import os


for root, dirs, files in os.walk("./"):
    for file in files:
        if ".txt" in file:
            z = 0
            line_nr = 0
            line_found = False
            with open(os.path.join(root,file), 'r', encoding="ISO-8859-1") as open_file:
                lines = open_file.readlines()
                for line in lines:
                    if line.strip().startswith("#"):
                        continue
                    line_nr += 1
                    for char in line:
                        if char == "{":
                            z += 1
                        if char == "}":
                            z -= 1
                    if z == -1 and line_found == False:
                        line_found = True
                        print(line_nr)
                if z != 0:
                    print(z)
                    print(open_file.name)
