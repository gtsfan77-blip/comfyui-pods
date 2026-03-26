#!/usr/bin/env bash

set -euo pipefail

# =========================
# Generic DIR|URL|FILENAME Downloader
# Usage:
#   ./download_models.sh models.list
#   ./download_models.sh myfile.txt
#   ./download_models.sh   (defaults to models.list)
#
# File format:
#   DIR|URL
#   DIR|URL|FILENAME
# =========================

BASE_DIR="/models"
INPUT_FILE="${1:-models.list}"
MAX_PARALLEL=4

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file '$INPUT_FILE' not found!"
  exit 1
fi

echo "Using input file: $INPUT_FILE"
echo "Base directory: $BASE_DIR"
echo "Max parallel downloads: $MAX_PARALLEL"
echo

while IFS='|' read -r DIR URL CUSTOM_NAME; do
  # Skip empty lines or comments
  [[ -z "${DIR:-}" ]] && continue
  [[ "$DIR" =~ ^# ]] && continue

  TARGET_DIR="$BASE_DIR/$DIR"
  mkdir -p "$TARGET_DIR"

  # Determine filename
  if [[ -n "${CUSTOM_NAME:-}" ]]; then
    FILENAME="$CUSTOM_NAME"
  else
    # Extract filename from URL (remove query string)
    FILENAME=$(basename "${URL%%\?*}")
  fi

  TARGET_FILE="$TARGET_DIR/$FILENAME"

  # Skip if file already exists
  if [ -f "$TARGET_FILE" ]; then
    echo "✔ Skipping (exists): $TARGET_FILE"
    continue
  fi

  echo "⬇ Downloading → $TARGET_FILE"
  wget -c -O "$TARGET_FILE" "$URL" &

  # Limit parallel jobs
  while [ "$(jobs -r | wc -l)" -ge "$MAX_PARALLEL" ]; do
    sleep 1
  done

done <"$INPUT_FILE"

wait

echo
echo "All downloads completed successfully!"
