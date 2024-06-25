import pydantic
from pymem import Pymem
from typing import ClassVar

from classes.CProvinceModifier import CProvinceModifier
from utils import to_number, get_string_maybe_ptr


class CBuilding(pydantic.BaseModel):
    PATTERN: ClassVar[bytes] = rb"\xF8\x09.\x01\x8D\x01\x00\x00"
    BUILDINGS: ClassVar[list] = None
    LENGTH: ClassVar[int] = 232
    self_ptr: int
    effect_value: int  # 0x8
    CProvinceModifier_ptr: int  # 0xC
    index: int  # 0x54
    name_raw: str  # 0x1c
    name_pretty: str  # 0x38
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
            "name_raw": get_string_maybe_ptr(pm, ptr + 0x1C),
            "name_pretty": get_string_maybe_ptr(pm, ptr + 0x38),
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

        return cls(**temp)

    @classmethod
    def get_buildings(cls, pm: Pymem):
        if cls.BUILDINGS:
            return cls.BUILDINGS
        building_ptrs = pm.pattern_scan_all(pattern=cls.PATTERN, return_multiple=True)
        res = []
        for ptr in building_ptrs:
            x = cls.make(pm, ptr)
            res.append(x)
        res = sorted(res, key=lambda bld: bld.index)
        cls.BUILDINGS = res
        return res

    def get_province_modifier(self, pm: Pymem):
        modifier = CProvinceModifier.make(pm, to_number(pm.read_bytes(self.CProvinceModifier_ptr, 4)))
        return modifier
