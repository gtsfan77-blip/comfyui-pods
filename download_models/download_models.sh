#!/usr/bin/env bash

set -euo pipefail

# =========================
# Generic DIR|URL|FILENAME Downloader
#
# Usage:
#   ./download_models.sh models.list
#   ./download_models.sh   (defaults to models.list)
#
# Format:
#   DIR|URL
#   DIR|URL|FILENAME
#
# Auth:
#   export CIVITAI_TOKEN="xxx"
#   export HF_TOKEN="xxx"
# =========================

BASE_DIR="/models"
INPUT_FILE="${1:-models.list}"
MAX_PARALLEL=4
LOG_FILE="./download.log"

# Initialize log
echo "==== Download session $(date '+%Y-%m-%d %H:%M:%S') ====" >>"$LOG_FILE"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file '$INPUT_FILE' not found!"
  exit 1
fi

echo "Using input file: $INPUT_FILE"
echo "Base directory: $BASE_DIR"
echo "Max parallel downloads: $MAX_PARALLEL"
echo "Log file: $LOG_FILE"
echo

download() {
  local DIR="$1"
  local URL="$2"
  local CUSTOM_NAME="${3:-}"

  local TARGET_DIR="$BASE_DIR/$DIR"
  mkdir -p "$TARGET_DIR"

  # Determine filename
  local FILENAME
  if [[ -n "$CUSTOM_NAME" ]]; then
    FILENAME="$CUSTOM_NAME"
  else
    FILENAME=$(basename "${URL%%\?*}")
  fi

  local TARGET_FILE="$TARGET_DIR/$FILENAME"

  # Skip existing
  if [ -f "$TARGET_FILE" ]; then
    echo "✔ Skipping: $FILENAME"
    return
  fi

  printf "⬇ %-60s ..." "$FILENAME"

  # Base curl options
  local CURL_OPTS
  CURL_OPTS=(-L --fail --retry 3 --retry-delay 5 -o "$TARGET_FILE" -s)

  # Detect provider and apply auth
  if [[ "$URL" == *"civitai.com"* ]]; then
    if [[ -z "${CIVITAI_TOKEN:-}" ]]; then
      echo " ❌ Missing CIVITAI_TOKEN"
      return
    fi
    CURL_OPTS+=(-H "Authorization: Bearer $CIVITAI_TOKEN")

  elif [[ "$URL" == *"huggingface.co"* ]]; then
    if [[ -z "${HF_TOKEN:-}" ]]; then
      echo " ❌ Missing HF_TOKEN"
      return
    fi
    CURL_OPTS+=(-H "Authorization: Bearer $HF_TOKEN")
  fi

  # Log start
  {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] START $FILENAME"
    echo "URL: $URL"
  } >>"$LOG_FILE"

  # Execute download
  if curl "${CURL_OPTS[@]}" "$URL" >>"$LOG_FILE" 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DONE $FILENAME" >>"$LOG_FILE"
    echo " ✅"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR $FILENAME" >>"$LOG_FILE"
    echo " ❌ (see download.log)"
  fi
}

# Read input file
while IFS='|' read -r DIR URL CUSTOM_NAME; do
  [[ -z "${DIR:-}" ]] && continue
  [[ "$DIR" =~ ^# ]] && continue

  download "$DIR" "$URL" "$CUSTOM_NAME" &

  # Limit parallel jobs
  while [ "$(jobs -r | wc -l)" -ge "$MAX_PARALLEL" ]; do
    sleep 1
  done

done <"$INPUT_FILE"

wait

echo
echo "All downloads completed!"
