from pymem import Pymem

from classes.CProvince import (
    PROVINCE_PATTERN_A,
    CProvince,
)
from classes.CProvinceBuilding import CProvinceBuilding
from utils import get_array_element_lengths, to_number

PROVINCE_ID = 2207


def get_provinces(pm: Pymem):
    provinces = pm.pattern_scan_all(pattern=PROVINCE_PATTERN_A, return_multiple=True)
    print(f"{len(provinces)=}")
    get_array_element_lengths(provinces)
    return provinces


def get_province(pm: Pymem, provinces: list, _id: int):
    for p in provinces:
        if CProvince.check_id_from_ptr(pm, p, _id):
            c_province = CProvince.make(pm, p)
            return c_province


def get_province_building(pm: Pymem, province: CProvince, building_index: int):
    # print(hex(province.building_pointer_list_pointer))
    building_ptr = to_number(pm.read_bytes(province.building_array_ptr + (building_index * 4), 4))
    building = CProvinceBuilding.make(pm, building_ptr)
    print(hex(building.self_ptr))
    print(building)

    x = 0
    # pm.write_bytes(building_ptr + 0x20, x.to_bytes(length=4, byteorder="little", signed=True), 4)


def main():
    pm = Pymem("hoi3_tfh.exe")
    provinces = get_provinces(pm)
    province = get_province(pm, provinces, PROVINCE_ID)
    print(province)
    get_province_building(pm, province, 11)


if __name__ == "__main__":
    main()
