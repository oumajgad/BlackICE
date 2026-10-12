"""The mod's localisation: what each key reads as in English, and where it is written.

Every table in `localisation/` is `KEY;English;French;...`, one key a line, in
Windows-1252. A country's name is the line keyed by its tag (`GER;Germany`), a province's
by `PROV` and its id, a technology's or a unit's by its own name, a decision's by its name
and `_title`.

The same key in two tables happens. Which one the game then shows is not established, so
an editor says how many there are rather than picking one as the game's.
"""

import glob
import os
import threading
from collections import namedtuple

Entry = namedtuple("Entry", "key text file line")


def _read(root, rel):
    with open(os.path.join(root, rel), "rb") as handle:
        text = handle.read().decode("cp1252", errors="replace")
    entries = []
    for number, line in enumerate(text.split("\n"), 1):
        if not line or line.startswith("#"):
            continue
        parts = line.rstrip("\r").split(";")
        key = parts[0].strip()
        if key:
            entries.append(Entry(key, parts[1] if len(parts) > 1 else "", rel, number))
    return entries


class Localisation:
    def __init__(self, root):
        self.root = root
        self._lock = threading.Lock()
        self._files = {}        # rel -> [Entry]
        self._keys = None       # lower key -> [Entry], built when first asked
        for path in sorted(glob.glob(os.path.join(root, "localisation", "*.csv"))):
            rel = os.path.relpath(path, root).replace("\\", "/")
            self._files[rel] = _read(root, rel)

    def reload_file(self, rel):
        """Read \\p rel again, or forget it if it has gone."""
        exists = os.path.exists(os.path.join(self.root, rel))
        entries = _read(self.root, rel) if exists else None
        with self._lock:
            if entries is None:
                self._files.pop(rel, None)
            else:
                self._files[rel] = entries
            self._keys = None

    def _table(self):
        with self._lock:
            if self._keys is None:
                keys = {}
                for rel in sorted(self._files):
                    for entry in self._files[rel]:
                        keys.setdefault(entry.key.lower(), []).append(entry)
                self._keys = keys
            return self._keys

    def entries(self, key):
        """Every line that localises \\p key, in table order."""
        return self._table().get(key.lower(), [])

    def text(self, key):
        """The English text of \\p key, or None. The first table's, where there are several."""
        found = self.entries(key)
        return found[0].text if found else None

    def has(self, key):
        return key.lower() in self._table()
