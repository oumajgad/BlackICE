from brigade import Brigade
from utils import merge_dicts_and_add, divide_dict
from collections import OrderedDict


class Division:
    brigades: list
    unit_count: int
    division_stats: dict
    division_stats_ordered: OrderedDict

    def __init__(self):
        self.unit_count = 0
        self.brigades = list()
        self.division_stats = dict()

    def add_brigade(self, brigade: Brigade):
        self.brigades.append(brigade)
        self.calculate_stats()

    def remove_brigade(self, index):
        ret = self.brigades.pop(index)
        self.calculate_stats()
        return ret

    def calculate_stats(self):
        self.division_stats = dict()
        for brigade in self.brigades:
            s = brigade.current_stats
            self.division_stats = merge_dicts_and_add(self.division_stats, s)
            if s["maximum_speed"] < self.division_stats["maximum_speed"]:
                self.division_stats["maximum_speed"] = s["maximum_speed"]
        for key in self.division_stats:
            if isinstance(self.division_stats[key], dict):  # Terrain effects
                self.division_stats[key] = divide_dict(self.division_stats[key], len(self.brigades))
        self.sort_stats()

    def sort_stats(self):
        self.division_stats_ordered = OrderedDict(sorted(self.division_stats.items()))
        new = OrderedDict(self.division_stats_ordered)
        for k, v in self.division_stats_ordered.items():
            if isinstance(v, dict): # Terrain stats
                new.move_to_end(k)
        self.division_stats_ordered = new
