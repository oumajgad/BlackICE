import pydantic
from pymem import Pymem
from utils import to_number


class CProvinceBuilding(pydantic.BaseModel):
    self_ptr: int
    effect: int  # 0x10
    CBuilding_ptr: int  # 0x18
    level_max: int  # 0x20
    level_current: int  # 0x24

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "effect": to_number(pm.read_bytes(ptr + 0x10, 4)),
            "CBuilding_ptr": to_number(pm.read_bytes(ptr + 0x18, 4)),
            "level_max": to_number(pm.read_bytes(ptr + 0x20, 4)),
            "level_current": to_number(pm.read_bytes(ptr + 0x24, 4)),
        }

        return cls(**temp)
