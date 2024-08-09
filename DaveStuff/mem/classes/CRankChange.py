import pydantic
from pymem import Pymem

from classes.CEU3Date import CEU3Date


class CRankChangeOffsets:
    VFTABLE_OFFSET: int = 0x11C9EB0
    date: int = 0x8
    rank: int = 0x10


class CRankChange(pydantic.BaseModel):
    self_ptr: int
    date: CEU3Date  # Amount of hours since 5000 BC / 1936.1.1 = 60759360
    rank: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        # print(f"Rankchange {ptr}")
        temp = {
            "self_ptr": ptr,
            "date": CEU3Date.make(pm.read_uint(ptr + CRankChangeOffsets.date)),
            "rank": pm.read_uint(ptr + CRankChangeOffsets.rank),
        }

        return cls(**temp)
