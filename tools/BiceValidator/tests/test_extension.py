"""The VS Code extension's manifest agrees with the library it fronts."""

import json
import os
import unittest

from bicevalidator import rules

from .helpers import TOOL

PACKAGE = os.path.join(TOOL, "vscode", "package.json")


class ManifestTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(PACKAGE, encoding="utf-8") as handle:
            cls.package = json.load(handle)
        cls.properties = cls.package["contributes"]["configuration"]["properties"]

    def test_rule_list_is_in_step(self):
        # vscode/build.py writes this list from rules.py; a rule added since the last
        # build would be missing from the setting.
        items = self.properties["blackice.validator.disabledRules"]["items"]
        self.assertEqual(items["enum"], list(rules.RULES))
        self.assertEqual(len(items["enumDescriptions"]), len(rules.RULES))

    def test_severities_match(self):
        self.assertEqual(self.properties["blackice.validator.minimumSeverity"]["enum"],
                         list(rules.SEVERITIES))

    def test_every_setting_is_read_by_the_server(self):
        from bicevalidator_lsp import server  # noqa: F401  - needs pygls
        import inspect
        source = inspect.getsource(server.Settings.from_client)
        for key in self.properties:
            name = key.rsplit(".", 1)[1]
            if name == "serverCommand":
                continue            # read by the extension, not the server
            self.assertIn('"%s"' % name, source, "the server ignores %s" % key)


if __name__ == "__main__":
    unittest.main()
