import os



leaderIDs = list()
for root, dirs, files in os.walk("./history/leaders"):
    for file1 in files:
        with open(root + "/" + file1 , "r", errors="ignore") as file:
            x = 0
            for line in file:
                if line.startswith("#"):
                    continue
                if "=" in line and x == 0:
                    x += 1
                    leaderID = line.split("=")[0].strip()
                    #print(leaderID)
                    leaderIDs.append(int(leaderID))
                    continue
                if "{" in line:
                    x += 1
                if "}" in line:
                    x -= 1

leadersSet = set()
duplicates = set()
for l in leaderIDs:
    if l not in leadersSet:
        leadersSet.add(l)
    else:
        duplicates.add(l)


leaderIDs.sort()

# nextFreeLeaders = []
# y = 0
# for l in range(leaderIDs[0], leaderIDs[-1]):
#     if y >= 1000:
#         break
#     if l not in leaderIDs:
#         nextFreeLeaders.append(l)
#         y += 1
#         if y % 20 == 0:
#             nextFreeLeaders.append("\n \n")

# print(*nextFreeLeaders)
# print("Above is a list of the next 1000 free leader numbers, in blocks of 20.")
# print("There are currently " + str(len(leadersSet)) + " leaders in the Game.")

freeLeaderBlocks = []
currentBlock = {
    "start": None,
    "end": 0
}
for potentialLeaderId in range(leaderIDs[0], 100_000):
    if potentialLeaderId not in leaderIDs:
        if currentBlock["start"] == None:
            currentBlock["start"] = potentialLeaderId
        else:
            currentBlock["end"] = potentialLeaderId
    else:
        if currentBlock["start"] == None:
            continue
        if currentBlock["end"] - currentBlock["start"] >= 100:
            freeLeaderBlocks.append(currentBlock)
            currentBlock = {
                "start": None,
                "end": 0
            }

print("Ranges of at least 100 free leader IDs")
for freeLeaderBlock in freeLeaderBlocks:
    print(f"Amount: {freeLeaderBlock['end'] - freeLeaderBlock['start']} Start: {freeLeaderBlock['start']} End: {freeLeaderBlock['end']}")

if len(duplicates) >= 1:
    print("DUPLICATES")
    for l in duplicates:
        print(l)
else:
    print("No Duplicates")
