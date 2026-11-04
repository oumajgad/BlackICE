"""Moves the resource icons on the map to free places in their provinces.

    python tools/placeResourceIcons.py                 # a report only; writes nothing
    python tools/placeResourceIcons.py --write         # rewrites map/positions.txt
    python tools/placeResourceIcons.py --preview p.png --region 2700,1550,2950,1700 --zoom 6

**positions.txt has no key for a resource icon.** The game draws the icons of crude oil,
metal, energy and rare materials at the position of a *building* - the one whose slot in
common/buildings.txt matches the good's slot in the goods pool (supplies, fuel, money, crude
oil, metal, energy, rare materials), slot 0 being the engine's own `nobuilding`. Read out of
hoi3_tfh.exe; reversing/findings/FINDINGS-resourceicons.md has the reading. For BlackICE's
buildings.txt that is:

    crude oil       -> coastal_fort     drawn on the map too, so a fort stands on the oil
    metal           -> beach_defence    not drawn, so this point is the icon's alone
    energy          -> land_fort        drawn on the map too
    rare materials  -> fortress         drawn on the map too

Vanilla's order put them on coastal_fort, land_fort, anti_air and radar_station, every one of
which its positions.txt declares. BlackICE's beach_defence and fortress moved the goods onto
two buildings the file hardly declares, and an undeclared position is (0, 0). The script works
the four keys out of buildings.txt itself, so it stays right if the order changes again.

What it does, for every land province that produces one of the four goods:

1. keeps the good's point where it is if it is declared, inside the province, at least
   --border pixels from every neighbouring province and --shore from the sea, and at least
   --keep-gap pixels from everything else drawn there;
2. otherwise puts it on one of the province's pixels that are --border and --shore off its
   edges - so that an icon is not taken for its neighbour's - choosing the one farthest from
   everything else drawn there, up to --gap pixels, then the one deepest inside, then the one
   nearest the middle. A province too small to have such pixels gives its deepest ones, and
   one with no --gap clear gives the best there is; the report lists both.

"Everything else" is every point that draws something: the position of each building with
`onmap = yes`, the other resource icons, the unit counter (`unit`), the name (`text_position`)
and the strategic resource icon, which stands on the middle of the province's bounding box and
cannot be moved. Points of neighbouring provinces count too.

A point shared with a building moves that building's picture as well - the engine has one
point for both. Oil's point is coastal_fort's, so where it has to move it is kept within a few
pixels of the sea.

Only the four keys are ever written, and only in provinces producing their good; every other
byte of the file is left as it was.
"""

import argparse
import math
import os
import re
import sys

import numpy as np

# The goods pool's order, and the history key of each of the four drawn goods.
GOODS = ["supplies", "fuel", "money", "crude_oil", "metal", "energy", "rare_materials"]
DRAWN = [3, 4, 5, 6]
GOOD_LABEL = {"crude_oil": "oil", "metal": "metal", "energy": "energy", "rare_materials": "rare"}

TOKEN = re.compile(r'#[^\n]*|"[^"]*"|[{}=]|[^\s{}=#"]+')


# ---------------------------------------------------------------- Clausewitz files


class Block:
    """a { } block: its (key, key offset, value) items, and where its braces are"""

    __slots__ = ("items", "open", "close")

    def __init__(self, items, open_, close):
        self.items = items
        self.open = open_
        self.close = close

    def get(self, key):
        for k, _, v in self.items:
            if k == key:
                return v
        return None

    def keyOffset(self, key):
        for k, s, _ in self.items:
            if k == key:
                return s
        return None


def parse(text):
    """the whole file as a Block; a leaf value is (text, start, end)"""
    toks = [(m.group(), m.start(), m.end()) for m in TOKEN.finditer(text) if m.group()[0] != "#"]
    pos = 0

    def block(open_):
        nonlocal pos
        items = []
        while pos < len(toks):
            t, s, e = toks[pos]
            if t == "}":
                pos += 1
                return Block(items, open_, s)
            if pos + 1 < len(toks) and toks[pos + 1][0] == "=":
                pos += 2
                if pos < len(toks) and toks[pos][0] == "{":
                    pos += 1
                    items.append((t, s, block(toks[pos - 1][1])))
                elif pos < len(toks):
                    items.append((t, s, toks[pos]))
                    pos += 1
            elif t == "{":
                pos += 1
                items.append((None, s, block(s)))
            else:
                pos += 1
                items.append((None, s, (t, s, e)))
        return Block(items, open_, len(text))

    return block(-1)


