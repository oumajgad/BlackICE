from typing import ClassVar

import pydantic
from pymem import Pymem

from classes.CFlag import CFlag
from constants import DATA_SECTION_START
from structs.FlagsAndVarsTree import FlagsAndVarsTree
from utils import utils


class CFlagsOffsets:
    VFTABLE_OFFSET_1: int = 0x11BB468
    CFlag_tree_ptr: int = 0x4
    VFTABLE_OFFSET_2: int = 0x11BB48C  # +0x24


class CFlags(pydantic.BaseModel):
    FLAGS: ClassVar[list[int]] = None
    self_ptr: int
    flags: list[CFlag]

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "flags": cls.get_flags(pm, ptr),
        }
        return cls(**temp)

    @classmethod
    def get_cflags_instances(cls, pm: Pymem) -> list[int]:
        if cls.FLAGS:
            return cls.FLAGS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CFlagsOffsets.VFTABLE_OFFSET_1)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.FLAGS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.FLAGS

    @staticmethod
    def get_flags(pm: Pymem, ptr) -> list[CFlag]:
        res = []
        ptrs = []
        tree_ptr = pm.read_uint(ptr + CFlagsOffsets.CFlag_tree_ptr)
        if tree_ptr != 0:
            FlagsAndVarsTree.traverse_tree_depth_first(pm=pm, node_ptr=tree_ptr, res=ptrs)
            for ptr in ptrs:
                res.append(CFlag.make(pm, ptr))
        return res


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    flags = CFlags.get_cflags_instances(pm)
    print(len(flags))
