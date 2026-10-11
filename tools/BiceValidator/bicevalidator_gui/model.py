"""The results table: a model over a run's classified findings, and the filter in front of it."""

from PySide6.QtCore import QAbstractTableModel, QModelIndex, QSortFilterProxyModel, Qt
from PySide6.QtGui import QColor
from PySide6.QtWidgets import QApplication, QStyle

from bicevalidator import rules

COLUMNS = ("Severity", "Rule", "File", "Line", "Message", "Status")
SEVERITY_ORDER = {s: i for i, s in enumerate(rules.SEVERITIES)}

_ICONS = {}


def severity_icon(severity):
    if not _ICONS:
        style = QApplication.style()
        _ICONS.update({
            rules.ERROR: style.standardIcon(QStyle.SP_MessageBoxCritical),
            rules.WARNING: style.standardIcon(QStyle.SP_MessageBoxWarning),
            rules.INFO: style.standardIcon(QStyle.SP_MessageBoxInformation),
        })
    return _ICONS[severity]


def status_of(item):
    if item.known:
        return "known"
    if item.hidden:
        return "hidden rule"
    return "new"


class ResultsModel(QAbstractTableModel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.items = []

    def set_items(self, items):
        self.beginResetModel()
        self.items = items
        self.endResetModel()

    def refresh(self):
        """Statuses changed (baseline or hidden rules) without the rows changing."""
        if self.items:
            self.dataChanged.emit(self.index(0, 0),
                                  self.index(len(self.items) - 1, len(COLUMNS) - 1))

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self.items)

    def columnCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(COLUMNS)

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            return COLUMNS[section]
        return None

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        item = self.items[index.row()]
        d = item.diagnostic
        column = index.column()
        if role == Qt.DisplayRole:
            if column == 4:
                # The backticks mark code for the details pane; in a table cell they are noise.
                return d.message.replace("`", "")
            return (d.severity, d.rule, d.file, d.line, d.message, status_of(item))[column]
        if role == Qt.DecorationRole and column == 0:
            return severity_icon(d.severity)
        if role == Qt.ToolTipRole:
            if column == 1:
                return rules.RULES[d.rule].title
            if column == 4:
                return d.message + ("\n\n" + d.hint if d.hint else "")
        if role == Qt.ForegroundRole and not item.is_new:
            return QColor(128, 128, 128)
        if role == Qt.UserRole:
            # Sort key: severity by rank, lines as numbers.
            if column == 0:
                return SEVERITY_ORDER[d.severity]
            if column == 3:
                return (d.file, d.line, d.col)
            return (d.severity, d.rule, d.file, d.line, d.message, status_of(item))[column]
        return None


class ResultsFilter(QSortFilterProxyModel):
    """Everything the filter panel decides, in one place."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSortRole(Qt.UserRole)
        self.severities = set(rules.SEVERITIES)
        self.show_new = True
        self.show_known = False
        self.show_hidden = False
        self.folder = ""            # "" for all, else "events/" etc.
        self.text = ""
        self.rule_only = None       # a rule id clicked in the rule list, or None

    def update(self, **changes):
        for key, value in changes.items():
            setattr(self, key, value)
        self.invalidateFilter()

    def accepts(self, item):
        d = item.diagnostic
        if d.severity not in self.severities:
            return False
        if item.known:
            if not self.show_known:
                return False
        elif item.hidden:
            if not self.show_hidden:
                return False
        elif not self.show_new:
            return False
        if self.rule_only and d.rule != self.rule_only:
            return False
        if self.folder and not d.file.startswith(self.folder):
            return False
        if self.text:
            needle = self.text.lower()
            if needle not in d.file.lower() and needle not in d.message.lower() \
                    and needle not in d.context.lower() and needle != d.rule.lower():
                return False
        return True

    def filterAcceptsRow(self, row, parent):
        return self.accepts(self.sourceModel().items[row])

    def lessThan(self, left, right):
        a = self.sourceModel().data(left, Qt.UserRole)
        b = self.sourceModel().data(right, Qt.UserRole)
        try:
            return a < b
        except TypeError:
            return str(a) < str(b)
