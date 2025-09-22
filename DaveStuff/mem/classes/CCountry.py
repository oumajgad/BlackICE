import json
from typing import ClassVar

import pydantic
from pymem import Pymem

from arrays.ModifiersArray import ModifiersArray
from classes.CArmy import CArmy
from classes.CMinister import CMinister
from classes.CModifier import CModifier
from constants import DATA_SECTION_START
from structs.LinkedLists import LinkedListNode
from utils import utils


class CCountryOffsets:
    VFTABLE_OFFSET: int = 0x11C1BA8
    CDivisionTemplate_initial_array_ptr: int = 0x138  # has the umodified templates
    CDivisionTemplate_current_array_ptr: int = 0x148  # has the template the way the player changed them
    available_CMinisters_ll_first_ptr: int = 0x160
    available_CMinisters_ll_last_ptr: int = 0x164
    all_CMinisters_ll_first_ptr: int = 0x170
    all_CMinisters_ll_last_ptr: int = 0x174
    CFlags_VFTABLE_PTR_1: int = 0x180  # embedded into the class
    CFlags_amount: int = 0x18C
    CFlags_VFTABLE_PTR_2: int = 0x1A4  # 2nd VFTABLE of the embedded class
    CVariables_VFTABLE_PTR_1: int = 0x1AC  # embedded into the class
    CVariables_VFTABLE_PTR_2: int = 0x1D0  # 2nd VFTABLE of the embedded class
    CEU3AI_ptr: int = 0x1D8
    CAIStrategy: int = 0x1DC  # embedded into the class
    tag: int = 0x1E4
    tag_id: int = 0x1E8
    effective_ic: int = 0x604
    exact_base_ic_x1000: int = 0x610
    base_ic: int = 0x60C
    timed_modifiers_list_start_ptr: int = 0x648
    neutrality: int = 0xA8C
    at_war: bool = 0xACC
    war_exhaustion: int = 0xAD0
    units_ll_ptr: int = 0xBAC
    owned_provinces_ll_ptr: int = 0xCF0
    controlled_provinces_ID_ll_ptr: int = 0xD00
    general_modifier_array_ptr: int = 0xDA8
    CDiplomacyStatus_array_ptr: int = 0xE28  # array with pointers to all CDiplomacystatus
    national_unity: int = 0x10B8


