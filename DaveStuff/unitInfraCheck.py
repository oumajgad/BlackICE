################################################################
### Searches for Units that spawn in lvl 1/0 infra provinces ###
################################################################

import os

folderUnits = "./history/units"
folderProvinces = "./history/provinces"

units = {}
provinces = {}

### Get all units + locations

for root, dirs, files in os.walk(folderUnits):
    for file in files:
        with open(os.path.join(root, file), "r", encoding="UTF-8", errors="ignore") as unit:
            for line in unit:
                if "location" in line:
                    try:
                        location = int(line.split("location")[1].split("=")[1].split("#")[0].strip().split(" ")[0].split("\t")[0])
                        units[unit.name] = location
                    except Exception as e:
                        print(f"{file:} {line}")

### Get all lvl 0/1 provinces

for root, dirs, files in os.walk(folderProvinces):
    for file in files:
        with open(os.path.join(root, file), "r", encoding="UTF-8", errors="ignore") as province:
            for line in province:
                if "infra" in line:
                    infra = int(line.split("infra")[1].split("=")[1].split("#")[0].strip())
                    if infra <= 1:
                        provinces[province.name.split("\\")[2].strip()] = infra


for infra in provinces:
    for location in units:
        if int(infra.split("-")[0].strip()) == units[location]:
            print(str(infra) + " ; " + str(location))
