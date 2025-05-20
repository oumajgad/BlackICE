from typing import ClassVar

import pydantic
from pymem import Pymem

from classes.CUnit import CUnitOffsets
from constants import DATA_SECTION_START
from structs.LinkedLists import LinkedListNode
from utils import utils


class CArmyOffsets(CUnitOffsets):
    VFTABLE_OFFSET: int = 0x11BDE0C
    VFTABLE_OFFSET_2: int = 0x11BDEB8
    VFTABLE_PTR_1: int = 0x0
    VFTABLE_PTR_2: int = 0x8
    VFTABLE_CUnitPlan_PTR: int = 0x1FC


class CArmy(pydantic.BaseModel):
    LENGTH: ClassVar[int] = 808
    UNITS: ClassVar[list[int]] = None
    self_ptr: int
    ptr_str: str
    is_selected: bool
    type: int
    id: int
    regiments_linked_list_first_ptr: int
    regiments_linked_list_last_ptr: int
    regiments_amount: int
    upgrade_prio: bool
    upgrade_active: bool
    reinforcements_active: bool
    order_ptr: int
    army_sub_unit_definition_ptr: int
    combat_cooldown: int  # 76000 = 76 hours
    supply_received_percentage: int  # 1000 = 100%
    fuel_received_percentage: int  # 1000 = 100%
    owner_tag: str
    owner_id: int
    leader_ptr: int
    current_province_ptr: int
    supplied_from_province_ptr: int
    movement_order_remaining_provinces_count: int  # Amount of provinces left in the current movement order
    in_game_idler_ptr: int
    hoi_avatar_ptr: int
    name: str
    name_length: int
    dig_in_level: int  # 1000 = 1
    base_ca_bonus: int  # 450 = 45% // does not include leader, techs, maybe other stuff
    higher_oob_unit_ptr: int
    lower_oob_unit_linked_list_first_ptr: int
    lower_oob_unit_linked_list_last_ptr: int
    lower_oob_unit_amount: int
    oob_level: int  # 0 -> Theatre, 4 -> Division (includes single brigades)

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
            "is_selected": pm.read_bool(ptr + CArmyOffsets.is_selected),
            "type": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.type, 4)),
            "id": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.id, 4)),
            "regiments_linked_list_first_ptr": pm.read_uint(ptr + CArmyOffsets.regiments_linked_list_first_ptr),
            "regiments_linked_list_last_ptr": pm.read_uint(ptr + CArmyOffsets.regiments_linked_list_last_ptr),
            "regiments_amount": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.regiments_amount, 4)),
            "upgrade_prio": pm.read_bool(ptr + CArmyOffsets.upgrade_prio),
            "upgrade_active": pm.read_bool(ptr + CArmyOffsets.upgrade_active),
            "reinforcements_active": pm.read_bool(ptr + CArmyOffsets.reinforcements_active),
            "order_ptr": pm.read_uint(ptr + CArmyOffsets.order_ptr),
            "army_sub_unit_definition_ptr": pm.read_uint(ptr + CArmyOffsets.CSubUnitDefinitionPtr),
            "combat_cooldown": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.combat_cooldown, 4)),
            "supply_received_percentage": utils.to_number(
                pm.read_bytes(ptr + CArmyOffsets.supply_received_percentage, 4)
            ),
            "fuel_received_percentage": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.fuel_received_percentage, 4)),
            "owner_tag": pm.read_bytes(ptr + CArmyOffsets.owner_tag, 3),
            "owner_id": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.owner_id, 4)),
            "leader_ptr": pm.read_uint(ptr + CArmyOffsets.leader_ptr),
            "current_province_ptr": pm.read_uint(ptr + CArmyOffsets.current_province_ptr),
            "supplied_from_province_ptr": pm.read_uint(ptr + CArmyOffsets.supplied_from_province_ptr),
            "movement_order_remaining_provinces_count": utils.to_number(
                pm.read_bytes(ptr + CArmyOffsets.movement_order_remaining_provinces_count, 4)
            ),
            "in_game_idler_ptr": pm.read_uint(ptr + CArmyOffsets.in_game_idler_ptr),
            "hoi_avatar_ptr": pm.read_uint(ptr + CArmyOffsets.hoi_avatar_ptr),
            "name": utils.get_string_maybe_ptr(pm, ptr + CArmyOffsets.name),
            "name_length": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.name_length, 4)),
            "dig_in_level": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.dig_in_level, 4)),
            "base_ca_bonus": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.base_ca_bonus, 4)),
            "higher_oob_unit_ptr": pm.read_uint(ptr + CArmyOffsets.higher_oob_unit_ptr),
            "lower_oob_unit_linked_list_first_ptr": pm.read_uint(
                ptr + CArmyOffsets.lower_oob_unit_linked_list_first_ptr
            ),
            "lower_oob_unit_linked_list_last_ptr": pm.read_uint(ptr + CArmyOffsets.lower_oob_unit_linked_list_last_ptr),
            "lower_oob_unit_amount": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.lower_oob_unit_amount, 4)),
            "oob_level": utils.to_number(pm.read_bytes(ptr + CArmyOffsets.oob_level, 4)),
        }
        return cls(**temp)

    @classmethod
    def get_units(cls, pm: Pymem) -> list[int]:
        if cls.UNITS:
            return cls.UNITS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CArmyOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.UNITS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.UNITS

    @classmethod
    def get_name_from_ptr(cls, pm: Pymem, ptr: int):
        return utils.get_string_maybe_ptr(pm, ptr + CArmyOffsets.name)

    def build_oob(self, pm: Pymem):
        def get_oob_units_recursive(pm: Pymem, unit: CArmy):
            res = {unit.name: unit.dict()}
            if unit.lower_oob_unit_linked_list_ptr != 0:
                res["units"] = []
                list_node = LinkedListNode.make(pm, unit.lower_oob_unit_linked_list_ptr)
                while True:
                    lower_unit = CArmy.make(pm, list_node.this)
                    res["units"].append(get_oob_units_recursive(pm, lower_unit))
                    if list_node.previous == 0:
                        res["units"].reverse()
                        break
                    list_node = LinkedListNode.make(pm, list_node.previous)
            return res

        return get_oob_units_recursive(pm, self)


def test1():
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    units = CArmy.get_units(pm)
    print(f"{len(units)=}")
    x = 0
    for unit_ptr in units:
        # print(unit_ptr)
        try:
            army = CArmy.make(pm, unit_ptr)
            if army.oob_level == 0:
                x += 1
        except Exception:
            pass
    # print(CArmy.make(pm, 0xB32FE6C0))
    print(x)


def test2():
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    unit_1_ptr = 0xC16535D0
    army_1 = CArmy.make(pm, unit_1_ptr)
    print(army_1)
    print(army_1.army_sub_unit_definition_ptr)
    utils.dump_bytes(pm=pm, ptr=unit_1_ptr, length=0x200)
    unit_2_ptr = 0x9021B658
    army_2 = CArmy.make(pm, unit_2_ptr)
    print(army_2)
    print(army_2.army_sub_unit_definition_ptr)
    utils.dump_bytes(pm=pm, ptr=unit_2_ptr, length=0x200)


if __name__ == "__main__":
    # test1()
    test2()
