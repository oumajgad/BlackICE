"""Fetches the OpenHOI3 engine and launcher the installer ships, from the engine's releases.

A release of the mod is made for one release of OpenHOI3, named in
releaseCommon.ENGINE_VERSION. This downloads that release's two archives from
GitHub, checks them against the release's own SHA256SUMS.txt, and unpacks them
into installer/openhoi/:

    installer/openhoi/engine/      OpenHOI3.exe, engine.txt, ...  -> tfh/mod/BlackICE <ver>/engine
    installer/openhoi/launcher/    OpenHOI3.Launcher.exe, ...     -> tfh/mod/BlackICE <ver>/launcher

Nothing of it is committed - the engine is about 210 MB - and the folder is
gitignored. Run this once before building the installer, and again after
ENGINE_VERSION changes; with the right version already unpacked it does nothing.

    python installer/fetchEngine.py
    python installer/fetchEngine.py --latest
    python installer/fetchEngine.py --from C:/path/to/OpenHOI3/export/release

--latest takes the engine's rolling build instead: the release of the tag
"latest" (releaseCommon.ENGINE_LATEST_TAG), which the engine's pipeline makes
again at every change to its main branch. It is what a test build of the mod
ships - buildInstaller.py with the version "GitHub" - so that such a build is
always on the newest engine without anybody naming one. Its archives are named
by the tag, and the version is whatever their engine.txt says. Fetched again
only when the release's SHA256SUMS.txt is no longer the one unpacked from.

--from takes the archives from a folder instead of downloading them: the
export/release folder that OpenHOI3's tools/build_release.ps1 leaves, for trying
an engine that has not been published. Where the folder holds the release the
mod names, that one is taken, as a download would be; where it holds one other
engine - a build between two releases, or one made with -Latest - that one is
taken as --latest's is, whatever its version.

The check against SHA256SUMS.txt is the same every way. What differs is the
version: the release the mod names must say exactly that in its engine.txt, so
an engine that is not the one named never reaches a release's installer; any
other is taken at its word, and buildInstaller.py ships it only in a test build
or where it is told to with --any-engine.
"""
import argparse
import glob
import hashlib
import os
import shutil
import sys
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, REPO)

import releaseCommon  # noqa: E402  - needs REPO on the path first

OPENHOI = os.path.join(HERE, "openhoi")
DOWNLOADS = os.path.join(OPENHOI, "_download")
SUMS = "SHA256SUMS.txt"
# The checksums of the release last unpacked, kept beside it: what --latest sets
# the release's own against, to know whether there is a newer build to fetch.
UNPACKED_SUMS = os.path.join(OPENHOI, SUMS)

# The file each unpacked part must hold to be what it says it is.
ENGINE_MARKER = "engine.txt"
LAUNCHER_MARKER = "OpenHOI3.Launcher.exe"

VERSION_PREFIX = "openhoi3-"
ENGINE_ARCHIVE = "OpenHOI3-engine-%s.zip"
LAUNCHER_ARCHIVE = "OpenHOI3-launcher-%s.zip"


def releaseName():
    """'0.1.0' for ENGINE_VERSION 'openhoi3-0.1.0': what the archives are named by."""
    return releaseCommon.engineTag()[1:]


def archives(name=None):
    """(archive file name, folder under installer/openhoi, marker file) for each part.

    \p name is what the archives are named by: the pinned release's number, or
    the rolling build's tag."""
    if name is None:
        name = releaseName()
    return [
        (ENGINE_ARCHIVE % name, releaseCommon.ENGINE_FOLDER, ENGINE_MARKER),
        (LAUNCHER_ARCHIVE % name, releaseCommon.LAUNCHER_FOLDER, LAUNCHER_MARKER),
    ]


def downloadUrl(fileName, tag=None):
    return "%s/releases/download/%s/%s" % (releaseCommon.ENGINE_REPOSITORY,
                                           tag or releaseCommon.engineTag(), fileName)


def readEngineVersion(folder):
    """The version an unpacked engine's engine.txt names, or None."""
    path = os.path.join(folder, ENGINE_MARKER)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.split("#")[0].strip()
            if line.startswith("version"):
                key, _, value = line.partition("=")
                if key.strip() == "version":
                    return value.strip().strip('"')
    return None


def fetchedVersion():
    """The version of the engine unpacked in installer/openhoi, or None where
    there is no engine there, or no launcher beside it."""
    engine = os.path.join(OPENHOI, releaseCommon.ENGINE_FOLDER)
    launcher = os.path.join(OPENHOI, releaseCommon.LAUNCHER_FOLDER, LAUNCHER_MARKER)
    if not os.path.exists(launcher):
        return None
    return readEngineVersion(engine)


