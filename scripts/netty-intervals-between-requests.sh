#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <log-file-path>"
    exit 1
fi

LOG_FILE="$1"

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: File '$LOG_FILE' not found"
    exit 1
fi

echo "Connection ID                                    | Interval from previous (ms)"
echo "--------------------------------------------------------------------------------"

last_registered_time=""
last_conn_id=""

while IFS= read -r line; do
    # Extract timestamp
    if [[ $line =~ ^([0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}) ]]; then
        timestamp="${BASH_REMATCH[1]}"

        # Convert timestamp to milliseconds
        IFS=':.' read -r hours mins secs millis <<< "$timestamp"
        time_ms=$((10#$hours * 3600000 + 10#$mins * 60000 + 10#$secs * 1000 + 10#$millis))

        # Extract connection ID and check for REGISTERED event
        if [[ $line =~ \[id:\ (0x[a-f0-9]+)[^\]]*\]\ REGISTERED ]]; then
            conn_id="${BASH_REMATCH[1]}"

            if [ -n "$last_registered_time" ]; then
                interval=$((time_ms - last_registered_time))
                printf "%-50s | %d ms\n" "$conn_id" "$interval"
            else
                printf "%-50s | (first)\n" "$conn_id"
            fi

            last_registered_time=$time_ms
            last_conn_id=$conn_id
        fi
    fi
done < "$LOG_FILE"

echo "--------------------------------------------------------------------------------"
echo "Done"