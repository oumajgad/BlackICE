"""What an editor is told about a place in a file: hover, definitions, references, the
outline, completion and the titles of fired events."""

import unittest

from bicevalidator.session import Session

from .helpers import TinyMod, dedent

EVENTS = dedent("""
    country_event = {
    	id = 1
    	is_triggered_only = yes
    	title = EVTNAME1
    	desc = EVTDESC1
    	option = {
    		name = A
    		country_event = 2
    		set_country_flag = my_flag
    		add_country_modifier = { name = real_modifier duration = 30 }
    		GER = { load_oob = real_oob.txt }
    	}
    }
    # two lines
    # of comment
    country_event = {
    	id = 2
    	is_triggered_only = yes
    	title = "Second"
    	option = {
    		name = B
    	}
    }
    """)

DECISIONS = dedent("""
    political_decisions = {
    	my_decision = {
    		potential = { has_country_flag = my_flag }
    		effect = { country_event = 1 }
    	}
    }
    """)


def place(text, needle, offset=0, nth=0):
    """(line, column), 1-based, of the \\p nth \\p needle in \\p text, plus \\p offset."""
    found = -1
    for number, line in enumerate(text.split("\n"), 1):
        start = line.find(needle)
        while start >= 0:
            found += 1
            if found == nth:
                return number, start + 1 + offset
            start = line.find(needle, start + 1)
    raise KeyError(needle)


class NavigateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = TinyMod()
        cls.mod.write("events/a.txt", EVENTS)
        cls.mod.write("decisions/d.txt", DECISIONS)
        cls.mod.write("localisation/names.csv", "GER;Germany;;;;;;;;;;;;;x\n"
                                                "my_decision_title;My decision;;;;;;;;;;;;;x\n")
        cls.session = Session(cls.mod.root)
        cls.nav = cls.session.navigator
        cls.parsed = cls.session.parse(EVENTS)

    @classmethod
    def tearDownClass(cls):
        cls.mod.close()

    def target(self, needle, offset=0, nth=0, text=EVENTS, rel="events/a.txt"):
        parsed = self.parsed if text is EVENTS else self.session.parse(text)
        return self.nav.target(rel, parsed, *place(text, needle, offset, nth))

    def test_a_fired_event_shows_its_title_and_where_it_is(self):
        target = self.target("country_event = 2", 16)
        self.assertEqual((target.what, target.name), ("event", "2"))
        self.assertIn("Second", self.nav.hover(target))
        [where] = self.nav.definitions(target)
        self.assertEqual((where.file, where.line), ("events/a.txt", 17))

    def test_an_event_is_referenced_from_where_it_is_fired(self):
        target = self.target("id = 1", 5)
        places = self.nav.references(target)
        self.assertEqual(sorted((p.file, p.line) for p in places),
                         [("decisions/d.txt", 4), ("events/a.txt", 2)])
        self.assertEqual(len(self.nav.references(target, include_declaration=False)), 1)

    def test_a_flag_is_found_where_it_is_set_and_tested(self):
        target = self.target("my_flag")
        self.assertEqual((target.what, target.kind), ("flag", "country"))
        places = self.nav.references(target)
        self.assertEqual(sorted((p.file, p.line) for p in places),
                         [("decisions/d.txt", 3), ("events/a.txt", 9)])
        self.assertIn("Set 1 time and tested 1 time", self.nav.hover(target))
        [where] = self.nav.definitions(target)
        self.assertEqual(where.file, "events/a.txt")

    def test_names_resolve_to_their_declarations(self):
        modifier = self.target("real_modifier")
        self.assertEqual(modifier.what, "modifier")
        self.assertIn("global_ic = 0.1", self.nav.hover(modifier))
        self.assertEqual(self.nav.definitions(modifier)[0].file, "common/event_modifiers.txt")
        tag = self.target("GER")
        self.assertEqual(tag.what, "tag")
        self.assertIn("Germany", self.nav.hover(tag))
        oob = self.target("real_oob.txt")
        self.assertEqual(self.nav.definitions(oob)[0].file, "history/units/real_oob.txt")
        loc = self.target("EVTDESC1")
        self.assertIn("Text", self.nav.hover(loc))

    def test_a_keyword_shows_its_page(self):
        target = self.target("set_country_flag")
        self.assertEqual(target.what, "keyword")
        self.assertIn("effect", self.nav.hover(target))
        self.assertTrue(self.nav.definitions(target)[0].file.endswith("effects.md"))

    def test_the_outline_lists_events_by_id_and_title(self):
        outline = self.nav.outline("events/a.txt", self.parsed)
        self.assertEqual([s.name for s in outline], ["1 Title", "2 Second"])
        self.assertEqual([c.name for c in outline[0].children], ["A"])
        decisions = self.nav.outline("decisions/d.txt", self.session.parse(DECISIONS))
        self.assertEqual(decisions[0].children[0].detail, "My decision")
        names = [s.name for s in self.nav.symbols("second")]
        self.assertEqual(names, ["2 Second"])

    def test_fired_events_get_their_titles_at_the_end_of_the_line(self):
        titles = self.nav.event_titles(self.parsed, 1, 100)
        self.assertEqual(titles, [(8, 20, "Second")])

    def test_completion_knows_the_block_it_is_in(self):
        text = EVENTS.replace("\t\tname = B\n", "\t\tname = B\n\t\tad\n\t\tlimit = { ha }\n")
        parsed = self.session.parse(text)
        line, col = place(text, "\t\tad", 4)
        items, _ = self.nav.completions("events/a.txt", parsed, line, col)
        labels = {i.label for i in items}
        self.assertIn("add_country_modifier", labels)
        self.assertNotIn("has_country_flag", labels)
        line, col = place(text, "{ ha }", 4)
        items, _ = self.nav.completions("events/a.txt", parsed, line, col)
        labels = {i.label for i in items}
        self.assertIn("has_country_flag", labels)
        self.assertNotIn("add_country_modifier", labels)

    def test_completion_offers_values_for_the_key(self):
        text = EVENTS.replace("country_event = 2", "country_event = ")
        parsed = self.session.parse(text)
        line, col = place(text, "country_event = ", 16, nth=0)
        items, _ = self.nav.completions("events/a.txt", parsed, line, col)
        self.assertEqual({i.label for i in items}, {"1", "2"})
        text = EVENTS.replace("set_country_flag = my_flag", "has_country_flag = ")
        parsed = self.session.parse(text)
        line, col = place(text, "has_country_flag = ", 19)
        items, _ = self.nav.completions("events/a.txt", parsed, line, col)
        self.assertEqual([i.label for i in items], ["my_flag"])

    def test_the_next_free_event_id_follows_the_event_above(self):
        self.assertEqual(self.session.index.next_event_id("events/a.txt", 5), 3)
        self.assertEqual(self.session.index.next_event_id("events/new.txt"), 3)

    def test_quick_fixes(self):
        self.assertEqual(self.nav.replacement("BV101", "infanty_brigade"), "infantry_brigade")
        self.assertEqual(self.nav.replacement("BV102", "brigade_exists"), "brigade_exist")
        self.assertIsNone(self.nav.replacement("BV102", "port"))

    def test_folding_follows_the_brackets(self):
        folds = self.nav.folds(self.parsed, EVENTS.split("\n"))
        self.assertIn((1, 12, False), folds)
        self.assertIn((14, 15, True), folds)

    def test_the_index_follows_the_text_being_edited(self):
        session = Session(self.mod.root)
        edited = EVENTS.replace("id = 2", "id = 7")
        session.analyse("events/a.txt", edited)
        self.assertEqual(session.index.events("2"), [])
        self.assertEqual(len(session.index.events("7")), 1)
        session.index.reload_file("events/a.txt")
        self.assertEqual(len(session.index.events("2")), 1)


if __name__ == "__main__":
    unittest.main()
