import glob
import shutil
import os
import sys

from itertools import product

######### INFO ##########
# Find unused OOBs
#########################

for oob in os.listdir(os.getcwd() + "/history/units/"):

    if "1936." in oob or "Unused" in oob:
        continue

    print(oob, flush=True)

    foundReference = False

    #Look for reference in events
    for event in os.listdir(os.getcwd() + "/events/"):
        if foundReference:
                break
        with open(os.path.join(os.getcwd() + "/events/", event), 'r', encoding="ISO-8859-1") as file:
            lines = file.readlines()
            for line in lines:
                if "load_oob" in line:
                    if oob.lower() in line.lower():
                        foundReference = True
                        break

    #Look for reference in decisions
    for decision in os.listdir(os.getcwd() + "/decisions/"):
        if foundReference:
            break
        with open(os.path.join(os.getcwd() + "/decisions/", decision), 'r', encoding="ISO-8859-1") as file:
            lines = file.readlines()
            for line in lines:
                if "load_oob" in line:
                    if oob.lower() in line.lower():
                        foundReference = True
                        break

    #Move to unused if not found
    if not foundReference:
        if not os.path.isdir('./history/units/Unused'):
            os.mkdir('./history/units/Unused')
        print("\tUnused, moving...", flush=True)
        shutil.move("./history/units/" + oob, "./history/units/Unused/" + oob)