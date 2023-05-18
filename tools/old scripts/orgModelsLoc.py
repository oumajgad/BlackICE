import glob
import os
import sys
import re

######### INFO ##########
# Organize models CSVs
#########################

modelCSVs = {
    "localisation/zDD-models.csv",
    "localisation/Models.csv",
    "localisation/NSM-models.csv"
}

nationModels = {}

#Load Model CSVs
for fileName in modelCSVs:
    with open(fileName, 'r', encoding="ISO-8859-1") as file:
        data = file.read()
        lines = data.split("\n")
        for line in lines:

            if "#" in line:
                continue

            parts = line.split(";")
            keys = parts[0].split("_")

            if keys[0] in nationModels.keys():
                nationModels[keys[0]][parts[0]] = parts[1]
            else:
                nationModels[keys[0]] = {}
                nationModels[keys[0]][parts[0]] = parts[1]

#Finalize Models csv
#print(nationModels)
data = ""
f = open("localisation/Models.csv", "w")
for nation, models in sorted(nationModels.items()):
    #print(models)
    f.write("##########################################################################################################;;;;;;;;;;;;;;x\n")
    for model in models:
        data = model + ";" + models[model] + ";;;;;;;;;;;;;x" + "\n"
        f.write(data)
f.close()