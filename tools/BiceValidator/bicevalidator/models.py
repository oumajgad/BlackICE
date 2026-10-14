"""Historical models, and what a queued brigade is built with when it names one.

A unit type's model N is a list of `<technology> = <level>`. Every country starts with
HISTORICAL_MODEL_MAX models of every type, each listing every technology of the type
(reversing/findings/FINDINGS-unitstart.md, section 5). A file of `units/models` whose name
begins with the country's tag replaces model N with what it lists, or adds model N where N
is one past the last; any other number is dropped with a log line.

On the map a model is applied technology by technology. **In a production line it is not**:
`historical_model = N` on a brigade of a `military_construction` walks the type's
technologies in order and appends the level of each one the model names, and the line hands
those levels out by position (reversing/findings/FINDINGS-buildqueue.md, section 10). So a
model that leaves out a technology of its type puts every level after the gap on the
technology before the one it was meant for. BlackICE's model files name a few technologies
each, by design, which is right on the map and wrong in the queue.

**BiceLib mends that** where `script/bicelib_lua.lua` calls
`BiceLib.ComplexPatches.fixQueuedHistoricalModel()`: the line then gets a 0 for each
technology the model leaves out, so every level is built on its own technology.
"""

import glob
import os
import re
from dataclasses import dataclass, field

from . import lexer, parser

# The base game's figure; a mod's common/defines.lua may raise it.
DEFAULT_MAX = 10
_DEFINE = re.compile(r"\bHISTORICAL_MODEL_MAX\s*=\s*(\d+)")

# Where the mod switches BiceLib's patches on, and the call that mends a queued model
PATCH_FILE = "script/bicelib_lua.lua"
_PATCH_CALL = re.compile(r"[.:]\s*fixQueuedHistoricalModel\s*\(")
_LONG_COMMENT = re.compile(r"--\[(=*)\[.*?\]\1\]", re.S)
_LINE_COMMENT = re.compile(r"--[^\n]*")


@dataclass
class Model:
    tag: str
    unit: str           # the type as the file writes it
    number: int
    file: str
    line: int
    levels: dict = field(default_factory=dict)      # lower technology -> level, as written


@dataclass
class Built:
    """What a queued brigade naming a model is built with."""
    model: Model
    rows: list          # (technology, the model's level or None, the level built or None)
    patched: tuple = None   # (file, line) of the call to BiceLib's mend, or None

    @property
    def misplaced(self):
        """The rows whose built level is not the model's for that technology."""
        return [r for r in self.rows if r[2] is not None and r[1] != r[2]]

    @property
    def unfilled(self):
        """The technologies the list runs out before, which the model gives a level to."""
        return [r for r in self.rows if r[2] is None and r[1] is not None]

    @property
    def wrong(self):
        """The rows built with a level other than the model's - a technology the model does
        not name counting as the 0 it would have on the map."""
        return [r for r in self.rows if r[2] is not None and (r[1] or "0") != r[2]]

    @property
    def lost(self):
        """The rows whose level, not 0, the list runs out before."""
        return [r for r in self.rows if r[2] is None and r[1] not in (None, "0")]

    @property
    def gap(self):
        """The first technology of the type the model does not name, or None."""
        return next((t for t, want, _ in self.rows if want is None), None)

    def landing(self):
        """Lower technology the model names -> the technology its level is built on in a
        production line: the n-th named goes to the type's n-th, or to itself where BiceLib
        mends it."""
        named = [t for t, want, _ in self.rows if want is not None]
        if self.patched:
            return {t.lower(): t for t in named}
        techs = [t for t, _, _ in self.rows]
        return {t.lower(): techs[i] for i, t in enumerate(named)}


