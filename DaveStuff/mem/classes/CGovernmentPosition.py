from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CGovernmentPositionOffsets:
    VFTABLE_OFFSET: int = 0x11C29B4
    name: int = 0x30
    id: int = 0x4C


class CGovernmentPosition(pydantic.BaseModel):
    POSITIONS: ClassVar[list[int]] = None
    self_ptr: int
    name: str
    id: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "name": utils.get_string_maybe_ptr(pm=pm, ptr=ptr + CGovernmentPositionOffsets.name),
            "id": pm.read_uint(ptr + CGovernmentPositionOffsets.id),
        }

        return cls(**temp)

    @classmethod
    def get_positions(cls, pm: Pymem) -> list[int]:
        if cls.POSITIONS:
            return cls.POSITIONS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CGovernmentPositionOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.POSITIONS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.POSITIONS


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    positions = CGovernmentPosition.get_positions(pm)
    print(f"{len(positions)=}")
    for ptr in positions:
        position = CGovernmentPosition.make(pm, ptr)
        print(position)
