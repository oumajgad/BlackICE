import os
import sys
import time
import zipfile

import releaseCommon

# Shared with installer/buildInstaller.py so the two release paths cannot drift.
Modfolders = releaseCommon.MOD_FOLDERS
version = str

path = releaseCommon.MOD_PARENT


def countFiles() -> int:
    maxcount = 0
    for root, dirs, files in os.walk("./"):
        for file in files:
            if root.split("\\")[0][2:] in Modfolders or root.split("/")[1] in Modfolders:
                maxcount +=1
    return maxcount

def zipdir(filename):
    zipf = zipfile.ZipFile(filename, 'w', zipfile.ZIP_DEFLATED)
    createModFile(zipf)
    addLua51dll(zipf)
    addDxvkArchive(zipf)
    addUtilityResources(zipf)
    addStatsCLI(zipf)
    addBorderlessWindowRars(zipf)
    addExePatcher(zipf)
    maxcount = countFiles()
    counter = 0
    for root, dirs, files in os.walk("./"):
        if root.split("\\")[0][2:] in Modfolders or root.split("/")[1] in Modfolders:
            for file in files:
                print(str(counter) + " - " + str(maxcount) +  "  included " + os.path.join(root, file))
                counter +=1
                filePath = os.path.join(root, file)
                zipPath = f"{path}/BlackICE %s/%s"%(version, root.split("/")[1])
                zipFilePath = os.path.join(zipPath, file)
                zipf.write(filePath, zipFilePath)
        else:
            print(str(counter) + " - " + str(maxcount) +  "  skipped " + root )
            continue
    zipf.close()


def createModFile(zipf: zipfile.ZipFile):
    modPath = releaseCommon.writeModFile(version, "./Mod File")
    zipf.write(modPath, f"{path}/{releaseCommon.modFileName(version)}")
    os.remove(modPath)

def addStatsCLI(zipf: zipfile.ZipFile):
    zipf.write("./tools/visualizeStatistics/visualizeStatisticCLI.exe", f"{path}/BlackICE {version}/stats/visualizeStatisticCLI.exe")

def addLua51dll(zipf: zipfile.ZipFile):
    zipf.write("./DaveStuff/luabinaries/lua5.1.dll", "lua5.1.dll")

def addUtilityResources(zipf: zipfile.ZipFile):
    for root, dirs, files in os.walk(f"./tools/wxWidget/projects/tfh/mod/BlackICE-utility-resources/"):
        for file in files:
            zipf.write(os.path.join(root, file), f"tfh/mod/BlackICE {version}/utility/{file}")

def addBorderlessWindowRars(zipf: zipfile.ZipFile):
    zipf.write("./DaveStuff/borderless_window_v2winfix/borderless.rar", f"borderless.rar")
    zipf.write("./DaveStuff/borderless_window_v2winfix/borderlessWithStretching.rar", f"borderlessWithStretching.rar")

def addExePatcher(zipf: zipfile.ZipFile):
    zipf.write("./tools/PythonExePatcher/zDsafe_ExePatcher.exe", f"zDsafe_ExePatcher.exe")

def addDxvkArchive(zipf: zipfile.ZipFile):
    zipf.write("./dxvk.rar", f"dxvk.rar")

def setLocsVersion():
    releaseCommon.setLocsVersion(version)

def resetLocsVersion():
    releaseCommon.resetLocsVersion()

def setLuaUtilityVersion():
    releaseCommon.setLuaUtilityVersion(version)

def resetLuaUtilityVersion():
    releaseCommon.resetLuaUtilityVersion()


def zipIt(filename):
    time1 = time.time()
    setLocsVersion()
    setLuaUtilityVersion()
    zipdir(filename)
    resetLocsVersion()
    resetLuaUtilityVersion()
    time2 = time.time()
    rounded_time = round((time2 - time1), 2)
    print("All done! Created BlackICE %s :)"%version )
    print("Took " + str(rounded_time) + " seconds")
    print("\n")
    print("To convert the archive into a self extracting one, open it and under 'tools' select 'convert to SFX'.")
    print("In the advanced options add the text from the 'SFXArchiveText.txt'")
    print("\n")
    os.system("pause")

argv = sys.argv[1:]
print(argv)
if len(argv) == 1:
    version = argv[0]
else:
    version = input("Enter the version number: ")

zipIt("BlackICE %s.zip"%version)

