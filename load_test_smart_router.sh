#!/bin/bash

# Smart Router Load Test Script
SMART_ROUTER="https://bnb-chain-jsonrpc.dev-smart-router.magmadevs.com:443"
DIRECT_IP="64.176.175.22"

# Configuration
DURATION="${1:-1s}"      # Default: 5 seconds
RATE="${2:-1000/s}"      # Default: 1000 requests per second
OUTPUT_FILE="${3:-smart_router_results.bin}"
BYPASS_CLOUDFLARE="${4:-true}"  # Default: bypass Cloudflare by connecting directly to IP
TIMEOUT="${5:-3m}"       # Default: 3 minutes timeout per request
MAX_CONNECTIONS="${6:-1000}"  # Default: 1000 max connections per host

echo "Starting load test..."
echo "Duration: $DURATION"
echo "Rate: $RATE"
echo "Timeout: $TIMEOUT per request"
echo "Max Connections: $MAX_CONNECTIONS"
echo "Target: $SMART_ROUTER"
if [ "$BYPASS_CLOUDFLARE" = "true" ]; then
  echo "Bypassing Cloudflare: Connecting directly to $DIRECT_IP:443"
  echo "Host header: bnb-chain-jsonrpc.dev-smart-router.magmadevs.com:443"
fi
echo ""

# Run the attack
if [ "$BYPASS_CLOUDFLARE" = "true" ]; then
  # Connect directly to IP but keep original hostname in Host header
  vegeta attack \
    -targets=smart_router_targets.txt \
    -connect-to="bnb-chain-jsonrpc.dev-smart-router.magmadevs.com:443:$DIRECT_IP:443" \
    -insecure \
    -duration=$DURATION \
    -rate=$RATE \
    -timeout=$TIMEOUT \
    -max-connections=$MAX_CONNECTIONS \
    -output=$OUTPUT_FILE
else
  # Normal attack through Cloudflare
  vegeta attack \
    -targets=smart_router_targets.txt \
    -duration=$DURATION \
    -rate=$RATE \
    -timeout=$TIMEOUT \
    -max-connections=$MAX_CONNECTIONS \
    -output=$OUTPUT_FILE
fi

echo ""
echo "Load test completed!"
echo ""
echo "=== Results Summary ==="
vegeta report $OUTPUT_FILE

echo ""
echo "=== Detailed JSON Report ==="
vegeta report -type=json $OUTPUT_FILE | jq '.'

echo ""
echo "=== Latency Histogram ==="
vegeta report -type="hist[0,100ms,200ms,500ms,1s,2s,5s]" $OUTPUT_FILE

echo ""
echo "Results saved to: $OUTPUT_FILE"
echo "Generate plot with: cat $OUTPUT_FILE | vegeta plot > plot.html"

