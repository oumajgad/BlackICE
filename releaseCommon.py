"""What the mod consists of, and how a version number is stamped into it.

Kept apart from installer/buildInstaller.py because these are facts about the
mod rather than about building an installer: which folders make up a release,
where it goes inside the game, and which two lines carry the version.

MOD_FOLDERS is the list the installer is checked against at build time - see
checkIssCoverage in buildInstaller.py - so a new top level folder cannot be
added to the mod and silently left out of what ships.
"""
import os

# The folders that make up the mod itself. Everything else in the repo is source
# material, tooling or notes and must not reach the player.
MOD_FOLDERS = ["battleplans", "cgm", "common", "decisions", "events", "history",
               "localisation", "map", "interface", "music", "script", "sound",
               "technologies", "units", "gfx"]

# Where the mod lives inside the base game folder.
MOD_PARENT = "tfh/mod"

# The release of OpenHOI3 this version of the mod is made for. A release of the
# mod ships exactly this engine, in the mod's own engine/ folder, and names it
# in its .mod file so the OpenHOI3 launcher runs that one and no other. The
# binary is never committed here: installer/fetchEngine.py downloads the
# release by this version. Moving to a newer engine is changing this one line.
#
# "openhoi3-<x>" is what the engine's engine.txt says; the release it comes
# from is the tag "v<x>" of ENGINE_REPOSITORY, which is also where its source
# is - the engine is GPL-3.0, and that link is what shipping it asks of us.
ENGINE_VERSION = "openhoi3-0.1.3"
ENGINE_REPOSITORY = "https://github.com/Dsafe1/OpenHOI3"

# The engine's rolling build: the release of this tag in ENGINE_REPOSITORY, which
# the engine's pipeline makes again at every change to its main branch. Its
# archives are named by the tag, whatever version their engine.txt says. A test
# build of the mod ships it (installer/fetchEngine.py --latest), so that such a
# build is on the newest engine without anybody naming one; a release ships
# ENGINE_VERSION and nothing else.
ENGINE_LATEST_TAG = "latest"

# The version a test build is stamped with: what the working copy calls itself.
TEST_VERSION = "GitHub"

# Where the engine and its launcher go inside the mod's folder. Their own
# subfolders, like everything the mod holds for OpenHOI3: the original game
# never looks in either.
ENGINE_FOLDER = "engine"
LAUNCHER_FOLDER = "launcher"


def isTestBuild(version):
    """Whether a build of this version is a test build and no release."""
    return version == TEST_VERSION


def engineTag():
    """The engine release's git tag, 'v0.1.0' for 'openhoi3-0.1.0'."""
    prefix = "openhoi3-"
    if not ENGINE_VERSION.startswith(prefix):
        raise ValueError("ENGINE_VERSION must begin with %r, got %r" % (prefix, ENGINE_VERSION))
    return "v" + ENGINE_VERSION[len(prefix):]

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


def writeModFile(version, destination, engine=True):
    """Write the versioned .mod next to \p destination, returning its path.

    The template in 'Mod File' carries the GitHub name and paths; only the three
    lines that name the version change, and a fourth is added: the engine.

    'engine = "..."' tells the OpenHOI3 launcher which engine this version of
    the mod was made for. The original game passes over a key it does not know
    when it is written as key = value, so the same .mod serves both. The
    template deliberately has no such line: a working copy is played on
    whatever engine its developer has built, and naming a released one there
    would make the launcher refuse to start it on any other. Pass engine=False
    for an installer built without the engine, and the version itself - what
    the engine.txt of the engine shipped says - where that is not the release
    the mod names: a test build on the engine's rolling build.
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
        elif key == "engine":
            # Never the template's: a release names the engine it ships.
            continue
        else:
            out.append(line)

    if engine:
        if out and not out[-1].endswith("\n"):
            out[-1] += "\n"
        out.append('engine = "%s"\n' % (engine if isinstance(engine, str) else ENGINE_VERSION))

    path = os.path.join(destination, modFileName(version))
    with open(path, "w") as handle:
        handle.writelines(out)
    return path
