"""The leaders of history/leaders, with the rank the game gives each of them, and the orders
of battle a new game loads.

**A leader's rank is not simply what his history says.** As a game is made his history is
folded to the start date, so the ranks dated on or before it apply in date order. After
that the only thing the game reads from it is the date of his first `rank`: on that day a
leader not yet in service is put in service **at rank 1, whatever rank is written**, and no
later `rank` is ever applied (reversing/findings/FINDINGS-leaders.md, section 3, "The leader
part of the daily pass"; reversing/findings/FINDINGS-leaderassign.md, section 2). Only a
promotion in play - by the player, the AI or an effect - moves him after that.

An order of battle's `leader = N` is given leader N whoever he is - of any country, rank or
arm, in service or not (FINDINGS-leaderassign.md, section 1). So nothing in the game reports
a leader who does not fit; the checks in checks/data.py do.
"""

import glob
import os
import re
from dataclasses import dataclass, field

_DATE = re.compile(r"^(\d{1,4})\.(\d{1,2})\.(\d{1,2})$")
# The one start the game offers when a mod has no bookmarks of its own.
DEFAULT_START = (1936, 1, 1)


def parse_date(text):
    found = _DATE.match(text or "")
    return tuple(int(x) for x in found.groups()) if found else None


def date_text(date):
    return "%d.%d.%d" % date


@dataclass
class Leader:
    ident: str
    name: str
    country: str
    arm: str            # land, sea or air
    skill: int
    max_skill: int
    file: str
    line: int
    traits: list = field(default_factory=list)
    ranks: list = field(default_factory=list)   # (date, rank, line) in file order

    def first_rank(self):
        """(date, rank, line) of the earliest dated rank, or None. Of two on one date the
        first written: the history is kept in date order, and of one date in file order."""
        return min(self.ranks, key=lambda r: r[0]) if self.ranks else None

    def rank_at(self, date):
        """His rank as a game starting on \\p date makes it: 0 if he is not yet in
        service."""
        rank = 0
        for when, value, _ in sorted(self.ranks, key=lambda r: r[0]):
            if when <= date:
                rank = value
        return rank

    def rank_in_play(self, start):
        """(rank, date or None): the rank he holds once in service in a game started on
        \\p start, and the date he enters service if that is after the start."""
        rank = self.rank_at(start)
        if rank:
            return rank, None
        first = self.first_rank()
        if first is None:
            return 0, None
        return 1, first[0]

    def ignored_ranks(self, start):
        """(date, rank, line, why) of every dated rank that does not do what it says in a
        game started on \\p start."""
        first = self.first_rank()
        out = []
        for when, value, line in self.ranks:
            if when <= start:
                continue
            if (when, value, line) == first:
                if value != 1:
                    out.append((when, value, line, "first"))
            else:
                out.append((when, value, line, "later"))
        return out


class Leaders:
    def __init__(self, root, tree):
        """\\p tree(rel) is a parsed file's root node, or None if it does not exist."""
        self.by_id = {}
        self.starts = self._starts(tree)
        self.start = self.starts[0]
        for path in sorted(glob.glob(os.path.join(root, "history", "leaders", "*.txt"))):
            rel = os.path.relpath(path, root).replace("\\", "/")
            node = tree(rel)
            for block in (node.children if node is not None else ()):
                if block.is_block and block.key and block.key.isdigit():
                    self.by_id.setdefault(block.key, read_leader(block, rel))
        # history/units/<file> -> (tag, start date) for every order of battle a country's
        # history loads as a game starts.
        # Kept in lower case, as file names are compared on Windows.
        self.start_oobs = {}
        for path in sorted(glob.glob(os.path.join(root, "history", "countries", "*.txt"))):
            rel = os.path.relpath(path, root).replace("\\", "/")
            node = tree(rel)
            if node is None:
                continue
            tag = os.path.basename(path)[:3].upper()
            for start in self.starts:
                oob = _folded_oob(node, start)
                if oob:
                    self.start_oobs.setdefault(("history/units/" + oob).lower(), (tag, start))

    def get(self, ident):
        return self.by_id.get(str(ident))

    def start_oob(self, rel):
        """(tag, start date) if a country's history loads order of battle \\p rel as a game
        starts, else None - a file only `load_oob` loads, at a date nothing here knows."""
        return self.start_oobs.get(rel.replace("\\", "/").lower())

    def rank_in(self, leader, rel):
        """(rank, date or None) of \\p leader where file \\p rel names him. In an order of
        battle a country's history loads as a game starts, the rank he has then - 0, with
        the date he comes into service at rank 1, if that is later. Anywhere else, the rank
        he holds once in service, with the date he comes into it if that is after the
        start. rank_phrase says either."""
        start = self.start_oob(rel)
        if start is not None:
            rank = leader.rank_at(start[1])
            first = leader.first_rank()
            return rank, (first[0] if rank == 0 and first is not None else None)
        return leader.rank_in_play(self.start)

    @staticmethod
    def _starts(tree):
        node = tree("common/bookmarks.txt")
        dates = []
        for bookmark in (node.children if node is not None else ()):
            if bookmark.is_block and bookmark.lkey == "bookmark":
                when = bookmark.child("date")
                date = parse_date(when.value) if when is not None else None
                if date is not None:
                    dates.append(date)
        return sorted(set(dates)) or [DEFAULT_START]


def rank_phrase(rank, since):
    """`rank 2`, `rank 1 from 1940.1.1`, or `rank 0 until 1940.1.1, then rank 1`."""
    if since is not None and rank == 0:
        return "rank 0 until %s, then rank 1" % date_text(since)
    if since is not None:
        return "rank %d from %s" % (rank, date_text(since))
    return "rank %d" % rank


def _value(block, key):
    child = block.child(key)
    return child.value if child is not None and child.value is not None else ""


def _int(text):
    try:
        return int(text)
    except ValueError:
        return 0


def read_leader(block, rel):
    """The Leader a `<id> = { ... }` block of history/leaders describes."""
    leader = Leader(ident=block.key, name=_value(block, "name"),
                    country=_value(block, "country").upper(), arm=_value(block, "type").lower(),
                    skill=_int(_value(block, "skill")), max_skill=_int(_value(block, "max_skill")),
                    file=rel, line=block.line)
    for child in block.children:
        if child.lkey in ("add_trait", "trait") and child.value:
            leader.traits.append(child.value)
    history = block.child("history")
    for entry in (history.children if history is not None and history.is_block else ()):
        when = parse_date(entry.key)
        if when is None or not entry.is_block:
            continue
        for child in entry.children:
            if child.lkey == "rank" and child.value and child.value.isdigit():
                leader.ranks.append((when, int(child.value), child.line))
    return leader


def _folded_oob(node, start):
    """The order of battle a country's history names on \\p start: its own `oob`, then each
    dated block's on or before the start, in date order."""
    oob = _value(node, "oob")
    dated = []
    for child in node.children:
        when = parse_date(child.key) if child.is_block else None
        if when is not None and when <= start:
            found = child.child("oob")
            if found is not None and found.value:
                dated.append((when, found.value))
    for _, value in sorted(dated, key=lambda d: d[0]):
        oob = value
    return oob
