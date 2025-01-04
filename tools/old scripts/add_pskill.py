import json
import os
import time

with open("out.txt", "r") as lf:
    leaders = json.loads(lf.read())

# print(leaders)
for root, subdirs, files in os.walk("./history/leaders"):
    for file in files:
        # if not "GER - Addition" in file:
        #     continue
        # print(file)
        with open(os.path.join(root, file), "r", encoding="ISO 8859-1") as leaderfile:
            lines = leaderfile.readlines()
        for i, line in enumerate(lines):
            if line[0].isnumeric():
                # print(line)
                leader_id = line.split("=")[0].strip()
                # print(leaders[leader_id])
                lines[i] = line + f"\tadd_trait = pskill_{leaders[leader_id]} # 'pure skill. see common/traits.txt'\n"
                del leaders[leader_id]
        with open(os.path.join(root, file), "w", encoding="ISO 8859-1") as leaderfile:
            leaderfile.writelines(lines)
