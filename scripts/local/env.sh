#!/bin/bash

# App runner connection
APP_RUNNER="app-runner"
# necessary to reach app-runner form gatling-runner
APP_RUNNER_IP="<app_runner_ip>"

# Gatling runner connection
GATLING_RUNNER="gatling-runner"
GATLING_RUNNER_USER="<gatling-runner-user>"

# Gatling runner project path
GATLING_RUNNER_PROJECT_PATH="/home/$GATLING_RUNNER_USER/thread-pool-playground"

# Gatling simulation class (full path, e.g., com.example.MySimulation)
GATLING_SIMULATION="org.zygiert.threadpoolapp.RunComputations"

# Gatling test parameters
COMPUTATION_COMPLEXITY=""
CONCURRENCY_MULTIPLIER="1"
DURATION="300"  # seconds
LONG_IO=""

# App settings
APP_JAR_PATH="/opt/app/thread-pool-playground.jar"
APP_PORT=8080
JVM_OPTS="-Xmx8g"

# Configuration parameters (will be passed as -D flags and used in result folder name)
THREAD_POOL_CONFIG=""
FJP_BLOCKING_IO=""

# Sampling interval (seconds)
SAMPLE_INTERVAL=2

# Results directory
RESULTS_DIR="<path-to-result-dir>"
