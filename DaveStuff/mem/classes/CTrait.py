from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CTraitOffsets:
    VFTABLE_OFFSET: int = 0x11C7DC0
    name: int = 0x2C
    name_length: int = 0x3C
    pretty_name: int = 0x48
    pretty_name_length: int = 0x58
    land: int = 0x2B0
    sea: int = 0x2B1
    air: int = 0x2B2


class CTrait(pydantic.BaseModel):
    TRAITS: ClassVar[list[int]] = None
    self_ptr: int
    ptr_str: str
    name: str
    pretty_name: str
    land: int
    sea: int
    air: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
            "name": utils.get_string_maybe_ptr(pm, ptr + CTraitOffsets.name, True),
            "pretty_name": utils.get_string_maybe_ptr(pm, ptr + CTraitOffsets.pretty_name, False),
            "land": pm.read_bool(ptr + CTraitOffsets.land),
            "sea": pm.read_bool(ptr + CTraitOffsets.sea),
            "air": pm.read_bool(ptr + CTraitOffsets.air),
        }

        return cls(**temp)

    @classmethod
    def get_traits(cls, pm: Pymem) -> list[int]:
        if cls.TRAITS:
            return cls.TRAITS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CTraitOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.TRAITS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.TRAITS


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    traits = CTrait.get_traits(pm)
    print(len(traits))
    for x in traits:
        trait = CTrait.make(pm, x)
        if trait.name in ["trickster", "old_guard"]:
            print(trait)
