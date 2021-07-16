import os

# Something to quickly increase the leader max_skill

folder = "./history/leaders"

for root, dirs, files in os.walk(folder):
    for file in files:
        with open(os.path.join(root, file), "r", encoding="ISO 8859-1", errors="ignore") as leaderfile:
            read_lines = leaderfile.readlines()

        for line in read_lines:
            if "max_skill" in line:
                max_skill = int(line.split("=")[1].split("#")[0].strip())
                if max_skill < 7:
                    #print(line)
                    read_lines[read_lines.index(line)] = "\tmax_skill = 7\n"

        
        with open(os.path.join(root, file), "w", encoding="ISO 8859-1", errors="ignore") as leaderfile:
            leaderfile.writelines(read_lines)
