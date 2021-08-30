import os
from tkinter import *
from tkinter import scrolledtext as st


print("Getting Techs! This may take a moment")


class modelClass():

    def add_model(self, nameraw:str, model_TAG:str):
        models.append(self)
        self.model_nameraw = nameraw
        self.model_level = int(nameraw.split(".")[1])
        self.model_unit_name = nameraw.split(".")[0]
        self.model_country = model_TAG.upper()
        self.model_techs = []

    def add_model_tech(self, tech_name:str, tech_lvl:int):
        tech_requirement = dict()
        tech_requirement["name"] = tech_name
        tech_requirement["level"] = tech_lvl
        self.model_techs.append(tech_requirement)

class techClass():

    def add_tech(self, tech_name:str):
        techs.append(self)
        self.tech_name = tech_name
        self.tech_units = []
        self.tech_misc = []
    def add_unit(self, combined_unit):
        self.tech_units.append(combined_unit)
        #combined_unit = ( unit_name , stats , terrain_modifiers )
    def add_misc(self, other):
        self.tech_misc.append(other)

class currentUnit():

    def __init__(self) -> None:
        self.affected_techs = []
        self.current_model_string = []
        self.current_unit_name = ""

    def get_techs(self, searched_unit_name:str):
        self.current_unit_name = searched_unit_name
        current_tech: techClass
        for current_tech in techs:
            current_tech_unit: list
            for current_tech_unit in current_tech.tech_units:
                if current_tech_unit[0] == searched_unit_name:
                    a = dict()
                    a["name"] = current_tech.tech_name
                    a["stats"] = current_tech_unit[1]
                    a["terrain"] = current_tech_unit[2]
                    a["misc"] = current_tech.tech_misc
                    self.affected_techs.append(a)
        self.fill_sidebar()
        self.build_model_string()
        self.fill_model_output()
        self.update_info()

    def fill_sidebar(self):
        output_techs.delete(0, END)
        self.tech_counter = 0
        for tech in self.affected_techs:
            self.tech_counter += 1
            output_techs.insert(END , str(self.tech_counter) + " - " + tech["name"])

    def build_model_string(self):
        for i in range(len(self.affected_techs)):
            self.current_model_string.append("0")

    def fill_model_output(self):
        output_model.delete(1.0 , END)
        output_model.insert(END, self.current_model_string)
        output_model.insert(END, "\n")
        for i in range(len(self.affected_techs)):
            output_model.insert(END, str(i+1) + "=")
            output_model.insert(END, self.current_model_string[i], ("level"))
            output_model.insert(END, " ")

    def update_info(self, tech_selected:str=None):
        if tech_selected == None:
            output_tech_info.delete(1.0, END)
        else:
            selection = tech_selected.split("-")[1].strip()
            for tech in self.affected_techs:
                if tech["name"] == selection:
                    output_tech_info.delete(1.0, END)
                    for thing in tech["misc"]:
                        output_tech_info.insert(END , str(thing[0]) + " = " + str(thing[1]) + "; ")
                    for stat in tech["stats"]:
                        output_tech_info.insert(END , "\n" + "     " + str(stat[0]) +" = "+ str(stat[1]) )
                    for terrain in tech["terrain"]:
                        output_tech_info.insert(END , "\n\t" + str(terrain[0]) +" = \n" )
                        for modifier in terrain[1]:
                            output_tech_info.insert(END , "\t\t" + str(modifier[0]) + " = " + str(modifier[1]) + "\n" )

    def build_custom_model(self, selection, level:int):
        if not selection or not level:
            pass
        else:
            tech = int(selection[0])
            level = int(level)
            self.current_model_string[tech] = level
            self.fill_model_output()

    def build_historic_model(self, searched_model_lvl:int, searched_model_TAG:str):
        model: modelClass
        for model in models:
            if model.model_country == searched_model_TAG.upper():
                if model.model_unit_name == self.current_unit_name:
                    # print(str(model.model_level) + " - " + str(searched_model_lvl))
                    # print(model.model_level == searched_model_lvl)
                    # for some reason it needs to be str() for the comparision to work
                    if str(model.model_level) == str(searched_model_lvl):
                        for model_tech in model.model_techs:
                            for unit_tech in self.affected_techs:
                                if model_tech["name"] == unit_tech["name"]:
                                    self.current_model_string[self.affected_techs.index(unit_tech)] = model_tech["level"]
        self.fill_model_output()
    


