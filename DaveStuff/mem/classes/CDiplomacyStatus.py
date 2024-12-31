import pydantic
from pymem import Pymem


class CDiplomacyStatusOffsets:
    VFTABLE_OFFSET: int = 0x11FBE78
    CWar: int = 0x20


class CDiplomacyStatus(pydantic.BaseModel):
    self_ptr: int
    CWar: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "CWar": pm.read_uint(ptr + CDiplomacyStatusOffsets.CWar),
        }

        return cls(**temp)
