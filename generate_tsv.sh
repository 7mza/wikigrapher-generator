#!/bin/bash
set -euo pipefail
export LC_ALL=C.UTF-8

TOTAL_CORES=$(nproc)
PARALLEL_CORES=$((TOTAL_CORES * 80 / 100))
echo "[INFO] TOTAL_CORES: $TOTAL_CORES, USING: $PARALLEL_CORES"

echo "[INFO] start: $(date +"%a %b %d %T %Y")"

./generate_headers.sh

DOWNLOAD_DATE=""
DUMP_LANG=""

while (("$#")); do
	case "$1" in
	--date)
		if [[ -z $2 ]] || [[ ${#2} -ne 8 ]]; then # YYYYMMDD
			echo "[ERROR] Invalid download date provided: $2"
			exit 1
		else
			DOWNLOAD_DATE="$2"
			shift 2
		fi
		;;
	--lang)
		LOWER_LANG=$(echo "$2" | tr '[:upper:]' '[:lower:]')
		case "$LOWER_LANG" in
		en | ar | fr)
			DUMP_LANG="$LOWER_LANG"
			shift 2
			;;
		*)
			if [[ ! $DOWNLOAD_DATE == "11111111" ]]; then
				echo "[ERROR] Unsupported lang provided: $2"
				exit 1
			fi
			shift 2
			;;
		esac
		;;
	*)
		PARAMS="$PARAMS $1"
		shift
		;;
	esac
done

if [[ -z $DUMP_LANG ]]; then
	DUMP_LANG="en"
fi

if [[ -z $DOWNLOAD_DATE ]]; then
	DOWNLOAD_DATE=$(wget -q -O- "https://dumps.wikimedia.org/${DUMP_LANG}wiki" | grep -Po '\d{8}' | sort | tail -n1)
fi

if [[ $DOWNLOAD_DATE == "11111111" ]]; then
	DUMP_LANG="en"
	./generate_dummy_dump.sh
fi

ROOT_DIR=$(pwd)
DUMP_DIR="dump/${DUMP_LANG}_${DOWNLOAD_DATE}"

DOWNLOAD_URL="https://dumps.wikimedia.org/${DUMP_LANG}wiki/$DOWNLOAD_DATE"

SHA1SUM_FILENAME="${DUMP_LANG}wiki-$DOWNLOAD_DATE-sha1sums.txt"
MD5SUM_FILENAME="${DUMP_LANG}wiki-$DOWNLOAD_DATE-md5sums.txt"
REDIRECTS_DUMP_FILENAME="${DUMP_LANG}wiki-$DOWNLOAD_DATE-redirect.sql.gz"
PAGES_DUMP_FILENAME="${DUMP_LANG}wiki-$DOWNLOAD_DATE-page.sql.gz"
PAGELINKS_DUMP_FILENAME="${DUMP_LANG}wiki-$DOWNLOAD_DATE-pagelinks.sql.gz"
PAGEPROPS_DUMP_FILENAME="${DUMP_LANG}wiki-$DOWNLOAD_DATE-page_props.sql.gz"
CATEGORIES_DUMP_FILENAME="${DUMP_LANG}wiki-$DOWNLOAD_DATE-category.sql.gz"
CATEGORYLINKS_DUMP_FILENAME="${DUMP_LANG}wiki-$DOWNLOAD_DATE-categorylinks.sql.gz"
LINKTARGETS_DUMP_FILENAME="${DUMP_LANG}wiki-$DOWNLOAD_DATE-linktarget.sql.gz"
#TEMPLATELINKS_DUMP_FILENAME="${DUMP_LANG}wiki-$DOWNLOAD_DATE-templatelinks.sql.gz"

mkdir -p "$DUMP_DIR"
pushd "$DUMP_DIR" >/dev/null

echo "[INFO] dump lang: $DUMP_LANG"
echo "[INFO] download date: $DOWNLOAD_DATE"
echo "[INFO] download URL: $DOWNLOAD_URL"
echo "[INFO] output directory: $DUMP_DIR"

