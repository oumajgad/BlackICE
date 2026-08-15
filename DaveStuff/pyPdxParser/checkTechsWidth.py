import json
import os
from pathlib import Path


from parser.node import Node
from parser.parser_node import parse_file


BASE_PATH = r"C:\Users\David\GitHub\BlackICE"
TECHS_PATH = r"technologies"


def get_techs() -> dict[str, Node]:
    res = {}
    for root, dirs, files in os.walk(Path(BASE_PATH).joinpath(Path(TECHS_PATH))):
        del dirs[:]  # Dont descend into subdirectories
        for file in files:
            # print(file)
            parsed = parse_file(Path(root).joinpath(Path(file)))
            for x in parsed.children:
                res[x.key] = x
    return res


if __name__ == "__main__":
    res = []
    techs = get_techs()
    for tech in techs.values():
        width_nodes = tech.find_by_key("combat_width")
        for width_node in width_nodes:
            print(f"{tech.key}: {width_node.parent.key} - {width_node.scalar_value}")
