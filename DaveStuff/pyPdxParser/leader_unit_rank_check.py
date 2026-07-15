import json
import os
from pathlib import Path


from parser.node import Node
from parser.parser_node import parse_file

BASE_PATH = r"C:\Users\David\GitHub\BlackICE"
OOBS_PATH = r"history\units"
LEADERS_PATH = r"history\leaders"
UNITS_TO_RANKS = {
    "division": 1,
    "corps": 2,
    "army": 3,
    "armygroup": 4,
    "theatre": 4,
    "navy": -1,
    "air": -1,
}

if __name__ == "__main__":
    res = {
        "missing_leaders": [],
        "inactive_leaders": [],
    }
    leaders: dict[str, Node] = {}
    for root, dirs, files in os.walk(Path(BASE_PATH).joinpath(Path(LEADERS_PATH))):
        del dirs[:]  # Dont descend into subdirectories
        for file in files:
            # print(file)
            parsed = parse_file(Path(root).joinpath(Path(file)))
            for leader in parsed.children:
                leaders[leader.key] = leader
    for root, dirs, files in os.walk(Path(BASE_PATH).joinpath(Path(OOBS_PATH))):
        for file in files:
            # print(file)
            parsed = parse_file(Path(root).joinpath(Path(file)))
            assigned_leaders = parsed.find_by_key("leader")
            for assigned_leader in assigned_leaders:
                unit_type = assigned_leader.parent.key
                unit_name = assigned_leader.parent.find_by_key_single("name").scalar_value
                expected_rank = UNITS_TO_RANKS.get(unit_type.lower())
                leader_id = str(assigned_leader.scalar_value)
                history_leader = leaders.get(leader_id)
                if not history_leader:
                    print(f"Could not find leader: {leader_id}")
                    res["missing_leaders"].append(
                        {
                            "leader_id": leader_id,
                            "unit_name": unit_name,
                        }
                    )
                    continue
                leader_rank = int(history_leader.find_by_key_single("rank").scalar_value)
                if expected_rank != leader_rank and expected_rank != -1:
                    res["inactive_leaders"].append(
                        {
                            "leader_id": leader_id,
                            "leader_rank": leader_rank,
                            "expected_rank": expected_rank,
                            "File": file,
                        }
                    )
                    print(
                        f"Mismatched rank for {leader_id}: Has {leader_rank} - Expected {expected_rank} - File: {file}"
                    )
        with open("leader_unit_rank_check_result.json", "w") as f:
            f.write(json.dumps(res, indent=2))
