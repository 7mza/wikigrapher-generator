#!/bin/bash
set -euo pipefail
export LC_ALL=C.UTF-8

ROOT_DIR=$(pwd)
DUMP_DIR="dump/en_11111111"
mkdir -p "$DUMP_DIR"
pushd "$DUMP_DIR" >/dev/null

echo "[INFO] generating dummy wikipedia dump in $ROOT_DIR/$DUMP_DIR/"

sed -n "/--##PAGES/,/--PAGES##/{//!p}" <"../../misc/example.sql" |
	grep -v '^\/\*' |
	sed ':a;N;$!ba;s/\n//g' |
	sed '0,/VALUES/{s/VALUES/VALUES /}' |
	pigz --best >enwiki-11111111-page.sql.gz

sed -n "/--##LINKS/,/--LINKS##/{//!p}" <"../../misc/example.sql" |
	grep -v '^\/\*' |
	sed ':a;N;$!ba;s/\n//g' |
	sed '0,/VALUES/{s/VALUES/VALUES /}' |
	pigz --best >enwiki-11111111-pagelinks.sql.gz

sed -n "/--##REDIRECTS/,/--REDIRECTS##/{//!p}" <"../../misc/example.sql" |
	grep -v '^\/\*' |
	sed ':a;N;$!ba;s/\n//g' |
	sed '0,/VALUES/{s/VALUES/VALUES /}' |
	pigz --best >enwiki-11111111-redirect.sql.gz

sed -n "/--##PAGEPROPS/,/--PAGEPROPS##/{//!p}" <"../../misc/example.sql" |
	grep -v '^\/\*' |
	sed ':a;N;$!ba;s/\n//g' |
	sed '0,/VALUES/{s/VALUES/VALUES /}' |
	pigz --best >enwiki-11111111-page_props.sql.gz

sed -n "/--##CATEGORIES/,/--CATEGORIES##/{//!p}" <"../../misc/example.sql" |
	grep -v '^\/\*' |
	sed ':a;N;$!ba;s/\n//g' |
	sed '0,/VALUES/{s/VALUES/VALUES /}' |
	pigz --best >enwiki-11111111-category.sql.gz

sed -n "/--##CATEGORYLINKS/,/--CATEGORYLINKS##/{//!p}" <"../../misc/example.sql" |
	grep -v '^\/\*' |
	sed ':a;N;$!ba;s/\n//g' |
	sed '0,/VALUES/{s/VALUES/VALUES /}' |
	pigz --best >enwiki-11111111-categorylinks.sql.gz

sed -n "/--##LINKTARGETS/,/--LINKTARGETS##/{//!p}" <"../../misc/example.sql" |
	grep -v '^\/\*' |
	sed ':a;N;$!ba;s/\n//g' |
	sed '0,/VALUES/{s/VALUES/VALUES /}' |
	pigz --best >enwiki-11111111-linktarget.sql.gz

: >enwiki-11111111-sha1sums.txt
: >enwiki-11111111-md5sums.txt

for file in *.gz; do
	if [ -f "$file" ]; then
		sha1sum "$file" >>enwiki-11111111-sha1sums.txt
		md5sum "$file" >>enwiki-11111111-md5sums.txt
	fi
done

exit 0
