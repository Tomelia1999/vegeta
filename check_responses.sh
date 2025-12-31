#!/bin/bash

# Response Monitoring Script for Vegeta Results
# Usage: ./check_responses.sh [results_file.bin]

RESULTS_FILE="${1:-quick_test.bin}"

if [ ! -f "$RESULTS_FILE" ]; then
    echo "Error: Results file '$RESULTS_FILE' not found!"
    echo "Usage: $0 [results_file.bin]"
    exit 1
fi

echo "=========================================="
echo "Response Monitoring Report"
echo "=========================================="
echo "File: $RESULTS_FILE"
echo ""

# Convert to JSON for analysis
JSON_OUTPUT=$(vegeta encode -to json "$RESULTS_FILE")

echo "=== 1. Response Status Codes ==="
echo "$JSON_OUTPUT" | jq -r '.code' | sort | uniq -c | awk '{printf "  %s: %d requests\n", $2, $1}'
echo ""

echo "=== 2. Response Headers Summary ==="
echo "Key headers found in responses:"
echo "$JSON_OUTPUT" | jq -r '.headers | keys[]' | sort -u | head -10
echo ""

echo "=== 3. Custom Headers (Provider/Lava) ==="
echo "Provider-Latest-Block values:"
echo "$JSON_OUTPUT" | jq -r 'select(.headers["Provider-Latest-Block"] != null) | .headers["Provider-Latest-Block"][0]' | sort -u
echo ""

echo "Lava-Guid values (sample of 5):"
echo "$JSON_OUTPUT" | jq -r 'select(.headers["Lava-Guid"] != null) | .headers["Lava-Guid"][0]' | head -5
echo ""

echo "Lava-Provider-Address values:"
echo "$JSON_OUTPUT" | jq -r 'select(.headers["Lava-Provider-Address"] != null) | .headers["Lava-Provider-Address"][0]' | sort -u
echo ""

echo "=== 4. Response Body Analysis ==="
echo "Sample response bodies (decoded, first 3):"
echo "$JSON_OUTPUT" | jq -r '.body' | head -3 | while read -r body; do
    if [ -n "$body" ]; then
        echo "$body" | base64 -d | jq '.' 2>/dev/null || echo "$body" | base64 -d
        echo "---"
    fi
done
echo ""

echo "=== 5. Response Body Content Check ==="
echo "Checking for 'result' field in JSON responses:"
HAS_RESULT=$(echo "$JSON_OUTPUT" | jq -r '.body' | head -1 | base64 -d | jq -r '.result // "N/A"' 2>/dev/null)
if [ "$HAS_RESULT" != "N/A" ] && [ -n "$HAS_RESULT" ]; then
    echo "  ✓ Response contains 'result' field: $HAS_RESULT"
else
    echo "  ✗ No 'result' field found"
fi
echo ""

echo "=== 6. Latency Distribution ==="
LATENCY_STATS=$(echo "$JSON_OUTPUT" | jq -r '.latency' | awk '
{
    latencies[NR] = $1 / 1000000  # Convert nanoseconds to milliseconds
    sum += $1 / 1000000
}
END {
    n = NR
    if (n > 0) {
        # Simple sort using bubble sort for compatibility
        for (i=1; i<=n; i++) {
            for (j=i+1; j<=n; j++) {
                if (latencies[i] > latencies[j]) {
                    temp = latencies[i]
                    latencies[i] = latencies[j]
                    latencies[j] = temp
                }
            }
        }
        printf "  Min:    %.2f ms\n", latencies[1]
        if (n > 1) {
            printf "  P50:    %.2f ms\n", latencies[int(n*0.5)+1]
            printf "  P95:    %.2f ms\n", latencies[int(n*0.95)+1]
            printf "  P99:    %.2f ms\n", latencies[int(n*0.99)+1]
        }
        printf "  Max:    %.2f ms\n", latencies[n]
        printf "  Mean:   %.2f ms\n", sum/n
    }
}')
echo "$LATENCY_STATS"
echo ""

echo "=== 7. Error Analysis ==="
ERROR_COUNT=$(echo "$JSON_OUTPUT" | jq -r 'select(.error != "") | .error' | wc -l | tr -d ' ')
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "  ⚠ Found $ERROR_COUNT errors:"
    echo "$JSON_OUTPUT" | jq -r 'select(.error != "") | "  - \(.error)"' | sort -u
else
    echo "  ✓ No errors found"
fi
echo ""

echo "=== 8. Response Size Analysis ==="
SIZE_STATS=$(echo "$JSON_OUTPUT" | jq -r '.bytes_in' | awk '
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
}')
echo "$SIZE_STATS"
echo ""

echo "=== 9. Timestamp Range ==="
FIRST=$(echo "$JSON_OUTPUT" | jq -r '.timestamp' | head -1)
LAST=$(echo "$JSON_OUTPUT" | jq -r '.timestamp' | tail -1)
echo "  First request: $FIRST"
echo "  Last request:  $LAST"
echo ""

echo "=========================================="
echo "For detailed JSON output, run:"
echo "  vegeta encode -to json $RESULTS_FILE | jq '.'"
echo "=========================================="

