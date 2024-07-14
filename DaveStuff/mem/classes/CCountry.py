from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from structs.CountryFlag import CountryFlag
from structs.CountryVariable import CountryVariable
from structs.LinkedLists import LinkedListNode
from utils import utils


class CCountryOffsets:
    VFTABLE_OFFSET: int = 0x11C1BA8
    CDivisionTemplate_initial_array_ptr: int = 0x138
    CDivisionTemplate_current_array_ptr: int = 0x148
    available_CMinisters_linked_list_first_ptr: int = 0x160
    available_CMinisters_linked_list_last_ptr: int = 0x164
    CMinisters_linked_list_first_ptr: int = 0x170
    CMinisters_linked_list_last_ptr: int = 0x174
    CFlags_VFTABLE_PTR_1: int = 0x180
    CFlags_ptr: int = 0x184
    CFlags_amount: int = 0x18C
    CFlags_VFTABLE_PTR_2: int = 0x1A4
    CVariables_VFTABLE_PTR_1: int = 0x1AC
    CVariables_ptr: int = 0x1B0
    CVariables_VFTABLE_PTR_2: int = 0x1D0
    CEU3AI_ptr: int = 0x1D8
    CAIStrategy: int = 0x1DC
    tag: int = 0x1E4
    tag_id: int = 0x1E8
    controlled_provinces_linked_list_ptr: int = 0xD00


