import json
import time

from pymem import Pymem

from classes.CInGameIdler import CInGameIdler
from classes.CLeader import CLeader
from classes.CProvince import CProvince
from classes.CBuilding import CBuilding
from classes.CProvinceModifier import CProvinceModifier
from classes.CUnit import CUnit
from utils import get_array_element_lengths, dump_bytes, get_string_maybe_ptr


# debug_setBreakpoint('00E9F4A7', function()
#   print(EBX)
#   if EBX == 0x391e44c0 and EDI == 0xB then
#     return 1
#   end
#   return 0
# end)


def search_pattern(pm: Pymem, pattern):
    res = pm.pattern_scan_all(pattern=pattern, return_multiple=True)
    print(f"{len(res)=}")
    return res


PROVINCE_ID = 2319


def main():
    pm = Pymem("hoi3_tfh.exe")
    # x = pm.pattern_scan_all(pattern=rb"\x20\x52.\x01\x8D\x01\x00\x00\x25\x00\x00\x00", return_multiple=True)
    # y = pm.pattern_scan_all(pattern=rb"\x20\x52\x23\x01\x8D\x01\x00\x00\x25\x00\x00\x00", return_multiple=True)
    # print(len(x))
    # print(len(y))
    # get_array_element_lengths(y)
    # provinces = CProvince.get_provinces(pm)
    # print(f"{len(provinces)=}")
    # province = CProvince.get_province(pm, PROVINCE_ID)
    # print(json.dumps(province.dict(), indent=2))
    # province_building = province.get_province_building(pm, 11)
    # print(json.dumps(province_building.dict(), indent=2))
    # buildings = CBuilding.get_buildings(pm)
    # print(f"{len(buildings)=}")
    # bld = buildings[57]
    # print(json.dumps(bld.dict(), indent=2))
    # cp_modifier = CProvinceModifier.make(pm, bld.CProvinceModifier_ptr)
    # print(f"{cp_modifier.name_raw=}")
    # # dump_bytes(pm, cp_modifier.self_ptr, cp_modifier.LENGTH)
    # in_game_idler = CInGameIdler.make(pm)
    # print(json.dumps(in_game_idler.dict(), indent=2))
    # for i in range(5):
    #     print(json.dumps(in_game_idler.dict(), indent=2))
    #     time.sleep(3)
    #     in_game_idler.update_selected_province_ptr(pm)
    #     if in_game_idler.selected_province_ptr_ptr != 0:
    #         print(CProvince.get_id_from_ptr(pm, in_game_idler.selected_province_ptr_ptr))

    unit = CUnit.make(pm=pm, ptr=0xC6F75E68)
    print(json.dumps(unit.dict(), indent=2))
    dump_bytes(pm, unit.self_ptr, unit.LENGTH)
    leader = CLeader.make(pm=pm, ptr=unit.leader_ptr)
    print(json.dumps(leader.dict(), indent=2))
    dump_bytes(pm, leader.self_ptr, leader.LENGTH)


if __name__ == "__main__":
    main()
