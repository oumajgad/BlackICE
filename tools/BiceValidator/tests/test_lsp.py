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

    def test_a_cancelled_request_does_not_stop_the_mod_loading(self):
        # VS Code cancels requests it no longer needs, often while the mod is still being
        # read. That once cancelled the reading itself, and nothing worked afterwards.
        self.open(TWO_EVENTS)
        ident = self.client.send_request("textDocument/documentSymbol",
                                         {"textDocument": {"uri": self.uri}})
        self.client.notify("$/cancelRequest", {"id": ident})
        self.client.wait_for(self.uri, lambda ds: "BV101" in self.codes(ds))
        symbols = self.client.request("textDocument/documentSymbol", {
            "textDocument": {"uri": self.uri}})["result"]
        self.assertEqual([s["name"] for s in symbols], ["1 Title", "2 Second"])

    def ask(self, method, line, character, **extra):
        params = {"textDocument": {"uri": self.uri},
                  "position": {"line": line, "character": character}}
        params.update(extra)
        return self.client.request(method, params)["result"]

    def test_reading_the_mod_from_the_editor(self):
        self.open(TWO_EVENTS)
        found = self.client.wait_for(self.uri, lambda ds: "BV101" in self.codes(ds))

        # Line 8 is `country_event = 2`, in the first event's option.
        hover = self.ask("textDocument/hover", 7, 25)
        self.assertIn("Second", hover["contents"]["value"])
        [where] = self.ask("textDocument/definition", 7, 25)
        self.assertEqual(where["uri"], self.uri)
        self.assertEqual(where["range"]["start"]["line"], 11)
        places = self.ask("textDocument/references", 11, 10,
                          context={"includeDeclaration": True})
        self.assertEqual(sorted(p["range"]["start"]["line"] for p in places), [7, 11])

        symbols = self.client.request("textDocument/documentSymbol", {
            "textDocument": {"uri": self.uri}})["result"]
        self.assertEqual([s["name"] for s in symbols], ["1 Title", "2 Second"])

        hints = self.client.request("textDocument/inlayHint", {
            "textDocument": {"uri": self.uri},
            "range": {"start": {"line": 0, "character": 0},
                      "end": {"line": 20, "character": 0}}})["result"]
        self.assertEqual([(h["position"]["line"], h["label"]) for h in hints], [(7, "Second")])

        completion = self.ask("textDocument/completion", 7, 24)
        self.assertIn("2", [item["label"] for item in completion["items"]])

        actions = self.client.request("textDocument/codeAction", {
            "textDocument": {"uri": self.uri}, "range": found[0]["range"],
            "context": {"diagnostics": [d for d in found if d["code"] in ("BV101", "BV113")]},
        })["result"]
        edits = sorted(a["edit"]["changes"][self.uri][0]["newText"] for a in actions)
        self.assertEqual(edits, [" =", "infantry_brigade"])

        ident = self.client.request("workspace/executeCommand", {
            "command": "blackice.nextEventId", "arguments": [self.uri, 0]})["result"]
        self.assertEqual(ident, 3)


TWO_EVENTS = dedent("""
    country_event = {
        id = 1
        is_triggered_only = yes
        title = EVTNAME1
        option = {
            name = A
            infanty_brigade = 1
            country_event = 2
        }
    }
    country_event = {
        id = 2
        is_triggered_only = yes
        title = "Second"
        option = {
            name = B
            ai_chance = { factor 100 }
        }
    }
    """)


if __name__ == "__main__":
    unittest.main()
