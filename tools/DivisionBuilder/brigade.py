from tech import Tech
from utils import merge_dicts_and_add
from collections import OrderedDict


class Brigade:
    name: str
    techs: dict[str, Tech]
    raw_stats: dict
    current_stats: dict
    current_stats_ordered: OrderedDict

    def __init__(self, name: str, raw_stats: dict, techs: list):
        self.name = name
        self.raw_stats = dict(raw_stats)
        self.current_stats = dict(raw_stats)
        self.techs = dict()
        for tech in techs:
            for k, v in tech.units.items():
                v: Tech
                if k == name:
                    self.techs[tech.name] = tech
        self.calculate_current_stats()

    def change_tech_level(self, tech: str, level: int):
        tech: Tech
        tech = self.techs.get(tech)
        tech.level = level
        self.calculate_current_stats()

    def calculate_current_stats(self):
        self.current_stats = dict(self.raw_stats)
        for k, v in self.techs.items():
            v: Tech
            unit_values = v.get_unit_values(self.name)
            x = 0
            while x < v.level:
                self.current_stats = merge_dicts_and_add(self.current_stats, unit_values)
                x += 1
        self.remove_junk_from_stats()
        self.sort_current_stats()

    def remove_junk_from_stats(self):
        junk = ["type", "sprite", "priority", "is_mobile", "on_completion", "is_bomber", "active",
                "is_buildable", "usable_by", "unit_group"]
        new = dict(self.current_stats)
        for k, v in self.current_stats.items():
            if k in junk:
                new.pop(k)
        self.current_stats = new

    def sort_current_stats(self):
        self.current_stats_ordered = OrderedDict(sorted(self.current_stats.items()))
        new = OrderedDict(self.current_stats_ordered)
        for k, v in self.current_stats_ordered.items():
            if isinstance(v, dict): # Terrain stats
                new.move_to_end(k)
        self.current_stats_ordered = new
