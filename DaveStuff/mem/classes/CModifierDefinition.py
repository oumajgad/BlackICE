import pydantic
from pymem import Pymem
from typing import ClassVar

from constants import DATA_SECTION_START
from utils import read_string, to_number


class CModifierDefinition(pydantic.BaseModel):
    VFTABLE_OFFSET: ClassVar[int] = 0x11BC4E4
    PATTERN: ClassVar[bytes] = rb"\xE4\xC4\x9C\x01"
    MODIFIERS: ClassVar[list] = None
    LENGTH: ClassVar[int] = 56
    self_ptr: int
    name_raw: str  # 0x4
    name_raw_length: int  # 0x14

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "name_raw_length": to_number(pm.read_bytes(ptr + 0x14, 4)),
        }
        if temp["name_raw_length"] <= 16:
            temp["name_raw"] = read_string(pm, ptr + 0x4)
        else:
            temp["name_raw"] = read_string(pm, pm.read_uint(ptr + 0x4))

        return cls(**temp)

    @classmethod
    def get_modifier_definitions(cls, pm: Pymem) -> list[int]:
        if cls.MODIFIERS:
            return cls.MODIFIERS
        res = pm.pattern_scan_all(
            pattern=(pm.base_address + cls.VFTABLE_OFFSET).to_bytes(length=4, byteorder="little", signed=False),
            return_multiple=True,
        )
        cls.MODIFIERS = [ptr for ptr in res if ptr >= DATA_SECTION_START]
        return cls.MODIFIERS
