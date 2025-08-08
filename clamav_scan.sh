#!/bin/bash

# https://docs.clamav.net/manual/Installing.html

set -euo pipefail
export LC_ALL=C.UTF-8

ROOT_DIR=$(pwd)
OUTPUT_DIR="output"
SCAN_DIR="$ROOT_DIR/$OUTPUT_DIR"
LOG_FILE="$SCAN_DIR/clamav_report.txt"

if [[ ! -d "$OUTPUT_DIR" ]]; then
	echo "[ERROR] output directory '$OUTPUT_DIR' not found in current working directory"
	exit 1
fi

rm -f "$LOG_FILE"

echo "[INFO] clamav scanning start"

find "$SCAN_DIR" -type f -name "*.gz" | while read -r file; do
	rel_path="${file#"$SCAN_DIR"/}"
	if [[ ! -s "$file" ]]; then
		echo "[WARN] skipping empty file: $rel_path"
		continue
	fi
	sha1=$(sha1sum "$file" | awk '{print $1}')
	echo "[INFO] scanning $rel_path	$sha1"
	result=$(clamscan --no-summary "$file")
	if echo "$result" | grep -q "FOUND"; then
		status="infected"
	else
		status="clean"
	fi
	printf "%s | %s | %s\n" "$sha1" "$status" "$rel_path" >>"$LOG_FILE"
done

infected_count=$(grep -c "infected" "$LOG_FILE" || true)
echo "[INFO] scan complete - $infected_count infected file(s) found"

exit 0
