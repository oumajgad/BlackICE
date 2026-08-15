import os
import time
from pathlib import Path

from tqdm import tqdm

from parser.node import Node
from parser.parser_node import parse_file

BASE_PATH = r"C:\Users\David\GitHub\BlackICE"
OOBS_PATH = r"history\units"
LEADERS_PATH = r"history\leaders"


def get_decisions() -> dict[str, Node]:
    time.sleep(0.1)
    res = {}
    events_path = rf"{BASE_PATH}\decisions"
    for root, dirs, files in os.walk(events_path):
        for file in tqdm(
            files,
            desc=f"'Parsing decisions'",
            unit=" it",
        ):
            x = parse_file(Path(root).joinpath(Path(file)))
            for diplomatic_decisions in x.children:
                diplomatic_decisions: Node
                for decision in diplomatic_decisions.children:
                    if res.get(decision.key):
                        raise Exception(f"Duplicate decision key: {decision.key}")
                    res[decision.key] = decision
    return res


def get_leaders() -> dict[str, Node]:
    res = {}
    for root, dirs, files in os.walk(Path(BASE_PATH).joinpath(Path(LEADERS_PATH))):
        del dirs[:]  # Dont descend into subdirectories
        for file in tqdm(
            files,
            desc=f"'Parsing leaders'",
            unit=" it",
        ):
            # print(file)
            parsed = parse_file(Path(root).joinpath(Path(file)))
            for leader in parsed.children:
                res[leader.key] = leader
    return res


def get_oobs() -> dict[str, Node]:
    res = {}
    all_files = []
    for root, dirs, files in os.walk(Path(BASE_PATH).joinpath(Path(OOBS_PATH))):
        for file in files:
            full_path = Path(root).joinpath(Path(file))
            all_files.append((file, full_path))

    for file in tqdm(
        all_files,
        desc=f"'Parsing OOBs'",
        unit=" it",
    ):
        parsed = parse_file(file[1])
        res[file[0]] = parsed
    return res
