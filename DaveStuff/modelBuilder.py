import os
from tkinter import *
from tkinter import scrolledtext as st



print("Getting Techs! This may take a moment")

class modelClass():

    models = []

    def add_model(self, nameraw, model_TAG):
        self.models.append(self)
        self.name = nameraw
        self.level = int(nameraw.split(".")[1])
        self.unit = nameraw.split(".")[0]
        self.country = model_TAG
        self.techs = []

    def add_model_tech(self, tech_name, tech_lvl):
        self.tech_name = tech_name
        self.tech_lvl = tech_lvl
        self.requirement = (self.tech_name , self.tech_lvl)
        self.techs.append(self.requirement)




class tech(modelClass):

    techs=[]

    def add_tech(self, tech_name):
        self.techs.append(self)
        self.name = tech_name
        self.units = []
        self.misc = []
    def add_unit(self, combined_unit):
        self.units.append(combined_unit)    
    def add_misc(self, other):
        self.misc.append(other)

    @classmethod
    def get_techs(self, search_unit):
        self.search_unit = search_unit
        self.tech_counter = 0
        self.model_output = []
        self.tech_list = []

        output_model.delete(1.0 , END)
        output_techs.delete(0 , END)
        #Fill the tech sidebar
        for self.tech in self.techs:
            for self.combined_unit in self.tech.units:
                if self.combined_unit[0] == self.search_unit:
                    self.tech_counter += 1
                    self.model_output.append("0")
                    output_techs.insert(END , str(self.tech_counter) + " - " + self.tech.name)
                    self.tech_list.append(self.tech.name)
    
    #Show the effects of the selected tech
    @classmethod
    def update_info(self, tech_selected, unit):
        self.selection = tech_selected.split("-")[1].strip()
        self.search_unit = unit.strip()
        for self.tech in self.techs:
            if self.tech.name == self.selection:
                for self.combined_unit in self.tech.units:
                    if self.combined_unit[0] == self.search_unit:
                        output_tech_info.delete(1.0, END)
                        output_tech_info.insert(END , "\n" + str(self.tech.name) +"\n")
                        for self.thing in self.tech.misc:
                            output_tech_info.insert(END , str(self.thing[0]) + " = " + str(self.thing[1]) + "; ")
                        self.unit_name = self.combined_unit[0]
                        self.unit_stats = self.combined_unit[1]
                        self.unit_modifiers = self.combined_unit[2]
                        for self.stat in self.unit_stats:
                            output_tech_info.insert(END , "\n" + "     " + str(self.stat[0]) +" = "+ str(self.stat[1]) )
                        for self.terrain in self.unit_modifiers:
                            output_tech_info.insert(END , "\t" + str(self.terrain[0]) +" = \n" )
                            for self.modifier in self.terrain[1]:
                                output_tech_info.insert(END , "\t\t" + str(self.modifier[0]) + " = " + str(self.modifier[1]) + "\n" )

    
    @classmethod
    def build_custom_model(self, level):
        if not output_techs.curselection() or not level:
            pass
        else:
            self.tech = int(output_techs.curselection()[0])
            self.level = int(level)
            self.model_output[self.tech] = self.level
            output_model.delete(1.0 , END)
            output_model.insert(END, self.model_output)

    @classmethod
    def build_specified_model(self, unit_name, model_lvl, model_TAG):
        self.get_techs(entry_unit.get())
        #The variables we search for
        self.unit_name = unit_name
        self.model_lvl = int(model_lvl) - 1
        self.model_TAG = model_TAG.upper()

        #The variable saved in the modelClass
        for self.model in modelClass.models:
            if self.model.unit == self.unit_name and self.model.level == self.model_lvl and self.model.country == self.model_TAG:
                for self.model_tech_tuple in self.model.techs:
                    for self.tech_list_tech in self.tech_list:
                        if self.model_tech_tuple[0] == self.tech_list_tech:
                            self.model_output[self.tech_list.index(self.tech_list_tech)] = self.model_tech_tuple[1]
                output_model.delete(1.0 , END)
                output_model.insert(END, self.model_output)


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
                        t = tech()
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

def search():
    tech.get_techs(entry_unit.get())

def build_custom():
    level = entry_tech_level.get()
    tech.build_custom_model(level)

def build_specified():
    model_lvl = entry_model_lvl.get()
    unit_name = entry_unit.get()
    model_TAG = entry_TAG.get()
    tech.build_specified_model(unit_name, model_lvl, model_TAG)

def update_tech_info(not_needed):
    tech_selected = output_techs.get(ANCHOR)
    unit = entry_unit.get()
    tech.update_info(tech_selected, unit)

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
entry_tech_level = Entry(root, width=5)

entry_unit.grid(row=1, column=2)
entry_TAG.grid(row=1, column=3)
entry_model_lvl.grid(row=1, column=4)
entry_tech_level.grid(row=1, column=5)

#Buttons
button_search = Button(root, text="Search for Unit", width=15 , command= lambda: search())
button_build = Button(root, text="Change selected Tech", width=16 , command= lambda: build_custom())
button_build_specified = Button(root, text="Build model with lvl", width=15 , command= lambda: build_specified())

button_search.grid(row = 0 , column = 2)
button_build.grid(row = 0 , column = 5)
button_build_specified.grid(row = 0 , column = 4 , pady = 10 , padx = 10)

#Outputs
output_techs = Listbox(root, selectmode=BROWSE, width=40, height=30, yscrollcommand=Scrollbar_techs.set)
output_model = st.ScrolledText(root, wrap="word", width=100, height=1, font=("Times New Roman", 10), pady=5)
output_tech_info = st.ScrolledText(root, wrap="word", width=100, height=25, font=("Times New Roman", 10))

output_techs.grid(row=2, column=0, rowspan=2)
output_model.grid(row=2, column=2, columnspan=5)
output_tech_info.grid(row=3, column=2, columnspan=5)


output_techs.bind("<<ListboxSelect>>", update_tech_info)
Scrollbar_techs.config(command=output_techs.yview)


root.mainloop()
