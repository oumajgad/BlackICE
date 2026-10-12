"""What a check reports: one finding, where it is, and what else is worth looking at."""

from dataclasses import dataclass, field


@dataclass(frozen=True)
class Related:
    """A second place that explains a finding - the bracket a block opened at, the other
    event with the same id."""
    label: str
    file: str
    line: int
    col: int = 1


@dataclass
class Diagnostic:
    rule: str           # a rule id from rules.RULES, e.g. "BV001"
    file: str           # relative to the mod root, forward slashes
    line: int           # 1-based
    col: int            # 1-based, in characters
    message: str
    # Where in the file's structure the finding sits, e.g. "country_event 14883 > option".
    # Line numbers move with every edit above them; this does not, which is what lets the
    # known-noise baseline recognise a finding again after the file has changed.
    context: str = ""
    hint: str = ""
    related: list = field(default_factory=list)

    @property
    def severity(self):
        from .rules import RULES
        return RULES[self.rule].severity

    def fingerprint(self):
        """The identity the baseline stores: no line numbers, so it survives edits."""
        return "|".join((self.rule, self.file, self.context, self.message))

    def format(self):
        """The one-line form editors and CI logs understand: file:line:col: severity id text."""
        return "%s:%d:%d: %s %s %s" % (self.file, self.line, self.col, self.severity,
                                       self.rule, self.message)