def point(value):
    """(x, y, x token, y token) of a { x= y= } block, or None"""
    if not isinstance(value, Block):
        return None
    x, y = value.get("x"), value.get("y")
    try:
        return float(x[0]), float(y[0]), x, y
    except (TypeError, ValueError):
        return None


def readText(path):
    # latin-1 maps every byte to one character and back, so nothing is lost on a rewrite;
    # the files are Windows-1252 and only ASCII is ever matched or written.
    with open(path, "rb") as f:
        return f.read().decode("latin-1")


# ---------------------------------------------------------------- the mod's data


def readBuildings(path):
    """[(name, onmap, port)] in file order; slot k of the engine's list is entry k - 1"""
    out = []
    for name, _, value in parse(readText(path)).items:
        if name and isinstance(value, Block):
            flag = lambda key: (value.get(key) or ("no",))[0] == "yes"
            out.append((name, flag("onmap"), flag("port")))
    return out


def readDefinitions(path):
    colours, names = {}, {}
    for line in readText(path).splitlines()[1:]:
        cells = line.split(";")
        try:
            pid, r, g, b = (int(c) for c in cells[:4])
        except (ValueError, IndexError):
            continue
        colours[(r << 16) | (g << 8) | b] = pid
        names[pid] = cells[4] if len(cells) > 4 else ""
    return colours, names


def readSeaIds(path):
    value = parse(readText(path)).get("sea_starts")
    return {int(t) for _, _, (t, _, _) in value.items} if isinstance(value, Block) else set()


def readHistory(folder):
    """{province: set of drawn goods it ever produces}, {province: has a strategic resource}"""
    goods, strategic = {}, set()
    wanted = {GOODS[i] for i in DRAWN}
    for root, _, files in os.walk(folder):
        for name in files:
            m = re.match(r"(\d+)", name)
            if not m or not name.lower().endswith(".txt"):
                continue
            pid = int(m.group(1))
            toks = [t.group() for t in TOKEN.finditer(readText(os.path.join(root, name)))
                    if t.group()[0] != "#"]
            for i in range(len(toks) - 2):
                if toks[i + 1] != "=":
                    continue
                key, value = toks[i], toks[i + 2]
                if key in wanted:
                    try:
                        if float(value) > 0:
                            goods.setdefault(pid, set()).add(key)
                    except ValueError:
                        pass
                elif key == "strategic_resource" and value.strip('"') != "none":
                    strategic.add(pid)
    return goods, strategic


def readProvinceMap(path, colours):
    """the province id of every pixel, indexed [y][x] with y growing north as positions.txt has it"""
    raw = open(path, "rb").read()
    offset = int.from_bytes(raw[10:14], "little")
    width = int.from_bytes(raw[18:22], "little", signed=True)
    height = int.from_bytes(raw[22:26], "little", signed=True)
    if int.from_bytes(raw[28:30], "little") != 24:
        sys.exit("provinces.bmp is not 24-bit")
    stride = (width * 3 + 3) // 4 * 4
    rows = abs(height)
    bgr = np.frombuffer(raw, np.uint8, rows * stride, offset).reshape(rows, stride)[:, :width * 3]
    bgr = bgr.reshape(rows, width, 3)
    if height < 0:
        bgr = bgr[::-1]
    # Which way up this leaves the map is settled against positions.txt in main(): the mod's
    # provinces.bmp says bottom-up in its header and is the other way round against the file.
    key =(bgr[..., 2].astype(np.uint32) << 16) | (bgr[..., 1].astype(np.uint32) << 8) | bgr[..., 0]
    ks = np.array(sorted(colours), np.uint32)
    vs = np.array([colours[k] for k in ks], np.int32)
    idx = np.clip(np.searchsorted(ks, key), 0, len(ks) - 1)
    return np.where(ks[idx] == key, vs[idx], 0).astype(np.int32)


