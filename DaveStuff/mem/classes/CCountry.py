import json
from typing import ClassVar

import pydantic
from pymem import Pymem

from classes.CArmy import CArmy
from classes.CFlags import CFlags
from classes.CMinister import CMinister
from classes.CVariables import CVariables
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
    units_ll_ptr: int = 0xBAC
    owned_provinces_ll_ptr: int = 0xCF0
    controlled_provinces_ll_ptr: int = 0xD00


class CCountry(pydantic.BaseModel):
    COUNTRIES: ClassVar[list[int]] = None
    self_ptr: int
    available_CMinisters: list[CMinister]
    all_CMinisters: list[CMinister]
    CFlags: CFlags
    CFlags_amount: int
    CVariables: CVariables
    tag: str
    tag_id: int
    units: list[CArmy]

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        # print(f"Creating CCountry from {ptr}")
        temp = {
            "self_ptr": ptr,
            "available_CMinisters": cls.build_minsters_from_linked_list(
                pm, pm.read_uint(ptr + CCountryOffsets.available_CMinisters_ll_first_ptr)
            ),
            "all_CMinisters": cls.build_minsters_from_linked_list(
                pm, pm.read_uint(ptr + CCountryOffsets.all_CMinisters_ll_first_ptr)
            ),
            "CFlags": CFlags.make(pm, ptr + CCountryOffsets.CFlags_VFTABLE_PTR_1),
            "CFlags_amount": pm.read_uint(ptr + CCountryOffsets.CFlags_amount),
            "CVariables": CVariables.make(pm, ptr + CCountryOffsets.CVariables_VFTABLE_PTR_1),
            "tag": pm.read_bytes(ptr + CCountryOffsets.tag, 3),
            "tag_id": utils.to_number(pm.read_bytes(ptr + CCountryOffsets.tag_id, 4)),
            "units": cls.get_units(pm, ptr),
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
    print(pm.base_address + DATA_SECTION_START)
    x = utils.rawbytes(
        (pm.base_address + CCountryOffsets.VFTABLE_OFFSET).to_bytes(length=4, byteorder="little", signed=False).hex()
    )
    print(x)
    # countries = CCountry.get_countries(pm)
    # print(len(countries))
    # print(utils.get_array_element_lengths(countries))
    # with open("out.json", "w") as f:
    #     out = {countries: get_all_countries(pm)}
    #     f.write(json.dumps(out, indent=2))
    country = get_country(pm, "USA")
    print(
        utils.dump_model(country, exlusions=["available_CMinisters", "all_CMinisters", "CFlags", "CVariables", "units"])
    )
    print(utils.int_to_pointer(country.self_ptr))
    # # print(f"{len(country.available_CMinisters)=}")
    # # print(f"{len(country.CFlags.flags)=}")
    # # print(f"{len(country.CVariables.variables)=}")
    # # print(f"{len(country.units)=}")
    # #
    # # with open("out.json", "w") as f:
    # #     f.write(utils.dump_model(country))
    # # exit(0)
