from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CFlagsOffsets:
    VFTABLE_OFFSET_1: int = 0x11BB468
    VFTABLE_OFFSET_2: int = 0x11BB48C  # +0x24
    CInGameIdler_ptr_ptr: int = 0x2C


class CFlags(pydantic.BaseModel):
    FLAGS: ClassVar[list[int]] = None
    self_ptr: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "CInGameIdler_ptr_ptr": pm.read_uint(ptr + CFlagsOffsets.CInGameIdler_ptr_ptr),
        }
        return cls(**temp)

    @classmethod
    def get_flags(cls, pm: Pymem) -> list[int]:
        if cls.FLAGS:
            return cls.FLAGS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CFlagsOffsets.VFTABLE_OFFSET_1)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.FLAGS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.FLAGS

    # @classmethod
    # def get_name_from_ptr(cls, pm: Pymem, ptr: int):
    #     return get_string_maybe_ptr(pm, ptr + CFlagsOffsets.name)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    flags = CFlags.get_flags(pm)
    print(len(flags))
