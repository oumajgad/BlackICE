import shutil
import sys

######### USAGE #########
# python duplicateModels.py <model> <from> <to> (BOTH INCLUSIVE)
# ie. python duplicateModels.py gfx/models/CHC_light_infantry_0.tga 1 7
#########################

######### INFO ##########
# Duplicate models between ranges
#########################

i = int(sys.argv[2])
to = int(sys.argv[3])
while i <= to:
    shutil.copyfile(sys.argv[1], sys.argv[1][:-5] + str(i) + ".tga")
    i = i + 1
