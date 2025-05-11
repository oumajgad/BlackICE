from typing import ClassVar

import pydantic
import pymem
from pymem import Pymem

from classes.CTerrain import CTerrain
from classes.CUnitAdjuster import CUnitAdjuster
from constants import DATA_SECTION_START
from utils import utils


class CSubUnitDefinitionOffsets:
    VFTABLE_OFFSET: int = 0x11BDC04
    # General
    is_buildable: int = 0x36  # bool!
    terrain_modifiers_CUnitAdjuster_ptr: int = 0x54
    max_strength: int = 0xEC
    max_organisation: int = 0xF0
    morale: int = 0xF4
    supply_consumption: int = 0x110
    fuel_consumption: int = 0x114
    officers: int = 0x118
    max_speed: int = 0x108
    air_defence: int = 0x128
    air_attack: int = 0x140
    manpower: int = 0xFC
    sprite: int = 0x198  # Name of the sprite
    # Land units
    width: int = 0xE8
    weight: int = 0x10C
    softness: int = 0x124
    suppression: int = 0x130
    soft_attack: int = 0x134
    hard_attack: int = 0x138
    piercing_attack: int = 0x13C
    armor: int = 0x12C
    defensiveness: int = 0x11C
    toughness: int = 0x120
    # Ships
    is_transport: int = 0x30  # bool!
    is_sub: int = 0x31
    can_be_pride: int = 0x39  # bool!
    is_capital: int = 0x2F  # bool!
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
    sub_unit_amount: int = 0x180
    positioning: int = 0x184
    unk_2e: int = 0x2E


class CSubUnitDefinition(pydantic.BaseModel):
    SUB_UNIT_DEFS: ClassVar[list[int]] = None
    self_ptr: int
    # General
    is_buildable: bool
    terrain_modifiers_CUnitAdjuster_ptr: int
    sub_unit_amount: int
    supply_consumption: int  # 5000 => 5.0
    fuel_consumption: int  # 5000 => 5.0
    officers: int  # 350000 => 350
    max_strength: int  # 125500 => 12.550 str
    max_speed: int  # 3270 => 3.27 kph
    max_organisation: int  # 80000 => 80.0
    morale: int  # 990 => 99%
    manpower: int  # 8800 => 8.8
    unk_2e: bool
    # Land units
    width: int  # 4800 => 4.8
    weight: int  # 124000 => 124
    softness: int  # 496 => 49.6%
    toughness: int  # 331340 => 331 // 2x the value than ingame
    soft_attack: int  # 117600 => 117
    hard_attack: int  # 87520 => 87
    piercing_attack: int  # 15000 => 15
    armor: int  # 10000 => 10
    defensiveness: int  # 10000 => 10
    # Ships
    can_be_pride: bool
    is_sub: bool
    is_transport: bool
    is_capital: bool
    hull: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "is_buildable": pm.read_bool(ptr + CSubUnitDefinitionOffsets.is_buildable),
            "sub_unit_amount": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.sub_unit_amount, 4)),
            "terrain_modifiers_CUnitAdjuster_ptr": pm.read_uint(
                ptr + CSubUnitDefinitionOffsets.terrain_modifiers_CUnitAdjuster_ptr
            ),
            "can_be_pride": pm.read_bool(ptr + CSubUnitDefinitionOffsets.can_be_pride),
            "max_strength": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.max_strength, 4)),
            "supply_consumption": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.supply_consumption, 4)),
            "fuel_consumption": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.fuel_consumption, 4)),
            "max_speed": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.max_speed, 4)),
            "officers": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.officers, 4)),
            "max_organisation": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.max_organisation, 4)),
            "softness": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.softness, 4)),
            "defensiveness": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.defensiveness, 4)),
            "toughness": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.toughness, 4)),
            "morale": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.morale, 4)),
            "weight": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.weight, 4)),
            "manpower": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.manpower, 4)),
            "width": utils.to_number(pm.read_bytes(ptr + CSubUnitDefinitionOffsets.width, 4)),
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

    class TerrainStats(pydantic.BaseModel):
        id: int
        name: str
        attack: int  # 100 => 10%
        defence: int  # 900 => 90%
        movement: int
        attrition: int  # 10000 => 10

    def get_terrain_stats(self, pm: pymem.Pymem) -> list[TerrainStats]:
        res = []
        terrains = CTerrain.get_terrains(pm)
        addr = self.terrain_modifiers_CUnitAdjuster_ptr
        for terrain_ptr in terrains:
            terrain = CTerrain.make(pm, terrain_ptr)
            unit_adjuster = CUnitAdjuster.make(pm, addr + (terrain.id * CUnitAdjuster.LENGTH_BYTES))
            temp = {
                "name": terrain.name,
                "id": terrain.id,
                "attack": unit_adjuster.attack + terrain.attack,
                "defence": unit_adjuster.defence + terrain.defence,
                "movement": unit_adjuster.movement + terrain.movement_cost,
                "attrition": unit_adjuster.attrition + terrain.attrition,
            }
            stats = CSubUnitDefinition.TerrainStats(**temp)
            res.append(stats)
        return res


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    # defs = CSubUnitDefinition.get_sub_unit_definitions(pm)
    # print(f"{len(defs)=}")
    # a_ptr = 0xD856F880
    # a = CSubUnitDefinition.make(pm=pm, ptr=a_ptr)
    # print(a)
    # utils.dump_bytes(pm=pm, ptr=a_ptr, length=0x200)
    b_ptr = 0xD86DD3E8
    b = CSubUnitDefinition.make(pm=pm, ptr=b_ptr)
    print(b)
    # utils.dump_bytes(pm=pm, ptr=b_ptr, length=0x200)
    terrain_stats = b.get_terrain_stats(pm)
    for terrain in terrain_stats:
        print(terrain)
