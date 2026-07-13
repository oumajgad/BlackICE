import json
from datetime import datetime

header_template = """###############################
#            {tag}            #
###############################
"""

event_template = """
country_event = {{
    id = {event_id}
    trigger = {{
        tag = {tag}
        date = {date}
        NOT = {{
            has_country_flag = "{country_flag}"
        }}
    }}
    title = "Leader removal."
    desc = "Some of our leaders have died due to natural causes or retired."
    picture = "politics2"
    option = {{
        name = "Unfortunate"{textA}
        set_country_flag = "{country_flag}"
    }}
    option = {{
        name = "Let me keep them"{textB}
        set_country_flag = "{country_flag}"
    }}
}}
"""

leader_deaths: dict[str,dict[str,list[int]]]
with open("tools\leader_deaths_event\leader_deaths_sorted.json", "r") as f:
    leader_deaths = json.load(f)

default_cutoff_date = datetime.strptime("1941.06.22", "%Y.%m.%d")
date_cutoffs = {
    "GER": datetime.strptime("1939.09.01", "%Y.%m.%d"),
    "ENG": datetime.strptime("1939.09.01", "%Y.%m.%d"),
    "FRA": datetime.strptime("1939.09.01", "%Y.%m.%d"),
    "ITA": datetime.strptime("1940.06.01", "%Y.%m.%d"),
    "USA": datetime.strptime("1941.12.07", "%Y.%m.%d"),
    "JAP": datetime.strptime("1941.12.07", "%Y.%m.%d"),
    "SOV": datetime.strptime("1941.06.22", "%Y.%m.%d"),
}

event_id = 78000
write_lines = []
handled_leaders = []
for tag, dates in leader_deaths.items():
    write_lines.append(header_template.format(tag=tag))
    for _date, leaders in dates.items():
        date = date_str = datetime.strptime(_date, "%Y.%m.%d")
        cutoff_date = date_cutoffs.get(tag, default_cutoff_date)
        if date > cutoff_date:
            print(f"Skipping {tag} leader deaths on {_date} because it is after the cutoff date of {cutoff_date.strftime('%Y.%m.%d')}.")
            continue
        date_str = datetime.strptime(_date, "%Y.%m.%d").strftime("%Y.%m.%d")
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
        event_text = event_template.format(
            event_id=event_id, 
            tag=tag, 
            date=date_str, 
            country_flag=f"leader_deaths_{date_str.replace('.','')}", 
            textA=event_lines, 
            textB=f"\n        officer_pool = -{len(leaders)*1000}\n        money = -{len(leaders)*200}"
        )
        event_id += 1
        write_lines.append(event_text)

with open("tools\leader_deaths_event\generated_leader_death_events.txt", "w") as f:
    f.writelines(write_lines)

