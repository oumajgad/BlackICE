import pyradox.load
from tech import Tech
from utils import to_dict
from time import time
from gui import Gui
from saveDialog import SaveDialog
from wx import App
from os import system
from traceback import print_exc

pyradox.config._basedirs = {'HoI3': r'./'} # Check your working directory config in the IDE
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


def run_gui(wx_app: App, tech_list: list[Tech], unit_dict: dict):
    gui = Gui(None)
    gui.wx_app = wx_app
    gui.set_up(tech_list, unit_dict)
    gui.Show()
    wx_app.MainLoop()


def run_dialog(wx_app: App, tech_list: list[Tech]):
    dialog = SaveDialog(None)
    dialog.wx_app = wx_app
    dialog.tech_list = tech_list
    dialog.Show()
    wx_app.MainLoop()
    dialog.Hide()


if __name__ == '__main__':
    try:
        wx_app = App()
        tech_list, unit_dict = prepare()
        run_dialog(wx_app, tech_list)
        run_gui(wx_app, tech_list, unit_dict)
    except Exception:
        print_exc()
        print("\nLooks like something went wrong.\n"
              "Please make sure you are launching the app from the BASE game/mod folder!\n")
        system("pause")
