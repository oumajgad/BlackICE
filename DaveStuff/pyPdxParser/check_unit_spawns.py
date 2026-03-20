import json
import os
import time
from pathlib import Path
from typing import Optional, Any

import pydantic
from tqdm import tqdm

from parser.node import Node
from parser.parser import parse_file

BASE_PATH = r"C:\Users\David\GitHub\BlackICE"


def get_events() -> list[Node]:
    time.sleep(0.1)
    res = []
    events_path = rf"{BASE_PATH}\events"
    for root, dirs, files in os.walk(events_path):
        for file in tqdm(
            files,
            desc=f"'Parsing events'",
            unit=" it",
        ):
            x = parse_file(Path(root).joinpath(Path(file)))
            file_node = Node.from_parsed(x)
            for child in file_node.children:
                if child.key == "country_event":
                    child.parent = None
                    res.append(child)
    print(f"Parsed {len(res)} events")
    return res


def get_decisions() -> list[Node]:
    time.sleep(0.1)
    res = []
    events_path = rf"{BASE_PATH}\decisions"
    for root, dirs, files in os.walk(events_path):
        for file in tqdm(
            files,
            desc=f"'Parsing decisions'",
            unit=" it",
        ):
            x = parse_file(Path(root).joinpath(Path(file)))
            file_node = Node.from_parsed(x.get("diplomatic_decisions"))
            for child in file_node.children:
                child.parent = None
                res.append(child)
    print(f"Parsed {len(res)} decisions")
    return res


def filter_for_oob_load(events: list[Node]) -> list[Node]:
    time.sleep(0.1)
    res = []
    for event in tqdm(
        events,
        desc=f"'Filtering for OOB events'",
        unit=" it",
    ):
        if len(event.find_by_key("load_oob")) > 0:
            res.append(event)
    return res


def find_decision_for_event_id(event_id: int, decisions: list[Node]) -> Optional[Node]:
    for decision in decisions:
        fired_event_nodes = decision.find_by_key("country_event")
        if len(fired_event_nodes) > 0:
            for fired_event_node in fired_event_nodes:
                if str(fired_event_node.scalar_value) == str(event_id):
                    return decision


def find_event_for_event_id(event_id: int, events: list[Node]) -> Optional[Node]:
    for event in events:
        fired_event_nodes = event.find_by_key("country_event")
        if len(fired_event_nodes) > 0:
            for fired_event_node in fired_event_nodes:
                if str(fired_event_node.scalar_value) == str(event_id):
                    return event


def get_oob_locations_from_event(event: Node) -> set[int]:
    units_path = rf"{BASE_PATH}\history\units"
    load_oob_nodes = event.find_by_key("load_oob")
    res = []
    for load_oob_node in load_oob_nodes:
        try:
            x = parse_file(Path(units_path).joinpath(Path(load_oob_node.scalar_value)))
            oob_file_node = Node.from_parsed(x)
            location_nodes = oob_file_node.find_by_key("location")
            for location_node in location_nodes:
                res.append(int(location_node.scalar_value))
        except FileNotFoundError:
            print(f"File {load_oob_node.scalar_value} was not found")
    return set(res)  # deduplicate


def get_checked_province_ids_from_node(node: Node) -> set[int]:
    res = []
    controls_nodes = node.find_by_key("controls")
    for controls_node in controls_nodes:
        res.append(int(controls_node.scalar_value))
    controlled_by_nodes = node.find_by_key("controlled_by")
    for controlled_by_node in controlled_by_nodes:
        if controlled_by_node.parent.key.isnumeric():
            res.append(int(controlled_by_node.parent.key))
    return set(res)  # deduplicate


def load_blacklist() -> list[int]:
    with open("./check_unit_spawns_blacklist.json", "r") as f:
        return json.load(f)


class EventReport(pydantic.BaseModel):
    event_id: int
    event_title: str
    oob_event: Node
    fired_by_type: str
    fired_by: Any
    unchecked: list[int] = []


if __name__ == "__main__":
    decision_nodes = get_decisions()
    event_nodes = get_events()
    oob_events = filter_for_oob_load(event_nodes)
    candidates = []
    time.sleep(0.1)
    for oob_event in tqdm(
        oob_events,
        desc=f"'Searching for trigger events and decisions'",
        unit=" it",
    ):
        oob_event_id_node = oob_event.find_by_key_single("id")
        oob_event_id = oob_event_id_node.scalar_value
        oob_event_title_node = oob_event.find_by_key_single("title")
        oob_event_title = oob_event_title_node.scalar_value
        if oob_event.find_by_key_single("is_triggered_only"):
            decision = find_decision_for_event_id(oob_event_id, decision_nodes)
            if decision:
                candidates.append(
                    EventReport(
                        event_id=oob_event_id,
                        event_title=oob_event_title,
                        oob_event=oob_event,
                        fired_by_type="decision",
                        fired_by=decision,
                    )
                )
                continue
            event = find_event_for_event_id(oob_event_id, event_nodes)
            if event:
                candidates.append(
                    EventReport(
                        event_id=oob_event_id,
                        event_title=oob_event_title,
                        oob_event=oob_event,
                        fired_by_type="event",
                        fired_by=event,
                    )
                )
                continue
            if not decision and not event:
                # print(f"None found for {event_id}")
                continue
        else:
            candidates.append(
                EventReport(
                    event_id=oob_event_id,
                    event_title=oob_event_title,
                    oob_event=oob_event,
                    fired_by_type="trigger",
                    fired_by=oob_event,
                )
            )
    print(len(candidates))
    violators: list[dict] = []
    blacklist = load_blacklist()
    for candidate in candidates:
        if candidate.event_id in blacklist:
            continue
        oob_locations = get_oob_locations_from_event(candidate.oob_event)
        checked = get_checked_province_ids_from_node(candidate.fired_by)
        candidate.unchecked = [oob_location for oob_location in oob_locations if oob_location not in checked]
        if len(candidate.unchecked) > 0:
            violators.append(candidate.dict(exclude={"oob_event": True, "fired_by": True}))
    violators.sort(key=lambda x: x.get("event_id"))
    with open("check_unit_spawns_result.json", "w") as f:
        f.write(json.dumps(violators, indent=2))
