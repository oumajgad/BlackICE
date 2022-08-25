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
                a_dict[key] = round((a_dict[key] + b_dict[key]), 2)
        else:
            a_dict[key] = b_dict[key]
    return dict(a_dict)


def divide_dict(a_dict, divisor):
    for key in a_dict:
        if isinstance(a_dict[key], dict):
            a_dict[key] = divide_dict(a_dict[key], divisor)
        elif isinstance(a_dict[key], int) or isinstance(a_dict[key], float):
            a_dict[key] = round((a_dict[key] / divisor), 2)
    return dict(a_dict)


def get_save_tech_levels(save: str, tag: str):
    techs: dict = dict()
    with open(save, "r", encoding="ISO-8859-1") as save:
        reached_ctr = False
        reached_tech = False
        for line in save:
            if not reached_ctr and line == f"{tag}=\n":
                reached_ctr = True
            elif reached_ctr is True and not reached_tech and line == "\ttechnology=\n":
                reached_tech = True
            elif reached_tech:
                if line == "\t{\n":
                    pass
                elif line == "\t}\n":
                    break
                else:
                    tech = line.strip().split("=")[0]
                    level = line.strip().split("{")[1].split(" ")[0]
                    techs[tech] = level
        return techs
