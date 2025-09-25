#!/bin/sh
# container/scripts/clean-logs.sh
# Simple cleanup/rotation utility for container/*.out logs

set -e

LOGDIR="$(dirname "$0")/.."
LOGDIR="$(cd "$LOGDIR" && pwd)"

KEEP=${KEEP:-3}

echo "Cleaning container logs in $LOGDIR"

find "$LOGDIR" -maxdepth 1 -type f -name '*.out' -print0 | while IFS= read -r -d '' f; do
  echo "Processing: $f"
  # rotate: keep last $KEEP copies (move with timestamp)
  if [ -f "$f" ]; then
    ts=$(date +%Y%m%d-%H%M%S)
    mv "$f" "$f.$ts"
    echo "Rotated $f -> $f.$ts"
  fi
done

# prune older rotated logs, keep $KEEP
find "$LOGDIR" -maxdepth 1 -type f -name '*.out.*' | sort -r | awk "NR>$KEEP" | xargs -r rm -v || true

echo "Done. Kept last $KEEP rotated logs per file."
