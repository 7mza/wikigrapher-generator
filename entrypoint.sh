#!/bin/bash
set -euo pipefail
export LC_ALL=C.UTF-8

ARGS=()
[[ -n ${DUMP_DATE:-} ]] && ARGS+=(--date "$DUMP_DATE")
[[ -n ${DUMP_LANG:-} ]] && ARGS+=(--lang "$DUMP_LANG")

./clean.sh && ./generate_tsv.sh "${ARGS[@]}"

exit 0
