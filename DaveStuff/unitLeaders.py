import os
import operator
from tkinter import *
from tkinter import scrolledtext as st

### This tool will give you a list of Leaders for a given country.

print("Getting leaders. This may take a moment.")

### Define leader class

class Leader():

    leaders = []
    def addLeader(self, name, ID, TAG, skill, maxSkill, Type, traits, list):
        self.leaders.append(self)
        self.name = name
        self.ID = ID
        self.TAG = TAG
        self.skill = skill
        self.maxSkill = maxSkill
        self.Type = Type
        self.traits = traits
        if self.ID in list:
            self.use = "Used"
        else:
            self.use = "Unused"

    @classmethod
    def get_countryleaders(self, country, fType, fTrait, optionA):
        self.country = country.upper()  #Country filter
        self.fType = fType.lower()      #Type filter
        self.traitFilter = fTrait
        self.optionA = optionA.upper()
        self.listA = []

        self.i = 0
        for self.leader in self.leaders:
            if self.country == self.leader.TAG and self.fType == self.leader.Type:
                if self.traitFilter:
                    if self.traitFilter in self.leader.traits:
                        self.listA.append(self.leader)
                        self.i += 1
                else:
                    self.i += 1
                    self.listA.append(self.leader)
            if self.country == self.leader.TAG and self.fType.lower() == "all":
                if self.traitFilter:
                    if self.traitFilter in self.leader.traits:
                        self.listA.append(self.leader)
                        self.i += 1
                else:
                    self.i += 1
                    self.listA.append(self.leader)
            else:
                continue

        self.listA.sort(key=operator.attrgetter('skill'), reverse=True)
        e_output.insert(END,str(self.i) + " Leaders\n")
        e_output.insert(END,"ID;TAG;Skill;Max Skill;Type\n")

        for self.e in self.listA:
            std = str(self.e.ID) + " " + str(self.e.TAG) + " " + str(self.e.skill) + " " + str(self.e.maxSkill) + " " + str(self.e.Type) + " " + str(self.e.use) + " " + str(self.e.name)
            if self.optionA == "Y":
                e_output.insert(END, std + " " + str(self.e.traits) + "\n" )
            else:
                e_output.insert(END,std + "\n")

### Get all the Leaders which are used in OOBs already
Used = []
folder = "./history/units"
for root, dirs, files in os.walk(folder):
    for file in files:
        with open(os.path.join(root, file), "r", encoding="UTF-8", errors="ignore") as unit:
            for line in unit:
                if "Unused" in unit.name:
                    continue

                if "leader" in line and "#" not in line.split("=")[0] and "regiment" not in line:
                    if line.split("=")[1].split("#")[0].strip() not in Used:
                        Used.append(line.split("=")[1].split("#")[0].strip())
                    else:
                        continue

found = 0
a = 0
b = 0
c = 0
d = 0
e = 0
i = 0

### Get all the Leaders of every Country.
### This approach is flawed since it takes very long on a cold start
for root, dirs, files in os.walk("./history/leaders"):
    for file1 in files:
        with open(root + "/" + file1 , "r", errors="ignore") as file:
            for line in file:
                if "= {" in line and "rank" not in line and "history" not in line and found == 0:
                    ID = line.split("=")[0].strip()
                    found = 1
                    l = i
                    i += 1
                    traits = []
                if found == 1 and a == 0 and "country" in line:
                    TAG = line.split("=")[1].strip().split(" ")[0]
                    a = 1
                if found == 1 and b == 0 and "skill" in line:
                    skill = line.split("=")[1].strip().split(" ")[0]
                    b = 1
                if found == 1 and c == 0 and "type" in line:
                    Type = line.split("=")[1].strip().split(" ")[0]
                    c = 1
                if found == 1 and d == 0 and "name" in line:
                    name = line.split("=")[1].strip()
                    if "#" in name:
                        name = name.split("#")[0].strip()
                    d = 1
                if found == 1 and e == 0 and "max_skill" in line:
                    maxSkill = line.split("=")[1].strip()
                    e = 1
                if found == 1 and "add_trait" in line:
                    line1 = line.split("trait")[1]
                    if "#" in line1:
                        traits.append(line1.split("=")[1].split("#")[0].strip())
                    else:
                        traits.append(line1.split("=")[1].strip())

                if found + a + b + c + d + e == 6 and "history" in line:
                    found = 0
                    a = 0
                    b = 0
                    c = 0
                    d = 0
                    e = 0
                    l = Leader()
                    l.addLeader(name, ID, TAG, skill, maxSkill, Type, traits, Used)

root = Tk()
root.title("unitLeaders")

RBvar = StringVar()

def parse(optionA):
    e_output.delete(1.0, END)
    tag = e_TAG.get()
    typetk = RBvar.get()
    traitfilter = e_trait.get()
    Leader.get_countryleaders(tag, typetk, traitfilter, optionA)

#Labels
label_tag = Label(root, text="Enter TAG")
label_type = Label(root, text="Select type")
label_filter = Label(root, text="Filter for a trait?")
label_traits = Label(root, text="Do you want to display traits?")

label_tag.grid(row=0, column=0)
label_type.grid(row=0, column=1 , columnspan=2)
label_filter.grid(row=0, column=3)
label_traits.grid(row=0, column=4)

#Inputs
e_TAG = Entry(root, width=25)
e_trait = Entry(root, width=25)
rb_all = Radiobutton(root, text="All", value="all" , variable=RBvar)
rb_land = Radiobutton(root, text="Land", value="land" , variable=RBvar)
rb_air = Radiobutton(root, text="Air", value="air" , variable=RBvar)
rb_sea = Radiobutton(root, text="Sea", value="sea" , variable=RBvar)

button_traits1 = Button(root, text="Yes", width=25, command= lambda: parse("y"))
button_traits2 = Button(root, text="No" , width=25, command= lambda: parse("n"))

e_TAG.grid(row=1, column=0, rowspan=2)
rb_all.grid(row=1, column=1)
rb_land.grid(row=2, column=1)
rb_air.grid(row=1, column=2)
rb_sea.grid(row=2, column=2)
e_trait.grid(row=1, column=3, rowspan=2)
button_traits1.grid(row=1, column=4)
button_traits2.grid(row=2, column=4)

e_output = st.ScrolledText(root, wrap="word", width=200, height=30, font=("Times New Roman", 10))
e_output.grid(row=3, column=0, columnspan=5)

root.mainloop()