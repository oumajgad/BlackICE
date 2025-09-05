from typing import ClassVar

import pydantic
from pymem import Pymem

from utils import utils


class CCurrentGameStateOffsets:
    VFTABLE_OFFSET_1: ClassVar[int] = 0x11CF674
    player_tag: int = 0x18
    player_id: int = 0x1C
    player_countries_array: int = 0xBCC  # array of bools (4 byte), country_id is the index


class CCurrentGameState(pydantic.BaseModel):
    LENGTH: ClassVar[int] = 0xDA8
    self_ptr: int
    ptr_str: str
    player_tag: str
    player_id: int
    player_countries_array: int

    @classmethod
    def make(cls, pm: Pymem):
        ptr = pm.base_address + 0x1689790
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
    utils.dump_bytes(pm, cgamestate.self_ptr, CCurrentGameState.LENGTH)
