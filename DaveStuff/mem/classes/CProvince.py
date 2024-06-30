import pydantic
from pymem import Pymem
from typing import ClassVar

from classes.CProvinceBuilding import CProvinceBuilding
from utils import to_number


class CProvince(pydantic.BaseModel):
    PATTERN: ClassVar[bytes] = rb"\xF8\xEB..\x8D\x01\x00\x00\x1C\xEC.\x01"
    LENGTH: ClassVar[int] = 936
    PROVINCES: ClassVar[list[int]] = None
    self_ptr: int
    # unknown_function_pointer: int  # 0x8 // always return 3
    is_selected: bool  # 0xc
    id: int  # 0xd0
    owner_tag: str  # 0x32c
    owner_id: int  # 0x330
    controller_tag: str  # 0x334
    controller_id: int  # 0x338
    supply_pool: int  # 0x1b4
    supply_depot_province: int  # 0x48
    manpower: int  # 0x320
    leadership: int  # 0x324
    energy: int  # 0x284
    metal: int  # 0x280
    rares: int  # 0x288
    oil: int  # 0x27c
    CProvinceBuilding_array_ptr: int  # 0x310

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "is_selected": pm.read_bool(ptr + 0xC),
            "id": to_number(pm.read_bytes(ptr + 0xD0, 4)),
            "owner_tag": pm.read_bytes(ptr + 0x32C, 3),
            "owner_id": to_number(pm.read_bytes(ptr + 0x330, 4)),
            "controller_tag": pm.read_bytes(ptr + 0x334, 3),
            "controller_id": to_number(pm.read_bytes(ptr + 0x338, 4)),
            "supply_pool": to_number(pm.read_bytes(ptr + 0x1B4, 4)),
            "supply_depot_province": to_number(pm.read_bytes(ptr + 0x48, 4)),
            "manpower": to_number(pm.read_bytes(ptr + 0x320, 4)),
            "leadership": to_number(pm.read_bytes(ptr + 0x324, 4)),
            "energy": to_number(pm.read_bytes(ptr + 0x284, 4)),
            "metal": to_number(pm.read_bytes(ptr + 0x280, 4)),
            "rares": to_number(pm.read_bytes(ptr + 0x288, 4)),
            "oil": to_number(pm.read_bytes(ptr + 0x27C, 4)),
            "CProvinceBuilding_array_ptr": pm.read_uint(ptr + 0x310),
        }

        return cls(**temp)

    @classmethod
    def get_provinces(cls, pm: Pymem) -> list[int]:
        if cls.PROVINCES:
            return cls.PROVINCES
        provinces = pm.pattern_scan_all(pattern=cls.PATTERN, return_multiple=True)
        cls.PROVINCES = provinces
        return provinces

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
