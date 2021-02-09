import os

### This will find event OOBs which are loaded into the Construction Queue.

folder = "./history/units"
aux = ["auxhigh.txt", "auxlow.txt", "auxmedium.txt",]
fList = []
for root, dirs, files in os.walk(folder):
    for file in files:
        with open(os.path.join(root, file), "r", encoding="UTF-8", errors="ignore") as unit:
            for line in unit:
                if file in aux:
                    continue

                elif "military_construction" in line:
                    if unit.name not in fList:
                        print(unit.name)
                        fList.append(unit.name)
                    else:
                        continue


with open("ProdQuUnits.txt", "w") as file:
    for unit in fList:
        file.write(str(unit) + "\n")


os.system("pause")