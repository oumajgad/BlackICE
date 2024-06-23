import pydantic
from pymem import Pymem
from typing import ClassVar
from utils import to_number


class CProvince(pydantic.BaseModel):
    PATTERN: ClassVar[bytes] = rb"\xF8\xEB..\x8D\x01\x00\x00"
    LENGTH: ClassVar[int] = 936
    self_ptr: int
    id: int  # 0xd0
    owner: str  # 0x32c
    owner_id: int  # 0x330
    controller: str  # 0x334
    controller_id: int  # 0x338
    supply_pool: int  # 0x1b4
    supply_depot_province: int  # 0x48
    manpower: int  # 0x320
    leadership: int  # 0x324
    energy: int  # 0x284
    metal: int  # 0x280
    rares: int  # 0x288
    oil: int  # 0x27c
    building_array_ptr: int  # 0x310

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {
            "self_ptr": ptr,
            "id": to_number(pm.read_bytes(ptr + 0xD0, 4)),
            "owner": pm.read_bytes(ptr + 0x32C, 3),
            "owner_id": to_number(pm.read_bytes(ptr + 0x330, 4)),
            "controller": pm.read_bytes(ptr + 0x334, 3),
            "controller_id": to_number(pm.read_bytes(ptr + 0x338, 4)),
            "supply_pool": to_number(pm.read_bytes(ptr + 0x1B4, 4)),
            "supply_depot_province": to_number(pm.read_bytes(ptr + 0x48, 4)),
            "manpower": to_number(pm.read_bytes(ptr + 0x320, 4)),
            "leadership": to_number(pm.read_bytes(ptr + 0x324, 4)),
            "energy": to_number(pm.read_bytes(ptr + 0x284, 4)),
            "metal": to_number(pm.read_bytes(ptr + 0x280, 4)),
            "rares": to_number(pm.read_bytes(ptr + 0x288, 4)),
            "oil": to_number(pm.read_bytes(ptr + 0x27C, 4)),
            "building_array_ptr": to_number(pm.read_bytes(ptr + 0x310, 4)),
        }

        return cls(**temp)

    @classmethod
    def dump_province_four_bytes(cls, pm: Pymem, province_ptr: int):
        print(f"Dumping {hex(province_ptr)}")
        current = province_ptr
        for _ in range(0, int(cls.LENGTH / 4)):
            res = pm.read_bytes(current, 4)

            print(
                f"addr: +{hex(current - province_ptr)} hex: {hex(to_number(res))} - {to_number(res)} - {res.decode(encoding='cp1252', errors='ignore')}"
            )
            current += 4

    @staticmethod
    def check_id_from_ptr(pm, province_ptr, target_id):
        _id = to_number(pm.read_bytes(province_ptr + 0xD0, 4))
        return _id == target_id
