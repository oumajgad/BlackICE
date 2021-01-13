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

######### HISTORY ##########
# https://en.wikipedia.org/wiki/List_of_cruisers_of_World_War_II
# https://en.wikipedia.org/wiki/Interwar_period
# https://preview.redd.it/avt4tbn1vq001.jpg?width=941&auto=webp&s=952230271ec7c5a3a67e39efe02d48a144d6bfd8 (GDP per Capita in 1938 Europe)

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

    "chemical_engineering = 1",
    "mechanicalengineering_theory = 3",
    "construction_practical = 3",
]

#Medium Development
packs["med_dev"] = [ 
    "basic_education = 4",
    "civil_medicine = 6",

    "industral_production = 2",
    "industral_efficiency = 2",
    "coal_processing_technologies = 1",
    "steel_production = 1",
    "supply_production = 1",
    "ammo_production = 1",
    "food_rations_production = 1",

    "construction_engineering = 1",
    "advanced_construction_engineering = 1",
    "airfield_construction = 1",
    "port_construction = 1",
    "industry_tech = 2",
    "agriculture = 3",
    "railway = 1",

    "electronic_mechanical_egineering = 1",

    "electronic_engineering_theory = 1",
    "mechanicalengineering_theory = 3",
    "construction_practical = 6",
]

#Politically Agitated
packs["political_agitation"] = [
    "political_indoctrination = 1",
    "political_integration = 1",
    "partisan_suppression = 1",
    "resistance_support = 1",

    "militia_theory = 3",
    "militia_practical = 2",
]

#Mine Development (countries rich in metals have developed them a bit)
packs["mining"] = [
    "coal_processing_technologies = 1",
    "steel_production = 1",
    "raremetal_refinning_techniques = 1",

    "chemical_engineering = 3",
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

    "mobile_theory = 3"
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

    "infantry_theory = 2",
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

    "land_defence_engineering = 1",

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
    "infantry_practical = 2",
    "artillery_theory = 2",
    "artillery_practical = 1",
]

#WW1 Armor Experiments (experimented in WW1 armor)
packs["ww1_armor"] = [
    "rivetted_armour = 2",

    "steel_casting_capability = 1",

    "infantry_tank_design = 1",
    "armored_car_design = 1",

    "automotive_theory = 2",
    "automotive_practical = 0.5",
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

    "automotive_theory = 5",
    "automotive_practical = 2",
    "mechanicalengineering_theory = 5",
    "construction_practical = 4",
]

#WW1 Naval Basic
packs["ww1_naval_basic"] = [
    "destroyer_technology = 1",
    "torpedo_boat_class = 1",
    "motor_torpedo_boat_class = 1",
    "light_naval_guns = 1",
    "light_warship_engine = 1",

    "torpedo_upgrade = 1",

    "torpedo_warhead = 1",
    "torpedo_targeting = 1",
    "torpedo_propulsion = 1",

    "naval_engineering = 2",
    "destroyer_practical = 1",
]

#WW1 Naval Medium
packs["ww1_naval_med"] = [
    "lightcruiser_technology = 1",
    "light_cruiser_naval_guns = 1",
    "lightcruiser_armour_thickness = 1",
    "cruiser_engine_and_boilers = 1",
    "cruiser_screws_and_rudder_optimalisation = 1",
    "cruiser_hull_shape_optimalisation = 1",
    "cruiser_horizontal_protection_layout = 1",
    "cruiser_vertical_protection_layout = 1",
    "cruiser_hull_shape_optimalisation = 1",

    "heavy_artillery_activation = 1",

    "naval_engineering = 3",
    "destroyer_practical = 1",
    "cruiser_practical = 0.5",
]

#Interwar Naval Basic (not many applications..)

#Interwar Naval Medium
packs["interway_naval_med"] = [
    "cruiser_naval_guns_HE_ammo = 1",
    "cruiser_naval_guns_AP_ammo = 1",

    "heavycruiser_class = 1",
    "heavy_cruiser_armour_thickness = 1",
    "heavy_cruiser_naval_guns = 1",

    "naval_engineering = 4",
    "destroyer_practical = 2",
    "cruiser_practical = 1",
]

#Basic Submarine Development (Coastal)
packs["basic_submarine"] = [
    "submarine_technology = 1",

    "coastal_submarine_class = 1",

    "submarine_battery = 1",
    "submarine_engine = 1",
    "submarine_hull = 1",
    "submarine_crew_berthing = 1",
    "submarine_periscope = 1",
    "submarine_torpedo_tubes = 1",

    "torpedo_upgrade = 1",
    "submarine_torpedo = 1"
    "torpedo_warhead = 1",
    "torpedo_targeting = 1",
    "torpedo_propulsion = 1",

    "naval_engineering = 2",
    "submarine_engineering = 2",
    "submarine_practical = 1",
]

#Medium Submarine Development (ie. Netherlands)
packs["med_submarine"] = [
    "submarine_technology = 1",

    "coastal_submarine_class = 1",
    "submarine_class = 1",

    "submarine_battery = 1",
    "submarine_engine = 1",
    "submarine_hull = 1",
    "submarine_crew_berthing = 1",
    "submarine_periscope = 1",
    "submarine_torpedo_tubes = 1",

    "torpedo_upgrade = 1",
    "submarine_torpedo = 1"
    "torpedo_warhead = 1",
    "torpedo_targeting = 1",
    "torpedo_propulsion = 1",

    "naval_engineering = 3",
    "submarine_engineering = 3",
    "submarine_practical = 2",
]

#WW1 Aviation
packs["ww1_aviation"] = [
    "basic_aircraft_design = 1",

    "single_engine_airframe = 1",
    "small_fueltank = 1",
    "single_engine_aircraft_armament = 1",
    "aeroengine = 1",

    "single_engine_fighter_design = 1",
    "recon_aircraft_design = 1",

    "basic_aircraft_machinegun = 1",
    "mg_focus = 1",
    "wing_guns = 1",
    "basic_bomb = 1",

    "basic_single_engine_airframe = 1",
    "basic_small_fueltank = 1",
    "basic_aeroengine = 1",

    "aeronautic_engineering = 4"
]

#Interwar Aviation
packs["interwar_aviation"] = [
    "basic_aircraft_design = 1",

    "single_engine_airframe = 1",
    "small_fueltank = 1",
    "single_engine_aircraft_armament = 1",
    "aeroengine = 1",

    "single_engine_fighter_design = 1",
    "cas_design = 1"
    "recon_aircraft_design = 1",

    "basic_aircraft_machinegun = 1",
    "mg_focus = 2",
    "wing_guns = 1",
    "sync_machinegun = 1",
    "basic_bomb = 1",
    "small_bomb = 1",

    "basic_single_engine_airframe = 1",
    "basic_twin_engine_airframe = 1",
    "basic_small_fueltank = 1",
    "basic_medium_fueltank = 1",
    "basic_aeroengine = 1",

    "aerodynamics = 1"

    "aeronautic_engineering = 6"
]

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