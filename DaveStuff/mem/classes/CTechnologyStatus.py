from typing import ClassVar

import pydantic
from pymem import Pymem

from utils import utils


class CTechnologyStatusOffsets:
    VFTABLE_OFFSET: ClassVar[int] = 0x11C35BC
    technology_levels_array_ptr: int = 0x218
    building_researched_array_ptr: int = 0x28C


class CTechnologyStatus(pydantic.BaseModel):
    self_ptr: int
    ptr_str: str
    technology_levels_array_ptr: int  # array of technologies
    building_researched_array_ptr: int  # array of bools which show if the building is active due to techs

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "ptr_str": utils.int_to_pointer(ptr),
            "technology_levels_array_ptr": utils.int_to_pointer(
                pm.read_uint(ptr + CTechnologyStatusOffsets.technology_levels_array_ptr)
            ),
            "building_researched_array_ptr": utils.int_to_pointer(
                pm.read_uint(ptr + CTechnologyStatusOffsets.building_researched_array_ptr)
            ),
        }

        return cls(**temp)
