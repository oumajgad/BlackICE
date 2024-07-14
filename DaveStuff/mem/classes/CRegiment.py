from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils.utils import to_number, get_string_maybe_ptr, rawbytes, int_to_pointer


class CRegimentOffsets:
    VFTABLE_OFFSET: int = 0x11BDD7C
    strength_a: int = 0x30
    strength_b: int = 0x5C
    organisation: int = 0x60
    name: int = 0x68
    name_length: int = 0x78
    owner_tag: int = 0x94
    owner_id: int = 0x98
    division_ptr: int = 0xB0


class CRegiment(pydantic.BaseModel):
    REGIMENTS: ClassVar[list[int]] = None
    LENGTH: ClassVar[int] = 224
    self_ptr: int
    strength_a: int
    strength_b: int
    organisation: int
    name: str
    name_length: int
    owner_tag: str
    owner_id: int
    division_ptr: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "strength_a": to_number(pm.read_bytes(ptr + CRegimentOffsets.strength_a, 4)),
            "strength_b": to_number(pm.read_bytes(ptr + CRegimentOffsets.strength_b, 4)),
            "organisation": to_number(pm.read_bytes(ptr + CRegimentOffsets.organisation, 4)),
            "name": get_string_maybe_ptr(pm, ptr + CRegimentOffsets.name),
            "name_length": to_number(pm.read_bytes(ptr + CRegimentOffsets.name_length, 4)),
            "owner_tag": pm.read_bytes(ptr + CRegimentOffsets.owner_tag, 3),
            "owner_id": to_number(pm.read_bytes(ptr + CRegimentOffsets.owner_id, 4)),
            "division_ptr": pm.read_uint(ptr + CRegimentOffsets.division_ptr),
        }

        return cls(**temp)

    @classmethod
    def get_regiments(cls, pm: Pymem) -> list[int]:
        if cls.REGIMENTS:
            return cls.REGIMENTS
        res = pm.pattern_scan_all(
            pattern=rawbytes(
                (pm.base_address + CRegimentOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.REGIMENTS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.REGIMENTS

    @classmethod
    def get_name_from_ptr(cls, pm: Pymem, ptr: int):
        return get_string_maybe_ptr(pm, ptr + CRegimentOffsets.name)
        # if to_number(pm.read_bytes(ptr + CRegimentOffsets.name_length, 4)) <= 16:
        #     return read_string(pm, ptr + CRegimentOffsets.name)
        # else:
        #     return read_string(pm, pm.read_uint(ptr + CRegimentOffsets.name))

    @classmethod
    def get_division_ptr_from_ptr(cls, pm: Pymem, ptr: int):
        return pm.read_uint(ptr + CRegimentOffsets.division_ptr)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    regiments = CRegiment.get_regiments(pm)
    print(f"{len(regiments)=}")
    for reg in regiments:
        # print(reg)
        # if CRegiment.get_name_from_ptr(pm, reg) in ["Stab 1. Infanterie-Division", "Inf.-Rgt. 1/22/43"]:
        #     x = CRegiment.make(pm, reg)
        #     print(x)
        #     print(f"{int_to_pointer(x.self_ptr)=}")
        #     print(f"{int_to_pointer(x.division_ptr)=}")
        if CRegiment.get_division_ptr_from_ptr(pm, reg) == 0xBD3FF430:
            x = CRegiment.make(pm, reg)
            print(f"{int_to_pointer(x.division_ptr)=} - {int_to_pointer(x.self_ptr)=} - {x.name}")
    # y = CRegiment.make(pm, 0x90916F10)
    # print(y)
