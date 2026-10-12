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


CHAIN_EVENTS = dedent("""
    country_event = {
        id = 10
        trigger = { ai = no }
        option = { name = A country_event = 11 }
    }
    country_event = { id = 11 is_triggered_only = yes option = { name = A } }
    country_event = {
        id = 12
        is_triggered_only = yes
        option = { name = A country_event = 13 }
    }
    country_event = { id = 13 is_triggered_only = yes option = { name = A } }
    country_event = { id = 14 is_triggered_only = yes option = { name = A } }
    country_event = { id = 15 is_triggered_only = yes option = { name = A } }
    country_event = { id = 16 is_triggered_only = yes option = { name = A } }
    country_event = {
        id = 17
        is_triggered_only = yes
        option = { name = A country_event = { id = 18 days = 30 } }
    }
    country_event = {
        id = 18
        is_triggered_only = yes
        option = { name = A country_event = 17 }
    }
    """)


class ChainsTest(unittest.TestCase):
    """Which events can happen: fired on their own, from a decision, from on_actions, from
    a casus belli - and not from events that never happen themselves, a loop included."""

    @classmethod
    def setUpClass(cls):
        cls.mod = TinyMod()
        cls.mod.write("events/c.txt", CHAIN_EVENTS)
        cls.mod.write("decisions/d.txt", dedent("""
            political_decisions = {
                my_decision = { effect = { country_event = 14 } }
            }
            """))
        cls.mod.write("common/on_actions.txt", "on_war = {\n\t10 = 15\n}\n")
        cls.mod.write("common/cb_types.txt", dedent("""
            my_cb = {
                on_completion = { country_event = 16 country_event = 404 }
            }
            """))
        result = runner.run(cls.mod.root, [rules.REFERENCES], workers=1)
        cls.found = sorted((d.rule, d.message) for d in result.diagnostics
                           if d.rule in ("BV201", "BV213", "BV214"))

    @classmethod
    def tearDownClass(cls):
        cls.mod.close()

    def test_what_never_happens(self):
        self.assertEqual(self.found, [
            ("BV201", "Event 404 does not exist"),
            ("BV213", "Event 12 is triggered only, and nothing fires it"),
            ("BV214", "Event 13 is fired only by event 12, which never happens"),
            ("BV214", "Event 17 is fired only by event 18, which never happens"),
            ("BV214", "Event 18 is fired only by event 17, which never happens"),
        ])

    def test_the_editor_walks_the_chain(self):
        from bicevalidator.navigate import Target
        from bicevalidator.session import Session
        session = Session(self.mod.root)
        nav = session.navigator
        text = nav.hover(Target("event", "11", None, None))
        self.assertIn("Fired by event 10.", text)
        self.assertIn("**Never happens**", nav.hover(Target("event", "13", None, None)))
        parsed = session.parse(CHAIN_EVENTS)
        item = nav.chain_item("events/c.txt", parsed, 4, 3)    # inside event 10
        self.assertEqual((item.kind, item.name), ("event", "10"))
        self.assertEqual([(i.name, len(s)) for i, s in nav.callees(item)], [("11", 1)])
        sixteen = nav.event_item("16")
        [(cb, sites)] = nav.callers(sixteen)
        self.assertEqual((cb.kind, cb.name, cb.file), ("block", "my_cb", "common/cb_types.txt"))
        self.assertEqual([(i.name, i.detail) for i, _ in nav.callees(cb)],
                         [("16", "events/c.txt"), ("404", "does not exist")])
        [(decision, _)] = nav.callers(nav.event_item("14"))
        self.assertEqual((decision.kind, decision.name), ("decision", "my_decision"))
        self.assertEqual(nav.event_item("13").detail, "never happens · events/c.txt")


VARIABLE_EVENTS = dedent("""
    country_event = {
        id = 30
        is_triggered_only = yes
        trigger = {
            check_variable = { which = Counted value = 1 }
            check_variable = { which = never_set value = 2 }
            check_variable = { which = never_set_low value = 0 }
            check_variable = { which = tank_built value = 1 }
            check_variable = { which = from_lua value = 1 }
        }
        option = {
            name = A
            set_variable = { which = counted value = 1 }
            change_variable = { which = "lonely" value = 1 }
            set_variable = { which = tested_in_tech value = 1 }
        }
    }
    """)


