import pydantic
from pymem import Pymem

from utils import utils


class CountryFlagOffsets:
    name: int = 0x0


class CountryFlag(pydantic.BaseModel):
    self_ptr: int
    name: str

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "name": utils.get_string_maybe_ptr(pm, ptr + CountryFlagOffsets.name, True),
        }

        return cls(**temp)
