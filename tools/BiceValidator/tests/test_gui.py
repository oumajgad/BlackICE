"""The window, driven without a screen. Skipped where PySide6 is not installed."""

import os
import shutil
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

try:
    from PySide6.QtCore import Qt
    from PySide6.QtWidgets import QApplication
except ImportError:
    QApplication = None

from bicevalidator.baseline import Baseline
from bicevalidator.config import Config
from bicevalidator.diagnostic import Diagnostic
from bicevalidator.runner import Result


@unittest.skipIf(QApplication is None, "PySide6 is not installed")
class RuleListTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        from bicevalidator_gui.app import MainWindow
        self.folder = tempfile.mkdtemp(prefix="bicevalidator-gui-")
        self.window = MainWindow()
        self.window.persist = False
        # Its own settings files, so the test never writes the repository's.
        self.window.config = Config(path=os.path.join(self.folder, "validator.json"))
        self.window.baseline = Baseline(os.path.join(self.folder, "baseline.json"))
        self.window.result = Result(self.folder, {"code", "references"}, diagnostics=[
            Diagnostic("BV201", "events/a.txt", 3, 1, "Event 9 does not exist", "ev 1"),
            Diagnostic("BV101", "events/a.txt", 5, 1, "`x` is not", "ev 1"),
        ])
        self.window._reclassify()

    def tearDown(self):
        self.window.close()
        shutil.rmtree(self.folder, ignore_errors=True)

    def settle(self):
        for _ in range(3):
            self.app.processEvents()

    def test_ticking_the_selected_rule(self):
        # This crashed the window: ticking rebuilt the list while Qt was still handling
        # the selected row's change.
        node = self.window.rule_items["BV201"]
        self.window.rule_tree.setCurrentItem(node)
        self.settle()
        for _ in range(3):
            node.setCheckState(0, Qt.Unchecked)
            self.settle()
            self.assertEqual(self.window.config.hidden_rules, {"BV201"})
            self.assertEqual(sum(1 for i in self.window.model.items if i.hidden), 1)
            node.setCheckState(0, Qt.Checked)
            self.settle()
            self.assertEqual(self.window.config.hidden_rules, set())
        self.assertIs(self.window.rule_items["BV201"], node)

    def test_counts_update_in_place(self):
        self.assertEqual(self.window.rule_items["BV201"].text(1), "1")
        self.assertEqual(self.window.all_rules_item.text(1), "2")


if __name__ == "__main__":
    unittest.main()
