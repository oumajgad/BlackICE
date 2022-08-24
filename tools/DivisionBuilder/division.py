from brigade import Brigade
from utils import merge_dicts_and_add, divide_dict
from collections import OrderedDict


class Division:
    brigades: list[Brigade]
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

    def calculate_stats_fully(self):
        for brigade in self.brigades:
            brigade.calculate_current_stats()
        self.calculate_stats()

    def calculate_stats(self):
        self.division_stats = dict()

        if len(self.brigades) == 0:
            self.division_stats_ordered = dict()
            return

        self.division_stats["build_cost_ic"] = self.calculate_ic_cost()
        self.division_stats["can_paradrop"] = True

        for brigade in self.brigades:
            temp_brigade: dict = dict(brigade.current_stats)
            if temp_brigade.get("maximum_speed", 10000) < self.division_stats.get("maximum_speed", 10000):
                self.division_stats["maximum_speed"] = temp_brigade["maximum_speed"]
            if temp_brigade.get("build_time", 0) > self.division_stats.get("build_time", 0):
                self.division_stats["build_time"] = round(temp_brigade["build_time"], 3)
            if temp_brigade.get("ap_attack", 0) > self.division_stats.get("ap_attack", 0):
                self.division_stats["ap_attack"] = temp_brigade["ap_attack"]
            if temp_brigade.get("armor_value", 0) > self.division_stats.get("armor_value", 0):
                self.division_stats["armor_value"] = temp_brigade["armor_value"]
            if not temp_brigade.get("can_paradrop", False):
                self.division_stats["can_paradrop"] = False
            temp_brigade.pop("maximum_speed", None)
            temp_brigade.pop("build_time", None)
            temp_brigade.pop("ap_attack", None)
            temp_brigade.pop("armor_value", None)
            temp_brigade.pop("can_paradrop", None)

            self.division_stats = merge_dicts_and_add(self.division_stats, temp_brigade)

        for key in self.division_stats:
            if isinstance(self.division_stats[key], dict):  # Terrain effects
                self.division_stats[key] = divide_dict(self.division_stats[key], len(self.brigades))

        self.division_stats["default_morale"] = round(self.division_stats["default_morale"] / len(self.brigades), 3)
        self.division_stats["default_organisation"] = round(self.division_stats["default_organisation"] /
                                                            len(self.brigades), 3)
        self.division_stats["softness"] = round(self.division_stats["softness"] / len(self.brigades), 3)
        self.sort_stats()

    def calculate_ic_cost(self):
        total_cost = 0
        total_days = 0
        for brigade in self.brigades:
            total_cost += brigade.current_stats["build_cost_ic"]
            total_days += brigade.current_stats["build_time"]
        return total_cost/total_days

    def sort_stats(self):
        self.division_stats_ordered = OrderedDict(sorted(self.division_stats.items()))
        new = OrderedDict(self.division_stats_ordered)
        for k, v in self.division_stats_ordered.items():
            if isinstance(v, dict):  # Terrain stats
                new.move_to_end(k)
        self.division_stats_ordered = new
