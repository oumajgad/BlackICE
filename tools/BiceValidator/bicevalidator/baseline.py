"""Known noise: findings someone has looked at and accepted, so only new ones stand out.

A finding is matched by its fingerprint - rule, file, structural context and message, with
no line number - so it is still recognised after lines are added above it. The same
fingerprint can occur more than once (two identical lines in one option), so each entry
carries a count, and a third occurrence of something accepted twice is new.

The file is JSON, sorted, one entry per object, so a diff of it in a commit reads as the
list of what was accepted or fixed.
"""

import json
import os
from collections import Counter


class Baseline:
    def __init__(self, path):
        self.path = path
        self.entries = {}       # fingerprint -> {"rule", "file", "context", "message", "count"}
        if os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                for entry in json.load(handle).get("known", ()):
                    key = "|".join((entry["rule"], entry["file"], entry["context"],
                                    entry["message"]))
                    self.entries[key] = entry

    def __len__(self):
        return sum(e.get("count", 1) for e in self.entries.values())

    def known(self, diagnostics):
        """The ids (positions in \\p diagnostics) of the findings the baseline accepts."""
        allowance = Counter({k: e.get("count", 1) for k, e in self.entries.items()})
        out = set()
        for index, d in enumerate(diagnostics):
            key = d.fingerprint()
            if allowance[key] > 0:
                allowance[key] -= 1
                out.add(index)
        return out

    def add(self, diagnostics):
        """Accept \\p diagnostics, on top of what is already accepted."""
        counts = Counter(d.fingerprint() for d in diagnostics)
        sample = {d.fingerprint(): d for d in diagnostics}
        for key, count in counts.items():
            d = sample[key]
            entry = self.entries.setdefault(key, {"rule": d.rule, "file": d.file,
                                                  "context": d.context, "message": d.message,
                                                  "count": 0})
            entry["count"] = entry.get("count", 0) + count

    def remove(self, diagnostics):
        for d in diagnostics:
            entry = self.entries.get(d.fingerprint())
            if entry is None:
                continue
            entry["count"] = entry.get("count", 1) - 1
            if entry["count"] <= 0:
                del self.entries[d.fingerprint()]

    def replace(self, diagnostics):
        """Make the baseline exactly \\p diagnostics: what is fixed drops out of it."""
        self.entries = {}
        self.add(diagnostics)

    def stale(self, diagnostics):
        """Entries that no longer match anything - fixed, so they can be dropped."""
        present = Counter(d.fingerprint() for d in diagnostics)
        return [e for k, e in self.entries.items() if present[k] == 0]

    def save(self):
        known = sorted(self.entries.values(),
                       key=lambda e: (e["file"], e["rule"], e["context"], e["message"]))
        with open(self.path, "w", encoding="utf-8", newline="\n") as handle:
            json.dump({"version": 1, "known": known}, handle, indent=1, ensure_ascii=False)
            handle.write("\n")
