import wx
import json
import pickle
from guiGenerated import MyFrame1
from tech import Tech
from brigade import Brigade
from division import Division
from copy import deepcopy


class Gui(MyFrame1):
    wx_app: wx.App
    tech_list: list[Tech]
    unit_dict: dict[str, dict]
    land_terrain: dict[str, dict]
    combined_arms: dict[str, dict]
    builder_current_brigade: Brigade
    search_current_division_brigade: Brigade
    search_searched_brigade: Brigade
    search_brigade_list: list[Brigade]
    current_division: Division
    current_tech: Tech
    templates: dict[str, Division]
    division_a: Division
    division_b: Division
    division_c: Division
    division_d: Division
    division_e: Division
    compare_scrolling_latest_pos: int
    scroll_a_pos: int
    scroll_b_pos: int
    scroll_c_pos: int
    scroll_d_pos: int
    scroll_e_pos: int

    def set_up(self, tech_list: list[Tech], unit_dict: dict, land_terrain: dict, combined_arms: dict):
        self.tech_list = tech_list
        self.unit_dict = unit_dict
        self.land_terrain = land_terrain
        self.combined_arms = combined_arms
        self.m_choice_brigades.SetItems([k for k in self.unit_dict])
        self.reset_division()
        self.builder_current_brigade = None
        self.current_tech = None
        try:
            self.load_templates()
        except FileNotFoundError as e:
            print(f"Could not load save templates: {e}")
            print("Creating new empty template list.")
            self.templates = dict()
        self.create_brigade_list_for_search()
        self.compare_scrolling_latest_pos = 0
        self.scroll_a_pos = 0
        self.scroll_b_pos = 0
        self.scroll_c_pos = 0
        self.scroll_d_pos = 0
        self.scroll_e_pos = 0

    def create_brigade_list_for_search(self):
        print("Creating brigade list for search & sort...")
        self.search_brigade_list = list()
        unit_len = len(self.unit_dict)
        z = 0
        for k, v in self.unit_dict.items():
            z += 1
            print(f"Creating Brigade {z}/{unit_len}           ", end="\r")
            brigade = Brigade(k, v, self.tech_list)
            self.search_brigade_list.append(brigade)
        print(f"Created {unit_len} brigades for search & sort.")

    # Event methods
    # Builder Page
    def m_choice_brigadesOnChoice(self, event):
        # Reset stuff
        self.m_textCtrl_selected_tech.Clear()
        self.current_tech = None
        self.m_choice_brigades_searched.SetSelection(wx.NOT_FOUND)

        # Get selection
        choice_index = self.m_choice_brigades.GetSelection()
        name = self.m_choice_brigades.GetString(choice_index)
        unit = self.unit_dict.get(name)

        # Create Brigade
        self.builder_current_brigade = Brigade(name, unit, self.tech_list)
        self.update_builder_brigade_view()

    def m_choice_brigades_searchedOnChoice(self, event):
        # Reset stuff
        self.m_textCtrl_selected_tech.Clear()
        self.current_tech = None
        self.m_choice_brigades.SetSelection(wx.NOT_FOUND)

        # Get selection
        choice_index = self.m_choice_brigades_searched.GetSelection()
        name = self.m_choice_brigades_searched.GetString(choice_index)
        unit = self.unit_dict.get(name)

        # Create Brigade
        self.builder_current_brigade = Brigade(name, unit, self.tech_list)
        self.update_builder_brigade_view()

    def m_textCtrl_brigade_searchOnTextEnter(self, event):
        search_string = self.m_textCtrl_brigade_search.GetValue().lower()
        self.m_choice_brigades_searched.Clear()
        self.m_choice_brigades_searched.SetItems([k for k in self.unit_dict if search_string in k])
        if self.m_choice_brigades_searched.GetCount() > 0:
            self.m_choice_brigades_searched.SetSelection(0)
            self.m_choice_brigades_searchedOnChoice(None)

    def m_listBox_techsOnListBox(self, event):
        self.calculate_selected_tech()

    def m_button_tech_increaseOnButtonClick(self, event):
        if self.current_tech is None:
            return
        self.current_tech.level += 1
        self.update_brigade_tech_level()
        self.calculate_selected_tech()

    def m_button_tech_decreaseOnButtonClick(self, event):
        if self.current_tech is None:
            return
        if self.current_tech.level <= 0:
            return
        self.current_tech.level -= 1
        self.update_brigade_tech_level()
        self.calculate_selected_tech()

    def m_button_add_to_divOnButtonClick(self, event):
        if self.builder_current_brigade is None:
            return
        self.current_division.add_brigade(self.builder_current_brigade)
        self.update_division_view()
        self.builder_current_brigade = deepcopy(self.builder_current_brigade)
        self.update_builder_brigade_view()

    def m_listBox_division_brigadesOnListBox(self, event):
        self.builder_current_brigade = self.current_division.brigades[self.m_listBox_division_brigades.GetSelection()]
        self.update_builder_brigade_view()

        # Set Brigade selection
        li = self.m_choice_brigades.GetItems()
        self.m_choice_brigades.SetSelection(li.index(self.builder_current_brigade.name))

    def m_button_delete_brigadeOnButtonClick(self, event):
        index = self.m_listBox_division_brigades.GetSelection()
        if index is wx.NOT_FOUND:
            return
        self.m_listBox_division_brigades.Delete(index)
        self.current_division.remove_brigade(index)
        self.update_division_view()

    def m_button_division_resetOnButtonClick(self, event):
        self.reset_division()
        self.m_textCtrl_template_name.Clear()
        self.m_listBox_templates.SetSelection(wx.NOT_FOUND)

    def m_button_template_loadOnButtonClick(self, event):
        selection_index = self.m_listBox_templates.GetSelection()
        if selection_index != wx.NOT_FOUND:
            self.reset_division()

            template_name = self.m_listBox_templates.GetString(selection_index)
            self.m_textCtrl_template_name.SetValue(template_name)
            self.current_division = deepcopy(self.templates.get(template_name))
            self.current_division.calculate_stats_fully()
            self.update_division_view()

    def m_button_template_saveOnButtonClick(self, event):
        if self.m_textCtrl_template_name.IsEmpty():
            return
        template_name = self.m_textCtrl_template_name.GetValue()
        self.templates[template_name] = deepcopy(self.current_division)
        self.write_templates()

    def m_button_templates_deleteOnButtonClick(self, event):
        selection_index = self.m_listBox_templates.GetSelection()
        if selection_index != wx.NOT_FOUND:
            template_name = self.m_listBox_templates.GetString(selection_index)
            self.templates.pop(template_name)
        self.write_templates()

    # Compare Page
    def m_choice_div_aOnChoice(self, event):
        self.add_div_to_compare("a")

    def m_choice_div_bOnChoice(self, event):
        self.add_div_to_compare("b")

    def m_choice_div_cOnChoice(self, event):
        self.add_div_to_compare("c")

    def m_choice_div_dOnChoice(self, event):
        self.add_div_to_compare("d")

    def m_choice_div_eOnChoice(self, event):
        self.add_div_to_compare("e")

    def m_button_div_a_clearOnButtonClick(self, event):
        self.remove_div_from_compare("a")

    def m_button_div_b_clearOnButtonClick(self, event):
        self.remove_div_from_compare("b")

    def m_button_div_c_clearOnButtonClick(self, event):
        self.remove_div_from_compare("c")

    def m_button_div_d_clearOnButtonClick(self, event):
        self.remove_div_from_compare("d")

    def m_button_div_e_clearOnButtonClick(self, event):
        self.remove_div_from_compare("e")

    # Search Page
    def m_button17_search_sortOnButtonClick(self, event):
        search_term: str = self.m_textCtrl15_search_stat_name.GetValue()
        if search_term.count(":") == 1:
            split = search_term.split(":")
            sorted_list, output_list = self.sort_brigade_search_terrain(split[0], split[1])
        else:
            sorted_list, output_list = self.sort_brigade_search_simple(search_term)
        self.m_listBox_searched_brigades.Clear()
        self.m_listBox_searched_brigades.SetItems(output_list)

    def m_textCtrl15_search_stat_nameOnTextEnter(self, event):
        self.m_button17_search_sortOnButtonClick(event)

    def m_listBox_searched_brigadesOnListBox(self, event):
        index = self.m_listBox_searched_brigades.GetSelection()
        name_raw = self.m_listBox_searched_brigades.GetString(index)
        name = name_raw.split("- ")[1].strip()
        self.search_searched_brigade = Brigade(name, self.unit_dict.get(name), self.tech_list)
        self.m_textCtrl_search_searched_brigade_stats.Clear()
        self.m_textCtrl_search_searched_brigade_stats.SetValue(
            json.dumps(self.search_searched_brigade.current_stats_ordered, indent=4))

    def m_button_search_searched_brigade_addOnButtonClick(self, event):
        if self.search_searched_brigade is None:
            return
        self.current_division.add_brigade(self.search_searched_brigade)
        self.update_division_view()
        self.search_searched_brigade = deepcopy(self.search_searched_brigade)

    def m_button_search_selected_brigade_removeOnButtonClick(self, event):
        index = self.m_listBox_search_division_brigades.GetSelection()
        if index is wx.NOT_FOUND:
            return
        self.m_listBox_search_division_brigades.Delete(index)
        self.current_division.remove_brigade(index)
        self.update_division_view()
        self.search_current_division_brigade = None
        self.m_textCtrl_search_selected_brigade_stats.Clear()

    def m_listBox_search_division_brigadesOnListBox(self, event):
        self.search_current_division_brigade = \
            self.current_division.brigades[self.m_listBox_search_division_brigades.GetSelection()]
        self.update_search_selected_brigade_view()

    # Extended Methods

    # Builder Page
    def reset_brigade_view(self):
        # Builder Page
        self.m_textCtrl_selected_brigade.Clear()
        self.m_listBox_techs.Clear()
        self.m_textCtrl_selected_tech.Clear()

    def update_builder_brigade_view(self):
        self.reset_brigade_view()
        # Builder Page
        self.m_textCtrl_selected_brigade.SetValue(json.dumps(self.builder_current_brigade.current_stats_ordered, indent=4))

        # Fill tech textctrl
        techs = [f"[{v}] - {k}" for k, v in self.builder_current_brigade.techs.items()]
        if len(techs) != 0:
            self.m_listBox_techs.InsertItems(techs, 0)

    def update_brigade_tech_level(self):
        self.builder_current_brigade.change_tech_level(self.current_tech.name, self.current_tech.level)
        self.update_builder_brigade_view()
        self.update_division_view_stats()

    def calculate_selected_tech(self):
        # Get selection
        selection_index = self.m_listBox_techs.GetSelection()
        if selection_index != wx.NOT_FOUND:
            tech_name_raw: str = self.m_listBox_techs.GetString(selection_index)
            tech_name = tech_name_raw.split("-")[1].strip()
            # Create Tech
            for tech in self.tech_list:
                if tech.name == tech_name:
                    self.current_tech = deepcopy(tech)
                    self.current_tech.level = self.builder_current_brigade.techs[tech_name]
                    break

        self.m_textCtrl_selected_tech.Clear()
        self.m_textCtrl_selected_tech.SetValue(
            f"Current level: {self.current_tech.level}\n"
            f"Max level: {self.current_tech.max_level}\n"
            f"Start year: {self.current_tech.start_year}\n"
            f"First offset: {self.current_tech.first_offset}\n"
            f"Additional offset: {self.current_tech.additional_offset}\n"
            f"{json.dumps(self.current_tech.get_unit_values_at_level(self.builder_current_brigade.name), indent=4)}\n")

    def update_tech_level_view_increase(self):
        selection_index = self.m_listBox_techs.FindString(f"[{self.current_tech.level - 1}] - {self.current_tech.name}")
        self.m_listBox_techs.SetString(selection_index, f"[{self.current_tech.level}] - {self.current_tech.name}")

    def update_tech_level_view_decrease(self):
        selection_index = self.m_listBox_techs.FindString(f"[{self.current_tech.level + 1}] - {self.current_tech.name}")
        self.m_listBox_techs.SetString(selection_index, f"[{self.current_tech.level}] - {self.current_tech.name}")

    def reset_division(self):
        self.current_division = Division(self.land_terrain, self.combined_arms)
        # Builder Page
        self.m_textCtrl_current_division_stats.Clear()
        self.m_listBox_division_brigades.Clear()
        # Search Page
        self.m_listBox_search_division_brigades.Clear()
        self.m_textCtrl_search_current_division_stats.Clear()

    def update_division_view(self):
        # Builder Page
        self.m_listBox_division_brigades.SetItems([x.name for x in self.current_division.brigades])
        self.m_textCtrl_current_division_stats.SetValue(
            json.dumps(self.current_division.division_stats_ordered, indent=4))
        # Search Page
        self.m_listBox_search_division_brigades.SetItems([x.name for x in self.current_division.brigades])
        self.m_textCtrl_search_current_division_stats.SetValue(
            json.dumps(self.current_division.division_stats_ordered, indent=4))

    def update_division_view_stats(self):
        self.current_division.calculate_stats()
        # Builder Page
        self.m_textCtrl_current_division_stats.SetValue(
            json.dumps(self.current_division.division_stats_ordered, indent=4))
        # Search Page
        self.m_textCtrl_search_current_division_stats.SetValue(
            json.dumps(self.current_division.division_stats_ordered, indent=4))

    def update_template_view(self):
        self.templates = dict(sorted(self.templates.items()))
        str_list = [str(x) for x in self.templates.keys()]
        self.m_listBox_templates.SetItems(str_list)

        for x in ["a", "b", "c", "d", "e"]:
            choice_obj: wx.Choice = getattr(self, f"m_choice_div_{x}")
            selection = choice_obj.GetSelection()
            selection_str = str()

            if selection != wx.NOT_FOUND:
                selection_str = choice_obj.GetString(selection)

            choice_obj.SetItems(str_list)

            if selection == wx.NOT_FOUND or selection_str not in str_list:
                textctrl: wx.TextCtrl = getattr(self, f"m_textCtrl_compare_div_{x}")
                textctrl.Clear()
                continue

            choice_obj.SetSelection(str_list.index(selection_str))
            self.add_div_to_compare(x)

    # Compare Page
    def add_div_to_compare(self, div: str):
        choice_obj: wx.Choice = getattr(self, f"m_choice_div_{div}")
        selection_index = choice_obj.GetSelection()
        if selection_index != wx.NOT_FOUND:
            template_name = choice_obj.GetString(selection_index)
            division: Division = deepcopy(self.templates.get(template_name))
            textctrl: wx.TextCtrl = getattr(self, f"m_textCtrl_compare_div_{div}")
            division.calculate_stats_fully()
            setattr(self, f"division_{div}", division)
            textctrl.Clear()
            textctrl.SetValue(json.dumps(division.division_stats_ordered, indent=4))

    def remove_div_from_compare(self, div: str):
        setattr(self, f"division_{div}", None)
        textctrl: wx.TextCtrl = getattr(self, f"m_textCtrl_compare_div_{div}")
        textctrl.Clear()
        choice: wx.Choice = getattr(self, f"m_choice_div_{div}")
        choice.SetSelection(wx.NOT_FOUND)

    # Search Page
    def sort_brigade_search_simple(self, search_term):
        sorted_list = sorted(self.search_brigade_list, key=lambda x: x.current_stats.get(search_term, 0), reverse=True)
        filtered_list = self.filter_search_list(sorted_list)
        output_list = [f"[{x.current_stats.get(search_term, 0)}]\t- {x.name}" for x in filtered_list]
        return sorted_list, output_list

    def sort_brigade_search_terrain(self, terrain, modifier):
        sorted_list = sorted(self.search_brigade_list,
                             key=lambda x: x.current_stats.get(terrain, dict()).get(modifier, 0), reverse=True)
        filtered_list = self.filter_search_list(sorted_list)
        output_list = [f"[{x.current_stats.get(terrain, dict()).get(modifier, 0)}]\t- {x.name}" for x in filtered_list]
        return sorted_list, output_list

    def filter_search_list(self, list_a):
        filter_army = self.m_checkBox_search_filter_army.GetValue()
        filter_ships = self.m_checkBox_search_filter_ships.GetValue()
        filter_planes = self.m_checkBox_search_filter_planes.GetValue()
        filter_hqs = self.m_checkBox_search_filter_hqs.GetValue()
        list_b = list(list_a)
        if filter_army:
            list_b = list(filter(lambda x: (x.current_stats.get("suppression", False) is False or
                                            x.current_stats.get("transport_weight", False) is False or
                                            x.current_stats.get("softness", False) is False), list_b))
        if filter_ships:
            list_b = list(filter(lambda x: (x.current_stats.get("hull", False) is False), list_b))
        if filter_planes:
            list_b = list(filter(lambda x: (x.current_stats.get("strategic_attack", False) is False or
                                            x.current_stats.get("surface_defence", False) is False), list_b))
        if filter_hqs:
            types = ["blank", "division_HQ_unit_type", "veteran_division_HQ_unit_type",
                     "elite_division_HQ_unit_type", "corps_HQ_unit_type", "mot_HQ_unit_type"]
            list_b = list(filter(lambda x: (x.current_stats.get("unit_group", "blank") not in types), list_b))
        return list_b

    def update_search_selected_brigade_view(self):
        self.m_textCtrl_search_selected_brigade_stats.Clear()
        self.m_textCtrl_search_selected_brigade_stats.SetValue(json.dumps(
            self.search_current_division_brigade.current_stats_ordered, indent=4))

    # Others
    def write_templates(self):
        with open("DivisionBuilderTemplates.dat", "wb") as t_file:
            pickle.dump(self.templates, t_file, pickle.HIGHEST_PROTOCOL)
        self.update_template_view()

    def load_templates(self):
        with open("DivisionBuilderTemplates.dat", "rb") as t_file:
            self.templates = pickle.load(t_file)
        self.update_template_view()
        # Check for brigades with the old way of saving techs
        for name, division in self.templates.items():
            transformed = False
            division: Division
            for brigade in division.brigades:
                brigade: Brigade
                for k, v in brigade.techs.items():
                    if isinstance(v, Tech):
                        brigade.transform_techs(self.tech_list)
                        transformed = True
                        break
            division.update_brigade_techs(self.tech_list)
            division.land_terrain_base = self.land_terrain
            division.combined_arms = self.combined_arms
            division.calculate_stats_fully()
            if transformed:
                print(f"Transformed old division template: '{name}'")

    def MyFrame1OnClose(self, event):
        self.wx_app.ExitMainLoop()

    # Compare page scrollbar syncing
    def sync_scroll(self, element):
        cols = ["a", "b", "c", "d", "e"]
        for x in cols:
            if x == element:
                continue
            check: wx.CheckBox = getattr(self, f"m_checkBox_comp_sync_{x}")
            if check.GetValue():
                ctrl: wx.TextCtrl = getattr(self, f"m_textCtrl_compare_div_{x}")
                pos = ctrl.GetScrollPos(wx.VERTICAL)
                pos_g = self.compare_scrolling_latest_pos
                ctrl.SetScrollPos(wx.VERTICAL, pos_g)
                ctrl.ScrollLines(pos_g - pos)
                setattr(self, f"scroll_{x}_pos", pos_g)

    def m_textCtrl_compare_div_aOnUpdateUI(self, event):
        if self.m_checkBox_comp_sync_a.GetValue():
            pos = self.m_textCtrl_compare_div_a.GetScrollPos(wx.VERTICAL)
            if pos != self.compare_scrolling_latest_pos:
                self.compare_scrolling_latest_pos = pos
                self.sync_scroll("a")

    def m_textCtrl_compare_div_bOnUpdateUI(self, event):
        if self.m_checkBox_comp_sync_b.GetValue():
            pos = self.m_textCtrl_compare_div_b.GetScrollPos(wx.VERTICAL)
            if pos != self.compare_scrolling_latest_pos:
                self.compare_scrolling_latest_pos = pos
                self.sync_scroll("b")

    def m_textCtrl_compare_div_cOnUpdateUI(self, event):
        if self.m_checkBox_comp_sync_c.GetValue():
            pos = self.m_textCtrl_compare_div_c.GetScrollPos(wx.VERTICAL)
            if pos != self.compare_scrolling_latest_pos:
                self.compare_scrolling_latest_pos = pos
                self.sync_scroll("c")

    def m_textCtrl_compare_div_dOnUpdateUI(self, event):
        if self.m_checkBox_comp_sync_d.GetValue():
            pos = self.m_textCtrl_compare_div_d.GetScrollPos(wx.VERTICAL)
            if pos != self.compare_scrolling_latest_pos:
                self.compare_scrolling_latest_pos = pos
                self.sync_scroll("d")

    def m_textCtrl_compare_div_eOnUpdateUI(self, event):
        if self.m_checkBox_comp_sync_e.GetValue():
            pos = self.m_textCtrl_compare_div_e.GetScrollPos(wx.VERTICAL)
            if pos != self.compare_scrolling_latest_pos:
                self.compare_scrolling_latest_pos = pos
                self.sync_scroll("e")
