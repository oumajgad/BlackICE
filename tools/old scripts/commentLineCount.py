import os



folders = ["./decisions", "./events"]

found_list = []

for folder in folders:
    for path, subdirs, files in os.walk(folder):
        for file in files:
            with open(os.path.join(path, file), "r", encoding="Windows-1252", errors="ignore") as file0:
                line_nr = 0
                counter = 0
                found = False
                for line in file0:
                    line_nr += 1
                    if line.strip().startswith("#"):
                        counter += 1
                        if found == False:
                            found = True
                        continue
                    else:
                        if counter >= 100:
                            found_list.append([file0.name, counter, line_nr])
                        found = False
                        counter = 0
            if counter >= 100:
                found_list.append([file0.name, counter, line_nr])
            found = False
            counter = 0


for element in found_list:
    print("file\t - \t" + str(element[0]))
    print("count\t - \t" + str(element[1]))
    print("line\t - \t" + str(element[2]))
    