from utils import merge_dicts_and_add


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
        self.start_year = int(raw_values.get("start_year", "1"))
        self.first_offset = int(raw_values.get("first_offset", "1"))
        self.additional_offset = int(raw_values.get("additional_offset", "1"))
        self.max_level = int(raw_values.get("max_level", "1"))
        self.units = {k: v for k, v in raw_values.items() if isinstance(v, dict) and k != "allow"}

    def get_unit_values(self, unit_name):
        for k, v in self.units.items():
            if k == unit_name:
                return v

    def get_unit_values_at_level(self, unit_name):
        values = dict(self.get_unit_values(unit_name))
        x = 0
        while x < self.level:
            values = merge_dicts_and_add(values, self.get_unit_values(unit_name))
            x += 1
        return values
