import pydantic
from pymem import Pymem

from utils import utils


class CFlagOffsets:
    name: int = 0x0


class CFlag(pydantic.BaseModel):
    self_ptr: int
    name: str

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "name": utils.get_string_maybe_ptr(pm, ptr + CFlagOffsets.name, True),
        }

        return cls(**temp)
