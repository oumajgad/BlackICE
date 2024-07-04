import json
import time

from pymem import Pymem

from classes.CInGameIdler import CInGameIdler
from classes.CLeader import CLeader
from classes.CMapProvince import CMapProvince
from classes.CBuilding import CBuilding
from classes.CModifierDefinition import CModifierDefinition
from classes.CRegiment import CRegiment
from classes.CArmy import CArmy
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
    # for ptr in provinces:
    #     # print(ptr)
    #     province = CMapProvince.make(pm, ptr)
    #

    # province = CMapProvince.get_province(pm, PROVINCE_ID)
    # print(json.dumps(province.dict(), indent=2))
    # province_building = province.get_province_building(pm, 21)
    # print(json.dumps(province_building.dict(), indent=2))
    # buildings_ptrs, buildings = CBuilding.get_buildings(pm)
    # print(f"{len(buildings)=}")
    # bld = buildings[10]
    # print(json.dumps(bld.dict(), indent=2))
    # cp_modifier = CModifierDefinition.make(pm, bld.CProvinceModifier_ptr)
    # print(json.dumps(cp_modifier.dict(), indent=2))
    # modifiers = CModifierDefinition.get_modifier_definitions(pm)
    # for mod in modifiers:
    #     cp_modifier = CModifierDefinition.make(pm, mod)
    #     print(json.dumps(cp_modifier.dict(), indent=2))
    # dump_bytes(pm, cp_modifier.self_ptr, cp_modifier.LENGTH)
    # in_game_idler = CInGameIdler.make(pm)
    # print(json.dumps(in_game_idler.dict(), indent=2))
    # for i in range(5):
    #     print(json.dumps(in_game_idler.dict(), indent=2))
    #     time.sleep(3)
    #     in_game_idler.update_selected_province_ptr(pm)
    #     if in_game_idler.selected_province_ptr_ptr != 0:
    #         print(CProvince.get_id_from_ptr(pm, in_game_idler.selected_province_ptr_ptr))
    units = CArmy.get_units(pm)
    print(f"{len(units)=}")
    for unit_ptr in CArmy.get_units(pm):
        # print(unit_ptr)
        name = CArmy.get_name_from_ptr(pm, unit_ptr)
        # BD2ABCF8 1. inf
        # BD2B2848 1. kav
        if name == "I. A.K." or name == "1. Infanterie-Division" or name == "§Y1. Kavallerie-Brigade§W":
            army = CArmy.make(pm, unit_ptr)
            if army.owner_tag == "GER":
                print(f"{name} - {army.self_ptr}")
                print(f"{army.leader_ptr=}")
                # print(json.dumps(army.dict(), indent=2))

    leaders = CLeader.get_leaders(pm)
    print(f"{len(leaders)=}")

    # sub_unit = CSubUnit.make(pm, 0x92C823E8)
    # print(json.dumps(sub_unit.dict(), indent=2))


if __name__ == "__main__":
    main()
