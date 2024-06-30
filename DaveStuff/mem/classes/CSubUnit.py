from typing import ClassVar

import pydantic
from pymem import Pymem
from utils import to_number, get_string_maybe_ptr


class CSubUnit(pydantic.BaseModel):
    # 92C823E8
    # 7C DD 22 01 8D 01 00 00 29 00 00 00 11 00 00 00
    # 7C DD 22 01 8D 01 00 00 29 00 00 00 13 00 00 00
    PATTERN: ClassVar[bytes] = rb"\x7C\xDD\x22\x01\x8D\x01\x00\x00\x29\x00\x00\x00"
    LENGTH: ClassVar[int] = 224
    self_ptr: int
    strength_a: int  # 0x30
    strength_b: int  # 0x5C
    organisation: int  # 0x60
    name: str  # 0x68
    name_length: int  # 0x78
    owner_tag: str  # 0x94
    owner_id: int  # 0x98
    division_ptr: int  # 0xB0

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "strength_a": to_number(pm.read_bytes(ptr + 0x30, 4)),
            "strength_b": to_number(pm.read_bytes(ptr + 0x5C, 4)),
            "organisation": to_number(pm.read_bytes(ptr + 0x60, 4)),
            "name": get_string_maybe_ptr(pm, ptr + 0x68),
            "name_length": to_number(pm.read_bytes(ptr + 0x78, 4)),
            "owner_tag": pm.read_bytes(ptr + 0x94, 3),
            "owner_id": to_number(pm.read_bytes(ptr + 0x98, 4)),
            "division_ptr": pm.read_uint(ptr + 0xB0),
        }

        return cls(**temp)
