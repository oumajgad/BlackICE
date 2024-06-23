import json

from pymem import Pymem

from classes.CProvince import CProvince
from classes.CBuilding import CBuilding
from utils import get_array_element_lengths


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
    get_array_element_lengths(res)


PROVINCE_ID = 2207


def main():
    pm = Pymem("hoi3_tfh.exe")
    # search_pattern(pm, rb"\xF8\x09\x8A\x01\x8D\x01\x00\x00")
    provinces = CProvince.get_provinces(pm)
    print(f"{len(provinces)=}")
    province = CProvince.get_province(pm, PROVINCE_ID)
    print(province)
    province_building = province.get_province_building(pm, 11)
    print(province_building)
    buildings = CBuilding.get_buildings(pm)
    print(json.dumps(buildings[10].dict(), indent=2))


if __name__ == "__main__":
    main()
