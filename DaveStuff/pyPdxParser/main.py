import os
from pathlib import Path

from parser.parser import parse_file
from parser.node import Node
from tqdm import tqdm

if __name__ == "__main__":
    base_path = r"C:\Users\David\GitHub\BlackICE"
    for path in [
        rf"{base_path}\common\countries",
        rf"{base_path}\history",
        rf"{base_path}\decisions",
        rf"{base_path}\events",
    ]:
        for root, dirs, files in os.walk(path):
            for file in files:
                if file == "credits.txt":
                    continue
                print(Path(root).joinpath(Path(file)))
                x = parse_file(Path(root).joinpath(Path(file)))
                # print(x)
                x_node = Node.from_parsed(parsed=x)
                colors = x_node.find_by_key("color")
                print(file)
                # print(x_node)
