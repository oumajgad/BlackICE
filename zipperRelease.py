import os
import csv
import time
import zipfile


Modfolders = ["./battleplans","./cgm","./common","./decisions","./events","./history","./localisation","./map",
                "./interface","./music","./script","./sound","./technologies","./units","./gfx"]
newlines = []
version = str




def countFiles() -> int:
    maxcount = 0
    for root, dirs, files in os.walk("./"):
        for file in files:
            if root.split("\\")[0] in Modfolders:
                maxcount +=1
    return maxcount

def zipdir(filename):
    zipf = zipfile.ZipFile(filename, 'w', zipfile.ZIP_DEFLATED)
    createModFile(zipf)
    addWxDll(zipf)
    maxcount = countFiles()
    counter = 0
    for root, dirs, files in os.walk("./"):
        if root.split("\\")[0] not in Modfolders:
            print(str(counter) + " - " + str(maxcount) +  "  skipped " + root )
            continue
        else:
            for file in files:
                print(str(counter) + " - " + str(maxcount) +  "  included " + str(root) + "\\" + str(file))
                counter +=1
                filePath = os.path.join(root, file)
                zipPath = "BlackICE %s/%s"%(version, root.split("/")[1])
                zipFilePath = os.path.join(zipPath, file)
                zipf.write(filePath, zipFilePath)
    zipf.close()


def createModFile(zipf: zipfile.ZipFile):
    with open("./Mod File/BlackICE GitHub.mod", "r") as file1:
        lines = file1.readlines()

    for line in lines:
        if line.split("=")[0].strip() == "name":
            newlines.append('name = "BlackICE %s"\n'% version)
        elif line.split("=")[0].strip() == "path":
            newlines.append('path = "tfh/mod/BlackICE %s"\n'% version)
        elif line.split("=")[0].strip() == "user_dir":
            newlines.append('user_dir = "BlackICE %s"\n'% version)
        else:
            newlines.append(line)

    with open("./Mod File/BlackICE %s.mod"% version, "w") as file2:
        file2.writelines(newlines)

    zipf.write("./Mod File/BlackICE %s.mod"% version, "BlackICE %s.mod"% version)
    os.remove("./Mod File/BlackICE %s.mod"% version)

def addWxDll(zipf: zipfile.ZipFile):
    zipf.write("./tools/wxWidget/wx.dll", "wx.dll")


def setLocsVersion():
    with open("./localisation/bi_version.csv", "r") as versionFile1:
        lines = versionFile1.readlines()
    lines[1] = "BI_VERSION;BlackICE %s;;;;;;;;;;;;;x"%version
    with open("./localisation/bi_version.csv", "w") as versionFile2:
        versionFile2.writelines(lines)

def resetLocsVersion():
    with open("./localisation/bi_version.csv", "r") as versionFile3:
        lines = versionFile3.readlines()
    lines[1] = "BI_VERSION;BlackICE TestVersion;;;;;;;;;;;;;x"
    with open("./localisation/bi_version.csv", "w") as versionFile4:
        versionFile4.writelines(lines)


def zipIt(filename):
    time1 = time.time()
    setLocsVersion()
    zipdir(filename)
    resetLocsVersion()
    time2 = time.time()
    rounded_time = round((time2 - time1), 2)
    print("All done! Created BlackICE %s :)"%version )
    print("Took " + str(rounded_time) + " seconds")
    os.system("pause")


print("Enter the version number.")
version = input()
zipIt("BlackICE %s.zip"%version)

