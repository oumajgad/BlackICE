import glob
import os
import sys

######### USAGE #########
# python unusedGFX.py <folder of images> <b = move not found files>
# ie. python unusedGFX.py gfx/pictures/leaders b
#########################

######### INFO ##########
# Only works for images that hoi3 does a basic search ("events", "portraits", "tech", maybe more)
# "models" won't work as there are suppositions such as TAG prefix or number suffix
#########################


def searchReference(files, reference):
    for file in files:
        if reference.upper() in file: #File is already upper
            return True
    return False


#Get folder of images to search
imageDir = str(sys.argv[1])

#Found/Not Found
foundN = 0
foundSize = 0

nFoundN = 0
nFoundSize = 0
nFoundFiles = []

#Every .txt file
print("Reading .txt(s)", flush=True)
txtFiles = []
for txtPath, subdirs, files in os.walk("."):
    for txt in files:
        if ".txt" in txt:
            with open(os.path.join(txtPath, txt), 'r', errors='ignore') as file:
                data = file.read()
                txtFiles.append(data.upper())

#Every Image file
print("Starting search: " + imageDir, flush=True)
for imagesPath, subdirs, files in os.walk(imageDir):
    for image in files:
        size = os.path.getsize(os.path.join(imagesPath, image))
        imageName = os.path.splitext(image)[0]

        #Ignore specific files
        if imageName == "event_no_image":
            continue

        print(os.path.join(imagesPath, image), flush=True, end =" - ")
        if searchReference(txtFiles, imageName):
            foundN = foundN + 1
            foundSize = foundSize + size
            print("Found", flush=True)
        else:
            nFoundN = nFoundN + 1
            nFoundSize = nFoundSize + size
            nFoundFiles.append(image)
            print("Not Found", flush=True)

#Found/Not found stats
print("\nFound Total: " + str(foundN) + " -> " + str(foundSize) + " Bytes")
print("Not Found Total: " + str(nFoundN) + " -> " + str(nFoundSize) + " Bytes")

#Move Not Found to separate folder
if len(sys.argv) > 2 and str(sys.argv[2] == "b"):
    for nFoundFile in nFoundFiles:
        src = imageDir + "/" + nFoundFile
        dest = "WIP/GFX/Unusedgfx/" + sys.argv[1] + "/" + nFoundFile
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        os.rename(src, dest)

    print("Not Found moved to backup folder \"WIP/GFX/Unusedgfx\"")