def edgeDistances(ids, seaMask, pid, xs, ys, reach):
    """for each of a province's pixels, how far its middle is from the nearest pixel of another
    land province and from the nearest sea pixel, up to `reach`. The map wraps east to west."""
    height, width = ids.shape
    x0, y0 = int(xs.min()) - reach, int(ys.min()) - reach
    rows = np.clip(np.arange(y0, int(ys.max()) + reach + 1), 0, height - 1)
    cols = np.arange(x0, int(xs.max()) + reach + 1) % width
    crop = ids[np.ix_(rows, cols)]
    sea = seaMask[np.ix_(rows, cols)]
    land = (crop != pid) & ~sea
    sea = sea & (crop != pid)
    lx, ly = xs - x0, ys - y0
    toLand = np.full(len(xs), float(reach))
    toSea = np.full(len(xs), float(reach))
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            d = math.hypot(dx, dy)
            if d == 0 or d > reach:
                continue
            # to the near edge of that pixel rather than its middle
            toLand = np.where(land[ly + dy, lx + dx], np.minimum(toLand, d - 0.5), toLand)
            toSea = np.where(sea[ly + dy, lx + dx], np.minimum(toSea, d - 0.5), toSea)
    return toLand, toSea


def nearMask(mask, steps):
    """mask grown by `steps` pixels in the eight directions"""
    out = mask.copy()
    for _ in range(steps):
        grown = out.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy or dx:
                    grown |= np.roll(out, (dy, dx), (0, 1))
        out = grown
    return out


# ---------------------------------------------------------------- placing


