"""A mod kept loaded between checks, for an editor that checks one file at a time.

A run reads the keyword pages and every declaration afresh, which is right for a run and
three seconds too slow for every keystroke. A Session reads them once, checks the text of
one file in milliseconds, and reads the declarations again when told a file that declares
things has changed.
"""

import os
import threading

from . import lexer, parser, rules, runner
from .checks.script import ScriptChecker
from .declarations import Declarations
from .schema import Schema, locate_keyword_pages

# Saving a file under one of these can change what the mod declares.
DECLARING = ("common/", "technologies/", "units/", "map/")


class Session:
    def __init__(self, root):
        self.root = root
        # ScriptChecker keeps per-file state while it works, so checks take turns.
        self._lock = threading.Lock()
        self.reload()

    def reload(self):
        """Read the keyword pages and the declarations again."""
        docs, keywords_from = locate_keyword_pages(self.root)
        schema = Schema(docs)
        declarations = Declarations(self.root)
        with self._lock:
            self.keywords_from = keywords_from
            self.schema = schema
            self.declarations = declarations
            self.checker = ScriptChecker(schema, declarations)

    def relpath(self, path):
        """\\p path relative to the mod, with forward slashes; None if it is outside it."""
        rel = os.path.relpath(os.path.abspath(path), self.root)
        if rel.startswith(".."):
            return None
        return rel.replace("\\", "/")

    def is_script(self, rel):
        """Whether a run would check this file at all."""
        if rel is None:
            return False
        folder = rel.split("/", 1)[0]
        for name, pattern in runner.SCRIPT_FOLDERS:
            if folder == name and rel.endswith(pattern[pattern.rfind("."):]):
                if pattern.startswith("**") or rel.count("/") == 1:
                    return True
        return False

    def check_text(self, rel, text):
        """Code-mode findings for \\p text, the current content of \\p rel.

        The editor hands over text it has already decoded. Turning it back into
        Windows-1252 bytes first lets the reader notice what it would on disk - a file
        that is really UTF-8 shows up as such - and keeps every column where it was,
        since each character becomes one byte.
        """
        source = lexer.decode(rel, text.encode("cp1252", errors="replace"))
        parsed = parser.parse(source.text)
        with self._lock:
            return runner.check_file(source, parsed, self.checker, (rules.CODE,))

    def declares(self, rel):
        return rel is not None and rel.startswith(DECLARING)
