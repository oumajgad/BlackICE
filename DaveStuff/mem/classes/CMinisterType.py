from typing import ClassVar

import pydantic
from pymem import Pymem

import utils
from constants import DATA_SECTION_START


class CMinisterTypeOffsets:
    VFTABLE_OFFSET: int = 0x11C29F4
    name: int = 0x30
    id: int = 0x4C


class CMinisterType(pydantic.BaseModel):
    TYPES: ClassVar[list[int]] = None
    self_ptr: int
    name: str
    id: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "name": utils.get_string_maybe_ptr(pm=pm, ptr=ptr + CMinisterTypeOffsets.name),
            "id": pm.read_uint(ptr + CMinisterTypeOffsets.id),
        }

        return cls(**temp)

    @classmethod
    def get_types(cls, pm: Pymem) -> list[int]:
        if cls.TYPES:
            return cls.TYPES
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CMinisterTypeOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.TYPES = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.TYPES


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    types = CMinisterType.get_types(pm)
    print(f"{len(types)=}")
    for ptr in types:
        type = CMinisterType.make(pm, ptr)
        print(type)
