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
    categorylinktargets: dict[str, str],
    pages_by_ids: dict[str, tuple[str, bool]],
    total_lines: int = 0,
) -> None:
    with pgzip.open(path, "rt") as file:
        for _, line in enumerate(
            tqdm(file, total=total_lines, desc="Processing categorylinks"), start=1
        ):
            try:
                source_page_id, target_category_id = line.rstrip("\n").split(SEPARATOR)
                if (
                    # target category id exists in categorylinktargets
                    target_category_id in categorylinktargets
                    # and source page exists in pages_by_ids
                    and source_page_id in pages_by_ids
                ):
                    print(
                        "\t".join(
                            [
                                source_page_id,
                                "belong_to",
                                categorylinktargets[target_category_id],
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
    "--CATEGORYLINKTARGETS_PKL_FILENAME",
    type=pkl_gz_file,
    help="categorylinktargets pkl file path",
)
parser.add_argument(
    "--PAGES_BY_IDS_PKL_FILENAME", type=pkl_gz_file, help="pages_by_ids pkl file path"
)
parser.add_argument(
    "--total_lines", type=int, default=0, help="number of lines to process (optional)"
)

args = parser.parse_args()

CATEGORYLINKS_TRIM_FILENAME = args.CATEGORYLINKS_TRIM_FILENAME
CATEGORYLINKTARGETS_PKL_FILENAME = args.CATEGORYLINKTARGETS_PKL_FILENAME
PAGES_BY_IDS_PKL_FILENAME = args.PAGES_BY_IDS_PKL_FILENAME
TOTAL_LINES = args.total_lines

logger.info("unpickling categorylinktargets")
categorylinktargets = deserialize(CATEGORYLINKTARGETS_PKL_FILENAME)

logger.info("unpickling pages_by_ids")
pages_by_ids = deserialize(PAGES_BY_IDS_PKL_FILENAME)

logger.info("processing categorylinks & > stdout")
process_categorylinks(
    CATEGORYLINKS_TRIM_FILENAME,
    categorylinktargets,
    pages_by_ids,
    TOTAL_LINES,
)
