import os
from pathlib import Path


from parser.parser_node import parse_file

if __name__ == "__main__":
    base_path = r"C:\Users\David\GitHub\BlackICE"
    for path in [
        rf"{base_path}\common\countries",
        rf"{base_path}\decisions",
        rf"{base_path}\events",
        rf"{base_path}\history",
        rf"{base_path}\units",
        rf"{base_path}\technologies",
    ]:
        for root, dirs, files in os.walk(path):
            for file in files:
                if file == "credits.txt":
                    continue
                print(Path(root).joinpath(Path(file)))
                b = parse_file(Path(root).joinpath(Path(file)))
                combat = b.find_by_key_single("combat")
                print(b)
