"""Brackets, quotes, operators and encoding: whether a file can be read at all.

A bracket error is reported where the parser noticed it, which is rarely where it was
made. A lost `option = {` shows up as a `}` with nothing open thirty lines later. So each
bracket finding also carries a hint: the first place, inside the block that went wrong,
where the indentation stops agreeing with the brackets. Indentation is not meaningful to
the game, but every file in the mod is indented by its brackets, so where the two part
company is where a human would look.
"""

from ..diagnostic import Diagnostic, Related
from ..context import describe
from .. import lexer, parser


def _indent(line):
    """Visual width of a line's leading whitespace, or None for a blank line."""
    width = 0
    for c in line:
        if c == "\t":
            width += 4 - width % 4
        elif c == " ":
            width += 1
        else:
            return width
    return None


class _Lines:
    def __init__(self, source):
        self.lines = source.lines

    def indent(self, number):
        if 1 <= number <= len(self.lines):
            return _indent(self.lines[number - 1])
        return None

    def starts_with(self, token):
        """Whether \\p token is the first thing on its line."""
        line = self.lines[token.line - 1] if 1 <= token.line <= len(self.lines) else ""
        return line[:token.col - 1].strip() == ""


def _anomalies(block, lines):
    """Places inside \\p block where indentation and brackets disagree, in file order.

    Two shapes: a block whose `}` sits at a different indentation from the line that
    opened it, and a key indented deeper than the keys before it with no `{` to explain it.
    """
    found = []

    def visit(node):
        if not node.is_block:
            return
        open_indent = lines.indent(node.line) if node.open_tok is not None else None
        close = node.close_tok
        if close is not None and open_indent is not None and lines.starts_with(close) \
                and node.line != close.line:
            close_indent = lines.indent(close.line)
            if close_indent != open_indent:
                found.append((close.line, close.col, node, close_indent > open_indent))
        expected = None
        for child in node.children:
            token = child.key_tok or child.open_tok
            if token is None or not lines.starts_with(token):
                visit(child)
                continue
            width = lines.indent(token.line)
            if expected is None:
                expected = width
            elif width > expected:
                found.append((token.line, token.col, child, None))
                expected = width
            visit(child)

    visit(block)
    found.sort(key=lambda item: (item[0], item[1]))
    return found


def _hint_for(block, lines, source):
    """A hint and a related location for a bracket fault inside \\p block, or (\"\", None)."""
    found = _anomalies(block, lines)
    if not found:
        return "", None
    line, col, node, deeper = found[0]
    text = source.lines[line - 1].strip()
    if deeper is None:
        hint = ("Line %d (`%s`) is indented deeper than the lines before it, but no `{` "
                "opens a block there - a line like `option = {` or `trigger = {` may be "
                "missing just above it." % (line, text))
        return hint, Related("indentation jumps here", source.path, line, col)
    opened = node.line
    if deeper:
        hint = ("The `}` on line %d closes the block opened on line %d, but is indented "
                "like a nested block - a `{` is probably missing between them, so this "
                "`}` is closing the wrong block." % (line, opened))
    else:
        hint = ("The `}` on line %d closes the block opened on line %d, but is indented "
                "like an outer block - a `}` is probably missing before it." % (line, opened))
    return hint, Related("brackets and indentation disagree", source.path, line, col)


def _since_last_clean(root_children, token, lines):
    """The top-level entries between the last well-formed one and the stray `}`.

    A block that closed too early leaves its remaining children at the top of the file,
    so the culprit is usually not the entry just before the `}` but the one that broke
    first. Walk back while entries are indented (top-level entries never are) or show an
    anomaly; the first clean, unindented entry is where the file was last in step.
    """
    before = [c for c in root_children
              if (c.line, c.col) < (token.line, token.col)]
    suspects = []
    for node in reversed(before):
        token0 = node.key_tok or node.open_tok
        indented = token0 is not None and lines.starts_with(token0) \
            and (lines.indent(token0.line) or 0) > 0
        if node.is_block and not indented and not _anomalies(node, lines) and suspects:
            break
        suspects.append(node)
        if not indented and node.is_block and not _anomalies(node, lines):
            break
    return list(reversed(suspects))


