import argparse
import itertools
import logging
import os
import sys

import pgzip
from dill import dumps, loads
from typeguard import typechecked

logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    stream=sys.stderr,
)

SEPARATOR = "\t"


@typechecked
def serialize(
    _dict: dict[any, any] | set[any],
    path: str,
) -> tuple[str, str | None]:
    @typechecked
    def convert_bytes(
        size: float,
    ) -> str | None:
        for x in ["bytes", "KB", "MB", "GB", "TB"]:
            if size < 1024.0:
                return f"{size:3.1f} {x}"
            size /= 1024.0
        return None

    gz_path = f"{path}.tmp"
    with open(gz_path, "wb") as file:
        file.write(pgzip.compress(dumps(_dict), compresslevel=0))
        return (
            os.path.realpath(gz_path),
            convert_bytes(os.path.getsize(gz_path)),
        )


@typechecked
def deserialize(
    path: str,
) -> any:
    with open(path, "rb") as file:
        return loads(pgzip.decompress(file.read()))


@typechecked
def print_dict_header(
    _dict: dict[any, any],
    lines: int = 10,
) -> str:
    _slice = itertools.islice(_dict.items(), lines)
    result = ""
    for key, value in _slice:
        result += f"({key}: {value}), "
    return f"{{ {result}... }}"


@typechecked
def print_set_header(
    _set: set[any],
    lines: int = 10,
) -> str:
    _slice = itertools.islice(_set, lines)
    result = ""
    for element in _slice:
        result += f"{element}, "
    return f"{{ {result}... }}"


@typechecked
def gz_file(
    path: str,
) -> str:
    if not path.endswith(".gz"):
        raise argparse.ArgumentTypeError(f"{path} not a .gz file")
    return path


@typechecked
def pkl_gz_file(
    path: str,
) -> str:
    if not path.endswith(".pkl.gz"):
        raise argparse.ArgumentTypeError(f"{path} not a .pkl.gz file")
    return path
