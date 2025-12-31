# Response Aggregation Commands

## Full Aggregation Report

```bash
./aggregate_responses.sh smart_router_results.bin
```

Shows:
- Status code distribution
- Response body content analysis (JSON-RPC results)
- Error type aggregation
- HTTP error codes
- Response headers analysis
- Response size distribution
- Latency by response type
- Response pattern summary

## Quick One-Liners

### Status Code Distribution
```bash
vegeta encode -to json results.bin | jq -r '.code' | sort | uniq -c
```

### JSON-RPC Result Values (Block Numbers)
```bash
vegeta encode -to json results.bin | jq -r 'select(.code == 200) | .body' | base64 -d | jq -r '.result' | sort | uniq -c | sort -rn
```

### Error Types
```bash
vegeta encode -to json results.bin | jq -r 'select(.code == 0) | .error' | sort | uniq -c | sort -rn
```

### Response Body Types
```bash
# Count responses with 'result' field
vegeta encode -to json results.bin | jq -r 'select(.code == 200) | .body' | base64 -d | jq -r 'select(.result != null) | .result' | wc -l

# Count responses with 'error' field
vegeta encode -to json results.bin | jq -r 'select(.code == 200) | .body' | base64 -d | jq -r 'select(.error != null) | .error' | wc -l
```

### Provider-Latest-Block Header Values
```bash
vegeta encode -to json results.bin | jq -r 'select(.headers["Provider-Latest-Block"] != null) | .headers["Provider-Latest-Block"][0]' | sort -u
```

### Response Size by Status Code
```bash
vegeta encode -to json results.bin | jq -r '[.code, .bytes_in] | @tsv' | awk '{sum[$1]+=$2; count[$1]++} END {for (code in sum) printf "%s: %.2f bytes (avg from %d requests)\n", code, sum[code]/count[code], count[code]}'
```

### Latency by Status Code
```bash
vegeta encode -to json results.bin | jq -r '[.code, .latency] | @tsv' | awk '{latency=$2/1000000; sum[$1]+=latency; count[$1]++} END {for (code in sum) printf "%s: %.2f ms (avg from %d requests)\n", code, sum[code]/count[code], count[code]}'
```

### Group by Response Pattern
```bash
# Group by status code and result value
vegeta encode -to json results.bin | jq -r 'select(.code == 200) | [.code, (.body | @base64d | fromjson | .result // "N/A")] | @tsv' | sort | uniq -c
```

### Sample Responses
```bash
# First successful response
vegeta encode -to json results.bin | jq -r 'select(.code == 200) | .body' | head -1 | base64 -d | jq '.'

# First failed response
vegeta encode -to json results.bin | jq -r 'select(.code == 0) | {seq: .seq, error: .error}' | head -1
```

## Using the Aggregation Script

```bash
# Default (uses smart_router_results.bin)
./aggregate_responses.sh

# Specify a different file
./aggregate_responses.sh results.bin

# Or any results file
./aggregate_responses.sh my_test_results.bin
```

