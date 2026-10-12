"""What each kind of data file may hold: orders of battle, histories, technologies, unit
types, the files of common/ and map/.

Events and decisions are checked against the keyword lists the game's two script loaders
switch over (schema.py). Every other file is read by a loader of its own, so each kind of
file has a schema here: one JSON file in this folder, which says where the kind of file
lives and, block by block, which keys it takes and what each key's value is.

    {
      "kind": "oob",                          a short id, used in messages
      "title": "Order of battle",             what a reader calls this kind of file
      "files": ["history/units/**/*.txt"],    where it is, relative to the mod
      "doc": "docs/script/oob.md",            where a modder reads about it, if anywhere
      "source": "...",                        where the schema's facts come from
      "root": "file",                         the block the file's top level is
      "blocks": {
        "file": {
          "keys": {
            "corps": {"value": "block:formation", "repeat": true,
                      "confidence": "confirmed", "desc": "a land formation"}
          },
          "patterns": [
            {"match": "date", "value": "block:file", "desc": "applied on that date"}
          ],
          "list": "integer",                  bare items the block may hold, and of what
          "open": false                       true: keys not listed are not reported
        }
      }
    }

A key's entry:

| | |
| --- | --- |
| `value` | what its value is - see VALUES below |
| `repeat` | true when the key may be given more than once and each one counts |
| `required` | true when leaving it out is a fault |
| `confidence` | `confirmed` when read out of the game, `inferred` when taken from how the mod writes it. A block takes the confidence of its keys unless it gives its own |
| `desc` | one line for hover and completion |

A pattern's `match` is one of `date`, `integer`, `number`, `modifier name`,
`unit type.number`, `any`, or a kind of name - any value kind that names something, such
as `technology`, `unit type`, `tag`, `province`, or `name:<kind>`.

VALUES are the kinds a value may be. A `block:<name>` value is a block of that name in the
same schema; `list:<kind>` a block of bare items of that kind; `name:<kind>` a name some
schema declares (below); the rest are single values.

Two more things a schema may say:

- `"declares": [{"kind": "trait", "depth": 0}]` - the keys at that depth of its files are
  names of that kind, which other schemas can then ask for as `name:trait`. With
  `"field": "id"` the name is instead the value of that key inside each block, as a
  leader's `id`; with `"items": true` it is each bare word, as a list of graphical
  cultures; with `"under": ["spriteTypes"]` only blocks of those keys at the level above
  count, so a file's sprites and its fonts can be two kinds.

A value `exactly:a|b` is `one of:` compared with case, for a loader that compares exactly.
A block with `"skips_unknown": true` has a loader that drops an unknown key's block whole.
- `"include": ["country:file"]` in a block - that block also takes every key and pattern of
  block `file` of the schema of kind `country`, for a file read by the same loader as
  another kind.
"""

import glob
import json
import os
import re

VALUES = {
    "any": "anything",
    "text": "a word or quoted text",
    "number": "a number",
    "integer": "a whole number",
    "yes/no": "yes or no",
    "date": "a date like 1936.1.1",
    "province": "a province id",
    "tag": "a country tag",
    "unit type": "a unit type from units/",
    "technology": "a technology",
    "building": "a building from common/buildings.txt",
    "ideology": "an ideology",
    "ideology group": "an ideology group",
    "government": "a government",
    "law": "a law",
    "law group": "a law group",
    "position": "a government position",
    "region": "a region",
    "continent": "a continent",
    "event modifier": "a modifier from common/event_modifiers.txt",
    "strategic resource": "a strategic resource",
    "faction": "a faction",
    "oob file": "a file in history/units/",
    "triggers": "a block of conditions",
    "effects": "a block of effects",
    "modifiers": "a block of modifier = number",
    "model": "a list of technology levels, one per technology of the unit type",
    "colour": "a colour: three numbers, or four with alpha",
    "chance": "a block of `factor` and `modifier` blocks, as an option's `ai_chance`",
}

