import wx
import json
from guiGenerated import MyFrame1
from tech import Tech
from brigade import Brigade
from division import Division
from copy import deepcopy


class Gui(MyFrame1):
    tech_list: list[Tech]
    unit_dict: dict[str, Brigade]
    current_brigade: Brigade
    current_division: Division
    current_tech: Tech
    wx_app: wx.App

    def set_up(self, tech_list, unit_dict):
        self.tech_list = tech_list
        self.unit_dict = unit_dict
        self.m_choice_brigades.SetItems([k for k in self.unit_dict])
        self.reset_division()
        self.current_brigade = None
        self.current_tech = None

    # Event methods
    def m_choice_brigadesOnChoice(self, event):
        # Reset stuff
        self.m_textCtrl_selected_tech.Clear()
        self.current_tech = None

        # Get selection
        choice_index = self.m_choice_brigades.GetSelection()
        name = self.m_choice_brigades.GetString(choice_index)
        unit = self.unit_dict.get(name)

        # Create Brigade
        self.current_brigade = Brigade(name, unit, self.tech_list)
        self.update_brigade_view()

    def m_listBox_techsOnListBox(self, event):
        self.calculate_selected_tech()

    def m_button_tech_increaseOnButtonClick(self, event):
        if self.current_tech is None:
            return
        self.current_tech.level += 1
        self.calculate_selected_tech()
        self.update_tech_level_view_increase()
        self.update_brigade_tech_level()

    def m_button_tech_decreaseOnButtonClick(self, event):
        if self.current_tech is None:
            return
        self.current_tech.level -= 1
        self.calculate_selected_tech()
        self.update_tech_level_view_decrease()
        self.update_brigade_tech_level()

    def m_button_add_to_divOnButtonClick(self, event):
        if self.current_brigade is None:
            return
        self.current_division.add_brigade(self.current_brigade)
        self.m_listBox_division_brigades.Append(self.current_brigade.name)
        self.update_division_view()
        self.current_brigade = deepcopy(self.current_brigade)
        self.update_brigade_view()

    def m_listBox_division_brigadesOnListBox(self, event):
        event.Skip()

    def m_button_edit_brigadeOnButtonClick(self, event):
        index = self.m_listBox_division_brigades.GetSelection()
        if index is wx.NOT_FOUND:
            return
        self.m_listBox_division_brigades.Delete(index)
        self.current_brigade = self.current_division.remove_brigade(index)
        self.update_brigade_view()
        self.m_choice_brigades.SetSelection(self.m_choice_brigades.FindString(self.current_brigade.name))
        self.update_division_view()

    def m_button_division_resetOnButtonClick(self, event):
        self.reset_division()

    # Extended Methods
    def update_brigade_view(self):
        # Fill stat textctrl
        self.m_textCtrl_selected_brigade.Clear()
        self.m_textCtrl_selected_brigade.SetValue(json.dumps(self.current_brigade.current_stats_ordered, indent=4))

        # Fill tech textctrl
        self.m_listBox_techs.Clear()
        techs = [f"[{v.level}] - {v.name}" for k, v in self.current_brigade.techs.items()]
        if len(techs) != 0:
            self.m_listBox_techs.InsertItems(techs, 0)

    def update_brigade_tech_level(self):
        self.current_brigade.change_tech_level(self.current_tech.name, self.current_tech.level)
        self.update_brigade_view()

    def calculate_selected_tech(self):
        # Get selection
        selection_index = self.m_listBox_techs.GetSelection()
        if selection_index != wx.NOT_FOUND:
            tech_name_raw: str = self.m_listBox_techs.GetString(selection_index)
            tech_name = tech_name_raw.split("-")[1].strip()
            # Create Tech
            self.current_tech = self.current_brigade.techs.get(tech_name)

        self.m_textCtrl_selected_tech.Clear()
        self.m_textCtrl_selected_tech.SetValue(
            f"Current level: {self.current_tech.level}\n"
            f"Max level: {self.current_tech.max_level}\n"
            f"Start year: {self.current_tech.start_year}\n"
            f"First offset: {self.current_tech.first_offset}\n"
            f"Additional offset: {self.current_tech.additional_offset}\n"
            f"{json.dumps(self.current_tech.get_unit_values_at_level(self.current_brigade.name), indent=4)}\n")

    def update_tech_level_view_increase(self):
        selection_index = self.m_listBox_techs.FindString(f"[{self.current_tech.level - 1}] - {self.current_tech.name}")
        self.m_listBox_techs.SetString(selection_index, f"[{self.current_tech.level}] - {self.current_tech.name}")

    def update_tech_level_view_decrease(self):
        selection_index = self.m_listBox_techs.FindString(f"[{self.current_tech.level + 1}] - {self.current_tech.name}")
        self.m_listBox_techs.SetString(selection_index, f"[{self.current_tech.level}] - {self.current_tech.name}")

    def reset_division(self):
        self.current_division = Division()
        self.m_textCtrl_current_division_stats.Clear()
        self.m_listBox_division_brigades.Clear()

    def update_division_view(self):
        self.m_textCtrl_current_division_stats.SetValue(json.dumps(self.current_division.division_stats_ordered, indent=4))

    def MyFrame1OnClose(self, event):
        self.wx_app.ExitMainLoop()
