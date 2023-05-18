import os


for path, subdirs, files in os.walk("./history/provinces"):
    for file in files:
        newlines = []
        with open(os.path.join(path, file), 'r', encoding="ISO-8859-1") as data:
            lines = data.readlines()
            for line in lines:
                if line.strip() != "":
                    newlines.append(line)
        with open(os.path.join(path, file), 'w', encoding="ISO-8859-1") as data:
            data.writelines(newlines)