class VariablesTest(unittest.TestCase):
    """Variables set and tested: names without case, as the game compares them, and Lua's
    names - in quotes, or built from pieces - counting as both."""

    @classmethod
    def setUpClass(cls):
        cls.mod = TinyMod()
        cls.mod.write("events/v.txt", VARIABLE_EVENTS)
        cls.mod.write("technologies/t.txt",
                      "tech = { allow = { check_variable = { which = tested_in_tech value = 1 } } }\n")
        cls.mod.write("script/v.lua", 'local a = GetVariable(CString("from_lua"))\n'
                                      'local b = CString(kind .. "_built")\n')
        result = runner.run(cls.mod.root, [rules.REFERENCES], workers=1)
        cls.found = sorted((d.rule, d.message, d.hint) for d in result.diagnostics
                           if d.rule in ("BV215", "BV216"))

    @classmethod
    def tearDownClass(cls):
        cls.mod.close()

    def test_set_and_tested(self):
        self.assertEqual({(r, m) for r, m, _ in self.found}, {
            ("BV215", "Variable `never_set` is tested but never set"),
            ("BV215", "Variable `never_set_low` is tested but never set"),
            ("BV216", "Variable `lonely` is set but never tested"),
        })
        hints = {m.split("`")[1]: h for _, m, h in self.found}
        self.assertIn("always false", hints["never_set"])
        self.assertIn("always true", hints["never_set_low"])

    def test_the_editor_follows_a_variable(self):
        from bicevalidator.session import Session
        session = Session(self.mod.root)
        nav = session.navigator
        parsed = session.parse(VARIABLE_EVENTS)
        lines = VARIABLE_EVENTS.split("\n")
        line = next(i for i, t in enumerate(lines, 1) if "which = Counted" in t)
        target = nav.target("events/v.txt", parsed, line, lines[line - 1].index("Counted") + 2)
        self.assertEqual(target.what, "variable")
        text = nav.hover(target)
        self.assertIn("Set 1 time and tested 1 time.", text)
        self.assertIn("`Counted`, `counted`", text)
        [where] = nav.definitions(target)
        self.assertEqual(where.line, next(i for i, t in enumerate(lines, 1)
                                          if "which = counted" in t))
        line = next(i for i, t in enumerate(lines, 1) if "tested_in_tech" in t)
        target = nav.target("events/v.txt", parsed, line,
                            lines[line - 1].index("tested_in_tech") + 2)
        self.assertEqual(sorted(p.file for p in nav.references(target)),
                         ["events/v.txt", "technologies/t.txt"])
        items, _ = nav.completions("events/v.txt", parsed, line,
                                   lines[line - 1].index("tested_in_tech") + 1)
        self.assertIn("Counted", [i.label for i in items])


GUARD_EVENTS = dedent("""
    country_event = {
        id = 40
        is_triggered_only = yes
        option = {
            name = A
            any_country = {
                limit = { tag = GER controls = 1 }
                load_oob = in_one.txt
            }
            any_country = {
                limit = { tag = GER not = { controls = 1 } }
                load_oob = in_two.txt
            }
            any_country = {
                limit = { or = { controls = 1 controls = 2 } or = { controls = 2 2 = { controller = { tag = GER } } } }
                load_oob = in_both.txt
            }
        }
    }
    country_event = {
        id = 41
        is_triggered_only = yes
        option = { name = A load_oob = in_both.txt }
    }
    """)


