"""Shared release plumbing for zipperRelease.py and installer/buildInstaller.py.

Both of them ship the same tree under a version number, so the rules for what
counts as a mod folder and which lines carry the version live here rather than
being copied into each script and drifting apart.
"""
import os

# The folders that make up the mod itself. Everything else in the repo is source
# material, tooling or notes and must not reach the player.
MOD_FOLDERS = ["battleplans", "cgm", "common", "decisions", "events", "history",
               "localisation", "map", "interface", "music", "script", "sound",
               "technologies", "units", "gfx"]

# Where the mod lives inside the base game folder.
MOD_PARENT = "tfh/mod"

REPO = os.path.dirname(os.path.abspath(__file__))

_VERSION_CSV = os.path.join(REPO, "localisation", "bi_version.csv")
_AUTOEXEC = os.path.join(REPO, "script", "autoexec.lua")
_TEMPLATE_MOD = os.path.join(REPO, "Mod File", "BlackICE GitHub.mod")

# What the two version lines hold while working in the repo, so a build can put
# them back afterwards and leave the tree as it found it.
_DEV_CSV_LINE = "BI_VERSION;BlackICE TestVersion;;;;;;;;;;;;;x"
_DEV_LUA_LINE = 'G_MOD_VERSION = "GitHub"\n'

# The version string sits on a fixed line in each file. Kept as named constants
# because an off-by-one here silently ships the wrong version.
_CSV_LINE_INDEX = 1
_LUA_LINE_INDEX = 6


def _replace_line(path, index, text):
    with open(path, "r") as handle:
        lines = handle.readlines()
    lines[index] = text
    with open(path, "w") as handle:
        handle.writelines(lines)


def setLocsVersion(version):
    _replace_line(_VERSION_CSV, _CSV_LINE_INDEX,
                  "BI_VERSION;BlackICE %s;;;;;;;;;;;;;x" % version)


def resetLocsVersion():
    _replace_line(_VERSION_CSV, _CSV_LINE_INDEX, _DEV_CSV_LINE)


def setLuaUtilityVersion(version):
    _replace_line(_AUTOEXEC, _LUA_LINE_INDEX, 'G_MOD_VERSION = "%s"\n' % version)


def resetLuaUtilityVersion():
    _replace_line(_AUTOEXEC, _LUA_LINE_INDEX, _DEV_LUA_LINE)


def modFileName(version):
    """The .mod file the game reads, e.g. 'BlackICE 15.2.mod'."""
    return "BlackICE %s.mod" % version


def writeModFile(version, destination):
    """Write the versioned .mod next to \p destination, returning its path.

    The template in 'Mod File' carries the GitHub name and paths; only the three
    lines that name the version change.
    """
    with open(_TEMPLATE_MOD, "r") as handle:
        lines = handle.readlines()

    out = []
    for line in lines:
        key = line.split("=")[0].strip()
        if key == "name":
            out.append('name = "BlackICE %s"\n' % version)
        elif key == "path":
            out.append('path = "%s/BlackICE %s"\n' % (MOD_PARENT, version))
        elif key == "user_dir":
            out.append('user_dir = "BlackICE %s"\n' % version)
        else:
            out.append(line)

    path = os.path.join(destination, modFileName(version))
    with open(path, "w") as handle:
        handle.writelines(out)
    return path