function download_file() {
	if [[ ! -f "$2" ]]; then
		# dont' use aria2 for small sum file
		if [[ "$1" != sha1sums ]] && [[ "$1" != md5sums ]] && command -v aria2c >/dev/null; then
			echo "[INFO] downloading $1 file via aria2c"
			if ! aria2c --console-log-level=error -c -x 3 -s 32 -k 10M \
				"$DOWNLOAD_URL/$2"; then
				echo "[ERROR] failed to download $1 file via aria2c"
				return 1
			fi
		else
			echo "[INFO] downloading $1 file via wget"
			if ! wget --progress=dot:giga "$DOWNLOAD_URL/$2"; then
				echo "[ERROR] failed to download $1 file via wget"
				return 1
			fi
		fi
		if [[ "$1" != sha1sums ]] && [[ "$1" != md5sums ]]; then
			echo "[INFO] verifying checksum for $1"
			local verified=0
			if grep -q "$2" "$SHA1SUM_FILENAME"; then
				grep "$2" "$SHA1SUM_FILENAME" | sha1sum -c && verified=1
			fi
			if [[ $verified -eq 0 ]] && grep -q "$2" "$MD5SUM_FILENAME"; then
				grep "$2" "$MD5SUM_FILENAME" | md5sum -c && verified=1
			fi
			if [[ $verified -eq 0 ]]; then
				echo "[ERROR] checksum verification failed for $1"
				rm -f "$2"
				return 1
			fi
		fi
	else
		echo "[WARN] already downloaded $1 file"
	fi
}

if [[ $DOWNLOAD_DATE != "11111111" ]]; then
	# always get sums files from server
	rm -f "$SHA1SUM_FILENAME" "$MD5SUM_FILENAME"
fi

download_file "sha1sums" "$SHA1SUM_FILENAME"
download_file "md5sums" "$MD5SUM_FILENAME"
download_file "redirects" "$REDIRECTS_DUMP_FILENAME"
download_file "pages" "$PAGES_DUMP_FILENAME"
download_file "pagelinks" "$PAGELINKS_DUMP_FILENAME"
download_file "pageprops" "$PAGEPROPS_DUMP_FILENAME"
download_file "categories" "$CATEGORIES_DUMP_FILENAME"
download_file "categorylinks" "$CATEGORYLINKS_DUMP_FILENAME"
download_file "linktargets" "$LINKTARGETS_DUMP_FILENAME"
#download_file "templatelinks" "$TEMPLATELINKS_DUMP_FILENAME"

(
	set +e +o pipefail
	for file in *.sql.gz; do pigz -dc "$file" | head -n100 | awk 'BEGIN{RS="INSERT"} NR==1'; done >DDL.sql
	echo "[INFO] DDL generated in $DUMP_DIR/DDL.sql"
)

REDIRECTS_TRIM_FILENAME="redirects_trim.tsv.gz"

if [[ ! -f $REDIRECTS_TRIM_FILENAME ]]; then
	echo "[INFO] REDIRECTS: trimming file"
	pigz -dc "$REDIRECTS_DUMP_FILENAME" |
		sed -n "s/^INSERT INTO \`redirect\` VALUES (//p" |
		sed -e "s/),(/\\n/g" |
		grep -E "^[0-9]+,0," |
		sed -e "s/,0,'/\\t/" |
		sed -e "s/',.*$//" | # FIXME: 'zebi',zebi'
		pigz --fast >"$REDIRECTS_TRIM_FILENAME".tmp
	mv "$REDIRECTS_TRIM_FILENAME".tmp "$REDIRECTS_TRIM_FILENAME"
else
	echo "[WARN] REDIRECTS: already trimmed file"
fi

PAGES_TRIM_FILENAME="pages_trim.tsv.gz"

if [[ ! -f "$PAGES_TRIM_FILENAME" ]]; then
	echo "[INFO] PAGES: trimming file"
	pigz -dc "$PAGES_DUMP_FILENAME" |
		sed -n "s/^INSERT INTO \`page\` VALUES (//p" |
		sed -e "s/),(/\\n/g" |
		grep -E "^[0-9]+,0," |
		sed -e "s/,0,'/\\t/" |
		sed -e "s/',\([01]\),.*$/\t\1/" | # FIXME: 'zebi',zebi'
		pigz --fast >"$PAGES_TRIM_FILENAME".tmp
	mv "$PAGES_TRIM_FILENAME".tmp "$PAGES_TRIM_FILENAME"
