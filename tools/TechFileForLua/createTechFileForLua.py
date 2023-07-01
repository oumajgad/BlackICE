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

def run():
    techs_raw = get_techs()
    t = to_dict(techs_raw)
    linesIcEff = []
    for name, values in t.items():
        for value in values:
            if value == 'ic_efficiency':
                linesIcEff.append(f"{name}={values.get('ic_efficiency')}\n")
    with open("tools/TechFileForLua/TechsIcEffValues.txt", "w") as file:
        file.writelines(linesIcEff)
    linesIcMod = []
    for name, values in t.items():
        for value in values:
            if value == 'ic_modifier':
                linesIcMod.append(f"{name}={values.get('ic_modifier')}\n")
    with open("tools/TechFileForLua/TechsIcModValues.txt", "w") as file:
        file.writelines(linesIcMod)
    linesResEff = []
    for name, values in t.items():
        for value in values:
            if value == 'research_efficiency':
                linesResEff.append(f"{name}={values.get('research_efficiency')}\n")
    with open("tools/TechFileForLua/TechsResEffValues.txt", "w") as file:
        file.writelines(linesResEff)
    linesSuppThrou = []
    for name, values in t.items():
        for value in values:
            if value == 'supply_throughput':
                linesSuppThrou.append(f"{name}={values.get('supply_throughput')}\n")
    with open("tools/TechFileForLua/TechsSuppThrouValues.txt", "w") as file:
        file.writelines(linesSuppThrou)

if __name__ == "__main__":
    run()
