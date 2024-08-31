from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CDefinesOffsets:
    VFTABLE_OFFSET: int = 0x11BB2D4


class CDefines(pydantic.BaseModel):
    SINGLETON: ClassVar[int] = None
    self_ptr: int
    ptr_str: str

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
        }

        return cls(**temp)

    @classmethod
    def get_defines(cls, pm: Pymem) -> int:
        if cls.SINGLETON:
            return cls.SINGLETON
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CDefinesOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.SINGLETON = [x for x in res if x > DATA_SECTION_START][0]
        return cls.SINGLETON


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    ptr = CDefines.get_defines(pm)
    defines = CDefines.make(pm, ptr)
    print(defines)
