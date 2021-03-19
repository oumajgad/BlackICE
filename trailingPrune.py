import glob
import os
import sys
import re

######### INFO ##########
# Prune trailing spaces
#########################

diff = 0
for path, subdirs, files in os.walk("."):
    for file in files:
        if ".txt" in file or ".gfx" in file or ".csv" in file or ".fx" in file:
            with open(os.path.join(path, file), 'r', encoding="ISO-8859-1") as data:
                lines = data.readlines()

                thisdiff = 0

                i = 0
                for line in lines:
                    s = len(lines[i])

                    lines[i] = lines[i].rstrip("\n").rstrip()

                    thisdiff = thisdiff + (s - len(lines[i]) - 1)
                    i = i + 1

                diff = diff + thisdiff

                if thisdiff > 0:
                    f = open(os.path.join(path, file), "r+", encoding="ISO-8859-1")
                    f.seek(0)
                    f.truncate()
                    f.write("\n".join(lines))
                    f.close()

print("Removed " + str(diff))