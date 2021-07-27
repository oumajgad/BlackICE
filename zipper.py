import os
import zipfile
import zlib
import time

# This will "quickly" create a zip with the files needed to run the mod.


Modfolders = ["./battleplans","./cgm","./common","./decisions","./events","./history","./localisation","./map",
                "./interface","./music","./script","./sound","./technologies","./units"]
filename = "BlackIce.zip"

print("Do you want to include the GFX folder? [Y/N]\nIt will take much longer if you do.")
x = input()
if x.lower() == "y":
    Modfolders.append("./gfx")
    filename = "BlackIceGFX.zip"

maxcount = 0

for root, dirs, files in os.walk("./"):
    for file in files:
        if root.split("\\")[0] in Modfolders:
            maxcount +=1

def zipdir(path):
    counter = 0
    for root, dirs, files in os.walk(path):
        if root.split("\\")[0] not in Modfolders:
            print(str(counter) + " - " + str(maxcount) +  "  skipped " + root )
            continue
        else:
            for file in files:
                print(str(counter) + " - " + str(maxcount) +  "  included " + str(root) + "\\" + str(file))
                counter +=1
                zipf.write(os.path.join(root, file))

zipf = zipfile.ZipFile(filename, 'w', zipfile.ZIP_DEFLATED)
zipdir('./')
zipf.close()

print("All done! :)" )
time.sleep(1)
