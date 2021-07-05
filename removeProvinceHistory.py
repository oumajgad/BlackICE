import os

folder = "./history/provinces"

for root, dirs, files in os.walk(folder):
    for file in files:
        with open(os.path.join(root, file), "r", encoding="ISO 8859-1", errors="ignore") as provincefile:
            lines = provincefile.readlines()

        found = 0
        dateindex = 0
        for line in lines:
            if line.strip().split(".")[0].startswith("19") and found == 0:
                found = 1
                print(line)
                dateindex = lines.index(line)
                print(dateindex)
                break
        if found == 1:
            lines = lines[:dateindex]
            print(lines)
            found = 0
        # else:
        #     print("No Date")

        with open(os.path.join(root, file), "w", encoding="ISO 8859-1", errors="ignore") as provincefile:
            provincefile.writelines(lines)
