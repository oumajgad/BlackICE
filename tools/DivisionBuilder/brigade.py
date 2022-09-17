from tech import Tech
from utils import merge_dicts_and_add
from collections import OrderedDict
from copy import deepcopy


class Brigade:
    name: str
    tech_list: list[Tech]   # The global tech list
    techs: dict[str, int]   # [Tech name, Tech level]
    raw_stats: dict
    current_stats: dict
    current_stats_ordered: OrderedDict

    def __init__(self, name: str, raw_stats: dict, tech_list: list):
        self.name = name
        self.raw_stats = dict(raw_stats)
        self.current_stats = dict(raw_stats)
        self.techs = dict()
        self.tech_list = list()
        self.update_techs(tech_list)
        self.calculate_current_stats()

    # Update the techs associated with a brigade, but keeping the same levels (for when the tech files have changed)
    def update_techs(self, tech_list: list):
        self.tech_list = tech_list
        new_techs: dict[str, int] = dict()
        for tech in self.tech_list:
            if tech.units.get(self.name, None):
                # Get the level of the current brigades tech, default to the global tech level
                new_techs[tech.name] = self.techs.get(tech.name, tech.level)
        self.techs = new_techs

    def change_tech_level(self, tech_name: str, level: int):
        self.techs[tech_name] = level
        self.calculate_current_stats()

    def get_total_tech_level(self):
        total_level = 0
        for k, v in self.techs.items():
            total_level += v
        return total_level

    # Each tech level increases build time by 1% (after effects and practicals)
    def ballpark_tech_build_time_effect(self):
        self.current_stats["build_time"] = round(self.current_stats["build_time"]
                                                 * (1 + (self.get_total_tech_level() / 100)), 3)

    def calculate_current_stats(self):
        self.current_stats = deepcopy(self.raw_stats)
        unit_techs = [tech for tech in self.tech_list if tech.name in self.techs]
        for tech in unit_techs:
            tech: Tech
            values = tech.get_unit_values(self.name)
            x = 0
            while x < self.techs[tech.name]:
                self.current_stats = merge_dicts_and_add(self.current_stats, values)
                x += 1
        self.remove_junk_from_stats()
        self.ballpark_tech_build_time_effect()
        self.correct_terrain_value()
        self.correct_shown_values()
        self.sort_current_stats()

    def remove_junk_from_stats(self):
        junk = ["type", "sprite", "priority", "is_mobile", "on_completion", "is_bomber", "active",
                "is_buildable", "usable_by", "available_trigger", "repair_cost_multiplier",
                "is_armor", "completion_size"]
        new = dict(self.current_stats)
        for k, v in self.current_stats.items():
            if k in junk:
                new.pop(k)
        self.current_stats = new

    def correct_terrain_value(self):
        for k, v in self.current_stats.items():
            if isinstance(v, dict):
                for modifier, value in v.items():
                    if modifier == "attrition":
                        pass
                    else:
                        self.current_stats[k][modifier] = round(self.current_stats[k][modifier] * 100)

    def correct_shown_values(self):
        if self.current_stats.get("max_strength", None):
            self.current_stats["max_strength"] = round(self.current_stats["max_strength"] * 100)
        if self.current_stats.get("default_morale", None):
            self.current_stats["default_morale"] = round(self.current_stats["default_morale"] * 100)
        if self.current_stats.get("softness", None):
            self.current_stats["softness"] = round(self.current_stats["softness"] * 100)
        if self.current_stats.get("default_organisation", None):
            self.current_stats["default_organisation"] = round(self.current_stats["default_organisation"])

    def sort_current_stats(self):
        self.current_stats_ordered = OrderedDict(sorted(self.current_stats.items()))
        new = OrderedDict(self.current_stats_ordered)
        for k, v in self.current_stats_ordered.items():
            if isinstance(v, dict):  # Terrain stats
                new.move_to_end(k)
        if new.get("unit_group", None):
            new.move_to_end("unit_group", False)
        self.current_stats_ordered = new

    def transform_techs(self, tech_list):
        self.tech_list = tech_list
        new_tech_dict = dict()
        for k, tech in self.techs.items():
            tech: Tech
            new_tech_dict[k] = tech.level
        self.techs = new_tech_dict
