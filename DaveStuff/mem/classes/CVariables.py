from typing import ClassVar

import pydantic
from pymem import Pymem

from classes.CVariable import CVariable
from constants import DATA_SECTION_START
from structs.FlagsAndVarsTree import FlagsAndVarsTree
from utils import utils


class CVariablesOffsets:
    VFTABLE_OFFSET_1: int = 0x11BD700
    CVariable_tree_ptr: int = 0x4
    VFTABLE_OFFSET_2: int = 0x11BD724  # +0x24


class CVariables(pydantic.BaseModel):
    VARIABLES: ClassVar[list[int]] = None
    self_ptr: int
    variables: list[CVariable]

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "variables": cls.get_variables(pm, ptr),
        }
        return cls(**temp)

    @classmethod
    def get_cvariables_instances(cls, pm: Pymem) -> list[int]:
        if cls.VARIABLES:
            return cls.VARIABLES
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CVariablesOffsets.VFTABLE_OFFSET_1)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.VARIABLES = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.VARIABLES

    @staticmethod
    def get_variables(pm: Pymem, ptr) -> list[CVariable]:
        res = []
        ptrs = []
        tree_ptr = pm.read_uint(ptr + CVariablesOffsets.CVariable_tree_ptr)
        if tree_ptr != 0:
            FlagsAndVarsTree.traverse_tree_depth_first(pm=pm, node_ptr=tree_ptr, res=ptrs)
            for ptr in ptrs:
                variable = CVariable.make(pm, ptr)
                if variable.value != 0:
                    res.append(variable)
        return res


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    vars = CVariables.get_cvariables_instances(pm)
    print(len(vars))
