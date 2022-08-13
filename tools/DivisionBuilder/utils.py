import pyradox


def to_dict(item):
    di = {}
    if isinstance(item, pyradox.struct.Tree._Item):
        di[item.key] = to_dict(item.value)
        return di
    elif isinstance(item, pyradox.struct.Tree):
        for i in item._data:
            di[i.key] = to_dict(i.value)
        return di
    else:
        return item


def merge_dicts_and_add(a_dict_orig: dict, b_dict_orig: dict):
    a_dict = dict(a_dict_orig)
    b_dict = dict(b_dict_orig)
    for key in b_dict:
        if key in a_dict:
            if isinstance(a_dict[key], dict) and isinstance(b_dict[key], dict):
                a_dict[key] = merge_dicts_and_add(a_dict[key], b_dict[key])
            elif isinstance(a_dict[key], int) or isinstance(a_dict[key], float):
                a_dict[key] = round((a_dict[key] + b_dict[key]), 3)
        else:
            a_dict[key] = b_dict[key]
    return dict(a_dict)


def divide_dict(a_dict, divisor):
    for key in a_dict:
        if isinstance(a_dict[key], dict):
            a_dict[key] = divide_dict(a_dict[key], divisor)
        elif isinstance(a_dict[key], int) or isinstance(a_dict[key], float):
            a_dict[key] = round((a_dict[key] / divisor), 3)
    return dict(a_dict)
