import os
import time

folder = "D:\GitHub\BlackICE\events"

IDs = []

for root, dirs, files in os.walk(folder):
    for file in files:
        with open(os.path.join(folder, file), "r") as eventfile:
            for line in eventfile:
                if "id =" in line:
                    split_line = line.strip().split("=")[1]
                    if "#" in split_line:
                        IDs.append(split_line.strip().split("#")[0])
                    else:
                        IDs.append(split_line)

CIDs = []
for ID in IDs:
    ID = ID.replace(" ", "")
    if ID.isnumeric():
        ID = int(ID)
        CIDs.append(ID)
    else:
        continue
CIDs.sort()
with open("eventIDs.txt", 'w') as file:
    for ID in CIDs:
        file.write(str(ID) + "\n")

print(str(len(CIDs)) + " Events in the Game")

print("Check the file for taken ID numbers!")
time.sleep(5)