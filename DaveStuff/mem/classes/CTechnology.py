from typing import ClassVar

import pydantic
from pymem import Pymem

from utils import utils


class CTechnologyOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11C34B0
    name: int = 0x20C
    id: int = 0x244
    CTechnologyCategory: int = 0x28C
    CTechnologyFolder: int = 0x290


class CTechnology(pydantic.BaseModel):
    self_ptr: int
    ptr_str: str
    name: str

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
            "name": utils.get_string_maybe_ptr(pm, ptr + CTechnologyOffsets.name),
        }

        return cls(**temp)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)

    tech = CTechnology.make(pm, 0x31B22338)
    print(tech)
