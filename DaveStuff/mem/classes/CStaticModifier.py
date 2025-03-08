from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CStaticModifierOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11BC568
    name_raw: int = 0x2C
    name_raw_length: int = 0x3C


class CStaticModifier(pydantic.BaseModel):
    MODIFIERS: ClassVar[list] = None
    self_ptr: int
    name_raw: str
    name_raw_length: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "name_raw": utils.get_string_maybe_ptr(pm, ptr + CStaticModifierOffsets.name_raw),
            "name_raw_length": utils.to_number(pm.read_bytes(ptr + CStaticModifierOffsets.name_raw_length, 4)),
        }

        return cls(**temp)

    @classmethod
    def get_modifier_definitions(cls, pm: Pymem) -> list[int]:
        if cls.MODIFIERS:
            return cls.MODIFIERS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CStaticModifierOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.MODIFIERS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.MODIFIERS


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    defs = CStaticModifier.get_modifier_definitions(pm)
    print(f"{len(defs)=}")
    for ptr in defs:
        try:
            if ptr != 0x4BC87C30:
                continue
            x = CStaticModifier.make(pm, ptr)
            if x.name_raw_length > 0:
                print(x)
        except Exception:
            pass