else
	echo "[WARN] PAGES: already trimmed file"
fi

PAGELINKS_TRIM_FILENAME="pagelinks_trim.tsv.gz"

if [[ ! -f "$PAGELINKS_TRIM_FILENAME" ]]; then
	echo "[INFO] PAGELINKS: trimming file"
	pigz -dc "$PAGELINKS_DUMP_FILENAME" |
		sed -n "s/^INSERT INTO \`pagelinks\` VALUES (//p" |
		sed -e "s/),(/\\n/g" |
		grep -E "^[0-9]+,0," |
		sed -e "s/,0,/\\t/" |
		sed -e "s/);*$//" |
		pigz --fast >"$PAGELINKS_TRIM_FILENAME".tmp
	mv "$PAGELINKS_TRIM_FILENAME".tmp "$PAGELINKS_TRIM_FILENAME"
else
	echo "[WARN] PAGELINKS: already trimmed file"
fi

# TEMPLATELINKS_TRIM_FILENAME="templatelinks_trim.tsv.gz"

# if [[ ! -f "$TEMPLATELINKS_TRIM_FILENAME" ]]; then
# 	echo "[INFO] TEMPLATELINKS: trimming file"
# 	pigz -dc "$TEMPLATELINKS_DUMP_FILENAME" |
# 		sed -n "s/^INSERT INTO \`templatelinks\` VALUES (//p" |
# 		sed -e "s/),(/\\n/g" |
# 		grep -E "^[0-9]+,0," |
# 		sed -e "s/,0,/\\t/" |
# 		sed -e "s/);*$//" |
# 		pigz --fast >"$TEMPLATELINKS_TRIM_FILENAME".tmp
# 	mv "$TEMPLATELINKS_TRIM_FILENAME".tmp "$TEMPLATELINKS_TRIM_FILENAME"
# else
# 	echo "[WARN] TEMPLATELINKS: already trimmed file"
# fi

PAGEPROPS_TRIM_FILENAME="pageprops_trim.tsv.gz"

if [[ ! -f "$PAGEPROPS_TRIM_FILENAME" ]]; then
	echo "[INFO] PAGEPROPS: extracting hiddencats"
	pigz -dc "$PAGEPROPS_DUMP_FILENAME" |
		sed -n "s/^INSERT INTO \`page_props\` VALUES (//p" |
		sed -e "s/),(/\\n/g" |
		grep -E "^[0-9]+,'hiddencat',.*$" |
		sed -e "s/,'hiddencat',.*$//" |
		pigz --fast >"$PAGEPROPS_TRIM_FILENAME".tmp
	mv "$PAGEPROPS_TRIM_FILENAME".tmp "$PAGEPROPS_TRIM_FILENAME"
else
	echo "[WARN] PAGEPROPS: already extracted hiddencats"
fi
CATEGORIES_TRIM_FILENAME="categories_trim.tsv.gz"

if [[ ! -f "$CATEGORIES_TRIM_FILENAME" ]]; then
	echo "[INFO] CATEGORIES: trimming file"
	(
		set +e +o pipefail
		pigz -dc "$CATEGORIES_DUMP_FILENAME" |
			iconv -t UTF-8 -c |
			sed -n "s/^INSERT INTO \`category\` VALUES (//p" |
			sed -e "s/),(/\\n/g" |
			sed -e "s/,'/\\t/" |
			sed -e "s/',.*$//" | # FIXME: 'zebi',zebi'
			pigz --fast >"$CATEGORIES_TRIM_FILENAME".tmp
	)
	mv "$CATEGORIES_TRIM_FILENAME".tmp "$CATEGORIES_TRIM_FILENAME"
else
	echo "[WARN] CATEGORIES: already trimmed file"
fi

CATEGORYLINKS_SANITIZED_FILENAME="categorylinks_sanitized.tsv.gz"

