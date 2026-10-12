"""Every name the mod declares, which a script key may be instead of a keyword.

A key that is not a keyword falls through to a lookup: a province id, an ideology, then
the game's databases, ending in the technologies (reversing/findings/FINDINGS-script.md,
"How the two loaders work"). So `industry = 3` works because `industry` is a building,
and `infanty_brigade = 1` is silently dropped because nothing is called that.

BlackICE replaces `common`, `map`, `technologies`, `units`, `localisation` and the script
folders outright (see its .mod file), so the mod alone declares everything - the game
install is not needed.
"""

import csv
import glob
import io
import os

from . import lexer, parser


class Kinds:
    TAG = "country tag"
    TECH = "technology"
    THEORY = "theory"
    PRACTICAL = "practical"
    BUILDING = "building"
    UNIT = "unit type"
    IDEOLOGY = "ideology"
    IDEOLOGY_GROUP = "ideology group"
    POSITION = "government position"
    LAW = "law"
    LAW_GROUP = "law group"
    REGION = "region"
    CONTINENT = "continent"
    PROVINCE = "province id"
    MODIFIER = "event modifier"
    RESOURCE = "strategic resource"
    GOVERNMENT = "government"
    FACTION = "faction"


# Names a script key may be, with the file each is declared in. Ordered as a reader would
# want them reported: what a name *is*, most specific first.
KEY_KINDS = (Kinds.TECH, Kinds.THEORY, Kinds.PRACTICAL, Kinds.BUILDING, Kinds.UNIT,
             Kinds.IDEOLOGY, Kinds.IDEOLOGY_GROUP, Kinds.POSITION, Kinds.LAW_GROUP,
             Kinds.TAG, Kinds.REGION)


def _parse_file(root, rel):
    """(source, parse result) for \\p rel, or None if it does not exist."""
    if not os.path.exists(os.path.join(root, rel)):
        return None
    source = lexer.read(root, rel)
    return source, parser.parse(source.text)


def _rel(root, path):
    return os.path.relpath(path, root).replace("\\", "/")


class Declarations:
    def __init__(self, root, load=None):
        """\\p load(rel) -> (source, result) or None lets a caller share its parse cache,
        so a file both declared from and checked is only read once."""
        self.root = root
        self._load_file = load or (lambda rel: _parse_file(root, rel))
        self.names = {}     # kind -> {lower name: (written name, file, line)}
        self.missing = []   # files expected and not found
        for kind in vars(Kinds).values():
            if isinstance(kind, str) and not kind.startswith("_"):
                self.names.setdefault(kind, {})
        self._load()

    def add(self, kind, name, file, line):
        self.names[kind].setdefault(name.lower(), (name, file, line))

    def has(self, kind, name):
        return name.lower() in self.names[kind]

    def where(self, kind, name):
        return self.names[kind].get(name.lower())

    def resolve_key(self, key):
        """What kind of declared name \\p key is, or None. Province ids are numbers."""
        if key.isdigit():
            return Kinds.PROVINCE
        low = key.lower()
        for kind in KEY_KINDS:
            if low in self.names[kind]:
                return kind
        return None

    def _tree(self, rel):
        loaded = self._load_file(rel)
        return loaded[1].root if loaded is not None else None

    def _blocks(self, rel, kind, depth=0):
        """Declare every block name at \\p depth of \\p rel as \\p kind."""
        tree = self._tree(rel)
        if tree is None:
            self.missing.append(rel)
            return None
        level = [tree]
        for _ in range(depth):
            level = [c for n in level for c in n.children if c.is_block]
        for node in level:
            for c in node.children:
                if c.is_block and c.key is not None:
                    self.add(kind, c.key, rel, c.line)
        return tree

    def _load(self):
        root = self.root
        tree = self._tree("common/countries.txt")
        if tree is None:
            self.missing.append("common/countries.txt")
        else:
            for c in tree.children:
                if c.is_pair and c.key:
                    self.add(Kinds.TAG, c.key, "common/countries.txt", c.line)

        for path in sorted(glob.glob(os.path.join(root, "technologies", "*.txt"))):
            self._blocks(_rel(root, path), Kinds.TECH)

        tree = self._tree("common/technology.txt")
        if tree is not None:
            for group, kind in (("theoretical", Kinds.THEORY), ("practical", Kinds.PRACTICAL)):
                node = tree.child(group)
                for c in (node.children if node is not None and node.is_block else ()):
                    if c.op is None and c.key:
                        self.add(kind, c.key, "common/technology.txt", c.line)

        self._blocks("common/buildings.txt", Kinds.BUILDING)
        for path in sorted(glob.glob(os.path.join(root, "units", "*.txt"))):
            self._blocks(_rel(root, path), Kinds.UNIT)

        tree = self._tree("common/ideologies.txt")
        if tree is not None:
            for group in tree.children:
                if group.is_block and group.key:
                    self.add(Kinds.IDEOLOGY_GROUP, group.key, "common/ideologies.txt", group.line)
                    for c in group.children:
                        # An ideology is a block with a colour; the group's own fields
                        # (faction, position) are not.
                        if c.is_block and c.child("color") is not None:
                            self.add(Kinds.IDEOLOGY, c.key, "common/ideologies.txt", c.line)
                        elif c.is_block and c.lkey == "faction":
                            tag = c.child("tag")
                            if tag is not None and tag.value:
                                self.add(Kinds.FACTION, tag.value, "common/ideologies.txt",
                                         tag.line)

        self._blocks("common/governments.txt", Kinds.GOVERNMENT)

        self._blocks("common/government_positions.txt", Kinds.POSITION)
        tree = self._blocks("common/laws.txt", Kinds.LAW_GROUP)
        if tree is not None:
            for group in tree.children:
                for c in group.children or ():
                    if c.is_block and c.key:
                        self.add(Kinds.LAW, c.key, "common/laws.txt", c.line)

        self._blocks("map/region.txt", Kinds.REGION)
        self._blocks("map/continent.txt", Kinds.CONTINENT)
        self._blocks("common/event_modifiers.txt", Kinds.MODIFIER)
        self._blocks("common/strategic_resources.txt", Kinds.RESOURCE)

        definition = os.path.join(root, "map", "definition.csv")
        if os.path.exists(definition):
            with open(definition, "rb") as handle:
                text = handle.read().decode("cp1252", errors="replace")
            for number, row in enumerate(csv.reader(io.StringIO(text), delimiter=";"), 1):
                if row and row[0].strip().isdigit():
                    self.add(Kinds.PROVINCE, row[0].strip(), "map/definition.csv", number)
        else:
            self.missing.append("map/definition.csv")
