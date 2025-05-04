from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CSubUnitDefinitionOffsets:
    VFTABLE_OFFSET: int = 0x11BDC04
    # General
    is_buildable: int = 0x36  # bool!
    max_strength: int = 0xEC
    morale: int = 0xF4
    current_speed: int = 0x108
    toughness: int = 0x120
    max_speed: int = 0x108
    sprite: int = 0x198  # Name of the sprite
    # Land units
    soft_attack: int = 0x134
    hard_attack: int = 0x138
    piercing_attack: int = 0x13C
    armor: int = 0x12C
    # Ships
    is_transport: int = 0x30  # bool!
    is_sub: int = 0x31
    can_be_pride: int = 0x39  # bool!
    is_capital: int = 0x2F  # bool!
    air_defence: int = 0x128
    air_attack: int = 0x140
    range: int = 0x148
    firing_distance: int = 0x14C
    surface_detection: int = 0x150
    air_detection: int = 0x154
    visibility: int = 0x15C
    sea_defence: int = 0x160
    convoy_attack: int = 0x164
    sea_attack: int = 0x168
    shore_bombardment: int = 0x170
    hull: int = 0x178
    positioning: int = 0x184
    unk_2e: int = 0x2E


class CSubUnitDefinition(pydantic.BaseModel):
    SUB_UNIT_DEFS: ClassVar[list[int]] = None
    self_ptr: int
    is_buildable: bool
    can_be_pride: bool
    max_strength: int  # 125500 => 12.550 str
    max_speed: int
    morale: int  # 990 => 99%
    current_speed: int  # 90000 => 90 kph
    toughness: int  # 331340 => 331
    soft_attack: int  # 117600 => 117
    hard_attack: int  # 87520 => 87
    piercing_attack: int  # 15000 => 15
    armor: int  # 10000 => 10
    unk_2e: bool
    is_sub: bool
    is_transport: bool
    is_capital: bool
    hull: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "is_buildable": pm.read_bool(ptr + CSubUnitDefinitionOffsets.is_buildable),
            "can_be_pride": pm.read_bool(ptr + CSubUnitDefinitionOffsets.can_be_pride),
            "max_strength": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.max_strength, 4)),
            "max_speed": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.max_speed, 4)),
            "morale": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.morale, 4)),
            "current_speed": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.current_speed, 4)),
            "toughness": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.toughness, 4)),
            "soft_attack": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.soft_attack, 4)),
            "hard_attack": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.hard_attack, 4)),
            "piercing_attack": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.piercing_attack, 4)),
            "armor": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.armor, 4)),
            "is_transport": pm.read_bool(ptr + CSubUnitDefinitionOffsets.is_transport),
            "is_capital": pm.read_bool(ptr + CSubUnitDefinitionOffsets.is_capital),
            "hull": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.hull, 4)),
            "is_sub": pm.read_bool(ptr + CSubUnitDefinitionOffsets.is_sub),
            "unk_2e": pm.read_bool(ptr + CSubUnitDefinitionOffsets.unk_2e),
        }

        return cls(**temp)

    @classmethod
    def get_sub_unit_definitions(cls, pm: Pymem) -> list[int]:
        if cls.SUB_UNIT_DEFS:
            return cls.SUB_UNIT_DEFS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
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
    dtl = 0xBC4E0A58
    dtl = CSubUnitDefinition.make(pm=pm, ptr=dtl)
    print(dtl)
    spe = 0xBC4DFEF0
    spe = CSubUnitDefinition.make(pm=pm, ptr=spe)
    print(spe)
    # utils.dump_bytes(pm=pm, ptr=addr, length=0x200)
    # x = CSubUnitDefinition.make(pm, 0xB12DB3E8)
    # print(x)
