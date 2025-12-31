#!/bin/bash

# Response Aggregation Script for Vegeta Results
# Usage: ./aggregate_responses.sh [results_file.bin]

RESULTS_FILE="${1:-smart_router_results.bin}"

if [ ! -f "$RESULTS_FILE" ]; then
    echo "Error: Results file '$RESULTS_FILE' not found!"
    echo "Usage: $0 [results_file.bin]"
    exit 1
fi

echo "=========================================="
echo "Response Aggregation Report"
echo "=========================================="
echo "File: $RESULTS_FILE"
echo ""

# Convert to JSON for analysis
JSON_OUTPUT=$(vegeta encode -to json "$RESULTS_FILE")
TOTAL=$(echo "$JSON_OUTPUT" | jq -s 'length')

echo "Total Requests: $TOTAL"
echo ""

echo "=== 1. Status Code Distribution ==="
echo "$JSON_OUTPUT" | jq -r '.code' | sort | uniq -c | awk '{printf "  %-6s: %6d requests (%.2f%%)\n", $2, $1, ($1/'$TOTAL')*100}'
echo ""

echo "=== 2. Response Body Content Analysis ==="
echo "Extracting JSON-RPC result values..."
echo ""

# Group by response body result (for JSON-RPC)
RESULT_VALUES=$(echo "$JSON_OUTPUT" | jq -r 'select(.code == 200) | .body' | base64 -d 2>/dev/null | jq -r '.result // "N/A"' 2>/dev/null | sort | uniq -c | sort -rn)

if [ -n "$RESULT_VALUES" ]; then
    echo "JSON-RPC Result Values:"
    echo "$RESULT_VALUES" | awk '{printf "  %-20s: %6d occurrences\n", $2, $1}'
else
    echo "  No valid JSON-RPC results found"
fi
echo ""

echo "=== 3. Response Body Types ==="
echo "Analyzing response body patterns..."
echo ""

# Check for different response patterns
SUCCESS_WITH_RESULT=$(echo "$JSON_OUTPUT" | jq -r 'select(.code == 200) | .body' | base64 -d 2>/dev/null | jq -r 'select(.result != null) | .result' 2>/dev/null | wc -l | tr -d ' ')
SUCCESS_WITH_ERROR=$(echo "$JSON_OUTPUT" | jq -r 'select(.code == 200) | .body' | base64 -d 2>/dev/null | jq -r 'select(.error != null) | .error' 2>/dev/null | wc -l | tr -d ' ')
SUCCESS_EMPTY=$(echo "$JSON_OUTPUT" | jq -r 'select(.code == 200 and (.body == "" or .body == null)) | .code' | wc -l | tr -d ' ')

echo "  Responses with 'result' field: $SUCCESS_WITH_RESULT"
echo "  Responses with 'error' field: $SUCCESS_WITH_ERROR"
echo "  Empty responses: $SUCCESS_EMPTY"
echo ""

echo "=== 4. Error Type Aggregation ==="
ERROR_COUNT=$(echo "$JSON_OUTPUT" | jq -r 'select(.code == 0) | .error' | wc -l | tr -d ' ')
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "Error Distribution (Status Code 0):"
    echo "$JSON_OUTPUT" | jq -r 'select(.code == 0) | .error' | sort | uniq -c | sort -rn | head -10 | awk '{printf "  %-6d: %s\n", $1, substr($0, index($0,$2))}'
else
    echo "  No errors found (status code 0)"
fi
echo ""

echo "=== 5. HTTP Error Codes (4xx, 5xx) ==="
HTTP_ERRORS=$(echo "$JSON_OUTPUT" | jq -r 'select(.code >= 400) | .code' | sort | uniq -c)
if [ -n "$HTTP_ERRORS" ]; then
    echo "$HTTP_ERRORS" | awk '{printf "  %-6s: %6d requests\n", $2, $1}'
else
    echo "  No HTTP error codes (4xx, 5xx) found"
fi
echo ""

echo "=== 6. Response Header Analysis ==="
echo "Provider-Latest-Block values (showing unique block numbers):"
BLOCK_NUMS=$(echo "$JSON_OUTPUT" | jq -r 'select(.headers["Provider-Latest-Block"] != null) | .headers["Provider-Latest-Block"][0]' | sort -u)
BLOCK_COUNT=$(echo "$BLOCK_NUMS" | wc -l | tr -d ' ')
echo "  Unique block numbers: $BLOCK_COUNT"
if [ "$BLOCK_COUNT" -le 20 ]; then
    echo "$BLOCK_NUMS" | awk '{printf "    %s\n", $1}'
else
    echo "  (showing first and last 5)"
    echo "$BLOCK_NUMS" | head -5 | awk '{printf "    %s\n", $1}'
    echo "    ..."
    echo "$BLOCK_NUMS" | tail -5 | awk '{printf "    %s\n", $1}'
fi
echo ""

echo "=== 7. Response Size Distribution ==="
echo "$JSON_OUTPUT" | jq -r '.bytes_in' | awk '
{
    sizes[NR] = $1
    sum += $1
    if (NR == 1 || $1 < min) min = $1
    if (NR == 1 || $1 > max) max = $1
}
END {
    n = NR
    if (n > 0) {
        printf "  Min:    %d bytes\n", min
        printf "  Max:    %d bytes\n", max
        printf "  Mean:   %.2f bytes\n", sum/n
        printf "  Total:  %d bytes\n", sum
    }
}'
echo ""

echo "=== 8. Latency by Response Type ==="
echo "Average latency by status code:"
echo "$JSON_OUTPUT" | jq -r '[.code, .latency] | @tsv' | awk '
{
    code = $1
    latency = $2 / 1000000  # Convert to milliseconds
    count[code]++
    sum[code] += latency
}
END {
    for (code in count) {
        printf "  %-6s: %.2f ms (from %d requests)\n", code, sum[code]/count[code], count[code]
    }
}' | sort
echo ""

echo "=== 9. Response Pattern Summary ==="
SUCCESS_200=$(echo "$JSON_OUTPUT" | jq -r 'select(.code == 200) | .code' | wc -l | tr -d ' ')
FAILED_0=$(echo "$JSON_OUTPUT" | jq -r 'select(.code == 0) | .code' | wc -l | tr -d ' ')
OTHER=$(echo "$JSON_OUTPUT" | jq -r 'select(.code != 200 and .code != 0) | .code' | wc -l | tr -d ' ')

echo "  Successful (200):     $SUCCESS_200 ($(awk "BEGIN {printf \"%.2f\", ($SUCCESS_200/$TOTAL)*100}")%)"
echo "  Failed (0):           $FAILED_0 ($(awk "BEGIN {printf \"%.2f\", ($FAILED_0/$TOTAL)*100}")%)"
echo "  Other status codes:   $OTHER ($(awk "BEGIN {printf \"%.2f\", ($OTHER/$TOTAL)*100}")%)"
echo ""

echo "=== 10. Sample Responses ==="
echo "Sample successful response (first one):"
echo "$JSON_OUTPUT" | jq -r 'select(.code == 200) | .body' | head -1 | base64 -d 2>/dev/null | jq '.' 2>/dev/null || echo "  (Could not decode)"
echo ""

if [ "$FAILED_0" -gt 0 ]; then
    echo "Sample failed response (first one):"
    echo "$JSON_OUTPUT" | jq -r 'select(.code == 0) | {seq: .seq, error: .error, timestamp: .timestamp}' | head -3
fi
echo ""

echo "=========================================="
echo "For detailed analysis, run:"
echo "  vegeta encode -to json $RESULTS_FILE | jq '.'"
echo "=========================================="

