import os


### A one time script used to add resource costs to the IC maluses given by event OOBs



for root, subdirs, files in os.walk("./events"):
    for file1 in files:
        found = 0
        IC5 = 0
        IC10 = 0
        IC15 = 0
        IC20 = 0
        IC25 = 0
        IC30 = 0
        IC40 = 0
        i = -1
        with open(os.path.join(root, file1), "r", encoding="ISO 8859-1", errors="ignore") as file:
            lines_list = file.readlines()

        for line in lines_list:
            i += 1
            if found == 0:
                if "spawn_penalty" in line and "IC" in line:
                    if "5IC" in line:
                        found = 1
                        IC5 = 1
                        continue
                    if "10IC" in line:
                        found = 1
                        IC10 = 1
                        continue
                    if "15IC" in line:
                        found = 1
                        IC15 = 1
                        continue
                    if "20IC" in line:
                        found = 1
                        IC20 = 1
                        continue
                    if "25IC" in line:
                        found = 1
                        IC25 = 1
                        continue
                    if "30IC" in line:
                        found = 1
                        IC30 = 1
                        continue
                    if "40IC" in line:
                        found = 1
                        IC40 = 1
                        continue
            if found == 1:
                if "}" in line:
                    found = 0
                    if IC5 == 1:
                        lines_list[i] = "\t\t\t\t}\n\t\t\t\tenergy = -1100\n\t\t\t\tmetal = -550\n\t\t\t\trare_materials = -275\n"
                        IC5 = 0
                    if IC10 == 1:
                        lines_list[i] = "\t\t\t\t}\n\t\t\t\tenergy = -2200\n\t\t\t\tmetal = -1100\n\t\t\t\trare_materials = -550\n"
                        IC10 = 0
                    if IC15 == 1:
                        lines_list[i] = "\t\t\t\t}\n\t\t\t\tenergy = -3300\n\t\t\t\tmetal = -1650\n\t\t\t\trare_materials = -825\n"
                        IC15 = 0

                    if IC20 == 1:
                        lines_list[i] = "\t\t\t\t}\n\t\t\t\tenergy = -4400\n\t\t\t\tmetal = -2200\n\t\t\t\trare_materials = -1100\n"
                        IC20 = 0

                    if IC25 == 1:
                        lines_list[i] = "\t\t\t\t}\n\t\t\t\tenergy = -5500\n\t\t\t\tmetal = -2750\n\t\t\t\trare_materials = -1375\n"
                        IC25 = 0

                    if IC30 == 1:
                        lines_list[i] = "\t\t\t\t}\n\t\t\t\tenergy = -6600\n\t\t\t\tmetal = -3300\n\t\t\t\trare_materials = -1650\n"
                        IC30 = 0

                    if IC40 == 1:
                        lines_list[i] = "\t\t\t\t}\n\t\t\t\tenergy = -8800\n\t\t\t\tmetal = -4400\n\t\t\t\trare_materials = -2200\n"
                        IC40 = 0


        with open(os.path.join(root, file1), "w", encoding="ISO 8859-1", errors="ignore") as file:
            file.writelines(lines_list)
