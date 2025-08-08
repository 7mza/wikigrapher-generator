#!/bin/bash
set -euo pipefail
export LC_ALL=C.UTF-8

ROOT_DIR=$(pwd)
DUMP_DIR="dump/en_11111111"
OUTPUT_DIR="output"

echo "[WARN] cleaning workspace"

if [[ -d "$ROOT_DIR/$DUMP_DIR" ]]; then
	find "$ROOT_DIR/$DUMP_DIR" -type f -delete
fi

if [[ -d "$ROOT_DIR/$OUTPUT_DIR" ]]; then
	find "$ROOT_DIR/$OUTPUT_DIR" -type f ! -name ".gitkeep" -delete
fi

exit 0
