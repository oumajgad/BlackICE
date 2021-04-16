import os



lines = []
search = 0
reps = []

with open("save.hoi3" , "r" , encoding="UTF-8" , errors="ignore") as file:
    i = 0   # Line number
    x = 4   # Amount of following lines to check
    y = 0   # Number of repetitions
    z = 20  # Threshold for printing
    for line in file:
        i += 1

        if "controller=" in line and search == 0:
            search = 1
            line1 = i

        elif "controller=" not in line and search == 0:
            x = 4

        elif "controller=" not in line and search == 1 and x > 0:
            x -= 1

        elif "controller=" in line and search == 1 and x != 0:
            x = 4
            y += 1
            if y >= 5:
                print("y = " + str(y))

        elif "controller=" not in line and search == 1 and x == 0:
            search = 0
            x = 4
            if y >= z:
                lines.append(line1)
                reps.append(y)
                y = 0
            else:
                y = 0
                continue

print("\n\n\nRepetitions found in these lines\n")
for line in lines:
    print("\t" + str(line) + "\n")
#print(reps)
print("Use 'Ctrl + G' to jump lines in Notepad++")
os.system('pause')