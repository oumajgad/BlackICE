import pydantic
from pymem import Pymem

from classes.CRankChange import CRankChange
from structs.LinkedLists import LinkedListNode
from utils import utils


class CLeaderHistoryOffsets:
    VFTABLE_OFFSET: int = 0x11C88C8
    CRankChange_ll_start: int = 0xC  # Linked list of the "history" entries
    CRankChange_ll_end: int = 0x10  # Linked list of the "history" entries
    starting_skill: int = 0x44


class CLeaderHistory(pydantic.BaseModel):
    self_ptr: int
    starting_skill: int
    history: list[CRankChange]

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "history": CLeaderHistory.build_history(pm, pm.read_uint(ptr + CLeaderHistoryOffsets.CRankChange_ll_start)),
            "starting_skill": utils.to_number(pm.read_bytes(ptr + CLeaderHistoryOffsets.starting_skill, 4)),
        }

        return cls(**temp)

    @staticmethod
    def build_history(pm: Pymem, ptr):
        res = []
        if ptr == 0:
            return res
        else:
            list_node = LinkedListNode.make(pm, ptr)
            while True:
                change = CRankChange.make(pm, list_node.this)
                res.append(change)
                if list_node.next == 0:
                    break
                list_node = LinkedListNode.make(pm, list_node.next)
        return res
