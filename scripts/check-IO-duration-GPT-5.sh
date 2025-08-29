#!/usr/bin/env bash
set -euo pipefail

# analyze_read_times.sh
# macOS Bash 3.2 compatible (no mapfile / assoc arrays).
# Buckets "Reading file took: <ns>ns" per-container into ms ranges and checks global consistency.

export LC_ALL=C

RANGES_INPUT="${1:-"[0-3],[3-5],[5-7],[7-9],[9,+]"}"
THRESHOLD="${2:-90}"

# Validate threshold (integer or float)
case "$THRESHOLD" in
  ''|*[!0-9.]*) echo "Error: Threshold must be a number (integer/float), got: $THRESHOLD" >&2; exit 1;;
esac

trim() { sed -E 's/^[[:space:]]+|[[:space:]]+$//g'; }

# Parse ranges into 3 pipe-delimited strings for awk: labels|labels..., lows|..., highs|...
RANGE_LABELS_STR=""
RANGE_LO_MS_STR=""
RANGE_HI_MS_STR=""

parse_ranges() {
  local input="$1"
  input="$(printf '%s' "$input" | tr -d $'\n' | trim)"
  local token
  local first=1
  # Extract every [...] group without relying on commas
  while IFS= read -r token; do
    token="$(printf '%s' "$token" | tr -d ' ')"

    if [[ "$token" =~ ^\[[0-9]+-[0-9]+\]$ ]]; then
      local low="${token#[}"; low="${low%-*}"
      local high="${token#*-}"; high="${high%]}"
      if (( low >= high )); then
        echo "Error: Invalid range '$token' (low must be < high)" >&2
        exit 1
      fi
      if (( first )); then
        RANGE_LABELS_STR="[$low-$high]"
        RANGE_LO_MS_STR="$low"
        RANGE_HI_MS_STR="$high"
        first=0
      else
        RANGE_LABELS_STR="$RANGE_LABELS_STR|[$low-$high]"
        RANGE_LO_MS_STR="$RANGE_LO_MS_STR|$low"
        RANGE_HI_MS_STR="$RANGE_HI_MS_STR|$high"
      fi

    elif [[ "$token" =~ ^\[[0-9]+,\+\]$ ]]; then
      local low="${token#[}"; low="${low%,+]}"
      if (( first )); then
        RANGE_LABELS_STR="[$low,+]"
        RANGE_LO_MS_STR="$low"
        RANGE_HI_MS_STR="+"
        first=0
      else
        RANGE_LABELS_STR="$RANGE_LABELS_STR|[$low,+]"
        RANGE_LO_MS_STR="$RANGE_LO_MS_STR|$low"
        RANGE_HI_MS_STR="$RANGE_HI_MS_STR|+"
      fi

    else
      echo "Error: Invalid range format '$token'. Expected [a-b] or [a,+]" >&2
      exit 1
    fi
  done < <(printf '%s' "$input" | grep -oE '\[[^]]+\]')

  if [[ -z "$RANGE_LABELS_STR" ]]; then
    echo "Error: No valid ranges parsed from: $input" >&2
    exit 1
  fi
}

parse_ranges "$RANGES_INPUT"

# Function to list running container names
read_containers() {
  docker ps --format '{{.Names}}'
}

# Arrays (indexed) for included containers and their dominant results
INCLUDED_CONTAINERS=()
DOM_LABELS=()
DOM_PCTS=()