if [[ ! -f "$CATEGORYLINKS_SANITIZED_FILENAME" ]]; then
	echo "[INFO] CATEGORYLINKS: sanitizing file"
	rm -f "$CATEGORYLINKS_SANITIZED_FILENAME".tmp
	pigz -dc "$CATEGORYLINKS_DUMP_FILENAME" |
		split -l 50000 - chunk_
	(
		set +e +o pipefail
		for file in chunk_*; do
			iconv -t UTF-8 -c "$file" |
				pigz --fast >>"$CATEGORYLINKS_SANITIZED_FILENAME".tmp
			rm "$file"
		done
	)
	mv "$CATEGORYLINKS_SANITIZED_FILENAME".tmp "$CATEGORYLINKS_SANITIZED_FILENAME"
else
	echo "[WARN] CATEGORYLINKS: already sanitized file"
fi

CATEGORYLINKS_TRIM_FILENAME="categorylinks_trim.tsv.gz"

if [[ ! -f "$CATEGORYLINKS_TRIM_FILENAME" ]]; then
	echo "[INFO] CATEGORYLINKS: trimming file"
	pigz -dc "$CATEGORYLINKS_SANITIZED_FILENAME" |
		sed -n "s/^INSERT INTO \`categorylinks\` VALUES (//p" |
		sed -e "s/),(/\\n/g" |
		sed -e "s/,'/\\t/" |
		sed -e "s/',.*$//" | # FIXME: 'zebi',zebi'
		pigz --fast >"$CATEGORYLINKS_TRIM_FILENAME".tmp
	mv "$CATEGORYLINKS_TRIM_FILENAME".tmp "$CATEGORYLINKS_TRIM_FILENAME"
else
	echo "[WARN] CATEGORYLINKS: already trimmed file"
fi

PAGECATEGORIES_TRIM_FILENAME="pagecategories_trim.tsv.gz"

if [[ ! -f "$PAGECATEGORIES_TRIM_FILENAME" ]]; then
	echo "[INFO] PAGECATEGORIES: trimming file"
	pigz -dc "$PAGES_DUMP_FILENAME" |
		sed -n "s/^INSERT INTO \`page\` VALUES (//p" |
		sed -e "s/),(/\\n/g" |
		grep -E "^[0-9]+,14," |
		sed -e "s/,14,'/\\t/" |
		sed -e "s/',.*$//" | # FIXME: 'zebi',zebi'
		pigz --fast >"$PAGECATEGORIES_TRIM_FILENAME".tmp
	mv "$PAGECATEGORIES_TRIM_FILENAME".tmp "$PAGECATEGORIES_TRIM_FILENAME"
else
	echo "[WARN] PAGECATEGORIES: already trimmed file"
fi

LINKTARGETS_TRIM_FILENAME="linktargets_trim.tsv.gz"

if [[ ! -f "$LINKTARGETS_TRIM_FILENAME" ]]; then
	echo "[INFO] LINKTARGETS: trimming file"
	pigz -dc "$LINKTARGETS_DUMP_FILENAME" |
		sed -n "s/^INSERT INTO \`linktarget\` VALUES (//p" |
		sed -e "s/),(/\\n/g" |
		grep -E "^[0-9]+,0," |
		sed -e "s/,0,'/\\t/" |
		sed -e "s/'$//" | # FIXME: 'zebi',zebi'
		sed -e "s/');$//" |
		pigz --fast >"$LINKTARGETS_TRIM_FILENAME".tmp
	mv "$LINKTARGETS_TRIM_FILENAME".tmp "$LINKTARGETS_TRIM_FILENAME"
else
	echo "[WARN] LINKTARGETS: already trimmed file"
fi

CATEGORIES_BY_TITLES_PKL_FILENAME="CATEGORIES_BY_TITLES.pkl.gz"
CATEGORIES_FILENAME="categories.tsv.gz"

if [[ ! -f "$CATEGORIES_FILENAME" ]] || [[ ! -f "$CATEGORIES_BY_TITLES_PKL_FILENAME" ]]; then
	echo "[INFO] CATEGORIES: generating by_title pickle"
	total_lines=$(pigz -dc "$CATEGORIES_TRIM_FILENAME" | sed -n '$=')
	python3 "$ROOT_DIR/scripts/process_categories.py" \
		--CATEGORIES_TRIM_FILENAME "$CATEGORIES_TRIM_FILENAME" \
		--CATEGORIES_BY_TITLES_PKL_FILENAME "$CATEGORIES_BY_TITLES_PKL_FILENAME" \
		--total_lines "$total_lines" |
		pigz --fast >"$CATEGORIES_FILENAME".tmp
	mv "$CATEGORIES_FILENAME".tmp "$CATEGORIES_FILENAME"
	mv "$CATEGORIES_BY_TITLES_PKL_FILENAME".tmp "$CATEGORIES_BY_TITLES_PKL_FILENAME"
