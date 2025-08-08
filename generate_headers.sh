#!/bin/bash
set -euo pipefail
export LC_ALL=C.UTF-8

ROOT_DIR=$(pwd)
OUTPUT_DIR="output"
mkdir -p "$OUTPUT_DIR"
pushd "$OUTPUT_DIR" >/dev/null
SEPARATOR="\t"

echo "[INFO] generating tsv headers in $ROOT_DIR/$OUTPUT_DIR/"

echo -e "pageId:ID(page-ID)${SEPARATOR}title${SEPARATOR}:LABEL" |
	pigz --best >pages.header.tsv.gz

echo -e "categoryId:ID(category-ID)${SEPARATOR}title${SEPARATOR}:LABEL" |
	pigz --best >categories.header.tsv.gz

echo -e "metaId:ID(meta-ID)${SEPARATOR}property${SEPARATOR}value${SEPARATOR}:LABEL" |
	pigz --best >meta.header.tsv.gz

echo -e "sourceId:START_ID(page-ID)${SEPARATOR}:TYPE${SEPARATOR}targetId:END_ID(page-ID)" |
	pigz --best >link_to.header.tsv.gz

echo -e "sourceId:START_ID(page-ID)${SEPARATOR}:TYPE${SEPARATOR}targetId:END_ID(page-ID)" |
	pigz --best >redirect_to.header.tsv.gz

echo -e "sourceId:START_ID(page-ID)${SEPARATOR}:TYPE${SEPARATOR}targetId:END_ID(category-ID)" |
	pigz --best >belong_to.header.tsv.gz

echo -e "sourceId:START_ID(category-ID)${SEPARATOR}:TYPE${SEPARATOR}targetId:END_ID(page-ID)" |
	pigz --best >contains.header.tsv.gz

echo "[INFO] done"

exit 0
