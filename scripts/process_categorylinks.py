import argparse
import os

import pgzip
from commons import SEPARATOR, deserialize, gz_file, logging, pkl_gz_file
from tqdm import tqdm
from typeguard import typechecked

script_name = os.path.splitext(os.path.basename(__file__))[0]
logger = logging.getLogger(script_name)


@typechecked
def process_categorylinks(
    path: str,
    hidden_pagecategories_by_titles: dict[str, str],
    categories_by_titles: dict[str, str],
    pages_by_ids: dict[str, tuple[str, bool]],
    total_lines: int = 0,
) -> None:
    with pgzip.open(path, "rt") as file:
        for _, line in enumerate(
            tqdm(file, total=total_lines, desc="Processing categorylinks"), start=1
        ):
            try:
                source_page_id, target_category_title = line.rstrip("\n").split(
                    SEPARATOR
                )
                if (
                    # not a hidden category
                    (not target_category_title in hidden_pagecategories_by_titles)
                    # and target category exists in categories
                    and target_category_title in categories_by_titles
                    # and source page exists in pages_by_ids
                    and source_page_id in pages_by_ids
                ):
                    print(
                        "\t".join(
                            [
                                source_page_id,
                                "belong_to",
                                categories_by_titles[target_category_title],
                            ]
                        )
                    )
            except Exception:
                logger.error("error parsing line:\n%s", line)
                continue


parser = argparse.ArgumentParser(description="process categorylinks file")

parser.add_argument(
    "--CATEGORYLINKS_TRIM_FILENAME",
    type=gz_file,
    help="categorylinks trimmed file path",
)
parser.add_argument(
    "--HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME",
    type=pkl_gz_file,
    help="hidden_categories_by_titles pkl file path",
)
parser.add_argument(
    "--CATEGORIES_BY_TITLES_PKL_FILENAME",
    type=pkl_gz_file,
    help="categories_by_titles pkl file path",
)
parser.add_argument(
    "--PAGES_BY_IDS_PKL_FILENAME", type=pkl_gz_file, help="pages_by_ids pkl file path"
)
parser.add_argument(
    "--total_lines", type=int, default=0, help="number of lines to process (optional)"
)

args = parser.parse_args()

CATEGORYLINKS_TRIM_FILENAME = args.CATEGORYLINKS_TRIM_FILENAME
HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME = (
    args.HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME
)
CATEGORIES_BY_TITLES_PKL_FILENAME = args.CATEGORIES_BY_TITLES_PKL_FILENAME
PAGES_BY_IDS_PKL_FILENAME = args.PAGES_BY_IDS_PKL_FILENAME
TOTAL_LINES = args.total_lines

logger.info("unpickling hidden_pagecategories_by_titles")
hidden_pagecategories_by_titles = deserialize(
    HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME
)

logger.info("unpickling categories_by_titles")
categories_by_titles = deserialize(CATEGORIES_BY_TITLES_PKL_FILENAME)

logger.info("unpickling pages_by_ids")
pages_by_ids = deserialize(PAGES_BY_IDS_PKL_FILENAME)

logger.info("processing categorylinks & > stdout")
process_categorylinks(
    CATEGORYLINKS_TRIM_FILENAME,
    hidden_pagecategories_by_titles,
    categories_by_titles,
    pages_by_ids,
    TOTAL_LINES,
)
