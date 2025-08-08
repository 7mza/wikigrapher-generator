import argparse
import os

import pgzip
from commons import SEPARATOR, deserialize, gz_file, logging, pkl_gz_file
from tqdm import tqdm
from typeguard import typechecked

script_name = os.path.splitext(os.path.basename(__file__))[0]
logger = logging.getLogger(script_name)


@typechecked
def process_pagelinks(
    path: str,
    purged_pages: dict[str, tuple[str, bool]],
    linktargets: dict[str, str],
    total_lines: int = 0,
) -> None:
    with pgzip.open(path, "rt") as file:
        for _, line in enumerate(
            tqdm(file, total=total_lines, desc="Processing pagelinks"), start=1
        ):
            try:
                source_page_id, linktarget_id = line.rstrip("\n").split(SEPARATOR)
                # skip if source page is not existing or is a redirect
                if not purged_pages.get(source_page_id, (None, True))[1]:
                    target_page_id = linktargets.get(linktarget_id)
                    # prevent linking to non existing pages and to self
                    if target_page_id and source_page_id != target_page_id:
                        print("\t".join([source_page_id, "link_to", target_page_id]))
            except Exception:
                logger.error("error parsing line:\n%s", line)
                continue


parser = argparse.ArgumentParser(description="process pagelinks file")

parser.add_argument(
    "--PAGELINKS_TRIM_FILENAME", type=gz_file, help="pagelinks trimmed file path"
)
parser.add_argument(
    "--PURGED_PAGES_PKL_FILENAME", type=pkl_gz_file, help="purged_pages pkl file path"
)
parser.add_argument(
    "--LINKTARGETS_PKL_FILENAME", type=pkl_gz_file, help="linktargets pkl file path"
)
parser.add_argument(
    "--total_lines", type=int, default=0, help="number of lines to process (optional)"
)

args = parser.parse_args()

PAGELINKS_TRIM_FILENAME = args.PAGELINKS_TRIM_FILENAME
PURGED_PAGES_PKL_FILENAME = args.PURGED_PAGES_PKL_FILENAME
LINKTARGETS_PKL_FILENAME = args.LINKTARGETS_PKL_FILENAME
TOTAL_LINES = args.total_lines

logger.info("unpickling purged_pages")
purged_pages = deserialize(PURGED_PAGES_PKL_FILENAME)

logger.info("unpickling linktargets")
linktargets = deserialize(LINKTARGETS_PKL_FILENAME)

logger.info("processing pagelinks & > stdout")
process_pagelinks(PAGELINKS_TRIM_FILENAME, purged_pages, linktargets, TOTAL_LINES)
