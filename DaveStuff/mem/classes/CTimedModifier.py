from typing import ClassVar

import pydantic
from pymem import Pymem

from utils import utils


class CTimedModifierOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11BC5A4
    static_modifier_ptr: int = 0x8
    expiry_date: int = 0xC


class TimedModifier(pydantic.BaseModel):
    MODIFIERS: ClassVar[list] = None
    self_ptr: int
    ptr_str: str
    static_modifier_ptr: int = 0x8
    expiry_date: int = 0xC

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
            "static_modifier_ptr": utils.to_number(pm.read_bytes(ptr + CTimedModifierOffsets.static_modifier_ptr, 4)),
            "expiry_date": utils.to_number(pm.read_bytes(ptr + CTimedModifierOffsets.expiry_date, 4)),
        }

        return cls(**temp)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
