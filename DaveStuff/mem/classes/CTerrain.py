from typing import ClassVar

import pydantic
from pymem import Pymem

from constants import DATA_SECTION_START
from utils import utils


class CTerrainOffsets:
    VFTABLE_OFFSET: int = 0x11C0764
    id: int = 0x8
    name: int = 0x28
    movement_cost: int = 0x44
    is_water: int = 0x48
    defence: int = 0x4C
    attack: int = 0x50
    temperature: int = 0x58
    attrition: int = 0x5C
    humidity: int = 0x60
    precipitation: int = 0x64


class CTerrain(pydantic.BaseModel):
    TERRAINS: ClassVar[list[int]] = None
    self_ptr: int
    id: int
    name: str
    movement_cost: int  # 1550 => 1.55 (55% Penalty)
    is_water: bool
    defence: int  # -400 => -40.0%
    attack: int  # -400 => -40.0%
    temperature: int  # -20000 => -20
    attrition: int  # 7000 => 7
    humidity: int  # 800 => 0.8
    precipitation: int  # 5000 => 5

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "id": utils.to_number(pm.read_bytes(ptr + CTerrainOffsets.id, 4)),
            "name": utils.get_string_maybe_ptr(pm, ptr + CTerrainOffsets.name),
            "movement_cost": utils.to_number(pm.read_bytes(ptr + CTerrainOffsets.movement_cost, 4)),
            "is_water": pm.read_bool(ptr + CTerrainOffsets.is_water),
            "defence": utils.to_number(pm.read_bytes(ptr + CTerrainOffsets.defence, 4)),
            "attack": utils.to_number(pm.read_bytes(ptr + CTerrainOffsets.attack, 4)),
            "temperature": utils.to_number(pm.read_bytes(ptr + CTerrainOffsets.temperature, 4)),
            "attrition": utils.to_number(pm.read_bytes(ptr + CTerrainOffsets.attrition, 4)),
            "humidity": utils.to_number(pm.read_bytes(ptr + CTerrainOffsets.humidity, 4)),
            "precipitation": utils.to_number(pm.read_bytes(ptr + CTerrainOffsets.precipitation, 4)),
        }

        return cls(**temp)

    @classmethod
    def get_terrains(cls, pm: Pymem) -> list[int]:
        if cls.TERRAINS:
            return cls.TERRAINS
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CTerrainOffsets.VFTABLE_OFFSET)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        cls.TERRAINS = [ptr for ptr in res if ptr >= pm.base_address + DATA_SECTION_START and ptr % 2 == 0]
        return cls.TERRAINS


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    terrains = CTerrain.get_terrains(pm)
    print(f"{len(terrains) = }")
    for terrain in terrains:
        x = CTerrain.make(pm, terrain)
        print(x)
        # if x.name == "normal_coast":
        #     print(x)
        #     utils.dump_bytes(pm, terrain, 120)