else
	echo "[WARN] CATEGORIES: already generated pickle"
fi

CATEGORIES_FINAL_FILENAME="categories.final.tsv.gz"

if [[ ! -f "$CATEGORIES_FINAL_FILENAME" ]]; then
	echo "[INFO] CATEGORIES: sorting final tsv by title then by id"
	pigz -dc "$CATEGORIES_FILENAME" |
		sort --parallel=$PARALLEL_CORES -S 80% -t $'\t' -k2,2 -k1,1 |
		pigz --best >"$CATEGORIES_FINAL_FILENAME".tmp
	mv "$CATEGORIES_FINAL_FILENAME".tmp "$CATEGORIES_FINAL_FILENAME"
else
	echo "[WARN] CATEGORIES: already sorted final tsv"
fi

PAGES_BY_IDS_PKL_FILENAME="PAGES_BY_IDS.pkl.gz"
PAGES_BY_TITLES_PKL_FILENAME="PAGES_BY_TITLES.pkl.gz"
PAGES_FILENAME="pages.tsv.gz"

if [[ ! -f "$PAGES_BY_IDS_PKL_FILENAME" ]] || [[ ! -f "$PAGES_BY_TITLES_PKL_FILENAME" ]] || [[ ! -f "$PAGES_FILENAME" ]]; then
	echo "[INFO] PAGES: generating pages_by_ids and pages_by_titles pickles"
	total_lines=$(pigz -dc "$PAGES_TRIM_FILENAME" | sed -n '$=')
	python3 "$ROOT_DIR/scripts/process_pages.py" \
		--PAGES_TRIM_FILENAME "$PAGES_TRIM_FILENAME" \
		--PAGES_BY_IDS_PKL_FILENAME "$PAGES_BY_IDS_PKL_FILENAME" \
		--PAGES_BY_TITLES_PKL_FILENAME "$PAGES_BY_TITLES_PKL_FILENAME" \
		--total_lines "$total_lines" |
		pigz --fast >"$PAGES_FILENAME".tmp
	mv "$PAGES_BY_IDS_PKL_FILENAME".tmp "$PAGES_BY_IDS_PKL_FILENAME"
	mv "$PAGES_BY_TITLES_PKL_FILENAME".tmp "$PAGES_BY_TITLES_PKL_FILENAME"
	mv "$PAGES_FILENAME".tmp "$PAGES_FILENAME"
else
	echo "[WARN] PAGES: already generated pickles"
fi

REDIRECTS_PKL_FILENAME="REDIRECTS.pkl.gz"
REDIRECTS_IDS_FILENAME="redirects_ids.tsv.gz"

if [[ ! -f "$REDIRECTS_IDS_FILENAME" ]] || [[ ! -f "$REDIRECTS_PKL_FILENAME" ]]; then
	echo "[INFO] REDIRECTS: replacing target_page_title by target_page_id & generating pickle"
	total_lines=$(pigz -dc "$REDIRECTS_TRIM_FILENAME" | sed -n '$=')
	python3 "$ROOT_DIR/scripts/process_redirects.py" \
		--REDIRECTS_TRIM_FILENAME "$REDIRECTS_TRIM_FILENAME" \
		--PAGES_BY_IDS_PKL_FILENAME "$PAGES_BY_IDS_PKL_FILENAME" \
		--PAGES_BY_TITLES_PKL_FILENAME "$PAGES_BY_TITLES_PKL_FILENAME" \
		--REDIRECTS_PKL_FILENAME "$REDIRECTS_PKL_FILENAME" \
		--total_lines "$total_lines" |
		pigz --fast >"$REDIRECTS_IDS_FILENAME".tmp
	mv "$REDIRECTS_PKL_FILENAME".tmp "$REDIRECTS_PKL_FILENAME"
	mv "$REDIRECTS_IDS_FILENAME".tmp "$REDIRECTS_IDS_FILENAME"
