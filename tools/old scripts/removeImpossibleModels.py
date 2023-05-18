import glob
import os
import sys
import re

######### INFO ##########
# Remove exclusive models from countries that cant have them
#########################

saved = 0

whitelist = {
    "ss_": "GER_",

    "GER_light_transport": "GER_",
    "USA_light_transport": "USA_",
    "GER_truck_transport": "GER_",
    "USA_truck_transport": "USA_",
    "ENG_truck_transport": "ENG_",
    "FRA_truck_transport": "FRA_",
    "FRA_hftrack_transport": "FRA_",
    "GER_hftrack_transport": "GER_",
    "SOV_horse_transport": "SOV_",
    "ITA_light_transport": "ITA_",

    "Gurkha_brigade": "ENG",
    "anzac_brigade": "ENG",
    "anzac_brigade": "AST",
    "anzac_brigade": "NZL",
}

for path, subdirs, files in os.walk("units/models/"):
    for file in files:
        with open(os.path.join(path, file), 'r', encoding="ISO-8859-1") as data:
            lines = data.readlines()

            removing = False

            savedthis = 0

            for key in whitelist:

                #Check whitelisted
                if file.startswith(whitelist[key]):
                    continue

                #Remove lines with key
                for i in range(0,len(lines)):
                    if "{" in lines[i] and lines[i].startswith(key):
                        savedthis = savedthis + len(lines[i])
                        lines[i] = ""
                        removing = True
                        continue

                    if "}" in lines[i] and removing:
                        savedthis = savedthis + len(lines[i])
                        lines[i] = ""
                        removing = False
                        continue

                    if removing:
                        savedthis = savedthis + len(lines[i])
                        lines[i] = ""
                        continue

            if savedthis > 0:
                saved = saved + savedthis

                f = open(os.path.join(path, file), "r+", encoding="ISO-8859-1")
                f.seek(0)
                f.truncate()
                f.write("".join(lines))
                f.close()

print("Saved: " + str(saved))