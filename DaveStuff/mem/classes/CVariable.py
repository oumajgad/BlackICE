import pydantic
from pymem import Pymem

from utils import utils


class CVariableOffsets:
    name: int = 0x0
    value: int = 0x1C


class CVariable(pydantic.BaseModel):
    self_ptr: int
    name: str
    value_fixed_point: int  # x1000
    value: int

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        value_fixed_point = utils.to_number(pm.read_bytes(ptr + CVariableOffsets.value, 4))
        temp = {
            "self_ptr": ptr,
            "name": utils.get_string_maybe_ptr(pm, ptr + CVariableOffsets.name, True),
            "value_fixed_point": value_fixed_point,
            "value": int(value_fixed_point / 1000),
        }

        return cls(**temp)
