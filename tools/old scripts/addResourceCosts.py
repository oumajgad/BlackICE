import os


def whatToWrite(value: int) -> str:
    energy = value * 2
    metal = value
    rare_materials = round(value / 2)
    text = "\t\t\t\t}\n\t\t\t\tenergy = %s\n\t\t\t\tmetal = %s\n\t\t\t\trare_materials = %s\n" %(energy,metal,rare_materials)
    return text



for root, dirs, files in os.walk("./events"):
    for file in files:
        readLines = []
        writeLines = []
        with open(os.path.join(root,file), "r", encoding="ISO 8859-1") as openFile:
            readLines = openFile.readlines()
        i = 0
        found = False
        value = 0
        for line in readLines:
            if "value = +" in line and "IC_days_spent" in readLines[i-1]:
                # print(file)
                # print(readLines[i-1].strip())
                # print(readLines[i].strip())
                value = int(line.strip().split("+")[1])
                found = True
                writeLines.append(line)
            elif found == True and "}" in line:
                writeLines.append(whatToWrite(value))
                found = False
            else:
                writeLines.append(line)
            i += 1

        with open(os.path.join(root,file), "w", encoding="ISO 8859-1") as writeFile:
            writeFile.writelines(writeLines)
