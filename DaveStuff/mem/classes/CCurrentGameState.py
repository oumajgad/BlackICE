from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CCurrentGameStateOffsets:
    VFTABLE_OFFSET_1: ClassVar[int] = 0x11CF674
    player_tag: int = 0x18
    player_id: int = 0x1C
    player_countries_array: int = 0xBCC  # array of bools (4 byte), country_id is the index


class CCurrentGameState(pydantic.BaseModel):
    self_ptr: int
    ptr_str: str
    player_tag: str
    player_id: int
    player_countries_array: int

    @classmethod
    def make(cls, pm: Pymem):
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
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
            "ptr_str": utils.int_to_pointer(ptr),
            "player_tag": pm.read_bytes(ptr + CCurrentGameStateOffsets.player_tag, 3),
            "player_id": pm.read_uint(ptr + CCurrentGameStateOffsets.player_id),
            "player_countries_array": pm.read_uint(ptr + CCurrentGameStateOffsets.player_countries_array),
        }

        return cls(**temp)

    def is_player(self, id: int):
        return bool(pm.read_uint(self.player_countries_array + 4 * id))


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    cgamestate = CCurrentGameState.make(pm)
    print(cgamestate)
    print(cgamestate.is_player(3))
    print(cgamestate.is_player(20))
