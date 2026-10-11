"""Sorting a run's findings into new, known noise and hidden, the same way everywhere."""

from dataclasses import dataclass

from . import rules


@dataclass
class Item:
    diagnostic: object
    known: bool       # accepted in the baseline
    hidden: bool      # its rule is hidden in validator.json

    @property
    def is_new(self):
        return not self.known and not self.hidden


def classify(diagnostics, config, baseline):
    known = baseline.known(diagnostics) if baseline is not None else set()
    hidden = config.hidden_rules if config is not None else set()
    return [Item(d, i in known, d.rule in hidden) for i, d in enumerate(diagnostics)]


def fails(items, level):
    """Whether any new finding is at \\p level or worse ("error", "warning", "never")."""
    if level == "never":
        return False
    worst = rules.SEVERITIES.index(level)
    return any(item.is_new and rules.SEVERITIES.index(item.diagnostic.severity) <= worst
               for item in items)
