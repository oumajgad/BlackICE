import glob
import os
import sys
import re
import Levenshtein

######### INFO ##########
# Find typos in oob files
#########################

#Get unit names
units = []
for file in glob.glob("units/*.txt"):
    units.append(file[6:len(file)-4])

minSize = 999
for unit in units:
    if len(unit) < minSize:
        minSize = len(unit)

#Every oob file
for path, subdirs, files in os.walk("history/units/"):
    i = 0
    for file in files:
        if ".txt" in file:
            #print(str(i) + "/" + str(len(files)) + " - " + file, flush=True)
            with open(os.path.join(path, file), 'r', encoding="ISO-8859-1") as data:
                lines = data.readlines()
                for line in lines:
                    words = line.split(" ")
                    for word in words:
                        if len(word) < minSize:
                            continue
                        word = word.replace(" ", "")
                        word = word.replace("\n", "")
                        word = word.replace("\t", "")
                        word = word.replace("=", "")
                        if word in units:
                            continue
                        for unit in units:
                            similarity = Levenshtein.ratio(word, unit)
                            if similarity < 1 and similarity > 0.9: #Adjust similarity (should be fairly high for typos)
                                print("\tPotential typo: " + word + " -> " + unit + " (" + file +")", flush=True)
                                break
        i = i + 1
