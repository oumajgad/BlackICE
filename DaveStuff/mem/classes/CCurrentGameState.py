from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import rawbytes


class CCurrentGameStateOffsets:
    VFTABLE_OFFSET_1: ClassVar[int] = 0x11CF674
    player_tag: int = 0x18
    player_id: int = 0x1C


class CCurrentGameState(pydantic.BaseModel):
    self_ptr: int
    player_tag: str
    player_id: int

    @classmethod
    def make(cls, pm: Pymem):
        res = pm.pattern_scan_all(
            pattern=rawbytes(
                (pm.base_address + CCurrentGameStateOffsets.VFTABLE_OFFSET_1)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        ptr = 0
        for x in res:
            if x >= pm.base_address + DATA_SECTION_START:
                ptr = x

        temp = {
            "self_ptr": ptr,
            "player_tag": pm.read_bytes(ptr + CCurrentGameStateOffsets.player_tag, 3),
            "player_id": pm.read_uint(ptr + CCurrentGameStateOffsets.player_id),
        }

        return cls(**temp)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    cgamestate = CCurrentGameState.make(pm)
    print(cgamestate)
