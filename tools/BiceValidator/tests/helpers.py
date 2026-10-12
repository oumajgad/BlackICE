"""Small mods built in a temporary folder, so the checks can be tried on exact inputs."""

import os
import shutil
import tempfile
import textwrap

TOOL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.dirname(os.path.dirname(TOOL))          # the BlackICE checkout
DOCS = os.path.join(MOD, "docs", "script")


def dedent(text):
    return textwrap.dedent(text).lstrip("\n")


class TinyMod:
    """A mod folder with just enough declared to resolve names: GER and ENG, two
    provinces, a technology, a building, a unit, an ideology, a modifier."""

    def __init__(self):
        self.root = tempfile.mkdtemp(prefix="bicevalidator-")
        shutil.copytree(DOCS, os.path.join(self.root, "docs", "script"))
        self.write("common/countries.txt", 'GER = "countries/Germany.txt"\n'
                                          'ENG = "countries/England.txt"\n')
        self.write("common/buildings.txt", "industry = { }\n")
        self.write("common/ideologies.txt", dedent("""
            fascism = {
                national_socialist = { color = { 1 2 3 } }
                faction = { tag = axis }
            }
            """))
        self.write("common/event_modifiers.txt", "real_modifier = { global_ic = 0.1 }\n")
        self.write("common/governments.txt", "national_socialism = { }\n")
        self.write("technologies/infantry.txt", "infantry_theory_tech = { }\n")
        self.write("units/infantry_brigade.txt", "infantry_brigade = { }\n")
        self.write("map/region.txt", "test_region = { 1 2 }\n")
        self.write("map/definition.csv", "province;red;green;blue;x;x\n1;1;1;1;A;x\n2;2;2;2;B;x\n")
        self.write("localisation/test.csv", "EVTNAME1;Title;;;;;;;;;;;;;x\n"
                                            "EVTDESC1;Text;;;;;;;;;;;;;x\n")
        self.write("history/units/real_oob.txt", "")
        self.write("gfx/flags/GER.tga", "")
        os.makedirs(os.path.join(self.root, "events"), exist_ok=True)
        os.makedirs(os.path.join(self.root, "decisions"), exist_ok=True)

    def write(self, rel, text, encoding="cp1252"):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding=encoding, newline="") as handle:
            handle.write(text)

    def close(self):
        shutil.rmtree(self.root, ignore_errors=True)
