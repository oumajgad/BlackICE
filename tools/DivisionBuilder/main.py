import pyradox.load
from tech import Tech
from brigade import Brigade
from division import Division
from utils import to_dict
from time import time
parse_techs, get_techs = pyradox.load.load_functions('HoI3', 'technologies', 'technologies', mode="merge")
parse_units, get_units = pyradox.load.load_functions('HoI3', 'units', 'units', mode="merge")


def build_tech_list():
    print("Getting technologies")
    techs = get_techs()
    tech_list = list()
    t = to_dict(techs)
    for k, v in t.items():
        new = Tech(k, v)
        tech_list.append(new)
    print("Finished technologies")
    return tech_list


def build_unit_dict():
    print("Getting units")
    units = to_dict(get_units())
    print("Finished units")
    return units


def prepare():
    t1 = time()
    t_list = build_tech_list()
    print(time() - t1)
    u_dict = build_unit_dict()
    print(time() - t1)
    return t_list, u_dict


if __name__ == '__main__':
    techs_list, unit_dict = prepare()
    unit_name1 = "armor_bat"
    brigade1 = Brigade(unit_name1, unit_dict.get(unit_name1), techs_list)
    brigade1.change_tech_level("armor_brigade_design", 5)
    unit_name2 = "artillery_brigade"
    brigade2 = Brigade(unit_name2, unit_dict.get(unit_name2), techs_list)
    brigade2.change_tech_level("artillery_activation", 5)
    division1 = Division()
    division1.add_brigade(brigade1)
    division1.add_brigade(brigade2)
    print(1)