import requests
import json
import urllib.request
import os
import sys

# Downloads all the files changed between two commits (inclusive for both)
# NOTE: Currently downloads latest versions of files, not necessarily files at time of <commit2>
# python patch.py <commit1> <commit2>

blacklist = [
    "DaveStuff",
    "WIP",
    "master-models",
    "Mod File"
]

commit1 = sys.argv[1]
commit2 = sys.argv[2]

# Compare two commits
response = requests.get("https://api.github.com/repos/oumajgad/BlackICE/compare/" + commit1 + "..." + commit2)
jsonResponse = json.loads(response.text)

# Identify files changed
files = []
for value in jsonResponse["files"]:
    print(value["filename"])
    files.append(value["filename"])

if not os.path.isdir("patch"):
    os.mkdir("patch")

# Get files
for file in files:
    parts = file.split("/")
    urlFile = file.replace(" ", "%20")
    #TODO blacklist check
    #TODO blacklist .py files
    #TODO missing makedirs
    urllib.request.urlretrieve("https://raw.githubusercontent.com/oumajgad/BlackICE/master/" + urlFile, "patch/" + file)