def isFetched():
    """Whether installer/openhoi already holds the engine the mod names, and a launcher."""
    return fetchedVersion() == releaseCommon.ENGINE_VERSION


def _sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def _readSums(path):
    """{file name: sha256} out of a SHA256SUMS.txt, as sha256sum writes it."""
    sums = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            parts = line.split(None, 1)
            if len(parts) == 2:
                sums[parts[1].strip().lstrip("*")] = parts[0].lower()
    return sums


def _download(fileName, target, tag):
    url = downloadUrl(fileName, tag)
    print("  get    %s" % fileName)
    print("         %s" % url)
    request = urllib.request.Request(url, headers={"User-Agent": "BlackICE-installer-build"})
    temporary = target + ".part"
    with urllib.request.urlopen(request) as response, open(temporary, "wb") as handle:
        shutil.copyfileobj(response, handle)
    os.replace(temporary, target)
    print("         %.1f MB" % (os.path.getsize(target) / 1048576))


def _obtain(fileName, source, tag):
    """Put one release file into the download folder, from \p source or from GitHub."""
    target = os.path.join(DOWNLOADS, fileName)
    if source:
        candidate = os.path.join(source, fileName)
        if not os.path.exists(candidate):
            raise FileNotFoundError("%s is not in %s" % (fileName, source))
        print("  take   %s" % candidate)
        shutil.copy2(candidate, target)
    else:
        _download(fileName, target, tag)
    return target


def _unpack(archive, folder):
    """Unpack \p archive into an emptied \p folder, refusing a path that would leave it."""
    if os.path.exists(folder):
        shutil.rmtree(folder)
    os.makedirs(folder)
    root = os.path.realpath(folder)
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            # An archive packed by Windows' own tools writes backslashes.
            name = member.filename.replace("\\", "/")
            destination = os.path.realpath(os.path.join(root, *name.split("/")))
            if destination != root and not destination.startswith(root + os.sep):
                raise ValueError("%s holds a path outside itself: %s"
                                 % (os.path.basename(archive), member.filename))
            if name.endswith("/"):
                os.makedirs(destination, exist_ok=True)
                continue
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            with bundle.open(member) as source, open(destination, "wb") as handle:
                shutil.copyfileobj(source, handle)


def _nameInFolder(source):
    """What the archives in a folder of OpenHOI3's are named by, and whether it
    is the release the mod names.

    The pinned release where its engine archive is there; else the one other
    engine the folder holds. More than one other, or none, is an error: the
    folder does not say which engine is meant."""
    pinned = releaseName()
    if os.path.exists(os.path.join(source, ENGINE_ARCHIVE % pinned)):
        return pinned, True
    prefix, suffix = ENGINE_ARCHIVE.split("%s")
    found = [os.path.basename(path)[len(prefix):-len(suffix)]
             for path in glob.glob(os.path.join(source, ENGINE_ARCHIVE % "*"))]
    if len(found) == 1:
        return found[0], False
    if not found:
        raise FileNotFoundError("%s holds no %s" % (source, ENGINE_ARCHIVE % "<version>"))
    raise ValueError("%s holds %d engines (%s) and none is %s: which one is meant?"
                     % (source, len(found), ", ".join(sorted(found)), pinned))


def _sameSums(path):
    """Whether \p path is the SHA256SUMS.txt of the release already unpacked."""
    if not os.path.exists(UNPACKED_SUMS):
        return False
    with open(path, "rb") as fresh, open(UNPACKED_SUMS, "rb") as kept:
        return fresh.read() == kept.read()


