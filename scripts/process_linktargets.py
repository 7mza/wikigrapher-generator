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
def process_linktargets(
    path: str,
    pages_by_ids: dict[str, tuple[str, bool]],
    total_lines: int = 0,
) -> dict[str, str]:
    linktargets: dict[str, str | None] = {}
    pages_by_titles: dict[str, str] = {}
    for page_id, (
        page_title,
        _,
    ) in pages_by_ids.items():  # FIXME: useless, pass pages_by_titles instead
        pages_by_titles[page_title] = page_id
    with pgzip.open(path, "rt") as file:
        for _, line in enumerate(
            tqdm(file, total=total_lines, desc="Processing linktargets"), start=1
        ):
            try:
                linktarget_id, linktarget_title = line.rstrip("\n").split(SEPARATOR)
                # ignore linktargets that doesn't appear in pages
                if linktarget_title in pages_by_titles:
                    linktargets[linktarget_id] = pages_by_titles.get(linktarget_title)
            except Exception:
                logger.error("error parsing line:\n%s", line)
                continue
    return linktargets


parser = argparse.ArgumentParser(description="process linktargets file")

parser.add_argument(
    "--LINKTARGETS_TRIM_FILENAME", type=gz_file, help="linktargets trimmed file path"
)
parser.add_argument(
    "--PAGES_BY_IDS_PKL_FILENAME", type=pkl_gz_file, help="pages_by_ids pkl file path"
)
parser.add_argument(
    "--LINKTARGETS_PKL_FILENAME", type=pkl_gz_file, help="linktargets pkl file path"
)
parser.add_argument(
    "--total_lines", type=int, default=0, help="number of lines to process (optional)"
)

args = parser.parse_args()

LINKTARGETS_TRIM_FILENAME = args.LINKTARGETS_TRIM_FILENAME
PAGES_BY_IDS_PKL_FILENAME = args.PAGES_BY_IDS_PKL_FILENAME
LINKTARGETS_PKL_FILENAME = args.LINKTARGETS_PKL_FILENAME
TOTAL_LINES = args.total_lines

logger.info("unpickling pages_by_ids")
pages_by_ids = deserialize(PAGES_BY_IDS_PKL_FILENAME)

logger.info("processing linktargets")
linktargets = process_linktargets(LINKTARGETS_TRIM_FILENAME, pages_by_ids, TOTAL_LINES)

logger.info("generating pickle")
path, size = serialize(linktargets, LINKTARGETS_PKL_FILENAME)
logger.info("%s, %s", path, size)
logger.info("linktargets:\n%s", print_dict_header(linktargets))
