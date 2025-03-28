from typing import ClassVar

import pydantic
from pymem import Pymem

from classes.CModifierDefinition import CModifierDefinition
from constants import DATA_SECTION_START
from utils import utils


class CBuildingOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11C09F8
    effect_value: int = 0x8
    CModifierDefinition_ptr: int = 0xC
    name_raw: int = 0x1C
    name_raw_length: int = 0x30
    name_pretty: int = 0x38
    name_pretty_length: int = 0x48
    time: int = 0x5C
    index: int = 0x54
    cost: int = 0x58
    capital: int = 0x60
    port: int = 0x61
    max_level: int = 0x68
    completion_size: int = 0x8C
    damage_factor: int = 0x90
    on_map: int = 0x94
    visibility: int = 0x95
    repair: int = 0x96


class CBuilding(pydantic.BaseModel):
    VFTABLE_OFFSET: ClassVar[int] = 0x11C09F8
    BUILDINGS_PTRS: ClassVar[list[int]] = None
    BUILDINGS: ClassVar[list] = None
    LENGTH: ClassVar[int] = 232
    self_ptr: int
    effect_value: int
    CModifierDefinition_ptr: int
    index: int
    name_raw: str
    name_raw_length: int
    name_pretty: str
    name_pretty_length: int
    cost: int
    time: int
    max_level: int
    completion_size: int
    damage_factor: int
    on_map: bool
    visibility: bool
    repair: bool
    capital: bool
    port: bool

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "index": utils.to_number(pm.read_bytes(ptr + CBuildingOffsets.index, 4)),
            "effect_value": utils.to_number(pm.read_bytes(ptr + CBuildingOffsets.effect_value, 4)),
            "CModifierDefinition_ptr": utils.to_number(
                pm.read_bytes(ptr + CBuildingOffsets.CModifierDefinition_ptr, 4)
            ),
            "name_raw": utils.get_string_maybe_ptr(pm, ptr + CBuildingOffsets.name_raw),
            "name_raw_length": utils.to_number(pm.read_bytes(ptr + CBuildingOffsets.name_raw_length, 4)),
            "name_pretty": utils.get_string_maybe_ptr(pm, ptr + CBuildingOffsets.name_pretty),
            "name_pretty_length": utils.to_number(pm.read_bytes(ptr + CBuildingOffsets.name_pretty_length, 4)),
            "cost": utils.to_number(pm.read_bytes(ptr + CBuildingOffsets.cost, 4)),
            "time": utils.to_number(pm.read_bytes(ptr + CBuildingOffsets.time, 4)),
            "max_level": utils.to_number(pm.read_bytes(ptr + CBuildingOffsets.max_level, 4)),
            "completion_size": utils.to_number(pm.read_bytes(ptr + CBuildingOffsets.completion_size, 4)),
            "damage_factor": utils.to_number(pm.read_bytes(ptr + CBuildingOffsets.damage_factor, 4)),
            "on_map": pm.read_bool(ptr + CBuildingOffsets.on_map),
            "visibility": pm.read_bool(ptr + CBuildingOffsets.visibility),
            "repair": pm.read_bool(ptr + CBuildingOffsets.repair),
            "capital": pm.read_bool(ptr + CBuildingOffsets.capital),
            "port": pm.read_bool(ptr + CBuildingOffsets.port),
        }

        return cls(**temp)

    @classmethod
    def get_buildings(cls, pm: Pymem):
        if cls.BUILDINGS_PTRS:
            return cls.BUILDINGS_PTRS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CBuildingOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.BUILDINGS_PTRS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]

        res2 = []
        for ptr in cls.BUILDINGS_PTRS:
            x = cls.make(pm, ptr)
            res2.append(x)
        cls.BUILDINGS = sorted(res2, key=lambda bld: bld.index)
        return cls.BUILDINGS_PTRS, cls.BUILDINGS

    def get_province_modifier(self, pm: Pymem):
        modifier = CModifierDefinition.make(pm, utils.to_number(pm.read_bytes(self.CModifierDefinition_ptr, 4)))
        return modifier


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    buildings_ptrs, buildings = CBuilding.get_buildings(pm)
    print(f"{len(buildings)=}")
    bld = buildings[10]
    print(bld)
