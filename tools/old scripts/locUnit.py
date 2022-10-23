import glob
import os
import sys
import re

######### INFO ##########
# Find units lacking localisation or with number in name (causes issues)
#########################

# Get unit names
units = []
for file in glob.glob("units/*.txt"):
    units.append((file[6:len(file)-4], False))

# Look for localisation
for path, subdirs, files in os.walk("localisation/"):
    for file in files:
        if ".csv" in file:
            #print(file, flush=True)
            with open(os.path.join(path, file), 'r', encoding="ISO-8859-1") as data:
                lines = data.readlines()
                for line in lines:

                    # Reference
                    words = line.split(";")
                    reference = words[0]

                    # Check with units
                    for i in range(len(units)):
                        if str(units[i][0]).casefold() == str(reference).casefold():
                            units[i] = (units[i][0], True)

# Check failed localisation
print("\nUNITS WITHOUT LOCALISATION:\n")
for unit in units:
    if unit[1] == False:
        print(unit[0])

# Check units with number in name
print("\nUNITS WITH NUMBERS (CAUSES PROBLEMS):\n")
for unit in units:
    if "0" in unit[0] or "1" in unit[0] or "2" in unit[0] or "3" in unit[0] or "4" in unit[0] or "5" in unit[0] or "6" in unit[0] or "7" in unit[0] or "8" in unit[0] or "9" in unit[0]:
        print(unit[0])