# Iterate containers
while IFS= read -r cname; do
  [[ -z "$cname" ]] && continue

  # Extract just the numeric ns values first to avoid regex parsing in awk.
  # We only pass clean numbers to awk.
  ns_stream="$(
    docker logs "$cname" 2>&1 \
      | grep -E 'Reading file took:' \
      | sed -nE 's/.*Reading file took:[[:space:]]*([0-9]+)ns.*/\1/p' \
      | grep -E '^[0-9]+$' || true
  )"

  # Skip containers without relevant logs
  if [[ -z "$ns_stream" ]]; then
    continue
  fi

  # Process numbers with awk for bucketing
  out="$(
    printf '%s\n' "$ns_stream" \
      | awk -v labels="$RANGE_LABELS_STR" -v lows_ms="$RANGE_LO_MS_STR" -v highs_ms="$RANGE_HI_MS_STR" '
        BEGIN {
          n = split(labels, LBL, /\|/)
          split(lows_ms, LO_MS, /\|/)
          split(highs_ms, HI_MS, /\|/)
          for (i=1;i<=n;i++){
            LO_NS[i] = LO_MS[i] * 1000000
            if (HI_MS[i] == "+") HI_NS[i] = -1
            else HI_NS[i] = HI_MS[i] * 1000000
            CNT[i]=0
          }
          total=0
        }
        {
          ns = $1 + 0
          total++
          for (i=1;i<=n;i++){
            if (HI_NS[i] == -1) {
              if (ns >= LO_NS[i]) { CNT[i]++; break }
            } else {
              if (ns >= LO_NS[i] && ns < HI_NS[i]) { CNT[i]++; break }
            }
          }
        }
        END {
          if (total == 0) exit 2
          dom_i=1; dom_pct=0
          for (i=1;i<=n;i++){
            pct = (100.0*CNT[i]/total)
            printf("%s\t%d\t%.2f\n", LBL[i], CNT[i], pct)
            if (pct > dom_pct) { dom_pct=pct; dom_i=i }
          }
          printf("--DOM--\t%s\t%.2f\n", LBL[dom_i], dom_pct)
        }
      ' || true
  )"

  if [[ -z "$out" ]]; then
    continue
  fi

  echo "$cname:"
  dom_label=""
  dom_pct=""
  while IFS=$'\t' read -r col1 col2 col3; do
    [[ -z "${col1-}" ]] && continue
    if [[ "$col1" == "--DOM--" ]]; then
      dom_label="$col2"
      dom_pct="$col3"
    else
      printf "%s - %s - %s%%\n" "$col1" "$col2" "$col3"
    fi
  done <<< "$out"
  echo

  if [[ -n "$dom_label" ]]; then
    INCLUDED_CONTAINERS+=("$cname")
    DOM_LABELS+=("$dom_label")
    DOM_PCTS+=("$dom_pct")
  fi
done < <(read_containers)

# If none included, finish
if [[ ${#INCLUDED_CONTAINERS[@]} -eq 0 ]]; then
  echo "No containers with matching 'Reading file took: <ns>ns' log entries were found."
  exit 0
fi

# Global consistency check
echo "Global check (threshold: ${THRESHOLD}%):"
qualified_labels=()
all_ok=1
for i in "${!INCLUDED_CONTAINERS[@]}"; do
  cname="${INCLUDED_CONTAINERS[$i]}"
  lbl="${DOM_LABELS[$i]}"
  pct="${DOM_PCTS[$i]}"
  if awk -v p="$pct" -v t="$THRESHOLD" 'BEGIN{exit !(p+0 >= t+0)}'; then
    echo "- $cname: OK (dominant ${lbl} at ${pct}%)"
    qualified_labels+=("$lbl")
  else
    echo "- $cname: FAIL (dominant ${lbl} at ${pct}%)"
    all_ok=0
  fi
done

if [[ $all_ok -ne 1 ]]; then
  echo "Result: NOT CONSISTENT (some containers did not reach the threshold)."
  exit 0
fi

# Check if all qualified have the same dominant label
consistent=1
first_label=""
for ql in "${qualified_labels[@]}"; do
  if [[ -z "$first_label" ]]; then
    first_label="$ql"
  elif [[ "$ql" != "$first_label" ]]; then
    consistent=0
    break
  fi
done

if [[ $consistent -eq 1 ]]; then
  echo "Result: CONSISTENT (all containers have >= ${THRESHOLD}% in the same range ${first_label})."
else
  echo "Result: NOT CONSISTENT (containers' dominant ranges differ)."
  echo "Details:"
  for i in "${!INCLUDED_CONTAINERS[@]}"; do
    echo "  - ${INCLUDED_CONTAINERS[$i]}: ${DOM_LABELS[$i]} at ${DOM_PCTS[$i]}%"
  done
fi