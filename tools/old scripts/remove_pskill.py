import json
import os
import time

# print(leaders)
for root, subdirs, files in os.walk("./history/leaders"):
    for file in files:
        # if not "GER - Addition" in file:
        #     continue
        # print(file)
        with open(os.path.join(root, file), "r", encoding="ISO 8859-1") as leaderfile:
            lines = leaderfile.readlines()
        writelines = []
        for i, line in enumerate(lines):
            if "pure skill. see common/traits.txt" in line:
                continue
            writelines.append(line)

        with open(os.path.join(root, file), "w", encoding="ISO 8859-1") as leaderfile:
            leaderfile.writelines(writelines)
