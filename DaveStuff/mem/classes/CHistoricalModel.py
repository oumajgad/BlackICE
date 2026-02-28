from typing import ClassVar

import pydantic
from pymem import Pymem

from utils import utils


class CHistoricalModelOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11C52F8
    country_tag: int = 0x8
    country_id: int = 0xC
    CSubUnitDefinition_ptr: int = 0x10
    CTechnology_list: int = 0x14
    level: int = 0x24


class CHistoricalModel(pydantic.BaseModel):
    self_ptr: int
    ptr_str: str
    country_tag: str | bytes
    country_id: int
    level: int
    CSubUnitDefinition_ptr: int
    CTechnology_list: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
            "country_tag": (pm.read_bytes(ptr + CHistoricalModelOffsets.country_tag, 3)),
            "country_id": pm.read_uint(ptr + CHistoricalModelOffsets.country_id),
            "CSubUnitDefinition_ptr": pm.read_uint(ptr + CHistoricalModelOffsets.CSubUnitDefinition_ptr),
            "CTechnology_list": pm.read_uint(ptr + CHistoricalModelOffsets.CTechnology_list),
            "level": pm.read_uint(ptr + CHistoricalModelOffsets.level),
        }

        return cls(**temp)
