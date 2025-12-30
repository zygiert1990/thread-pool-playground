#!/bin/bash
set -e

# Capture script start time
SCRIPT_START_TIME=$(date +%s)

# Accept computation complexity as parameter (default: 10)
DEFAULT_COMPUTATION_COMPLEXITY=10
CUSTOM_COMPUTATION_COMPLEXITY=${1:-$DEFAULT_COMPUTATION_COMPLEXITY}

# Function to calculate and format elapsed time
elapsed_time() {
  local start_time=$1
  local current_time=$(date +%s)
  local elapsed=$((current_time - start_time))

  local hours=$((elapsed / 3600))
  local minutes=$(((elapsed % 3600) / 60))
  local seconds=$((elapsed % 60))

  printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Function to print time summary
print_time_summary() {
  local label=$1
  local elapsed=$(elapsed_time $SCRIPT_START_TIME)
  echo "⏱️  Time elapsed since start: $elapsed | $label"
}

# Array of all thread pool configurations from the enum
THREAD_POOL_CONFIGS=(
  "GLOBAL"
  "GLOBAL_VTP"
  "GLOBAL_CTP"
  "FJP"
  "FJP_VTP"
  "FJP_CTP"
  "CTP"
  "CTP_VTP"
  "FTP"
  "FTP_VTP"
  "FTP_CTP"
  "VTP"
)

# Use case configurations: "USE_CASE|COMPUTATION_COMPLEXITY|LONG_IO"
# If custom computation complexity is provided, use it for LONG_CPU cases
if [ "$CUSTOM_COMPUTATION_COMPLEXITY" != "$DEFAULT_COMPUTATION_COMPLEXITY" ]; then
  echo "Using custom computation complexity: $CUSTOM_COMPUTATION_COMPLEXITY for LONG_CPU cases"
  echo ""
fi

USE_CASES=(
  "SHORT_CPU_SHORT_IO|2|false"
  "SHORT_CPU_LONG_IO|2|true"
  "LONG_CPU_SHORT_IO|${CUSTOM_COMPUTATION_COMPLEXITY}|false"
  "LONG_CPU_LONG_IO|${CUSTOM_COMPUTATION_COMPLEXITY}|true"
)

echo "==================================================================="
echo "=== Starting full benchmark suite ==="
echo "=== Total runs: 4 use cases × 14 configs = 56 benchmark runs ==="
echo "==================================================================="
echo ""
print_time_summary "Script started"
echo ""

# Read the original RESULTS_DIR from env.sh
source env.sh
BASE_RESULTS_DIR="$RESULTS_DIR"

# Validate BASE_RESULTS_DIR
if [ -z "$BASE_RESULTS_DIR" ]; then
  echo "ERROR: RESULTS_DIR is not set in env.sh"
  exit 1
fi

# Try to create the base directory if it doesn't exist
mkdir -p "$BASE_RESULTS_DIR" || {
  echo "ERROR: Failed to create base results directory: $BASE_RESULTS_DIR"
  exit 1
}

# Create subdirectories for each use case
echo "Creating result directories..."
for USE_CASE_CONFIG in "${USE_CASES[@]}"; do
  USE_CASE=$(echo "$USE_CASE_CONFIG" | cut -d'|' -f1)
  mkdir -p "$BASE_RESULTS_DIR/$USE_CASE"
  echo "  - $BASE_RESULTS_DIR/$USE_CASE"
done
echo ""

OUTER_RUN=0
TOTAL_RUNS=0

# Outer loop: iterate through use cases
for USE_CASE_CONFIG in "${USE_CASES[@]}"; do
  OUTER_RUN=$((OUTER_RUN + 1))
  USE_CASE_START_TIME=$(date +%s)

  # Parse configuration for this use case
  USE_CASE=$(echo "$USE_CASE_CONFIG" | cut -d'|' -f1)
  COMP_COMPLEXITY=$(echo "$USE_CASE_CONFIG" | cut -d'|' -f2)
  LONG_IO_VALUE=$(echo "$USE_CASE_CONFIG" | cut -d'|' -f3)

  echo ""
  echo "###################################################################"
  echo "### USE CASE $OUTER_RUN/4: $USE_CASE"
  echo "### COMPUTATION_COMPLEXITY=$COMP_COMPLEXITY, LONG_IO=$LONG_IO_VALUE"
  echo "###################################################################"
  echo ""
  print_time_summary "Starting use case $OUTER_RUN/4"
  echo ""

  # Set use case specific parameters in env.sh (macOS compatible)
  sed -i '.bak' "s/^COMPUTATION_COMPLEXITY=.*/COMPUTATION_COMPLEXITY=\"$COMP_COMPLEXITY\"/" env.sh
  sed -i '.bak' "s/^LONG_IO=.*/LONG_IO=\"$LONG_IO_VALUE\"/" env.sh
  sed -i '.bak' "s|^RESULTS_DIR=.*|RESULTS_DIR=\"$BASE_RESULTS_DIR/$USE_CASE\"|" env.sh

  echo "=== Starting benchmark suite for $USE_CASE ==="
  echo "Total runs for this use case: 14 (10 configs + 2 GLOBAL variants + 2 FJP variants)"
  echo ""

  RUN_COUNT=0

  # Inner loop: iterate through thread pool configurations
  for CONFIG in "${THREAD_POOL_CONFIGS[@]}"; do
    RUN_COUNT=$((RUN_COUNT + 1))
    TOTAL_RUNS=$((TOTAL_RUNS + 1))

    if [ "$CONFIG" = "GLOBAL" ] || [ "$CONFIG" = "FJP" ]; then
      # Run GLOBAL/FJP with fjpBlockingIo=false
      echo "=========================================="
      echo "USE CASE: $USE_CASE ($OUTER_RUN/4)"
      echo "Run $RUN_COUNT/14 (Total: $TOTAL_RUNS/56): $CONFIG with fjpBlockingIo=false"
      echo "=========================================="

      # Modify env.sh (macOS compatible)
      sed -i '.bak' "s/^THREAD_POOL_CONFIG=.*/THREAD_POOL_CONFIG=\"$CONFIG\"/" env.sh
      sed -i '.bak' "s/^FJP_BLOCKING_IO=.*/FJP_BLOCKING_IO=\"false\"/" env.sh

      # Run benchmark
      ./run-benchmark.sh

      print_time_summary "Completed: $CONFIG with fjpBlockingIo=false"
      echo ""
      echo "Waiting 90 seconds before next run..."
      sleep 90

      # Run GLOBAL/FJP with fjpBlockingIo=true
      RUN_COUNT=$((RUN_COUNT + 1))
      TOTAL_RUNS=$((TOTAL_RUNS + 1))
      echo "=========================================="
      echo "USE CASE: $USE_CASE ($OUTER_RUN/4)"
      echo "Run $RUN_COUNT/14 (Total: $TOTAL_RUNS/56): $CONFIG with fjpBlockingIo=true"
      echo "=========================================="

      sed -i '.bak' "s/^FJP_BLOCKING_IO=.*/FJP_BLOCKING_IO=\"true\"/" env.sh

      ./run-benchmark.sh

      print_time_summary "Completed: $CONFIG with fjpBlockingIo=true"
    else
      # For all other configs, fjpBlockingIo doesn't matter - leave it empty
      echo "=========================================="
      echo "USE CASE: $USE_CASE ($OUTER_RUN/4)"
      echo "Run $RUN_COUNT/14 (Total: $TOTAL_RUNS/56): $CONFIG"
      echo "=========================================="

      sed -i '.bak' "s/^THREAD_POOL_CONFIG=.*/THREAD_POOL_CONFIG=\"$CONFIG\"/" env.sh
      sed -i '.bak' "s/^FJP_BLOCKING_IO=.*/FJP_BLOCKING_IO=\"\"/" env.sh

      ./run-benchmark.sh

      print_time_summary "Completed: $CONFIG"
    fi

    echo ""
    echo "Waiting 90 seconds before next run..."
    sleep 90
  done

  USE_CASE_ELAPSED=$(elapsed_time $USE_CASE_START_TIME)
  echo ""
  echo "=== Benchmark suite for $USE_CASE complete ==="
  echo "⏱️  Use case duration: $USE_CASE_ELAPSED"
  print_time_summary "Finished use case $OUTER_RUN/4"
  echo ""

  if [ $OUTER_RUN -lt 4 ]; then
    echo "Waiting 120 seconds before next use case..."
    sleep 120
  fi
done

# Restore original RESULTS_DIR (macOS compatible)
sed -i '.bak' "s|^RESULTS_DIR=.*|RESULTS_DIR=\"$BASE_RESULTS_DIR\"|" env.sh

# Clean up backup files
rm -f env.sh.bak

TOTAL_ELAPSED=$(elapsed_time $SCRIPT_START_TIME)
echo ""
echo "==================================================================="
echo "=== Full benchmark suite complete ==="
echo "=== All 4 use cases tested (56 total configurations) ==="
echo "⏱️  Total execution time: $TOTAL_ELAPSED"
echo "==================================================================="
echo "Results saved in:"
for USE_CASE_CONFIG in "${USE_CASES[@]}"; do
  USE_CASE=$(echo "$USE_CASE_CONFIG" | cut -d'|' -f1)
  echo "  - $BASE_RESULTS_DIR/$USE_CASE"
done
