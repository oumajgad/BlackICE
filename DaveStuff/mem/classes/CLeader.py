from typing import ClassVar

import pydantic
from pymem import Pymem
from utils import to_number, get_string_maybe_ptr


class CLeader(pydantic.BaseModel):
    """
    No idea what this thing does, probably does alot of things.
    Virtual function number 16 gets used by the GUI every frame.
    """

    PATTERN: ClassVar[bytes] = rb"\x20\x52.\x01\x8D\x01\x00\x00\x25\x00\x00\x00"
    LENGTH: ClassVar[int] = 216
    LEADERS: ClassVar[list[int]] = None
    self_ptr: int
    id: int  # 0xC
    number_of_traits: int  # 0x38
    unit_ptr: int  # 0x40
    country_tag: str  # 0x44
    country_id: int  # 0x48
    name: str  # 0x4C
    rank: int  # 0x6C

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "id": to_number(pm.read_bytes(ptr + 0xC, 4)),
            "number_of_traits": to_number(pm.read_bytes(ptr + 0x38, 4)),
            "unit_ptr": pm.read_uint(ptr + 0x40),
            "country_tag": pm.read_bytes(ptr + 0x44, 3),
            "country_id": to_number(pm.read_bytes(ptr + 0x48, 4)),
            "name": get_string_maybe_ptr(pm, ptr + 0x4C),
            "rank": to_number(pm.read_bytes(ptr + 0x6C, 4)),
        }

        return cls(**temp)

    @classmethod
    def get_leaders(cls, pm: Pymem) -> list[int]:
        if cls.LEADERS:
            return cls.LEADERS
        res = pm.pattern_scan_all(pattern=cls.PATTERN, return_multiple=True)
        cls.LEADERS = res
        return res
