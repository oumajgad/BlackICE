"""A mod that is not a checkout: no docs/, no tools/ - an installed copy under tfh/mod."""

import os
import shutil
import tempfile
import unittest
from unittest import mock

from bicevalidator import config, rules, runner, schema

from .helpers import DOCS, TinyMod


class BareModTest(unittest.TestCase):
    def setUp(self):
        self.mod = TinyMod()
        shutil.rmtree(os.path.join(self.mod.root, "docs"))
        self.mod.write("events/a.txt", "country_event = { id = 1 is_triggered_only = yes "
                                       "option = { name = A dissent = 1 } }\n")

    def tearDown(self):
        self.mod.close()

    def test_found_without_docs(self):
        inner = os.path.join(self.mod.root, "events")
        self.assertEqual(runner.find_mod_root(inner), self.mod.root)

    def test_keyword_pages_fall_back(self):
        # Run from source, the pages come from the checkout the tool sits in.
        folder, source = schema.locate_keyword_pages(self.mod.root)
        self.assertEqual(os.path.normcase(folder), os.path.normcase(DOCS))
        self.assertIn("docs/script of", source)
        result = runner.run(self.mod.root, [rules.CODE], workers=1)
        self.assertEqual(result.diagnostics, [])

    def test_bundled_pages_win_over_the_tool_checkout(self):
        bundle = tempfile.mkdtemp(prefix="bicevalidator-bundle-")
        try:
            shutil.copytree(DOCS, os.path.join(bundle, schema.BUNDLED_FOLDER))
            with mock.patch("sys._MEIPASS", bundle, create=True):
                _, source = schema.locate_keyword_pages(self.mod.root)
            self.assertTrue(source.startswith("built into the exe"))
        finally:
            shutil.rmtree(bundle, ignore_errors=True)

    def test_own_pages_win_over_everything(self):
        shutil.copytree(DOCS, os.path.join(self.mod.root, "docs", "script"))
        with mock.patch("sys._MEIPASS", "nowhere", create=True):
            _, source = schema.locate_keyword_pages(self.mod.root)
        self.assertEqual(source, "docs/script")

    def test_settings_go_to_the_user_profile(self):
        profile = tempfile.mkdtemp(prefix="bicevalidator-profile-")
        try:
            with mock.patch.dict(os.environ, {"APPDATA": profile}):
                path = config.path_for(self.mod.root)
            self.assertTrue(path.startswith(profile))
            self.assertFalse(path.startswith(self.mod.root))
        finally:
            shutil.rmtree(profile, ignore_errors=True)

    def test_settings_stay_in_a_checkout(self):
        os.makedirs(os.path.join(self.mod.root, "tools", "BiceValidator"))
        self.assertEqual(config.path_for(self.mod.root),
                         os.path.join(self.mod.root, "tools", "BiceValidator", "validator.json"))


if __name__ == "__main__":
    unittest.main()
