import os





def readEvents():
    foundPicRefs = []
    for root, dirs, files in os.walk("./events"):
        for file in files:
            if ".txt" in file:
                with open(os.path.join(root, file), "r") as openFile:
                    readlines = openFile.readlines()
                    for line in readlines:
                        if "picture =" in line and not line.strip().startswith("#"):
                            foundPicRefs.append(str(line.split('=')[1].replace('"','').strip()).upper())

    return foundPicRefs

def getImages():
    foundPics = []
    for root, dirs, files in os.walk("./gfx/pictures/events"):
        for file in files:
            foundPics.append(str(file.split(".")[0].strip()).upper())

    return foundPics

def compare(references : list, images : list):
    unusedImages = []
    for image in images:
        if image not in references:
            unusedImages.append(image)
    return unusedImages


if __name__ == "__main__":
    print(compare(readEvents(), getImages()))
    # compare(readEvents(), getImages())