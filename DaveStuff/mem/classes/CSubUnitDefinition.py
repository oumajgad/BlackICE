from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import rawbytes, to_number


class CSubUnitDefinitionOffsets:
    VFTABLE_OFFSET: int = 0x11BDC04
    max_strength: int = 0xEC
    morale: int = 0xF4
    current_speed: int = 0x108
    toughness: int = 0x120
    soft_attack: int = 0x134
    hard_attack: int = 0x138
    piercing_attack: int = 0x13C
    armor: int = 0x12C
    hull: int = 0x178


class CSubUnitDefinition(pydantic.BaseModel):
    SUB_UNIT_DEFS: ClassVar[list[int]] = None
    self_ptr: int
    max_strength: int  # 125500 => 12.550 str
    morale: int  # 990 => 99%
    current_speed: int  # 90000 => 90 kph
    toughness: int  # 331340 => 331
    soft_attack: int  # 117600 => 117
    hard_attack: int  # 87520 => 87
    piercing_attack: int  # 15000 => 15
    armor: int  # 10000 => 10
    hull: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "max_strength": to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.max_strength, 4)),
            "morale": to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.morale, 4)),
            "current_speed": to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.current_speed, 4)),
            "toughness": to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.toughness, 4)),
            "soft_attack": to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.soft_attack, 4)),
            "hard_attack": to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.hard_attack, 4)),
            "piercing_attack": to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.piercing_attack, 4)),
            "armor": to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.armor, 4)),
            "hull": to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.hull, 4)),
        }

        return cls(**temp)

    @classmethod
    def get_sub_unit_definitions(cls, pm: Pymem) -> list[int]:
        if cls.SUB_UNIT_DEFS:
            return cls.SUB_UNIT_DEFS
        res = pm.pattern_scan_all(
            pattern=rawbytes(
                (pm.base_address + CSubUnitDefinitionOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.SUB_UNIT_DEFS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START]
        return cls.SUB_UNIT_DEFS


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    # defs = CSubUnitDefinition.get_sub_unit_definitions(pm)
    # print(f"{len(defs)=}")
    x = CSubUnitDefinition.make(pm, 0xB12DB3E8)
    print(x)
