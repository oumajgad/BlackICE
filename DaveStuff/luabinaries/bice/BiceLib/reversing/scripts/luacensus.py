# -*- coding: utf-8 -*-
r"""Which of the Lua API is reachable, and which of it anything actually uses.

    python scripts/luacensus.py                 the summary
    python scripts/luacensus.py --unreachable   just the classes Lua cannot obtain
    python scripts/luacensus.py --class CUnit   one class in detail
    python scripts/luacensus.py --json <path>   write the verdicts for buildFindings

**Why this exists.** `ghidra/luabind.json` is a third of the fact base and
`buildFindings.py` gives it **priority 0** - "what the game names wins" - so a Lua
registration's name *and type* outrank anything in `project.json` at the same offset. That
is right when the registration is live. It is wrong when the registration was abandoned,
because then nothing ever exercised it and its type was never checked against reality by
anyone, including the people who wrote it.

The live case that prompted this: **`CEventScope +0x10` reaches Ghidra as a 4-byte
`CCountryTag *` laid over the four characters of a country tag**, because luabind's
`def_readwrite` getter for a by-value member returns `T&` and the extractor recorded the
reference. Four bytes later, `from_country_tag` is the identical shape and is correctly
`char[4]` - because no Lua accessor is registered on it. So the generated type is wrong,
and `CEventScope` turns out to be a class **Lua cannot get hold of at all**.

## The two questions, which are different

**Reachable** - can a script obtain an instance? A class is reachable if it has a Lua
constructor, or if some member of a reachable class returns it, or a free function does.
Computed to a fixpoint. An **unreachable** class is dead weight: its registration cannot
be exercised from script however much a modder wants to.

**Used** - does any script in the corpus name it? Text census over both Lua corpora, by
the idiom the scripts actually use: a method is `obj:GetX(...)`, so the Lua-visible name is
the accessor's own name out of `evidence`; a `def_readwrite` field is `obj.name`.

The two come apart in both directions, which is why both are reported. A reachable class
nobody happens to call is ordinary - the API is wider than any one mod. **An unreachable
one is a different claim**: no mod could use it.

## What this cannot see, and the control for it

The engine also calls *into* Lua, so a class could in principle arrive as an argument to a
script entry point without being constructible or returned. That route is bounded here by
the corpus rather than by the bytes: the Lua the engine loads **is** the corpus, so a class
arriving that way would have to be received by a function in one of these files and used
without ever being named - possible, but it would also have to never appear in a type
check, a constructor call or a comment. For `CEventScope` and `CDecision` the corpus
mentions neither, in 108 vanilla files and 229 mod files. **Positive control** for the same
search: `GetCountryTag` matches 66 vanilla and 22 mod files, `PostAction` 23 and 4,
`CString` 12 and 12 - so the search is not blind.

The other limit is that this is a **text** census, not a call graph, so **"used" is an
upper bound.** Two kinds of collision inflate it: a member whose name matches a script's
own local function, and a member name registered on more than one class. Ten names are
registered on several classes - `GetCountryTag`, `GetType`, `GetSize`, `GetIndex`,
`GetKey`, `GetGroup`, `GetOwnerAI`, `GetPriority` and two more - and **11 classes have no
other evidence than one of them**: `CBuilding`, `CCountryTag`, `CDiplomaticAction`,
`CIdeology`, `CIdeologyGroup`, `CLaw`, `CLawGroup`, `CMinisterType`, `CRegion`,
`CTechnologyCategory`, `CTechnologyFolder`. `CWarGoal` is the plainest case: it is marked
used only because `GetCountry` matches 134 files, which will be `CCountry` work on other
classes rather than a war goal.

**This cannot reach the verdicts that matter.** A collision can only *add* matches, so a
class with zero matches on its own name and zero on every member really has none - which is
the whole of the DEAD set and the whole of the reachable-but-unused set. Only the "used"
figure is soft, and nothing downstream keys on it: `buildFindings.py` demotes a field only
when its class is unreachable **and** unmatched.
"""
import argparse
import collections
import io
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REVERSING = os.path.dirname(HERE)
LUABIND = os.path.join(REVERSING, "ghidra", "luabind.json")

# The Lua the engine loads. The mod's copy under the install's `tfh/mod/` is the deployed
# copy of the repo's `script/`, so it is excluded or every mod file counts twice.
CORPORA = [
    ("vanilla", [r"C:\Users\David\Hearts of Iron 3\script",
                 r"C:\Users\David\Hearts of Iron 3\tfh\script"]),
    ("mod", [r"C:\Users\David\GitHub\BlackICE\script",
             r"C:\Users\David\GitHub\BlackICE\common"]),
]

# A bare type name out of a signature or a field type: strip cv, refs, pointers, templates.
def baseType(spelled):
    if not spelled:
        return None
    t = str(spelled).strip()
    t = re.sub(r"\b(const|class|struct|volatile)\b", " ", t)
    t = t.replace("*", " ").replace("&", " ").strip()
    t = re.sub(r"<.*>", "", t).strip()
    t = t.split()[0] if t.split() else ""
    return t or None


