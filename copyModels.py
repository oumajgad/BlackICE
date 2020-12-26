import glob
import shutil
import os
import sys

######### USAGE #########
# python copyModels.py <model> <from> <to>
# ie. python copyModels.py interceptor SOV CHC
#########################

######### INFO ##########
# Copy models from one tag to another
#########################

for path, subdirs, files in os.walk("gfx/models/"):
    for file in files:
        if ".tga" in file:
            with open(os.path.join(path, file), 'r', errors='ignore') as file:
                pathParts = file.name.split("/")
                fileName = pathParts[len(pathParts)-1]
                parts = fileName.split("_")
                if parts[0] == sys.argv[2] and sys.argv[1] in fileName:
                    parts[0] = sys.argv[3]
                    newFile = "_".join(parts)
                    shutil.copyfile(file.name, os.path.join(path, newFile))