models = []
techs=[]

#Get all the models
for root, dirs, files in os.walk( "./units/models"):
    for file in files:
        with open(root + "/" + file , "r", errors="ignore") as file:
            found = 0
            for line in file:
                if "{" in line and found == 0:
                    found = 1
                    model_name_raw = line.split("=")[0].strip()
                    model_TAG = file.name.split("_")[0].split("/")[file.name.count("/")]
                    m = modelClass()
                    m.add_model(model_name_raw, model_TAG)
                if found == 1 and "=" in line and "{" not in line and not line.strip().startswith("#"):
                    model_tech_name = line.split("=")[0].strip()
                    model_tech_lvl = line.split("=")[1].strip().split("#")[0].strip()
                    m.add_model_tech(model_tech_name, model_tech_lvl)
                if found == 1 and "}" in line:
                    found = 0


### read all the techs and save them with their modified units
### in retrospect it would probably have been easier to just filter for the possible stats to change, after you have found a unit, instead of doing this
terrain_blacklist = [
    "ocean","mediterranean_sea","north_sea","arctic_sea","fiords_sea","north_atlantic","central_atlantic","south_atlantic","equator_sea","south_pacific"
    ,"north_pacific","indian_ocean","cold_coast","hot_coast","normal_coast","mountain","forest","woods","marsh","plains","urban","hills","jungle","desert"
    ,"arctic","bocage","town","fort","river","amphibious"
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
                for char in line:
                    #search for Tech beginning
                    if char == "{" and checking == 0 and not line.startswith("#"):
                        tech_name = line.split("=")[0].strip()
                        checking = 1
                        t = techClass()
                        t.add_tech(tech_name)
                        found_units = []
                        continue
                    #search for Unit beginning
                    if char == "{" and checking == 1 and unit_found == 0 and not "research_bonus_from" in line and not "allow" in line and not line.split("=")[0].strip().startswith("#"):
                        unit_found = 1
                        stats = []
                        terrain_modifiers = []
                        unit_name = line.split("=")[0].strip()
                        continue
                    #search for stat modifications
                    #fuck these filters
                    # and not  "{" in line.split("=")[line.count("=")] ---- to make sure that you arent in modifiers when it is spread over multiple lines
                    # and not line.split("{")[line.count("{")-1].replace("=","").strip() in terrain_blacklist ----- to make sure of it if you are in one line
                    x = not line.strip().startswith("#") and not  "{" in line.split("=")[line.count("=")]
                    y = line.split("{")[line.count("{")-1].replace("=","").strip() in terrain_blacklist
                    if unit_found == 1 and char == "=" and modifier_found == 0 and checking == 1 and x and not y:
                        stats.append( (line.split("=")[line.count("=")-1].replace("\t","").replace("{","").strip(),line.split("=")[line.count("=")].replace("\t","").replace("}","").strip()) )
                        continue
                    #search for modifier beginning
                    #pretty simple, only need to look for "{" inside of your found unit
                    if unit_found == 1 and char == "{" and modifier_found == 0 and checking == 1 and not line.strip().startswith("#"):
                        modifier_found = 1
                        terrain = line.split("=")[line.count("{") - 1].strip()
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
                        combined_unit = ( unit_name , stats , terrain_modifiers )
                        found_units.append(combined_unit)
                        #print(unit_name)            #string
                        #print("stats - ")
                        #print(stats)                # [ ( stat , value ) , ( stat , value ) ]
                        #print("terrain - ")
                        #print(terrain_modifiers)    # [ ( terrain , [ ( stat , value ) , ( stat , value ) ] ) , ( terrain , [ ( stat , value ) , ( stat , value ) ] ) ]
                        #print(combined_unit)
                        t.add_unit(combined_unit)
                        continue
                    #search for additional parameters
                    z = "start_year" in line or "first_offset" in line or "additional_offset" in line or "max_level" in line
                    if char == "=" and checking == 1 and unit_found == 0 and z and not line.strip().startswith("#"):
                        thing = line.split("=")[0].strip().split("#")[0]
                        value = line.split("=")[1].strip().split("#")[0]
                        t.add_misc((thing,value))
                    #count { } outside of a found unit
                    if char == "}" and checking >= 1 and unit_found == 0 and not line.strip().startswith("#"):
                        checking -= 1
                        continue
                    if char == "{" and checking >= 1 and unit_found == 0 and not line.strip().startswith("#"):
                        checking += 1
                        continue


root = Tk()
root.title("modelBuilder")

class User():

    def search(self):
        self.current_unit = currentUnit()
        self.current_unit.get_techs(entry_unit.get())

    def build_custom(self):
        level = entry_tech_level.get()
        selection = output_techs.curselection()
        self.current_unit.build_custom_model(selection, level)

    def build_historic(self):
        model_lvl = entry_model_lvl.get().strip()
        model_TAG = entry_TAG.get()
        self.current_unit.build_historic_model(model_lvl, model_TAG)

    def update_tech_info(self, event):
        if output_techs.get(ANCHOR):
            tech_selected = output_techs.get(ANCHOR)
            self.current_unit.update_info(tech_selected)


u = User()
#things
Scrollbar_techs = Scrollbar(root)
Scrollbar_techs.grid( row=2, column=1 , rowspan=2, sticky='ns')

#Labels
label_techs = Label(root , text="Techs")
label_model_tag = Label(root , text="Enter TAG for the model")

label_techs.grid(row = 0 , column = 0 , pady = 10 , padx = 10)
label_model_tag.grid(row = 0 , column = 3 , pady = 10 , padx = 10)

#Entries
entry_unit = Entry(root, width=30)
entry_TAG = Entry(root, width=5)
entry_model_lvl = Entry(root, width=5)
entry_model_lvl.insert(-1, "1")
entry_tech_level = Entry(root, width=5)

entry_unit.grid(row=1, column=2)
entry_TAG.grid(row=1, column=3)
entry_model_lvl.grid(row=1, column=4)
entry_tech_level.grid(row=1, column=5)

#Buttons
button_search = Button(root, text="Search for Unit", width=15 , command= lambda: u.search())
button_build = Button(root, text="Change selected Tech", width=16 , command= lambda: u.build_custom())
button_build_specified = Button(root, text="Build model with lvl", width=15 , command= lambda: u.build_historic())

button_search.grid(row = 0 , column = 2)
button_build.grid(row = 0 , column = 5)
button_build_specified.grid(row = 0 , column = 4 , pady = 10 , padx = 10)

#Outputs
output_techs = Listbox(root, selectmode=BROWSE, width=40, height=30, exportselection=FALSE, yscrollcommand=Scrollbar_techs.set)
output_model = st.ScrolledText(root, wrap="word", width=150, height=3, font=("Times New Roman", 12), pady=5)
output_tech_info = st.ScrolledText(root, wrap="word", width=150, height=20, font=("Times New Roman", 12))
output_model.tag_configure("level", background="black", foreground="red")

output_techs.grid(row=2, column=0, rowspan=2)
output_model.grid(row=2, column=2, columnspan=5)
output_tech_info.grid(row=3, column=2, columnspan=5)


output_techs.bind("<<ListboxSelect>>", u.update_tech_info)
Scrollbar_techs.config(command=output_techs.yview)


root.mainloop()