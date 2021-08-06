import os



leaders = list()
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
                    leaders.append(int(leaderID))
                    continue
                if "{" in line:
                    x += 1
                if "}" in line:
                    x -= 1

leadersSet = set()
duplicates = set()
for l in leaders:
    if l not in leadersSet:
        leadersSet.add(l)
    else:
        duplicates.add(l)


leaders.sort()
freeleaders = []
y = 0
for l in range(leaders[0], leaders[-1]):
    if y >= 1000:
        break
    if l not in leaders:
        freeleaders.append(l)
        y += 1
        if y % 20 == 0:
            freeleaders.append("\n \n")

print(*freeleaders)
print("Above is a list of the next 1000 free leader numbers, in blocks of 20.")
print("There are currently " + str(len(leadersSet)) + " leaders in the Game.")

if len(duplicates) >= 1:
    print("DUPLICATES")
    for l in duplicates:
        print(l)
