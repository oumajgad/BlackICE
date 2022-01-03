import os


eventfile = "events\zBI_ENG_EventOOBs.txt"
targetFile = "events\eventOOBs_ENG.txt"

readLines = []
with open(eventfile, "r", encoding="ISO-8859-1") as openFile:
    readLines = openFile.readlines()


normalEvents = []
oobEvents = []

tempEvent = []
oobEvent = False
for line in readLines:
    tempEvent.append(line)
    if "load_oob" in line:
        oobEvent = True
    if line.startswith("}"):
        if oobEvent == True:
            oobEvents.extend(tempEvent)
            tempEvent.clear()
            oobEvent = False
        else:
            normalEvents.extend(tempEvent)
            tempEvent.clear()

# print(normalEvents)
# print(oobEvents)

with open(eventfile, "w", encoding="ISO-8859-1") as openFile:
    openFile.writelines(normalEvents)

with open(targetFile, "a", encoding="ISO-8859-1") as openFile:
    openFile.writelines(oobEvents)