class CCountry(pydantic.BaseModel):
    COUNTRIES: ClassVar[list[int]] = None
    self_ptr: int
    CDivisionTemplate_initial_array_ptr: int  # has the umodified templates
    CDivisionTemplate_current_array_ptr: int  # has the template the way the player changed them
    available_CMinisters_linked_list_first_ptr: int
    available_CMinisters_linked_list_last_ptr: int
    CMinisters_linked_list_first_ptr: int
    CMinisters_linked_list_last_ptr: int
    CFlags_VFTABLE_PTR_1: int  # embedded into the class
    CFlags_ptr: int  # Flags are single chars saved as a Tree, offsets for each Node: +0x4 = current char, +0xc = the next node on the same level, +0x10 = the next deeper node
    # So a depth first algorithm needs to be implemented to build the names for each flag individually
    CFlags_amount: int
    CFlags_VFTABLE_PTR_2: int  # 2nd VFTABLE of the embedded class
    CVariables_VFTABLE_PTR_1: int  # embedded into the class
    CVariables_ptr: int  # Flags are single chars saved as a Tree, offsets for each Node: +0x4 = current char, +0xc = the next node on the same level, +0x10 = the next deeper node
    # So a depth first algorithm needs to be implemented to build the names for each flag individually
    CVariables_VFTABLE_PTR_2: int  # 2nd VFTABLE of the embedded class
    CEU3AI_ptr: int
    CAIStrategy: int  # embedded into the class
    tag: str
    tag_id: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "CDivisionTemplate_initial_array_ptr": pm.read_uint(
                ptr + CCountryOffsets.CDivisionTemplate_initial_array_ptr
            ),
            "CDivisionTemplate_current_array_ptr": pm.read_uint(
                ptr + CCountryOffsets.CDivisionTemplate_current_array_ptr
            ),
            "available_CMinisters_linked_list_first_ptr": pm.read_uint(
                ptr + CCountryOffsets.available_CMinisters_linked_list_first_ptr
            ),
            "available_CMinisters_linked_list_last_ptr": pm.read_uint(
                ptr + CCountryOffsets.available_CMinisters_linked_list_last_ptr
            ),
            "CMinisters_linked_list_first_ptr": pm.read_uint(ptr + CCountryOffsets.CMinisters_linked_list_first_ptr),
            "CMinisters_linked_list_last_ptr": pm.read_uint(ptr + CCountryOffsets.CMinisters_linked_list_last_ptr),
            "CFlags_VFTABLE_PTR_1": ptr + CCountryOffsets.CFlags_VFTABLE_PTR_1,
            "CFlags_ptr": pm.read_uint(ptr + CCountryOffsets.CFlags_ptr),
            "CFlags_amount": pm.read_uint(ptr + CCountryOffsets.CFlags_amount),
            "CFlags_VFTABLE_PTR_2": ptr + CCountryOffsets.CFlags_VFTABLE_PTR_2,
            "CVariables_VFTABLE_PTR_1": ptr + CCountryOffsets.CVariables_VFTABLE_PTR_1,
            "CVariables_ptr": pm.read_uint(ptr + CCountryOffsets.CVariables_ptr),
            "CVariables_VFTABLE_PTR_2": ptr + CCountryOffsets.CVariables_VFTABLE_PTR_2,
            "CEU3AI_ptr": pm.read_uint(ptr + CCountryOffsets.CEU3AI_ptr),
            "CAIStrategy": ptr + CCountryOffsets.CAIStrategy,
            "tag": pm.read_bytes(ptr + CCountryOffsets.tag, 3),
            "tag_id": utils.to_number(pm.read_bytes(ptr + CCountryOffsets.tag_id, 4)),
        }
        return cls(**temp)

    @classmethod
    def get_countries(cls, pm: Pymem) -> list[int]:
        if cls.COUNTRIES:
            return cls.COUNTRIES
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CCountryOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.COUNTRIES = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.COUNTRIES

    def get_ministers(self, available_only: bool = False):
        res = []
        if available_only:
            ptr = self.available_CMinisters_linked_list_first_ptr
        else:
            ptr = self.CMinisters_linked_list_first_ptr

        if ptr == 0:
            return res
        list_node = LinkedListNode.make(pm, ptr)
        while True:
            res.append(list_node.this)
            if list_node.next == 0:
                return res
            list_node = LinkedListNode.make(pm, list_node.next)

    @staticmethod
    def _build_names_from_tree_recursive(pm: Pymem, res: list, node_ptr: int, current_name: str = ""):
        character = pm.read_char(node_ptr + 0x4)
        next_sibling_node = pm.read_uint(node_ptr + 0xC)
        child_node = pm.read_uint(node_ptr + 0x10)
        # print(f"{node_ptr=} - {current_name=} - {character=} - {next_sibling_node=} - {child_node=}")
        new_name = current_name + character
        if child_node != 0:
            CCountry._build_names_from_tree_recursive(pm, res, child_node, new_name)
        if child_node == 0:
            # print(f"{node_ptr=} - {new_name=}")
            res.append(new_name)
        if next_sibling_node != 0:
            CCountry._build_names_from_tree_recursive(pm, res, next_sibling_node, current_name)

    @staticmethod
    def _traverse_tree_depth_first(pm: Pymem, res: list, node_ptr: int):
        character = pm.read_char(node_ptr + 0x4)
        next_sibling_node = pm.read_uint(node_ptr + 0xC)
        child_node = pm.read_uint(node_ptr + 0x10)
        element_ptr = pm.read_uint(node_ptr)
        # print(f"{node_ptr=} - {character=} - {next_sibling_node=} - {child_node=}")
        if element_ptr != 0:
            # print(f"{node_ptr=} - {element_ptr=}")
            res.append(element_ptr)
        if child_node != 0:
            CCountry._traverse_tree_depth_first(pm, res, child_node)
        if next_sibling_node != 0:
            CCountry._traverse_tree_depth_first(pm, res, next_sibling_node)

    def get_country_flags(self, pm: Pymem) -> list[str]:
        temp = []
        res = []
        if self.CFlags_ptr != 0:
            CCountry._traverse_tree_depth_first(pm, temp, self.CFlags_ptr)
            for ptr in temp:
                res.append(CountryFlag.make(pm, ptr))
        return res

    def get_country_variables(self, pm: Pymem) -> list[str]:
        temp = []
        res = []
        if self.CVariables_ptr != 0:
            CCountry._traverse_tree_depth_first(pm, temp, self.CVariables_ptr)
            for ptr in temp:
                res.append(CountryVariable.make(pm, ptr))
        return res


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    countries = CCountry.get_countries(pm)
    print(len(countries))
    print(utils.get_array_element_lengths(countries))
    for ptr in countries:
        country = CCountry.make(pm, ptr)
        if country.tag == "GER":
            print(utils.dump_model(country))
            print(f"{len(country.get_ministers(available_only=True))=}")
            flags = country.get_country_flags(pm)
            vars = country.get_country_variables(pm)
            print(f"{len(flags)=}")
            print(f"{len(vars)=}")
            for var in vars:
                print(var)
