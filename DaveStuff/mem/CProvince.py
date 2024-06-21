import pydantic
from pymem import Pymem

from utils import to_number


PROVINCE_PATTERN_A = rb"\xF8\xEB..\x8D\x01\x00\x00"
PROVINCE_PATTERN_B = rb"\xF8\xEB..\x8D\x01\x00\x00\x1C\xEC..\x00\x00\x00\x00"
PROVINCE_PATTERN_C = rb"\xF8\xEB..\x8D\x01\x00\x00\x1C\xEC..\x00\x00\x00\x00\x9F\x86\x01\x00\x00\x00\x00\x00"
PROVINCE_LENGTH_BYTES = 936


class CProvince(pydantic.BaseModel):
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
    building_pointer_list_pointer: int  # 0x310


def make_province(pm: Pymem, p_province: int):
    temp = {
        "id": to_number(pm.read_bytes(p_province + 0xD0, 4)),
        "owner": pm.read_bytes(p_province + 0x32C, 3),
        "owner_id": to_number(pm.read_bytes(p_province + 0x330, 4)),
        "controller": pm.read_bytes(p_province + 0x334, 3),
        "controller_id": to_number(pm.read_bytes(p_province + 0x338, 4)),
        "supply_pool": to_number(pm.read_bytes(p_province + 0x1B4, 4)),
        "supply_depot_province": to_number(pm.read_bytes(p_province + 0x48, 4)),
        "manpower": to_number(pm.read_bytes(p_province + 0x320, 4)),
        "leadership": to_number(pm.read_bytes(p_province + 0x324, 4)),
        "energy": to_number(pm.read_bytes(p_province + 0x284, 4)),
        "metal": to_number(pm.read_bytes(p_province + 0x280, 4)),
        "rares": to_number(pm.read_bytes(p_province + 0x288, 4)),
        "oil": to_number(pm.read_bytes(p_province + 0x27C, 4)),
        "building_pointer_list_pointer": to_number(pm.read_bytes(p_province + 0x310, 4)),
    }

    return CProvince(**temp)


def dump_province_four_bytes(pm: Pymem, p_province: int):
    print(f"Dumping {hex(p_province)}")
    current = p_province
    for _ in range(0, int(PROVINCE_LENGTH_BYTES / 4)):
        res = pm.read_bytes(current, 4)

        print(
            f"addr: +{hex(current - p_province)} hex: {hex(to_number(res))} - {to_number(res)} - {res.decode(encoding='cp1252', errors='ignore')}"
        )
        current += 4
