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

# Arrays to store labels and avg values
labels=()
avg_values=()

# Process each subdirectory
for dir in "$ROOT_DIR"/*/; do
    latency_file="$dir/network-latency.txt"
    
    if [ -f "$latency_file" ]; then
        # Extract label
        label=$(basename "$dir" | sed 's/_[0-9]\{8\}-[0-9]\{6\}$//')
        
        # Extract avg value from the file (macOS compatible)
        avg=$(sed -n 's/.*rtt min\/avg\/max\/mdev = [0-9.]*\/\([0-9.]*\)\/.*/\1/p' "$latency_file")
        
        if [ -n "$avg" ]; then
            labels+=("$label")
            avg_values+=("$avg")
            echo "$label: avg = $avg ms"
        fi
    fi
done

# Check if we have any values
if [ ${#avg_values[@]} -eq 0 ]; then
    echo "No network latency data found"
    exit 0
fi

# Find min and max values with their labels
min=${avg_values[0]}
max=${avg_values[0]}
min_label=${labels[0]}
max_label=${labels[0]}
sum=0

for i in "${!avg_values[@]}"; do
    val=${avg_values[$i]}
    lbl=${labels[$i]}
    
    if (( $(echo "$val < $min" | bc -l) )); then
        min=$val
        min_label=$lbl
    fi
    if (( $(echo "$val > $max" | bc -l) )); then
        max=$val
        max_label=$lbl
    fi
    
    sum=$(echo "$sum + $val" | bc -l)
done

# Calculate mean
mean=$(echo "scale=3; $sum / ${#avg_values[@]}" | bc -l)

# Calculate difference
diff=$(echo "$max - $min" | bc -l)

echo ""
echo "Summary:"
echo "Min avg latency: $min ms ($min_label)"
echo "Max avg latency: $max ms ($max_label)"
echo "Mean avg latency: $mean ms"
echo "Difference: $diff ms"
echo ""

# Check if difference is within acceptable range
THRESHOLD=2.0

if (( $(echo "$diff > $THRESHOLD" | bc -l) )); then
    echo "⚠️  WARNING: Latency difference exceeds ${THRESHOLD}ms threshold!"
    exit 1
else
    echo "✓ Latency values are within acceptable range (≤${THRESHOLD}ms difference)"
    exit 0
fi