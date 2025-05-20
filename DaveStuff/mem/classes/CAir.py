import pydantic


class CAirOffsets:
    VFTABLE_1: int = 0x11C8774


class CAir(pydantic.BaseModel): ...
