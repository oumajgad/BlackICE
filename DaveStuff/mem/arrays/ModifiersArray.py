from typing import ClassVar

import pydantic
from pymem import Pymem

import utils.utils as utils
from classes.CModifierDefinition import CModifierDefinition


class ModifierArrayEntry(pydantic.BaseModel):
    name: str
    value: int


class ModifiersArray(pydantic.BaseModel):
    ENTRIES_AMOUNT: ClassVar[int] = 143
    self_ptr: int
    ptr_str: str
    entries: list[ModifierArrayEntry]

    @classmethod
    def make(cls, pm: Pymem, ptr: int):
        temp = {"self_ptr": ptr, "ptr_str": utils.int_to_pointer(ptr), "entries": []}

        for i in range(0, cls.ENTRIES_AMOUNT):
            offset = i * 8
            definition_ptr = pm.read_uint(ptr + offset + 4)
            definition = CModifierDefinition.make(pm, definition_ptr)
            effect = pm.read_int(ptr + offset)
            temp["entries"].append(ModifierArrayEntry(**{"name": definition.name_raw, "value": effect}))
            # print(f"{utils.int_to_pointer(offset)} - {definition.name_raw}: {effect}")

        return cls(**temp)


if __name__ == "__main__":
    pm = Pymem("hoi3_tfh.exe")
    mods = ModifiersArray.make(pm, 1)