def fetch(source=None, force=False, latest=False):
    """Fetch, check and unpack. Returns 0 when installer/openhoi is ready.

    \p latest takes the engine's rolling build in place of the release the mod
    names; \p source a folder of archives in place of GitHub."""
    pinned = not latest
    tag = releaseCommon.ENGINE_LATEST_TAG if latest else releaseCommon.engineTag()
    name = tag if latest else releaseName()
    try:
        if source:
            name, pinned = _nameInFolder(source)
            if latest and pinned:
                # Asked for the rolling build and given a folder holding the named release: say which was taken.
                print("  note   %s holds the release the mod names; --latest changes nothing there." % source)
    except Exception as error:
        print("FAILED: %s" % error)
        return 1

    version = releaseCommon.ENGINE_VERSION
    if pinned:
        print("OpenHOI3 %s for the installer, into %s\n" % (version, OPENHOI))
        if isFetched() and not force:
            print("  have   %s, already unpacked. --force fetches it again." % version)
            return 0
    elif source:
        print("OpenHOI3 from %s (%s) for the installer, into %s\n" % (source, name, OPENHOI))
    else:
        print("OpenHOI3's rolling build, the release of the tag %s, for the installer, into %s\n" % (tag, OPENHOI))

    if os.path.exists(DOWNLOADS):
        shutil.rmtree(DOWNLOADS)
    os.makedirs(DOWNLOADS)

    try:
        sumsPath = _obtain(SUMS, source, tag)
        if not pinned and not force and fetchedVersion() and _sameSums(sumsPath):
            print("  have   %s, the build these checksums are of. --force fetches it again." % fetchedVersion())
            return 0
        sums = _readSums(sumsPath)
        for fileName, folder, marker in archives(name):
            archive = _obtain(fileName, source, tag)
            expected = sums.get(fileName)
            if expected is None:
                print("\nFAILED: %s does not list %s." % (SUMS, fileName))
                return 1
            actual = _sha256(archive)
            if actual != expected:
                print("\nFAILED: %s is not the file the release lists." % fileName)
                print("  %s says %s" % (SUMS, expected))
                print("  the file is  %s" % actual)
                if not pinned and not source:
                    print("The rolling build may have been replaced while it was being fetched: run this again.")
                return 1
            print("  ok     sha256 %s..." % actual[:16])

            target = os.path.join(OPENHOI, folder)
            _unpack(archive, target)
            if not os.path.exists(os.path.join(target, marker)):
                print("\nFAILED: %s holds no %s at its top." % (fileName, marker))
                return 1
            count = sum(len(files) for _root, _dirs, files in os.walk(target))
            print("  unpack %s/  %d files" % (folder, count))
        shutil.copy2(sumsPath, UNPACKED_SUMS)
    except Exception as error:  # a download or an archive that failed: say which, build nothing on it
        print("\nFAILED: %s" % error)
        if not source:
            print("Is %s published? Its release would be at" % tag)
            print("  %s/releases/tag/%s" % (releaseCommon.ENGINE_REPOSITORY, tag))
        return 1
    finally:
        shutil.rmtree(DOWNLOADS, ignore_errors=True)

    found = readEngineVersion(os.path.join(OPENHOI, releaseCommon.ENGINE_FOLDER))
    if pinned:
        # The archive is named by the version, but what the launcher goes by is what
        # engine.txt says. If the two disagree the .mod would name an engine that is
        # not in its folder, and the launcher would refuse to start the mod.
        if found != version:
            print("\nFAILED: the engine unpacked says it is %r, and the mod names %r." % (found, version))
            print("Set releaseCommon.ENGINE_VERSION to the engine you mean to ship.")
            shutil.rmtree(os.path.join(OPENHOI, releaseCommon.ENGINE_FOLDER), ignore_errors=True)
            return 1
    elif not found or not found.startswith(VERSION_PREFIX):
        print("\nFAILED: the engine unpacked says it is %r, which is no version of OpenHOI3's." % found)
        shutil.rmtree(os.path.join(OPENHOI, releaseCommon.ENGINE_FOLDER), ignore_errors=True)
        return 1

    total = 0
    for root, _dirs, files in os.walk(OPENHOI):
        total += sum(os.path.getsize(os.path.join(root, f)) for f in files)
    print("\nReady: engine %s and its launcher, %.0f MB unpacked." % (found, total / 1048576))
    if not pinned:
        print("Not the release the mod names (%s): for a test build, or buildInstaller.py --any-engine." % version)
    return 0


def main():
    parser = argparse.ArgumentParser(description="Fetch the OpenHOI3 engine the installer ships.")
    parser.add_argument("--latest", action="store_true",
                        help="take the engine's rolling build, the release of the tag '%s', "
                             "in place of the release the mod names" % releaseCommon.ENGINE_LATEST_TAG)
    parser.add_argument("--from", dest="source", metavar="FOLDER",
                        help="take the release's files from this folder instead of downloading them")
    parser.add_argument("--force", action="store_true",
                        help="fetch again even if the right engine is already unpacked")
    arguments = parser.parse_args()
    return fetch(arguments.source, arguments.force, arguments.latest)


if __name__ == "__main__":
    sys.exit(main())
