from typing import ClassVar

import pydantic
from pymem import Pymem
from utils import to_number, get_string_maybe_ptr


class CUnit(pydantic.BaseModel):
    """
    No idea what this thing does, probably does alot of things.
    Virtual function number 16 gets used by the GUI every frame.
    """

    PATTERN: ClassVar[bytes] = rb"\x0C\xDE.\x01.\x00\x00\x00"
    LENGTH: ClassVar[int] = 808
    UNITS: ClassVar[list[int]] = None
    self_ptr: int
    is_selected: bool  # 0x4
    type: int  # 0x10
    id: int  # 0x14
    sub_unit_amount: int  # 0x40
    upgrade_prio: bool  # 0xA4
    upgrade_active: bool  # 0xA5
    reinforcements_active: bool  # 0xA6
    combat_cooldown: int  # 0xD4 // 76000 = 76 hours
    supply_received_percentage: int  # 0xFC // 1000 = 100%
    fuel_received_percentage: int  # 0x100 // 1000 = 100%
    owner_tag: str  # 0x124
    owner_id: int  # 0x128
    leader_ptr: int  # 0x12C
    current_province_ptr: int  # 0x130
    supplied_from_province_ptr: int  # 0x134
    path_length: int  # 0x140 // Amount of provinces left in the current movement order
    name: str  # 0x16C
    name_length: int  # 0x17C
    dig_in_level: int  # 0x1C8 // 1000 = 1
    higher_oob_unit_ptr: int  # 0x1E0

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "is_selected": pm.read_bool(ptr + 0x4),
            "type": to_number(pm.read_bytes(ptr + 0x10, 4)),
            "id": to_number(pm.read_bytes(ptr + 0x14, 4)),
            "sub_unit_amount": to_number(pm.read_bytes(ptr + 0x40, 4)),
            "upgrade_prio": pm.read_bool(ptr + 0xA4),
            "upgrade_active": pm.read_bool(ptr + 0xA5),
            "reinforcements_active": pm.read_bool(ptr + 0xA6),
            "combat_cooldown": to_number(pm.read_bytes(ptr + 0xD4, 4)),
            "supply_received_percentage": to_number(pm.read_bytes(ptr + 0xFC, 4)),
            "fuel_received_percentage": to_number(pm.read_bytes(ptr + 0x100, 4)),
            "owner_tag": pm.read_bytes(ptr + 0x124, 3),
            "owner_id": to_number(pm.read_bytes(ptr + 0x128, 4)),
            "leader_ptr": pm.read_uint(ptr + 0x12C),
            "current_province_ptr": pm.read_uint(ptr + 0x130),
            "supplied_from_province_ptr": pm.read_uint(ptr + 0x134),
            "path_length": to_number(pm.read_bytes(ptr + 0x140, 4)),
            "name": get_string_maybe_ptr(pm, ptr + 0x16C),
            "name_length": to_number(pm.read_bytes(ptr + 0x17C, 4)),
            "dig_in_level": to_number(pm.read_bytes(ptr + 0x1C8, 4)),
            "higher_oob_unit_ptr": pm.read_uint(ptr + 0x1E0),
        }

        return cls(**temp)

    @classmethod
    def get_units(cls, pm: Pymem) -> list[int]:
        if cls.UNITS:
            return cls.UNITS
        res = pm.pattern_scan_all(pattern=cls.PATTERN, return_multiple=True)
        cls.UNITS = res
        return res
