import os
import operator

### This tool will give you a list of Leaders for a given country.


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


### Get all the Leaders a Country has

class Leader():

    leaders = []
    listA = []
    def __init__(self):
        self.leaders.append(self)
        

    def addLeader(self, name, ID, TAG, skill, Type, traits, list):
        self.name = name
        self.ID = ID
        self.TAG = TAG
        self.skill = skill
        self.Type = Type
        self.traits = traits
        if self.ID in list:
            self.use = "Used"
        else:
            self.use = "Unused"

    @classmethod
    def get_countryleaders(self, country, ftype, optionA):
        self.country = country.upper()  #Country filter
        self.ftype = ftype.lower()      #Type filter
        self.i = 0
        self.optionA = optionA.upper()
        for self.leader in self.leaders:

            if self.country == self.leader.TAG and self.ftype == self.leader.Type:
                self.i += 1
                self.listA.append(self.leader)
            if self.country == self.leader.TAG and self.ftype.lower() == "all":
                self.i += 1
                self.listA.append(self.leader)

            else:
                continue

        self.listA.sort(key=operator.attrgetter('skill'), reverse=True)
        for self.e in self.listA:
            std = str(self.e.ID) + " " + str(self.e.TAG) + " " + str(self.e.skill) + " " + str(self.e.Type) + " " + str(self.e.use) + " " + str(self.e.name)
            if self.optionA == "Y":
                print(std + " " + str(self.e.traits) )
            else:
                print(std)

        print("ID;TAG;Skill;Type")
        print(str(self.i) + " Leaders")

found = 0
a = 0
b = 0
c = 0
d = 0
i = 0

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
                    TAG = line.split(" ")[2].strip()
                    a = 1
                if found == 1 and b == 0 and "skill" in line:
                    skill = line.split(" ")[2].strip()
                    b = 1
                if found == 1 and c == 0 and "type" in line:
                    Type = line.split(" ")[2].strip()
                    c = 1
                if found == 1 and d == 0 and "name" in line:
                    name = line.split("=")[1].strip()
                    if "#" in name:
                        name = name.split("#")[0].strip()
                    d = 1
                if found == 1 and "add_trait" in line:
                    line1 = line.split("trait")[1]
                    if "#" in line1:
                        traits.append(line1.split("=")[1].split("#")[0].strip())
                    else:
                        traits.append(line1.split("=")[1].strip())
                        

                if found + a + b + c + d == 5 and "history" in line:
                    found = 0
                    a = 0
                    b = 0
                    c = 0
                    d = 0
                    l = Leader()
                    l.addLeader(name, ID, TAG, skill, Type, traits, Used)

print("Please enter the desired Countrys TAG: ")
taginput = input()
print("Please enter the desired type of leader(land, air, sea, all): ")
typeinput = input()
print("Do you want to include Traits?(Y/N)")
optionA = input()


Leader.get_countryleaders(taginput, typeinput, optionA)


os.system("pause")
