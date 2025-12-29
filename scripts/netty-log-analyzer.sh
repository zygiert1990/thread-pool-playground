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

# Temporary arrays
declare -A registered_times
declare -A last_read_complete_times

# Temporary file to store results
temp_file=$(mktemp)

while IFS= read -r line; do
    # Extract timestamp
    if [[ $line =~ ^([0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}) ]]; then
        timestamp="${BASH_REMATCH[1]}"

        # Convert timestamp to milliseconds
        IFS=':.' read -r hours mins secs millis <<< "$timestamp"
        time_ms=$((10#$hours * 3600000 + 10#$mins * 60000 + 10#$secs * 1000 + 10#$millis))

        # Extract connection ID and event type
        if [[ $line =~ \[id:\ (0x[a-f0-9]+)[^\]]*\]\ (REGISTERED|READ\ COMPLETE|UNREGISTERED) ]]; then
            conn_id="${BASH_REMATCH[1]}"
            event="${BASH_REMATCH[2]}"

            if [ "$event" == "REGISTERED" ]; then
                registered_times[$conn_id]=$time_ms
            elif [ "$event" == "READ COMPLETE" ]; then
                # Keep updating the last READ COMPLETE time
                last_read_complete_times[$conn_id]=$time_ms
            elif [ "$event" == "UNREGISTERED" ]; then
                # Connection closed, calculate duration
                if [ -n "${registered_times[$conn_id]}" ] && [ -n "${last_read_complete_times[$conn_id]}" ]; then
                    reg_time=${registered_times[$conn_id]}
                    read_time=${last_read_complete_times[$conn_id]}
                    duration=$((read_time - reg_time))
                    # Store in temp file with duration first for sorting
                    echo "$duration|$conn_id" >> "$temp_file"
                fi
                # Clean up
                unset registered_times[$conn_id]
                unset last_read_complete_times[$conn_id]
            fi
        fi
    fi
done < "$LOG_FILE"

echo "Connection ID                                    | Duration (ms)"
echo "----------------------------------------------------------------------"

# Sort by duration (descending) and format output
sort -t'|' -k1 -rn "$temp_file" | while IFS='|' read -r duration conn_id; do
    printf "%-50s | %d ms\n" "$conn_id" "$duration"
done

echo "----------------------------------------------------------------------"
echo "Done"

# Clean up temp file
rm -f "$temp_file"