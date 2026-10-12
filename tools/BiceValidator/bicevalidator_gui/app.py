"""The main window: what to run on the top, filters on the left, results and details beside."""

import csv
import os
import shutil
import subprocess
import sys

from PySide6.QtCore import QObject, QSettings, Qt, QThread, QTimer, Signal, Slot
from PySide6.QtGui import QAction, QKeySequence
from PySide6.QtWidgets import (QAbstractItemView, QApplication, QCheckBox, QComboBox,
                               QFileDialog, QGroupBox, QHBoxLayout, QHeaderView, QLabel,
                               QLineEdit, QMainWindow, QMessageBox, QProgressBar, QPushButton,
                               QSplitter, QTableView, QTreeWidget, QTreeWidgetItem, QVBoxLayout,
                               QWidget)

from bicevalidator import __version__, review, rules, runner
from bicevalidator.baseline import Baseline
from bicevalidator.config import Config
from bicevalidator.pictures import find_game, is_game

from .details import DetailsPane
from .model import ResultsFilter, ResultsModel, severity_icon

ALL_RULES = "(all rules)"


class RunWorker(QObject):
    progress = Signal(int, int, str)
    finished = Signal(object)
    failed = Signal(str)

    def __init__(self, root, modes, only, game=None):
        super().__init__()
        self.root, self.modes, self.only, self.game = root, modes, only, game

    @Slot()
    def run(self):
        try:
            result = runner.run(self.root, self.modes, only=self.only, game=self.game,
                                progress=lambda d, t, m: self.progress.emit(d, t, m))
            self.finished.emit(result)
        except Exception as error:     # shown to the user rather than lost in a thread
            import traceback
            self.failed.emit("%s\n\n%s" % (error, traceback.format_exc()))


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("BICE Validator %s" % __version__)
        self.settings = QSettings("BlackICE", "BICE Validator")
        # Both belong to the mod checkout and are loaded when one is chosen (set_mod).
        self.config = Config(path="")
        self.baseline = None
        self.result = None
        self.full_run = False
        self.thread = None
        # Off for the smoke test, which must not leave its test folder as the one the
        # window remembers.
        self.persist = True
        # Notes already shown this session; the same note after every run is noise.
        self.shown_notes = set()

        self.model = ResultsModel(self)
        self.filter = ResultsFilter(self)
        self.filter.setSourceModel(self.model)

        self._build_top()
        self._build_filters()
        self._build_results()
        self.details = DetailsPane()
        self.details.open_requested.connect(self.open_in_editor)
        self.details.known_toggled.connect(self.toggle_known)
        self.details.hide_rule_requested.connect(lambda r: self.set_rule_hidden(r, True))
        self.details.splitter.setOrientation(Qt.Horizontal)

        right = QSplitter(Qt.Vertical)
        right.addWidget(self.table)
        right.addWidget(self.details)
        right.setStretchFactor(0, 3)
        right.setStretchFactor(1, 2)
        self.right_splitter = right

        main = QSplitter(Qt.Horizontal)
        main.addWidget(self.filters)
        main.addWidget(right)
        main.setStretchFactor(0, 0)
        main.setStretchFactor(1, 1)
        main.setSizes([400, 1100])
        self.main_splitter = main

        central = QWidget()
        layout = QVBoxLayout(central)
        layout.setContentsMargins(6, 6, 6, 6)
        layout.addWidget(self.top)
        layout.addWidget(main, 1)
        self.setCentralWidget(central)
        self._build_menu()
        self.statusBar().showMessage("Ready. Press Run (F5).")
        self._restore()

    # --- layout ------------------------------------------------------------------------

    def _build_top(self):
        self.top = QWidget()
        row = QHBoxLayout(self.top)
        row.setContentsMargins(0, 0, 0, 0)
        row.addWidget(QLabel("Mod:"))
        self.mod_edit = QLineEdit()
        self.mod_edit.setReadOnly(True)
        row.addWidget(self.mod_edit, 1)
        browse = QPushButton("Browse...")
        browse.clicked.connect(self.choose_mod)
        row.addWidget(browse)
        row.addSpacing(16)
        self.code_box = QCheckBox("Code")
        self.code_box.setToolTip("Brackets, encoding, keywords and where they stand: "
                                 "whether each file is valid script on its own")
        self.refs_box = QCheckBox("References")
        self.refs_box.setToolTip("Events, tags, provinces, modifiers, flags, localisation and "
                                 "OOB files: whether what a file names exists")
        self.changed_box = QCheckBox("Changed files only")
        self.changed_box.setToolTip("Report only on files git sees as modified or new")
        for box in (self.code_box, self.refs_box, self.changed_box):
            row.addWidget(box)
        self.run_button = QPushButton("Run")
        self.run_button.setDefault(True)
        self.run_button.clicked.connect(self.start_run)
        row.addWidget(self.run_button)
        self.progress = QProgressBar()
        self.progress.setMaximumWidth(220)
        self.progress.setVisible(False)
        row.addWidget(self.progress)

    def _build_filters(self):
        self.filters = QWidget()
        column = QVBoxLayout(self.filters)
        column.setContentsMargins(0, 0, 0, 0)

        self.search = QLineEdit()
        self.search.setPlaceholderText("Filter: file, message, context or rule id")
        self.search.setClearButtonEnabled(True)
        self.search.textChanged.connect(lambda t: self.filter.update(text=t.strip()))
        column.addWidget(self.search)

        severity = QGroupBox("Severity")
        box = QVBoxLayout(severity)
        self.severity_boxes = {}
        for level in rules.SEVERITIES:
            check = QCheckBox(level)
            check.setIcon(severity_icon(level))
            check.setChecked(True)
            check.toggled.connect(self._severity_changed)
            box.addWidget(check)
            self.severity_boxes[level] = check
        column.addWidget(severity)

        show = QGroupBox("Show")
        box = QVBoxLayout(show)
        self.show_new = QCheckBox("New")
        self.show_new.setChecked(True)
        self.show_known = QCheckBox("Known noise")
        self.show_hidden = QCheckBox("Hidden rules")
        for check, key in ((self.show_new, "show_new"), (self.show_known, "show_known"),
                           (self.show_hidden, "show_hidden")):
            check.toggled.connect(lambda on, k=key: self.filter.update(**{k: on}))
            box.addWidget(check)
        column.addWidget(show)

        self.folder_combo = QComboBox()
        self.folder_combo.addItem("All folders", "")
        for folder in sorted({f for f, _ in runner.SCRIPT_FOLDERS}):
            self.folder_combo.addItem(folder, folder + "/")
        self.folder_combo.currentIndexChanged.connect(
            lambda: self.filter.update(folder=self.folder_combo.currentData()))
        column.addWidget(self.folder_combo)

        group = QGroupBox("Rules  (untick to hide)")
        box = QVBoxLayout(group)
        self.rule_tree = QTreeWidget()
        self.rule_tree.setHeaderLabels(["Rule", "Found"])
        self.rule_tree.setRootIsDecorated(False)
        self.rule_tree.header().setStretchLastSection(False)
        self.rule_tree.header().setSectionResizeMode(0, QHeaderView.Stretch)
        self.rule_tree.header().setSectionResizeMode(1, QHeaderView.ResizeToContents)
        self.rule_tree.itemChanged.connect(self._rule_ticked)
        self.rule_tree.currentItemChanged.connect(self._rule_selected)
        box.addWidget(self.rule_tree)
        column.addWidget(group, 1)
        self._build_rule_tree()
        self._fill_rule_tree()

    def _build_results(self):
        self.table = QTableView()
        self.table.setModel(self.filter)
        self.table.setSortingEnabled(True)
        self.table.sortByColumn(3, Qt.AscendingOrder)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.table.setAlternatingRowColors(True)
        self.table.setWordWrap(False)
        self.table.verticalHeader().setVisible(False)
        self.table.verticalHeader().setDefaultSectionSize(
            self.table.fontMetrics().height() + 6)
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(4, QHeaderView.Stretch)
        for column, width in ((0, 80), (1, 60), (2, 300), (3, 60), (5, 80)):
            self.table.setColumnWidth(column, width)
        self.table.selectionModel().currentRowChanged.connect(self._row_changed)
        self.table.doubleClicked.connect(lambda index: self._open_row(index))

    def _build_menu(self):
        file_menu = self.menuBar().addMenu("&File")
        run = QAction("&Run", self, shortcut=QKeySequence("F5"), triggered=self.start_run)
        choose = QAction("Choose &mod folder...", self, triggered=self.choose_mod)
        game = QAction("Choose &game folder...", self, triggered=self.choose_game)
        export = QAction("&Export shown results...", self, triggered=self.export)
        quit_action = QAction("&Quit", self, shortcut=QKeySequence.Quit, triggered=self.close)
        for action in (run, choose, game, export):
            file_menu.addAction(action)
        file_menu.addSeparator()
        file_menu.addAction(quit_action)

        noise = self.menuBar().addMenu("&Known noise")
        self.mark_action = QAction("&Mark selected as known", self,
                                   shortcut=QKeySequence("Ctrl+K"),
                                   triggered=lambda: self.set_known(self._selected(), True))
        self.unmark_action = QAction("&Remove selected from known", self,
                                     shortcut=QKeySequence("Ctrl+Shift+K"),
                                     triggered=lambda: self.set_known(self._selected(), False))
        self.accept_all_action = QAction("Accept &all shown as known...", self,
                                         triggered=self.accept_all_shown)
        self.prune_action = QAction("&Drop entries that no longer match...", self,
                                    triggered=self.prune_baseline)
        for action in (self.mark_action, self.unmark_action, self.accept_all_action,
                       self.prune_action):
            noise.addAction(action)
            self.addAction(action)
        self.prune_action.setEnabled(False)

        help_menu = self.menuBar().addMenu("&Help")
        help_menu.addAction(QAction("&About", self, triggered=self.about))

    # --- settings ----------------------------------------------------------------------

    def _restore(self):
        s = self.settings
        geometry = s.value("geometry")
        if geometry is not None:
            self.restoreGeometry(geometry)
        else:
            self.resize(1500, 900)
        for splitter, key in ((self.main_splitter, "mainSplitter"),
                              (self.right_splitter, "rightSplitter"),
                              (self.details.splitter, "detailsSplitter")):
            state = s.value(key)
            if state is not None:
                splitter.restoreState(state)
        # The checkout this copy of the tool sits in comes first, whatever was browsed to
        # last time; a remembered folder is for a copy kept outside any checkout.
        mod = own_checkout()
        if mod is None:
            remembered = s.value("mod")
            if remembered and runner.find_mod_root(remembered) is not None:
                mod = remembered
        if mod is None:
            mod = runner.find_mod_root(os.getcwd())
        self.set_mod(mod)
        self.code_box.setChecked(s.value("code", True, type=bool))
        self.refs_box.setChecked(s.value("references", False, type=bool))
        self.changed_box.setChecked(s.value("changed", False, type=bool))
        self.show_known.setChecked(s.value("showKnown", False, type=bool))
        self.show_hidden.setChecked(s.value("showHidden", False, type=bool))

    def closeEvent(self, event):
        if self.thread is not None and self.thread.isRunning():
            self.thread.quit()
            self.thread.wait(2000)
        if not self.persist:
            super().closeEvent(event)
            return
        s = self.settings
        s.setValue("geometry", self.saveGeometry())
        s.setValue("mainSplitter", self.main_splitter.saveState())
        s.setValue("rightSplitter", self.right_splitter.saveState())
        s.setValue("detailsSplitter", self.details.splitter.saveState())
        s.setValue("mod", self.mod_edit.text())
        s.setValue("code", self.code_box.isChecked())
        s.setValue("references", self.refs_box.isChecked())
        s.setValue("changed", self.changed_box.isChecked())
        s.setValue("showKnown", self.show_known.isChecked())
        s.setValue("showHidden", self.show_hidden.isChecked())
        super().closeEvent(event)

    # --- running -----------------------------------------------------------------------

    def choose_mod(self):
        folder = QFileDialog.getExistingDirectory(self, "BlackICE checkout",
                                                  self.mod_edit.text())
        if not folder:
            return
        root = runner.find_mod_root(folder)
        if root is None:
            QMessageBox.warning(self, "Not a mod folder",
                                "No events, decisions and common folders were found in "
                                "%s or above it." % folder)
            return
        self.set_mod(root)

    def game_folder(self):
        """The game install the user chose, or "" to find it beside the mod."""
        return self.settings.value("game", "") or ""

    def choose_game(self):
        found = self.game_folder() or find_game(self.mod_edit.text() or os.getcwd()) or ""
        folder = QFileDialog.getExistingDirectory(
            self, "Hearts of Iron 3 folder, for the event pictures the mod does not ship",
            found)
        if not folder:
            return
        if not is_game(folder):
            QMessageBox.warning(self, "Not the game folder",
                                "%s has no hoi3_tfh.exe and common folder." % folder)
            return
        if self.persist:
            self.settings.setValue("game", folder)
        self.shown_notes.clear()

    def set_mod(self, root):
        """Point the window at the checkout at \\p root, with its own hidden rules and
        known noise. A run against another checkout is cleared, since its findings and
        its baseline no longer belong together."""
        self.mod_edit.setText(root or "")
        self.details.root = root
        if root:
            self.config = Config.for_mod(root)
            self.baseline = Baseline(self.config.baseline_path)
        if self.result is not None and self.result.root != root:
            self.result = None
            self.model.set_items([])
            self.details.show_item(None)
        self._fill_rule_tree()

    def start_run(self):
        if self.thread is not None and self.thread.isRunning():
            return
        root = self.mod_edit.text()
        if not root or runner.find_mod_root(root) != os.path.abspath(root):
            QMessageBox.warning(self, "No mod folder", "Choose the BlackICE checkout first.")
            return
        modes = [m for m, box in ((rules.CODE, self.code_box), (rules.REFERENCES, self.refs_box))
                 if box.isChecked()]
        if not modes:
            QMessageBox.information(self, "Nothing to run", "Tick Code, References or both.")
            return
        only = None
        if self.changed_box.isChecked():
            from bicevalidator.__main__ import changed_files
            try:
                only = changed_files(root)
            except SystemExit as error:
                QMessageBox.warning(self, "Changed files", str(error))
                return
        self.full_run = only is None and len(modes) == 2
        self.run_button.setEnabled(False)
        self.progress.setVisible(True)
        self.progress.setRange(0, 0)
        self.statusBar().showMessage("Running...")

        self.thread = QThread(self)
        self.worker = RunWorker(root, modes, only, self.game_folder() or None)
        self.worker.moveToThread(self.thread)
        self.thread.started.connect(self.worker.run)
        self.worker.progress.connect(self._progress)
        self.worker.finished.connect(self._finished)
        self.worker.failed.connect(self._failed)
        self.worker.finished.connect(self.thread.quit)
        self.worker.failed.connect(self.thread.quit)
        self.thread.start()

    @Slot(int, int, str)
    def _progress(self, done, total, message):
        if total > 1:
            self.progress.setRange(0, total)
            self.progress.setValue(done)
        self.statusBar().showMessage(message)

    @Slot(object)
    def _finished(self, result):
        self.result = result
        self.run_button.setEnabled(True)
        self.progress.setVisible(False)
        self.prune_action.setEnabled(self.full_run)
        # Reloaded, in case either was changed outside the window since.
        self.config = Config.for_mod(result.root)
        self.baseline = Baseline(self.config.baseline_path)
        self.model.set_items(review.classify(result.diagnostics, self.config, self.baseline))
        self._update_counts()
        new_notes = [n for n in result.notes if n not in self.shown_notes]
        if new_notes:
            self.shown_notes.update(new_notes)
            QMessageBox.information(self, "Notes from the run", "\n\n".join(new_notes))

    @Slot(str)
    def _failed(self, message):
        self.run_button.setEnabled(True)
        self.progress.setVisible(False)
        self.statusBar().showMessage("The run failed.")
        QMessageBox.critical(self, "The run failed", message)

    # --- filters and counts ------------------------------------------------------------

    def _severity_changed(self):
        self.filter.update(severities={level for level, box in self.severity_boxes.items()
                                       if box.isChecked()})

    def _build_rule_tree(self):
        """The rule list's rows, made once. They are only ever updated after this
        (_fill_rule_tree): ticking a rule recounts everything from inside the tick's own
        signal, and clearing the list there deleted the row Qt was still handling - which
        crashed the window whenever the ticked rule was also the selected one."""
        self.all_rules_item = QTreeWidgetItem([ALL_RULES, ""])
        self.rule_tree.addTopLevelItem(self.all_rules_item)
        self.rule_items = {}
        for rule in rules.RULES.values():
            node = QTreeWidgetItem(["%s  %s" % (rule.id, rule.title), ""])
            node.setData(0, Qt.UserRole, rule.id)
            node.setIcon(0, severity_icon(rule.severity))
            node.setToolTip(0, "%s (%s, %s mode, %s)\n\n%s"
                            % (rule.title, rule.severity, rule.mode, rule.confidence,
                               rule.explanation.replace("`", "").replace("**", "")))
            node.setFlags(node.flags() | Qt.ItemIsUserCheckable)
            node.setCheckState(0, Qt.Checked)
            self.rule_tree.addTopLevelItem(node)
            self.rule_items[rule.id] = node

    def _fill_rule_tree(self, counts=None):
        """Counts and ticks for the existing rows; never adds or removes one."""
        counts = counts or {}
        self.rule_tree.blockSignals(True)
        try:
            self.all_rules_item.setText(1, str(sum(counts.values())) if counts else "")
            normal = self.palette().text()
            faded = self.palette().placeholderText()
            for rule_id, node in self.rule_items.items():
                node.setText(1, str(counts.get(rule_id, 0)) if counts else "")
                node.setCheckState(0, Qt.Unchecked if rule_id in self.config.hidden_rules
                                   else Qt.Checked)
                node.setForeground(0, faded if counts and not counts.get(rule_id) else normal)
        finally:
            self.rule_tree.blockSignals(False)

    def _rule_ticked(self, node, column):
        rule = node.data(0, Qt.UserRole)
        if rule and column == 0:
            hidden = node.checkState(0) == Qt.Unchecked
            if hidden != (rule in self.config.hidden_rules):
                # After the signal has returned, so nothing is redrawn under Qt's feet.
                QTimer.singleShot(0, lambda: self.set_rule_hidden(rule, hidden))

    def _rule_selected(self, node, _previous):
        rule = node.data(0, Qt.UserRole) if node is not None else None
        self.filter.update(rule_only=rule)

    def _update_counts(self):
        items = self.model.items
        new = [i for i in items if i.is_new]
        for level, box in self.severity_boxes.items():
            box.setText("%s  (%d new)" % (level, sum(1 for i in new
                                                     if i.diagnostic.severity == level)))
        known = sum(1 for i in items if i.known)
        hidden = sum(1 for i in items if i.hidden and not i.known)
        self.show_new.setText("New  (%d)" % len(new))
        self.show_known.setText("Known noise  (%d)" % known)
        self.show_hidden.setText("Hidden rules  (%d)" % hidden)
        counts = {}
        for i in items:
            counts[i.diagnostic.rule] = counts.get(i.diagnostic.rule, 0) + 1
        self._fill_rule_tree(counts)
        if self.result is not None:
            self.statusBar().showMessage(
                "%d new, %d known, %d hidden  -  %d files in %.1fs  -  keywords from %s"
                % (len(new), known, hidden, self.result.checked, self.result.seconds,
                   self.result.keywords_from))

    def _reclassify(self):
        if self.result is None:
            return
        current = self._current_item()
        self.model.set_items(review.classify(self.result.diagnostics, self.config,
                                             self.baseline))
        self._update_counts()
        if current is not None:
            self._select_diagnostic(current.diagnostic)

    # --- known noise and hidden rules --------------------------------------------------

    def set_rule_hidden(self, rule, hidden):
        if hidden:
            self.config.hidden_rules.add(rule)
        else:
            self.config.hidden_rules.discard(rule)
        self.config.save()
        self._reclassify()

    def set_known(self, items, known):
        if not items:
            return
        if known:
            self.baseline.add([i.diagnostic for i in items if not i.known])
        else:
            self.baseline.remove([i.diagnostic for i in items if i.known])
        self.baseline.save()
        self._reclassify()

    def toggle_known(self):
        item = self.details.item
        if item is not None:
            self.set_known([item], not item.known)

    def accept_all_shown(self):
        shown = [self.model.items[self.filter.mapToSource(self.filter.index(r, 0)).row()]
                 for r in range(self.filter.rowCount())]
        shown = [i for i in shown if not i.known]
        if not shown:
            return
        answer = QMessageBox.question(self, "Accept as known noise",
                                      "Accept all %d shown findings as known noise? They will "
                                      "be written to %s." % (len(shown),
                                                             self.config.baseline_path))
        if answer == QMessageBox.Yes:
            self.set_known(shown, True)

    def prune_baseline(self):
        if self.result is None or not self.full_run:
            return
        stale = self.baseline.stale(self.result.diagnostics)
        if not stale:
            QMessageBox.information(self, "Known noise", "Every entry still matches.")
            return
        answer = QMessageBox.question(self, "Drop fixed entries",
                                      "%d known-noise entries no longer match anything - they "
                                      "were fixed. Drop them?" % len(stale))
        if answer == QMessageBox.Yes:
            for entry in stale:
                key = "|".join((entry["rule"], entry["file"], entry["context"],
                                entry["message"]))
                self.baseline.entries.pop(key, None)
            self.baseline.save()
            self._reclassify()

    # --- selection and editor ----------------------------------------------------------

    def _current_item(self):
        index = self.table.currentIndex()
        if not index.isValid():
            return None
        return self.model.items[self.filter.mapToSource(index).row()]

    def _selected(self):
        rows = {self.filter.mapToSource(i).row() for i in self.table.selectionModel().selectedRows()}
        return [self.model.items[r] for r in sorted(rows)]

    def _select_diagnostic(self, diagnostic):
        for row, item in enumerate(self.model.items):
            if item.diagnostic is diagnostic:
                index = self.filter.mapFromSource(self.model.index(row, 0))
                if index.isValid():
                    self.table.setCurrentIndex(index)
                    self.details.show_item(item)
                return

    def _row_changed(self, current, _previous):
        self.details.show_item(self.model.items[self.filter.mapToSource(current).row()]
                               if current.isValid() else None)

    def _open_row(self, index):
        item = self.model.items[self.filter.mapToSource(index).row()]
        d = item.diagnostic
        self.open_in_editor(d.file, d.line, d.col)

    def open_in_editor(self, rel, line, col):
        path = os.path.join(self.mod_edit.text(), rel)
        code = shutil.which("code")
        try:
            if code:
                subprocess.Popen([code, "-g", "%s:%d:%d" % (path, line, col)])
            else:
                os.startfile(path)
        except OSError as error:
            QMessageBox.warning(self, "Cannot open", str(error))

    def export(self):
        path, _ = QFileDialog.getSaveFileName(self, "Export shown results", "findings.csv",
                                              "CSV (*.csv);;Text (*.txt)")
        if not path:
            return
        shown = [self.model.items[self.filter.mapToSource(self.filter.index(r, 0)).row()]
                 for r in range(self.filter.rowCount())]
        with open(path, "w", encoding="utf-8", newline="") as handle:
            if path.lower().endswith(".csv"):
                writer = csv.writer(handle)
                writer.writerow(["severity", "rule", "file", "line", "col", "message",
                                 "context", "hint", "status"])
                for i in shown:
                    d = i.diagnostic
                    writer.writerow([d.severity, d.rule, d.file, d.line, d.col, d.message,
                                     d.context, d.hint,
                                     "known" if i.known else "hidden" if i.hidden else "new"])
            else:
                for i in shown:
                    handle.write(i.diagnostic.format() + "\n")
        self.statusBar().showMessage("Exported %d findings to %s" % (len(shown), path))

    def about(self):
        from bicevalidator.schema import locate_keyword_pages
        try:
            _, keywords = locate_keyword_pages(self.mod_edit.text())
        except (FileNotFoundError, OSError) as error:
            keywords = str(error)
        QMessageBox.about(self, "BICE Validator",
                          "<b>BICE Validator %s</b><p>Checks BlackICE's script against the "
                          "keyword lists in docs/script, which were read out of the game."
                          "</p><p>Keyword lists: %s<br>Hidden rules: %s<br>Known noise: %s</p>"
                          % (__version__, keywords, self.config.path,
                             self.config.baseline_path))


