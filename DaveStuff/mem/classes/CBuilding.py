import pydantic
from pymem import Pymem
from typing import ClassVar

from classes.CModifierDefinition import CModifierDefinition
from constants import DATA_SECTION_START
from utils import to_number, get_string_maybe_ptr, read_string


class CBuilding(pydantic.BaseModel):
    VFTABLE_OFFSET: ClassVar[int] = 0x11C09F8
    PATTERN: ClassVar[bytes] = rb"\xF8\x09.\x01\x8D\x01\x00\x00"
    BUILDINGS_PTRS: ClassVar[list[int]] = None
    BUILDINGS: ClassVar[list] = None
    LENGTH: ClassVar[int] = 232
    self_ptr: int
    effect_value: int  # 0x8
    CProvinceModifier_ptr: int  # 0xC
    index: int  # 0x54
    name_raw: str  # 0x1c
    name_raw_length: int  # 0x30
    name_pretty: str  # 0x38
    name_pretty_length: int  # 0x48
    cost: int  # 0x58
    time: int  # 0x5c
    max_level: int  # 0x68
    completion_size: int  # 0x8c
    damage_factor: int  # 0x90
    on_map: bool  # 0x94
    visibility: bool  # 0x95
    repair: bool  # 0x96
    capital: bool  # 0x60
    port: bool  # 0x61

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "index": to_number(pm.read_bytes(ptr + 0x54, 4)),
            "effect_value": to_number(pm.read_bytes(ptr + 0x8, 4)),
            "CProvinceModifier_ptr": to_number(pm.read_bytes(ptr + 0xC, 4)),
            "name_raw_length": to_number(pm.read_bytes(ptr + 0x30, 4)),
            "name_pretty_length": to_number(pm.read_bytes(ptr + 0x48, 4)),
            "cost": to_number(pm.read_bytes(ptr + 0x58, 4)),
            "time": to_number(pm.read_bytes(ptr + 0x5C, 4)),
            "max_level": to_number(pm.read_bytes(ptr + 0x68, 4)),
            "completion_size": to_number(pm.read_bytes(ptr + 0x8C, 4)),
            "damage_factor": to_number(pm.read_bytes(ptr + 0x90, 4)),
            "on_map": pm.read_bool(ptr + 0x94),
            "visibility": pm.read_bool(ptr + 0x95),
            "repair": pm.read_bool(ptr + 0x96),
            "capital": pm.read_bool(ptr + 0x60),
            "port": pm.read_bool(ptr + 0x61),
        }
        if temp["name_raw_length"] <= 16:
            temp["name_raw"] = read_string(pm, ptr + 0x1C)
        else:
            temp["name_raw"] = read_string(pm, pm.read_uint(ptr + 0x1C))
        if temp["name_pretty_length"] <= 16:
            temp["name_pretty"] = read_string(pm, ptr + 0x38)
        else:
            temp["name_pretty"] = read_string(pm, pm.read_uint(ptr + 0x38))

        return cls(**temp)

    @classmethod
    def get_buildings(cls, pm: Pymem):
        if cls.BUILDINGS_PTRS:
            return cls.BUILDINGS_PTRS
        res = pm.pattern_scan_all(
            pattern=(pm.base_address + cls.VFTABLE_OFFSET).to_bytes(length=4, byteorder="little", signed=False),
            return_multiple=True,
        )
        cls.BUILDINGS_PTRS = [ptr for ptr in res if ptr >= DATA_SECTION_START]

        res2 = []
        for ptr in cls.BUILDINGS_PTRS:
            x = cls.make(pm, ptr)
            res2.append(x)
        cls.BUILDINGS = sorted(res2, key=lambda bld: bld.index)
        return cls.BUILDINGS_PTRS, cls.BUILDINGS

    def get_province_modifier(self, pm: Pymem):
        modifier = CModifierDefinition.make(pm, to_number(pm.read_bytes(self.CProvinceModifier_ptr, 4)))
        return modifier
