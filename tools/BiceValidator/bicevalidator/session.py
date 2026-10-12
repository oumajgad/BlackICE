"""A mod kept loaded between checks, for an editor that checks one file at a time.

A run reads the keyword pages and every declaration afresh, which is right for a run and
three seconds too slow for every keystroke. A Session reads them once, checks the text of
one file in milliseconds, and reads the declarations again when told a file that declares
things has changed.

It also keeps what an editor asks about between checks: the localisation, the event
pictures (pictures.py), and an index of the events, decisions, flags and modifiers
(index.py), with the open files' parts taken from the text being edited.
"""

import os
import threading

from . import index as idx, lexer, parser, rules, runner
from .checks.script import ScriptChecker
from .declarations import Declarations
from .localisation import Localisation
from .navigate import Navigator
from .pictures import Pictures
from .schema import Schema, locate_keyword_pages

# Saving a file under one of these can change what the mod declares.
DECLARING = ("common/", "technologies/", "units/", "map/")


class Session:
    def __init__(self, root):
        self.root = root
        # ScriptChecker keeps per-file state while it works, so checks take turns.
        self._lock = threading.Lock()
        self.reload()
        self.localisation = Localisation(root)
        self.index = idx.ModIndex(root)
        self.pictures = Pictures(root)

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
            self.navigator = Navigator(self)

    def files_changed(self, rels):
        """\\p rels changed on disk: read again whatever this session keeps of them. True
        if the declarations were read again, which can change any file's findings."""
        for rel in rels:
            if rel.startswith("localisation/") and rel.endswith(".csv"):
                self.localisation.reload_file(rel)
            if rel.lower().startswith("gfx/pictures/"):
                self.pictures.forget()
            self.index.reload_file(rel)
        if any(self.declares(rel) for rel in rels):
            self.reload()
            return True
        return False

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
        return self.analyse(rel, text)[0]

    def analyse(self, rel, text):
        """(findings, parse) of \\p text, the current content of \\p rel; the index takes
        the file's part from it."""
        source = lexer.decode(rel, text.encode("cp1252", errors="replace"))
        parsed = parser.parse(source.text)
        with self._lock:
            found = runner.check_file(source, parsed, self.checker, (rules.CODE,))
        self.index.update(rel, parsed.root)
        return found, parsed

    @staticmethod
    def parse(text):
        """The parse of \\p text, for questions asked between checks."""
        return parser.parse(text)

    def declares(self, rel):
        return rel is not None and rel.startswith(DECLARING)
