#!/bin/bash
set -e

if [[ -z "$DOMAIN" || -z "$PORT" || -z "$CLOUDFLARE_API_TOKEN" || -z "$CNAME_TARGET" || -z "$CADDYFILE_PATH" ]]; then
  echo "Missing required environment variables."
  exit 1
fi

echo "Processing domain: $DOMAIN on port: $PORT"

# Extract root domain (zone)
ROOT_DOMAIN=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
echo "Detected root domain: $ROOT_DOMAIN"

# Fetch Zone ID dynamically
CLOUDFLARE_ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ROOT_DOMAIN" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ -z "$CLOUDFLARE_ZONE_ID" || "$CLOUDFLARE_ZONE_ID" == "null" ]]; then
  echo "Failed to retrieve Zone ID for $ROOT_DOMAIN"
  exit 1
fi

echo "Retrieved Zone ID: $CLOUDFLARE_ZONE_ID"

# Check if DNS record exists
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?type=CNAME&name=$DOMAIN" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ "$RECORD_ID" != "null" && "$RECORD_ID" != "" ]]; then
  echo "DNS record for $DOMAIN already exists."
else
  echo "Creating DNS record for $DOMAIN..."
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"CNAME\",\"name\":\"$DOMAIN\",\"content\":\"$CNAME_TARGET\",\"ttl\":120,\"proxied\":true}" | jq
fi

# Backup Caddyfile
cp "$CADDYFILE_PATH" "${CADDYFILE_PATH}.bak_$(date +%Y%m%d%H%M%S)"

# Update Caddyfile if needed
if grep -q "$DOMAIN" "$CADDYFILE_PATH"; then
  echo "Caddyfile already contains configuration for $DOMAIN"
else
  echo "Appending to Caddyfile for $DOMAIN..."
  echo -e "\n$DOMAIN {\n    import cloudflare\n    reverse_proxy 172.17.0.1:$PORT\n}" >> "$CADDYFILE_PATH"
fi

# Reload Caddy
echo "Reloading Caddy..."
docker exec caddy caddy reload --config /etc/caddy/Caddyfile || echo "Warning: Failed to reload Caddy"

echo "Task completed."