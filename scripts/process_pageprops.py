import argparse
import os

import pgzip
from commons import gz_file, logging, pkl_gz_file, print_set_header, serialize
from tqdm import tqdm
from typeguard import typechecked

script_name = os.path.splitext(os.path.basename(__file__))[0]
logger = logging.getLogger(script_name)


@typechecked
def process_pageprops(
    path: str,
    total_lines: int = 0,
) -> set[str]:
    pageprops: set[str] = set()
    with pgzip.open(path, "rt") as file:
        for _, line in enumerate(
            tqdm(file, total=total_lines, desc="Processing pageprops")
        ):
            try:
                _id = line.rstrip("\n")
                int(_id)  # detect if a line is unparsable
                pageprops.add(_id)
            except Exception:
                logger.error("error parsing line:\n%s", line)
                continue
    return pageprops


parser = argparse.ArgumentParser(description="process pageprops file")

parser.add_argument(
    "--PAGEPROPS_TRIM_FILENAME", type=gz_file, help="pageprops trimmed file path"
)
parser.add_argument(
    "--PAGEPROPS_PKL_FILENAME", type=pkl_gz_file, help="pageprops pkl file path"
)
parser.add_argument(
    "--total_lines", type=int, default=0, help="number of lines to process (optional)"
)

args = parser.parse_args()

PAGEPROPS_TRIM_FILENAME = args.PAGEPROPS_TRIM_FILENAME
PAGEPROPS_PKL_FILENAME = args.PAGEPROPS_PKL_FILENAME
TOTAL_LINES = args.total_lines

logger.info("processing pageprops")
pageprops = process_pageprops(PAGEPROPS_TRIM_FILENAME, TOTAL_LINES)

logger.info("generating pickle")
path, size = serialize(pageprops, PAGEPROPS_PKL_FILENAME)
logger.info("%s, %s", path, size)
logger.info("pageprops:\n%s", print_set_header(pageprops))
