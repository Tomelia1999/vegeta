# Vegeta Response Monitoring Commands

## Quick One-Liners

### View All Response Details (JSON)
```bash
vegeta encode -to json results.bin | jq '.'
```

### Check Response Status Codes
```bash
vegeta encode -to json results.bin | jq -r '.code' | sort | uniq -c
```

### View Response Bodies (Decoded)
```bash
vegeta encode -to json results.bin | jq -r '.body' | head -5 | while read b; do echo "$b" | base64 -d | jq '.'; done
```

### Check Specific Response Header
```bash
# Check Provider-Latest-Block header
vegeta encode -to json results.bin | jq -r 'select(.headers["Provider-Latest-Block"] != null) | .headers["Provider-Latest-Block"][0]' | sort -u

# Check Lava-Guid header
vegeta encode -to json results.bin | jq -r 'select(.headers["Lava-Guid"] != null) | .headers["Lava-Guid"][0]' | head -10
```

### Extract Response Body Result Field
```bash
vegeta encode -to json results.bin | jq -r '.body' | head -1 | base64 -d | jq -r '.result'
```

### Check for Errors
```bash
vegeta encode -to json results.bin | jq -r 'select(.error != "") | {seq: .seq, error: .error}'
```

### View Response Headers (All)
```bash
vegeta encode -to json results.bin | jq -r '.headers | keys[]' | sort -u
```

### Latency Analysis
```bash
# Individual latencies in milliseconds
vegeta encode -to json results.bin | jq -r '.latency' | awk '{print $1/1000000 " ms"}'

# Or use vegeta report for aggregated stats
vegeta report results.bin
```

### Response Size Analysis
```bash
vegeta encode -to json results.bin | jq -r '.bytes_in' | awk '{sum+=$1; count++} END {print "Total:", sum, "bytes, Mean:", sum/count, "bytes"}'
```

### Filter by Status Code
```bash
# Only show 200 responses
vegeta encode -to json results.bin | jq 'select(.code == 200)'

# Only show non-200 responses
vegeta encode -to json results.bin | jq 'select(.code != 200)'
```

### Check Response Timestamps
```bash
vegeta encode -to json results.bin | jq -r '.timestamp' | head -1
vegeta encode -to json results.bin | jq -r '.timestamp' | tail -1
```

### Monitor Real-Time During Attack
```bash
vegeta attack -targets=smart_router_targets.txt -duration=60s -rate=10/s | \
  vegeta encode | \
  jq -r '"\(.timestamp) | Code: \(.code) | Latency: \(.latency/1000000)ms | Result: \(.body | @base64d | fromjson | .result // "N/A")"'
```

## Using the Monitoring Script

```bash
# Run full monitoring report
./check_responses.sh results.bin

# Or specify a different file
./check_responses.sh smart_router_results.bin
```

