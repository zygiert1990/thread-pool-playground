#!/bin/bash
set -e

JVM_OPTS=$1
APP_JAR=$2
SAMPLE_INTERVAL=$3

METRICS_FILE="/tmp/app-metrics.csv"
PID_FILE="/tmp/app.pid"
SAMPLER_PID_FILE="/tmp/sampler.pid"

# Source sdkman to add Java to PATH
if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Now which will work
JAVA_CMD=$(which java)

echo "=== Starting Application ==="

# Clean up old files
rm -f "$METRICS_FILE" "$PID_FILE" "$SAMPLER_PID_FILE"

# Start application in background
echo "Starting Java application..."
nohup $JAVA_CMD $JVM_OPTS -jar "$APP_JAR" > /tmp/app.log 2>&1 &
APP_PID=$!
echo $APP_PID > "$PID_FILE"

echo "Application started with PID: $APP_PID"

# Wait 10 seconds for app to initialize
echo "Waiting 10 seconds for application to initialize..."
sleep 10

# Verify app is still running
if ! kill -0 "$APP_PID" 2>/dev/null; then
  echo "ERROR: Application failed to start!"
  cat /tmp/app.log
  exit 1
fi

# Start metrics sampler
echo "Starting metrics sampler..."
nohup /opt/bench/sample-metrics.sh "$APP_PID" "$SAMPLE_INTERVAL" "$METRICS_FILE" > /tmp/sampler.log 2>&1 &
SAMPLER_PID=$!
echo $SAMPLER_PID > "$SAMPLER_PID_FILE"

echo "Sampler started with PID: $SAMPLER_PID"
echo "Application ready for testing"
