import glob
import os
import sys

######### INFO ##########
# [R]emove [D]uplicate [L]ines from [P]rovince [H]istory files
#########################

#Saved space
saved = 0

#Every province history file
print("Cleaning province history files...", flush=True)
for txtPath, subdirs, files in os.walk("history/provinces/"):
    for txt in files:
        if ".txt" in txt:
            lines = []
            with open(os.path.join(txtPath, txt), 'r', errors='ignore') as file:
                for line in file:
                    if line != "\n":
                        if (line not in lines or "{" in line or "}" in line):
                            lines.append(line)
                        else:
                            saved = saved + len(line.encode('utf-8'))

            f = open(os.path.join(txtPath, txt), "w")
            for line in lines:
                f.write(line)
            f.close()

print("Done, saved " + str(saved) + " bytes", flush=True)