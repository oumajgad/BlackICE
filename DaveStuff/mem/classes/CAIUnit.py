from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CAIUnitOffsets:
    VFTABLE_OFFSET: int = 0x11EC0B0


class CAIUnit(pydantic.BaseModel):
    UNITS: ClassVar[list[int]] = None
    self_ptr: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
        }

        return cls(**temp)

    @classmethod
    def get_units(cls, pm: Pymem) -> list[int]:
        if cls.UNITS:
            return cls.UNITS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CAIUnitOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.UNITS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.UNITS


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    units = CAIUnit.get_units(pm)
    print(f"{len(units)=}")
