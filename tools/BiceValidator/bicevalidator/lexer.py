"""Bytes to tokens, for the Paradox script language.

The whole syntax is `key = value`, where a value is a word, a quoted string or a block in
braces, and `#` comments to the end of the line (docs/script/README.md). Files are
Windows-1252. Every token keeps its line and column, because a finding that does not say
where it is is the thing this tool exists to replace.
"""

import re
from dataclasses import dataclass

OPEN, CLOSE, OP, WORD, STRING = "{", "}", "op", "word", "string"


class Token:
    """One token. A plain slotted class: a run makes some millions of them, and a dataclass
    costs noticeably more to build."""
    __slots__ = ("kind", "text", "line", "col", "end_line")

    def __init__(self, kind, text, line, col, end_line=0):
        self.kind = kind
        self.text = text
        self.line = line
        self.col = col
        self.end_line = end_line    # a quoted string can run over several lines

    def __repr__(self):
        return "Token(%s %r @%d:%d)" % (self.kind, self.text, self.line, self.col)


@dataclass
class Source:
    """A file's text and what reading it found."""
    path: str           # relative, forward slashes
    text: str
    lines: list
    encoding_issues: list   # (line, col, description)
    bom: bool = False
    utf8: bool = False      # valid UTF-8 with non-ASCII bytes: saved by a UTF-8 editor


_CP1252_UNDEFINED = {0x81, 0x8D, 0x8F, 0x90, 0x9D}


def decode(path, data):
    """Windows-1252 text from \\p data, noting what a UTF-8 editor would have left behind."""
    issues = []
    bom = data.startswith(b"\xef\xbb\xbf")
    if bom:
        data = data[3:]
    utf8 = False
    if not data.isascii():
        try:
            data.decode("utf-8")
            # ASCII-only files decode as both; only non-ASCII ones that are valid UTF-8 are
            # suspicious, since real Windows-1252 text almost never happens to be valid UTF-8.
            utf8 = True
        except UnicodeDecodeError:
            pass
    try:
        text = data.decode("cp1252")
    except UnicodeDecodeError:
        # One of the five undefined bytes. Rare, so find them the slow way.
        for index, b in enumerate(data):
            if b in _CP1252_UNDEFINED:
                line = data.count(b"\n", 0, index) + 1
                col = index - (data.rfind(b"\n", 0, index) + 1) + 1
                issues.append((line, col, "byte 0x%02X has no Windows-1252 character" % b))
        text = data.decode("cp1252", errors="replace")
    return Source(path, text, text.split("\n"), issues, bom, utf8)


def read(root, relpath):
    import os
    with open(os.path.join(root, relpath), "rb") as handle:
        return decode(relpath.replace("\\", "/"), handle.read())


# Whitespace is not matched at all - finditer steps over it - and line numbers are found by
# counting newlines between tokens, which keeps the loop to one pass per real token. The
# province history files alone are 18,000 files, so this loop is most of a run's time.
_TOKEN = re.compile(r'(#[^\n]*)|([{}])|([<>]=?|=)|("[^"]*"?)|([^\s{}=<>"#]+)')
_KIND = {2: None, 3: OP, 4: STRING, 5: WORD}


def tokenize(text):
    """The tokens of \\p text, and the strings that never closed.

    Returns (tokens, unterminated) where unterminated is the opening token of a quoted
    string that ran to the end of the file.
    """
    tokens = []
    append = tokens.append
    count, rfind = text.count, text.rfind
    unterminated = None
    line, line_start, pos = 1, 0, 0
    for match in _TOKEN.finditer(text):
        group = match.lastindex
        start = match.start()
        newlines = count("\n", pos, start)
        if newlines:
            line += newlines
            line_start = rfind("\n", pos, start) + 1
        pos = match.end()
        if group == 1:
            continue
        raw = match.group()
        if group == 4:
            col = start - line_start + 1
            start_line = line
            inside = raw.count("\n")
            if inside:
                line += inside
                line_start = start + raw.rfind("\n") + 1
            closed = len(raw) > 1 and raw[-1] == '"'
            token = Token(STRING, raw[1:-1] if closed else raw[1:], start_line, col, line)
            append(token)
            if not closed:
                unterminated = token
            continue
        append(Token(raw if group == 2 else _KIND[group], raw, line, start - line_start + 1, line))
    return tokens, unterminated
