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
def process_pagecategories(
    path: str,
    pageprops: set[str],
    total_lines: int = 0,
) -> tuple[dict[str, str], dict[str, str]]:
    pagecategories_by_ids: dict[str, str] = {}
    hidden_pagecategories_by_titles: dict[str, str] = {}
    with pgzip.open(path, "rt") as file:
        for _, line in enumerate(
            tqdm(file, total=total_lines, desc="Processing pagecategories")
        ):
            try:
                category_id, category_title = line.rstrip("\n").split(SEPARATOR)
                # separate hidden categories from non hidden
                if not category_id in pageprops:
                    pagecategories_by_ids[category_id] = category_title
                else:
                    hidden_pagecategories_by_titles[category_title] = category_id
            except Exception:
                logger.error("error parsing line:\n%s", line)
                continue
    return (pagecategories_by_ids, hidden_pagecategories_by_titles)


@typechecked
def output_pagecategories_to_stdout(
    pagecategories: dict[str, str],
) -> None:
    for _id, title in tqdm(pagecategories.items()):
        print("\t".join([_id, title]))


parser = argparse.ArgumentParser(description="process pagecategories file")

parser.add_argument(
    "--PAGECATEGORIES_TRIM_FILENAME",
    type=gz_file,
    help="pagecategories trimmed file path",
)
parser.add_argument(
    "--PAGEPROPS_PKL_FILENAME", type=pkl_gz_file, help="pageprops pkl file path"
)
parser.add_argument(
    "--HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME",
    type=pkl_gz_file,
    help="hidden_pagecategories_by_titles pkl file path",
)
parser.add_argument(
    "--total_lines", type=int, default=0, help="number of lines to process (optional)"
)

args = parser.parse_args()

PAGECATEGORIES_TRIM_FILENAME = args.PAGECATEGORIES_TRIM_FILENAME
PAGEPROPS_PKL_FILENAME = args.PAGEPROPS_PKL_FILENAME
HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME = (
    args.HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME
)
TOTAL_LINES = args.total_lines

logger.info("unpickling pageprops")
pageprops = deserialize(PAGEPROPS_PKL_FILENAME)

logger.info("processing pagecategories")
pagecategories_by_ids, hidden_pagecategories_by_titles = process_pagecategories(
    PAGECATEGORIES_TRIM_FILENAME, pageprops, TOTAL_LINES
)

logger.info("generating pickle")
path, size = serialize(
    hidden_pagecategories_by_titles, HIDDEN_PAGECATEGORIES_BY_TITLES_PKL_FILENAME
)
logger.info("%s, %s", path, size)
logger.info(
    "hidden_pagecategories_by_titles:\n%s",
    print_dict_header(hidden_pagecategories_by_titles),
)

logger.info("pagecategories > stdout")
output_pagecategories_to_stdout(pagecategories_by_ids)
