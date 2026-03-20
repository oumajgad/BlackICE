import os
from pathlib import Path

from parser.parser import parse_file
from parser.node import Node
from tqdm import tqdm

if __name__ == "__main__":
    path = r"C:\Users\David\GitHub\BlackICE\events"
    for root, dirs, files in os.walk(path):
        for file in files:
            print(file)
            x = parse_file(Path(root).joinpath(Path(file)))
            # print(x)
            x_node = Node.from_parsed(parsed=x)
            # print(x_node)
            nodes = x_node.find_by_key(key="controls")
            for node in nodes:
                event = node.get_parent_by_key("country_event")
                if event:
                    event_id = event.find_by_key("id")
                    if len(event_id) > 0:
                        print(event_id[0].scalar_value)
                    else:
                        print("event id not found")
                else:
                    print("event is null")
