import json

header_template = """###############################
#            {tag}            #
###############################
"""

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
        name = "Unfortunate"{textA}
	}}
    option = {{
        name = "Let me keep them"{textB}
	}}
}}
"""

leader_deaths: dict
with open("tools\leader_deaths_event\leader_deaths_sorted.json", "r") as f:
    leader_deaths = json.load(f)

event_id = 78000
write_lines = []
handled_leaders = []
for tag, dates in leader_deaths.items():
    write_lines.append(header_template.format(tag=tag))
    for date, leaders in dates.items():
        # print(tag)
        # print(date)
        # print(leaders)
        event_lines = ""
        for leader in leaders:
            event_lines = event_lines + (f"\n        kill_leader = {leader}")
            if leader not in handled_leaders:
                handled_leaders.append(leader)
            else:
                print(f"Duplicate leader death in JSON. Leader ID: {leader}")
        event_text = event_template.format(event_id=event_id, tag=tag, date=date, textA=event_lines, textB=f"\n        officer_pool = -{len(leaders*1000)}\n        money = -{len(leaders*200)}")
        event_id += 1
        write_lines.append(event_text)

with open("tools\leader_deaths_event\generated_leader_death_events.txt", "w") as f:
    f.writelines(write_lines)

