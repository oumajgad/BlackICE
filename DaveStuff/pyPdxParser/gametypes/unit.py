import enum
from typing import Optional

import pydantic


class UnitTypes(str, enum.Enum):
    Theatre = "theatre"
    ArmyGroup = "armygroup"
    Army = "army"
    Corps = "corps"
    Division = "division"
    Navy = "navy"
    Air = "air"


class BrigadeTypes(str, enum.Enum):
    Regiment = "regiment"
    Ship = "ship"
    Wing = "wing"


UnitTypesList = [x for x in UnitTypes]


class Brigade(pydantic.BaseModel):
    class Config:
        extra = "ignore"

    type: str
    name: Optional[str]
    historical_model: Optional[int]
    experience: Optional[int]

    @classmethod
    def from_dict(cls, _in: dict):
        return cls(
            type=_in.get("type"),
            name=_in.get("name"),
            historical_model=_in.get("historical_model"),
            experience=_in.get("experience"),
        )


class Unit(pydantic.BaseModel):
    class Config:
        extra = "ignore"

    type: str
    name: Optional[str]
    location: Optional[int]
    leader: Optional[int]
    is_reserve: Optional[bool] = False
    brigades: list[Brigade]  # Regiments, etc.
    sub_units: list["Unit"]  # Assigned Units

    @classmethod
    def from_dict(cls, unit_type: str, _in: dict):
        brigades_key = BrigadeTypes.Regiment
        if unit_type == UnitTypes.Navy:
            brigades_key = BrigadeTypes.Ship
        elif unit_type == UnitTypes.Air:
            brigades_key = BrigadeTypes.Wing
        brigades = _in.get(brigades_key, [])
        if isinstance(brigades, dict):
            brigades = [brigades]
        sub_units = []
        for k, v in _in.items():
            if k in UnitTypesList:
                if isinstance(v, list):
                    for x in v:
                        sub_units.append(Unit.from_dict(k, x))
                else:
                    sub_units.append(Unit.from_dict(k, v))

        return cls(
            type=unit_type,
            name=_in.get("name"),
            location=_in.get("location"),
            leader=_in.get("leader"),
            is_reserve=_in.get("is_reserve"),
            brigades=[Brigade.from_dict(x) for x in brigades],
            sub_units=sub_units,
        )

    @staticmethod
    def from_parsed(parsed: dict) -> list["Unit"]:
        res = []
        for k, v in parsed.items():
            if isinstance(v, list):
                for x in v:
                    res.append(Unit.from_dict(k, x))
            else:
                res.append(Unit.from_dict(k, v))
        return res
