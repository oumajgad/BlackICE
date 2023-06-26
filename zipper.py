import os
import zipfile
import time
from tkinter import *

# This will "quickly" create a zip with the files needed to run the mod.

Modfolders = ["./battleplans","./cgm","./common","./decisions","./events","./history","./localisation","./map",
                "./interface","./music","./script","./sound","./technologies","./units"]


def countFiles() -> int:
    maxcount = 0
    for root, dirs, files in os.walk("./"):
        for file in files:
            if root.split("\\")[0] in Modfolders:
                maxcount +=1
    return maxcount

def addUtilityResources(zipf: zipfile.ZipFile):
    for root, dirs, files in os.walk(f"./tools/wxWidget/projects/tfh/mod/BlackICE-utility-resources/"):
        for file in files:
            zipf.write(os.path.join(root, file), f"utility/{file}")

def addStatsCLI(zipf: zipfile.ZipFile):
    zipf.write("./tools/visualizeStatistics/visualizeStatisticCLI.exe", f"stats/visualizeStatisticCLI.exe")

def zipdir(filename):
    maxcount = countFiles()
    zipf = zipfile.ZipFile(filename, 'w', zipfile.ZIP_DEFLATED)
    addUtilityResources(zipf)
    addStatsCLI(zipf)
    zipf.write("./tools/TechFileForLua/TechsIcEffValues.txt", f"utility/TechsIcEffValues.txt")
    zipf.write("./tools/TechFileForLua/TechsResEffValues.txt", f"utility/TechsResEffValues.txt")
    zipf.write("./tools/TechFileForLua/TechsSuppThrouValues.txt", f"utility/TechsSuppThrouValues.txt")
    counter = 0
    for root, dirs, files in os.walk("./"):
        if root.split("\\")[0] not in Modfolders:
            print(str(counter) + " - " + str(maxcount) +  "  skipped " + root )
            continue
        else:
            for file in files:
                print(str(counter) + " - " + str(maxcount) +  "  included " + str(root) + "\\" + str(file))
                counter +=1
                zipf.write(os.path.join(root, file))
    zipf.close()


def zipIt(filename):
    time1 = time.time()
    zipdir(filename)
    time2 = time.time()
    rounded_time = round((time2 - time1), 2)
    print("All done! :)" )
    print("Took " + str(rounded_time) + " seconds")
    os.system("pause")
    main.destroy()


main = Tk()
main.title("Zipper")


def ZipFilesSmall():
    main.withdraw()
    filename = "BlackIce.zip"
    zipIt(filename)

def ZipFilesGFX():
    main.withdraw()
    Modfolders.append("./gfx")
    filename = "BlackIceGFX.zip"
    zipIt(filename)

# def ZipFilesRelease():
#     main.withdraw()
#     zipIt()



b_ZipFilesSmall     = Button(main, text="ZipFiles",         width=25, command= lambda: ZipFilesSmall())
b_ZipFilesGFX       = Button(main, text="ZipFilesGFX",      width=25, command= lambda: ZipFilesGFX())
# b_ZipFilesRelease   = Button(main, text="ZipFilesRelease",  width=25, command= lambda: ZipFilesRelease())


b_ZipFilesSmall.grid    (row=0, column=0, padx=10, pady=10)
b_ZipFilesGFX.grid      (row=0, column=1, padx=10, pady=10)
# b_ZipFilesRelease.grid  (row=0, column=2, padx=10, pady=10)


main.mainloop()
