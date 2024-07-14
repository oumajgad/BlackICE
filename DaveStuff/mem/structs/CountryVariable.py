import pydantic
from pymem import Pymem

from utils import utils


class CountryVariableOffsets:
    name: int = 0x0
    value: int = 0x1C


class CountryVariable(pydantic.BaseModel):
    self_ptr: int
    name: str
    value: int  # x1000

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "name": utils.get_string_maybe_ptr(pm, ptr + CountryVariableOffsets.name, True),
            "value": utils.to_number(pm.read_bytes(ptr + CountryVariableOffsets.value, 4)),
        }

        return cls(**temp)
