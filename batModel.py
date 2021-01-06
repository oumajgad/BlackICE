import glob
import os
import sys
import re

######### INFO ##########
# Create localisation for bat version of certain units (ie. light_armor_brigade => light_armor_bat)
# Currently only does armor units (light or normal)
#########################

files = {
    "localisation/Models.csv",
    "localisation/zDD-models.csv",
    "localisation/BlackIce_Land_SOV.csv",
    "localisation/BlackIce_Land_JAP.csv",
    "localisation/BlackIce_Land_ITA.csv",
    "localisation/BlackIce_Land_GER.csv",
    "localisation/BlackIce_Land_GER_SS.csv",
    "localisation/BlackIce_Land_FRA.csv",
    "localisation/BlackIce_Land_FRA.csv",
    "localisation/BlackIce_Land_ENG.csv",
    "localisation/BlackIce_Land_AST.csv",
    "localisation/BlackIce_Land_USA.csv",
    "localisation/BlackIce_Land_SAF.csv",
    "localisation/BlackIce_Land_Other.csv",
    "localisation/BlackIce_Land_CAN.csv",
}

whitelist = {
    "light_armor_brigade",
    "armor_brigade",
    #"infantry_brigade",
    #"elite_light_infantry"
}

blacklist = {
    "captured_armor_brigade",
    "heavy_armor",
    "super_heavy_armor_brigade",
    #"airlanding_infantry",
    #"light_infantry",
    #"naval_infantry"
}

for fileName in files:
    with open(fileName, 'r', encoding="ISO-8859-1") as file:
        data = file.read()
        lines = data.split("\n")
        finalLines = data.split("\n")
        offset = 0
        changed = False
        for j in range(0,len(lines)):
            #Found brigade
            line = lines[j]

            valid = False
            for white in whitelist:
                if white in line:
                    valid = True
            for black in blacklist:
                if black in line:
                    valid = False

            if valid:
                print("\n" + line)

                #Get sections
                parts = line.split(";")

                #Get model code
                code = parts[0]
                parts = code.split("_")

                #Get unit
                unit = parts[1:len(parts)-1]
                print(unit)

                #Construct bat version
                bat = parts[0]
                for i in range(0,len(unit) - 1):
                    bat = bat + "_" + unit[i]

                #Special case for elite_light_infantry_battalion
                if("elite_light_infantry_brigade" in line):
                    bat = bat + "_" + "battalion"
                else:
                    bat = bat + "_" + "bat"

                bat = bat + "_" + parts[len(parts)-1]
                print (bat)

                #Check bat exists already
                if bat not in data:

                    #Add localisation to bat
                    parts = line.split(";")
                    for part in range(1, len(parts)):
                        bat = bat + ";" + parts[part]
                    print(bat)

                    finalLines.insert(j + offset, bat)
                    offset = offset + 1

                    changed = True

        if changed:
            f = open(fileName, 'w', encoding="ISO-8859-1")
            f.write("\n".join(finalLines))
            f.close() 