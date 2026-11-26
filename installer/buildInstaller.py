"""Builds the BlackICE installer.

Stamps the version into bi_version.csv and autoexec.lua, writes the versioned
.mod, and hands the repo to the Inno Setup compiler. The tree is always put back
afterwards, including when the compile fails.

    python installer/buildInstaller.py 15.2

The mod folders are read straight out of the repo by BlackICE.iss, so nothing
is copied twice; only the generated .mod and the unpacked dxvk/borderless
payloads are staged.

Run installer/fetchRedists.py once first, or pass --no-redist to build an
installer that detects missing runtimes but does not carry them.

Run installer/fetchEngine.py once first too. The OpenHOI3 engine and its
launcher are a core part of a release, so without them the build stops;
--no-engine builds an installer for the original game alone, for testing.

A release ships the engine the mod names, releaseCommon.ENGINE_VERSION, and
stops where another is unpacked. A test build - the version "GitHub" - ships
whatever engine is unpacked, which fetchEngine.py --latest makes the engine's
newest build, and its .mod names that one. --any-engine does the same for a
build under any other version: a release candidate on an engine not yet released.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, REPO)

import releaseCommon  # noqa: E402  - needs REPO on the path first
import fetchEngine  # noqa: E402  - beside this file

STAGING = os.path.join(HERE, "staging")
OUTPUT = os.path.join(HERE, "output")
REDIST = os.path.join(HERE, "redist")
ISS = os.path.join(HERE, "BlackICE.iss")

# Inno refuses to build a single file installer past this, and asks for disk
# spanning instead. Measured payload is around 800 MB, so there is room, but a
# build that creeps up on it should say so rather than fail at the last minute.
INNO_SINGLE_FILE_LIMIT = 2100000000

ARCHIVES = [
    # (archive, staging subfolder, what it is)
    (os.path.join(REPO, "dxvk.rar"), "dxvk", "DXVK d3d9/dxgi"),

    # The stretching build rather than plain borderless.rar. Both drop the same
    # dinput8.dll into the game folder so only one can be installed, and this
    # one is a superset: borderless=1 alone behaves exactly like the plain
    # build, and the [dsafe] section additionally allows stretching the window
    # with the cursor still lining up. It is also the newer of the two.
    (os.path.join(REPO, "DaveStuff", "borderless_window_v2winfix",
                  "borderlessWithStretching.rar"),
     "borderless", "borderless window"),
]


def _isccFromRegistry():
    """Where Inno Setup's own uninstall entry says it is.

    Needed because winget installs it per user under %LOCALAPPDATA%\\Programs
    while the classic installer puts it in Program Files, and neither location
    is guessable from the other.
    """
    try:
        import winreg
    except ImportError:
        return None

    key = r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1"
    roots = [(winreg.HKEY_CURRENT_USER, 0),
             (winreg.HKEY_LOCAL_MACHINE, winreg.KEY_WOW64_32KEY),
             (winreg.HKEY_LOCAL_MACHINE, winreg.KEY_WOW64_64KEY)]
    for root, flag in roots:
        try:
            with winreg.OpenKey(root, key, 0, winreg.KEY_READ | flag) as handle:
                location = winreg.QueryValueEx(handle, "InstallLocation")[0]
        except OSError:
            continue
        candidate = os.path.join(location, "ISCC.exe")
        if os.path.exists(candidate):
            return candidate
    return None


def findIscc():
    """Locate the Inno Setup command line compiler."""
    override = os.environ.get("ISCC")
    if override and os.path.exists(override):
        return override

    fromRegistry = _isccFromRegistry()
    if fromRegistry:
        return fromRegistry

    candidates = [
        os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Inno Setup 6", "ISCC.exe"),
        r"C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        r"C:\Program Files\Inno Setup 6\ISCC.exe",
    ]
    for candidate in candidates:
        if candidate and os.path.exists(candidate):
            return candidate
    return shutil.which("ISCC")


def findSevenZip():
    for candidate in (r"C:\Program Files\7-Zip\7z.exe",
                      r"C:\Program Files (x86)\7-Zip\7z.exe"):
        if os.path.exists(candidate):
            return candidate
    return shutil.which("7z")


def stageArchives():
    """Unpack dxvk.rar and borderless.rar so the installer places real files.

    The old instructions asked the player to right click a .rar and pick
    "extract here", which is one more thing to get wrong for no benefit.
    """
    sevenZip = findSevenZip()
    for archive, folder, what in ARCHIVES:
        target = os.path.join(STAGING, folder)
        os.makedirs(target, exist_ok=True)

        if not os.path.exists(archive):
            print("  WARN  %s not found, %s will be empty" % (archive, what))
            continue
        if sevenZip is None:
            print("  WARN  7-Zip not found, cannot unpack %s" % os.path.basename(archive))
            continue

        subprocess.run([sevenZip, "x", "-y", "-o" + target, archive],
                       check=True, stdout=subprocess.DEVNULL)
        names = sorted(os.listdir(target))
        print("  stage %-12s %s" % (folder, ", ".join(names)))


def checkIssCoverage():
    """Every folder the mod is made of must have a Source line in the .iss.

    BlackICE.iss lists the folders one by one rather than walking the tree, so
    adding a new top level folder to the mod would otherwise leave it silently
    out of the installer - the build would succeed and the mod would be broken
    in a way nothing points at. Compared against releaseCommon.MOD_FOLDERS,
    which is the definition of what a release contains.

    Returns a list of problems, empty when the two agree.
    """
    with open(ISS, encoding="utf-8") as handle:
        text = handle.read()

    # Source: "{#RepoRoot}\<folder>\*"
    listed = set(re.findall(r'Source:\s*"\{#RepoRoot\}\\([^\\"]+)\\\*"', text))

    problems = []
    for folder in releaseCommon.MOD_FOLDERS:
        if folder not in listed:
            problems.append("  %s is part of the mod but has no Source line in %s"
                            % (folder, os.path.basename(ISS)))

    # The reverse: a Source line for a folder that is no longer part of the mod
    # would ship stale files. Only checked for top level repo folders, since the
    # .iss also pulls in tools/ paths that are not mod folders.
    for folder in sorted(listed):
        if folder in releaseCommon.MOD_FOLDERS:
            continue
        if os.path.isdir(os.path.join(REPO, folder)):
            problems.append("  %s is in %s but is not one of MOD_FOLDERS"
                            % (folder, os.path.basename(ISS)))

    return problems


def emptyStaging():
    if os.path.exists(STAGING):
        shutil.rmtree(STAGING)
    os.makedirs(STAGING, exist_ok=True)


def reportRedist(useRedist):
    if not useRedist:
        print("  --no-redist: runtimes will be detected but not bundled.")
        return
    if not os.path.isdir(REDIST) or not os.listdir(REDIST):
        print("  WARN  installer/redist is empty. Run:")
        print("          python installer/fetchRedists.py")
        print("        Building anyway; the installer will report missing runtimes")
        print("        instead of installing them.")
        return
    total = 0
    for root, _dirs, files in os.walk(REDIST):
        total += sum(os.path.getsize(os.path.join(root, f)) for f in files)
    print("  redist bundled: %.1f MB" % (total / 1048576))


def checkEngine(useEngine, anyEngine=False):
    """Whether the build may go on, and the engine it ships.

    Returns (True, version) with the version of the engine unpacked in
    installer/openhoi, (True, None) where the engine is left out on purpose,
    and (False, None) where the build must stop: no engine is unpacked, or one
    that is not the release the mod names while \p anyEngine does not allow it.
    """
    if not useEngine:
        print("  --no-engine: this installer is for the original game alone. Not a release.")
        return True, None
    found = fetchEngine.fetchedVersion()
    if found is None:
        print("\nThe OpenHOI3 engine is not in installer/openhoi.")
        print("It is a core part of a release. Fetch it with:")
        print("    python installer/fetchEngine.py            the release the mod names, %s"
              % releaseCommon.ENGINE_VERSION)
        print("    python installer/fetchEngine.py --latest   the engine's newest build, for a test build")
        print("or build an installer for the original game alone with --no-engine.")
        return False, None
    if found != releaseCommon.ENGINE_VERSION and not anyEngine:
        print("\nThe OpenHOI3 engine in installer/openhoi is %s, and the mod names %s."
              % (found, releaseCommon.ENGINE_VERSION))
        print("A release ships the engine it names. Fetch that one with:")
        print("    python installer/fetchEngine.py")
        print("or ship the one unpacked, which is then no release, with --any-engine.")
        return False, None
    total = 0
    for root, _dirs, files in os.walk(fetchEngine.OPENHOI):
        total += sum(os.path.getsize(os.path.join(root, f)) for f in files)
    print("  engine bundled: %s with its launcher, %.0f MB" % (found, total / 1048576))
    if found != releaseCommon.ENGINE_VERSION:
        print("        not the release the mod names (%s): this installer is no release."
              % releaseCommon.ENGINE_VERSION)
    return True, found


def validateMod():
    """Run BICE Validator's release check. False if the mod has a file the game cannot
    read past - an unmatched bracket, a key with no value - which would otherwise ship."""
    sys.path.insert(0, os.path.join(REPO, "tools", "BiceValidator"))
    from bicevalidator import release  # noqa: E402  - needs the tool on the path first
    return release.check(REPO)


def build(version, useRedist, fast, validate=True, useEngine=True, anyEngine=False):
    iscc = findIscc()
    if iscc is None:
        print("Inno Setup 6 was not found.")
        print("Install it from https://jrsoftware.org/isdl.php, or point the ISCC")
        print("environment variable at ISCC.exe.")
        return 1

    print("Building BlackICE %s\n" % version)
    print("  compiler: %s" % iscc)

    problems = checkIssCoverage()
    if problems:
        print("\nThe installer does not match what the mod is made of:")
        for problem in problems:
            print(problem)
        print("\nFix BlackICE.iss or releaseCommon.MOD_FOLDERS and build again.")
        return 1

    if validate:
        if not validateMod():
            print("\nOr build anyway with --skip-validation.")
            return 1
    else:
        print("  validator: skipped (--skip-validation)")

    # A test build ships whatever engine is unpacked - the engine's newest build,
    # where fetchEngine.py --latest unpacked it - and a release only the one it names.
    engineOk, engineVersion = checkEngine(useEngine, anyEngine or releaseCommon.isTestBuild(version))
    if not engineOk:
        return 1

    emptyStaging()
    # The .mod names the engine only when the installer carries it: a .mod that
    # names an engine which is not in its folder cannot be started by the launcher.
    # It names the engine shipped, by what that engine's own engine.txt says.
    releaseCommon.writeModFile(version, STAGING, engine=engineVersion if useEngine else False)
    print("  stage %-12s %s" % ("mod file", releaseCommon.modFileName(version)))
    stageArchives()
    reportRedist(useRedist)

    os.makedirs(OUTPUT, exist_ok=True)

    command = [iscc, "/DModVersion=" + version]
    if useEngine:
        # Switches on the engine's [Files] and [Icons] lines in BlackICE.iss.
        command += ["/DWithEngine=1", "/DEngineVersion=" + engineVersion]
    if fast:
        # Switches the [Setup] compression directives; ISCC has no way to
        # override those from the command line.
        command += ["/DFastBuild=1"]
    command.append(ISS)

    print("\n  stamping version into bi_version.csv and autoexec.lua")
    releaseCommon.setLocsVersion(version)
    releaseCommon.setLuaUtilityVersion(version)

    started = time.time()
    try:
        result = subprocess.run(command, cwd=HERE)
    finally:
        # Always, so a failed compile does not leave a release version stamped
        # into the working tree.
        releaseCommon.resetLocsVersion()
        releaseCommon.resetLuaUtilityVersion()
        print("  restored the working tree version strings")

    if result.returncode != 0:
        print("\nISCC failed with code %d." % result.returncode)
        return result.returncode

    produced = os.path.join(OUTPUT, "BlackICE %s Setup.exe" % version)
    elapsed = time.time() - started
    print("\nDone in %d min %d s" % (elapsed // 60, elapsed % 60))

    if os.path.exists(produced):
        size = os.path.getsize(produced)
        print("  %s" % produced)
        print("  %.0f MB" % (size / 1048576))
        headroom = INNO_SINGLE_FILE_LIMIT - size
        if fast:
            # --fast stores the payload uncompressed, so its size says nothing
            # about what a release build will come to.
            print("  (uncompressed test build - not a release, do not publish)")
        elif headroom < 150 * 1048576:
            print("  WARNING: only %.0f MB under Inno's single file limit." % (headroom / 1048576))
            print("  When that runs out, add DiskSpanning=yes to BlackICE.iss;")
            print("  the installer then ships as an exe plus .bin files.")
    else:
        print("  WARNING: expected output not found at %s" % produced)

    return 0


def main():
    parser = argparse.ArgumentParser(description="Build the BlackICE installer.")
    parser.add_argument("version", nargs="?", help="e.g. 15.2")
    parser.add_argument("--no-redist", action="store_true",
                        help="do not bundle the Microsoft runtimes")
    parser.add_argument("--fast", action="store_true",
                        help="skip compression, for testing the wizard only")
    parser.add_argument("--skip-validation", action="store_true",
                        help="build even if BICE Validator finds a file the game cannot read")
    parser.add_argument("--no-engine", action="store_true",
                        help="leave out the OpenHOI3 engine and launcher: the original game alone, not a release")
    parser.add_argument("--any-engine", action="store_true",
                        help="ship whatever engine is unpacked, not only the release the mod names; "
                             "a test build (version '%s') does so anyway" % releaseCommon.TEST_VERSION)
    arguments = parser.parse_args()

    version = arguments.version
    if not version:
        version = input("Enter the version number: ").strip()
    if not version:
        print("No version given.")
        return 1

    return build(version, not arguments.no_redist, arguments.fast,
                 validate=not arguments.skip_validation,
                 useEngine=not arguments.no_engine,
                 anyEngine=arguments.any_engine)


if __name__ == "__main__":
    sys.exit(main())
