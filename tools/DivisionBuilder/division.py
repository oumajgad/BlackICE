from brigade import Brigade
from utils import merge_dicts_and_add, divide_dict


class Division:
    brigades: list
    division_stats: dict

    def __init__(self):
        self.unit_count = 0
        self.brigades = list()
        self.division_stats = dict()

    def add_brigade(self, brigade: Brigade):
        self.brigades.append(brigade)
        self.calculate_stats()

    def remove_brigade(self, index):
        self.brigades.pop(index)
        self.calculate_stats()

    def calculate_stats(self):
        for brigade in self.brigades:
            s = brigade.current_stats
            self.division_stats = merge_dicts_and_add(self.division_stats, s)
        for key in self.division_stats:
            if isinstance(self.division_stats[key], dict):  # Terrain effects
                self.division_stats[key] = divide_dict(self.division_stats[key], len(self.brigades))

