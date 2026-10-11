import unittest

from bicevalidator import lexer, parser
from bicevalidator.checks import syntax

from .helpers import dedent


def source(text, path="events/test.txt", encoding="cp1252"):
    return lexer.decode(path, text.encode(encoding))


def check(text, path="events/test.txt"):
    src = source(text, path)
    return syntax.check(src, parser.parse(src.text))


class LexerTest(unittest.TestCase):
    def test_positions(self):
        tokens, _ = lexer.tokenize('a = b # c = d\n\tkey = "two words"\n')
        self.assertEqual([(t.text, t.line, t.col) for t in tokens],
                         [("a", 1, 1), ("=", 1, 3), ("b", 1, 5),
                          ("key", 2, 2), ("=", 2, 6), ("two words", 2, 8)])

    def test_string_over_lines_keeps_counting(self):
        tokens, unterminated = lexer.tokenize('desc = "one\ntwo"\nnext = 1')
        self.assertIsNone(unterminated)
        self.assertEqual((tokens[2].line, tokens[2].end_line), (1, 2))
        self.assertEqual((tokens[3].text, tokens[3].line), ("next", 3))

    def test_unterminated_string(self):
        _, unterminated = lexer.tokenize('title = "never closed\nid = 5\n')
        self.assertEqual(unterminated.line, 1)

    def test_windows_1252(self):
        src = source("title = \"Göring\"\n")
        self.assertIn("Göring", src.text)
        self.assertFalse(src.utf8)

    def test_utf8_file_is_noticed(self):
        src = source("title = \"Göring\"\n", encoding="utf-8")
        self.assertTrue(src.utf8)

    def test_bom_is_noticed(self):
        src = lexer.decode("x.txt", b"\xef\xbb\xbfa = b\n")
        self.assertTrue(src.bom)
        self.assertEqual(src.text, "a = b\n")


class ParserTest(unittest.TestCase):
    def test_shapes(self):
        root = parser.parse("a = b\nc = { 0 0 1 }\nd = { e = f }\n{ 1 }\n").root
        a, c, d, anon = root.children
        self.assertTrue(a.is_pair and a.value == "b")
        self.assertEqual([n.key for n in c.children], ["0", "0", "1"])
        self.assertIsNone(c.children[0].op)
        self.assertEqual(d.child("E").value, "f")
        self.assertIsNone(anon.key)

    def test_extra_closer_and_unclosed(self):
        result = parser.parse("a = { b = c } }\nd = {\n")
        self.assertEqual([t.line for t in result.extra_closers], [1])
        self.assertEqual([n.key for n in result.unclosed], ["d"])

    def test_missing_value(self):
        result = parser.parse("points = \nindustry = 5\n")
        self.assertEqual([n.key for n in result.missing_values], ["points"])
        self.assertEqual(result.root.children[1].key, "industry")


class SyntaxTest(unittest.TestCase):
    # The fault that started this tool: an event that lost `picture` and `option = {`,
    # so the option's `}` closed the event and the event's own `}` was left over.
    LOST_OPTION = dedent("""
        country_event = {
        \tid = 1
        \ttitle = "A"
        \toption = {
        \t\tname = "Fine"
        \t}
        }
        country_event = {
        \tid = 2
        \ttitle = "B"
        \t\tname = "Give Permission"
        \t\tmetal = -3500
        \t}
        \toption = {
        \t\tname = "No"
        \t}
        }
        """)

    def test_lost_option_points_at_the_indentation_jump(self):
        found = [d for d in check(self.LOST_OPTION) if d.rule == "BV001"]
        self.assertEqual(len(found), 1)
        d = found[0]
        self.assertEqual(d.line, 17)
        self.assertEqual(d.context, "country_event 2")
        self.assertEqual(d.related[0].line, 11)
        self.assertIn("option = {", d.hint)

    def test_lost_closer_points_at_the_misplaced_bracket(self):
        text = dedent("""
            country_event = {
            \tid = 1
            \toption = {
            \t\tname = "A"
            \toption = {
            \t\tname = "B"
            \t}
            }
            """)
        found = [d for d in check(text) if d.rule == "BV002"]
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0].line, 1)
        self.assertEqual(found[0].related[0].line, 8)

    def test_double_equals(self):
        found = check("regiment = { type = militia_brigade = \"Komsomolskiy\" }\n",
                      "history/units/x.txt")
        self.assertEqual([d.rule for d in found], ["BV004"])
        self.assertIn("another `=`", found[0].message)

    def test_value_on_the_next_line(self):
        found = check("points = \nindustry = 5\n", "history/provinces/x.txt")
        self.assertEqual(found[0].rule, "BV004")
        self.assertIn("industry", found[0].hint)

    def test_clean_file(self):
        self.assertEqual(check('a = { b = "c d" e = { 1 2 } }\n'), [])

    def test_string_with_script_inside(self):
        found = check('desc = "runs on\nid = 5 {"\n')
        self.assertEqual([d.rule for d in found], ["BV006"])


if __name__ == "__main__":
    unittest.main()
