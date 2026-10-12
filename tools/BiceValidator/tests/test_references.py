import os
import unittest

from bicevalidator import rules, runner
from bicevalidator.baseline import Baseline
from bicevalidator.diagnostic import Diagnostic

from .helpers import TinyMod, dedent


class ReferencesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = TinyMod()
        cls.mod.write("events/a.txt", dedent("""
            country_event = {
                id = 1
                title = EVTNAME1
                desc = EVTDESC1
                is_triggered_only = yes
                option = {
                    name = "Fine"
                    country_event = 2
                    country_event = 99
                    load_oob = real_oob.txt
                    load_oob = missing_oob.txt
                    add_country_modifier = { name = real_modifier duration = 5 }
                    add_country_modifier = { name = made_up duration = 5 }
                    set_country_flag = used_flag
                    set_country_flag = lonely_flag
                    3 = { industry = 1 }
                    join_faction = alies
                }
            }
            country_event = {
                id = 2
                title = EVTNAME_MISSING
                desc = "Inline text is fine"
                trigger = {
                    has_country_flag = used_flag
                    has_country_flag = never_set
                    war_with = XYZ
                    controls = 2
                    controls = 999
                }
                option = { name = "OK" }
            }
            country_event = {
                id = 2
                is_triggered_only = yes
                option = { name = "Again" }
            }
            """))
        cls.result = runner.run(cls.mod.root, [rules.REFERENCES], workers=1)
        cls.found = {(d.rule, d.message) for d in cls.result.diagnostics}

    @classmethod
    def tearDownClass(cls):
        cls.mod.close()

    def has(self, rule, fragment):
        return any(r == rule and fragment in m for r, m in self.found)

    def test_events(self):
        self.assertTrue(self.has("BV201", "Event 99 "))
        self.assertFalse(self.has("BV201", "Event 2 "))
        self.assertTrue(self.has("BV202", "Event id 2"))

    def test_files_and_names(self):
        self.assertTrue(self.has("BV203", "missing_oob.txt"))
        self.assertFalse(self.has("BV203", "real_oob.txt"))
        self.assertTrue(self.has("BV207", "made_up"))
        self.assertFalse(self.has("BV207", "real_modifier"))
        self.assertTrue(self.has("BV204", "XYZ"))
        self.assertTrue(self.has("BV205", "Province 3 "))
        self.assertTrue(self.has("BV205", "Province 999 "))
        self.assertFalse(self.has("BV205", "Province 2 "))
        self.assertTrue(self.has("BV211", "alies"))

    def test_localisation(self):
        self.assertTrue(self.has("BV206", "EVTNAME_MISSING"))
        self.assertFalse(self.has("BV206", "EVTNAME1"))
        self.assertFalse(self.has("BV206", "Inline"))

    def test_flags(self):
        self.assertTrue(self.has("BV208", "never_set"))
        self.assertTrue(self.has("BV209", "lonely_flag"))
        self.assertFalse(self.has("BV208", "used_flag"))
        self.assertFalse(self.has("BV209", "used_flag"))

    def test_flag_images(self):
        self.assertTrue(self.has("BV210", "ENG"))
        self.assertFalse(self.has("BV210", "GER"))

    def test_code_findings_stay_out_of_a_references_run(self):
        self.assertTrue(all(rules.RULES[d.rule].mode == rules.REFERENCES
                            for d in self.result.diagnostics))


class BaselineTest(unittest.TestCase):
    def test_survives_moved_lines_and_counts(self):
        mod = TinyMod()
        try:
            path = os.path.join(mod.root, "baseline.json")
            a = Diagnostic("BV101", "events/a.txt", 10, 3, "`x` is not", context="ev 1 > option")
            b = Diagnostic("BV101", "events/a.txt", 11, 3, "`x` is not", context="ev 1 > option")
            baseline = Baseline(path)
            baseline.add([a])
            baseline.save()
            reloaded = Baseline(path)
            moved = Diagnostic("BV101", "events/a.txt", 40, 3, "`x` is not",
                               context="ev 1 > option")
            self.assertEqual(reloaded.known([moved]), {0})
            # Accepted once, so a second identical finding is new.
            self.assertEqual(reloaded.known([moved, b]), {0})
            self.assertEqual(len(reloaded.stale([])), 1)
        finally:
            mod.close()


if __name__ == "__main__":
    unittest.main()
