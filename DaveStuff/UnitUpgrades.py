import os

#Generate Unit upgrades for A to A upgrade paths

units = []

with open("DaveStuff/upgradeswhitelist.txt", "r") as file:
    for line in file:
        line = line.split(".")
        units.append(line[0])


#print(units)
with open("DaveStuff/upgradesprint.txt", "w") as file1:
    for unit in units:
        #print(	"\tupgrade = { \n\t\tbase = " + unit + "\n\t\ttarget = " + unit + "\n\t}"
        file1.write("\n\tupgrade = { \n\t\tbase = " + unit + "\n\t\ttarget = " + unit + "\n\t}")

print("Done")
