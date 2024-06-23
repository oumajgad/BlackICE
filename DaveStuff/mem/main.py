import json

from pymem import Pymem

from classes.CProvince import CProvince
from classes.CProvinceBuilding import CProvinceBuilding
from classes.CBuilding import CBuilding
from utils import get_array_element_lengths, to_number

PROVINCE_ID = 2207


def get_provinces(pm: Pymem):
    provinces = pm.pattern_scan_all(pattern=CProvince.PATTERN, return_multiple=True)
    print(f"{len(provinces)=}")
    get_array_element_lengths(provinces)
    return provinces


def get_province(pm: Pymem, provinces: list, _id: int):
    for p in provinces:
        if CProvince.check_id_from_ptr(pm, p, _id):
            c_province = CProvince.make(pm, p)
            return c_province


def get_province_building(pm: Pymem, province: CProvince, building_index: int):
    building_ptr = to_number(pm.read_bytes(province.building_array_ptr + (building_index * 4), 4))
    building = CProvinceBuilding.make(pm, building_ptr)
    # print(hex(building.self_ptr))
    # print(building)
    return building

    x = 0
    # pm.write_bytes(building_ptr + 0x20, x.to_bytes(length=4, byteorder="little", signed=True), 4)


def get_buildings(pm: Pymem):
    building_ptrs = pm.pattern_scan_all(pattern=CBuilding.PATTERN, return_multiple=True)
    print(f"{len(building_ptrs)=}")
    res = []
    for ptr in building_ptrs:
        x = CBuilding.make(pm, ptr)
        res.append(x)
    res = sorted(res, key=lambda bld: bld.index)
    return res


def search_pattern(pm: Pymem, pattern):
    res = pm.pattern_scan_all(pattern=pattern, return_multiple=True)
    print(f"{len(res)=}")
    get_array_element_lengths(res)


def main():
    pm = Pymem("hoi3_tfh.exe")
    # search_pattern(pm, rb"\xF8\x09\x8A\x01\x8D\x01\x00\x00")
    provinces = get_provinces(pm)
    province = get_province(pm, provinces, PROVINCE_ID)
    print(province)
    province_building = get_province_building(pm, province, 12)
    print(province_building)
    # buildings = get_buildings(pm)
    # for x in buildings:
    #     print(json.dumps(x.dict(), indent=2))


if __name__ == "__main__":
    main()