class GuardsTest(unittest.TestCase):
    """load_oob puts units where its file says: each province should have its controller
    tested on every way to the load - here by the decision that fires event 41."""

    @classmethod
    def setUpClass(cls):
        cls.mod = TinyMod()
        cls.mod.write("events/g.txt", GUARD_EVENTS)
        cls.mod.write("decisions/g.txt", dedent("""
            political_decisions = {
                fire_41 = {
                    potential = { tag = GER }
                    allow = { controls = 1 2 = { controlled_by = THIS } }
                    effect = { country_event = 40 country_event = 41 }
                }
            }
            """))
        for name, places in (("in_one.txt", "1"), ("in_two.txt", "2"), ("in_both.txt", "1 2")):
            units = "".join('division = { name = "D%s" location = %s }\n' % (p, p)
                            for p in places.split())
            cls.mod.write("history/units/" + name, units + "unit_deployment = { air = { location = 2 } }\n")
        result = runner.run(cls.mod.root, [rules.REFERENCES], workers=1)
        cls.found = sorted((d.line, d.message) for d in result.diagnostics if d.rule == "BV217")

    @classmethod
    def tearDownClass(cls):
        cls.mod.close()

    def test_each_load_against_its_own_tests(self):
        # The decision tests 1 and 2 before firing either event, so every load is guarded.
        self.assertEqual(self.found, [])

    def test_without_the_decision(self):
        mod = TinyMod()
        try:
            mod.write("events/g.txt", GUARD_EVENTS)
            mod.write("decisions/g.txt", "political_decisions = {\n\tfire = { effect = { "
                                         "country_event = 40 country_event = 41 } }\n}\n")
            for name, places in (("in_one.txt", "1"), ("in_two.txt", "2"),
                                 ("in_both.txt", "1 2")):
                mod.write("history/units/" + name, "".join(
                    'division = { name = "D%s" location = %s }\n' % (p, p) for p in places.split()))
            result = runner.run(mod.root, [rules.REFERENCES], workers=1)
            found = [d.message for d in result.diagnostics if d.rule == "BV217"]
        finally:
            mod.close()
        # in_one is guarded by its limit; the fallback's `not` guards nothing; the first `or`
        # guards neither province alone, the second guards 2; event 41's load nothing.
        self.assertEqual(sorted(found), [
            "in_both.txt puts units in 1 province nothing checks the controller of: 1",
            "in_both.txt puts units in 2 provinces nothing checks the controller of: 1, 2",
            "in_two.txt puts units in 1 province nothing checks the controller of: 2",
        ])

    def test_a_switch_on_a_flag_guards_where_the_flag_is_set(self):
        # The decision needs province 1 only in production mode; the production load asks
        # for that mode, so it is guarded, and the spawn load is not.
        mod = TinyMod()
        try:
            mod.write("decisions/g.txt", dedent("""
                political_decisions = {
                    build = {
                        allow = {
                            or = {
                                not = { has_country_flag = OOB_production }
                                controls = 1
                            }
                        }
                        effect = { country_event = 50 }
                    }
                }
                """))
            mod.write("events/g.txt", dedent("""
                country_event = {
                    id = 50
                    is_triggered_only = yes
                    option = {
                        name = A
                        any_country = {
                            limit = { tag = GER has_country_flag = OOB_production }
                            load_oob = in_one_build.txt
                        }
                        any_country = {
                            limit = { tag = GER has_country_flag = OOB_spawn }
                            load_oob = in_one.txt
                        }
                    }
                }
                """))
            for name in ("in_one.txt", "in_one_build.txt"):
                mod.write("history/units/" + name, 'corps = { name = "C" location = 1 }\n')
            result = runner.run(mod.root, [rules.REFERENCES], workers=1)
            found = [d.message for d in result.diagnostics if d.rule == "BV217"]
        finally:
            mod.close()
        self.assertEqual(found, ["in_one.txt puts units in 1 province nothing checks the "
                                 "controller of: 1"])

    def test_the_hover_marks_each_province(self):
        from bicevalidator.session import Session
        session = Session(self.mod.root)
        nav = session.navigator
        parsed = session.parse(GUARD_EVENTS)
        lines = GUARD_EVENTS.split("\n")
        line = next(i for i, t in enumerate(lines, 1) if "load_oob = in_two.txt" in t)
        target = nav.target("events/g.txt", parsed, line, lines[line - 1].index("in_two") + 2)
        text = nav.hover(target)
        self.assertIn("Puts units in 1 province, each one's controller tested", text)
        self.assertIn("(2) ✓", text)


class PicturesTest(unittest.TestCase):
    """BV212: a picture is found in the mod or in the game; without the game, not checked."""

    @classmethod
    def setUpClass(cls):
        cls.mod = TinyMod()
        events = []
        for number, picture in enumerate(("InMod", "FromGame", "inmodd", "Nowhere"), 1):
            events.append("country_event = {\n\tid = %d\n\tis_triggered_only = yes\n"
                          "\tpicture = \"%s\"\n\toption = { name = \"OK\" }\n}\n"
                          % (number, picture))
        cls.mod.write("events/pictures.txt", "".join(events))
        cls.mod.write("gfx/pictures/events/InMod.tga", "")
        cls.game = os.path.join(cls.mod.root, "game")
        for rel in ("hoi3_tfh.exe", "gfx/pictures/events/FromGame.tga"):
            cls.mod.write("game/" + rel, "")
        os.makedirs(os.path.join(cls.game, "common"))

    @classmethod
    def tearDownClass(cls):
        cls.mod.close()

    def missing(self, game):
        result = runner.run(self.mod.root, [rules.REFERENCES], workers=1, game=game)
        found = {d.message: d.hint for d in result.diagnostics if d.rule == "BV212"}
        return found, result.notes

    def test_pictures_in_the_mod_and_the_game_are_found(self):
        found, notes = self.missing(self.game)
        self.assertEqual(sorted(found), ["Event picture `Nowhere` not found",
                                         "Event picture `inmodd` not found"])
        self.assertEqual(found["Event picture `inmodd` not found"], "Did you mean `InMod`?")
        self.assertFalse(any("BV212" in note for note in notes))

    def test_without_the_game_nothing_is_checked_and_the_run_says_so(self):
        found, notes = self.missing(os.path.join(self.mod.root, "no-game-here"))
        self.assertEqual(found, {})
        self.assertTrue(any("Event pictures were not checked (BV212)" in n for n in notes))


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
