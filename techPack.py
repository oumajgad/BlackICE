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

#Tech packs
packs = {}

#Low Development (still over very low development countries that dont even have these)
packs["low_dev"] = [ 
    "basic_education = 2",
    "civil_medicine = 3",

    "industral_production = 1",
    "coal_processing_technologies = 1",
    "supply_production = 1",

    "construction_engineering = 1",
    "industry_tech = 1",
    "agriculture = 1",

    "mechanicalengineering_theory = 3",
    "construction_practical = 3",
]

#Mine Development (countries rich in metals have developed it a bit)
packs["mining"] = [
    "coal_processing_technologies = 1",
    "steel_production = 1",
    "raremetal_refinning_techniques = 1",

    "chemical_engineering = 4",
]

#Oil Development (countries rich in oil have developed it a bit)
packs["oil"] = [
    "oil_refinning = 1",

    "chemical_engineering = 2",
]

#Automotive Industry (countries that have developed an automotive industry, ie.Romania)
packs["automotive"] = [
    "semi_motorization = 1",
    "Vehicle_reliability = 1",
    "motorcycle_recon_brigade_activation = 1",

    "road_highway = 1",
]

#Electronics edge  (developed electronics in Interwar)
packs["electronic_edge"] = [
    "electronic_mechanical_egineering = 1",
    "radio_technology = 1",

    "electronic_engineering_theory = 3",
    "electronic_engineering_practical = 1",
]

#Mountain pack (countries with mountainous geography)
packs["mountain"] = [
    "mountain_infantry = 1",
    "mountain_warfare_equipment = 1",
    "mountain_training = 1",
    "engineer_brigade_activation = 1",
    "special_forces_upgrade = 1",
]

#WW1 Experience (fought in WW1) (only doctrine and few advancements)
packs["ww1_exp"] = [
    "civil_medicine = 3",

    "ww1_warfare = 2",
    "artillery_barrage = 1",
    "cavalry_pursuit_tactics = 1",

    "brigade_command_structure = 1",
    "divisonal_command_structure = 1",

    "infantry_training = 1",
    "infantry_command_and_control = 1",

    "ammo_production = 1",

    "infantry_theory = 2",
]

#Interwar Experience (fought during Interwar, ie.Poland) (doctrine and some equipment modernization)
packs["interwar_exp"] = [
    "smallarms_technology = 1",
    "infantry_support = 1",
    "infantry_guns = 1",
    "infantry_at = 1",

    "range_finding = 1",
    "artillery_activation = 1",

    "civil_medicine = 4",

    "ww1_warfare = 3",
    "artillery_barrage = 1",
    "cavalry_pursuit_tactics = 2",

    "brigade_command_structure = 1",
    "divisonal_command_structure = 1",

    "infantry_training = 1",
    "infantry_command_and_control = 1",

    "artillery_training = 1",

    "ammo_production = 1",
    "food_rations_production = 1",

    "infantry_theory = 4",
    "artillery_theory = 2",
]

#WW1 Armor Experiments (experimented in WW1 armor)
packs["ww1_armor"] = [
    "rivetted_armour = 2",

    "steel_casting_capability = 1",

    "infantry_tank_design = 1",
    "armored_car_design = 1",

    "automotive_theory = 2",
]

#Interwar Armor Development (developed armor significantly in Interwar, ie. Sweden)
packs["interwar_armor"] = [
    "rivetted_armour = 5",

    "industral_production = 1",
    "industral_efficiency = 1",

    "steel_casting_capability = 2",
    "steel_electro_welding_technology = 1",

    "construction_engineering = 1",
    "industry_tech = 2",

    "small_calibre_gun_design = 1",

    "tank_chassis_design = 1",

    "infantry_tank_design = 1",
    "armored_car_design = 1",

    "automotive_theory = 6",
    "mechanicalengineering_theory = 5",
    "construction_practical = 5",
]

#Politically Agitated
packs["political_agitation"] = [
    "political_indoctrination = 1",
    "political_integration = 1",
    "partisan_suppression = 1",
    "resistance_support = 1",

    "militia_theory = 3",
]

#TODO PACKS
# WW1 Naval Basic (include heavy arty tech) (no AA ship tech)
# WW1 Naval Capital (includes lighter ship tech) (include heavy arty tech) (no AA ship tech) (remember heavy armor forging)
# Interwar Naval Basic (include heavy arty tech)
# Interwar Naval Capital (includes lighter ship tech) (include heavy arty tech) (remember heavy armor forging)
# Interwar Naval Aircraft Carrier
# WW1 Submarine development (no AA sub tech)
# Interwar Submarine development
# WW1 Aviation (just single engine)
# Interwar Aviation (variants per engine number)

#Find desired TAG
for path, subdirs, files in os.walk("history/countries/"):
    for file in files:
        if sys.argv[1] in file:
            with open(os.path.join(path, file), 'r', errors='ignore') as data:
                lines = data.read().split("\n")

                #Selected pack
                pack = packs[sys.argv[2]]

                #Remove pack parts already defined with higher value
                for l in range(0,len(lines)):
                    
                    #Found date, break
                    if lines[l].count(".") >= 2:
                        #print(l)
                        break

                    #Ignore sub groups (ie. organization)
                    if len(lines[l].split("=")) != 2:
                        continue

                    for packPart in pack:
                        formatted = packPart.split("=")[0]
                        packValue = packPart.split("=")[1]
                        lineValue = lines[l].split("=")[1]
                        lineValue = lineValue.replace(" ","")
                        if lineValue.isnumeric():
                            if formatted in lines[l]:
                                if int(packValue) < int(lineValue):
                                    print("Found existing higher tech " + lines[l])
                                    pack.remove(packPart)
                                    break

                #Write tech pack at end of file
                lines.append("\n# Tech Pack: " + sys.argv[2])
                for packPart in pack:
                    lines.append(packPart)

                #Write new file
                f = open(os.path.join(path, file), "r+")
                f.seek(0)
                f.truncate()
                f.write("\n".join(lines))
                f.close() 