else
	echo "[WARN] REDIRECTS: already replaced titles by ids & generated pickle"
fi

REDIRECTS_FINAL_FILENAME="redirect_to.final.tsv.gz"

if [[ ! -f "$REDIRECTS_FINAL_FILENAME" ]]; then
	echo "[INFO] REDIRECTS: sorting final tsv by source_page_id then by target_page_id"
	pigz -dc "$REDIRECTS_IDS_FILENAME" |
		sort --parallel=$PARALLEL_CORES -S 80% -t $'\t' -k1,1 -k3,3 |
		pigz --best >"$REDIRECTS_FINAL_FILENAME".tmp
	mv "$REDIRECTS_FINAL_FILENAME".tmp "$REDIRECTS_FINAL_FILENAME"
else
	echo "[WARN] REDIRECTS: already sorted final tsv"
fi

LINKTARGETS_PKL_FILENAME="LINKTARGETS.pkl.gz"

if [[ ! -f "$LINKTARGETS_PKL_FILENAME" ]]; then
	echo "[INFO] LINKTARGETS: purging linktargets & generating pickle"
	total_lines=$(pigz -dc "$LINKTARGETS_TRIM_FILENAME" | sed -n '$=')
	python3 "$ROOT_DIR/scripts/process_linktargets.py" \
		--LINKTARGETS_TRIM_FILENAME "$LINKTARGETS_TRIM_FILENAME" \
		--PAGES_BY_IDS_PKL_FILENAME "$PAGES_BY_IDS_PKL_FILENAME" \
		--LINKTARGETS_PKL_FILENAME "$LINKTARGETS_PKL_FILENAME" \
		--total_lines "$total_lines"
	mv "$LINKTARGETS_PKL_FILENAME".tmp "$LINKTARGETS_PKL_FILENAME"
else
	echo "[WARN] LINKTARGETS: already purged linktargets & generated pickle"
fi

PAGELINKS_IDS_FILENAME="pagelinks_ids.tsv.gz"

if [[ ! -f "$PAGELINKS_IDS_FILENAME" ]]; then
	echo "[INFO] PAGELINKS: replacing target_page_title by target_page_id"
	total_lines=$(pigz -dc "$PAGELINKS_TRIM_FILENAME" | sed -n '$=')
	python3 "$ROOT_DIR/scripts/process_pagelinks.py" \
		--PAGELINKS_TRIM_FILENAME "$PAGELINKS_TRIM_FILENAME" \
		--PAGES_BY_IDS_PKL_FILENAME "$PAGES_BY_IDS_PKL_FILENAME" \
		--LINKTARGETS_PKL_FILENAME "$LINKTARGETS_PKL_FILENAME" \
		--total_lines "$total_lines" |
		pigz --fast >"$PAGELINKS_IDS_FILENAME".tmp
	mv "$PAGELINKS_IDS_FILENAME".tmp "$PAGELINKS_IDS_FILENAME"
else
	echo "[WARN] PAGELINKS: already replaced titles by ids"
fi

PAGELINKS_FINAL_FILENAME="link_to.final.tsv.gz"

if [[ ! -f "$PAGELINKS_FINAL_FILENAME" ]]; then
	echo "[INFO] PAGELINKS: sorting final tsv by source_page_id then by target_page_id & removing duplicates"
	pigz -dc "$PAGELINKS_IDS_FILENAME" |
		sort --parallel=$PARALLEL_CORES -S 80% -t $'\t' -k1,1 -k3,3 |
		uniq |
		pigz --best >"$PAGELINKS_FINAL_FILENAME".tmp
	mv "$PAGELINKS_FINAL_FILENAME".tmp "$PAGELINKS_FINAL_FILENAME"
else
	echo "[WARN] PAGELINKS: already sorted & cleaned final tsv"
fi

PAGEPROPS_PKL_FILENAME="PAGEPROPS.pkl.gz"

