import pydantic
from pymem import Pymem

from utils import utils


class CUnitOffsets:
    is_selected: int = 0x4
    type: int = 0x10
    id: int = 0x14
    regiments_linked_list_first_ptr: int = 0x38
    regiments_linked_list_last_ptr: int = 0x3C
    regiments_amount: int = 0x40
    upgrade_prio: int = 0xA4
    upgrade_active: int = 0xA5
    reinforcements_active: int = 0xA6
    order_ptr: int = 0xB0
    CSubUnitDefinition_Ptr: int = 0xC8  # This is the CSubUnitDefinition definition for the whole Unit
    combat_cooldown: int = 0xD4
    supply_received_percentage: int = 0xFC
    fuel_received_percentage: int = 0x100
    owner_tag: int = 0x124
    owner_id: int = 0x128
    leader_ptr: int = 0x12C
    current_province_ptr: int = 0x130
    # supplied_from_province_ptr: int = 0x134
    movement_order_next_province_ptr: int = 0x138
    movement_order_last_current_province_ptr: int = 0x13C
    movement_order_remaining_provinces_count: int = 0x140
    in_game_idler_ptr: int = 0x160
    hoi_avatar_ptr: int = 0x164
    name: int = 0x16C
    name_length: int = 0x17C
    dig_in_level: int = 0x1C8
    base_ca_bonus: int = 0x1CC
    higher_oob_unit_ptr: int = 0x1E0
    lower_oob_unit_linked_list_first_ptr: int = 0x1E4
    lower_oob_unit_linked_list_last_ptr: int = 0x1E8
    lower_oob_unit_amount: int = 0x1EC
    oob_level: int = 0x1F4  # 0 -> Theatre, 4 -> Division (includes single brigades); 5 -> Navy


class CUnit(pydantic.BaseModel):
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
    CSubUnitDefinition_Ptr: int
    combat_cooldown: int  # 76000 = 76 hours
    supply_received_percentage: int  # 1000 = 100%
    fuel_received_percentage: int  # 1000 = 100%
    owner_tag: str
    owner_id: int
    leader_ptr: int
    current_province_ptr: int
    # supplied_from_province_ptr: int
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
            "is_selected": pm.read_bool(ptr + CUnitOffsets.is_selected),
            "type": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.type, 4)),
            "id": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.id, 4)),
            "regiments_linked_list_first_ptr": pm.read_uint(ptr + CUnitOffsets.regiments_linked_list_first_ptr),
            "regiments_linked_list_last_ptr": pm.read_uint(ptr + CUnitOffsets.regiments_linked_list_last_ptr),
            "regiments_amount": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.regiments_amount, 4)),
            "upgrade_prio": pm.read_bool(ptr + CUnitOffsets.upgrade_prio),
            "upgrade_active": pm.read_bool(ptr + CUnitOffsets.upgrade_active),
            "reinforcements_active": pm.read_bool(ptr + CUnitOffsets.reinforcements_active),
            "order_ptr": pm.read_uint(ptr + CUnitOffsets.order_ptr),
            "CSubUnitDefinition_Ptr": pm.read_uint(ptr + CUnitOffsets.CSubUnitDefinition_Ptr),
            "combat_cooldown": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.combat_cooldown, 4)),
            "supply_received_percentage": utils.to_number(
                pm.read_bytes(ptr + CUnitOffsets.supply_received_percentage, 4)
            ),
            "fuel_received_percentage": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.fuel_received_percentage, 4)),
            "owner_tag": pm.read_bytes(ptr + CUnitOffsets.owner_tag, 3),
            "owner_id": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.owner_id, 4)),
            "leader_ptr": pm.read_uint(ptr + CUnitOffsets.leader_ptr),
            "current_province_ptr": pm.read_uint(ptr + CUnitOffsets.current_province_ptr),
            # "supplied_from_province_ptr": pm.read_uint(ptr + CUnitOffsets.supplied_from_province_ptr),
            "in_game_idler_ptr": pm.read_uint(ptr + CUnitOffsets.in_game_idler_ptr),
            "hoi_avatar_ptr": pm.read_uint(ptr + CUnitOffsets.hoi_avatar_ptr),
            "name": utils.get_string_maybe_ptr(pm, ptr + CUnitOffsets.name),
            "name_length": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.name_length, 4)),
            "dig_in_level": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.dig_in_level, 4)),
            "base_ca_bonus": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.base_ca_bonus, 4)),
            "higher_oob_unit_ptr": pm.read_uint(ptr + CUnitOffsets.higher_oob_unit_ptr),
            "lower_oob_unit_linked_list_first_ptr": pm.read_uint(
                ptr + CUnitOffsets.lower_oob_unit_linked_list_first_ptr
            ),
            "lower_oob_unit_linked_list_last_ptr": pm.read_uint(ptr + CUnitOffsets.lower_oob_unit_linked_list_last_ptr),
            "lower_oob_unit_amount": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.lower_oob_unit_amount, 4)),
            "oob_level": utils.to_number(pm.read_bytes(ptr + CUnitOffsets.oob_level, 4)),
        }
        return cls(**temp)


def test1():
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    unit_1_ptr = 2703943752
    unit_1 = CUnit.make(pm, unit_1_ptr)
    print(unit_1)
    print(unit_1.CSubUnitDefinition_Ptr)
    utils.dump_bytes(pm=pm, ptr=unit_1_ptr, length=0x308)
    # unit_2_ptr = 0x9021B658
    # unit_2 = CUnit.make(pm, unit_2_ptr)
    # print(unit_2)
    # print(unit_2.army_sub_unit_definition_ptr)
    # utils.dump_bytes(pm=pm, ptr=unit_2_ptr, length=0x200)


if __name__ == "__main__":
    test1()
