import json
import time

from pymem import Pymem

from classes.CInGameIdler import CInGameIdler
from classes.CLeader import CLeader
from classes.CMapProvince import CMapProvince
from classes.CBuilding import CBuilding
from classes.CProvinceModifier import CProvinceModifier
from classes.CSubUnit import CSubUnit
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


PROVINCE_ID = 1528


def main():
    pm = Pymem("hoi3_tfh.exe")
    # x = pm.pattern_scan_all(
    #     pattern=rb"\x0C\xDE\x22\x01\x00\x00\x00\x00\xB8\xDE\x22\x01\x8D\x01\x00\x00", return_multiple=True
    # )
    # y = pm.pattern_scan_all(
    #     pattern=rb"\x0C\xDE.\x01.\x00\x00\x00\xB8\xDE\x22\x01\x8D\x01\x00\x00", return_multiple=True
    # )
    # print(len(x))
    # print(len(y))
    # get_array_element_lengths(y)
    provinces = CMapProvince.get_provinces(pm)
    print(f"{len(provinces)=}")
    for ptr in provinces:
        # print(ptr)
        province = CMapProvince.make(pm, ptr)

    # province = CMapProvince.get_province(pm, PROVINCE_ID)
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

    # for unit_ptr in CUnit.get_units(pm):
    #     name = CUnit.get_name_from_ptr(pm, unit_ptr)
    #     # BD2ABCF8 1. inf
    #     # BD2B2848 1. kav
    #     if name == "I. A.K." or name == "1. Infanterie-Division" or name == "§Y1. Kavallerie-Brigade§W":
    #         unit = CUnit.make(pm, unit_ptr)
    #         if unit.owner_tag == "GER":
    #             print(f"{name} - {unit.self_ptr}")
    #             # print(json.dumps(unit.dict(), indent=2))

    # sub_unit = CSubUnit.make(pm, 0x92C823E8)
    # print(json.dumps(sub_unit.dict(), indent=2))

    # x = CUnit.make(pm, 0xBD2AC020)
    # print(x.name)
    # x = CUnit.make(pm, 0xBD2ABCF8)
    # print(x.name)
    # x = CUnit.make(pm, 0xBD2A9A40)
    # print(x.name)
    # x = CUnit.make(pm, 0x92C825A8)
    # print(x.name)


if __name__ == "__main__":
    main()
