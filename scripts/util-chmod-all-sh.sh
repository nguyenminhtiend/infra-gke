#!/usr/bin/env bash
set -euo pipefail

# Make all .sh scripts under scripts/ executable

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SCRIPTS_DIR="$ROOT_DIR/scripts"

if [[ ! -d "$SCRIPTS_DIR" ]]; then
  echo "Scripts directory not found: $SCRIPTS_DIR" >&2
  exit 1
fi

echo "Marking all .sh files in $SCRIPTS_DIR as executable..."
files_list=$(find "$SCRIPTS_DIR" -type f -name "*.sh")

if [[ -z "$files_list" ]]; then
  echo "No .sh files found under $SCRIPTS_DIR"
  exit 0
fi

count=0
while IFS= read -r f; do
  chmod +x "$f"
  printf "  %s\n" "$f"
  count=$((count+1))
done <<< "$files_list"

echo "Updated permissions for ${count} file(s)."

echo "Done."
