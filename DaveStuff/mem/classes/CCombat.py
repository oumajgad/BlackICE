from typing import Optional, ClassVar

import pydantic
from pymem import Pymem

from classes.CCombatant import CCombatant


class CCombatOffsets:
    VFTABLE_OFFSET_1: int = 0x11C4EE4
    VFTABLE_OFFSET_2: int = 0x11C4F34
    is_selected: int = 0xB
    attacker: int = 0x10
    defender: int = 0x14
    day: int = 0x1C
    duration: int = 0x20


class CCombat(pydantic.BaseModel):
    LENGTH: ClassVar[int] = 0x44
    self_ptr: int
    attacker: Optional[CCombatant]
    defender: Optional[CCombatant]
    is_selected: bool
    day: int
    duration: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "is_selected": pm.read_bool(ptr + CCombatOffsets.is_selected),
            "day": pm.read_uint(ptr + CCombatOffsets.day),
            "duration": pm.read_uint(ptr + CCombatOffsets.duration),
        }
        combat = cls(**temp)
        combat.attacker = CCombatant.make(pm, pm.read_uint(ptr + CCombatOffsets.attacker))
        combat.defender = CCombatant.make(pm, pm.read_uint(ptr + CCombatOffsets.defender))
        return combat


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
