import os

folder = "./events"

IDs = []

for root, dirs, files in os.walk(folder):
    for file in files:
        with open(os.path.join(folder, file), "r") as eventfile:
            for line in eventfile:
                if line.startswith("#"):
                    continue
                if "id =" in line and not "province_id" in line:
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
with open("DaveStuff/eventIDs.txt", 'w') as file:
    for ID in CIDs:
        file.write(str(ID) + "\n")

FreeID = []
a = 0
for ID in range(CIDs[0], CIDs[-1]):
    if a >= 1000:
        break
    if ID not in CIDs:
        FreeID.append(ID)
        a += 1
        if a % 20 == 0:
            FreeID.append("\n \n")

print(*FreeID)
print("Above is a list of the next 1000 free event numbers, in blocks of 20.")
print("There are currently " + str(len(CIDs)) + " Events in the Game.")
print("Check the file for taken ID numbers!")

seen = set()
for x in CIDs:
    if x in seen:
        print(f"Duplicate ID - {x}")
    seen.add(x)