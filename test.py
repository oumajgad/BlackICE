import os


for root, dirs, files in os.walk("./history/provinces"):
    for file in files:
        readLines = []
        newLines = []
        with open(os.path.join(root,file), "r") as readFile:
            readLines = readFile.readlines()
        
        for line in readLines:
            if "air_base" in line and "fake_air_base" not in line:
                level = line.split("=")[1].strip()
                newLines.append(line)
            elif "fake_air_base" in line:
                newLines.append("fake_air_base = " + level + "\n")
            else:
                newLines.append(line)
        with open(os.path.join(root,file), "w") as writeFile:
            writeFile.writelines(newLines)

