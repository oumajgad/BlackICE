import json
import os

##########################################
# 
##########################################

leaders_to_death_date: dict = {}
leaders_json: dict[str,dict[str,list]]
with open("tools\leader_deaths_event\leader_deaths_sorted.json", "r") as f:
    leaders_json = json.load(f)
for tag, dates in leaders_json.items():
    for date, leaders in dates.items():
        for leader in leaders:
            leaders_to_death_date[leader] = date
print(leaders_to_death_date)

# Figure out which leaders have already received the comment
leaders_already_handled = []
for root, subdirs, files in os.walk("./history/leaders"):
    for file in files:
        print(file)
        with open(os.path.join(root, file), "r", encoding="ISO 8859-1") as leaderfile:
            lines = leaderfile.readlines()
        in_count = 0
        leader_id = 0
        handled = False
        for i, _line in enumerate(lines):
            line = _line[:_line.find("#")]
            if "{" in line and in_count == 0:
                leader_id = int(line.split("=")[0].strip())
            if "{" in line:
                in_count += 1
            if "}" in line:
                in_count -= 1
            if in_count == 1 and _line.startswith("#leader_death:"):
                handled = True
            if in_count == 0:
                if handled:
                    leaders_already_handled.append(leader_id)
                leader_id = 0
                handled = False
print(leaders_already_handled)


# write back leaders with comment added
for root, subdirs, files in os.walk("./history/leaders"):
    for file in files:
        print(file)
        with open(os.path.join(root, file), "r", encoding="ISO 8859-1") as leaderfile:
            lines = leaderfile.readlines()
        write_lines = []
        in_count = 0
        leader_id = 0
        handled = False
        for i, _line in enumerate(lines):
            write_lines.append(_line)
            line = _line[:_line.find("#")]
            if "{" in line and in_count == 0:
                leader_id = int(line.split("=")[0].strip())
                if leader_id in leaders_to_death_date and leader_id not in leaders_already_handled:
                    write_lines.append(f"#leader_death: {leaders_to_death_date[leader_id]}\n")

            if "{" in line:
                in_count += 1
            if "}" in line:
                in_count -= 1
            if in_count == 0:
                if handled:
                    leaders_already_handled.append(leader_id)
                leader_id = 0
                handled = False

        with open(os.path.join(root, file), "w", encoding="ISO 8859-1") as f:
            f.writelines(write_lines)