def own_checkout():
    """The checkout this copy of the tool sits in - tools/BiceValidator/dist for the exe -
    or None for a copy kept anywhere else.

    For the exe that is where the exe file is: a bundled copy unpacks its own code into a
    temporary folder, so the code's location says nothing.
    """
    if getattr(sys, "frozen", False):
        here = os.path.dirname(os.path.abspath(sys.executable))
    else:
        here = os.path.dirname(os.path.abspath(__file__))
    return runner.find_mod_root(here)


def smoke_test(argv):
    """`--smoke-test <mod> <report> [screenshot.png]`: build the window, run a code-mode
    validation of <mod> without showing anything, and write a one-line summary to
    <report> - and, if asked, a picture of the window with the results in it.

    For the build workflow, which has no screen to look at and, in a windowed exe, no
    stdout either. It proves what a bundle most often gets wrong: that Qt's plugins were
    packed, and that the run's worker processes start from a frozen exe.
    """
    mod, report = argv[0], argv[1]
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    app = QApplication([sys.argv[0]])
    window = MainWindow()
    window.persist = False
    opened_on = window.mod_edit.text()
    window.set_mod(mod)
    result = runner.run(mod, [rules.CODE])
    with open(report, "w", encoding="utf-8") as handle:
        handle.write("files=%d findings=%d seconds=%.1f keywords=%s opened_on=%s\n"
                     % (result.checked, len(result.diagnostics), result.seconds,
                        result.keywords_from, opened_on))
    if len(argv) > 2:
        window.resize(1600, 950)
        window.show()
        window.run_button.setEnabled(True)
        result.notes = []       # they would open a message box, and nobody is there to close it
        window._finished(result)
        window.table.selectRow(0)
        app.processEvents()
        window.grab().save(argv[2])
    window.close()
    app.quit()
    return 0 if result.checked > 0 else 1


def main():
    if len(sys.argv) >= 4 and sys.argv[1] == "--smoke-test":
        return smoke_test(sys.argv[2:])
    app = QApplication(sys.argv)
    app.setApplicationName("BICE Validator")
    window = MainWindow()
    window.show()
    return app.exec()
