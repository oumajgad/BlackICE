from brigade import Brigade
from utils import merge_dicts_and_add, divide_dict
from collections import OrderedDict


class Division:
    brigades: list[Brigade]
    land_terrain_base: dict[str, dict]  # The base modifiers defined in terrain.txt, NOT the actual brigades values
    combined_arms: dict[str, dict]
    unit_count: int
    division_stats: dict
    division_stats_ordered: OrderedDict

    def __init__(self, land_terrain_base: dict, combined_arms: dict):
        self.unit_count = 0
        self.brigades = list()
        self.division_stats = dict()
        self.land_terrain_base = land_terrain_base
        self.combined_arms = combined_arms

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

    def update_brigade_techs(self, tech_list):
        for brigade in self.brigades:
            brigade.update_techs(tech_list)

    def calculate_stats(self):
        self.division_stats = self.create_stat_baseline()
        if len(self.brigades) == 0:
            self.division_stats_ordered = OrderedDict()
            return
        self.division_stats["build_cost_ic"] = round(self.calculate_ic_cost(), 1)
        self.add_brigade_stats()

        for key in self.division_stats:
            if isinstance(self.division_stats[key], dict):  # Terrain effects
                self.division_stats[key] = divide_dict(self.division_stats[key], len(self.brigades))
        if self.division_stats.get("unit_group", None):
            self.division_stats.pop("unit_group")

        # Stats which need to be averaged
        self.division_stats["default_morale"] = round(self.division_stats.get("default_morale", 0) / len(self.brigades))
        self.division_stats["default_organisation"] = round(self.division_stats.get("default_organisation", 0) /
                                                            len(self.brigades))
        self.division_stats["softness"] = round(self.division_stats.get("softness", 0) / len(self.brigades))

        self.calculate_ca_bonus()
        self.add_base_terrain_values()

        # Round modifiers
        for key in self.division_stats:
            if isinstance(self.division_stats[key], dict):  # Terrain effects
                for modifier, value in self.division_stats[key].items():
                    self.division_stats[key][modifier] = round(self.division_stats[key][modifier])
        # Round some stats
        self.division_stats["toughness"] = round(self.division_stats["toughness"])
        self.division_stats["suppression"] = round(self.division_stats["suppression"])
        self.division_stats["soft_attack"] = round(self.division_stats["soft_attack"])
        self.division_stats["hard_attack"] = round(self.division_stats["hard_attack"])
        self.division_stats["officers"] = round(self.division_stats["officers"])
        self.division_stats["defensiveness"] = round(self.division_stats["defensiveness"])
        self.division_stats["air_defence"] = round(self.division_stats["air_defence"])
        self.division_stats["air_attack"] = round(self.division_stats["air_attack"])
        # 100x Values which need it
        self.division_stats["ca_bonus"] = round(self.division_stats["ca_bonus"] * 100)

        self.sort_stats()

    def sort_stats(self):
        self.division_stats_ordered = OrderedDict(sorted(self.division_stats.items()))
        new = OrderedDict(self.division_stats_ordered)
        for k, v in self.division_stats_ordered.items():
            if isinstance(v, dict):  # Terrain stats
                new[k] = OrderedDict(sorted(new[k].items()))
                new.move_to_end(k)
        if new.get("unit_group", None):
            new.pop("unit_group")
        new.move_to_end("can_paradrop", False)
        new.move_to_end("ca_bonus", False)
        new.move_to_end("ca_active", False)
        self.division_stats_ordered = new

    def add_brigade_stats(self):
        for brigade in self.brigades:
            temp_brigade: dict = dict(brigade.current_stats)
            if temp_brigade.get("maximum_speed", 10000) < self.division_stats.get("maximum_speed", 10000):
                self.division_stats["maximum_speed"] = temp_brigade["maximum_speed"]
            if temp_brigade.get("build_time", 0) > self.division_stats.get("build_time", 0):
                self.division_stats["build_time"] = round(temp_brigade["build_time"])
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

    def calculate_ca_bonus(self):
        self.division_stats["ca_active"] = False
        self.division_stats["ca_bonus"] = 0
        active_groups = []
        for brigade in self.brigades:
            if brigade.current_stats.get("unit_group", None):
                unit_group = self.combined_arms.get(brigade.current_stats.get("unit_group"), None)
                if unit_group and unit_group not in active_groups:
                    active_groups.append(unit_group)
                    self.division_stats["ca_bonus"] += unit_group.get("value", 0)
                    if unit_group.get("base", False):
                        self.division_stats["ca_active"] = True

    def calculate_ic_cost(self):
        total_cost = 0
        total_days = 0
        for brigade in self.brigades:
            total_cost += brigade.current_stats["build_cost_ic"]
            total_days += brigade.current_stats["build_time"]
        return total_cost / total_days

    def add_base_terrain_values(self):
        for k in self.land_terrain_base:
            if self.division_stats.get(k, None) is None:
                self.division_stats[k] = dict()
            self.division_stats[k]["attack"] = ((self.land_terrain_base[k].get("attack", 0) * 100)
                                                + self.division_stats[k].get("attack", 0))
            self.division_stats[k]["defence"] = ((self.land_terrain_base[k].get("defence", 0) * 100)
                                                 + self.division_stats[k].get("defence", 0))
            self.division_stats[k]["movement"] = ((self.land_terrain_base[k].get("movement", 0) * 100)
                                                  + self.division_stats[k].get("movement", 0))

    def create_stat_baseline(self):
        new = dict()
        stats_list = ['max_strength', 'default_organisation', 'default_morale', 'officers', 'build_cost_ic',
                      'build_cost_manpower', 'build_time', 'transport_weight', 'supply_consumption',
                      'fuel_consumption', 'radio_strength', 'defensiveness', 'toughness', 'softness', 'air_defence',
                      'suppression', 'soft_attack', 'hard_attack', 'air_attack', 'ap_attack', 'combat_width',
                      'armor_value']
        terrain_list = ['plains', 'river', 'urban', 'arctic', 'desert', 'woods', 'forest', 'jungle', 'hills',
                        'mountain', 'marsh', 'fort', 'amphibious', 'night']
        for stat in stats_list:
            new[stat] = 0
        for terrain in terrain_list:
            new[terrain] = {"attack": 0, "defence": 0, "movement": 0, "attrition": 0}
        new["can_paradrop"] = True
        new["ca_active"] = False
        new["ca_bonus"] = 0
        new["maximum_speed"] = 10000
        return new
