#!/bin/bash
set -e

# Load configuration
source ./env.sh

# Build configuration name for results folder
CONFIG_NAME="${THREAD_POOL_CONFIG}"
if [ -n "$FJP_BLOCKING_IO" ]; then
  CONFIG_NAME="${CONFIG_NAME}_fjp-${FJP_BLOCKING_IO}"
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RUN_DIR="$RESULTS_DIR/${CONFIG_NAME}_${TIMESTAMP}"

echo "=== Starting benchmark run: $CONFIG_NAME at $TIMESTAMP ==="

# Create results directory
mkdir -p "$RUN_DIR"

# Build JVM system properties
SYSTEM_PROPS="-DthreadPoolConfig=$THREAD_POOL_CONFIG"
if [ -n "$FJP_BLOCKING_IO" ]; then
  SYSTEM_PROPS="$SYSTEM_PROPS -DfjpBlockingIo=$FJP_BLOCKING_IO"
fi

# Combine with JVM opts
FULL_JVM_OPTS="$JVM_OPTS $SYSTEM_PROPS"

# Step 1: Start app on app-runner
echo "[1/6] Starting application..."
echo "  Configuration: $CONFIG_NAME"
echo "  JVM options: $FULL_JVM_OPTS"
ssh "$APP_RUNNER" "/opt/bench/app-start.sh '$FULL_JVM_OPTS' '$APP_JAR_PATH' $SAMPLE_INTERVAL"

# Step 2: Measure network latency from gatling-runner to app-runner
echo "[2/6] Measuring network latency from gatling-runner to app-runner (100 pings)..."
ssh "$GATLING_RUNNER" "ping -c 100 -i 0.2 $APP_RUNNER_IP | tail -1" > "$RUN_DIR/network-latency.txt" || echo "Latency check failed"

# Step 3: Clean up previous Gatling reports
echo "[3/6] Cleaning up previous Gatling reports..."
ssh "$GATLING_RUNNER" "rm -rf $GATLING_RUNNER_PROJECT_PATH/target/gatling/*"
echo "  Previous reports deleted"

# Step 4: Run Gatling tests from GCP
echo "[4/6] Running Gatling tests from GCP..."
echo "  Simulation: $GATLING_SIMULATION"
echo "  Target: http://$APP_RUNNER_IP:$APP_PORT"
echo "  Complexity: $COMPUTATION_COMPLEXITY, Multiplier: $CONCURRENCY_MULTIPLIER, Duration: ${DURATION}s, LongIO: $LONG_IO"
ssh "$GATLING_RUNNER" "/opt/bench/gatling-run.sh '$GATLING_RUNNER_PROJECT_PATH' '$GATLING_SIMULATION' '$APP_RUNNER_IP' '$APP_PORT' '$COMPUTATION_COMPLEXITY' '$CONCURRENCY_MULTIPLIER' '$DURATION' '$LONG_IO'"

# Wait 90 seconds to capture post-test metrics
echo "Waiting 90 seconds to capture post-test metrics..."
sleep 90

# Step 5: Stop app and sampler on app-runner
echo "[5/6] Stopping application..."
ssh "$APP_RUNNER" "/opt/bench/app-stop.sh"

# Step 6: Download metrics and Gatling results
echo "[6/6] Downloading results..."

# Download app metrics
scp "$APP_RUNNER:/tmp/app-metrics.csv" "$RUN_DIR/app-metrics.csv"

# Download Gatling results (latest simulation results)
echo "  Downloading Gatling results..."
LATEST_GATLING_DIR=$(ssh "$GATLING_RUNNER" "ls -td $GATLING_RUNNER_PROJECT_PATH/target/gatling/* | head -1")
scp -r "$GATLING_RUNNER:$LATEST_GATLING_DIR" "$RUN_DIR/gatling-results/"

# Save run configuration metadata
echo "Configuration: $CONFIG_NAME" > "$RUN_DIR/run-info.txt"
echo "Timestamp: $TIMESTAMP" >> "$RUN_DIR/run-info.txt"
echo "threadPoolConfig: $THREAD_POOL_CONFIG" >> "$RUN_DIR/run-info.txt"
echo "fjpBlockingIo: ${FJP_BLOCKING_IO:-<not set>}" >> "$RUN_DIR/run-info.txt"
echo "Gatling Simulation: $GATLING_SIMULATION" >> "$RUN_DIR/run-info.txt"
echo "Target Host: $APP_RUNNER_IP:$APP_PORT" >> "$RUN_DIR/run-info.txt"
echo "Computation Complexity: $COMPUTATION_COMPLEXITY" >> "$RUN_DIR/run-info.txt"
echo "Concurrency Multiplier: $CONCURRENCY_MULTIPLIER" >> "$RUN_DIR/run-info.txt"
echo "Duration: ${DURATION}s" >> "$RUN_DIR/run-info.txt"
echo "Long IO: $LONG_IO" >> "$RUN_DIR/run-info.txt"

echo ""
echo "=== Benchmark complete ==="
echo "Results saved to: $RUN_DIR"
echo ""
echo "Files:"
ls -lh "$RUN_DIR"
