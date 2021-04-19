import os
from tkinter import *
from tkinter import scrolledtext as st

root = Tk()
root.title("techParser")

class tech():

    techs=[]

    def add_tech(self, tech_name, unit_effects):
        self.name = tech_name
        self.unit_effects = unit_effects


terrain_blacklist = [
    "ocean"
    ,"mediterranean_sea"
    ,"north_sea"
    ,"arctic_sea"
    ,"fiords_sea"
    ,"north_atlantic"
	,"central_atlantic"
	,"south_atlantic"
	,"equator_sea"
	,"south_pacific"
	,"north_pacific"
	,"indian_ocean"
	,"cold_coast"
	,"hot_coast"
	,"normal_coast"
    ,"mountain"
	,"forest"
	,"woods"
	,"marsh"
	,"plains"
	,"urban"
	,"hills"
	,"jungle"
	,"desert"
	,"arctic"
	,"bocage"
	,"town"
    ,"fort"
    ,"river"
    ,"amphibious"

]

for root, dirs, files in os.walk( "./technologies"):
    for file in files:
        with open(root + "/" + file , "r", errors="ignore") as file:
            i = 0   #line number
            checking = 0    #counting the { }
            unit_found = 0
            completed = 0
            modifier_found = 0
            stats = []
            modifiers = []
            terrain_modifiers = []
            for line in file:
                i += 1
                #print(line)
                for char in line:
                    #search for Tech beginning
                    if char == "{" and checking == 0 and not line.startswith("#"):          
                        tech_name = line.split("=")[0].strip()
                        checking = 1
                        print(tech_name)
                        print("techname")
                        #os.system("pause")
                        continue
                    #search for Unit beginning
                    if char == "{" and checking == 1 and unit_found == 0 and not "research_bonus_from" in line and not "allow" in line and not line.split("=")[0].strip().startswith("#"):
                        unit_found = 1
                        stats = []
                        terrain_modifiers = []
                        unit_name = line.split("=")[0].strip()
                        #print("unit found")
                        print(unit_name)
                        continue
                    #search for stat modifications
                    #fuck these filters
                    # and not  "{" in line.split("=")[line.count("=")] ---- to make sure that you arent in modifiers when it is spread over multiple lines
                    # and not line.split("{")[line.count("{")-1].replace("=","").strip() in terrain_blacklist ----- to make sure of it if you are in one line
                    x = not line.strip().startswith("#") and not  "{" in line.split("=")[line.count("=")] and not line.split("{")[line.count("{")-1].replace("=","").strip() in terrain_blacklist
                    if unit_found == 1 and char == "=" and modifier_found == 0 and checking == 1 and x:
                        stats.append( (line.split("=")[line.count("=")-1].replace("\t","").replace("{","").strip(),line.split("=")[line.count("=")].replace("\t","").replace("}","").strip()) )
                        #print(line.split("{")[line.count("{")-1].replace("=","").strip())
                        #print(stats)
                        #print(line.split("=")[line.count("=")].strip())
                        continue
                    #search for modifier beginning
                    #pretty simple, only need to look for "{" inside of your found unit
                    if unit_found == 1 and char == "{" and modifier_found == 0 and checking == 1 and not line.strip().startswith("#"):
                        modifier_found = 1
                        terrain = line.split("=")[line.count("{") - 1].strip()
                        #print(terrain)
                        continue
                    #add the modifiers to the list of modifiers
                    if modifier_found == 1 and char == "=":
                        modifiers.append( (line.split("=")[line.count("=") - 1].replace("{","").strip() , line.split("=")[line.count("=")].replace("}","").strip()) )
                        #print(modifiers)
                        continue
                    #pair the list of modifiers to the terrain
                    #clear out the list for the next terrain type
                    if modifier_found == 1 and char == "}":
                        modifier_found = 0
                        terrain_modifiers.append( (terrain, modifiers))
                        modifiers = []
                        continue
                    #close the found unit
                    if unit_found == 1 and char == "}" and checking == 1 and modifier_found == 0 and not line.strip().startswith("#"):
                        unit_found = 0
                        #checking -= 1
                        print("stats - ")
                        print(stats)
                        print("terrain - ")
                        print(terrain_modifiers)
                        print("unit discard")
                        #os.system("pause")
                        continue
                    #count {} outside of a found unit
                    if char == "}" and checking >= 1 and unit_found == 0 and not line.startswith("#"):
                        checking -= 1
                        #print("-1")
                        continue
                    if char == "{" and checking >= 1 and unit_found == 0 and not line.startswith("#"):
                        checking += 1
                        #print("+1")
                        continue



#######TODO########
# filter out "research_bonus_from = {}"
# filter out _INFO techs