class Models:
    def __init__(self, root, unit_techs, tags):
        """\\p unit_techs: lower type -> its technologies in order; \\p tags: the country
        tags, in any case."""
        self.unit_techs = unit_techs
        self.most = _defined_max(root)
        self.patched = patch_call(root)
        tags = {t.upper() for t in tags}
        self.by_key = {}        # (TAG, lower type, number) -> Model
        counts = {}             # (TAG, lower type) -> how many models it has
        for path in sorted(glob.glob(os.path.join(root, "units", "models", "*.txt")),
                           key=lambda p: os.path.basename(p).upper()):
            tag = os.path.basename(path).upper()[:3]
            if tag not in tags:
                continue        # a name that does not begin with a tag: the file is skipped
            rel = os.path.relpath(path, root).replace("\\", "/")
            text = lexer.read(root, rel).text
            for node in parser.parse(text).root.children:
                if not (node.is_block and node.key and "." in node.key):
                    continue
                unit, _, number = node.key.rpartition(".")
                if unit.lower() not in unit_techs or not number.isdigit():
                    continue
                number = int(number)
                key = (tag, unit.lower())
                have = counts.get(key, self.most)
                if number > have:
                    continue    # "error in model order": dropped
                if number == have:
                    counts[key] = have + 1
                model = Model(tag, unit, number, rel, node.line)
                for child in node.children:
                    if child.key and child.value is not None:
                        model.levels.setdefault(child.lkey, child.value)
                self.by_key[(tag, unit.lower(), number)] = model

    def model(self, tag, unit, number):
        """The country's model of that number from a file, or None - where the country has a
        default model or none."""
        return self.by_key.get((tag.upper(), unit.lower(), number))

    def exists(self, tag, unit, number):
        return number < self.most or self.model(tag, unit, number) is not None

    def built(self, tag, unit, number):
        """Built for a queued brigade of \\p unit naming model \\p number of \\p tag, or None
        where the model is a default one - which lists every technology and so is built
        right."""
        model = self.model(tag, unit, number)
        if model is None:
            return None
        techs = self.unit_techs.get(unit.lower(), [])
        if self.patched:
            given = [model.levels.get(t.lower(), "0") for t in techs]
        else:
            given = [model.levels[t.lower()] for t in techs if t.lower() in model.levels]
        rows = []
        for i, tech in enumerate(techs):
            rows.append((tech, model.levels.get(tech.lower()),
                         given[i] if i < len(given) else None))
        return Built(model, rows, self.patched)


@dataclass
class Queued:
    """A brigade of a production line in an order of battle that names a historical model."""
    file: str
    which: object       # the `historical_model` node
    brigade: object     # the brigade's block
    tag: str            # whose model, or None where nothing settles it
    how: str            # how the country is known
    number: int


def queued_brigades(root, unit_techs, leaders, tags):
    """Every Queued in history/units, in file order."""
    out = []
    for path in sorted(glob.glob(os.path.join(root, "history", "units", "**", "*.txt"),
                                 recursive=True)):
        with open(path, "rb") as handle:
            text = handle.read().decode("cp1252", errors="replace")
        if "historical_model" not in text or "military_construction" not in text:
            continue
        rel = os.path.relpath(path, root).replace("\\", "/")
        for line in parser.walk(parser.parse(text).root):
            if line.lkey != "military_construction" or not line.is_block:
                continue
            for brigade in line.children:
                which = brigade.child("historical_model") if brigade.is_block else None
                if which is None or not (which.value or "").isdigit() \
                        or brigade.lkey not in unit_techs:
                    continue
                tag, how = queued_country(rel, line, brigade, leaders, tags)
                out.append(Queued(rel, which, brigade, tag, how, int(which.value)))
    return out


def queued_country(rel, construction, brigade, leaders, tags):
    """(tag, how it is known) for \\p brigade of the `military_construction` block
    \\p construction in order of battle \\p rel, or (None, None).

    A brigade takes its country when its block is read: the `country` the line names above
    it, or else the country the line is queued for - the one whose history or `load_oob`
    loads the file. That last is known here only for a file a country's history loads at the
    start, so a file under `history/units/<TAG>/` or named `<TAG>_...` is taken to be that
    country's."""
    tag = None
    for child in construction.children:
        if child is brigade:
            break
        if child.lkey == "country" and child.value:
            tag = child.value.upper()
    if tag is not None:
        return tag, "the line's `country`"
    start = leaders.start_oob(rel) if leaders is not None else None
    if start is not None:
        return start[0], "%s's history loads the file" % start[0]
    parts = rel.split("/")
    if len(parts) > 3 and parts[2].upper() in tags:
        return parts[2].upper(), "the file is under history/units/%s/" % parts[2]
    name = os.path.basename(rel)
    if len(name) > 3 and name[:3].upper() in tags and not name[3].isalnum():
        return name[:3].upper(), "the file's name begins with %s" % name[:3].upper()
    return None, None


def patch_call(root):
    """(file, line) where the mod calls BiceLib's fixQueuedHistoricalModel, or None. A call
    inside a Lua comment does not count."""
    path = os.path.join(root, *PATCH_FILE.split("/"))
    if not os.path.exists(path):
        return None
    with open(path, "rb") as handle:
        text = handle.read().decode("cp1252", errors="replace").replace("\r", "")
    # Blank the comments out keeping their newlines, so a match's line is the file's.
    text = _LONG_COMMENT.sub(lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)
    text = _LINE_COMMENT.sub(lambda m: " " * len(m.group(0)), text)
    found = _PATCH_CALL.search(text)
    if found is None:
        return None
    return PATCH_FILE, text.count("\n", 0, found.start()) + 1


def _defined_max(root):
    for rel in ("common/defines.lua",):
        path = os.path.join(root, rel)
        if os.path.exists(path):
            with open(path, "rb") as handle:
                found = _DEFINE.search(handle.read().decode("cp1252", errors="replace"))
            if found:
                return int(found.group(1))
    return DEFAULT_MAX