class Grid:
    """every point that draws something, bucketed so a province asks only its neighbourhood"""

    CELL = 16

    def __init__(self):
        self.cells = {}

    def add(self, x, y, owner, always=False):
        """`always`: drawn whatever is built - a resource icon - as against a building's point"""
        self.cells.setdefault((int(x) // self.CELL, int(y) // self.CELL), []).append(
            (x, y, owner, always))

    def near(self, x0, y0, x1, y1, exclude=None, always=False):
        c = self.CELL
        out = []
        for cx in range(int(x0) // c - 1, int(x1) // c + 2):
            for cy in range(int(y0) // c - 1, int(y1) // c + 2):
                for x, y, owner, isAlways in self.cells.get((cx, cy), ()):
                    if owner != exclude and (isAlways or not always):
                        out.append((x, y))
        return np.array(out, float).reshape(-1, 2)


def clearance(px, py, obstacles):
    if not len(obstacles):
        return np.full(np.shape(px), np.inf)
    dx = np.asarray(px, float)[..., None] - obstacles[:, 0]
    dy = np.asarray(py, float)[..., None] - obstacles[:, 1]
    return np.sqrt(dx * dx + dy * dy).min(axis=-1)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--mod", default=os.path.dirname(here), help="the mod's root folder")
    parser.add_argument("--write", action="store_true", help="rewrite map/positions.txt")
    parser.add_argument("--positions", help="read this positions.txt instead of the mod's")
    parser.add_argument("--output", help="with --write, write here instead of over the input")
    parser.add_argument("--gap", type=float, default=3.5,
                        help="clearance a new point looks for, in map pixels (default 3.5)")
    parser.add_argument("--keep-gap", type=float, default=2.5,
                        help="clearance at which a declared point is left alone (default 2.5)")
    parser.add_argument("--border", type=float, default=3.0,
                        help="how far a point stays from a neighbouring province, in pixels "
                             "(default 3)")
    parser.add_argument("--shore", type=float, default=1.5,
                        help="how far a point stays from the sea, in pixels (default 1.5)")
    parser.add_argument("--coast", type=int, default=3,
                        help="how near the sea a moved coastal point stays, in pixels (default 3)")
    parser.add_argument("--ignore", default="",
                        help="buildings whose points need not be kept clear, comma separated "
                             "(say nuclear_reactor,rocket_test - they are seldom built)")
    parser.add_argument("--all", action="store_true",
                        help="move every resource icon, not only those that need it")
    parser.add_argument("--verbose", action="store_true", help="list every point set")
    parser.add_argument("--preview", help="draw the result into this .png")
    parser.add_argument("--region", help="x0,y0,x1,y1 in map pixels for --preview (default: all)")
    parser.add_argument("--zoom", type=int, default=4, help="pixels per map pixel in --preview")
    args = parser.parse_args()

    mapDir = os.path.join(args.mod, "map")
    positionsPath = args.positions or os.path.join(mapDir, "positions.txt")

    buildings = readBuildings(os.path.join(args.mod, "common", "buildings.txt"))
    onmap = {name for name, drawn, _ in buildings if drawn}
    port = {name for name, _, isPort in buildings if isPort}
    goodKey = {GOODS[i]: buildings[i - 1][0] for i in DRAWN}  # slot 0 is the engine's nobuilding
    ignored = {name.strip() for name in args.ignore.split(",") if name.strip()}
    unknown = ignored - {name for name, _, _ in buildings}
    if unknown:
        sys.exit("--ignore names no building: " + ", ".join(sorted(unknown)))
    print("resource icons stand on: " + ", ".join(
        "%s -> %s%s" % (GOOD_LABEL[g], k, " (drawn too)" if k in onmap else "")
        for g, k in goodKey.items()))

    colours, names = readDefinitions(os.path.join(mapDir, "definition.csv"))
    seaIds = readSeaIds(os.path.join(mapDir, "default.map"))
    goods, strategic = readHistory(os.path.join(args.mod, "history", "provinces"))
    print("%d provinces produce a drawn good, %d hold a strategic resource"
          % (len(goods), len(strategic)))

    text = readText(positionsPath)
    root = parse(text)
    blocks = {}
    for key, _, value in root.items:
        if key and key.isdigit() and isinstance(value, Block):
            blocks.setdefault(int(key), value)

    # The file and the bitmap have to agree on which way up the map is: take the way round
    # that puts the unit points in their own provinces.
    ids = readProvinceMap(os.path.join(mapDir, "provinces.bmp"), colours)
    height, width = ids.shape
    units = [(pid, point(b.get("unit"))) for pid, b in blocks.items()]
    units = [(pid, int(p[0]), int(p[1])) for pid, p in units if p
             and 0 <= p[0] < width and 0 <= p[1] < height]
    fits = lambda m: sum(m[y, x] == pid for pid, x, y in units)
    if fits(ids[::-1]) > fits(ids):
        ids = np.ascontiguousarray(ids[::-1])
    if units and fits(ids) < 0.9 * len(units):
        sys.exit("only %d of %d unit points fall in their own province - is provinces.bmp the map "
                 "positions.txt was made for?" % (fits(ids), len(units)))
    seaMask = np.isin(ids, np.array(sorted(seaIds), np.int32))
    nearSea = nearMask(seaMask, args.coast) & ~seaMask
    reach = int(math.ceil(max(args.border, args.shore) * 2)) + 1

    def inset(pid, xs, ys):
        """how well each pixel keeps off the borders: 1 or more is far enough"""
        toLand, toSea = edgeDistances(ids, seaMask, pid, xs, ys, reach)
        share = toLand / args.border if args.border > 0 else np.full(len(xs), np.inf)
        if args.shore > 0:
            share = np.minimum(share, toSea / args.shore)
        return share

    flat = ids.ravel()
    order = np.argsort(flat, kind="stable")
    starts = np.searchsorted(flat[order], np.arange(flat.max() + 2))

    def pixels(pid):
        idx = order[starts[pid]:starts[pid + 1]] if 0 < pid < len(starts) - 1 else order[:0]
        return idx % width, idx // width

    def owns(pid, x, y):
        xi, yi = int(math.floor(x)), int(math.floor(y))
        return 0 <= xi < width and 0 <= yi < height and ids[yi, xi] == pid

    # Everything drawn, except the points this script may move.
    grid = Grid()
    slots = []  # [province, good, key, declared point or None]
    for pid, block in blocks.items():
        produced = goods.get(pid, set()) if pid not in seaIds else set()
        movable = {goodKey[g]: g for g in produced}
        positions = block.get("building_position")
        declared = {}
        if isinstance(positions, Block):
            for key, _, value in positions.items:
                p = point(value)
                if p is None:
                    continue
                declared[key] = p
                if key in onmap and key not in movable and key not in ignored:
                    grid.add(p[0], p[1], (pid, key))
        for key in ("unit", "text_position"):
            p = point(block.get(key))
            if p and (key == "unit" or pid not in seaIds):
                grid.add(p[0], p[1], (pid, key))
        for good in sorted(produced, key=GOODS.index):
            slots.append([pid, good, goodKey[good], declared.get(goodKey[good])])
    for pid in strategic:
        xs, ys = pixels(pid)
        if len(xs):
            # the bounding box's middle, as the engine works it: min + (max - min + 1) / 2
            grid.add(xs.min() + (xs.max() - xs.min() + 1) // 2,
                     ys.min() + (ys.max() - ys.min() + 1) // 2, (pid, "strategic"), always=True)

    # First keep what is already good, so a new point never lands on one.
    kept, pending = [], []
    for slot in slots:
        pid, good, key, p = slot
        if p and not args.all and owns(pid, p[0], p[1]):
            near = grid.near(p[0] - 1, p[1] - 1, p[0] + 1, p[1] + 1, exclude=(pid, key))
            px, py = np.array([int(math.floor(p[0]))]), np.array([int(math.floor(p[1]))])
            if clearance(p[0], p[1], near) >= args.keep_gap and inset(pid, px, py)[0] >= 1:
                grid.add(p[0], p[1], (pid, key), always=True)
                kept.append(slot)
                continue
        pending.append(slot)

    placed = []  # (slot, x, y, clearance)
    nearBorder = []  # (slot, how far off the border it got, as a share of what was asked)
    for slot in pending:
        pid, good, key, p = slot
        xs, ys = pixels(pid)
        if not len(xs):
            print("  province %d has no pixels on the map; %s left alone" % (pid, key))
            continue
        if key in port and key in onmap:
            coastal = nearSea[ys, xs]
            if coastal.any():
                xs, ys = xs[coastal], ys[coastal]
        # What is weighed, most first: not on another resource icon, which is always drawn;
        # --border and --shore off the edges, so it is not taken for the neighbour's; clear of
        # the buildings' points, which are drawn only once something is built; deeper inside;
        # nearer the middle. In a small province this puts two icons a little nearer the border
        # rather than on top of each other.
        share = inset(pid, xs, ys)
        cx, cy = xs + 0.5, ys + 0.5
        box = (cx.min() - args.gap, cy.min() - args.gap, cx.max() + args.gap, cy.max() + args.gap)
        clear = clearance(cx, cy, grid.near(*box, exclude=(pid, key)))
        clearIcons = clearance(cx, cy, grid.near(*box, exclude=(pid, key), always=True))
        mx, my = cx.mean(), cy.mean()
        score = (np.minimum(clearIcons, args.keep_gap) * 10 + np.minimum(share, 1) * 15
                 + np.minimum(clear, args.gap) * 6 + np.minimum(share, 2) * 2
                 - 0.02 * np.hypot(cx - mx, cy - my))
        best = int(np.argmax(score))
        x, y = float(cx[best]), float(cy[best])
        grid.add(x, y, (pid, key), always=True)
        placed.append((slot, x, y, float(clear[best])))
        if share[best] < 1:
            nearBorder.append((slot, float(share[best])))

    # ------------------------------------------------------------ the report
    crowded = [p for p in placed if p[3] < args.keep_gap]
    # A crowded point is placed again on every run, and mostly lands where it already was.
    same = lambda s, x, y: s[3] and abs(s[3][0] - x) < 5e-4 and abs(s[3][1] - y) < 5e-4
    kept += [s for s, x, y, _ in placed if same(s, x, y)]
    placed = [q for q in placed if not same(*q[:3])]
    print("%d resource icons: %d left where they were, %d moved, %d placed for the first time"
          % (len(slots), len(kept), sum(1 for s, *_ in placed if s[3]),
             sum(1 for s, *_ in placed if not s[3])))
    for good in (GOODS[i] for i in DRAWN):
        mine = [p for p in placed if p[0][1] == good]
        print("  %-6s %4d set, %4d kept" % (GOOD_LABEL[good], len(mine),
                                            sum(1 for s in kept if s[1] == good)))
    if crowded:
        print("%d set less than %.1f px from something else, the province having no room:"
              % (len(crowded), args.keep_gap))
        for (pid, good, key, _), x, y, clear in crowded:
            print("  %5d %-24s %-6s %.1f px" % (pid, names.get(pid, "")[:24], GOOD_LABEL[good], clear))
    if nearBorder:
        print("%d set nearer a border than %.1f px (or the sea than %.1f px), the province being "
              "too small:" % (len(nearBorder), args.border, args.shore))
        for (pid, good, key, _), share in nearBorder:
            print("  %5d %-24s %-6s %.0f%% of the distance"
                  % (pid, names.get(pid, "")[:24], GOOD_LABEL[good], share * 100))
    if args.verbose:
        for (pid, good, key, p), x, y, clear in placed:
            old = "(%.1f, %.1f)" % (p[0], p[1]) if p else "undeclared"
            print("  %5d %-24s %-6s %-14s %s -> (%.1f, %.1f), %.1f px clear"
                  % (pid, names.get(pid, "")[:24], GOOD_LABEL[good], key, old, x, y, clear))

    if args.preview:
        drawPreview(args, ids, seaMask, grid, kept, placed)

    if not args.write:
        print("nothing written; --write rewrites %s" % positionsPath)
        return

    # ------------------------------------------------------------ the rewrite
    nl = "\r\n" if "\r\n" in text else "\n"
    lineStart = lambda offset: text.rfind("\n", 0, offset) + 1
    entry = lambda key, x, y: (key + "=" + nl + "\t\t{" + nl + "\t\t\tx=%.6f" % x + nl
                               + "\t\t\ty=%.6f" % y + nl + "\t\t}" + nl + nl)
    edits = []  # (offset, end, text)
    inserts = {}  # province -> [entry text]
    for (pid, good, key, p), x, y, _ in placed:
        if p:
            edits.append((p[2][1], p[2][2], "%.6f" % x))
            edits.append((p[3][1], p[3][2], "%.6f" % y))
        else:
            inserts.setdefault(pid, []).append(entry(key, x, y))
    for pid, entries in inserts.items():
        block = blocks[pid]
        positions = block.get("building_position")
        if isinstance(positions, Block):
            at = lineStart(positions.close)
            edits.append((at, at, "".join(entries)))
        else:
            nudge = block.keyOffset("building_nudge")
            at = lineStart(nudge if nudge is not None else block.close)
            edits.append((at, at, "building_position = " + nl + "\t{" + nl
                          + "".join(entries) + "\t}" + nl))
    pieces, last = [], len(text)
    for start, end, new in sorted(edits, reverse=True):
        pieces.append(text[end:last])
        pieces.append(new)
        last = start
    pieces.append(text[:last])
    out = args.output or positionsPath
    with open(out, "wb") as f:
        f.write("".join(reversed(pieces)).encode("latin-1"))
    added = sum(map(len, inserts.values()))
    print("wrote %s: %d points moved, %d added" % (out, len(placed) - added, added))


def drawPreview(args, ids, seaMask, grid, kept, placed):
    from PIL import Image, ImageDraw

    height, width = ids.shape
    x0, y0, x1, y1 = (int(v) for v in args.region.split(",")) if args.region else (0, 0, width, height)
    z = args.zoom
    crop = ids[y0:y1, x0:x1]
    border = np.zeros(crop.shape, bool)
    border[:, 1:] |= crop[:, 1:] != crop[:, :-1]
    border[1:, :] |= crop[1:, :] != crop[:-1, :]
    rgb = np.where(seaMask[y0:y1, x0:x1, None], [170, 200, 230], [235, 230, 210]).astype(np.uint8)
    rgb[border] = [120, 120, 120]
    image = Image.fromarray(rgb[::-1]).resize(((x1 - x0) * z, (y1 - y0) * z), Image.NEAREST)
    draw = ImageDraw.Draw(image)
    to = lambda x, y: ((x - x0) * z, (y1 - y) * z)
    colour = {"crude_oil": (20, 20, 20), "metal": (60, 90, 200), "energy": (200, 140, 0),
              "rare_materials": (170, 40, 170)}
    movable = {(s[0], s[2]) for s in kept} | {(p[0][0], p[0][2]) for p in placed}
    for cell in grid.cells.values():
        for x, y, owner, _ in cell:
            if owner not in movable and x0 <= x < x1 and y0 <= y < y1:
                px, py = to(x, y)
                draw.rectangle((px - z * 0.5, py - z * 0.5, px + z * 0.5, py + z * 0.5),
                               outline=(90, 90, 90))
    r = z * 1.2
    for pid, good, key, p in kept:
        px, py = to(p[0], p[1])
        draw.ellipse((px - r, py - r, px + r, py + r), fill=colour[good])
    for (pid, good, key, p), x, y, _ in placed:
        px, py = to(x, y)
        if p and x0 <= p[0] < x1 and y0 <= p[1] < y1:
            draw.line((to(p[0], p[1]), (px, py)), fill=(220, 0, 0))
        draw.ellipse((px - r, py - r, px + r, py + r), fill=colour[good], outline=(220, 0, 0), width=2)
    image.save(args.preview)
    print("preview: %s (grey squares: other icons; dots: resources, red ring: set by this run)"
          % args.preview)


if __name__ == "__main__":
    main()
