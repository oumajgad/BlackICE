import time

import pydantic
from pymem import Pymem

from classes.CArmy import CArmy, CArmyOffsets
from classes.CMapProvince import CMapProvince, CMapProvinceOffsets
from constants import DATA_SECTION_START
from utils import utils


class CIngameIdlerOffsets:
    VFTABLE_OFFSET_1 = 0x11CEB54
    selected_thing_ptr_ptr: int = 0x1304
    selected_thing_ptr_ptr_2: int = 0x1308
    selected_thing_window_open: int = 0x1309


class CInGameIdler(pydantic.BaseModel):
    """
    No idea what this thing does, probably does alot of things.
    Virtual function number 16 gets used by the GUI every frame.
    """

    self_ptr: int
    selected_thing_ptr_ptr: int  # nested pointers!
    selected_thing_ptr_ptr_2: int  # Copied into this field too for some reason
    selected_thing_window_open: bool  # Is the selection window open?

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
        for x in res:
            if x >= pm.base_address + DATA_SECTION_START:
                ptr = x

        temp = {
            "self_ptr": ptr,
            "selected_thing_ptr_ptr": pm.read_uint(ptr + CIngameIdlerOffsets.selected_thing_ptr_ptr),
            "selected_thing_ptr_ptr_2": pm.read_uint(ptr + CIngameIdlerOffsets.selected_thing_ptr_ptr_2),
            "selected_thing_window_open": pm.read_bool(ptr + CIngameIdlerOffsets.selected_thing_window_open),
        }

        return cls(**temp)

    @classmethod
    def _read_province_ptrs(cls, pm: Pymem, ptr):
        province_ptr_1 = utils.read_nested_pointers(pm, ptr + CIngameIdlerOffsets.selected_thing_ptr_ptr, 2)
        province_ptr_2 = utils.read_nested_pointers(pm, ptr + CIngameIdlerOffsets.selected_thing_ptr_ptr_2, 2)
        return province_ptr_1, province_ptr_2

    def update_selected_thing_ptr(self, pm: Pymem) -> int:
        self.selected_thing_ptr_ptr = pm.read_uint(self.self_ptr + CIngameIdlerOffsets.selected_thing_ptr_ptr)
        self.selected_thing_ptr_ptr_2 = pm.read_uint(self.self_ptr + CIngameIdlerOffsets.selected_thing_ptr_ptr_2)
        self.selected_thing_window_open = pm.read_bool(self.self_ptr + CIngameIdlerOffsets.selected_thing_window_open)
        return self.selected_thing_ptr_ptr

    def get_selected_thing_type(self, pm: Pymem):
        if self.selected_thing_ptr_ptr == 0:
            return None
        else:
            first_bytes = utils.read_nested_pointers(pm, self.selected_thing_ptr_ptr, 2)
            print(first_bytes)
            print(pm.base_address + CArmyOffsets.VFTABLE_OFFSET)
            if first_bytes == (pm.base_address + CMapProvinceOffsets.VFTABLE_OFFSET_2):
                return CMapProvince
            elif first_bytes == (pm.base_address + CArmyOffsets.VFTABLE_OFFSET):
                return CArmy


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    idler = CInGameIdler.make(pm)
    print(idler.self_ptr)
    while True:
        idler.update_selected_thing_ptr(pm)
        print(idler.get_selected_thing_type(pm))
        time.sleep(1)
