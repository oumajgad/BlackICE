from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import to_number, rawbytes


class CProvinceBuildingOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11C0A78
    effect: int = 0x10
    CBuilding_ptr: int = 0x18
    level_max: int = 0x20
    level_current: int = 0x24


class CProvinceBuilding(pydantic.BaseModel):
    BUILDINGS: ClassVar[list[int]] = None
    self_ptr: int
    effect: int  # 0x10
    CBuilding_ptr: int  # 0x18
    level_max: int  # 0x20
    level_current: int  # 0x24

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "effect": to_number(pm.read_bytes(ptr + CProvinceBuildingOffsets.effect, 4)),
            "CBuilding_ptr": to_number(pm.read_bytes(ptr + CProvinceBuildingOffsets.CBuilding_ptr, 4)),
            "level_max": to_number(pm.read_bytes(ptr + CProvinceBuildingOffsets.level_max, 4)),
            "level_current": to_number(pm.read_bytes(ptr + CProvinceBuildingOffsets.level_current, 4)),
        }

        return cls(**temp)

    @classmethod
    def get_province_buildings(cls, pm: Pymem) -> list[int]:
        if cls.BUILDINGS:
            return cls.BUILDINGS
        res = pm.pattern_scan_all(
            pattern=rawbytes(
                (pm.base_address + CProvinceBuildingOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.BUILDINGS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.BUILDINGS


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    blds = CProvinceBuilding.get_province_buildings(pm)
    print(f"{len(blds)=}")
