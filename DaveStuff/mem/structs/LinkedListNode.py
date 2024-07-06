import pydantic


class LinkedListNodeOffsets:
    this: int = 0x0
    previous: int = 0x4
    next: int = 0x8


class LinkedListNode(pydantic.BaseModel):
    self_ptr: int
    this: int
    previous: int
    next: int

    @classmethod
    def make(cls, pm, ptr):
        temp = {
            "self_ptr": ptr,
            "this": pm.read_uint(ptr),
            "previous": pm.read_uint(ptr + LinkedListNodeOffsets.previous),
            "next": pm.read_uint(ptr + LinkedListNodeOffsets.next),
        }

        return cls(**temp)
