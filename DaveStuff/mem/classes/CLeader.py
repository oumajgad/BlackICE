import json
from typing import ClassVar

import pydantic
from pymem import Pymem

from classes.CLeaderHistory import CLeaderHistory
from constants import DATA_SECTION_START
from utils import utils


class CLeaderOffsets:
    VFTABLE_OFFSET: int = 0x11C5220
    id: int = 0xC
    trait_ll_start: int = 0x30
    trait_ll_end: int = 0x34
    number_of_traits: int = 0x38
    unit_ptr: int = 0x40
    country_tag: int = 0x44
    country_id: int = 0x48
    name: int = 0x4C
    rank: int = 0x6C
    skill: int = 0x70
    max_skill: int = 0x74
    experience: int = (
        0x78  # lvl 1 = 32_768_000 -> each level needs 2x of the previous, maxes out at 540_672_000 per level (level 6)
    )
    loyalty: int = 0x80
    CLeaderHistoryOffset: int = 0x84


class CLeader(pydantic.BaseModel):
    LENGTH: ClassVar[int] = 216
    LEADERS: ClassVar[list[int]] = None
    self_ptr: int
    ptr_str: str
    id: int
    number_of_traits: int
    unit_ptr: int
    country_tag: str
    country_id: int
    name: str
    rank: int
    skill: int
    max_skill: int
    experience: int
    loyalty: int
    history: CLeaderHistory

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
            "id": utils.to_number(pm.read_bytes(ptr + CLeaderOffsets.id, 4)),
            "number_of_traits": utils.to_number(pm.read_bytes(ptr + CLeaderOffsets.number_of_traits, 4)),
            "unit_ptr": pm.read_uint(ptr + CLeaderOffsets.unit_ptr),
            "country_tag": pm.read_bytes(ptr + CLeaderOffsets.country_tag, 3),
            "country_id": utils.to_number(pm.read_bytes(ptr + CLeaderOffsets.country_id, 4)),
            "name": utils.get_string_maybe_ptr(pm, ptr + CLeaderOffsets.name),
            "rank": utils.to_number(pm.read_bytes(ptr + CLeaderOffsets.rank, 4)),
            "skill": utils.to_number(pm.read_bytes(ptr + CLeaderOffsets.skill, 4)),
            "max_skill": utils.to_number(pm.read_bytes(ptr + CLeaderOffsets.max_skill, 4)),
            "experience": utils.to_number(pm.read_bytes(ptr + CLeaderOffsets.experience, 4)),
            "loyalty": utils.to_number(pm.read_bytes(ptr + CLeaderOffsets.loyalty, 4)),
            "history": CLeaderHistory.make(pm, ptr + CLeaderOffsets.CLeaderHistoryOffset),
        }

        return cls(**temp)

    @classmethod
    def get_leaders(cls, pm: Pymem) -> list[int]:
        if cls.LEADERS:
            return cls.LEADERS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CLeaderOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.LEADERS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.LEADERS

    def get_starting_rank_and_date(self):
        rank = 0
        date = 0x7FFFFFFF
        for rank_change in x.history.history:
            if rank_change.date.EU3Date <= 60759360:
                if date < rank_change.date.EU3Date or rank_change.rank > rank:
                    date = rank_change.date.EU3Date
                    rank = rank_change.rank
            elif rank_change.date.EU3Date < date:
                rank = rank_change.rank
                date = rank_change.date.EU3Date
        return rank, date


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    leaders = CLeader.get_leaders(pm)
    print(f"{len(leaders)=}")
    out = {}
    for leader in leaders:
        # print(f"{leader=}")
        x = CLeader.make(pm, leader)
        p_skill = x.history.starting_skill + x.get_starting_rank_and_date()[0] - 1
        if p_skill < 0:
            p_skill = 0
        out[x.id] = p_skill
        if "Beck" == x.name and x.country_tag == "GER":
            print(json.dumps(x.dict(), indent=2, default=str))
            print(x.get_starting_rank_and_date())
    with open("out.txt", "w") as f:
        f.writelines(json.dumps(out, indent=2))
