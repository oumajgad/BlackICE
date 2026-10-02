"""Parse every interface/*.gui into (name -> declaring keyword, depth, file).

Crude but sufficient: track brace depth and remember the keyword that opened each
block, so `name = "x"` inside it is attributed to that keyword.
"""
import os, re, sys, json, collections

ROOT = r"c:\Users\David\GitHub\BlackICE\interface"
TOK = re.compile(r'"[^"]*"|[^\s{}=]+|[{}=]')

out = {}
dupes = collections.Counter()
tops = {}

for fn in sorted(os.listdir(ROOT)):
    if not fn.lower().endswith(".gui"):
        continue
    text = open(os.path.join(ROOT, fn), encoding="latin-1").read()
    text = re.sub(r"#[^\n]*", "", text)
    toks = TOK.findall(text)
    stack = []          # keyword that opened each open block
    pending = None      # last bare identifier seen
    i = 0
    while i < len(toks):
        t = toks[i]
        if t == "{":
            stack.append(pending or "?")
            pending = None
        elif t == "}":
            if stack:
                stack.pop()
        elif t == "=":
            pass
        elif t.startswith('"'):
            pending = None
        else:
            if i + 1 < len(toks) and toks[i + 1] == "=" and i + 2 < len(toks):
                key = t
                val = toks[i + 2]
                if key.lower() == "name" and val.startswith('"'):
                    nm = val[1:-1]
                    kw = stack[-1] if stack else "?"
                    depth = len(stack)
                    if nm in out:
                        dupes[nm] += 1
                    out[nm] = (kw, depth, fn)
                    if depth == 2:   # guiTypes { <kw> { name } }  -> top level entry
                        tops[nm] = (kw, fn)
                    i += 2
                else:
                    pending = t
                    i += 2
                    continue
            else:
                pending = t
        i += 1

json.dump({"all": out, "top": tops}, open("guinames.json", "w"))
print("names: %d  top-level: %d  duplicate names: %d" % (len(out), len(tops), len(dupes)))
print("top-level by keyword:")
for k, c in collections.Counter(v[0] for v in tops.values()).most_common():
    print("   %-28s %d" % (k, c))
print("all by keyword:")
for k, c in collections.Counter(v[0] for v in out.values()).most_common():
    print("   %-28s %d" % (k, c))
