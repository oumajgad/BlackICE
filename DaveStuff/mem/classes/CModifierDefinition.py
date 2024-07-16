from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CModifierDefinitionOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11BC4E4
    name_raw: int = 0x4
    name_raw_length: int = 0x14


class CModifierDefinition(pydantic.BaseModel):
    MODIFIERS: ClassVar[list] = None
    LENGTH: ClassVar[int] = 56
    self_ptr: int
    name_raw: str
    name_raw_length: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "name_raw": utils.get_string_maybe_ptr(pm, ptr + CModifierDefinitionOffsets.name_raw),
            "name_raw_length": utils.to_number(pm.read_bytes(ptr + CModifierDefinitionOffsets.name_raw_length, 4)),
        }

        return cls(**temp)

    @classmethod
    def get_modifier_definitions(cls, pm: Pymem) -> list[int]:
        if cls.MODIFIERS:
            return cls.MODIFIERS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CModifierDefinitionOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.MODIFIERS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.MODIFIERS


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    defs = CModifierDefinition.get_modifier_definitions(pm)
    print(f"{len(defs)=}")
