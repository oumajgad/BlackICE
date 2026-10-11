"""The language server, driven over JSON-RPC the way VS Code drives it.

Runs the server from source; set BICEVALIDATOR_LSP to a bicevalidator-lsp.exe to try the
bundled one instead. Skipped where pygls is not installed.
"""

import os
import sys
import unittest

try:
    import pygls  # noqa: F401
except ImportError:
    pygls = None

from .helpers import TOOL, TinyMod, dedent
from .lspclient import LspClient

BROKEN = dedent("""
    country_event = {
        id = 1
        is_triggered_only = yes
        option = {
            name = A
            infanty_brigade = 1
            country_event = 99
        }
    }
    """)

FIXED = BROKEN.replace("infanty_brigade", "infantry_brigade")


def uri_of(path):
    from pygls.uris import from_fs_path
    return from_fs_path(path)


@unittest.skipIf(pygls is None, "pygls is not installed")
class LanguageServerTest(unittest.TestCase):
    def setUp(self):
        self.mod = TinyMod()
        self.mod.write("events/a.txt", BROKEN)
        self.path = os.path.join(self.mod.root, "events", "a.txt")
        self.uri = uri_of(self.path)
        exe = os.environ.get("BICEVALIDATOR_LSP")
        command = [exe] if exe else [sys.executable, os.path.join(TOOL, "BiceValidatorLsp.py")]
        self.client = LspClient(command)
        self.client.start(uri_of(self.mod.root))

    def tearDown(self):
        self.client.stop()
        self.mod.close()

    def open(self, text, version=1):
        self.client.notify("textDocument/didOpen", {"textDocument": {
            "uri": self.uri, "languageId": "blackice-script", "version": version, "text": text}})

    def change(self, text, version):
        self.client.notify("textDocument/didChange", {
            "textDocument": {"uri": self.uri, "version": version},
            "contentChanges": [{"text": text}]})

    @staticmethod
    def codes(diagnostics):
        return sorted(d["code"] for d in diagnostics)

    def test_findings_follow_the_text(self):
        self.open(BROKEN)
        found = self.client.wait_for(self.uri, lambda ds: "BV101" in self.codes(ds))
        unknown = next(d for d in found if d["code"] == "BV101")
        # Line 6, the whole of `infanty_brigade`, and the hint on its own line.
        self.assertEqual(unknown["range"]["start"], {"line": 5, "character": 8})
        self.assertEqual(unknown["range"]["end"], {"line": 5, "character": 23})
        self.assertIn("Did you mean infantry_brigade?", unknown["message"])
        self.assertEqual(unknown["source"], "BICE Validator")

        self.change(FIXED, 2)
        self.client.wait_for(self.uri, lambda ds: "BV101" not in self.codes(ds))

    def test_references_come_from_the_background_run(self):
        self.open(BROKEN)
        found = self.client.wait_for(self.uri, lambda ds: "BV201" in self.codes(ds))
        self.assertIn("Event 99 does not exist", next(
            d["message"] for d in found if d["code"] == "BV201"))

    def test_settings_hide_rules(self):
        self.client.settings = {"disabledRules": ["BV101"], "references": "off"}
        self.client.notify("workspace/didChangeConfiguration", {"settings": None})
        self.open(BROKEN)
        found = self.client.wait_for(self.uri, lambda ds: True)
        self.assertEqual(self.codes(found), [])

    def test_closing_clears_the_file(self):
        self.open(BROKEN)
        self.client.wait_for(self.uri, lambda ds: "BV101" in self.codes(ds))
        self.client.notify("textDocument/didClose", {"textDocument": {"uri": self.uri}})
        self.client.wait_for(self.uri, lambda ds: ds == [])


if __name__ == "__main__":
    unittest.main()
