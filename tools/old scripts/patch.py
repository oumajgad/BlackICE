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
    "Mod File",
    "Sightseeing"
]

commit1 = sys.argv[1]
commit2 = sys.argv[2]

# Yeah yeah security, this token doesnt give any permissions
user = "Dozed12"
token = "cfb9d1e5dde37e7e70364ec5ee405262f035eba1"

# Compare two commits
response = requests.get("https://api.github.com/repos/oumajgad/BlackICE/compare/" + commit1 + "..." + commit2, auth=(user,token))
jsonResponse = json.loads(response.text)

# Commit list between two
shas = []
shas.append(sys.argv[1])
shas.append(sys.argv[2])
for value in jsonResponse["commits"]:
    shas.append(value["sha"])

# Identify files changed
files = []
for sha in shas:
    response = requests.get("https://api.github.com/repos/oumajgad/BlackICE/commits/" + sha, auth=(user,token))
    jsonResponse = json.loads(response.text)
    for value in jsonResponse["files"]:
        files.append(value["filename"])
        print(value["filename"])

# Get files
if not os.path.isdir("patch"):
    os.mkdir("patch")
for file in files:
    parts = file.split("/")
    urlFile = file.replace(" ", "%20")

    # Check blacklist
    skip = False
    for black in blacklist:
        if black in file:
            skip = True
            break
    if skip:
        continue

    # No py files
    if ".py" in file:
        continue

    # Missing dir
    directory = "patch/"
    for i in range(0, len(parts)-1):
        directory = directory + parts[i] + "/"
    print(directory)
    if not os.path.isdir(directory):
        os.makedirs(directory, exist_ok=True)

    # Download file
    requestURL = "https://raw.githubusercontent.com/oumajgad/BlackICE/master/" + urlFile
    print(requestURL)
    try:
        urllib.request.urlretrieve(requestURL, "patch/" + file)
    except:
        print("File not found")