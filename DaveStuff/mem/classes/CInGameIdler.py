from typing import ClassVar

import pydantic
from pymem import Pymem
from utils import read_nested_pointers


class CInGameIdler(pydantic.BaseModel):
    """
    No idea what this thing does, probably does alot of things.
    Virtual function number 16 gets used by the GUI every frame.
    """

    PATTERN: ClassVar[bytes] = rb"\x54\xEB.\x01\x00\x00\x00\x00\x00...\x00\x00\x00\x00"
    self_ptr: int
    selected_province_ptr_ptr: int  # 0x1304 // Points into the 3rd double word of the province; nested pointers!
    selected_province_ptr_ptr_2: int  # 0x1308 // Copied into this field too for some reason
    selected_province_window_open: bool  # 0x1309 // Is the province window open?

    @classmethod
    def make(cls, pm: Pymem):
        ptr = pm.pattern_scan_all(cls.PATTERN)
        province_ptr_1, province_ptr_2 = cls._read_province_ptrs(pm, ptr)
        temp = {
            "self_ptr": ptr,
            "selected_province_ptr_ptr": province_ptr_1,
            "selected_province_ptr_ptr_2": province_ptr_2,
            "selected_province_window_open": pm.read_bool(ptr + 0x1309),
        }

        return cls(**temp)

    @classmethod
    def _read_province_ptrs(cls, pm: Pymem, ptr):
        province_ptr_1 = read_nested_pointers(pm, ptr + 0x1304, 2)
        province_ptr_2 = read_nested_pointers(pm, ptr + 0x1308, 2)
        # -8 to get the actual head of the province.
        if province_ptr_1:
            province_ptr_1 -= 8
        if province_ptr_2:
            province_ptr_2 -= 8
        return province_ptr_1, province_ptr_2

    def update_selected_province_ptr(self, pm: Pymem) -> int:
        province_ptr_1, province_ptr_2 = self._read_province_ptrs(pm, self.self_ptr)
        self.selected_province_ptr_ptr = province_ptr_1
        self.selected_province_ptr_ptr_2 = province_ptr_2
        return self.selected_province_ptr_ptr
