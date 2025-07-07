FROM alpine:latest

# Install curl, bash, jq, and docker-cli
RUN apk add --no-cache bash curl jq docker-cli

COPY task.sh /app/task.sh
WORKDIR /app

#ENTRYPOINT ["bash", "/app/task.sh"]
CMD ["./task.sh"]
