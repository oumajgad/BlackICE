from typing import ClassVar

import pydantic
from pymem import Pymem

from arrays.ModifiersArray import ModifiersArray
from classes.CProvinceBuilding import CProvinceBuilding
from constants import DATA_SECTION_START
from utils import utils


class CMapProvinceOffsets:
    VFTABLE_OFFSET_1: ClassVar[int] = 0x11BEBF8  # this one return  extra provinces, needs investigation
    VFTABLE_OFFSET_2: ClassVar[int] = 0x11BEC1C
    is_selected: int = 0xC
    supply_depot_province_id: int = 0x48
    id: int = 0xD0
    CTerrain_ptr: int = 0xD4
    pressure: int = 0x74  # air pressure
    province_modifiers_array_ptr: int = 0x114  # Array of CModifierDefinition
    province_timed_modifiers_list_start_ptr: int = 0x13C
    province_timed_modifiers_list_end_ptr: int = 0x140
    supply_pool: int = 0x164
    fuel_pool: int = 0x168
    oil: int = 0x27C
    metal: int = 0x280
    energy: int = 0x284
    rares: int = 0x288
    COwnerArea_ptr: int = 0x2B4
    CProvinceBuilding_array_ptr: int = 0x310
    manpower: int = 0x320
    leadership: int = 0x324
    owner_tag: int = 0x32C
    owner_id: int = 0x330
    controller_tag: int = 0x334
    controller_id: int = 0x338


class CMapProvince(pydantic.BaseModel):
    LENGTH: ClassVar[int] = 0x39C
    PROVINCES: ClassVar[list[int]] = None
    self_ptr: int
    self_ptr_str: str
    is_selected: bool
    id: int
    CTerrain_ptr: int
    owner_tag: str
    owner_id: int
    controller_tag: str
    controller_id: int
    supply_pool: int
    supply_depot_province_id: int
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
            "self_ptr_str": utils.int_to_pointer(ptr),
            "is_selected": pm.read_bool(ptr + CMapProvinceOffsets.is_selected),
            "id": utils.to_number(pm.read_bytes(ptr + CMapProvinceOffsets.id, 4)),
            "CTerrain_ptr": pm.read_uint(ptr + CMapProvinceOffsets.CTerrain_ptr),
            "owner_tag": pm.read_bytes(ptr + CMapProvinceOffsets.owner_tag, 3),
            "owner_id": utils.to_number(pm.read_bytes(ptr + CMapProvinceOffsets.owner_id, 4)),
            "controller_tag": pm.read_bytes(ptr + CMapProvinceOffsets.controller_tag, 3),
            "controller_id": utils.to_number(pm.read_bytes(ptr + CMapProvinceOffsets.controller_id, 4)),
            "supply_pool": utils.to_number(pm.read_bytes(ptr + CMapProvinceOffsets.supply_pool, 4)),
            "supply_depot_province_id": utils.to_number(
                pm.read_bytes(ptr + CMapProvinceOffsets.supply_depot_province_id, 4)
            ),
            "manpower": utils.to_number(pm.read_bytes(ptr + CMapProvinceOffsets.manpower, 4)),
            "leadership": utils.to_number(pm.read_bytes(ptr + CMapProvinceOffsets.leadership, 4)),
            "energy": utils.to_number(pm.read_bytes(ptr + CMapProvinceOffsets.energy, 4)),
            "metal": utils.to_number(pm.read_bytes(ptr + CMapProvinceOffsets.metal, 4)),
            "rares": utils.to_number(pm.read_bytes(ptr + CMapProvinceOffsets.rares, 4)),
            "oil": utils.to_number(pm.read_bytes(ptr + CMapProvinceOffsets.oil, 4)),
            "CProvinceBuilding_array_ptr": pm.read_uint(ptr + CMapProvinceOffsets.CProvinceBuilding_array_ptr),
        }

        return cls(**temp)

    @classmethod
    def get_provinces(cls, pm: Pymem) -> list[int]:
        if cls.PROVINCES:
            return cls.PROVINCES
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CMapProvinceOffsets.VFTABLE_OFFSET_2)
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
        return utils.to_number(pm.read_bytes(province_ptr + 0xD0, 4))

    def get_province_building(self, pm: Pymem, building_index: int):
        building_ptr = pm.read_uint(self.CProvinceBuilding_array_ptr + (building_index * 4))
        building = CProvinceBuilding.make(pm, building_ptr)
        x = 0
        # pm.write_bytes(building_ptr + 0x20, x.to_bytes(length=4, byteorder="little", signed=True), 4)

        return building


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    provinces = CMapProvince.get_provinces(pm)
    print(f"{len(provinces)=}")
    # prov = CMapProvince.make(pm, provinces[1000])
    # print(json.dumps(prov.dict(), indent=2))
    # for ptr in provinces:
    #     # print(ptr)
    #     province = CMapProvince.make(pm, ptr)
    prov = CMapProvince.get_province(pm, 1861)
    print(prov)
    mods_ptr = pm.read_uint(prov.self_ptr + CMapProvinceOffsets.province_modifiers_array_ptr)
    # utils.dump_bytes(pm, mods_ptr, 0x200)
    modifiers = ModifiersArray.make(pm, mods_ptr)
    print(modifiers)
    utils.dump_bytes(pm, prov.self_ptr, 0x200)
