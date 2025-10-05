# FIXME: combine with process_linktargets in one pass

import argparse
import os

import pgzip
from commons import (
    SEPARATOR,
    deserialize,
    gz_file,
    logging,
    pkl_gz_file,
    print_dict_header,
    serialize,
)
from tqdm import tqdm
from typeguard import typechecked

script_name = os.path.splitext(os.path.basename(__file__))[0]
logger = logging.getLogger(script_name)


@typechecked
def process_categorylinktargets(
    path: str,
    categories_by_titles: dict[str, str],
    hidden_pagecategories_by_titles: dict[str, str],
    total_lines: int = 0,
) -> dict[str, str]:
    categorylinktargets: dict[str, str] = {}
    with pgzip.open(path, "rt") as file:
        for _, line in enumerate(
            tqdm(file, total=total_lines, desc="Processing categorylinktargets"),
            start=1,
        ):
            try:
                _id, title = line.rstrip("\n").split(SEPARATOR)

                if (
                    # not a hidden category
                    (not title in hidden_pagecategories_by_titles)
                    # and categorylinktarget title exists in categories
                    and title in categories_by_titles
                ):
                    categorylinktargets[_id] = categories_by_titles.get(title)
            except Exception:
                logger.error("error parsing line:\n%s", line)
                continue
    return categorylinktargets


parser = argparse.ArgumentParser(description="process categorylinktargets file")

parser.add_argument(
    "--CATEGORYLINKTARGETS_TRIM_FILENAME",
    type=gz_file,
    help="categorylinktargets trimmed file path",
)
parser.add_argument(
    "--CATEGORIES_BY_TITLES_PKL_FILENAME",
    type=pkl_gz_file,
    help="categories_by_titles pkl file path",
)
parser.add_argument(
    "--CATEGORYLINKTARGETS_PKL_FILENAME",
    type=pkl_gz_file,
    help="categorylinktargets pkl file path",
)
parser.add_argument(
    "--HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME",
    type=pkl_gz_file,
    help="hidden_categories_by_titles pkl file path",
)
parser.add_argument(
    "--total_lines", type=int, default=0, help="number of lines to process (optional)"
)

args = parser.parse_args()

CATEGORYLINKTARGETS_TRIM_FILENAME = args.CATEGORYLINKTARGETS_TRIM_FILENAME
CATEGORIES_BY_TITLES_PKL_FILENAME = args.CATEGORIES_BY_TITLES_PKL_FILENAME
CATEGORYLINKTARGETS_PKL_FILENAME = args.CATEGORYLINKTARGETS_PKL_FILENAME
HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME = (
    args.HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME
)
TOTAL_LINES = args.total_lines

logger.info("unpickling categories_by_titles")
categories_by_titles = deserialize(CATEGORIES_BY_TITLES_PKL_FILENAME)

logger.info("unpickling hidden_pagecategories_by_titles")
hidden_pagecategories_by_titles = deserialize(
    HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME
)

logger.info("processing categorylinktargets")
categorylinktargets = process_categorylinktargets(
    CATEGORYLINKTARGETS_TRIM_FILENAME,
    categories_by_titles,
    hidden_pagecategories_by_titles,
    TOTAL_LINES,
)

logger.info("generating pickle")
path, size = serialize(categorylinktargets, CATEGORYLINKTARGETS_PKL_FILENAME)
logger.info("%s, %s", path, size)
logger.info("categorylinktargets:\n%s", print_dict_header(categorylinktargets))
