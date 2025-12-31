#!/bin/bash

# Smart Router Load Test Script
SMART_ROUTER="https://bnb-chain-jsonrpc.dev-smart-router.magmadevs.com:443"

# Configuration
DURATION="${1:-5s}"      # Default: 5 seconds
RATE="${2:-1000/s}"      # Default: 1000 requests per second
OUTPUT_FILE="${3:-smart_router_results.bin}"

echo "Starting load test..."
echo "Duration: $DURATION"
echo "Rate: $RATE"
echo "Target: $SMART_ROUTER"
echo ""

# Run the attack
vegeta attack \
  -targets=smart_router_targets.txt \
  -duration=$DURATION \
  -rate=$RATE \
  -output=$OUTPUT_FILE

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

