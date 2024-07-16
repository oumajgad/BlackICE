import pydantic
from pymem import Pymem

from utils import utils


class CVariableOffsets:
    name: int = 0x0
    value: int = 0x1C


class CVariable(pydantic.BaseModel):
    self_ptr: int
    name: str
    value: int  # x1000

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "name": utils.get_string_maybe_ptr(pm, ptr + CVariableOffsets.name, True),
            "value": utils.to_number(pm.read_bytes(ptr + CVariableOffsets.value, 4)),
        }

        return cls(**temp)
