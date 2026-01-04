#!/bin/bash

# Usage:
#   ./latency-all.sh [parent-of-parents-directory]
#
# If no directory is given, it uses the current directory as the parent-of-parents.

# Resolve top-level directory
if [ -n "$1" ]; then
    TOP_DIR="$1"
else
    TOP_DIR="."
fi

# Check if directory exists
if [ ! -d "$TOP_DIR" ]; then
    echo "Error: Directory '$TOP_DIR' does not exist"
    exit 1
fi

# Arrays to store labels and avg values
labels=()
avg_values=()

# Walk: parent-of-parents -> root-parent -> root -> child
for root_parent in "$TOP_DIR"/*/; do
    [ -d "$root_parent" ] || continue
    root_parent_name=$(basename "$root_parent")

    for root in "$root_parent"*/; do
        [ -d "$root" ] || continue
        root_name=$(basename "$root")

        for child in "$root"*/; do
            [ -d "$child" ] || continue

            latency_file="$child/network-latency.txt"
            if [ -f "$latency_file" ]; then
                # Child label, same stripping rule as your original script
                child_raw_label=$(basename "$child")
                child_label=$(echo "$child_raw_label" | sed 's/_[0-9]\{8\}-[0-9]\{6\}$//')

                # Full label includes all levels so it's unique
                label="${root_parent_name}/${root_name}/${child_label}"

                # Extract avg value (macOS compatible, same as before)
                avg=$(sed -n 's/.*rtt min\/avg\/max\/mdev = [0-9.]*\/\([0-9.]*\)\/.*/\1/p' "$latency_file")

                if [ -n "$avg" ]; then
                    labels+=("$label")
                    avg_values+=("$avg")
                    echo "$label: avg = $avg ms"
                fi
            fi
        done
    done
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
echo "Summary (across all parents, roots, and children):"
echo "Min avg latency: $min ms ($min_label)"
echo "Max avg latency: $max ms ($max_label)"
echo "Mean avg latency: $mean ms"
echo "Difference: $diff ms"
echo ""

# Threshold logic (same as your current script)
THRESHOLD=2.0

if (( $(echo "$diff > $THRESHOLD" | bc -l) )); then
    echo "⚠️  WARNING: Latency difference exceeds ${THRESHOLD}ms threshold!"
    exit 1
else
    echo "✓ Latency values are within acceptable range (≤${THRESHOLD}ms difference)"
    exit 0
fi