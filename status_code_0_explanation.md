# Status Code 0 in Vegeta - Explanation & Solutions

## What is Status Code 0?

**Status code `0`** in Vegeta means the request **failed before receiving an HTTP response**. It's not an HTTP error code - it indicates a **network/connection error**.

### Common Causes:

1. **Timeout** - Request took too long and was canceled
   - `Client.Timeout exceeded while awaiting headers`
   - `context deadline exceeded`

2. **Connection Refused** - Server rejected the connection
   - `dial tcp: connect: connection refused`

3. **DNS Failure** - Couldn't resolve hostname
   - `no such host`

4. **Network Issues** - Connection dropped
   - `connection reset by peer`
   - `broken pipe`

5. **Server Overwhelmed** - Server can't handle the load
   - Too many concurrent connections
   - Server is rate limiting

## Your Current Situation

From your test results:
- **Total requests**: 5000
- **Successful (200)**: 2531 (50.62%)
- **Failed (0)**: 2469 (49.38%)
- **Error type**: Timeout errors

This suggests the server is **overwhelmed** at 1000 requests/second.

## Solutions to Reduce Status Code 0 Errors

### 1. Increase Timeout (Default: 30s → 10s+)
```bash
# Use longer timeout
./load_test_smart_router.sh 5s 1000/s results.bin true 30s
#                                                      ^^^^ timeout
```

### 2. Reduce Request Rate
```bash
# Lower rate to avoid overwhelming server
./load_test_smart_router.sh 5s 500/s results.bin
#                              ^^^ lower rate
```

### 3. Increase Max Connections
```bash
# Allow more concurrent connections
./load_test_smart_router.sh 5s 1000/s results.bin true 10s 2000
#                                                          ^^^^ max connections
```

### 4. Check Server Capacity
- The server might not handle 1000 req/s
- Try ramping up gradually: 100/s → 500/s → 1000/s

### 5. Monitor Server Health
```bash
# Check if server is responding
curl -k --connect-to bnb-chain-jsonrpc.dev-smart-router.magmadevs.com:443:64.176.175.22:443 \
  -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  https://bnb-chain-jsonrpc.dev-smart-router.magmadevs.com:443
```

## Updated Script Usage

The script now supports timeout and max-connections:

```bash
# Full syntax:
./load_test_smart_router.sh [duration] [rate] [output_file] [bypass_cf] [timeout] [max_connections]

# Examples:
./load_test_smart_router.sh 5s 1000/s results.bin true 30s 2000
#                            ^^  ^^^^^  ^^^^^^^^^^  ^^^^  ^^^^  ^^^^
#                            |   |      |           |     |     |
#                            |   |      |           |     |     +-- Max connections
#                            |   |      |           |     +-------- Timeout
#                            |   |      |           +-------------- Bypass Cloudflare
#                            |   |      +-------------------------- Output file
#                            |   +---------------------------------- Request rate
#                            +-------------------------------------- Duration
```

## Understanding Your Results

When you see status code 0:
1. Check the error messages in the report
2. Look at the error patterns (all timeouts? all connection refused?)
3. Adjust timeout, rate, or connections accordingly
4. Consider if the server can handle the load

## Quick Check Commands

```bash
# See all errors
vegeta report -type=json results.bin | jq -r '.errors[]'

# Count error types
vegeta encode -to json results.bin | jq -r 'select(.code == 0) | .error' | sort | uniq -c

# Check success rate
vegeta report -type=json results.bin | jq '{success: .success, total: .requests, failed: (.status_codes."0" // 0)}'
```

