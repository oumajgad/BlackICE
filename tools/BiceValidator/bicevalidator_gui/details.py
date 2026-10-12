"""The details pane: everything known about one finding, and the source around it."""

import html
import os
import re

from PySide6.QtCore import Qt, Signal, QUrl
from PySide6.QtGui import QColor, QFont, QTextCursor, QTextFormat
from PySide6.QtWidgets import (QHBoxLayout, QLabel, QPlainTextEdit, QPushButton, QSplitter,
                               QTextBrowser, QTextEdit, QVBoxLayout, QWidget)

from bicevalidator import lexer, rules

CONTEXT_LINES = 12


def rich(text):
    """The rule texts' light markdown - `code` and **bold** - as HTML."""
    out = html.escape(text)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", out)
    return out


class DetailsPane(QWidget):
    open_requested = Signal(str, int, int)      # file, line, col
    known_toggled = Signal()
    hide_rule_requested = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.root = None
        self.item = None
        self._source_cache = (None, None)

        self.title = QLabel()
        self.title.setTextFormat(Qt.RichText)
        self.title.setWordWrap(True)
        font = self.title.font()
        font.setPointSizeF(font.pointSizeF() * 1.15)
        self.title.setFont(font)

        self.text = QTextBrowser()
        self.text.setOpenLinks(False)
        self.text.anchorClicked.connect(self._anchor)

        self.source = QPlainTextEdit()
        self.source.setReadOnly(True)
        self.source.setLineWrapMode(QPlainTextEdit.NoWrap)
        mono = QFont("Consolas")
        mono.setStyleHint(QFont.Monospace)
        self.source.setFont(mono)
        self.source_label = QLabel()

        self.open_button = QPushButton("Open in editor")
        self.open_button.clicked.connect(self._open)
        self.known_button = QPushButton("Mark as known noise")
        self.known_button.clicked.connect(self.known_toggled.emit)
        self.hide_button = QPushButton("Hide this rule")
        self.hide_button.clicked.connect(
            lambda: self.item and self.hide_rule_requested.emit(self.item.diagnostic.rule))
        buttons = QHBoxLayout()
        for button in (self.open_button, self.known_button, self.hide_button):
            buttons.addWidget(button)
        buttons.addStretch(1)

        top = QWidget()
        top_layout = QVBoxLayout(top)
        top_layout.setContentsMargins(0, 0, 0, 0)
        top_layout.addWidget(self.title)
        top_layout.addWidget(self.text, 1)
        top_layout.addLayout(buttons)

        bottom = QWidget()
        bottom_layout = QVBoxLayout(bottom)
        bottom_layout.setContentsMargins(0, 0, 0, 0)
        bottom_layout.addWidget(self.source_label)
        bottom_layout.addWidget(self.source, 1)

        self.splitter = QSplitter(Qt.Vertical)
        self.splitter.addWidget(top)
        self.splitter.addWidget(bottom)
        self.splitter.setStretchFactor(0, 1)
        self.splitter.setStretchFactor(1, 1)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.addWidget(self.splitter)
        self.show_item(None)

    # --- showing -----------------------------------------------------------------------

    def show_item(self, item):
        self.item = item
        enabled = item is not None
        for button in (self.open_button, self.known_button, self.hide_button):
            button.setEnabled(enabled)
        if item is None:
            self.title.setText("<i>Select a finding to see its details.</i>")
            self.text.clear()
            self.source.clear()
            self.source_label.clear()
            return
        d = item.diagnostic
        rule = rules.RULES[d.rule]
        self.title.setText("<b>%s</b> &nbsp;%s" % (d.rule, rich(rule.title)))
        self.known_button.setText("Remove from known noise" if item.known
                                  else "Mark as known noise")
        self.hide_button.setText("Hide rule %s" % d.rule)

        parts = ["<p>%s</p>" % rich(d.message)]
        parts.append('<p><a href="loc:%s:%d:%d">%s:%d:%d</a>'
                     % (html.escape(d.file), d.line, d.col, html.escape(d.file), d.line, d.col))
        if d.context:
            parts.append("<br><small>in %s</small>" % html.escape(d.context))
        parts.append("</p>")
        status = "known noise" if item.known else "rule hidden" if item.hidden else "new"
        parts.append("<p><small>%s &middot; %s mode &middot; %s &middot; %s</small></p>"
                     % (d.severity, rule.mode, rule.confidence, status))
        if d.hint:
            parts.append("<p><b>Hint:</b> %s</p>" % rich(d.hint))
        if d.related:
            parts.append("<p><b>See also:</b><br>")
            for r in d.related:
                parts.append('&nbsp;&nbsp;<a href="loc:%s:%d:%d">%s:%d</a> &mdash; %s<br>'
                             % (html.escape(r.file), r.line, r.col, html.escape(r.file),
                                r.line, html.escape(r.label)))
            parts.append("</p>")
        parts.append("<hr><p><b>About this rule</b></p><p>%s</p>" % rich(rule.explanation))
        self.text.setHtml("".join(parts))
        self.show_source(d.file, d.line, d.col,
                         [r.line for r in d.related if r.file == d.file])

    def _lines(self, rel):
        if self._source_cache[0] != rel:
            try:
                lines = lexer.read(self.root, rel).lines
            except OSError:
                lines = None
            self._source_cache = (rel, lines)
        return self._source_cache[1]

    def show_source(self, rel, line, col, also=()):
        lines = self._lines(rel) if self.root else None
        if not lines:
            self.source.setPlainText("(cannot read %s)" % rel)
            return
        first = max(1, line - CONTEXT_LINES)
        last = min(len(lines), line + CONTEXT_LINES)
        for other in also:
            # Stretch the window to show a related line, unless it is far away.
            if abs(other - line) <= 60:
                first, last = min(first, other - 3), max(last, other + 3)
        first, last = max(1, first), min(len(lines), last)
        width = len(str(last))
        text = "\n".join("%*d  %s" % (width, n, lines[n - 1].rstrip("\r").expandtabs(4))
                         for n in range(first, last + 1))
        self.source.setPlainText(text)
        self.source_label.setText("<b>%s</b>, lines %d-%d" % (html.escape(rel), first, last))

        palette = self.source.palette()
        main = QColor(palette.highlight().color())
        main.setAlpha(90)
        extra = QColor(230, 160, 40)
        extra.setAlpha(70)
        selections = []
        for target, colour in [(line, main)] + [(o, extra) for o in also if first <= o <= last]:
            block = self.source.document().findBlockByNumber(target - first)
            if not block.isValid():
                continue
            selection = QTextEdit.ExtraSelection()
            selection.format.setBackground(colour)
            selection.format.setProperty(QTextFormat.FullWidthSelection, True)
            selection.cursor = QTextCursor(block)
            selections.append(selection)
        self.source.setExtraSelections(selections)
        cursor = QTextCursor(self.source.document().findBlockByNumber(line - first))
        self.source.setTextCursor(cursor)
        self.source.centerCursor()

    # --- actions -----------------------------------------------------------------------

    def _anchor(self, url):
        text = url.toString()
        if not text.startswith("loc:"):
            return
        rel, line, col = text[4:].rsplit(":", 2)
        line, col = int(line), int(col)
        d = self.item.diagnostic if self.item else None
        if d is not None and rel == d.file:
            self.show_source(rel, line, col, [d.line] if line != d.line else [])
        else:
            self.show_source(rel, line, col)

    def _open(self):
        if self.item is not None:
            d = self.item.diagnostic
            self.open_requested.emit(d.file, d.line, d.col)
