import pydantic
from pymem import Pymem
from typing import ClassVar
from utils import get_string_maybe_ptr


class CProvinceModifier(pydantic.BaseModel):
    PATTERN: ClassVar[bytes] = rb"\xE4\xC4\x9C\x01"
    MODIFIERS: ClassVar[list] = None
    LENGTH: ClassVar[int] = 56
    self_ptr: int
    name_raw: str  # 0x4

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "name_raw": get_string_maybe_ptr(pm, ptr + 0x4),
        }

        return cls(**temp)
