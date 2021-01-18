import glob
import os
import sys
import re

######### INFO ##########
# Country Starting Stats
#########################

#Every province oob file
TAG = sys.argv[1]
stats = {}

for txtPath, subdirs, files in os.walk("history/provinces/"):
    for txt in files:
        if ".txt" in txt:
            with open(os.path.join(txtPath, txt), 'r', encoding="ISO-8859-1") as file:
                lines = file.readlines()
                found = False
                for line in lines:
                    #Date found, stop searching
                    if line.count(".") == 2:
                        break

                    parts = line.split("=")
                    if "controller" in parts[0] or "owner" in parts[0]:
                        if TAG in parts[1]:
                            found = True
                            break

                if found:
                    for line in lines:
                        parts = line.split("=")
                        if len(parts) != 2:
                            continue
                        parts[0] = parts[0].replace("\t", "")
                        parts[0] = parts[0].replace(" ", "")
                        parts[1] = parts[1].replace(" ", "")
                        parts[1] = parts[1].replace("\n", "")
                        if parts[1].replace(".","").isnumeric():
                            if parts[0] in stats:
                                stats[parts[0]] = stats[parts[0]] + float(parts[1])
                            else:
                                stats[parts[0]] = float(parts[1])

print("\n" + TAG + " Starting Statistics\n")
for x in stats:
    print (x + " = " + str(stats[x]))