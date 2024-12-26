#!/bin/bash

#Variables
METRICS_URL=${METRICS_URL:-"http://node-exporter:9100/metrics"}
OUTPUT_DIR=${OUTPUT_DIR:-"/metrics"}
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="$OUTPUT_DIR/node-metrics-$TIMESTAMP.txt"

# Creating directory on the kubernetes node 
mkdir -p "$OUTPUT_DIR"

# Curl commands to save the metrics to a file
curl -s "$METRICS_URL" > "$OUTPUT_FILE"

echo "Metrics are sent to $OUTPUT_FILE"
