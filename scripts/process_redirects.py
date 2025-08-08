import argparse
import os
from collections import defaultdict

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
def process_redirects(
    path: str,
    pages_by_ids: defaultdict[str, str],
    pages_by_titles: defaultdict[str, tuple[str, bool]],
    total_lines: int = 0,
) -> dict[str, str]:
    redirects: dict[str, str] = {}
    with pgzip.open(path, "rt") as file:
        for _, line in enumerate(
            tqdm(file, total=total_lines, desc="Processing redirects")
        ):
            try:
                source_page_id, target_page_title = line.rstrip("\n").split(SEPARATOR)
                # skip if source page is not existing or not a redirect
                if pages_by_ids.get(source_page_id, (None, False))[1]:
                    # x.get(y) return None
                    # x[y] add defaultvalue to defaultdict and return it
                    target_page_id = pages_by_titles.get(target_page_title)
                    # skip if target is not existing or redirect to self
                    if target_page_id and source_page_id != target_page_id:
                        redirects[source_page_id] = target_page_id
            except Exception:
                logger.error("error parsing line:\n%s", line)
                continue
    return redirects


@typechecked
def output_redirects_to_stdout(
    redirects: dict[str, str],
) -> None:
    for source_id, target_id in tqdm(redirects.items()):
        print("\t".join([source_id, "redirect_to", target_id]))


parser = argparse.ArgumentParser(description="process redirects file")

parser.add_argument(
    "--REDIRECTS_TRIM_FILENAME", type=gz_file, help="redirects trimmed file path"
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
    "--REDIRECTS_PKL_FILENAME", type=pkl_gz_file, help="redirects pkl file path"
)
parser.add_argument(
    "--total_lines", type=int, default=0, help="number of lines to process (optional)"
)

args = parser.parse_args()

REDIRECTS_TRIM_FILENAME = args.REDIRECTS_TRIM_FILENAME
PAGES_BY_IDS_PKL_FILENAME = args.PAGES_BY_IDS_PKL_FILENAME
PAGES_BY_TITLES_PKL_FILENAME = args.PAGES_BY_TITLES_PKL_FILENAME
REDIRECTS_PKL_FILENAME = args.REDIRECTS_PKL_FILENAME
TOTAL_LINES = args.total_lines

logger.info("unpickling pages_by_ids")
pages_by_ids = deserialize(PAGES_BY_IDS_PKL_FILENAME)

logger.info("unpickling pages_by_titles")
pages_by_titles = deserialize(PAGES_BY_TITLES_PKL_FILENAME)

logger.info("processing redirects")
redirects = process_redirects(
    REDIRECTS_TRIM_FILENAME, pages_by_ids, pages_by_titles, TOTAL_LINES
)

logger.info("generating pickle")
path, size = serialize(redirects, REDIRECTS_PKL_FILENAME)
logger.info("%s, %s", path, size)
logger.info("redirects:\n%s", print_dict_header(redirects))

logger.info("redirects > stdout")
output_redirects_to_stdout(redirects)
