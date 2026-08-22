"""Shared plumbing for the reversing scripts.

Attaching to the game, turning a class name into the vftable address RTTI gave it,
scanning for instances of it, and reading memory without falling over when a pointer
turns out not to be one.

The class data comes from OpenHOI3's RTTI export rather than from anything written by
hand, so a class name here is the name the game's own compiler recorded.
"""

import json
import os
import struct

import pymem

PROCESS = "hoi3_tfh.exe"

# Where OpenHOI3 keeps what Ghidra recovered. Overridable for a checkout elsewhere.
CLASS_JSON = os.environ.get(
    "OPENHOI3_CLASSES",
    r"C:\Users\David\GitHub\OpenHOI3\OpenHOI3\docs\hoi3_tfh-classes.json")

# Instances live above this; below it is the image itself and its data sections, where
# the only matches are the vftables and the odd static.
DATA_SECTION_START = 0x12F5000

_classes = None


def classes():
    """name -> the RTTI record, loaded once"""
    global _classes
    if _classes is None:
        with open(CLASS_JSON, "r", encoding="utf-8") as f:
            document = json.load(f)
        _classes = {}
        for record in document["classes"]:
            _classes[record["name"]] = record
    return _classes


def vftableRva(className, index=0):
    """
    Where a class's vftable sits, relative to the module base.

    The export records absolute addresses against an image base of 0x400000, while
    everything at runtime is relative to wherever the module actually loaded, so the
    base has to come back off.
    """
    record = classes().get(className)
    if record is None:
        raise KeyError("no class named %s in the RTTI export" % className)

    tables = record.get("vftables") or []
    if not tables:
        raise KeyError("%s has no vftable; it is probably an interface" % className)
    return int(tables[index]["address"], 16) - 0x400000


def attach():
    return pymem.Pymem(PROCESS)


def instances(pm, className, index=0, limit=None):
    """
    Every object whose first four bytes are the class's vftable.

    That is what an instance of a polymorphic class looks like in memory, and it is
    the only handle available without a pointer from somewhere known. Derived classes
    carry their own vftable and so will not show up here - look them up by their own
    name instead.
    """
    address = pm.base_address + vftableRva(className, index)
    pattern = address.to_bytes(4, "little").hex()
    pattern = "".join("\\x" + pattern[i:i + 2] for i in range(0, len(pattern), 2))

    found = pm.pattern_scan_all(pattern=pattern.encode(), return_multiple=True)
    found = [p for p in found if p >= pm.base_address + DATA_SECTION_START]
    found.sort()
    return found[:limit] if limit else found


def readBytes(pm, address, length):
    """None rather than an exception when the address is not readable"""
    try:
        return pm.read_bytes(address, length)
    except Exception:
        return None


def readString(pm, address, maxLength=512):
    """
    A std::string as the game's compiler laid it out.

    Sixteen bytes that are either the characters or a pointer to them, then the
    length; past fifteen characters it is a pointer.
    """
    raw = readBytes(pm, address, 20)
    if raw is None:
        return None

    length = struct.unpack_from("<I", raw, 16)[0]
    if length == 0 or length > maxLength:
        return None

    if length > 15:
        pointer = struct.unpack_from("<I", raw, 0)[0]
        if pointer == 0:
            return None
        text = readBytes(pm, pointer, length)
    else:
        text = raw[:length]

    if text is None:
        return None
    return text.decode("latin-1", "replace")


# The game counts hours from an epoch 5000 years before its calendar starts, so a tick
# is (year * 365 + dayOfYear) * 24 + hour + 43800000. Mirrors utils::gameTickToDate in
# BiceLib, which is where this came from.
TICK_EPOCH = 43800000
TICKS_PER_DAY = 24
DAYS_PER_MONTH = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)


def tickToDate(tick):
    """'1936-01-01 05:00' for a game tick, or None if it is not one

    A Clausewitz year is 365 days with no leap day, which is why this cannot use
    anything from the calendar library.
    """
    if tick < TICK_EPOCH or tick > TICK_EPOCH + 24 * 365 * 3000:
        return None

    hours = tick - TICK_EPOCH
    totalDays = hours // TICKS_PER_DAY
    hour = hours % TICKS_PER_DAY

    year = totalDays // 365
    dayOfYear = totalDays - year * 365

    month = 0
    while month < 12 and dayOfYear >= DAYS_PER_MONTH[month]:
        dayOfYear -= DAYS_PER_MONTH[month]
        month += 1

    return "%04d-%02d-%02d %02d:00" % (year, month + 1, dayOfYear + 1, hour)


def looksLikeTick(value):
    """true for values in the range the game's own dates fall in"""
    return TICK_EPOCH <= value <= TICK_EPOCH + 24 * 365 * 2100


def describe(pm, value):
    """what a four byte field might be, for the dump columns"""
    notes = []
    if value == 0:
        return "zero"

    if looksLikeTick(value):
        notes.append("date %s" % tickToDate(value))

    base = pm.base_address
    if base <= value < base + 0x2000000:
        notes.append("module+0x%x" % (value - base))

        # A pointer to a vftable inside the module usually means the field points at
        # an object; name it when RTTI knows that table.
        name = classNameForVftable(pm, value)
        if name:
            notes.append("vftable of %s" % name)
    elif 0x10000 < value < 0xFFFFFFF0:
        target = readBytes(pm, value, 4)
        if target is not None:
            pointee = struct.unpack_from("<I", target, 0)[0]
            name = classNameForVftable(pm, pointee)
            notes.append("-> %s" % name if name else "readable pointer")

    asFloat = struct.unpack("<f", struct.pack("<I", value))[0]
    if 0.0001 < abs(asFloat) < 1000000.0:
        notes.append("float %.4g" % asFloat)

    return ", ".join(notes) if notes else ""


_vftableIndex = None


def classNameForVftable(pm, address):
    """the class whose vftable sits at this address, or None"""
    global _vftableIndex
    if _vftableIndex is None:
        _vftableIndex = {}
        for name, record in classes().items():
            for table in record.get("vftables") or []:
                rva = int(table["address"], 16) - 0x400000
                _vftableIndex[rva] = name

    if address < pm.base_address:
        return None
    return _vftableIndex.get(address - pm.base_address)
