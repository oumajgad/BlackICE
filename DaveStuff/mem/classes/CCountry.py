from typing import ClassVar

import pydantic
from pymem import Pymem

from classes.CArmy import CArmy
from classes.CFlag import CFlag
from classes.CFlags import CFlags
from classes.CVariable import CVariable
from classes.CVariables import CVariables
from constants import DATA_SECTION_START
from structs.LinkedLists import LinkedListNode
from utils import utils


class CCountryOffsets:
    VFTABLE_OFFSET: int = 0x11C1BA8
    CDivisionTemplate_initial_array_ptr: int = 0x138
    CDivisionTemplate_current_array_ptr: int = 0x148
    available_CMinisters_ll_first_ptr: int = 0x160
    available_CMinisters_ll_last_ptr: int = 0x164
    CMinisters_ll_first_ptr: int = 0x170
    CMinisters_ll_last_ptr: int = 0x174
    CFlags_VFTABLE_PTR_1: int = 0x180  # embedded into the class
    CFlags_amount: int = 0x18C
    CFlags_VFTABLE_PTR_2: int = 0x1A4  # 2nd VFTABLE of the embedded class
    CVariables_VFTABLE_PTR_1: int = 0x1AC  # embedded into the class
    CVariables_VFTABLE_PTR_2: int = 0x1D0  # 2nd VFTABLE of the embedded class
    CEU3AI_ptr: int = 0x1D8
    CAIStrategy: int = 0x1DC
    tag: int = 0x1E4
    tag_id: int = 0x1E8
    units_ll_ptr: int = 0xBAC
    owned_provinces_ll_ptr: int = 0xCF0
    controlled_provinces_ll_ptr: int = 0xD00


class CCountry(pydantic.BaseModel):
    COUNTRIES: ClassVar[list[int]] = None
    self_ptr: int
    CDivisionTemplate_initial_array_ptr: int  # has the umodified templates
    CDivisionTemplate_current_array_ptr: int  # has the template the way the player changed them
    available_CMinisters_ll_first_ptr: int
    available_CMinisters_ll_last_ptr: int
    CMinisters_ll_first_ptr: int
    CMinisters_ll_last_ptr: int
    CFlags: CFlags
    CFlags_amount: int
    CVariables: CVariables
    CEU3AI_ptr: int
    CAIStrategy: int  # embedded into the class
    tag: str
    tag_id: int
    units_ll_ptr: int
    owned_provinces_ll_ptr: int
    controlled_provinces_ll_ptr: int

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
            "available_CMinisters_ll_first_ptr": pm.read_uint(ptr + CCountryOffsets.available_CMinisters_ll_first_ptr),
            "available_CMinisters_ll_last_ptr": pm.read_uint(ptr + CCountryOffsets.available_CMinisters_ll_last_ptr),
            "CMinisters_ll_first_ptr": pm.read_uint(ptr + CCountryOffsets.CMinisters_ll_first_ptr),
            "CMinisters_ll_last_ptr": pm.read_uint(ptr + CCountryOffsets.CMinisters_ll_first_ptr),
            "CFlags": CFlags.make(pm, ptr + CCountryOffsets.CFlags_VFTABLE_PTR_1),
            "CFlags_amount": pm.read_uint(ptr + CCountryOffsets.CFlags_amount),
            "CVariables": CVariables.make(pm, ptr + CCountryOffsets.CVariables_VFTABLE_PTR_1),
            "CEU3AI_ptr": pm.read_uint(ptr + CCountryOffsets.CEU3AI_ptr),
            "CAIStrategy": ptr + CCountryOffsets.CAIStrategy,
            "tag": pm.read_bytes(ptr + CCountryOffsets.tag, 3),
            "tag_id": utils.to_number(pm.read_bytes(ptr + CCountryOffsets.tag_id, 4)),
            "units_ll_ptr": pm.read_uint(ptr + CCountryOffsets.units_ll_ptr),
            "owned_provinces_ll_ptr": pm.read_uint(ptr + CCountryOffsets.owned_provinces_ll_ptr),
            "controlled_provinces_ll_ptr": pm.read_uint(ptr + CCountryOffsets.controlled_provinces_ll_ptr),
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
            ptr = self.available_CMinisters_ll_first_ptr
        else:
            ptr = self.CMinisters_ll_first_ptr

        if ptr == 0:
            return res
        list_node = LinkedListNode.make(pm, ptr)
        while True:
            res.append(list_node.this)
            if list_node.next == 0:
                return res
            list_node = LinkedListNode.make(pm, list_node.next)

    def get_country_flags(self, pm: Pymem) -> list[CFlag]:
        return self.CFlags.get_flags(pm)

    def get_country_variables(self, pm: Pymem) -> list[CVariable]:
        return self.CVariables.get_variables(pm)

    def get_units(self, pm: Pymem) -> list[CArmy]:
        res = []
        list_node = LinkedListNode.make(pm, self.units_ll_ptr)
        while True:
            unit = CArmy.make(pm, list_node.this)
            res.append(unit)
            if list_node.next == 0:
                break
            list_node = LinkedListNode.make(pm, list_node.next)
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
            print(f"{flags}")
            print(f"{len(vars)=}")
            print(f"{vars}")
            # units = country.get_units(pm)
            # print(f"{len(units)=}")
