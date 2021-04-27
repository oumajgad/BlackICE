import os
from tkinter import *
from tkinter import scrolledtext as st



print("Getting Techs! This may take a moment")

class tech():

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
        self.model = []

        output_model.delete(1.0 , END)
        output_techs.delete(0 , END)
        for self.tech in self.techs:
            for self.combined_unit in self.tech.units:
                if self.combined_unit[0] == self.search_unit:
                    self.tech_counter += 1
                    self.model.append("0")
                    output_techs.insert(END , str(self.tech_counter) + " - " + self.tech.name)
    
    @classmethod
    def build_model(self, tech, level):

        if not tech:
            output_model.delete(1.0 , END)
            output_model.insert(END, self.model)
        else:
            self.tech = int(tech)
            self.level = int(level)

            self.model[self.tech-1] = self.level
            output_model.delete(1.0 , END)
            output_model.insert(END, self.model)

        


terrain_blacklist = [
    "ocean","mediterranean_sea","north_sea","arctic_sea","fiords_sea","north_atlantic","central_atlantic","south_atlantic","equator_sea","south_pacific"
    ,"north_pacific","indian_ocean","cold_coast","hot_coast","normal_coast","mountain","forest","woods","marsh","plains","urban","hills","jungle","desert"
    ,"arctic","bocage","town","fort","river","amphibious" 
    ]


### read all the techs and save them with their modified units
### in retrospect it would probably have been easier to just filter for the possible stats to change, after you have found a unit, instead of doing this
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

def build():
    tech_number = entry_tech_number.get()
    level = entry_tech_level.get()
    tech.build_model(tech_number, level)

#things
Scrollbar_techs = Scrollbar(root)
Scrollbar_techs.grid( row=2, column=1 , sticky='ns')

#Labels
label_techs = Label(root , text="Techs")
label_tech_number = Label(root , text="Tech number")
label_tech_level = Label(root , text="Level")

label_techs.grid(row = 0 , column = 0 , pady = 10 , padx = 10)
label_tech_number.grid(row = 0 , column = 3 , pady = 10 , padx = 10)
label_tech_level.grid(row = 0 , column = 4 , pady = 10 , padx = 10)

#Entries
entry_unit = Entry(root, width=30)
entry_tech_number = Entry(root, width=5)
entry_tech_level = Entry(root, width=5)

entry_unit.grid(row=1, column=2)
entry_tech_number.grid(row=1, column=3)
entry_tech_level.grid(row=1, column=4)

#Buttons
button_search = Button(root, text="Search for Unit", width=15 , command= lambda: search())
button_build = Button(root, text="Build model", width=15 , command= lambda: build())

button_search.grid(row = 0 , column = 2)
button_build.grid(row = 0 , column = 5)


#Outputs
output_techs = Listbox(root, selectmode=BROWSE, width=40, height=30, yscrollcommand=Scrollbar_techs.set)
output_model = st.ScrolledText(root, wrap="word", width=100, height=30, font=("Times New Roman", 10))

output_techs.grid(row=2, column=0)
output_model.grid(row=2, column=2, columnspan=4)

Scrollbar_techs.config(command=output_techs.yview)


root.mainloop()
