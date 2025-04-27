import os
import pydantic
from unidecode import unidecode

class Province(pydantic.BaseModel):
    id: str
    name: str
    country_name: str
    tag: str
    lines: list[str]


def get_province_names():
    names = {}
    with open("./localisation/province_names.csv", "r") as f:
        lines = f.readlines()
        for line in lines:
            if line.startswith("PROV"):
                _id = line.split(";")[0].removeprefix("PROV")
                name = unidecode(line.split(";")[1])
                # print(f"{_id} - {name}")
                names[_id] = name
    return names

def get_country_names():
    names = {}
    with open("./localisation/countries.csv", "r") as f:
        lines = f.readlines()
        for line in lines:
            tag = line.split(";")[0]
            name = line.split(";")[1]
            # print(f"{tag} - {name}")
            names[tag] = name
    return names

def get_province_data():
    province_data: list[Province] = []
    province_names = get_province_names()
    country_names = get_country_names()
    path_base = "./history_old/provinces"
    for _, dirs, _ in os.walk(path_base):
        for _dir in dirs:
            dir = f"{path_base}/{_dir}"
            # print(f"{dir = }")
            for _, _, files in os.walk(dir):
                # print(f"{files = }")
                for file in files:
                    prov_id = file.removesuffix(".txt").split("-")[0].strip()
                    file_path = f"{dir}/{file}"
                    with open(file=file_path, mode="r") as f:
                        lines = f.readlines()
                        for line in lines:
                            if line.startswith("owner"):
                                tag = line.split("owner")[1].split("=")[1].strip()[0:3]
                                # print(tag)
                                prov = Province(id=prov_id, name=province_names[prov_id], country_name=country_names[tag], tag=tag, lines=lines)
                                province_data.append(prov)
    return province_data

province_data = get_province_data()

print(f"{len(province_data) = }")

for province in province_data:
    os.makedirs(f"./history/provinces/{province.country_name}/", exist_ok=True)
    with open(f"./history/provinces/{province.country_name}/{province.id} - {province.name}.txt", "w") as f:
        f.writelines(province.lines)
