#!/bin/bash

# Default values
DEFAULT_RANGES="[0-3],[3-5],[5-7],[7-9],[9,+]"
DEFAULT_THRESHOLD=90

# --- Help Message ---
usage() {
    echo "Usage: $0 [\"<ranges>\"] [<threshold>]"
    echo "Analyzes docker container logs for 'Reading file took:' messages and categorizes timings."
    echo ""
    echo "Arguments:"
    echo "  <ranges>      Optional. A comma-separated string of ranges."
    echo "                Format: \"[min-max],[min-max],[min,+]\". The '+' denotes infinity."
    echo "                Example: \"[0-5],[5-10],[10,+]\""
    echo "                Defaults to: \"$DEFAULT_RANGES\""
    echo ""
    echo "  <threshold>   Optional. The percentage a range must meet to be considered dominant."
    echo "                Example: 85 (for 85%)"
    echo "                Defaults to: $DEFAULT_THRESHOLD"
    exit 1
}

# --- Argument Parsing ---
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

RANGES_ARG=${1:-$DEFAULT_RANGES}
THRESHOLD=${2:-$DEFAULT_THRESHOLD}

# Validate threshold input
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [ "$THRESHOLD" -lt 0 ] || [ "$THRESHOLD" -gt 100 ]; then
    echo "Error: Threshold must be an integer between 0 and 100." >&2
    usage
fi

# Pre-process the ranges string for awk.
# Turns "[0-3],[3-5],[9,+]" into "0-3 3-5 9,+"
AWK_RANGES=$(echo "$RANGES_ARG" | sed -e 's/^\[//' -e 's/\]$//' -e 's/\],\[/ /g')


# --- AWK Script Definition ---
# This AWK script does the heavy lifting of parsing the log values and categorizing them.
# It is defined here once and called for each container.
read -r -d '' AWK_SCRIPT << 'EOF'
BEGIN {
    # This block runs once before processing any log lines.
    # It parses the ranges passed from the bash script.
    num_ranges = split(ranges_str, range_arr, " ");
    for (i = 1; i <= num_ranges; i++) {
        range_str = range_arr[i];
        if (index(range_str, "+")) {
            # Handles infinity ranges like "9,+"
            split(range_str, bounds, ",");
            lower[i] = bounds[1];
            upper[i] = 1e30; # A very large number to represent infinity
            range_labels[i] = "[" bounds[1] "+]";
        } else {
            # Handles standard ranges like "0-3"
            split(range_str, bounds, "-");
            lower[i] = bounds[1];
            upper[i] = bounds[2];
            range_labels[i] = "[" bounds[1] "-" bounds[2] "]";
        }
        counts[i] = 0;
    }
    total = 0;
}
{
    # This block runs for each line of log input.
    # It converts nanoseconds to milliseconds and finds the correct range.
    ms = $1/1000000;
    total++;
    found_in_range = 0;
    for (i = 1; i <= num_ranges; i++) {
        # The first range is inclusive [min, max], subsequent ranges are (min, max]
        # This matches the behavior of the original one-liner.
        is_in_range = 0;
        if (i == 1 && ms >= lower[i] && ms <= upper[i]) {
            is_in_range = 1;
        } else if (i > 1 && ms > lower[i] && ms <= upper[i]) {
            is_in_range = 1;
        }

        if (is_in_range) {
            counts[i]++;
            found_in_range = 1;
            break; # Exit the loop once the correct range is found
        }
    }
    # If a value is larger than any defined range, it should be counted in the last range if it's an infinity range
    if (found_in_range == 0 && upper[num_ranges] > 1e29 && ms > lower[num_ranges]) {
      counts[num_ranges]++;
    }
}
END {
    # This block runs once after all log lines have been processed.
    # It prints the formatted summary and checks against the threshold.
    if (total > 0) {
        # Print the detailed summary of occurrences and percentages for each range.
        for (i = 1; i <= num_ranges; i++) {
            percentage = (counts[i] * 100) / total;
            printf "%s - %d - %.1f%%\n", range_labels[i], counts[i], percentage;
        }
        # To communicate with the bash script, print a special line if the threshold is met.
        for (i = 1; i <= num_ranges; i++) {
            percentage = (counts[i] * 100) / total;
            if (percentage >= threshold) {
                print "THRESHOLD_MET:" range_labels[i];
                exit; # Exit after finding the first dominant range
            }
        }
    }
}
EOF