if [[ ! -f "$PAGEPROPS_PKL_FILENAME" ]]; then
	echo "[INFO] PAGEPROPS: generating pickle"
	total_lines=$(pigz -dc "$PAGEPROPS_TRIM_FILENAME" | sed -n '$=')
	python3 "$ROOT_DIR/scripts/process_pageprops.py" \
		--PAGEPROPS_TRIM_FILENAME "$PAGEPROPS_TRIM_FILENAME" \
		--PAGEPROPS_PKL_FILENAME "$PAGEPROPS_PKL_FILENAME" \
		--total_lines "$total_lines"
	mv "$PAGEPROPS_PKL_FILENAME".tmp "$PAGEPROPS_PKL_FILENAME"
else
	echo "[WARN] PAGEPROPS: already generated pickle"
fi

PAGECATEGORIES_FILENAME="pagecategories.tsv.gz"
HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME="HIDDEN_PAGECATEGORIES_BY_TITLES.pkl.gz"

if [[ ! -f "$PAGECATEGORIES_FILENAME" ]] || [[ ! -f "$HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME" ]]; then
	echo "[INFO] PAGECATEGORIES: purging hidden pagecategories & generating pickle"
	total_lines=$(pigz -dc "$PAGECATEGORIES_TRIM_FILENAME" | sed -n '$=')
	python3 "$ROOT_DIR/scripts/process_pagecategories.py" \
		--PAGECATEGORIES_TRIM_FILENAME "$PAGECATEGORIES_TRIM_FILENAME" \
		--PAGEPROPS_PKL_FILENAME "$PAGEPROPS_PKL_FILENAME" \
		--HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME "$HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME" \
		--total_lines "$total_lines" |
		pigz --fast >"$PAGECATEGORIES_FILENAME".tmp
	mv "$PAGECATEGORIES_FILENAME".tmp "$PAGECATEGORIES_FILENAME"
	mv "$HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME".tmp "$HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME"
else
	echo "[WARN] PAGECATEGORIES: already purged hidden pagecategories & generated pickle"
fi

CATEGORYLINKS_PURGED_FILENAME="categorylinks_purged.tsv.gz"

if [[ ! -f "$CATEGORYLINKS_PURGED_FILENAME" ]]; then
	echo "[INFO] CATEGORYLINKS: purging hidden categorylinks & replacing category_title by category_id"
	total_lines=$(pigz -dc "$CATEGORYLINKS_TRIM_FILENAME" | sed -n '$=')
	python3 "$ROOT_DIR/scripts/process_categorylinks.py" \
		--CATEGORYLINKS_TRIM_FILENAME "$CATEGORYLINKS_TRIM_FILENAME" \
		--HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME "$HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME" \
		--CATEGORIES_BY_TITLES_PKL_FILENAME "$CATEGORIES_BY_TITLES_PKL_FILENAME" \
		--PAGES_BY_IDS_PKL_FILENAME "$PAGES_BY_IDS_PKL_FILENAME" \
		--total_lines "$total_lines" |
		pigz --fast >"$CATEGORYLINKS_PURGED_FILENAME".tmp
	mv "$CATEGORYLINKS_PURGED_FILENAME".tmp "$CATEGORYLINKS_PURGED_FILENAME"
else
	echo "[WARN] CATEGORYLINKS: already purged hidden categorylinks and category_title by category_id"
fi

CATEGORYLINKS_FINAL_FILENAME="belong_to.final.tsv.gz"

if [[ ! -f "$CATEGORYLINKS_FINAL_FILENAME" ]]; then
	echo "[INFO] CATEGORYLINKS: sorting final tsv by page_id then by category_id"
	pigz -dc "$CATEGORYLINKS_PURGED_FILENAME" |
		sort --parallel=$PARALLEL_CORES -S 80% -t $'\t' -k1,1 -k3,3 |
		pigz --best >"$CATEGORYLINKS_FINAL_FILENAME".tmp
	mv "$CATEGORYLINKS_FINAL_FILENAME".tmp "$CATEGORYLINKS_FINAL_FILENAME"
else
	echo "[WARN] CATEGORYLINKS: already sorted tsv"
fi

PAGES_FINAL_FILENAME="pages.final.tsv.gz"

if [[ ! -f "$PAGES_FINAL_FILENAME" ]]; then
	echo "[INFO] PAGES: sorting final tsv by page_id"
	pigz -dc "$PAGES_FILENAME" |
		sort --parallel=$PARALLEL_CORES -S 80% -t $'\t' -k1,1 |
		pigz --best >"$PAGES_FINAL_FILENAME".tmp
	mv "$PAGES_FINAL_FILENAME".tmp "$PAGES_FINAL_FILENAME"
