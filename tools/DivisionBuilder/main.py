import pyradox.load
import pyradox.txt
from tech import Tech
from utils import to_dict
from time import time
from gui import Gui
from saveDialog import SaveDialog
from wx import App
from os import system
from traceback import print_exc

pyradox.config._basedirs = {'HoI3': r'./'}  # Check your working directory config in the IDE
parse_techs, get_techs = pyradox.load.load_functions('HoI3', 'technologies', 'technologies', mode="merge")
parse_units, get_units = pyradox.load.load_functions('HoI3', 'units', 'units', mode="merge")


def build_tech_list():
    t1 = time()
    print("Getting technologies...")
    techs_raw = get_techs()
    tech_list = list()
    t = to_dict(techs_raw)
    for k, v in t.items():
        new = Tech(k, v)
        tech_list.append(new)
    print(f"Finished technologies in {time() - t1}.")
    return tech_list


def build_unit_dict():
    t1 = time()
    print("Getting units...")
    units = to_dict(get_units())
    print(f"Finished units in {time() - t1}.")
    return units


def build_land_terrain():
    t = pyradox.txt.parse_file("./map\\terrain.txt")
    terrains_raw = to_dict(t).get("categories")
    terrains_ret = dict()
    for k in terrains_raw:
        if not terrains_raw[k].get("is_water", False):
            terrains_ret[k] = dict()
            terrains_ret[k]["attack"] = terrains_raw[k].get("attack", 0)
            terrains_ret[k]["defence"] = terrains_raw[k].get("defence", 0)
    return terrains_ret


def build_combined_arms():
    x = pyradox.txt.parse_file("./common\\combined_arms.txt")
    cg = to_dict(x).get("combined_arms")
    return cg


def prepare():
    try:
        t_list = build_tech_list()
        u_dict = build_unit_dict()
        l_terrains = build_land_terrain()
        c_arms = build_combined_arms()
        return t_list, u_dict, l_terrains, c_arms
    except Exception:
        print_exc()
        print("\nLooks like something went wrong.\n"
              "Please make sure you are launching the app from the BASE game/mod folder!\n")
        system("pause")
        exit(1)


def run_gui(wx_app: App, tech_list: list[Tech], unit_dict: dict, land_terrain: dict, combined_arms: dict):
    t1 = time()
    print("Setting up GUI...")
    gui = Gui(None)
    gui.wx_app = wx_app
    gui.set_up(tech_list, unit_dict, land_terrain, combined_arms)
    gui.Show()
    print(f"Finished setting up GUI in {time() - t1}")
    wx_app.MainLoop()


def run_dialog(wx_app: App, tech_list: list[Tech]):
    dialog = SaveDialog(None)
    dialog.wx_app = wx_app
    dialog.tech_list = tech_list
    dialog.Show()
    wx_app.MainLoop()
    dialog.Hide()


def main():
    wx_app = App()
    tech_list, unit_dict, land_terrain, combined_arms = prepare()
    run_dialog(wx_app, tech_list)
    run_gui(wx_app, tech_list, unit_dict, land_terrain, combined_arms)


if __name__ == '__main__':
    main()
