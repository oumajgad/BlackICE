from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CCombatManagerOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11B68F8
    CCombatHistory: int = 0xFFFFFFFF


class CCombatManager(pydantic.BaseModel):
    self_ptr: int
    # country_ptr_array: int  # array with pointers to all countries

    @classmethod
    def make(cls, pm: Pymem):
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CCombatManagerOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        ptr = 0
        for x in res:
            if x >= pm.base_address + DATA_SECTION_START:
                ptr = x

        print(f"{len(res)=}")
        temp = {
            "self_ptr": ptr,
        }

        return cls(**temp)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    combatHistory = CCombatManager.make(pm)
    print(combatHistory)