class CCountry(pydantic.BaseModel):
    COUNTRIES: ClassVar[list[int]] = None
    self_ptr: int
    ptr_str: str
    # available_CMinisters: list[CMinister]
    # all_CMinisters: list[CMinister]
    # CFlags: CFlags
    CFlags_amount: int
    # CVariables: CVariables
    tag: str
    tag_id: int
    effective_ic: int
    exact_base_ic_x1000: int
    base_ic: int
    neutrality: int
    at_war: bool
    war_exhaustion: int
    # units: list[CArmy]
    CDiplomacyStatus_array_ptr: str  # array with pointers to all CDiplomacystatus

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        # print(f"Creating CCountry from {ptr}")
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
            # "available_CMinisters": cls.build_minsters_from_linked_list(
            #     pm, pm.read_uint(ptr + CCountryOffsets.available_CMinisters_ll_first_ptr)
            # ),
            # "all_CMinisters": cls.build_minsters_from_linked_list(
            #     pm, pm.read_uint(ptr + CCountryOffsets.all_CMinisters_ll_first_ptr)
            # ),
            # "CFlags": CFlags.make(pm, ptr + CCountryOffsets.CFlags_VFTABLE_PTR_1),
            "CFlags_amount": pm.read_uint(ptr + CCountryOffsets.CFlags_amount),
            # "CVariables": CVariables.make(pm, ptr + CCountryOffsets.CVariables_VFTABLE_PTR_1),
            "tag": pm.read_bytes(ptr + CCountryOffsets.tag, 3),
            "tag_id": utils.to_number(pm.read_bytes(ptr + CCountryOffsets.tag_id, 4)),
            "effective_ic": utils.to_number(pm.read_bytes(ptr + CCountryOffsets.effective_ic, 4)),
            "exact_base_ic_x1000": utils.to_number(pm.read_bytes(ptr + CCountryOffsets.exact_base_ic_x1000, 4)),
            "base_ic": utils.to_number(pm.read_bytes(ptr + CCountryOffsets.base_ic, 4)),
            "neutrality": utils.to_number(pm.read_bytes(ptr + CCountryOffsets.neutrality, 4)),
            "at_war": pm.read_bool(ptr + CCountryOffsets.at_war),
            "war_exhaustion": utils.to_number(pm.read_bytes(ptr + CCountryOffsets.war_exhaustion, 4)),
            # "units": cls.get_units(pm, ptr),
            "CDiplomacyStatus_array_ptr": utils.int_to_pointer(
                pm.read_uint(ptr + CCountryOffsets.CDiplomacyStatus_array_ptr)
            ),
        }
        return cls(**temp)

    @classmethod
    def get_countries(cls, pm: Pymem) -> list[int]:
        # print.debug(f"Getting all CCountry pointers.")
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
        # print.debug(f"Found {len(cls.COUNTRIES)} CCountry instances.")
        return cls.COUNTRIES

    @staticmethod
    def check_tag_from_ptr(pm: Pymem, ptr: int, tag: str):
        # print.debug(f"Checking for {tag} at {ptr}.")
        if ptr:
            x = pm.read_string(ptr + CCountryOffsets.tag, 3)
            # print.debug(x)
            if x == tag:
                return True
        return False

    @staticmethod
    def build_minsters_from_linked_list(pm: Pymem, ptr):
        res = []
        if ptr != 0:
            list_node = LinkedListNode.make(pm, ptr)
            while True:
                minister = CMinister.make(pm, list_node.this)
                res.append(minister)
                if list_node.next == 0:
                    break
                list_node = LinkedListNode.make(pm, list_node.next)
        return res

    @staticmethod
    def get_units(pm: Pymem, ptr) -> list[CArmy]:
        res = []
        list_ptr = pm.read_uint(ptr + CCountryOffsets.units_ll_ptr)
        if list_ptr != 0:
            list_node = LinkedListNode.make(pm, list_ptr)
            while True:
                unit = CArmy.make(pm, list_node.this)
                res.append(unit)
                if list_node.next == 0:
                    break
                list_node = LinkedListNode.make(pm, list_node.next)
        return res

    def get_active_modifiers(self):
        res = []
        node_ptr = pm.read_uint(self.self_ptr + CCountryOffsets.timed_modifiers_list_start_ptr)
        while node_ptr != 0:
            node = LinkedListNode.make(pm=pm, ptr=node_ptr)
            modifier = CModifier.make(pm=pm, ptr=node.this)
            res.append(modifier)
        return res


def get_all_countries(pm: Pymem) -> list[CCountry]:
    res = []
    countries = CCountry.get_countries(pm)
    for ptr in countries:
        # print.debug(ptr)
        country = CCountry.make(pm, ptr)
        res.append(country)
    return res


def get_country(pm: Pymem, tag: str) -> CCountry:
    countries = CCountry.get_countries(pm)
    for ptr in countries:
        if CCountry.check_tag_from_ptr(pm, ptr, tag):
            return CCountry.make(pm, ptr)


def dump_country(pm: Pymem, tag: str) -> str:
    c = get_country(pm, tag)
    return json.dumps(c.dict(), indent=2)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    country = get_country(pm, "GER")
    print(
        utils.dump_model(country, exlusions=["available_CMinisters", "all_CMinisters", "CFlags", "CVariables", "units"])
    )
    modifiers_ptr = pm.read_uint(country.self_ptr + CCountryOffsets.general_modifier_array_ptr)
    print(utils.int_to_pointer(modifiers_ptr))

    mods_arr = ModifiersArray.make(pm, modifiers_ptr)
    print(country)
    print(mods_arr.json())