def returnTypeOf(signature):
    """the return type of a luabind signature like `bool IsAllowed(CDecision&,CEventScope&)`"""
    if not signature:
        return None
    head = str(signature).split("(")[0].strip()
    parts = head.split()
    return baseType(" ".join(parts[:-1])) if len(parts) > 1 else None


def luaName(member):
    """the name a script writes.

    A luabind property registered from an accessor is reached as the accessor's own name -
    `obj:GetActor()`, not `obj.Actor` - which is what the vanilla AI scripts do throughout.
    A `def_readwrite` member is reached as the bare name with a dot.
    """
    evidence = str(member.get("evidence", ""))
    if evidence.startswith("accessor "):
        cpp = evidence[len("accessor "):].split(" at ")[0].strip()
        return cpp.split("::")[-1], "method"
    return member["name"], "property"


def loadCorpora():
    out = {}
    for name, roots in CORPORA:
        files = []
        for root in roots:
            if not os.path.isdir(root):
                continue
            for base, _, names in os.walk(root):
                if os.sep + "mod" + os.sep in base + os.sep:
                    continue
                for n in names:
                    if n.lower().endswith(".lua"):
                        files.append(os.path.join(base, n))
        texts = {}
        for path in files:
            try:
                texts[path] = io.open(path, encoding="latin-1").read()
            except IOError:
                pass
        out[name] = texts
    return out


def countWord(texts, word):
    """how many files contain `word` as a whole identifier"""
    pattern = re.compile(r"(?<![A-Za-z0-9_])" + re.escape(word) + r"(?![A-Za-z0-9_])")
    return sum(1 for t in texts.values() if pattern.search(t))


