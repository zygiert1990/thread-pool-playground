#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-root}"       # default root directory
TOLERANCE_PCT="${2:-0.05}"  # e.g. 0.05 for 5%

run_table_for_dir() {
  local DIR="$1"
  local LABEL="$2"
  local TOL="$3"

  # Check quickly if there are any matching CSV files; if not, skip
  if ! find "$DIR" -type f -name 'results-95-percentile.csv' -print -quit | grep -q .; then
    return 0
  fi

  local tmpfile
  tmpfile="$(mktemp)"
  # Will be removed by caller or at process exit if we trap; here we just cleanup locally
  # but let caller rm -f just in case.

  # 1) Aggregate scores across all CSVs into a temp CSV-like structure
  find "$DIR" -type f -name 'results-95-percentile.csv' -print0 | \
    xargs -0 awk -v tol="$TOL" '
  BEGIN {
    FS = ",";
    OFS = ",";
    initialized = 0;
    fileCount = 0;
  }

  # Line 1 of each file: header
  FNR == 1 {
    if (!initialized) {
      ncols = NF;
      for (i = 1; i <= NF; i++) {
        header[i] = $i;
      }
      initialized = 1;
    }
    next;
  }

  # Line 2 of each file: single data row
  FNR == 2 {
    # Read values
    for (i = 1; i <= ncols; i++) {
      val[i] = $i + 0.0;
    }

    # Compute minimum (best)
    min = val[1];
    for (i = 2; i <= ncols; i++) {
      if (val[i] < min) {
        min = val[i];
      }
    }

    # Compute scores and accumulate
    for (i = 1; i <= ncols; i++) {
      if (min <= 0) {
        slowdown = (val[i] + 1.0);
      } else {
        slowdown = val[i] / min;
      }

      # Within tolerance of best → treat as best
      if (slowdown <= 1.0 + tol) {
        effSlowdown = 1.0;
      } else {
        effSlowdown = slowdown;
      }

      score = 100.0 / effSlowdown;

      colName = header[i];
      total[colName] += score;
    }

    fileCount++;
    next;
  }

  END {
    if (fileCount == 0) {
      # No files in this group; produce no data
      exit 0;
    }

    maxPerColumn = 100 * fileCount;

    # Output: Column,TotalScore,MaxPossible,PercentageNumeric
    for (i = 1; i <= ncols; i++) {
      col = header[i];
      totalScore = (col in total ? total[col] : 0);
      perc = (totalScore / maxPerColumn) * 100.0;
      printf "%s,%.2f,%d,%.6f\n", col, totalScore, maxPerColumn, perc;
    }
  }
  ' > "$tmpfile"

  if [ ! -s "$tmpfile" ]; then
    rm -f "$tmpfile"
    return 0
  fi

  echo
  echo "=== $LABEL ==="
  # Header
  printf "%-20s %12s %12s %10s\n" "Column" "TotalScore" "MaxPossible" "Percent"
  printf "%-20s %12s %12s %10s\n" "--------------------" "------------" "------------" "----------"

  # Rows sorted by percentage (4th field) descending
  sort -t',' -k4,4nr "$tmpfile" | awk -F',' '
  {
    col = $1;
    totalScore = $2 + 0.0;
    maxPossible = $3;
    perc = $4 + 0.0;

    printf "%-20s %12.2f %12s %9.2f%%\n", col, totalScore, maxPossible, perc;
  }
  '

  rm -f "$tmpfile"
}

# --- Main ---

# 1) Per first-level subdirectory of ROOT_DIR
for d in "$ROOT_DIR"/*; do
  if [ -d "$d" ]; then
    name="$(basename "$d")"
    run_table_for_dir "$d" "$name" "$TOLERANCE_PCT"
  fi
done

# 2) Overall (all CSVs under ROOT_DIR)
run_table_for_dir "$ROOT_DIR" "OVERALL" "$TOLERANCE_PCT"