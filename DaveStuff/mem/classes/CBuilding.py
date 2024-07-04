import pydantic
from pymem import Pymem
from typing import ClassVar

from classes.CModifierDefinition import CModifierDefinition
from constants import DATA_SECTION_START
from utils import to_number, read_string, rawbytes


class CBuildingOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11C09F8
    effect_value: int = 0x8
    CModifierDefinition_ptr: int = 0xC
    index: int = 0x54
    name_raw: int = 0x1C
    name_raw_length: int = 0x30
    name_pretty: int = 0x38
    name_pretty_length: int = 0x48
    cost: int = 0x58
    time: int = 0x5C
    max_level: int = 0x68
    completion_size: int = 0x8C
    damage_factor: int = 0x90
    on_map: int = 0x94
    visibility: int = 0x95
    repair: int = 0x96
    capital: int = 0x60
    port: int = 0x61


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
            "index": to_number(pm.read_bytes(ptr + CBuildingOffsets.index, 4)),
            "effect_value": to_number(pm.read_bytes(ptr + CBuildingOffsets.effect_value, 4)),
            "CModifierDefinition_ptr": to_number(pm.read_bytes(ptr + CBuildingOffsets.CModifierDefinition_ptr, 4)),
            "name_raw_length": to_number(pm.read_bytes(ptr + CBuildingOffsets.name_raw_length, 4)),
            "name_pretty_length": to_number(pm.read_bytes(ptr + CBuildingOffsets.name_pretty_length, 4)),
            "cost": to_number(pm.read_bytes(ptr + CBuildingOffsets.cost, 4)),
            "time": to_number(pm.read_bytes(ptr + CBuildingOffsets.time, 4)),
            "max_level": to_number(pm.read_bytes(ptr + CBuildingOffsets.max_level, 4)),
            "completion_size": to_number(pm.read_bytes(ptr + CBuildingOffsets.completion_size, 4)),
            "damage_factor": to_number(pm.read_bytes(ptr + CBuildingOffsets.damage_factor, 4)),
            "on_map": pm.read_bool(ptr + CBuildingOffsets.on_map),
            "visibility": pm.read_bool(ptr + CBuildingOffsets.visibility),
            "repair": pm.read_bool(ptr + CBuildingOffsets.repair),
            "capital": pm.read_bool(ptr + CBuildingOffsets.capital),
            "port": pm.read_bool(ptr + CBuildingOffsets.port),
        }
        if temp["name_raw_length"] <= 16:
            temp["name_raw"] = read_string(pm, ptr + CBuildingOffsets.name_raw)
        else:
            temp["name_raw"] = read_string(pm, pm.read_uint(ptr + CBuildingOffsets.name_raw))
        if temp["name_pretty_length"] <= 16:
            temp["name_pretty"] = read_string(pm, ptr + CBuildingOffsets.name_pretty)
        else:
            temp["name_pretty"] = read_string(pm, pm.read_uint(ptr + CBuildingOffsets.name_pretty))

        return cls(**temp)

    @classmethod
    def get_buildings(cls, pm: Pymem):
        if cls.BUILDINGS_PTRS:
            return cls.BUILDINGS_PTRS
        res = pm.pattern_scan_all(
            pattern=rawbytes(
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
        modifier = CModifierDefinition.make(pm, to_number(pm.read_bytes(self.CModifierDefinition_ptr, 4)))
        return modifier


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    buildings_ptrs, buildings = CBuilding.get_buildings(pm)
    print(f"{len(buildings)=}")
    bld = buildings[10]
    print(bld)
