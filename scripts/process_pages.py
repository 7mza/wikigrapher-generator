import argparse
import os
from collections import defaultdict

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
def process_pages(
    path: str,
    total_lines: int = 0,
) -> tuple[defaultdict[str, tuple[str, bool]], defaultdict[str, str]]:
    pages_by_ids: defaultdict[str, tuple[str, bool]] = defaultdict(dict)
    pages_by_titles: defaultdict[str, str] = defaultdict(dict)
    with pgzip.open(path, "rt") as file:
        for _, line in enumerate(
            tqdm(file, total=total_lines, desc="Processing pages")
        ):
            try:
                _id, title, is_redirect = line.rstrip("\n").split(SEPARATOR)
                if title not in pages_by_titles:
                    pages_by_titles[title] = _id
                    pages_by_ids[_id] = (title, is_redirect == "1")
                else:
                    logger.warning("title '%s' already exists skipping.", title)
            except Exception:
                logger.error("error parsing line:\n%s", line)
                continue
    return (pages_by_ids, pages_by_titles)


parser = argparse.ArgumentParser(description="process pages file")

parser.add_argument(
    "--PAGES_TRIM_FILENAME", type=gz_file, help="pages trimmed file path"
)
parser.add_argument(
    "--PAGES_BY_IDS_PKL_FILENAME", type=pkl_gz_file, help="pages_by_ids pkl file path"
)
parser.add_argument(
    "--PAGES_BY_TITLES_PKL_FILENAME",
    type=pkl_gz_file,
    help="pages_by_titles pkl file path",
)
parser.add_argument(
    "--total_lines", type=int, default=0, help="number of lines to process (optional)"
)

args = parser.parse_args()

PAGES_TRIM_FILENAME = args.PAGES_TRIM_FILENAME
PAGES_BY_IDS_PKL_FILENAME = args.PAGES_BY_IDS_PKL_FILENAME
PAGES_BY_TITLES_PKL_FILENAME = args.PAGES_BY_TITLES_PKL_FILENAME
TOTAL_LINES = args.total_lines

logger.info("processing pages")
(pages_by_ids, pages_by_titles) = process_pages(PAGES_TRIM_FILENAME, TOTAL_LINES)

logger.info("generating pages_by_ids pickle")
path, size = serialize(pages_by_ids, PAGES_BY_IDS_PKL_FILENAME)
logger.info("%s, %s", path, size)
logger.info("pages_by_ids:\n%s", print_dict_header(pages_by_ids))

logger.info("generating pages_by_titles pickle")
path, size = serialize(pages_by_titles, PAGES_BY_TITLES_PKL_FILENAME)
logger.info("%s, %s", path, size)
logger.info("pages_by_titles:\n%s", print_dict_header(pages_by_titles))
