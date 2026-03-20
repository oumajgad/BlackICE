from typing import Optional

import pydantic


class Event(pydantic.BaseModel):
    class Config:
        extra = "ignore"

    id: int
    is_triggered_only: Optional[bool] = False
    title: Optional[str]
    desc: Optional[str]
    picture: Optional[str]
    potential: Optional[dict] = {}
    options: list[dict]

    @classmethod
    def from_dict(cls, _in):
        _options = _in.get("option")
        if isinstance(_options, dict):
            _options = [_options]
        return cls(
            id=_in.get("id"),
            is_triggered_only=_in.get("is_triggered_only"),
            title=_in.get("title"),
            desc=_in.get("desc"),
            picture=_in.get("picture"),
            potential=_in.get("potential"),
            options=_options,
        )

    @staticmethod
    def from_parsed(parsed: dict) -> list["Event"]:
        res = []
        a = parsed.get("country_event")
        if not a:
            return res
        if isinstance(a, list):
            for x in a:
                res.append(Event.from_dict(x))
        elif isinstance(a, dict):
            res.append(Event.from_dict(a))
        return res