# Value kinds that name something the mod declares, by declarations.Kinds name.
DECLARED = {
    "province": "province id", "tag": "country tag", "unit type": "unit type",
    "technology": "technology", "building": "building", "ideology": "ideology",
    "ideology group": "ideology group", "government": "government", "law": "law",
    "law group": "law group", "position": "government position", "region": "region",
    "continent": "continent", "event modifier": "event modifier",
    "strategic resource": "strategic resource", "faction": "faction",
}

FOLDER = os.path.dirname(os.path.abspath(__file__))


class SchemaError(Exception):
    """A schema file that does not make sense: a fault in the tool, not in the mod."""


class Schema:
    def __init__(self, data, path):
        self.path = path
        self.kind = data["kind"]
        self.title = data.get("title", self.kind)
        self.files = [p.replace("\\", "/") for p in data["files"]]
        self.doc = data.get("doc", "")
        self.source = data.get("source", "")
        self.declares = data.get("declares", [])
        self.blocks = {}
        for name, block in data["blocks"].items():
            self.blocks[name] = Block(self, name, block)
        self.root = self.blocks[data.get("root", "file")]

    def matches(self, rel):
        low = rel.lower()
        return any(_match(low, pattern.lower()) for pattern in self.files)

    def __repr__(self):
        return "<Schema %s>" % self.kind


def _match(rel, pattern):
    """\\p pattern against \\p rel, with `**/` matching any number of folders."""
    regex = ""
    i = 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            regex += "(?:.*/)?"
            i += 3
        elif pattern[i] == "*":
            regex += "[^/]*"
            i += 1
        elif pattern[i] == "?":
            regex += "[^/]"
            i += 1
        else:
            regex += re.escape(pattern[i])
            i += 1
    return re.fullmatch(regex, rel) is not None


class Key:
    """What one key, or one pattern of keys, takes."""

    def __init__(self, block, name, data):
        if isinstance(data, str):
            data = {"value": data}
        self.block = block
        self.name = name
        self.value = data.get("value", "any")
        self.repeat = bool(data.get("repeat", False))
        self.required = bool(data.get("required", False))
        self.confidence = data.get("confidence", block.confidence)
        self.desc = data.get("desc", "")
        self.match = data.get("match")          # for a pattern
        self.target = None                      # the Block a block:<name> value is

    @property
    def is_block(self):
        return self.value.startswith("block:")

    @property
    def is_list(self):
        return self.value.startswith("list:")

    def describe(self):
        """The kind of value, as a reader would put it."""
        if self.is_block:
            return "a block"
        if self.is_list:
            return "a list of %s" % _plural(self.value[5:])
        return describe_value(self.value)


def describe_value(value):
    """A value kind as a reader would put it."""
    for prefix, how in (("one of:", "one of "), ("exactly:", "exactly one of ")):
        if value.startswith(prefix):
            return how + ", ".join("`%s`" % v.strip() for v in value[len(prefix):].split("|"))
    if value.startswith("name:"):
        return "a " + value[5:]
    return VALUES.get(value, value)


def _plural(kind):
    return {"integer": "whole numbers", "number": "numbers", "province": "province ids",
            "tag": "country tags", "text": "words"}.get(kind, kind + "s")


