import os
import json
from datetime import datetime

res = {}

# event_killed = []
# for root, subdirs, files in os.walk("./events"):
#     for file in files:
#         # if not "GER - Addition" in file:
#         #     continue
#         print(file)
#         with open(os.path.join(root, file), "r", encoding="ISO 8859-1") as leaderfile:
#             lines = leaderfile.readlines()
#         for i, _line in enumerate(lines):
#             # print(_line)
#             if _line.strip().startswith("#") or _line.strip() == "":
#                 continue
#             line = _line[:_line.find("#")]
#             if "kill_leader" in line:
#                 leader_id = int(line.split("=")[1].strip())
#                 event_killed.append(leader_id)
# print(event_killed)

# MAX_DATE = datetime.strptime("1954.1.1", "%Y.%m.%d")
# for root, subdirs, files in os.walk("./history/leaders"):
#     for file in files:
#         # if not "GER - Addition" in file:
#         #     continue
#         print(file)
#         with open(os.path.join(root, file), "r", encoding="ISO 8859-1") as leaderfile:
#             lines = leaderfile.readlines()
#         in_history = False
#         leader_id = 0
#         tag = "NONE"
#         dies = False
#         for i, _line in enumerate(lines):
#             # print(_line)
#             if _line.strip().startswith("#") or _line.strip() == "":
#                 continue
#             line = _line[:_line.find("#")]
#             if "history" in line:
#                 # print(f"{file}:{i}: '{line}'")
#                 in_history = True
#                 continue
#             if "country" in line:
#                 tag = line.split("country")[1].replace("=", "").lstrip()[:3]
#                 continue
#             if "{" in line and not in_history:
#                 leader_id = int(line.split("=")[0].strip())
#                 continue
#             if in_history:
#                 if line.strip() == "}":
#                     if dies and leader_id not in event_killed:
#                         if leader_id == 600403:
#                             print("600403")
#                         if not res.get(tag):
#                             res[tag] = {}
#                         if not res[tag].get(date):
#                             res[tag][date] = []
#                         res[tag][date].append(leader_id)

#                     dies = False
#                     in_history = False
#                     leader_id = 0
#                     tag = "NONE"
#                     continue
#                 else:
#                     date = line.split("=")[0].strip()
#                     a = line.split("rank")[1]
#                     rank = int(line.split("rank")[1].replace("=", "").replace("}", "").strip())
#                     # print(f"{file}:{i}: '{line}'")
#                     this_date = datetime.strptime(date, "%Y.%m.%d")
#                     if this_date > MAX_DATE:
#                         continue
#                     if rank == 0:
#                         print(f"{tag} - {leader_id = } - {date = }")
#                         dies = True
#                     continue

# with open("leader_deaths.json", "w") as f:
#     f.write(json.dumps(res, indent=2))

with open("leader_deaths.json", "r") as f:
    res = json.loads(f.read())

event_template = """
country_event = {{
    id = {event_id}
    fire_only_once = yes
    trigger = {{
        tag = {tag}
        date = {date}
    }}
    title = "Leader removal."
    desc = "Some of our leaders have died due to natural causes or retired."
    picture = "politics2"
    option = {{
        name = "Unfortunate"
{text}
	}}
}}
"""
event_id = 78000

write_lines = []
for tag, dates in res.items():
    header = """###############################
#            {tag}            #
###############################
    """
    write_lines.append(header.format(tag=tag))
    print(tag)
    for date, leaders in dates.items():
        event_lines = ""
        for leader in leaders:
            event_lines = event_lines + (f"        kill_leader = {leader}\n")
        event_text = event_template.format(event_id=event_id, tag=tag, date=date, text=event_lines)
        event_id += 1
        write_lines.append(event_text)

with open("./generated_leader_death_events.txt", "w") as f:
    f.writelines(write_lines)