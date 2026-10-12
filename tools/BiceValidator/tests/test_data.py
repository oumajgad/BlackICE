"""Data files against their schemas: an order of battle, the order of a model's levels, and
what a schema can declare and include."""

import json
import os
import shutil
import tempfile
import unittest

from bicevalidator import rules, runner
from bicevalidator.declarations import Declarations, tech_files
from bicevalidator.schemas import Registry, SchemaError
from bicevalidator.session import Session

from .helpers import TinyMod, dedent

OOB = dedent("""
    corps = {
        name = "First"
        location = 1
        division = {
            name = "Nested, so no location needed"
            regiment = { type = infantry_brigade historical_model = 0 }
            regment = { type = infantry_brigade }
        }
    }
    division = {
        name = "Thrown away"
        regiment = { type = made_up_brigade historical_model = 0 }
    }
    military_construction = {
        country = GER
        is_prioritized = yes
        infantry_brigade = {
            name = "Built"
            strength = 100
            model = { 1 2 }
        }
    }
    unit_deployment = {
        air = { name = "Pooled, so no base needed" wing = { type = infantry_brigade } }
    }
    """)

# Two technology files whose order depends on comparing names in lower case: `B_late`
# sorts after `a_early` that way, and before it when upper case comes first.
TECH_A = "early_tech = { infantry_brigade = { soft_attack = 1 } }\n"
TECH_B = "late_tech = { infantry_brigade = { hard_attack = 1 } }\n"


class OobTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = TinyMod()
        cls.mod.write("technologies/a_early.txt", TECH_A)
        cls.mod.write("technologies/B_late.txt", TECH_B)
        cls.mod.write("history/units/test.txt", OOB)
        result = runner.run(cls.mod.root, [rules.CODE], workers=1)
        cls.found = [(d.rule, d.message) for d in result.diagnostics
                     if d.file == "history/units/test.txt"]

    @classmethod
    def tearDownClass(cls):
        cls.mod.close()

    def has(self, rule, fragment):
        return any(r == rule and fragment in m for r, m in self.found)

    def test_a_refused_block_and_a_refused_value_are_told_apart(self):
        self.assertTrue(self.has("BV301", "`regment`"))
        self.assertTrue(self.has("BV308", "`strength`"))
        self.assertTrue(self.has("BV308", "`is_prioritized`"))

    def test_only_a_top_level_formation_needs_a_location(self):
        located = [m for r, m in self.found if r == "BV304"]
        self.assertEqual(located, ["`division` has no `location`"])

    def test_names_are_checked(self):
        self.assertTrue(self.has("BV306", "Unit type `made_up_brigade` does not exist"))

    def test_a_model_is_held_to_its_unit_types_technologies(self):
        self.assertFalse(self.has("BV307", ""))

    def test_the_technologies_are_read_in_lower_case_name_order(self):
        self.assertEqual(tech_files(self.mod.root),
                         ["technologies/a_early.txt", "technologies/B_late.txt",
                          "technologies/infantry.txt"])
        decl = Declarations(self.mod.root)
        self.assertEqual(decl.unit_techs["infantry_brigade"], ["early_tech", "late_tech"])

    def test_only_the_keys_a_loader_takes_are_coloured(self):
        session = Session(self.mod.root)
        parsed = session.parse(OOB)
        lines = OOB.split("\n")
        coloured = {lines[line - 1][col - 1:col - 1 + length]
                    for line, col, length in session.navigator.data_keys(
                        "history/units/test.txt", parsed)}
        self.assertTrue({"corps", "name", "location", "division", "regiment", "type",
                         "historical_model", "military_construction", "model",
                         "unit_deployment"} <= coloured)
        # A misspelt key, a refused one and a unit type used as a key are not.
        self.assertFalse({"regment", "strength", "is_prioritized", "infantry_brigade"} & coloured)
        self.assertEqual(session.navigator.data_keys("events/a.txt", parsed), [])

    def test_the_editor_names_each_level(self):
        session = Session(self.mod.root)
        parsed = session.parse(OOB)
        nav = session.navigator
        lines = OOB.split("\n")
        line = next(i for i, text in enumerate(lines, 1) if "model = { 1 2 }" in text)
        two = lines[line - 1].index("2 }") + 1
        hints = nav.model_hints(parsed, 1, 100)
        self.assertEqual([(l, t) for l, _, t in hints], [(line, "early_tech"), (line, "late_tech")])
        target = nav.target("history/units/test.txt", parsed, line, two)
        self.assertEqual(target.what, "model level")
        text = nav.hover(target)
        self.assertIn("Level 2 of `late_tech`", text)
        self.assertIn("hard_attack = 1", text)
        model = nav.model_at(parsed, line, lines[line - 1].index("model") + 2)
        self.assertEqual(nav.annotated_model(model, "\t"),
                         "{\n\t\t1\t# 1 early_tech\n\t\t2\t# 2 late_tech\n\t}")


class SchemaFeaturesTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.mkdtemp(prefix="bicevalidator-schemas-")
        self.mod = TinyMod()

    def tearDown(self):
        shutil.rmtree(self.folder, ignore_errors=True)
        self.mod.close()

    def schema(self, name, data):
        with open(os.path.join(self.folder, name + ".json"), "w", encoding="utf-8") as handle:
            json.dump(data, handle)

    def test_declared_names_and_included_blocks(self):
        self.schema("traits", {
            "kind": "traits", "files": ["common/traits.txt"],
            "declares": [{"kind": "trait", "depth": 0}],
            "blocks": {"file": {"open": True}, "shared": {
                "confidence": "confirmed",
                "keys": {"skill": {"value": "integer"}}}}})
        self.schema("leaders", {
            "kind": "leaders", "files": ["history/leaders/*.txt"],
            "blocks": {"file": {"confidence": "confirmed", "patterns": [
                {"match": "integer", "value": "block:leader", "repeat": True}]},
                "leader": {"confidence": "confirmed", "include": ["traits:shared"],
                           "keys": {"traits": {"value": "list:name:trait"}}}}})
        self.mod.write("common/traits.txt", "brave = { }\nclever = { }\n")
        self.mod.write("history/leaders/GER.txt",
                       "1 = { skill = 3 traits = { brave stupid } }\n2 = { skil = 1 }\n")
        os.environ["BICEVALIDATOR_SCHEMAS"] = self.folder
        try:
            result = runner.run(self.mod.root, [rules.CODE], workers=1)
        finally:
            del os.environ["BICEVALIDATOR_SCHEMAS"]
        found = {(d.rule, d.message) for d in result.diagnostics
                 if d.file == "history/leaders/GER.txt"}
        self.assertEqual(found, {("BV306", "Trait `stupid` does not exist"),
                                 ("BV308", "`skil` is not a key of `2`")})

    def test_a_broken_schema_says_where(self):
        self.schema("broken", {"kind": "broken", "files": ["x.txt"],
                               "blocks": {"file": {"keys": {"a": {"value": "block:nowhere"}}}}})
        with self.assertRaises(SchemaError) as raised:
            Registry([self.folder])
        self.assertIn("nowhere", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
