#!/bin/bash
set -e

PROJECT_PATH=$1
SIMULATION=$2
TARGET_HOST=$3
TARGET_PORT=$4
COMPUTATION_COMPLEXITY=$5
CONCURRENCY_MULTIPLIER=$6
DURATION=$7
LONG_IO=$8

if [ -z "$PROJECT_PATH" ] || [ -z "$SIMULATION" ] || [ -z "$TARGET_HOST" ] || [ -z "$TARGET_PORT" ] || [ -z "$COMPUTATION_COMPLEXITY" ] || [ -z "$CONCURRENCY_MULTIPLIER" ] || [ -z "$DURATION" ] || [ -z "$LONG_IO" ]; then
  echo "Usage: $0 <PROJECT_PATH> <SIMULATION> <TARGET_HOST> <TARGET_PORT> <COMPUTATION_COMPLEXITY> <CONCURRENCY_MULTIPLIER> <DURATION> <LONG_IO>"
  echo "Example: $0 /home/user/my-project com.example.MySimulation 192.168.1.100 8080 1000 10 300 false"
  exit 1
fi

BASE_URL="http://${TARGET_HOST}:${TARGET_PORT}"

# Source sdkman if it exists
if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Find sbt
if command -v sbt >/dev/null 2>&1; then
  SBT_CMD=$(which sbt)
else
  echo "ERROR: sbt not found!"
  exit 1
fi

echo "=== Running Gatling Tests ==="
echo "Using sbt: $SBT_CMD"
echo "Project: $PROJECT_PATH"
echo "Simulation: $SIMULATION"
echo "Target: $BASE_URL"
echo "Computation Complexity: $COMPUTATION_COMPLEXITY"
echo "Concurrency Multiplier: $CONCURRENCY_MULTIPLIER"
echo "Duration: ${DURATION}s"
echo "Long IO: $LONG_IO"

cd "$PROJECT_PATH"

# Run specific Gatling simulation via sbt
# Pass all parameters as system properties
echo "Starting Gatling simulation..."
GATLING_BASE_URL="$BASE_URL" \
COMPUTATION_COMPLEXITY="$COMPUTATION_COMPLEXITY" \
CONCURRENCY_MULTIPLIER="$CONCURRENCY_MULTIPLIER" \
DURATION="$DURATION" \
LONG_IO="$LONG_IO" \
$SBT_CMD "Gatling/testOnly $SIMULATION"

echo "Gatling tests completed"
