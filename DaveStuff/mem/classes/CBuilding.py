import pydantic
from pymem import Pymem
from typing import ClassVar
from utils import to_number, read_string


# CBuildingPATTERN = rb"\xF8\x09\x8A\x01\x8D\x01\x00\x00"


class CBuilding(pydantic.BaseModel):
    PATTERN: ClassVar[bytes] = rb"\xF8\x09\x8A\x01\x8D\x01\x00\x00"
    self_ptr: int
    index: int  # 0x54
    name_raw: str  # 0x1c
    name_pretty: str  # 0x38

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "index": to_number(pm.read_bytes(ptr + 0x54, 4)),
            "name_raw": cls.get_string(pm, ptr + 0x1C),
            "name_pretty": cls.get_string(pm, ptr + 0x38),
        }

        return cls(**temp)

    @classmethod
    def get_string(cls, pm: Pymem, ptr: int):
        x = pm.read_bytes(ptr, 4)
        if x.isascii():
            return read_string(pm, ptr)
        else:
            return read_string(pm, to_number(x))
