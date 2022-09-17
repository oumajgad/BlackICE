from utils import merge_dicts_and_add
from copy import deepcopy


class Tech:
    raw_values: dict
    name: str
    level: int
    units: dict
    start_year: int
    first_offset: int
    additional_offset: int
    max_level: int

    def __init__(self, name: str, raw_values: dict):
        self.raw_values = dict(raw_values)
        self.name = name
        self.level = 0
        self.start_year = int(self.raw_values.get("start_year", "1"))
        self.first_offset = int(self.raw_values.get("first_offset", "1"))
        self.additional_offset = int(self.raw_values.get("additional_offset", "1"))
        self.max_level = int(self.raw_values.get("max_level", "1"))
        self.fix_toughness_value()
        self.units = {k: v for k, v in self.raw_values.items() if isinstance(v, dict) and k != "allow"}

    # Toughness gets double when applied in a tech
    def fix_toughness_value(self):
        for unit, unit_values in self.raw_values.items():
            if isinstance(unit_values, dict) and unit != "allow":
                for k, v in unit_values.items():
                    if k == "toughness":
                        self.raw_values[unit][k] = v * 2

    def get_unit_values(self, unit_name):
        for k, v in self.units.items():
            if k == unit_name:
                return deepcopy(v)

    def get_unit_values_at_level(self, unit_name):
        values = deepcopy(self.get_unit_values(unit_name))
        x = 1
        while x < self.level:
            values = merge_dicts_and_add(values, self.get_unit_values(unit_name))
            x += 1
        return values
