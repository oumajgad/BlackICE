import time

import pydantic
from pymem import Pymem

from classes.CAir import CAirOffsets, CAir
from classes.CArmy import CArmy, CArmyOffsets
from classes.CCombat import CCombatOffsets, CCombat
from classes.CMapProvince import CMapProvince, CMapProvinceOffsets
from classes.CNavy import CNavyOffsets, CNavy
from constants import DATA_SECTION_START
from utils import utils


class CIngameIdlerOffsets:
    VFTABLE_OFFSET_1 = 0x11CEB54
    selected_things_ll_start_ptr: int = 0x1304
    selected_things_ll_end_ptr: int = 0x1308
    selected_things_amount: int = 0x1309  # byte


class CInGameIdler(pydantic.BaseModel):
    """
    No idea what this thing does, probably does alot of things.
    Virtual function number 16 gets used by the GUI every frame.
    """

    self_ptr: int
    selected_things_ll_start_ptr: int
    selected_things_ll_end_ptr: int
    selected_things_amount: int

    @classmethod
    def make(cls, pm: Pymem):
        res = pm.pattern_scan_all(
            pattern=utils.rawbytes(
                (pm.base_address + CIngameIdlerOffsets.VFTABLE_OFFSET_1)
                .to_bytes(length=4, byteorder="little", signed=False)
                .hex()
            ),
            return_multiple=True,
        )
        ptr = 0
        print(f"{len(res) = }")
        for x in res:
            if x >= pm.base_address + DATA_SECTION_START:
                if pm.read_uint(x + 4) != 0:
                    continue
                ptr = x

                print(f"{utils.int_to_pointer(pm.base_address + DATA_SECTION_START) = }")
                print(f"{utils.int_to_pointer(ptr) = }")

        if ptr == 0:
            return None

        temp = {
            "self_ptr": ptr,
            "selected_things_ll_start_ptr": pm.read_uint(ptr + CIngameIdlerOffsets.selected_things_ll_start_ptr),
            "selected_things_ll_end_ptr": pm.read_uint(ptr + CIngameIdlerOffsets.selected_things_ll_end_ptr),
            "selected_things_amount": utils.to_number(
                pm.read_bytes(ptr + CIngameIdlerOffsets.selected_things_amount, 1)
            ),
        }

        return cls(**temp)

    def update_selected_thing_ptr(self, pm: Pymem) -> int:
        self.selected_things_ll_start_ptr = pm.read_uint(
            self.self_ptr + CIngameIdlerOffsets.selected_things_ll_start_ptr
        )
        self.selected_things_ll_end_ptr = pm.read_uint(self.self_ptr + CIngameIdlerOffsets.selected_things_ll_end_ptr)
        self.selected_things_amount = pm.read_bool(self.self_ptr + CIngameIdlerOffsets.selected_things_amount)
        return self.selected_things_ll_start_ptr

    def get_selected_thing_type(self, pm: Pymem) -> []:
        if self.selected_things_ll_start_ptr == 0:
            return None
        else:
            addr = pm.read_uint(self.selected_things_ll_start_ptr)
            first_bytes = utils.read_nested_pointers(pm, self.selected_things_ll_start_ptr, 2)
            if first_bytes == (pm.base_address + CMapProvinceOffsets.VFTABLE_OFFSET_2):
                return [CMapProvince, addr]
            elif first_bytes == (pm.base_address + CArmyOffsets.VFTABLE_OFFSET):
                return [CArmy, addr]
            elif first_bytes == (pm.base_address + CNavyOffsets.VFTABLE_OFFSET):
                return [CNavy, addr]
            elif first_bytes == (pm.base_address + CAirOffsets.VFTABLE_1):
                return [CAir, addr]
            elif first_bytes == (pm.base_address + CCombatOffsets.VFTABLE_OFFSET_2):
                return [CCombat, addr - 8]
            else:
                return ["Not Implemented: " + utils.get_class_name_from_rtti(pm, first_bytes), addr]


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    print(f"{pm.base_address=}")
    idler = CInGameIdler.make(pm)
    print(idler.self_ptr)
    while True:
        idler.update_selected_thing_ptr(pm)
        print(f"{utils.int_to_pointer(idler.selected_things_ll_start_ptr) = }")
        x = idler.get_selected_thing_type(pm)
        if x is not None:
            selected_type = x[0]
            addr = x[1]
            print(f"{selected_type = } - {addr = }")
            if selected_type == CArmy:
                army = CArmy.make(pm, addr)
                print(army)
            elif selected_type == CNavy:
                navy = CNavy.make(pm, addr)
                print(navy)
            elif selected_type == CMapProvince:
                province = CMapProvince.make(pm, addr)
                print(province)
            else:
                print(x)
        time.sleep(1)
