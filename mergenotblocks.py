import os 

### script to merge not blocks that can be merged

def merge_not_blocks(file):

    for i in range(9):

        with open(file, "r", encoding="Windows-1252", errors="ignore") as file0:
            print("Read  - " + file0.name)
            readlines = file0.readlines()

        stage1lines = list()
        not_found = False
        i = 0
        second_not_found = False
        for line in readlines:
            i += 1
            if line.strip().startswith("#"):
                stage1lines.append(line)
                continue

            if not_found == False:
                stage1lines.append(line)
                if line.strip().startswith("not = {"):
                    not_found = True
                    continue

            if not_found == True and second_not_found == False:
                if line.strip().startswith("}") and readlines[i + 1].strip().startswith("not = {"):
                    second_not_found = True
                    continue
                else:
                    stage1lines.append(line)
                    if line.strip() == "}":
                        not_found = False
                    continue
            
            if second_not_found == True:
                if line.strip().startswith("not = {"):
                    second_not_found = False
                    not_found = False
                    continue
                    

        with open(file, "w", encoding="Windows-1252") as file4:
            print("Wrote - " + file4.name)
            file4.writelines(stage1lines)




folders = ["./events", "./decisions"]

for folder in folders:
    for path, subdirs, files in os.walk(folder):
        for file in files:
            merge_not_blocks(os.path.join(path, file))