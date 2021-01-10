import glob
import shutil
import os
import sys

######### USAGE #########
# python techPack.py <TAG> <pack(check script)>
# ie. python techPack.py SWE armor_basic
#########################

######### INFO ##########
# Give tech packs to a nation
#########################

#TODO
packs = {}
packs["armor_basic"] = [
    "steel_casting_capability = 1",

    "light_armor_brigade_design = 1",
    "armored_car_design = 1"
]
packs["single_engine_basic"] = [
    "cas_design = 1",
]

#Find desired TAG
for path, subdirs, files in os.walk("history/countries/"):
    for file in files:
        if sys.argv[1] in file:
            with open(os.path.join(path, file), 'r', errors='ignore') as data:
                lines = data.read().split("\n")

                #Selected pack
                pack = packs[sys.argv[2]]

                #Replace if existing
                i = -1
                for l in range(0,len(lines)):
                    if len(lines[l].split("=")) != 2:
                        continue
                    for packPart in pack:
                        formatted = packPart.split("=")[0]
                        packValue = packPart.split("=")[1]
                        lineValue = lines[l].split("=")[1]
                        lineValue = lineValue.replace(" ","")
                        #Replace if found and pack is higher value
                        if lineValue.isnumeric():
                            if formatted in lines[l]:
                                if int(packValue) < int(lineValue):
                                    print("Found existing higher tech " + lines[l])
                                    i = l
                                    pack.remove(packPart)
                                    break
                                print("Found existing lower tech " + lines[l] + " => " + packPart)
                                lines[l] = packPart
                                i = l
                                pack.remove(packPart)
                                break

                #Didnt find any replaced tech yet (use oob line)
                if i == -1:
                    for l in range(0,len(lines)):
                        formatted = lines[l].split("=")[0]
                        if "oob" in formatted:
                            i = l
                            break

                #Write remaining pack techs
                for packPart in pack:
                    lines.insert(i, packPart)

                #Write new file
                f = open(os.path.join(path, file), "r+")
                f.seek(0)
                f.truncate()
                f.write("\n".join(lines))
                f.close() 