import argparse
import os

import pgzip
from commons import (
    SEPARATOR,
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
def process_categories(
    path: str,
    total_lines: int = 0,
) -> dict[str, str]:
    categories_by_titles: dict[str, str] = {}
    with pgzip.open(path, "rt") as file:
        for _, line in enumerate(
            tqdm(file, total=total_lines, desc="Processing categories"), start=1
        ):
            try:
                _id, title = line.rstrip("\n").split(SEPARATOR)
                categories_by_titles[title] = _id
            except Exception:
                logger.error("error parsing line:\n%s", line)
                continue
    return categories_by_titles


@typechecked
def output_categories_to_stdout(
    categories: dict[str, str],
) -> None:
    for title, _id in tqdm(categories.items()):
        print("\t".join([_id, title, "category"]))


parser = argparse.ArgumentParser(description="process pages file")

parser.add_argument(
    "--CATEGORIES_TRIM_FILENAME", type=gz_file, help="categories trim file path"
)
parser.add_argument(
    "--CATEGORIES_BY_TITLES_PKL_FILENAME",
    type=pkl_gz_file,
    help="categories_by_titles pkl file path",
)
parser.add_argument(
    "--total_lines", type=int, default=0, help="number of lines to process (optional)"
)

args = parser.parse_args()

CATEGORIES_TRIM_FILENAME = args.CATEGORIES_TRIM_FILENAME
CATEGORIES_BY_TITLES_PKL_FILENAME = args.CATEGORIES_BY_TITLES_PKL_FILENAME
TOTAL_LINES = args.total_lines

logger.info("processing categories")
categories_by_titles = process_categories(CATEGORIES_TRIM_FILENAME, TOTAL_LINES)

logger.info("generating pickle")
path, size = serialize(categories_by_titles, CATEGORIES_BY_TITLES_PKL_FILENAME)
logger.info("%s, %s", path, size)
logger.info("categories_by_titles:\n%s", print_dict_header(categories_by_titles))

logger.info("categories > stdout")
output_categories_to_stdout(categories_by_titles)
