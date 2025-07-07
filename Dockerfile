FROM alpine:latest
RUN apk add --no-cache curl bash jq
WORKDIR /app
COPY task.sh .
RUN chmod +x task.sh
CMD ["./task.sh"]
