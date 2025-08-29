
#!/bin/bash

# Default values
DEFAULT_RANGES="[0-3],[3-5],[5-7],[7-9],[9,+]"
DEFAULT_THRESHOLD=90

# Parse arguments
RANGES=${1:-$DEFAULT_RANGES}
THRESHOLD=${2:-$DEFAULT_THRESHOLD}

# Function to parse ranges - updated to handle the new [9,+] format
parse_ranges() {
    local ranges_str="$1"
    # Split by ],[ to get individual ranges, then clean up brackets
    echo "$ranges_str" | sed 's/\],\[/\n/g' | sed 's/^\[//; s/\]$//'
}

# Function to generate AWK conditions for ranges
generate_awk_conditions() {
    local ranges_str="$1"
    local conditions=""
    local range_names=""
    local counter=1

    while IFS= read -r range; do
        if [[ "$range" == *",+"* ]]; then
            # Handle infinity range like "9,+"
            local min=$(echo "$range" | sed 's/,+.*//')
            conditions+="else if(ms>=$min) r$counter++; "
            range_names+="[$range] "
        elif [[ "$range" == *"+"* ]]; then
            # Handle old infinity range format like "9+"
            local min=$(echo "$range" | sed 's/+.*//')
            conditions+="else if(ms>=$min) r$counter++; "
            range_names+="[$range] "
        else
            # Handle normal ranges like "0-3"
            local min=$(echo "$range" | cut -d'-' -f1)
            local max=$(echo "$range" | cut -d'-' -f2)
            if [ $counter -eq 1 ]; then
                conditions+="if(ms>=$min && ms<=$max) r$counter++; "
            else
                conditions+="else if(ms>=$min && ms<=$max) r$counter++; "
            fi
            range_names+="[$range] "
        fi
        ((counter++))
    done <<< "$(parse_ranges "$ranges_str")"

    echo "$conditions|$range_names|$counter"
}

# Function to generate AWK print statements
generate_awk_prints() {
    local range_names="$1"
    local counter="$2"
    local prints=""
    local i=1

    for range in $range_names; do
        prints+="print \"$range - \"(r$i+0)\" - \"sprintf(\"%.1f%%\", (r$i+0)*100/total); "
        ((i++))
    done

    echo "$prints"
}

# Function to analyze container
analyze_container() {
    local container="$1"
    local awk_script="$2"

    echo "Analyzing container: $container"

    # Get logs and check if they contain the pattern
    local logs=$(docker logs "$container" 2>&1 | grep "Reading file took:" 2>/dev/null)

    if [[ -z "$logs" ]]; then
        echo "  No matching logs found - skipping"
        echo ""
        return 1
    fi

    # Process logs with AWK
    echo "$logs" | sed 's/.*Reading file took: \([0-9]*\)ns.*/\1/' | awk "$awk_script"
    echo ""
    return 0
}

# Function to find dominant range for a container
find_dominant_range() {
    local container="$1"
    local awk_script="$2"
    local threshold="$3"

    local logs=$(docker logs "$container" 2>&1 | grep "Reading file took:" 2>/dev/null)

    if [[ -z "$logs" ]]; then
        return 1
    fi

    # Get percentages and find the dominant range
    local result=$(echo "$logs" | sed 's/.*Reading file took: \([0-9]*\)ns.*/\1/' | awk "$awk_script" | grep -o '[0-9.]*%' | sed 's/%//')
    local ranges_array=($(parse_ranges "$RANGES"))
    local i=0

    while IFS= read -r percentage; do
        if (( $(echo "$percentage >= $threshold" | bc -l) )); then
            echo "${ranges_array[$i]}"
            return 0
        fi
        ((i++))
    done <<< "$result"

    return 1
}

# Main script
echo "Docker Container Log Analysis"
echo "=============================="
echo "Ranges: $RANGES"
echo "Threshold: $THRESHOLD%"
echo ""

# Parse AWK script components
IFS='|' read -r conditions range_names counter <<< "$(generate_awk_conditions "$RANGES")"
prints=$(generate_awk_prints "$range_names" "$counter")

# Create AWK script
awk_script="{
    ms=\$1/1000000;
    total++;
    $conditions
}
END {
    if(total > 0) {
        $prints
    }
}"

# Get all running containers
containers=$(docker ps --format "{{.Names}}" 2>/dev/null)

if [[ -z "$containers" ]]; then
    echo "No running containers found."
    exit 1
fi

echo "INDIVIDUAL CONTAINER ANALYSIS:"
echo "=============================="

# Analyze each container
analyzed_containers=()
while IFS= read -r container; do
    if analyze_container "$container" "$awk_script"; then
        analyzed_containers+=("$container")
    fi
done <<< "$containers"

# Check if any containers were analyzed
if [ ${#analyzed_containers[@]} -eq 0 ]; then
    echo "No containers found with matching log patterns."
    exit 0
fi

echo ""
echo "THRESHOLD ANALYSIS:"
echo "=================="
echo "Checking if all containers have at least $THRESHOLD% in the same range..."
echo ""

# Find dominant ranges for each analyzed container
dominant_ranges=()
consistent_range=""
all_consistent=true

for container in "${analyzed_containers[@]}"; do
    dominant_range=$(find_dominant_range "$container" "$awk_script" "$THRESHOLD")

    if [[ -n "$dominant_range" ]]; then
        dominant_ranges+=("$container:$dominant_range")

        if [[ -z "$consistent_range" ]]; then
            consistent_range="$dominant_range"
        elif [[ "$consistent_range" != "$dominant_range" ]]; then
            all_consistent=false
        fi
    else
        echo "$container: No range reaches $THRESHOLD% threshold"
        all_consistent=false
    fi
done

# Display results
for entry in "${dominant_ranges[@]}"; do
    IFS=':' read -r cont range <<< "$entry"
    echo "$cont: Dominant range [$range] (≥$THRESHOLD%)"
done

echo ""
if [[ "$all_consistent" == true ]] && [[ -n "$consistent_range" ]]; then
    echo "✅ SUCCESS: All containers consistently perform in range [$consistent_range] at ≥$THRESHOLD%"
else
    echo "❌ INCONSISTENT: Containers do not have consistent performance in the same range at ≥$THRESHOLD%"
fi