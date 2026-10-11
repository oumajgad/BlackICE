import unittest

from bicevalidator import lexer, parser, schema
from bicevalidator.checks.script import ScriptChecker
from bicevalidator.declarations import Declarations

from .helpers import DOCS, TinyMod, dedent


class SchemaTest(unittest.TestCase):
    """The keyword lists are read from docs/script; these pin what was read."""

    @classmethod
    def setUpClass(cls):
        cls.schema = schema.Schema(DOCS)

    def test_counts_match_the_engine(self):
        # CTrigger::LoadKey has 152 cases and CEffect::LoadKey 91
        # (reversing/findings/FINDINGS-script.md).
        triggers = self.schema.names("trigger") | self.schema.names("combat")
        self.assertEqual(len(triggers), 152)
        self.assertEqual(len(self.schema.names("effect")), 91)
        self.assertEqual(set(self.schema.bad_keys),
                         {"brigade_exists", "fuel", "is_threatened", "neighbor", "port"})

    def test_value_types(self):
        get = self.schema.get
        self.assertEqual(get("ai", "trigger").value, schema.BOOL)
        self.assertEqual(get("dissent", "effect").value, schema.NUMBER)
        self.assertEqual(get("war_with", "trigger").value, schema.TAG)
        # The syntax shows a scope around it; only the keyword's own value counts.
        self.assertEqual(get("secede_province", "effect").value, schema.TAG)
        self.assertEqual(get("relation", "effect").value, schema.BLOCK)
        self.assertEqual(get("date", "trigger").value, "date")


class ScriptTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = TinyMod()
        cls.checker = ScriptChecker(schema.Schema(DOCS), Declarations(cls.mod.root))

    @classmethod
    def tearDownClass(cls):
        cls.mod.close()

    def events(self, text):
        src = lexer.decode("events/test.txt", dedent(text).encode("cp1252"))
        return self.checker.check_events(src, parser.parse(src.text).root)

    def rules(self, text):
        return [(d.rule, d.line) for d in self.events(text)]

    def wrap(self, trigger="", option=""):
        return ("country_event = {\n\tid = 1\n\tis_triggered_only = yes\n"
                "\ttrigger = {\n%s\n\t}\n\toption = {\n\t\tname = A\n%s\n\t}\n}\n"
                % (trigger, option))

    def test_clean_event(self):
        self.assertEqual(self.rules(self.wrap("ai = yes\nwar_with = GER",
                                              "dissent = 2\nGER = { dissent = 1 }")), [])

    def test_unknown_key_with_suggestion(self):
        found = self.events(self.wrap("infanty_brigade = 1"))
        self.assertEqual(found[0].rule, "BV101")
        self.assertIn("infantry_brigade", found[0].hint)

    def test_declared_names_are_keys(self):
        # A building, a technology, a unit type, a province and a tag are all valid keys.
        text = self.wrap("industry = 1\ninfantry_theory_tech = 1",
                         "infantry_brigade = 1\n1 = { industry = 1 }\nENG = { dissent = 1 }")
        self.assertEqual(self.rules(text), [])

    def test_known_bad_keys(self):
        found = self.events(self.wrap("brigade_exists = x\nfuel = 5", "change_owner = GER"))
        self.assertEqual([d.rule for d in found], ["BV102"] * 3)
        self.assertIn("brigade_exist", found[0].message)

    def test_wrong_context(self):
        found = self.events(self.wrap("set_country_flag = x", "has_country_flag = x"))
        self.assertEqual([d.rule for d in found], ["BV103", "BV103"])

    def test_effect_inside_a_limit(self):
        text = self.wrap(option="any_owned = {\n limit = {\n  ai = yes\n  money = 5\n"
                                "  set_province_flag = x\n }\n}")
        self.assertEqual([d.rule for d in self.events(text)], ["BV103"])

    def test_option_lost_its_opening_line(self):
        text = dedent("""
            country_event = {
                id = 1
                is_triggered_only = yes
                    name = "Give Permission"
                    metal = -5
                option = { name = B }
            }
            """)
        found = self.events(text)
        self.assertEqual([d.rule for d in found], ["BV104", "BV104"])
        self.assertIn("an effect", found[1].hint)

    def test_missing_equals(self):
        found = self.events(self.wrap(option="ai_chance = {\n factor 100\n}"))
        self.assertEqual([d.rule for d in found], ["BV113"])
        self.assertIn("factor 100", found[0].message)

    def test_value_types(self):
        found = self.events(self.wrap("ai = maybe\ndate = 1939.5.1\nis_core = GER",
                                      "dissent = lots"))
        self.assertEqual([d.rule for d in found], ["BV105", "BV105"])

    def test_event_shape(self):
        found = self.events("country_event = {\n\tid = 1\n\tid = 2\n}\nevent = { id = 3 }\n")
        self.assertEqual(sorted(d.rule for d in found), ["BV106", "BV107", "BV108", "BV112"])

    def test_not_is_left_alone(self):
        # `not` is a NOR in the engine (reversing/findings/FINDINGS-triggereval.md), so
        # several conditions under one are not a fault.
        self.assertEqual(self.rules(self.wrap("not = {\n ai = yes\n war = yes\n}")), [])


if __name__ == "__main__":
    unittest.main()
