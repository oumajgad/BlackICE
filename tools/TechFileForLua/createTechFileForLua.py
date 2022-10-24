import pyradox.load
import pyradox.txt

pyradox.config._basedirs = {'HoI3': r'./'}  # Check your working directory config in the IDE
parse_techs, get_techs = pyradox.load.load_functions('HoI3', 'technologies', 'technologies', mode="merge")


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


if __name__ == "__main__":
    techs_raw = get_techs()
    t = to_dict(techs_raw)
    lines = []
    for name, values in t.items():
        for value in values:
            if value == 'ic_efficiency':
                lines.append(f"{name}={values.get('ic_efficiency')}\n")
    with open("tools/TechFileForLua/output.txt", "w") as file:
        file.writelines(lines)
