import json
import os

###################################################
# Add new leaders which have a "rank = 0" history
###################################################

leaders_json: dict[str,dict[str,list]]
with open("tools\leader_deaths_event\leader_deaths_sorted.json", "r") as f:
    leaders_json = json.load(f)

for root, subdirs, files in os.walk("./history/leaders"):
    for file in files:
        print(file)
        with open(os.path.join(root, file), "r", encoding="ISO 8859-1") as leaderfile:
            lines = leaderfile.readlines()
        in_count = 0
        leader_id = 0
        tag = "---"
        for i, _line in enumerate(lines):
            line = _line[:_line.find("#")]
            if "{" in line and in_count == 0:
                leader_id = int(line.split("=")[0].strip())
            if "country" in line:
                tag = line.split("country")[1].replace("=", "").lstrip()[:3]
            if "{" in line:
                in_count += 1
            if "}" in line:
                in_count -= 1
            if line.find("rank = 0") != -1:
                date = line.split("=")[0].strip()
                if not leaders_json.get(tag):
                    leaders_json[tag] = {}
                if not leaders_json[tag].get(date):
                    leaders_json[tag][date] = []
                if leader_id not in leaders_json[tag][date]:
                    leaders_json[tag][date].append(leader_id)
            if in_count == 0:
                leader_id = 0
                tag = "---"

new_json = {}
for tag, dates in leaders_json.items():
    sorted_dates = sorted(dates)
    new_json[tag] = {}
    for date in sorted_dates:
        new_json[tag][date] = leaders_json[tag][date]

with open("tools\leader_deaths_event\leader_deaths_sorted.json", "w") as f:
    f.write(json.dumps(new_json, indent=2))
