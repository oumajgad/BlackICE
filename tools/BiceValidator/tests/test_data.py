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


LEADERS = dedent("""
    10 = {
        name = "Corporal" country = GER type = land skill = 1
        history = { 1936.1.1 = { rank = 1 } }
    }
    11 = {
        name = "Marshal" country = GER type = land skill = 3
        history = { 1930.1.1 = { rank = 2 } 1935.1.1 = { rank = 4 } 1940.1.1 = { rank = 2 } }
    }
    12 = {
        name = "Late" country = GER type = land skill = 2
        history = { 1939.1.1 = { rank = 3 } }
    }
    13 = {
        name = "Admiral" country = GER type = sea skill = 1
        history = { 1936.1.1 = { rank = 1 } }
    }
    14 = {
        name = "Briton" country = ENG type = land skill = 1
        history = { 1936.1.1 = { rank = 2 } }
    }
    15 = {
        name = "General" country = GER type = land skill = 2
        history = { 1936.1.1 = { rank = 2 } }
    }
    """)

START_OOB = dedent("""
    corps = {
        name = "Led by a corporal"
        location = 1
        leader = 10
        division = { name = "Led by one not in service" leader = 12 }
        division = { name = "Led by an admiral" leader = 13 }
        division = { name = "Led by a Briton" leader = 14 }
        division = { name = "Led by nobody that exists" leader = 99 }
    }
    army = {
        name = "Led by the corporal again"
        location = 2
        leader = 10
    }
    """)

# Loaded only by load_oob, at a date nothing knows: a leader is taken at the rank he holds
# once in service, and his country is not asked.
LATER_OOB = dedent("""
    corps = { name = "Late, once in service" location = 1 leader = 12 }
    army = { name = "Briton" location = 1 leader = 14 }
    """)


class LeaderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = TinyMod()
        cls.mod.write("common/bookmarks.txt", "bookmark = { name = X date = 1936.1.1 }\n")
        cls.mod.write("history/countries/GER - Germany.txt", 'capital = 1\noob = "GER_1936.txt"\n')
        cls.mod.write("history/leaders/GER.txt", LEADERS)
        cls.mod.write("history/units/GER_1936.txt", START_OOB)
        cls.mod.write("history/units/later.txt", LATER_OOB)
        result = runner.run(cls.mod.root, [rules.CODE], workers=1)
        cls.found = [(d.file, d.rule, d.message) for d in result.diagnostics
                     if d.rule in ("BV306", "BV309", "BV310", "BV311", "BV312", "BV313")]

    @classmethod
    def tearDownClass(cls):
        cls.mod.close()

    def messages(self, rule, file):
        return [m for f, r, m in self.found if r == rule and f == file]

    def test_rank_is_the_one_the_game_gives(self):
        start = self.messages("BV309", "history/units/GER_1936.txt")
        self.assertIn('Corporal (10) is rank 1, and the corps Led by a corporal wants rank 2',
                      start)
        # His history's 1939 rank 3 is not his on the start date: he has none until then.
        self.assertIn('Late (12) is rank 0 until 1939.1.1, then rank 1, and the division Led '
                      'by one not in service wants rank 1', start)
        self.assertIn('Corporal (10) is rank 1, and the army Led by the corporal again wants '
                      'rank 3', start)
        # A file only load_oob loads takes him once in service - at rank 1, not 3.
        self.assertEqual(self.messages("BV309", "history/units/later.txt"),
                         ['Late (12) is rank 1 from 1939.1.1, and the corps Late, once in '
                          'service wants rank 2',
                          'Briton (14) is rank 2, and the army Briton wants rank 3'])

    def test_arm_country_twice_and_missing(self):
        start = "history/units/GER_1936.txt"
        self.assertEqual(self.messages("BV310", start),
                         ["Admiral (13) is a sea leader, and the division Led by an admiral "
                          "wants a land one"])
        self.assertEqual(self.messages("BV311", start),
                         ["Briton (14) is ENG's leader, and this order of battle is GER's"])
        self.assertEqual(self.messages("BV311", "history/units/later.txt"), [])
        self.assertEqual(self.messages("BV312", start),
                         ["Corporal (10) is given to the army Led by the corporal again here, "
                          "after the corps Led by a corporal on line 1"])
        self.assertEqual(self.messages("BV306", start), ["Leader `99` does not exist"])

    def test_ranks_the_history_writes_and_the_game_does_not_apply(self):
        self.assertEqual(self.messages("BV313", "history/leaders/GER.txt"),
                         ["Rank 2 on 1940.1.1 is never applied to leader 11",
                          "Leader 12's first rank is 3, on 1939.1.1; the game puts him in "
                          "service that day at rank 1"])

    def test_the_editor_names_ids_and_offers_leaders(self):
        session = Session(self.mod.root)
        nav = session.navigator
        rel = "history/units/GER_1936.txt"
        parsed = session.parse(START_OOB)
        names = {(line, name) for line, _, name in nav.id_names(rel, parsed, 1, 100)}
        self.assertIn((4, "Corporal, rank 1"), names)
        self.assertIn((5, "Late, rank 0 until 1939.1.1, then rank 1"), names)
        line = START_OOB.split("\n")[4]
        target = nav.target(rel, parsed, 5, line.index("12") + 1)
        self.assertEqual(target.what, "leader")
        text = nav.hover(target)
        self.assertIn("**Late** — leader 12 of GER", text)
        self.assertIn("as GER's history loads this file on 1936.1.1", text)
        self.assertIn("the game applies only the first after the start, and as rank 1", text)
        self.assertEqual([(p.file, p.line) for p in nav.definitions(target)],
                         [("history/leaders/GER.txt", 9)])
        # In the army, after `leader = `: GER's land leaders of rank 3 and up first, then the
        # nearest below, free ones before those the file already uses (10 and 12), the other
        # arm last - and only GER's, since GER's history loads the file.
        line = START_OOB.split("\n")[12]
        items, _ = nav.completions(rel, parsed, 13, line.index("10") + 1)
        self.assertEqual([i.label for i in items], ["11", "15", "10", "12", "13"])
        self.assertIn("Marshal, GER land, rank 4", items[0].detail)


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
