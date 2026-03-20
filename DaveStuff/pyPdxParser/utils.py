def search_key(_dict: dict, key: str) -> list:
    def return_val(_val):
        if _val is not None:
            if isinstance(_val, list):
                return _val
            else:
                return [_val]

    val = _dict.get(key)
    if val is not None:
        return return_val(val)
    else:
        for k, v in _dict.items():
            if isinstance(v, dict):
                val = search_key(v, key)
                if val:
                    return return_val(val)
            if isinstance(v, list):
                for i in v:
                    if isinstance(i, dict):
                        val = search_key(i, key)
                        if val:
                            return return_val(val)