def _hint_for_many(nodes, lines, source):
    for node in nodes:
        token = node.key_tok or node.open_tok
        if token is not None and lines.starts_with(token) and (lines.indent(token.line) or 0) > 0:
            # An indented entry at the top of the file is a child cut loose from the block
            # above; the anomaly inside that block, if any, is the better pointer.
            continue
        hint, where = _hint_for(node, lines, source)
        if where is not None:
            return hint, where
    first = nodes[0]
    return ("`%s` on line %d is the first entry after the last well-formed one; the fault "
            "is between it and this bracket." % (first.key or "{", first.line),
            Related("first entry out of step", source.path, first.line, first.col))


def check(source, result):
    out = []
    path = source.path
    lines = _Lines(source)

    if source.bom:
        out.append(Diagnostic("BV008", path, 1, 1,
                              "File starts with a UTF-8 byte order mark"))
    if source.utf8:
        first = next((i for i, l in enumerate(source.lines, 1)
                      if any(ord(c) >= 0x80 for c in l)), 1)
        out.append(Diagnostic("BV007", path, first, 1,
                              "File is saved as UTF-8; the game reads Windows-1252",
                              hint="First non-ASCII text is on line %d: %s"
                                   % (first, source.lines[first - 1].strip()[:80])))
    for line, col, text in source.encoding_issues:
        out.append(Diagnostic("BV009", path, line, col, text.capitalize()))

    root_children = result.root.children
    for token in result.extra_closers:
        suspects = _since_last_clean(root_children, token, lines)
        hint, related = "", []
        context = ""
        if suspects:
            block = suspects[0]
            context = describe(block)
            hint, where = _hint_for_many(suspects, lines, source)
            related = [Related("first block that went wrong", path, block.line, block.col)]
            if where is not None:
                related.insert(0, where)
        message = "Closing bracket with nothing open"
        if context:
            message += " (after %s)" % context
        out.append(Diagnostic("BV001", path, token.line, token.col, message,
                              context=context, hint=hint, related=related))

    for index, block in enumerate(result.unclosed):
        hint, where = ("", None)
        if index == 0:
            hint, where = _hint_for(block, lines, source)
        related = [where] if where is not None else []
        out.append(Diagnostic("BV002", path, block.line, block.col,
                              "`%s` is never closed" % (block.key or "{"),
                              context=describe(block), hint=hint, related=related))

    if result.unterminated is not None:
        token = result.unterminated
        out.append(Diagnostic("BV003", path, token.line, token.col,
                              "Quoted text is never closed"))

    for node in result.missing_values:
        follower = node.value_tok
        if follower is not None and follower.line == node.line:
            # `type = militia_brigade = "Komsomolskiy B-n"`: a key lost between two values.
            message = ("`%s = %s` is followed by another `=`: a key is missing before it"
                       % (node.key, follower.text))
            hint = ("The game reads `%s = %s` and then finds an `=` with no key, so what "
                    "follows it is lost. Usually a `name` or similar went missing."
                    % (node.key, follower.text))
        elif follower is not None:
            message = "`%s =` has no value on its line" % node.key
            hint = ("The game takes the next word, `%s` on line %d, as the value, so that "
                    "line's own setting is lost." % (follower.text, follower.line))
        else:
            message, hint = "`%s =` has no value" % node.key, ""
        out.append(Diagnostic("BV004", path, node.line, node.col, message,
                              context=describe(node), hint=hint))

    for token in result.stray_ops:
        out.append(Diagnostic("BV005", path, token.line, token.col,
                              "`%s` with no key before it" % token.text))

    for token in result.tokens:
        if token.kind == lexer.STRING and token.end_line > token.line \
                and ("=" in token.text or "{" in token.text):
            out.append(Diagnostic("BV006", path, token.line, token.col,
                                  "Quoted text runs from line %d to %d and contains script"
                                  % (token.line, token.end_line),
                                  related=[Related("text ends here", path, token.end_line)]))

    # Events and decisions get the stricter BV113 from the script check instead.
    script_file = path.startswith(("events/", "decisions/"))
    for node in ([] if script_file else parser.walk(result.root)):
        if node.is_block and node.children:
            pairs = [c for c in node.children if c.op is not None or c.key is None]
            bare = [c for c in node.children if c.op is None and c.key is not None]
            if pairs and bare:
                for item in bare:
                    out.append(Diagnostic("BV010", path, item.line, item.col,
                                          "Bare `%s` among `key = value` pairs" % item.key,
                                          context=describe(node)))
    return out
