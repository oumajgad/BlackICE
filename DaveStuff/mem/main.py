import time
import json

from pymem import Pymem

from CProvince import (
    PROVINCE_PATTERN_A,
    make_province,
    dump_province_four_bytes,
    PROVINCE_BUILDINGS_ARRAY_PATTERN_COAL,
    CProvince,
)
from utils import check_id, get_array_element_lengths, to_number

PROVINCE_ID = 1973
# 36902f08 – 36874300 = 8EC08


def do_provinces(pm):
    provinces = pm.pattern_scan_all(pattern=PROVINCE_PATTERN_A, return_multiple=True)
    print(f"{len(provinces)=}")
    for p in provinces:
        if check_id(pm, p, PROVINCE_ID):
            c_province = make_province(pm, p)
            dump_province_four_bytes(pm, p)
            # pm.write_bytes(p + 0x334, "GER".encode(), 3)
            # pm.write_bytes(p + 0x338, b"\x03\x00\x00\x00", 4)
            print(json.dumps(c_province.dict(), indent=2))
    get_array_element_lengths(provinces)


def get_province(pm, _id):
    provinces = pm.pattern_scan_all(pattern=PROVINCE_PATTERN_A, return_multiple=True)
    print(f"{len(provinces)=}")
    for p in provinces:
        if check_id(pm, p, _id):
            c_province = make_province(pm, p)
            return c_province


def do_province_building(pm: Pymem, province: CProvince, building_index: int):
    # print(hex(province.building_pointer_list_pointer))
    building_pointer = to_number(pm.read_bytes(province.building_pointer_list_pointer + (building_index * 4), 4))
    # print(hex(building_pointer))
    # print(hex(building_pointer + 0x32))
    # print(hex(building_pointer + 0x36))
    print(f"Max = {to_number(pm.read_bytes(building_pointer + 32, 4))}")
    print(f"Current = {to_number(pm.read_bytes(building_pointer + 36, 4))}")


def main():
    pm = Pymem("hoi3_tfh.exe")
    # do_province_buildings(pm)
    # do_provinces(pm)
    do_province_building(pm, get_province(pm, PROVINCE_ID), 1)  # Airbase
    do_province_building(pm, get_province(pm, PROVINCE_ID), 21)  # infra


if __name__ == "__main__":
    main()
