import os


used_priorities = []

for root, dirs, files in os.walk("./units"):
    for file in files:
        if root == "./units\models":
            continue
        else:
            with open(os.path.join(root,file)) as file:
                lines = file.readlines()
                for line in lines:
                    if "priority" in line:
                        priority = line.split("=")[1].strip()
                        used_priorities.append(float(priority))

used_priorities2 = list(dict.fromkeys(used_priorities))

used_priorities2.sort()

print(used_priorities2)