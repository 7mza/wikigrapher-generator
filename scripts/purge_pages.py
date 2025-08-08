import argparse
import os

from commons import deserialize, logging, pkl_gz_file, print_dict_header, serialize
from tqdm import tqdm
from typeguard import typechecked

script_name = os.path.splitext(os.path.basename(__file__))[0]
logger = logging.getLogger(script_name)


@typechecked
def purge_orphan_redirectpages(
    pages: dict[str, tuple[str, bool]],
    redirects: dict,
) -> dict[str, tuple[str, bool]]:
    # remove any page marked as redirect that doesn't actually appear in redirects dump
    uniques = set(redirects.keys()).union(set(redirects.values()))
    return {
        _id: (title, is_redirect)
        for _id, (title, is_redirect) in tqdm(pages.items())
        if not (is_redirect and _id not in uniques)
    }


@typechecked
def output_pages_to_stdout(
    pages: dict[str, tuple[str, bool]],
) -> None:
    for _id, (title, is_redirect) in tqdm(pages.items()):
        print(
            "\t".join(
                [
                    _id,
                    title,
                    "redirect" if is_redirect else "page",
                ]
            )
        )


parser = argparse.ArgumentParser(description="process pages file")

parser.add_argument(
    "--PAGES_BY_IDS_PKL_FILENAME", type=pkl_gz_file, help="pages_by_ids pkl file path"
)
parser.add_argument(
    "--REDIRECTS_PKL_FILENAME", type=pkl_gz_file, help="redirects pkl file path"
)
parser.add_argument(
    "--PURGED_PAGES_PKL_FILENAME", type=pkl_gz_file, help="purged_pages pkl file path"
)

args = parser.parse_args()

PAGES_BY_IDS_PKL_FILENAME = args.PAGES_BY_IDS_PKL_FILENAME
REDIRECTS_PKL_FILENAME = args.REDIRECTS_PKL_FILENAME
PURGED_PAGES_PKL_FILENAME = args.PURGED_PAGES_PKL_FILENAME

logger.info("unpickling pages_by_ids")
pages_by_ids = deserialize(PAGES_BY_IDS_PKL_FILENAME)

logger.info("unpickling redirects")
redirects = deserialize(REDIRECTS_PKL_FILENAME)

logger.info("purging orphan redirect pages")
purged_pages = purge_orphan_redirectpages(pages_by_ids, redirects)
logger.info("purged %s pages", (len(pages_by_ids) - len(purged_pages)))

logger.info("generating pickle")
path, size = serialize(purged_pages, PURGED_PAGES_PKL_FILENAME)
logger.info("%s, %s", path, size)
logger.info("purged_pages:\n%s", print_dict_header(purged_pages))

logger.info("purged_pages > stdout")
output_pages_to_stdout(purged_pages)
