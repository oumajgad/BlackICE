from typing import ClassVar

import pydantic
from pymem import Pymem

from utils import utils


class CGoodsPoolOffsets:
    VFTABLE: int = 0x11C1BD0
    supply: int = 0x8
    fuel: int = 0xC
    money: int = 0x10
    oil: int = 0x14
    metal: int = 0x18
    energy: int = 0x1C
    rares: int = 0x20


class CGoodsPool(pydantic.BaseModel):
    LENGTH: ClassVar[int] = 0x24
    supply: int
    fuel: int
    money: int
    oil: int
    metal: int
    energy: int
    rares: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "self_ptr_str": utils.int_to_pointer(ptr),
            "supply": utils.to_number(pm.read_bytes(ptr + CGoodsPoolOffsets.supply, 4)),
            "fuel": utils.to_number(pm.read_bytes(ptr + CGoodsPoolOffsets.fuel, 4)),
            "money": utils.to_number(pm.read_bytes(ptr + CGoodsPoolOffsets.money, 4)),
            "oil": utils.to_number(pm.read_bytes(ptr + CGoodsPoolOffsets.oil, 4)),
            "metal": utils.to_number(pm.read_bytes(ptr + CGoodsPoolOffsets.metal, 4)),
            "energy": utils.to_number(pm.read_bytes(ptr + CGoodsPoolOffsets.energy, 4)),
            "rares": utils.to_number(pm.read_bytes(ptr + CGoodsPoolOffsets.rares, 4)),
        }

        return cls(**temp)
