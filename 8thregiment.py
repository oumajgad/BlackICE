import glob
import os
import sys

######### INFO ##########
# Detect oob files with divisions with 8 regiments
#########################

#Every province oob file
txtfile = ""
print("FILES WITH DIVISIONS WITH 8 REGIMENTS", flush=True)
for txtPath, subdirs, files in os.walk("history/units/"):
    for txt in files:
        if ".txt" in txt:
            with open(os.path.join(txtPath, txt), 'r', errors='ignore') as file:
                regCount = 0
                regiment8 = 0
                lines = []
                lineN = 1
                addedLine = False
                for line in file:
                    if "division" in line or "corps" in line or "army" in line or "armygroup" in line or "theatre" in line or "military_construction" in line:
                        regCount = 0
                        addedLine = False
                    if "regiment" in line or ("historical_model" in line and "ship" not in line and "wing" not in line):
                        regCount = regCount + 1
                    if regCount == 8 and not addedLine:
                        regiment8 = regiment8 + 1
                        lines.append(lineN)
                        addedLine = True
                    lineN = lineN + 1

                if regiment8 > 0:
                    txtfile = txtfile + os.path.join(txtPath, txt) + " - "
                    print(os.path.join(txtPath, txt) + " - ", flush=True, end="")
                    for line in lines:
                        txtfile = txtfile + "(line " + str(line) + ")"
                        print("(line " + str(line) + ")", flush=True, end="")
                    txtfile = txtfile + "\n"
                    print("")

#Save to txt
f = open("8th_regiment_divs.txt", "w")
f.write(txtfile)
f.close() 

print("DONE", flush=True)