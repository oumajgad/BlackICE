from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CNavyOffsets:
    VFTABLE_OFFSET: int = 0x11C869C
    name: int = 0x16C


class CNavy(pydantic.BaseModel):
    NAVIES: ClassVar[list[int]] = None
    self_ptr: int
    ptr_str: str
    name: str

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
            "name": utils.get_string_maybe_ptr(pm, ptr + CNavyOffsets.name),
        }
        return cls(**temp)

    @classmethod
    def get_navies(cls, pm: Pymem) -> list[int]:
        if cls.NAVIES:
            return cls.NAVIES
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CNavyOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.NAVIES = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.NAVIES

    @classmethod
    def get_name_from_ptr(cls, pm: Pymem, ptr: int):
        return utils.get_string_maybe_ptr(pm, ptr + CNavyOffsets.name)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    navies = CNavy.get_navies(pm)
    print(f"{len(navies)=}")
    x = 0
    for unit_ptr in navies:
        # print(unit_ptr)
        try:
            navy = CNavy.make(pm, unit_ptr)
            print(navy)
        except Exception as e:
            print(e)
            continue
