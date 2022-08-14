import pyradox.load
from tech import Tech
from brigade import Brigade
from division import Division
from utils import to_dict
from time import time
from gui import Gui
from wx import App
# pyradox.config._basedirs = {'HoI3': r'D:\Dsafe\Hearts of Iron 3'}
pyradox.config._basedirs = {'HoI3': r'./'}
parse_techs, get_techs = pyradox.load.load_functions('HoI3', 'technologies', 'technologies', mode="merge")
parse_units, get_units = pyradox.load.load_functions('HoI3', 'units', 'units', mode="merge")


def build_tech_list():
    t1 = time()
    print("Getting technologies")
    techs_raw = get_techs()
    tech_list = list()
    t = to_dict(techs_raw)
    for k, v in t.items():
        new = Tech(k, v)
        tech_list.append(new)
    print(f"Finished technologies in {time() - t1}")
    return tech_list


def build_unit_dict():
    t1 = time()
    print("Getting units")
    units = to_dict(get_units())
    print(f"Finished units in {time() - t1}")
    return units


def prepare():
    t_list = build_tech_list()
    u_dict = build_unit_dict()
    return t_list, u_dict


def test1():
    unit_name1 = "armor_bat"
    brigade1 = Brigade(unit_name1, unit_dict.get(unit_name1), tech_list)
    brigade1.change_tech_level("armor_brigade_design", 5)
    unit_name2 = "artillery_brigade"
    brigade2 = Brigade(unit_name2, unit_dict.get(unit_name2), tech_list)
    brigade2.change_tech_level("artillery_activation", 5)
    division1 = Division()
    division1.add_brigade(brigade1)
    division1.add_brigade(brigade2)


def run_gui(tech_list: list[Tech], unit_dict: dict):
    app = App()
    gui = Gui(None)
    gui.set_up(tech_list, unit_dict)

    gui.Show()
    app.MainLoop()


if __name__ == '__main__':
    tech_list, unit_dict = prepare()
    run_gui(tech_list, unit_dict)

