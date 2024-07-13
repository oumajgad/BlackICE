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


class LinkedList2NodeOffsets:
    this_1: int = 0x0
    this_2: int = 0x4
    previous: int = 0x8
    next: int = 0xC


class LinkedList2Node(pydantic.BaseModel):
    self_ptr: int
    this_1: int
    this_2: int
    previous: int
    next: int

    @classmethod
    def make(cls, pm, ptr):
        temp = {
            "self_ptr": ptr,
            "this_1": pm.read_uint(ptr + LinkedList2NodeOffsets.this_1),
            "this_2": pm.read_uint(ptr + LinkedList2NodeOffsets.this_2),
            "previous": pm.read_uint(ptr + LinkedList2NodeOffsets.previous),
            "next": pm.read_uint(ptr + LinkedList2NodeOffsets.next),
        }

        return cls(**temp)
