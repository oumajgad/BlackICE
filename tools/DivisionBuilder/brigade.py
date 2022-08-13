from tech import Tech
from utils import merge_dicts_and_add


class Brigade:
    name: str
    techs: dict
    raw_stats: dict
    current_stats: dict

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
