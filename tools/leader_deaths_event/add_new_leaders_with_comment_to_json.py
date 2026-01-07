import json
import os

########################################################
# Add new leaders which have a "#leader_death:" history
########################################################

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
        date = None
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
            if _line.find("#leader_death:") != -1:
                date = _line.split("#leader_death:")[1].strip()
            if in_count == 0:
                if date:
                    if not leaders_json.get(tag):
                        leaders_json[tag] = {}
                    if not leaders_json[tag].get(date):
                        leaders_json[tag][date] = []
                    if leader_id not in leaders_json[tag][date]:
                        leaders_json[tag][date].append(leader_id)

                leader_id = 0
                tag = "---"
                date = None

new_json = {}
for tag, dates in leaders_json.items():
    sorted_dates = sorted(dates)
    new_json[tag] = {}
    for date in sorted_dates:
        new_json[tag][date] = leaders_json[tag][date]

with open("tools\leader_deaths_event\leader_deaths_sorted.json", "w") as f:
    f.write(json.dumps(new_json, indent=2))
