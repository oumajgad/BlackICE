import os
from tkinter import *
from tkinter import scrolledtext as st



print("Getting Techs! This may take a moment")

class modelClass():

    models = []

    def add_model(self, nameraw, model_TAG):
        self.models.append(self)
        self.name = nameraw
        self.level = nameraw.split(".")[1]
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
    def add_unit(self, combined_unit):
        self.units.append(combined_unit)

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
    
    @classmethod
    def build_custom_model(self, level):

        if not output_techs.curselection():
            output_model.delete(1.0 , END)
            output_model.insert(END, self.model_output)
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
        self.model_lvl = model_lvl
        self.model_TAG = model_TAG
        #print(self.unit_name)
        #print(self.model_lvl)
        #print(self.model_TAG)
        #The variable of saved in the modelClass
        for self.model in modelClass.models:
            #print(self.model.unit)
            #print(self.model.level)
            #print(self.model.country)
            if self.model.unit == self.unit_name and self.model.level == self.model_lvl and self.model.country == self.model_TAG:
                for self.model_tech_tuple in self.model.techs:
                    for self.tech_list_tech in self.tech_list:
                        if self.model_tech_tuple[0] == self.tech_list_tech:
                            self.model_output[self.tech_list.index(self.tech_list_tech)] = self.model_tech_tuple[1]
                output_model.delete(1.0 , END)
                output_model.insert(END, self.model_output)

                    

        

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
                    model_tech_lvl = line.split("=")[1].strip()
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
                #print(line)
                for char in line:
                    #search for Tech beginning
                    if char == "{" and checking == 0 and not line.startswith("#"):
                        tech_name = line.split("=")[0].strip()
                        checking = 1
                        #print(tech_name)
                        #print("techname")
                        #os.system("pause")
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
                        #print("unit found")
                        continue
                    #search for stat modifications
                    #fuck these filters
                    # and not  "{" in line.split("=")[line.count("=")] ---- to make sure that you arent in modifiers when it is spread over multiple lines
                    # and not line.split("{")[line.count("{")-1].replace("=","").strip() in terrain_blacklist ----- to make sure of it if you are in one line
                    x = not line.strip().startswith("#") and not  "{" in line.split("=")[line.count("=")] 
                    y = line.split("{")[line.count("{")-1].replace("=","").strip() in terrain_blacklist
                    if unit_found == 1 and char == "=" and modifier_found == 0 and checking == 1 and x and not y:
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
                        combined_unit = ( unit_name , stats , terrain_modifiers )
                        found_units.append(combined_unit)
                        #print(unit_name)            #string
                        #print("stats - ")
                        #print(stats)                # [ ( stat , value ) , ( stat , value ) ]
                        #print("terrain - ")
                        #print(terrain_modifiers)    # [ ( terrain , [ ( stat , value ) , ( stat , value ) ] ) , ( terrain , [ ( stat , value ) , ( stat , value ) ] ) ]
                        #print("unit discard")
                        #print(combined_unit)
                        t.add_unit(combined_unit)
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

#things
Scrollbar_techs = Scrollbar(root)
Scrollbar_techs.grid( row=2, column=1 , sticky='ns')

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
output_model = st.ScrolledText(root, wrap="word", width=100, height=30, font=("Times New Roman", 10))

output_techs.grid(row=2, column=0)
output_model.grid(row=2, column=2, columnspan=5)

Scrollbar_techs.config(command=output_techs.yview)


root.mainloop()
