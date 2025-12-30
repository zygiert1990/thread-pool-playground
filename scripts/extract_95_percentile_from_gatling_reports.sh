
#!/bin/bash

# Check if directory parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <root-directory>"
    exit 1
fi

ROOT_DIR="$1"

# Check if directory exists
if [ ! -d "$ROOT_DIR" ]; then
    echo "Error: Directory '$ROOT_DIR' does not exist"
    exit 1
fi

# Define output file path
OUTPUT_FILE="$ROOT_DIR/results-95-percentile.csv"

# Arrays to store labels and values
labels=()
values=()

# Process each subdirectory
for dir in "$ROOT_DIR"/*/; do
    # Extract label by removing timestamp suffix
    label=$(basename "$dir" | sed 's/_[0-9]\{8\}-[0-9]\{6\}$//')

    # Extract value from index.html
    value=$(awk '/Run computations/,/<td class="value total col-10">/ {if (/<td class="value total col-10">/) print}' \
            "$dir/gatling-results/index.html" 2>/dev/null | \
            sed 's/.*>\([0-9]*\)<.*/\1/')

    # Add to arrays if value is found
    if [ -n "$value" ]; then
        labels+=("$label")
        values+=("$value")
    fi
done

# Write to CSV file
{
    # Print CSV header (labels)
    IFS=','
    echo "${labels[*]}"

    # Print CSV values
    echo "${values[*]}"
} > "$OUTPUT_FILE"

echo "Results saved to: $OUTPUT_FILE"