# --- Main Logic ---
echo "Analyzing logs for all running containers..."
echo "Ranges: $RANGES_ARG"
echo "Threshold: $THRESHOLD%"
echo "----------------------------------------"

# Arrays to store results (more compatible than associative arrays)
declare -a processed_containers
declare -a containers_meeting_threshold
declare -a dominant_range_values

# Loop through all running containers
while read -r container_id_name; do
    container_id=$(echo "$container_id_name" | cut -d' ' -f1)
    container_name=$(echo "$container_id_name" | cut -d' ' -f2)

    # Grep logs and extract the nanosecond value. Suppress errors for containers without logs.
    log_data=$(docker logs "$container_id" 2>/dev/null | grep 'Reading file took:' | sed 's/.*: \(.*\)ns/\1/')

    # Skip containers with no relevant log entries
    if [ -z "$log_data" ]; then
        continue
    fi

    processed_containers+=("$container_name")

    # Pipe the log data into our AWK script for processing
    result=$(echo "$log_data" | awk -v ranges_str="$AWK_RANGES" -v threshold="$THRESHOLD" "$AWK_SCRIPT")

    # If awk produced output, print it and store the results
    if [ -n "$result" ]; then
        echo "Container: $container_name"
        # Print the summary but exclude our special "THRESHOLD_MET" line
        echo "$result" | grep -v "THRESHOLD_MET"
        echo "" # Add a blank line for readability

        # Check if a dominant range was found and store it
        dominant_range_line=$(echo "$result" | grep "THRESHOLD_MET")
        if [ -n "$dominant_range_line" ]; then
            dominant_range=$(echo "$dominant_range_line" | cut -d':' -f2-)
            containers_meeting_threshold+=("$container_name")
            dominant_range_values+=("$dominant_range")
        fi
    fi
done < <(docker ps --format "{{.ID}} {{.Names}}")


# --- Final Summary ---
echo "----------------------------------------"
echo "OVERALL SUMMARY"
echo "----------------------------------------"

if [ ${#processed_containers[@]} -eq 0 ]; then
    echo "No containers with 'Reading file took:' logs were found."
    exit 0
fi

# Check if all containers that had logs also met the threshold
if [ ${#containers_meeting_threshold[@]} -ne ${#processed_containers[@]} ]; then
    echo "🔴 FAILED: Not all processed containers met the ${THRESHOLD}% threshold in a single range."
    echo ""
    echo "Containers that DID meet the threshold:"
    for i in "${!containers_meeting_threshold[@]}"; do
        echo "  - ${containers_meeting_threshold[$i]} (in range ${dominant_range_values[$i]})"
    done
    echo ""
    echo "Containers that did NOT meet the threshold:"
    for name in "${processed_containers[@]}"; do
        is_met=false
        for met_name in "${containers_meeting_threshold[@]}"; do
            if [[ "$name" == "$met_name" ]]; then
                is_met=true
                break
            fi
        done
        if ! $is_met; then
            echo "  - $name"
        fi
    done
    exit 1
fi

# If we get here, all containers met the threshold. Now check if the range is the same for all.
first_range=""
is_consistent=true
for current_range in "${dominant_range_values[@]}"; do
    if [ -z "$first_range" ]; then
        first_range=$current_range
    elif [ "$first_range" != "$current_range" ]; then
        is_consistent=false
        break
    fi
done

if $is_consistent; then
    echo "✅ SUCCESS: All processed containers have over ${THRESHOLD}% of logs in the same range: $first_range"
else
    echo "🔴 FAILED: Containers met the threshold but in DIFFERENT ranges."
    echo ""
    for i in "${!containers_meeting_threshold[@]}"; do
        echo "  - ${containers_meeting_threshold[$i]} has dominant range: ${dominant_range_values[$i]}"
    done
    exit 1
fi

exit 0