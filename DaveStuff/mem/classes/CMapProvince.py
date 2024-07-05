from typing import ClassVar

import pydantic
from pymem import Pymem

from classes.CProvinceBuilding import CProvinceBuilding
from constants import DATA_SECTION_START
from utils import to_number, rawbytes


class CMapProvinceOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11BEC1C
    is_selected: int = 0xC
    id: int = 0xD0
    owner_tag: int = 0x32C
    owner_id: int = 0x330
    controller_tag: int = 0x334
    controller_id: int = 0x338
    supply_pool: int = 0x1B4
    supply_depot_province: int = 0x48
    manpower: int = 0x320
    leadership: int = 0x324
    energy: int = 0x284
    metal: int = 0x280
    rares: int = 0x288
    oil: int = 0x27C
    CProvinceBuilding_array_ptr: int = 0x310


class CMapProvince(pydantic.BaseModel):
    LENGTH: ClassVar[int] = 936
    PROVINCES: ClassVar[list[int]] = None
    self_ptr: int
    is_selected: bool
    id: int
    owner_tag: str
    owner_id: int
    controller_tag: str
    controller_id: int
    supply_pool: int
    supply_depot_province: int
    manpower: int
    leadership: int
    energy: int
    metal: int
    rares: int
    oil: int
    CProvinceBuilding_array_ptr: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "is_selected": pm.read_bool(ptr + CMapProvinceOffsets.is_selected),
            "id": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.id, 4)),
            "owner_tag": pm.read_bytes(ptr + CMapProvinceOffsets.owner_tag, 3),
            "owner_id": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.owner_id, 4)),
            "controller_tag": pm.read_bytes(ptr + CMapProvinceOffsets.controller_tag, 3),
            "controller_id": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.controller_id, 4)),
            "supply_pool": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.supply_pool, 4)),
            "supply_depot_province": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.supply_depot_province, 4)),
            "manpower": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.manpower, 4)),
            "leadership": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.leadership, 4)),
            "energy": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.energy, 4)),
            "metal": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.metal, 4)),
            "rares": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.rares, 4)),
            "oil": to_number(pm.read_bytes(ptr + CMapProvinceOffsets.oil, 4)),
            "CProvinceBuilding_array_ptr": pm.read_uint(ptr + CMapProvinceOffsets.CProvinceBuilding_array_ptr),
        }

        return cls(**temp)

    @classmethod
    def get_provinces(cls, pm: Pymem) -> list[int]:
        if cls.PROVINCES:
            return cls.PROVINCES
        res = pm.pattern_scan_all(
            pattern=rawbytes(
                (pm.base_address + CMapProvinceOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.PROVINCES = [ptr - 8 for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.PROVINCES

    @classmethod
    def get_province(cls, pm: Pymem, _id: int):
        if not cls.PROVINCES:
            cls.get_provinces(pm)
        for p in cls.PROVINCES:
            if cls.get_id_from_ptr(pm, p) == _id:
                c_province = cls.make(pm, p)
                return c_province

    @staticmethod
    def get_id_from_ptr(pm, province_ptr):
        return to_number(pm.read_bytes(province_ptr + 0xD0, 4))

    def get_province_building(self, pm: Pymem, building_index: int):
        building_ptr = pm.read_uint(self.CProvinceBuilding_array_ptr + (building_index * 4))
        building = CProvinceBuilding.make(pm, building_ptr)
        x = 0
        # pm.write_bytes(building_ptr + 0x20, x.to_bytes(length=4, byteorder="little", signed=True), 4)

        return building


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    provinces = CMapProvince.get_provinces(pm)
    print(f"{len(provinces)=}")
    # for ptr in provinces:
    #     # print(ptr)
    #     province = CMapProvince.make(pm, ptr)
