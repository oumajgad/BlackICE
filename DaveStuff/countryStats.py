import os
from tkinter import *
from tkinter import scrolledtext as st

######### INFO ##########
# Country Starting Stats
#########################

military_buildings = ["air_base", "anti_air", "desperate_defence", "fortress", "land_fort", "naval_base", "coastal_fort", "beach_defence"]
industrial = ["artillery_factory", "automotive_factory", "capital_ship_shipyard", "heavy_aircraft_factory", "light_aircraft_factory", "medium_aircraft_factory", "medium_ship_shipyard",
                "small_ship_shipyard", "smallarms_factory", "submarine_shipyard", "tank_factory"]
other_industry = ["industry", "military_college", "police_station", "rail_terminous", "research_lab", "supplies_factory"]
resources = ["energy", "metal", "rare_materials", "crude_oil"]
strategic_resources = ["chromite_building", "aluminium_building" , "rubber_building" , "tungsten_building" , "uranium_building" , "gold_building" , "nickel_building" ,
                         "copper_building" , "zinc_building" , "manganese_building" , "molybdenum_building" , "graphite_nuclear_reactor", "heavy_water_nuclear_reactor"]


#Every province oob file


def getStats():
    TAG = e_TAG.get().upper()
    stats = {}
    buildings = { "heavy_industry": 0.25 , "steel_factory": 0.25 , "coal_mining": 0.25 , "sourcing_rares": 0.25 , "oil_well": 0.3 }

    for txtPath, subdirs, files in os.walk("history/provinces/"):
        for txt in files:
            with open(os.path.join(txtPath, txt), 'r', encoding="ISO-8859-1") as file:
                lines = file.readlines()
                found = False
                for line in lines:
                    #Date found, stop searching
                    if line.count(".") >= 2 and "#" not in line:
                        break

                    parts = line.split("=")
                    if  "owner" in parts[0]:
                        if TAG in parts[1] or TAG == "ALL":
                            found = True
                            break

                if found:
                    local = {}
                    for line in lines:

                        parts = line.split("=")     #Parts[0] is the Building/resource, Parts[1] the amount
                        if len(parts) != 2:
                            continue

                        parts[0] = parts[0].strip()
                        parts[1] = parts[1].strip()
                        if "#" in parts[0]:         #Filter commented lines
                            continue
                        if parts[1].replace(".","").isnumeric():
                            local[parts[0]] = float(parts[1])
                        if "#" in parts[1] and parts[0].count(".") < 2:
                            local[parts[0]] = float(parts[1].split("#")[0])


                    for key in local:
                        #check for resource buildings
                        if key in buildings:
                            print(file.name)
                            if key == "heavy_industry":
                                local["industry"]       += local["industry"] * ( local[key] * buildings[key] )
                            if key == "steel_factory":
                                local["metal"]          += local["metal"] * ( local[key] * buildings[key] )
                            if key == "coal_mining":
                                local["energy"]         += local["energy"] * ( local[key] * buildings[key] )
                            if key == "sourcing_rares":
                                local["rare_materials"] += local["rare_materials"] * ( local[key] * buildings[key] )
                            if key == "oil_well":
                                local["crude_oil"]      += local["crude_oil"] * ( local[key] * buildings[key] )

                    for key in local:
                        #add to overall stats
                        if key in stats:
                            stats[key] = stats[key] + local[key]
                        else:
                            stats[key] = local[key]

                    #if "small_ship_shipyard" in local:
                    #    print(file.name)
                    #    print(local["small_ship_shipyard"])

    e_output.delete(1.0, END)
    e_output.insert(END,"The resource value include potential local resource buildings!\n")
    e_output.insert(END,"\n" + TAG + " Starting Statistics\n" + "\n")
    sortedStats = dict( sorted(stats.items(), key=lambda x: x[0].lower()) )

    e_output.insert(END, "\n### Military Buildings ###\n")
    for x in sortedStats:
        if x in military_buildings:
            e_output.insert(END, x + " = " + str(round(sortedStats[x], 3)) + "\n")
    e_output.insert(END, "\n### Military Industry ###\n")
    for x in sortedStats:
        if x in industrial:
            e_output.insert(END, x + " = " + str(round(sortedStats[x], 3)) + "\n")
    e_output.insert(END, "\n### Mixed Industry ###\n")
    for x in sortedStats:
        if x in other_industry:
            e_output.insert(END, x + " = " + str(round(sortedStats[x], 3)) + "\n")
    e_output.insert(END, "\n### Resources ###\n")
    for x in sortedStats:
        if x in resources:
            e_output.insert(END, x + " = " + str(round(sortedStats[x], 3)) + "\n")
    e_output.insert(END, "\n### Strategic Resources ###\n")
    for x in sortedStats:
        if x in strategic_resources:
            e_output.insert(END, x + " = " + str(round(sortedStats[x], 3)) + "\n")
    e_output.insert(END, "\n### Misc ###\n")
    for x in sortedStats:
        if x not in military_buildings and x not in industrial and x not in other_industry and x not in resources and x not in strategic_resources:
            e_output.insert(END, x + " = " + str(round(sortedStats[x], 3)) + "\n")



root = Tk()
root.title("countryStats")



#Define
label_tag = Label(root, text="Enter TAG\n Type all for world stats")
disc_tag = Label(root, text="Disclaimer!: These values are a little below the values you will see ingame.\n This is most likely due to some hidden bonuses give by the .exe")
e_TAG = Entry(root, width=25)
b_get = Button(root, text="Get Stats", width=25, command=lambda: getStats())

#Call
label_tag.grid(row=0, column=0)
disc_tag.grid(row=0, column=1)
e_TAG.grid(row=1, column=0)
b_get.grid(row=1, column=1)

e_output = st.ScrolledText(root, wrap="word", width=75, height=50, font=("Times New Roman", 10))
e_output.grid(row=2, column=0, columnspan=3)



root.mainloop()