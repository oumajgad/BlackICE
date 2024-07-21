from typing import ClassVar

import pydantic
from pymem import Pymem

from classes.CGovernmentPosition import CGovernmentPosition
from classes.CMinisterType import CMinisterType
from constants import DATA_SECTION_START
from structs.LinkedLists import LinkedList2Node
from utils import utils


class CMinisterOffsets:
    VFTABLE_OFFSET: int = 0x11C2AB4
    id: int = 0xC
    name: int = 0x30
    CNullMinisterType_ptr_1: int = 0x4C
    CNullMinisterType_ptr_2: int = 0x50
    CGovernmentPosition_and_CMinisterType_list_first_ptr: int = 0x5C
    CGovernmentPosition_and_CMinisterType_list_last_ptr: int = 0x60
    number_of_positions: int = 0x64
    CIdeology_ptr: int = 0x6C
    loyalty: int = 0x70
    picture: int = 0x74


class CMinister(pydantic.BaseModel):
    MINISTERS: ClassVar[list[int]] = None
    self_ptr: int
    id: int
    name: str
    CNullMinisterType_ptr_1: int
    CNullMinisterType_ptr_2: int
    CGovernmentPosition_and_CMinisterType_list_first_ptr: int  # struct with 2 Pointers, 1. is Position, 2. is Type
    CGovernmentPosition_and_CMinisterType_list_last_ptr: int  # struct with 2 Pointers, 1. is Position, 2. is Type
    number_of_positions: int  # the amount of different positions the minister can take
    CIdeology_ptr: int
    loyalty: int
    picture: str

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "id": utils.to_number(pm.read_bytes(ptr + CMinisterOffsets.id, 4)),
            "name": utils.get_string_maybe_ptr(pm, ptr + CMinisterOffsets.name),
            "CNullMinisterType_ptr_1": pm.read_uint(ptr + CMinisterOffsets.CNullMinisterType_ptr_1),
            "CNullMinisterType_ptr_2": pm.read_uint(ptr + CMinisterOffsets.CNullMinisterType_ptr_2),
            "CGovernmentPosition_and_CMinisterType_list_first_ptr": pm.read_uint(
                ptr + CMinisterOffsets.CGovernmentPosition_and_CMinisterType_list_first_ptr
            ),
            "CGovernmentPosition_and_CMinisterType_list_last_ptr": pm.read_uint(
                ptr + CMinisterOffsets.CGovernmentPosition_and_CMinisterType_list_last_ptr
            ),
            "number_of_positions": utils.to_number(pm.read_bytes(ptr + CMinisterOffsets.number_of_positions, 4)),
            "CIdeology_ptr": pm.read_uint(ptr + CMinisterOffsets.CIdeology_ptr),
            "loyalty": utils.to_number(pm.read_bytes(ptr + CMinisterOffsets.loyalty, 4)),
            "picture": utils.get_string_maybe_ptr(pm, ptr + CMinisterOffsets.picture),
        }

        return cls(**temp)

    @classmethod
    def get_ministers(cls, pm: Pymem) -> list[int]:
        if cls.MINISTERS:
            return cls.MINISTERS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CMinisterOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.MINISTERS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.MINISTERS

    def get_positions(self, pm: Pymem) -> list[int]:
        if self.CGovernmentPosition_and_CMinisterType_list_first_ptr != 0:
            res = []
            list_node = LinkedList2Node.make(pm, self.CGovernmentPosition_and_CMinisterType_list_first_ptr)
            while True:
                res.append(list_node.this_1)
                if list_node.next == 0:
                    return res
                list_node = LinkedList2Node.make(pm, list_node.next)

    def get_types(self, pm: Pymem) -> list[int]:
        if self.CGovernmentPosition_and_CMinisterType_list_first_ptr != 0:
            res = []
            list_node = LinkedList2Node.make(pm, self.CGovernmentPosition_and_CMinisterType_list_first_ptr)
            while True:
                res.append(list_node.this_2)
                if list_node.next == 0:
                    return res
                list_node = LinkedList2Node.make(pm, list_node.next)

    def get_position_types_mapping(self, pm) -> list[tuple[CGovernmentPosition, CMinisterType]]:
        res = []
        positions = self.get_positions(pm)
        types = self.get_types(pm)
        for i in range(len(positions)):
            res.append(
                tuple(
                    [
                        CGovernmentPosition.make(pm, positions[i]),
                        CMinisterType.make(pm, types[i]),
                    ]
                )
            )
        return res


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    ministers = CMinister.get_ministers(pm)
    print(f"{len(ministers)=}")
    for ptr in ministers:
        minister = CMinister.make(pm, ptr)
        if minister.id in [116]:
            print(utils.dump_model(minister))
            for x in minister.get_position_types_mapping(pm):
                print(x)
            exit(0)
