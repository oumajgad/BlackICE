import json
import time

from pymem import Pymem

from classes.CInGameIdler import CInGameIdler
from classes.CProvince import CProvince
from classes.CBuilding import CBuilding
from classes.CProvinceModifier import CProvinceModifier
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


PROVINCE_ID = 10515


def main():
    pm = Pymem("hoi3_tfh.exe")
    provinces = CProvince.get_provinces(pm)
    print(f"{len(provinces)=}")
    province = CProvince.get_province(pm, PROVINCE_ID)
    print(json.dumps(province.dict(), indent=2))
    province_building = province.get_province_building(pm, 11)
    print(json.dumps(province_building.dict(), indent=2))
    buildings = CBuilding.get_buildings(pm)
    print(f"{len(buildings)=}")
    bld = buildings[57]
    print(json.dumps(bld.dict(), indent=2))
    cp_modifier = CProvinceModifier.make(pm, bld.CProvinceModifier_ptr)
    print(f"{cp_modifier.name_raw}")
    dump_bytes(pm, cp_modifier.self_ptr, cp_modifier.LENGTH)
    in_game_idler = CInGameIdler.make(pm)
    for i in range(5):
        print(json.dumps(in_game_idler.dict(), indent=2))
        time.sleep(3)
        in_game_idler.update_selected_province_ptr(pm)
        if in_game_idler.selected_province_ptr_ptr != 0:
            print(CProvince.get_id_from_ptr(pm, in_game_idler.selected_province_ptr_ptr))


if __name__ == "__main__":
    main()
