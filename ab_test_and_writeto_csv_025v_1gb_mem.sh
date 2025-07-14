#!/bin/bash

FIB_URL="http://aws-fargate-app-v3-3-alb-1867801490.us-east-1.elb.amazonaws.com/fib"
OUTPUT_CSV="ab_results_2GB.csv"

# Write CSV header
echo "timestamp,endpoint,requests,concurrency,requests_per_sec,mean_time_per_request(ms),total_time_taken(s)" > "$OUTPUT_CSV"

# Function to run ab and log to CSV
run_ab_and_log() {
  local url=$1
  local requests=$2
  local concurrency=$3
  local label=$4

  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  tmpfile=$(mktemp)

  ab -s 60 -n "$requests" -c "$concurrency" "$url" > "$tmpfile" 2>&1

  rps=$(grep "Requests per second" "$tmpfile" | awk '{print $4}')
  mean_time=$(grep "Time per request" "$tmpfile" | head -1 | awk '{print $4}')
  total_time=$(grep "Time taken for tests" "$tmpfile" | awk '{print $5}')

  echo "$timestamp,$label,$requests,$concurrency,$rps,$mean_time,$total_time" >> "$OUTPUT_CSV"

  cat "$tmpfile" >> ab_full_log.txt
  rm "$tmpfile"
}

echo "Starting First Phase: 3 cycles with 1 request each and 5 min gaps..."

for i in {1..3}
do
  echo "[Cycle $i] Sending 1 request to /fib..."
  run_ab_and_log "$FIB_URL" 1 1 "/fib"

  echo "Sleeping 5 minutes..."
  sleep 300
done

echo "Starting Second Phase: 3 rounds of 100 requests (10 at a time) with gaps..."

for i in {1..3}
do
  echo "[Round $i] Sending 100 requests to /fib with concurrency 10..."
  run_ab_and_log "$FIB_URL" 100 10 "/fib"

  echo "Sleeping 5 minutes before next round..."
  sleep 300
done

echo "All request cycles completed."

