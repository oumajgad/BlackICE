from typing import ClassVar

import pydantic
from pymem import Pymem


class CCombatantOffsets:
    VFTABLE_OFFSET: int = 0x11C4DFC
    CLandCombat_ptr: int = 0x3C
    unit_list_start: int = 0x40
    unit_list_end: int = 0x44


class CCombatant(pydantic.BaseModel):
    LENGTH: ClassVar[int] = 0xE4
    self_ptr: int
    CLandCombat_ptr: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "CLandCombat_ptr": pm.read_uint(ptr + CCombatantOffsets.CLandCombat_ptr),
        }

        return cls(**temp)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
