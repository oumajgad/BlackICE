import os

### script to enforce some a general indentation
### this makes a newline after every "{" or "}" and makes sure that lines are indentet properly


### How to use
### 1. Run first time
### 2. Run second time
### 3. Run tailingprune..py


def run_script():

    folders = ["./events", "./decisions"]

    readlines = list()
    for folder in folders:
        for path, subdirs, files in os.walk(folder):
            for file in files:
                for i in range(4):
                    with open(os.path.join(path, file), "r", encoding="Windows-1252", errors="ignore") as file0:
                        print("Read  - " + file0.name)
                        readlines = file0.readlines()

                    # Stage 1
                    # Every line gets checked for { or }
                    # every character except empty ones get added to a templine, so in the end we have a list with lines as elements
                    # but in those elements we can have multiple \n's
                    # to get the line split along those stage 2 happens
                    stage1lines = list()
                    for line in readlines:
                        if line.strip().startswith("#"):
                            stage1lines.append(line.lstrip())
                            continue
                        templine = list()
                        nfound = 0
                        for char in line.strip(" "):
                            if char == "{":
                                templine.append(str(char + "\n" ))
                                nfound = 1
                                continue
                            if char == "}":
                                templine.append(str("\n" + char))
                                if i >= 2 and len(line.split("}")[1]) >= 4:
                                    templine.append("\n")
                                continue
                            else:
                                if char == "\t":
                                    templine.append(" ")
                                    continue
                                if nfound == 1 and char == " ":
                                    continue
                                if nfound == 1 and char != " ":
                                    nfound = 0
                                templine.append(char)

                        stage1lines.append("".join(templine))


                    # Stage 2
                    # Write the lines out in a file and read them again so all the \n have made a new entry into the list.
                    # awful hack, someone tell me a better way pls
                    stage2lines = list()
                    for line in stage1lines:
                        stage2lines.append(line.strip(" "))


                    with open("output.txt", "w") as file1:
                        file1.writelines(stage2lines)

                    # Stage 3
                    with open("output.txt", "r") as file2:
                        stage3lines = file2.readlines()


                    # Stage 4
                    # go through the lines, now nicely spereated. each line only has 1 \n at most
                    # count the { } and add \t as needed
                    # "not = {" doesnt get caught earlier so now it does here
                    # if there is on in a line the line has to be split along it
                    stage4lines = list()
                    count = 0
                    for line in stage3lines:
                        if line.strip().startswith("#"):
                            stage4lines.append((count * "\t") + line)
                            continue

                        if "{" in line:
                            if "not" in line:
                                stage4lines.append((count * "\t") + line.split("not")[0])
                                stage4lines.append("\n" + (count * "\t") + "not" + str(line.split("not")[1]))
                                count += 1
                                continue
                            elif "NOT" in line:
                                stage4lines.append((count * "\t") + line.split("NOT")[0])
                                stage4lines.append("\n" + (count * "\t") + "not" + str(line.split("NOT")[1]))
                                count += 1
                                continue
                            else:
                                stage4lines.append((count * "\t") + str(line))
                                count += 1
                                continue
                        if "}" in line:
                            if len(line.strip()) > 1:
                                count += -1
                                stage4lines.append((count * "\t") + str("}") + "\n"+ (count * "\t") + line.split("}")[1].strip() + "\n" )
                                continue
                            else:
                                count += -1
                                stage4lines.append((count * "\t") + str(line))
                                continue
                        elif line.count("=") == 1:
                            stage4lines.append((count * "\t") + line)
                        elif line.count("=") >= 1:
                            i = 0
                            comment_case = False
                            for char in line:       # If we have the 2nd "=" in a comment we need to check if we dont need to split the line
                                if char == "=":
                                    i += 1
                                    continue
                                if char == "#" and i <= 1:
                                    stage4lines.append((count * "\t") + line)
                                    i = 0
                                    comment_case = True
                                    break
                            if comment_case == False:
                                templine = list()
                                i = 1
                                for x in line.split("="):
                                    x = x.strip().split(" ")
                                    for y in x:
                                        if y == '':
                                            continue
                                        if y != '':
                                            i += 1
                                            if (i % 2) == 0:
                                                templine.append((count * "\t") + y + " = ")
                                            else:
                                                templine.append( y +"\n")
                                z = "".join(templine)
                                stage4lines.append(z)


                    ### Note to future self
                    # If you want to add another step to filter more i recommend to write and read from file again so 
                    # all the \n from the previous step get seperated into different list elements

                    # Stage 5
                    # check for empty lines again
                    stage5lines = list()
                    for line in stage4lines:
                        if line.strip() == "":
                            continue
                        else:
                            stage5lines.append(line)

                    with open("output.txt", "w") as file4:
                        file4.writelines(stage5lines)

                    # Stage 6/7
                    # deal with some stupid things
                    with open("output.txt", "r") as file5:
                        stage6lines = file5.readlines()

                    stage7lines = list()
                    for line in stage6lines:
                        if line.count("=") >= 2 and not line.strip().startswith("#") and i >= 2:
                            print(line)
                            left_part = line.split("=")[0] + "="
                            middle_part = line.split("=")[1]
                            right_part = "=" + line.split("=")[2]
                            middle_left = middle_part.strip().split(" ")[0]
                            middle_right = middle_part.strip().split(" ")[1]
                            
                            new_line = left_part + middle_left + "\n" + middle_right + right_part

                            stage7lines.append(new_line)
                            continue
                        else:
                            stage7lines.append(line)


                    with open(os.path.join(path, file), "w", encoding="Windows-1252") as file6:
                        print("Wrote - " + file6.name)
                        file6.writelines(stage7lines)

                    os.remove("output.txt")


run_script()