class Block:
    def __init__(self, schema, name, data):
        self.schema = schema
        self.name = name
        self.confidence = data.get("confidence", "inferred")
        self.desc = data.get("desc", "")
        self.open = bool(data.get("open", False))
        # True where the loader drops an unknown key's block whole, as the model files'
        # does, instead of reading its contents as its own keys.
        self.skips_unknown = bool(data.get("skips_unknown", False))
        self.list = data.get("list")
        self.keys = {k.lower(): Key(self, k, v) for k, v in data.get("keys", {}).items()}
        self.patterns = [Key(self, p.get("match", "any"), p) for p in data.get("patterns", [])]
        self.include = data.get("include", [])

    def included(self, registry):
        """The blocks this one includes; raises for one that is not defined."""
        out = []
        for reference in self.include:
            kind, _, name = reference.partition(":")
            other = registry.by_kind.get(kind)
            if other is None or name not in other.blocks:
                raise SchemaError("%s: block `%s` includes `%s`, which is not defined"
                                  % (self.schema.path, self.name, reference))
            out.append(other.blocks[name])
        return out

    def merge(self, registry):
        for other in self.included(registry):
            for low, key in other.keys.items():
                self.keys.setdefault(low, key)
            self.patterns += [p for p in other.patterns if p not in self.patterns]
            if other.list and not self.list:
                self.list = other.list
        self.include = []

    def resolve(self):
        for key in list(self.keys.values()) + self.patterns:
            value = key.value
            if key.is_block and key.block is self:
                name = value[6:]
                if name not in self.schema.blocks:
                    raise SchemaError("%s: block `%s` names block `%s`, which is not "
                                      "defined" % (self.schema.path, self.name, name))
                key.target = self.schema.blocks[name]
            elif not (key.is_block or key.is_list or value in VALUES
                      or value.startswith(("one of:", "exactly:", "name:"))):
                raise SchemaError("%s: key `%s` in block `%s` has unknown value `%s`"
                                  % (self.schema.path, key.name, self.name, value))

    def find(self, key, is_pattern_match):
        """The Key that \\p key falls under here, or None. \\p is_pattern_match(match, key)
        says whether a pattern takes it."""
        found = self.keys.get(key.lower())
        if found is not None:
            return found
        for pattern in self.patterns:
            if is_pattern_match(pattern.match, key):
                return pattern
        return None


class Registry:
    """Every schema in this folder - or in the folders BICEVALIDATOR_SCHEMAS lists, which is
    how a schema is tried out before it is put here."""

    def __init__(self, folders=None):
        if folders is None:
            listed = os.environ.get("BICEVALIDATOR_SCHEMAS")
            folders = listed.split(os.pathsep) if listed else [FOLDER]
        self.schemas = []
        paths = [p for folder in folders for p in glob.glob(os.path.join(folder, "*.json"))]
        for path in sorted(paths, key=os.path.basename):
            with open(path, encoding="utf-8") as handle:
                try:
                    data = json.load(handle)
                except ValueError as error:
                    raise SchemaError("%s: %s" % (path, error))
            self.schemas.append(Schema(data, os.path.basename(path)))
        self.by_kind = {s.kind: s for s in self.schemas}
        blocks = [b for s in self.schemas for b in s.blocks.values()]
        # A block merges what it includes once those have merged theirs, so a chain of
        # includes arrives whole; a loop of them never settles and is a schema fault.
        pending = [b for b in blocks if b.include]
        while pending:
            ready = [b for b in pending
                     if not any(o.include for o in b.included(self))]
            if not ready:
                raise SchemaError("includes that go round in a loop: %s"
                                  % ", ".join("%s:%s" % (b.schema.kind, b.name)
                                              for b in pending))
            for block in ready:
                block.merge(self)
            pending = [b for b in pending if b.include]
        for block in blocks:
            block.resolve()
        self._cache = {}

    def declared_kinds(self):
        """{kind: [(schema, declaration)]} of every name a schema declares."""
        out = {}
        for schema in self.schemas:
            for declaration in schema.declares:
                out.setdefault(declaration["kind"], []).append((schema, declaration))
        return out

    def for_file(self, rel):
        """The schema \\p rel is read by, or None. The most specific pattern wins: one
        naming the file outright beats a folder's wildcard."""
        if rel in self._cache:
            return self._cache[rel]
        best, best_score = None, None
        for schema in self.schemas:
            for pattern in schema.files:
                if _match(rel.lower(), pattern.lower()):
                    score = (pattern.count("*") == 0, len(pattern) - pattern.count("*") * 5)
                    if best_score is None or score > best_score:
                        best, best_score = schema, score
        self._cache[rel] = best
        return best

    def __getstate__(self):
        return {"schemas": self.schemas, "_cache": {}}
