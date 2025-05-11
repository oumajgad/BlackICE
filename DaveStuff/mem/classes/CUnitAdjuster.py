from typing import ClassVar

import pydantic
import pymem
from pymem import Pymem

from utils import utils


class CUnitAdjusterOffsets:
    VFTABLE_OFFSET: int = 0x11C351C
    attack: int = 0x8
    defence: int = 0xC
    movement: int = 0x10
    attrition: int = 0x14


class CUnitAdjuster(pydantic.BaseModel):
    LENGTH_BYTES: ClassVar[int] = 24
    self_ptr: int
    attack: int  # 200 => 20.0%
    defence: int  # 200 => 20.0%
    movement: int  # 200 => 20.0%
    attrition: int  # 1000 => 1

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "attack": utils.to_number(pm.read_bytes(ptr + CUnitAdjusterOffsets.attack, 4)),
            "defence": utils.to_number(pm.read_bytes(ptr + CUnitAdjusterOffsets.defence, 4)),
            "movement": utils.to_number(pm.read_bytes(ptr + CUnitAdjusterOffsets.movement, 4)),
            "attrition": utils.to_number(pm.read_bytes(ptr + CUnitAdjusterOffsets.attrition, 4)),
        }

        return cls(**temp)

    def dump_bytes(self, pm: pymem.Pymem, number_of_terrains: int):
        for terrain in range(0, number_of_terrains):
            print(f"{terrain=}")
            for i in [8, 12, 16, 20]:
                x = utils.to_number(pm.read_bytes(a_ptr + ((terrain * CUnitAdjuster.LENGTH_BYTES) + i), 4))
                print(f"{i}: {x}")


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    a_ptr = 0xD5A0B590
    a = CUnitAdjuster.make(pm=pm, ptr=a_ptr)
    print(a)
    a.dump_bytes(pm, 44)
