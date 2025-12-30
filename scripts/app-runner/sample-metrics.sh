#!/bin/bash

# Usage: sample-metrics.sh <PID> <INTERVAL> <OUTPUT_FILE>

if [ $# -ne 3 ]; then
  echo "Usage: $0 <PID> <INTERVAL> <OUTPUT_FILE>"
  exit 1
fi

PID=$1
INTERVAL=$2
OUTPUT_FILE=$3

# Write CSV header with both CPU percentage styles
echo "timestamp,cpu_percent_per_core,cpu_percent_system_wide,rss_kb,rss_mb,threads" > "$OUTPUT_FILE"

echo "Starting metrics sampling for PID $PID (interval: ${INTERVAL}s)"

# Initialize previous values for CPU calculation
PREV_TOTAL=0
PREV_PROCESS=0

# Get number of CPU cores
NUM_CORES=$(nproc)

echo "System has $NUM_CORES CPU cores"
echo "- cpu_percent_per_core: can go 0-$(($NUM_CORES * 100))% (100% = 1 full core)"
echo "- cpu_percent_system_wide: 0-100% (100% = all cores maxed)"

# Sample loop
while kill -0 "$PID" 2>/dev/null; do
  TIMESTAMP=$(date +%s)

  # ===== CPU MEASUREMENT =====
  STAT=$(cat /proc/$PID/stat 2>/dev/null)
  if [ -z "$STAT" ]; then
    echo "Process $PID no longer exists, stopping sampler"
    break
  fi

  UTIME=$(echo "$STAT" | awk '{print $14}')
  STIME=$(echo "$STAT" | awk '{print $15}')
  PROCESS_TIME=$((UTIME + STIME))

  TOTAL_CPU=$(head -1 /proc/stat | awk '{sum=$2+$3+$4+$5+$6+$7+$8; print sum}')

  # Calculate BOTH CPU percentage styles
  if [ $PREV_TOTAL -ne 0 ]; then
    TOTAL_DELTA=$((TOTAL_CPU - PREV_TOTAL))
    PROCESS_DELTA=$((PROCESS_TIME - PREV_PROCESS))

    if [ $TOTAL_DELTA -gt 0 ]; then
      # Per-core: 100% = 1 full core (can exceed 100% on multi-core)
      CPU_PER_CORE=$(awk "BEGIN {printf \"%.2f\", ($PROCESS_DELTA / $TOTAL_DELTA) * 100 * $NUM_CORES}")

      # System-wide: 0-100% where 100% = all cores maxed
      CPU_SYSTEM_WIDE=$(awk "BEGIN {printf \"%.2f\", ($PROCESS_DELTA / $TOTAL_DELTA) * 100}")
    else
      CPU_PER_CORE="0.00"
      CPU_SYSTEM_WIDE="0.00"
    fi
  else
    CPU_PER_CORE="0.00"
    CPU_SYSTEM_WIDE="0.00"
  fi

  PREV_TOTAL=$TOTAL_CPU
  PREV_PROCESS=$PROCESS_TIME

  # ===== MEMORY MEASUREMENT =====
  RSS=$(awk '/^VmRSS:/ {print $2}' /proc/$PID/status 2>/dev/null)
  RSS_MB=$(awk "BEGIN {printf \"%.2f\", $RSS / 1024}")
  THREADS=$(awk '/^Threads:/ {print $2}' /proc/$PID/status 2>/dev/null)

  if [ -z "$RSS" ] || [ -z "$THREADS" ]; then
    echo "Process $PID no longer exists, stopping sampler"
    break
  fi

  # Append to CSV with BOTH CPU metrics
  echo "$TIMESTAMP,$CPU_PER_CORE,$CPU_SYSTEM_WIDE,$RSS,$RSS_MB,$THREADS" >> "$OUTPUT_FILE"

  sleep "$INTERVAL"
done

echo "Metrics sampling stopped"
