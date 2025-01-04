import json
import os
from datetime import datetime

MAX_DATE = datetime.strptime("2000.1.1", "%Y.%m.%d")
START_DATE = datetime.strptime("1936.1.1", "%Y.%m.%d")

for root, subdirs, files in os.walk("./history/leaders"):
    for file in files:
        # if not "GER - Addition" in file:
        #     continue
        # print(file)
        with open(os.path.join(root, file), "r", encoding="ISO 8859-1") as leaderfile:
            lines = leaderfile.readlines()
        writelines = []
        in_history = False
        history = []
        for i, line in enumerate(lines):
            if line.strip().startswith("#") or line.strip() == "":
                writelines.append(line)
                continue
            if "history" in line:
                # print(f"{file}:{i}: '{line}'")
                in_history = True
                history = []
                writelines.append(line)
                continue
            if in_history:
                if line.strip() == "}":
                    in_history = False
                    print(history)
                    res_entry = history[0]
                    for entry in history:
                        date = entry[0]
                        if (date >= res_entry[0] and date <= START_DATE):
                            res_entry = entry
                    print(f"{res_entry[0]} - {res_entry[1]}")
                    writelines.append(res_entry[1])
                    writelines.append(line)
                    continue
                else:
                    this_date_str = line.split("=")[0].strip()
                    # print(f"{file}:{i}: '{line}'")
                    this_date = datetime.strptime(this_date_str, "%Y.%m.%d")
                    history.append((this_date, line))
                    continue
            writelines.append(line)



        with open(os.path.join(root, file), "w", encoding="ISO 8859-1") as leaderfile:
            leaderfile.writelines(writelines)
