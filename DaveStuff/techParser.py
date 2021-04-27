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

    def print_units(self):
        for unit in self.units:
            print(unit[0])

    @classmethod
    def get_techs(self, search_unit, presentation, selection):

        self.search_unit = search_unit
        self.presentation = presentation
        self.selection = selection
        self.tech_counter = 0

        Output_effects.delete(1.0 , END)
        if self.presentation == "all":
            self.tech_counter = 0
            Output_techs.delete(0 , END)
            for self.tech in self.techs:
                for self.combined_unit in self.tech.units:
                    if self.combined_unit[0] == self.search_unit:
                        self.tech_counter += 1
                        Output_techs.insert(END , self.tech.name)
                        Output_effects.insert(END , "\n" + str(self.tech_counter) + " - " + str(self.tech.name) +"\n")
                        self.unit_name = self.combined_unit[0]
                        self.unit_stats = self.combined_unit[1]
                        self.unit_modifiers = self.combined_unit[2]
                        for self.stat in self.unit_stats:
                            Output_effects.insert(END , "     " + str(self.stat[0]) +" = "+ str(self.stat[1]) +"\n")
                        for self.terrain in self.unit_modifiers:
                            Output_effects.insert(END , "\t" + str(self.terrain[0]) +" = \n" )
                            for self.modifier in self.terrain[1]:
                                Output_effects.insert(END , "\t\t" + str(self.modifier[0]) + " = " + str(self.modifier[1]) + "\n" )

        if self.presentation == "selected":
            for self.tech in self.techs:
                if self.tech.name == self.selection:
                    for self.combined_unit in self.tech.units:
                        if self.combined_unit[0] == self.search_unit:
                            Output_effects.insert(END , "\n" + str(self.tech.name) +"\n")
                            self.unit_name = self.combined_unit[0]
                            self.unit_stats = self.combined_unit[1]
                            self.unit_modifiers = self.combined_unit[2]
                            for self.stat in self.unit_stats:
                                Output_effects.insert(END , "     " + str(self.stat[0]) +" = "+ str(self.stat[1]) +"\n")
                            for self.terrain in self.unit_modifiers:
                                Output_effects.insert(END , "\t" + str(self.terrain[0]) +" = \n" )
                                for self.modifier in self.terrain[1]:
                                    Output_effects.insert(END , "\t\t" + str(self.modifier[0]) + " = " + str(self.modifier[1]) + "\n" )


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
root.title("techParser")

RBvar = StringVar()

def search(selection):
    presentation = RBvar.get()
    unit_name = Entry_unit.get()
    selection = Output_techs.get(ANCHOR)
    tech.get_techs(unit_name, presentation, selection)

#things
Scrollbar_techs = Scrollbar(root)
Scrollbar_techs.grid( row=3, column=1 , sticky='ns')

#Labels
Label_techs = Label(root, text="Related techs")
Label_unit = Label(root, text="Enter unit name")

Label_techs.grid(row=0, column=0)
Label_unit.grid(row=0, column=2)

#Entries
Entry_unit = Entry(root, width=50)

Entry_unit.grid(row=1, column=2)

#Buttons
Radiobutton_all = Radiobutton(root, text="All", value="all" , variable=RBvar)
Radiobutton_selected = Radiobutton(root, text="Selected", value="selected" , variable=RBvar)
Button_search = Button(root, text="search", width=15 , command= lambda: search(0))

Radiobutton_all.grid(row=1, column=0)
Radiobutton_selected.grid(row=2, column=0)
Button_search.grid(row=1, column=3)

#Outputs
Output_techs = Listbox(root, selectmode=BROWSE, width=30, height=30, yscrollcommand=Scrollbar_techs.set)
Output_effects = st.ScrolledText(root, wrap="word", width=100, height=30, font=("Times New Roman", 10))

Output_techs.grid(row=3, column=0)
Output_effects.grid(row=3, column=2, columnspan=2)

Output_techs.bind("<<ListboxSelect>>", search)
Scrollbar_techs.config(command=Output_techs.yview)


root.mainloop()