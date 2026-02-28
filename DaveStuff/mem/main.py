import time

import pymem
from pymem import Pymem

from classes import CHistoricalModel, CTechnology, CSubUnitDefinition
from utils import utils


def write_out(out: str):
    with open("./tfh/mod/out.json", "w") as f:
        f.write(out)


def scan(pm: pymem.Pymem, addr: int) -> list[int]:
    res = pm.pattern_scan_all(
        pattern=utils.rawbytes((pm.base_address + addr).to_bytes(length=4, byteorder="little", signed=False).hex()),
        return_multiple=True,
    )
    print(res)
    print(len(res))
    return res


def main():
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    scan_res = scan(pm, CHistoricalModel.CHistoricalModelOffsets.VFTABLE_OFFSET)
    for ptr in scan_res:
        model = CHistoricalModel.CHistoricalModel.make(pm, ptr)
        if model.country_tag == b"GER" and model.level == 3:
            # print(model)
            if model.CTechnology_list == 0 or model.CSubUnitDefinition_ptr == 0:
                continue
            subunit = CSubUnitDefinition.CSubUnitDefinition.make(pm, model.CSubUnitDefinition_ptr)
            tech = CTechnology.CTechnology.make(pm, pm.read_uint(model.CTechnology_list))
            if tech.name == "art_barrel_ammo":
                # utils.dump_bytes(pm, subunit.self_ptr, 0x288)
                # utils.dump_bytes(pm, ptr, 0x28)
                print(model)
                print(subunit)
                print(tech)

    # utils.dump_bytes(pm, 0x319171A0, 0x228)

    # utils.dump_bytes(pm, 0xCC790CD8, CCombat.LENGTH + 4)
    # utils.dump_bytes(pm, 0x8B314BC0, CCombatant.LENGTH)
    # utils.dump_bytes(pm, 0x2C922888, CMapProvince.LENGTH)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(e)
        time.sleep(5)
