"""Names the mod's events and decisions use that nothing in the mod declares.

    python scriptcheck.py                 # the summary and the worst offenders
    python scriptcheck.py --all           # every one of them

An event or decision is written in the language `CTrigger::LoadKey` and `CEffect::LoadKey`
parse: a key is either one of their keywords (switchmap.py lists those), or the name of
something declared elsewhere - a technology, a unit type, a building, a country tag, a
decision. **A key that is none of those is silently dropped**, and the condition or effect
it belongs to quietly does nothing.

So: take every key the scripts use, subtract the two keyword lists, subtract every name
opened as a block anywhere in `common/`, `units/`, `map/`, `technologies/`, `events/` and
`decisions/`, subtract the technologies and country tags a running game holds, and look at
what is left.

Needs a running game for the technology list and the save tokens.
"""

import argparse
import collections
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hoi3
import switchmap

MOD = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))

TRIGGER_LOADER = 0x9C8D10
EFFECT_LOADER = 0x999CA0

# Keys that belong to an event or a decision's own shape rather than to the script
# language, so no database declares them and they are not slips.
STRUCTURE = {
    "country_event", "province_event", "id", "title", "desc", "picture", "option", "name",
    "trigger", "allow", "limit", "effect", "command", "is_triggered_only", "fire_only_once",
    "days", "date", "mean_time_to_happen", "modifier", "factor", "ai_chance", "ai_will_do",
    "decision", "potential", "value", "which", "type", "when", "months", "years", "style",
    "major", "random_list", "hidden", "persistent", "news_desc_long", "news_desc_medium",
    "news_desc_short", "news_title", "political_decisions", "country_decisions",
    "diplomatic_decisions", "where", "who", "duration", "day", "month", "year", "target",
    "amount", "power", "base", "add", "subtract", "multiply", "divide", "level", "unit",
    "leader", "province", "country", "state", "region", "tech", "priority", "range",
    "attacker_goal", "defender_goal", "war_goal", "capital_scope", "chance",
    "and", "or", "not", "nand", "nor", "if", "else", "invert",
    "this", "from", "root", "prev", "owner", "controller",
}

DECLARATION = re.compile(r"^[\t ]*([A-Za-z_][\w.\-]*)\s*=\s*\{", re.M)
USE = re.compile(r"(?<![\w.\"])([A-Za-z_][A-Za-z_0-9]*)\s*=")

SCRIPTS = ("events", "decisions")
DEFINITIONS = ("common", "units", "map", "technologies", "events", "decisions",
               "history", "gfx")


def read(path):
    try:
        return open(path, encoding="latin-1").read()
    except Exception:
        return ""


def keysIn(text):
    """
    The keys a file uses, with quoted strings and comments taken out first.

    **A quoted string can span lines.** `events/RSI-events.txt` has a `desc` whose text
    runs over eight of them, and read line by line its words look like keys - which is how
    `Dave = snek` came to be reported as a missing keyword. So the quote has to be tracked
    across the file rather than within a line.
    """
    out, inString = [], False
    for line in text.splitlines():
        kept = []
        for character in line:
            if character == '"':
                inString = not inString
            elif not inString:
                kept.append(character)
        out.extend(USE.findall("".join(kept).split("#")[0]))
    return out


def declaredNames():
    """Every name the mod opens a block for, anywhere."""
    out = set()
    for folder in DEFINITIONS:
        for path in glob.glob(os.path.join(MOD, folder, "**", "*.txt"), recursive=True):
            out.update(DECLARATION.findall(read(path)))
    return out


def liveNames():
    pm = hoi3.attach()
    u32, i32 = pm.read_uint, pm.read_int

    def string(a):
        length, capacity = i32(a + 0x10), i32(a + 0x14)
        if not (0 <= length < 4096):
            return None
        at = a if capacity < 16 else u32(a)
        try:
            text = pm.read_bytes(at, length).decode("latin-1")
        except Exception:
            return None
        return text if re.match(r"^[A-Za-z0-9_.\-]*$", text) else None

    out = {string(t + 0x20C) for t in hoi3.instances(pm, "CTechnology")}
    database = u32(pm.base_address + 0x16855A4)
    first, last = u32(database + 0x16C), u32(database + 0x170)
    for k in range((last - first) // 4):
        try:
            out.add(pm.read_bytes(u32(first + k * 4) + 0x1E4, 3).decode("latin-1"))
        except Exception:
            pass
    out.discard(None)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--all", action="store_true", help="list every name, not the top 40")
    args = parser.parse_args()

    tokens = switchmap.tokenNames()
    triggers = {tokens[t] for t in switchmap.cases(TRIGGER_LOADER) if tokens.get(t)}
    effects = {tokens[t] for t in switchmap.cases(EFFECT_LOADER) if tokens.get(t)}
    declared = declaredNames()
    live = liveNames()
    print("%d trigger keywords, %d effect keywords, %d names declared in files, "
          "%d live names" % (len(triggers), len(effects), len(declared), len(live)))

    known = set()
    for group in (triggers, effects, STRUCTURE, declared, live, set(tokens.values())):
        for item in group:
            known |= {item, item.lower(), item.upper()}

    used = collections.Counter()
    where = collections.defaultdict(set)
    for folder in SCRIPTS:
        for path in glob.glob(os.path.join(MOD, folder, "**", "*.txt"), recursive=True):
            for name in keysIn(read(path)):
                used[name] += 1
                where[name].add(os.path.basename(path))

    unknown = sorted(((n, k) for k, n in used.items()
                      if not ({k, k.lower(), k.upper()} & known)), reverse=True)
    print("\n%d distinct keys used, **%d that nothing declares** in %d uses"
          % (len(used), len(unknown), sum(n for n, _ in unknown)))

    print("\n%-48s %5s  %s" % ("name", "uses", "files"))
    for n, key in (unknown if args.all else unknown[:40]):
        print("%-48s %5d  %s" % (key, n, ", ".join(sorted(where[key])[:2])))

    byFile = collections.Counter()
    for n, key in unknown:
        for name in where[key]:
            byFile[name] += n
    print("\nworst files: %s" % byFile.most_common(8))


if __name__ == "__main__":
    main()
