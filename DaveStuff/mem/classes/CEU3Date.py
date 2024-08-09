from datetime import datetime, timedelta

import pydantic


class CEU3Date(pydantic.BaseModel):
    EU3Date: int
    asDateTime: datetime

    @classmethod
    def make(cls, hours_since_5000_bc):
        temp = {
            "EU3Date": hours_since_5000_bc,
            "asDateTime": cls.to_datetime(hours_since_5000_bc),
        }
        return cls(**temp)

    @classmethod
    def to_datetime(cls, date) -> datetime:
        res = datetime(year=1936, month=1, day=1, hour=0)
        # print(f"{date = } - {res = }")
        try:
            res = res + timedelta(hours=date - 60759360)
        except OverflowError:
            res = datetime(year=1, month=1, day=1, hour=0)
        # print(res)
        return res
