import os

###This will search for event modifiers that are given by events but dont exist in "event_modifier.txt"


modifiers = []


with open("./common/event_modifiers.txt", "r") as file:
    for line in file:
        if "=" and "{" in line:
            line = line.split("=")[0].strip()
            modifiers.append(line)

folders = ["./events" , "./decisions"]
line_found = 0
eventmods = []


for folder in folders:
    for root, dirs, files in os.walk(folder):
        #print(folder)
        for file1 in files:
            #print(file1)
            with open(root + "/" + file1 , "r", errors="ignore") as file:
                for line in file:
                    if ("add_country_modifier" in line or "add_province_modifier" in line) and "#" not in line:
                        if "name" in line:
                            eventmods.append(line.split('"')[1])
                        else:
                            line_found = 1
                            continue
                    if line_found == 1 and '"' in line:
                        eventmods.append(line.strip().split('"')[1])
                        line_found = 0
                    if line_found == 1 and '"' not in line:
                        eventmods.append(line.split("=")[1].strip())
                        line_found = 0

c_eventmods = list(dict.fromkeys(eventmods))
print("Non-existant event modifiers:\n")
for entry in c_eventmods:
    if entry not in modifiers:
        print(entry)

print("Unused event modifiers:\n")
for entry in modifiers:
    if entry not in c_eventmods:
        print(entry)