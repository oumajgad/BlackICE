"""Builds the BlackICE installer.

Does what zipperRelease.py does to the tree - stamps the version into
bi_version.csv and autoexec.lua, writes the versioned .mod - and then hands the
repo to the Inno Setup compiler instead of a zip writer. The tree is always put
back afterwards, including when the compile fails.

    python installer/buildInstaller.py 15.2

The mod folders are read straight out of the repo by BlackICE.iss, so nothing
is copied twice; only the generated .mod and the unpacked dxvk/borderless
payloads are staged.

Run installer/fetchRedists.py once first, or pass --no-redist to build an
installer that detects missing runtimes but does not carry them.
"""
import argparse
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, REPO)

import releaseCommon  # noqa: E402  - needs REPO on the path first

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


def build(version, useRedist, fast):
    iscc = findIscc()
    if iscc is None:
        print("Inno Setup 6 was not found.")
        print("Install it from https://jrsoftware.org/isdl.php, or point the ISCC")
        print("environment variable at ISCC.exe.")
        return 1

    print("Building BlackICE %s\n" % version)
    print("  compiler: %s" % iscc)

    emptyStaging()
    releaseCommon.writeModFile(version, STAGING)
    print("  stage %-12s %s" % ("mod file", releaseCommon.modFileName(version)))
    stageArchives()
    reportRedist(useRedist)

    os.makedirs(OUTPUT, exist_ok=True)

    command = [iscc, "/DModVersion=" + version]
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
    arguments = parser.parse_args()

    version = arguments.version
    if not version:
        version = input("Enter the version number: ").strip()
    if not version:
        print("No version given.")
        return 1

    return build(version, not arguments.no_redist, arguments.fast)


if __name__ == "__main__":
    sys.exit(main())
