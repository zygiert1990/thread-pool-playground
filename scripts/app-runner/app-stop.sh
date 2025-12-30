#!/bin/bash

PID_FILE="/tmp/app.pid"
SAMPLER_PID_FILE="/tmp/sampler.pid"

echo "=== Stopping Application ==="

# Stop sampler first
if [ -f "$SAMPLER_PID_FILE" ]; then
  SAMPLER_PID=$(cat "$SAMPLER_PID_FILE")
  if kill -0 "$SAMPLER_PID" 2>/dev/null; then
    echo "Stopping sampler (PID: $SAMPLER_PID)..."
    kill "$SAMPLER_PID"
    sleep 2
    kill -9 "$SAMPLER_PID" 2>/dev/null || true
  fi
  rm -f "$SAMPLER_PID_FILE"
fi

# Stop application
if [ -f "$PID_FILE" ]; then
  APP_PID=$(cat "$PID_FILE")
  if kill -0 "$APP_PID" 2>/dev/null; then
    echo "Stopping application (PID: $APP_PID)..."
    kill "$APP_PID"
    sleep 2
    kill -9 "$APP_PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi

echo "Application stopped"
echo "Metrics saved to: /tmp/app-metrics.csv"