def reachability(api):
    """the set of class names a script can obtain an instance of"""
    byName = {}
    for c in api["classes"]:
        for key in (c.get("lua"), c.get("cpp"), c.get("rtti")):
            if key:
                byName.setdefault(key, c)

    produces = collections.defaultdict(set)      # class -> types its members hand back
    for c in api["classes"]:
        owner = c.get("cpp") or c.get("lua")
        for f in c.get("fields", []):
            t = baseType(f.get("type"))
            if t:
                produces[owner].add(t)
    for fn in api.get("functions", []):
        t = returnTypeOf(fn.get("signature"))
        if not t:
            continue
        if fn.get("kind") == "method":
            produces[fn.get("cpp_class") or fn.get("class")].add(t)
        else:
            produces["<free>"].add(t)

    # roots: anything constructible from script, plus whatever a free function returns
    reachable = set(produces["<free>"])
    for c in api["classes"]:
        if c.get("constructors"):
            reachable.add(c.get("cpp") or c.get("lua"))

    changed = True
    while changed:
        changed = False
        for owner in list(reachable):
            # a reachable class's bases are reachable: their members are callable on it
            c = byName.get(owner)
            for base in (c.get("bases") or []) if c else []:
                b = baseType(base if isinstance(base, str) else base.get("name"))
                if b and b not in reachable:
                    reachable.add(b)
                    changed = True
            for t in produces.get(owner, ()):
                if t not in reachable:
                    reachable.add(t)
                    changed = True
    return reachable & set(n for n in byName), byName


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--unreachable", action="store_true",
                    help="only the classes a script cannot obtain")
    ap.add_argument("--unused", action="store_true",
                    help="reachable classes that no script in either corpus names")
    ap.add_argument("--class", dest="only", help="one class in detail")
    ap.add_argument("--json", help="write the per-class verdicts here")
    args = ap.parse_args()

    api = json.load(io.open(LUABIND, encoding="utf-8"))
    corpora = loadCorpora()
    reachable, byName = reachability(api)

    rows = []
    for c in sorted(api["classes"], key=lambda x: x.get("cpp") or x.get("lua")):
        owner = c.get("cpp") or c.get("lua")
        members = []
        for f in c.get("fields", []):
            name, kind = luaName(f)
            counts = {k: countWord(t, name) for k, t in corpora.items()}
            members.append({"field": f["name"], "lua": name, "kind": kind,
                            "offset": f.get("offset"), "type": f.get("type"),
                            "readwrite": str(f.get("evidence", "")).startswith("luabind def_"),
                            "uses": counts, "used": sum(counts.values()) > 0})
        classCounts = {k: countWord(t, c.get("lua") or owner) for k, t in corpora.items()}
        rows.append({"class": owner, "lua": c.get("lua"),
                     "reachable": owner in reachable,
                     "constructible": bool(c.get("constructors")),
                     "class_named": sum(classCounts.values()) > 0,
                     "class_uses": classCounts,
                     "members": members,
                     "members_used": sum(1 for m in members if m["used"]),
                     "members_total": len(members)})

    if args.only:
        for r in rows:
            if args.only in (r["class"], r["lua"]):
                print(json.dumps(r, indent=1))
        return

    if args.unused:
        # How a class is obtained, so the list says what a script would have to call to get
        # one. Recomputed here rather than stored: `luausage.json` carries the verdict, and
        # the route to it is a property of luabind.json.
        producers = collections.defaultdict(set)
        for c in api["classes"]:
            owner = c.get("cpp") or c.get("lua")
            for f in c.get("fields", []):
                t = baseType(f.get("type"))
                if t:
                    name, _ = luaName(f)
                    producers[t].add("%s:%s" % (owner, name))
        for fn in api.get("functions", []):
            t = returnTypeOf(fn.get("signature"))
            if not t:
                continue
            if fn.get("kind") == "method":
                producers[t].add("%s:%s" % (fn.get("cpp_class") or fn.get("class"),
                                            fn.get("lua_name")))
            else:
                producers[t].add("%s()" % fn.get("lua_name"))

        group = [r for r in rows if r["reachable"]
                 and not (r["class_named"] or r["members_used"])]
        print("Reachable from script, but no script in either corpus names the class or any")
        print("of its members. **These are not a problem** - the API is wider than any one mod,")
        print("and these keep their priority-0 privilege in buildFindings.py. Listed so the")
        print("distinction from the seven dead classes stays visible.")
        print()
        print("  %-32s %-5s %-6s %s" % ("class", "ctor", "membs", "how a script would get one"))
        print("  " + "-" * 104)
        for r in group:
            how = sorted(producers.get(r["class"], ()))
            shown = ", ".join(how[:3]) + (" +%d more" % (len(how) - 3) if len(how) > 3 else "")
            print("  %-32s %-5s %-6d %s"
                  % (r["class"], "yes" if r["constructible"] else "-", r["members_total"],
                     shown or ("constructor only" if r["constructible"] else "?")))
        print()
        print("  %d classes, %d registered members between them"
              % (len(group), sum(r["members_total"] for r in group)))
        return

    if args.unreachable:
        print("Classes with no constructor and nothing returning one, split by whether any")
        print("script nevertheless uses them - which means the engine hands them in.")
        print()
        for label, want in (("ENGINE-PUSHED - live, arrives as a callback's self or argument", True),
                            ("DEAD - unreachable and nothing names it or any member", False)):
            group = [r for r in rows if not r["reachable"]
                     and bool(r["class_named"] or r["members_used"]) == want]
            print("%s  (%d)" % (label, len(group)))
            print("  %-34s %-6s %-7s %s" % ("class", "membs", "named?", "members used"))
            for r in group:
                print("  %-34s %-6d %-7s %s"
                      % (r["class"], r["members_total"],
                         "yes" if r["class_named"] else "no",
                         ", ".join(m["lua"] for m in r["members"] if m["used"]) or "none"))
            print()
        return

    used = lambda r: bool(r["class_named"] or r["members_used"])
    live = [r for r in rows if r["reachable"]]
    pushed = [r for r in rows if not r["reachable"] and used(r)]
    dead = [r for r in rows if not r["reachable"] and not used(r)]
    usedClasses = [r for r in live if used(r)]
    print("Lua API census  (%s)" % api.get("source", LUABIND))
    print("  corpora: " + ", ".join("%s %d files" % (k, len(v)) for k, v in corpora.items()))
    print()
    print("  classes registered          %4d" % len(rows))
    print("    reachable from script     %4d  (constructible, or something returns one)" % len(live))
    print("      of those, something uses%4d" % len(usedClasses))
    print("      reachable but unused    %4d" % (len(live) - len(usedClasses)))
    print("    engine-pushed             %4d  (not obtainable, but scripts use it anyway -" % len(pushed))
    print("                                    so it arrives as a callback's self/argument)")
    print("    DEAD                      %4d  <- unreachable AND nothing names it" % len(dead))
    print("                                    (%d classes: %s)"
          % (len(dead), ", ".join(r["class"] for r in dead)))
    fields = [m for r in rows for m in r["members"]]
    print()
    print("  members registered          %4d" % len(fields))
    print("    used by some script       %4d" % sum(1 for m in fields if m["used"]))
    print("    on a DEAD class           %4d" % sum(1 for r in dead for m in r["members"]))
    rw = [m for r in rows for m in r["members"] if m["readwrite"]]
    print()
    print("  def_readwrite members       %4d  (the direct member bindings)" % len(rw))
    print("    used                      %4d" % sum(1 for m in rw if m["used"]))
    print("    typed as a reference      %4d  <- the `T&` artefact; the member is a T by value"
          % sum(1 for m in rw if str(m["type"]).rstrip().endswith("&")))

    if args.json:
        io.open(args.json, "w", encoding="utf-8").write(
            json.dumps({"about": "written by scripts/luacensus.py", "classes": rows},
                       indent=1, ensure_ascii=False))
        print()
        print("wrote %s" % args.json)


if __name__ == "__main__":
    main()
