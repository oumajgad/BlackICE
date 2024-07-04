from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import to_number, get_string_maybe_ptr, rawbytes


class CLeaderOffsets:
    VFTABLE_OFFSET: int = 0x11C5220
    id: int = 0xC
    number_of_traits: int = 0x38
    unit_ptr: int = 0x40
    country_tag: int = 0x44
    country_id: int = 0x48
    name: int = 0x4C
    rank: int = 0x6C


class CLeader(pydantic.BaseModel):
    LENGTH: ClassVar[int] = 216
    LEADERS: ClassVar[list[int]] = None
    self_ptr: int
    id: int
    number_of_traits: int
    unit_ptr: int
    country_tag: str
    country_id: int
    name: str
    rank: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "id": to_number(pm.read_bytes(ptr + CLeaderOffsets.id, 4)),
            "number_of_traits": to_number(pm.read_bytes(ptr + CLeaderOffsets.number_of_traits, 4)),
            "unit_ptr": pm.read_uint(ptr + CLeaderOffsets.unit_ptr),
            "country_tag": pm.read_bytes(ptr + CLeaderOffsets.country_tag, 3),
            "country_id": to_number(pm.read_bytes(ptr + CLeaderOffsets.country_id, 4)),
            "name": get_string_maybe_ptr(pm, ptr + CLeaderOffsets.name),
            "rank": to_number(pm.read_bytes(ptr + CLeaderOffsets.rank, 4)),
        }

        return cls(**temp)

    @classmethod
    def get_leaders(cls, pm: Pymem) -> list[int]:
        if cls.LEADERS:
            return cls.LEADERS
        res = pm.pattern_scan_all(
            pattern=rawbytes(
                (pm.base_address + CLeaderOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.LEADERS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.LEADERS


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    leaders = CLeader.get_leaders(pm)
    print(f"{len(leaders)=}")
    print(leaders[111])