else
	echo "[WARN] PAGES: already sorted final tsv"
fi

### will generate the inverse of relation (page|redirect)-[belong_to]->(category)
### which is (page|redirect)<-[contains]-(category)
###	you only need this if you plan to use an ORM to communicate with neo4j
### it will allow bypassing need of circular mapping
CATEGORYLINKS_REVERSED_FILENAME="categorylinks_reversed.tsv.gz"

if [[ ! -f "$CATEGORYLINKS_REVERSED_FILENAME" ]]; then
	echo "[INFO] CATEGORYLINKS: reversing TSV"
	pigz -dc "$CATEGORYLINKS_PURGED_FILENAME" |
		awk 'BEGIN{OFS="\t"} {print $3, "contains", $1}' |
		pigz --fast >"$CATEGORYLINKS_REVERSED_FILENAME".tmp
	mv "$CATEGORYLINKS_REVERSED_FILENAME".tmp "$CATEGORYLINKS_REVERSED_FILENAME"
else
	echo "[WARN] CATEGORYLINKS: already reversed tsv"
fi

CATEGORYLINKS_REVERSED_FINAL_FILENAME="contains.final.tsv.gz"

if [[ ! -f "$CATEGORYLINKS_REVERSED_FINAL_FILENAME" ]]; then
	echo "[INFO] CATEGORYLINKS: sorting final reversed tsv by category_id then by page_id"
	pigz -dc "$CATEGORYLINKS_REVERSED_FILENAME" |
		sort --parallel=$PARALLEL_CORES -S 80% -t $'\t' -k1,1 -k3,3 |
		pigz --best >"$CATEGORYLINKS_REVERSED_FINAL_FILENAME".tmp
	mv "$CATEGORYLINKS_REVERSED_FINAL_FILENAME".tmp "$CATEGORYLINKS_REVERSED_FINAL_FILENAME"
else
	echo "[WARN] CATEGORYLINKS: already sorted reversed tsv"
fi
##########

META_FINAL_FILENAME="meta.final.tsv.gz"
SEPARATOR="\t"

echo "[INFO] META: generating dump metadata"

echo -e "1${SEPARATOR}dump${SEPARATOR}{\"lang\":\"${DUMP_LANG}\",\"date\":\"${DOWNLOAD_DATE}\",\"url\":\"${DOWNLOAD_URL}\"}${SEPARATOR}meta" |
	pigz --best >"$META_FINAL_FILENAME"

if [[ -f "$PAGES_FINAL_FILENAME" ]] && [[ -f "$PAGELINKS_FINAL_FILENAME" ]] && [[ -f "$REDIRECTS_FINAL_FILENAME" ]] && [[ -f "$CATEGORIES_FINAL_FILENAME" ]] && [[ -f "$CATEGORYLINKS_FINAL_FILENAME" ]] && [[ -f "$CATEGORYLINKS_REVERSED_FINAL_FILENAME" ]] && [[ -f "$META_FINAL_FILENAME" ]]; then
	OUTPUT_DIR="$ROOT_DIR/output"
	mkdir -p "$OUTPUT_DIR"
	echo "[INFO] copying TSVs to $OUTPUT_DIR"
	cp "$PAGES_FINAL_FILENAME" "$OUTPUT_DIR"
	cp "$PAGELINKS_FINAL_FILENAME" "$OUTPUT_DIR"
	cp "$REDIRECTS_FINAL_FILENAME" "$OUTPUT_DIR"
	cp "$CATEGORIES_FINAL_FILENAME" "$OUTPUT_DIR"
	cp "$CATEGORYLINKS_FINAL_FILENAME" "$OUTPUT_DIR"
	cp "$CATEGORYLINKS_REVERSED_FINAL_FILENAME" "$OUTPUT_DIR"
	cp "$META_FINAL_FILENAME" "$OUTPUT_DIR"
	ls -l "$OUTPUT_DIR"
fi

echo "[INFO] graph generated successfully: $(date +"%a %b %d %T %Y")"

exit 0
