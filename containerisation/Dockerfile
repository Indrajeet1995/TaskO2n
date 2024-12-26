# Base image
FROM alpine:latest

# dependancy packages
RUN apk add --no-cache bash curl

COPY metrics.sh /usr/local/bin/metrics.sh

# Permission for the script
RUN chmod +x /usr/local/bin/metrics.sh

# Entrypoint
ENTRYPOINT ["/usr/local/bin/metrics.sh"]
