from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import to_number, get_string_maybe_ptr, read_string, rawbytes


class CArmyOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11BDEB8
    is_selected: int = 0x4
    type: int = 0x10
    id: int = 0x14
    sub_unit_amount: int = 0x40
    upgrade_prio: int = 0xA4
    upgrade_active: int = 0xA5
    reinforcements_active: int = 0xA6
    combat_cooldown: int = 0xD4
    supply_received_percentage: int = 0xFC
    fuel_received_percentage: int = 0x100
    owner_tag: int = 0x124
    owner_id: int = 0x128
    leader_ptr: int = 0x12C
    current_province_ptr: int = 0x130
    supplied_from_province_ptr: int = 0x134
    path_length: int = 0x140
    name: int = 0x16C
    name_length: int = 0x17C
    dig_in_level: int = 0x1C8
    base_ca_bonus: int = 0x1CC
    higher_oob_unit_ptr: int = 0x1E0
    lower_oob_unit_ptr: int = 0x1E8
    lower_oob_unit_amount: int = 0x1EC


class CArmy(pydantic.BaseModel):
    LENGTH: ClassVar[int] = 808
    UNITS: ClassVar[list[int]] = None
    self_ptr: int
    is_selected: bool
    type: int
    id: int
    sub_unit_amount: int
    upgrade_prio: bool
    upgrade_active: bool
    reinforcements_active: bool
    combat_cooldown: int  # 76000 = 76 hours
    supply_received_percentage: int  # 1000 = 100%
    fuel_received_percentage: int  # 1000 = 100%
    owner_tag: str
    owner_id: int
    leader_ptr: int
    current_province_ptr: int
    supplied_from_province_ptr: int
    path_length: int  # Amount of provinces left in the current movement order
    name: str
    name_length: int
    dig_in_level: int  # 1000 = 1
    base_ca_bonus: int  # 450 = 45% // does not include leader, techs, maybe other stuff
    higher_oob_unit_ptr: int
    lower_oob_unit_ptr: int
    lower_oob_unit_amount: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "is_selected": pm.read_bool(ptr + CArmyOffsets.is_selected),
            "type": to_number(pm.read_bytes(ptr + CArmyOffsets.type, 4)),
            "id": to_number(pm.read_bytes(ptr + CArmyOffsets.id, 4)),
            "sub_unit_amount": to_number(pm.read_bytes(ptr + CArmyOffsets.sub_unit_amount, 4)),
            "upgrade_prio": pm.read_bool(ptr + CArmyOffsets.upgrade_prio),
            "upgrade_active": pm.read_bool(ptr + CArmyOffsets.upgrade_active),
            "reinforcements_active": pm.read_bool(ptr + CArmyOffsets.reinforcements_active),
            "combat_cooldown": to_number(pm.read_bytes(ptr + CArmyOffsets.combat_cooldown, 4)),
            "supply_received_percentage": to_number(pm.read_bytes(ptr + CArmyOffsets.supply_received_percentage, 4)),
            "fuel_received_percentage": to_number(pm.read_bytes(ptr + CArmyOffsets.fuel_received_percentage, 4)),
            "owner_tag": pm.read_bytes(ptr + CArmyOffsets.owner_tag, 3),
            "owner_id": to_number(pm.read_bytes(ptr + CArmyOffsets.owner_id, 4)),
            "leader_ptr": pm.read_uint(ptr + CArmyOffsets.leader_ptr),
            "current_province_ptr": pm.read_uint(ptr + CArmyOffsets.current_province_ptr),
            "supplied_from_province_ptr": pm.read_uint(ptr + CArmyOffsets.supplied_from_province_ptr),
            "path_length": to_number(pm.read_bytes(ptr + CArmyOffsets.path_length, 4)),
            "name_length": to_number(pm.read_bytes(ptr + CArmyOffsets.name_length, 4)),
            "dig_in_level": to_number(pm.read_bytes(ptr + CArmyOffsets.dig_in_level, 4)),
            "base_ca_bonus": to_number(pm.read_bytes(ptr + CArmyOffsets.base_ca_bonus, 4)),
            "higher_oob_unit_ptr": pm.read_uint(ptr + CArmyOffsets.higher_oob_unit_ptr),
            "lower_oob_unit_ptr": pm.read_uint(ptr + CArmyOffsets.lower_oob_unit_ptr),
            "lower_oob_unit_amount": to_number(pm.read_bytes(ptr + CArmyOffsets.lower_oob_unit_amount, 4)),
        }
        if temp["name_length"] <= 16:
            temp["name"] = read_string(pm, ptr + CArmyOffsets.name)
        else:
            temp["name"] = read_string(pm, pm.read_uint(ptr + CArmyOffsets.name))
        return cls(**temp)

    @classmethod
    def get_units(cls, pm: Pymem) -> list[int]:
        if cls.UNITS:
            return cls.UNITS
        res = pm.pattern_scan_all(
            pattern=rawbytes(
                (pm.base_address + CArmyOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.UNITS = [ptr - 8 for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.UNITS

    @classmethod
    def get_name_from_ptr(cls, pm: Pymem, ptr: int):
        if to_number(pm.read_bytes(ptr + CArmyOffsets.name_length, 4)) <= 16:
            return read_string(pm, ptr + CArmyOffsets.name)
        else:
            return get_string_maybe_ptr(pm, ptr + CArmyOffsets.name)
