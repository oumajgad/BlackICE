from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CShipOffsets:
    VFTABLE_OFFSET: int = 0x11C7A74
    name: int = 0x68
    sub_unit_definition: int = 0x58


class CShip(pydantic.BaseModel):
    SHIPS: ClassVar[list[int]] = None
    self_ptr: int
    ptr_str: str
    name: str
    sub_unit_definition: str

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
            "name": utils.get_string_maybe_ptr(pm, ptr + CShipOffsets.name),
            "sub_unit_definition": utils.int_to_pointer(pm.read_uint(ptr + CShipOffsets.sub_unit_definition)),
        }
        return cls(**temp)

    @classmethod
    def get_ships(cls, pm: Pymem) -> list[int]:
        if cls.SHIPS:
            return cls.SHIPS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CShipOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.SHIPS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.SHIPS

    @classmethod
    def get_name_from_ptr(cls, pm: Pymem, ptr: int):
        return utils.get_string_maybe_ptr(pm, ptr + CShipOffsets.name)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    ships = CShip.get_ships(pm)
    print(f"{len(ships)=}")
    x = 0
    for unit_ptr in ships:
        # print(unit_ptr)
        try:
            ship = CShip.make(pm, unit_ptr)
            print(ship)
        except Exception as e:
            print(e)
            continue
