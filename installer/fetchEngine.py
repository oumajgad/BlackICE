"""Fetches the OpenHOI3 engine and launcher the installer ships, from the engine's releases.

The mod is made for one release of OpenHOI3, named in releaseCommon.ENGINE_VERSION.
This downloads that release's two archives from GitHub, checks them against the
release's own SHA256SUMS.txt, and unpacks them into installer/openhoi/:

    installer/openhoi/engine/      OpenHOI3.exe, engine.txt, ...  -> tfh/mod/BlackICE <ver>/engine
    installer/openhoi/launcher/    OpenHOI3.Launcher.exe, ...     -> tfh/mod/BlackICE <ver>/launcher

Nothing of it is committed - the engine is about 210 MB - and the folder is
gitignored. Run this once before building the installer, and again after
ENGINE_VERSION changes; with the right version already unpacked it does nothing.

    python installer/fetchEngine.py
    python installer/fetchEngine.py --from C:/path/to/OpenHOI3/export/release

--from takes the archives from a folder instead of downloading them: the
export/release folder that OpenHOI3's tools/build_release.ps1 leaves, for trying
an engine that has not been published. The check against SHA256SUMS.txt and
against the version in engine.txt is the same either way, so an engine that is
not the one the mod names never reaches the installer.
"""
import argparse
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

# The file each unpacked part must hold to be what it says it is.
ENGINE_MARKER = "engine.txt"
LAUNCHER_MARKER = "OpenHOI3.Launcher.exe"


def releaseName():
    """'0.1.0' for ENGINE_VERSION 'openhoi3-0.1.0': what the archives are named by."""
    return releaseCommon.engineTag()[1:]


def archives():
    """(archive file name, folder under installer/openhoi, marker file) for each part."""
    name = releaseName()
    return [
        ("OpenHOI3-engine-%s.zip" % name, releaseCommon.ENGINE_FOLDER, ENGINE_MARKER),
        ("OpenHOI3-launcher-%s.zip" % name, releaseCommon.LAUNCHER_FOLDER, LAUNCHER_MARKER),
    ]


def downloadUrl(fileName):
    return "%s/releases/download/%s/%s" % (releaseCommon.ENGINE_REPOSITORY,
                                           releaseCommon.engineTag(), fileName)


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


def isFetched():
    """Whether installer/openhoi already holds the engine the mod names, and a launcher."""
    engine = os.path.join(OPENHOI, releaseCommon.ENGINE_FOLDER)
    launcher = os.path.join(OPENHOI, releaseCommon.LAUNCHER_FOLDER, LAUNCHER_MARKER)
    return readEngineVersion(engine) == releaseCommon.ENGINE_VERSION and os.path.exists(launcher)


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


def _download(fileName, target):
    url = downloadUrl(fileName)
    print("  get    %s" % fileName)
    print("         %s" % url)
    request = urllib.request.Request(url, headers={"User-Agent": "BlackICE-installer-build"})
    temporary = target + ".part"
    with urllib.request.urlopen(request) as response, open(temporary, "wb") as handle:
        shutil.copyfileobj(response, handle)
    os.replace(temporary, target)
    print("         %.1f MB" % (os.path.getsize(target) / 1048576))


def _obtain(fileName, source):
    """Put one release file into the download folder, from \p source or from GitHub."""
    target = os.path.join(DOWNLOADS, fileName)
    if source:
        candidate = os.path.join(source, fileName)
        if not os.path.exists(candidate):
            raise FileNotFoundError("%s is not in %s" % (fileName, source))
        print("  take   %s" % candidate)
        shutil.copy2(candidate, target)
    else:
        _download(fileName, target)
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


def fetch(source=None, force=False):
    """Fetch, check and unpack. Returns 0 when installer/openhoi is ready."""
    version = releaseCommon.ENGINE_VERSION
    print("OpenHOI3 %s for the installer, into %s\n" % (version, OPENHOI))

    if isFetched() and not force:
        print("  have   %s, already unpacked. --force fetches it again." % version)
        return 0

    if os.path.exists(DOWNLOADS):
        shutil.rmtree(DOWNLOADS)
    os.makedirs(DOWNLOADS)

    try:
        sums = _readSums(_obtain(SUMS, source))
        for fileName, folder, marker in archives():
            archive = _obtain(fileName, source)
            expected = sums.get(fileName)
            if expected is None:
                print("\nFAILED: %s does not list %s." % (SUMS, fileName))
                return 1
            actual = _sha256(archive)
            if actual != expected:
                print("\nFAILED: %s is not the file the release lists." % fileName)
                print("  %s says %s" % (SUMS, expected))
                print("  the file is  %s" % actual)
                return 1
            print("  ok     sha256 %s..." % actual[:16])

            target = os.path.join(OPENHOI, folder)
            _unpack(archive, target)
            if not os.path.exists(os.path.join(target, marker)):
                print("\nFAILED: %s holds no %s at its top." % (fileName, marker))
                return 1
            count = sum(len(files) for _root, _dirs, files in os.walk(target))
            print("  unpack %s/  %d files" % (folder, count))
    except Exception as error:  # a download or an archive that failed: say which, build nothing on it
        print("\nFAILED: %s" % error)
        if not source:
            print("Is %s published? Its release would be at" % releaseCommon.engineTag())
            print("  %s/releases/tag/%s" % (releaseCommon.ENGINE_REPOSITORY, releaseCommon.engineTag()))
        return 1
    finally:
        shutil.rmtree(DOWNLOADS, ignore_errors=True)

    # The archive is named by the version, but what the launcher goes by is what
    # engine.txt says. If the two disagree the .mod would name an engine that is
    # not in its folder, and the launcher would refuse to start the mod.
    found = readEngineVersion(os.path.join(OPENHOI, releaseCommon.ENGINE_FOLDER))
    if found != version:
        print("\nFAILED: the engine unpacked says it is %r, and the mod names %r." % (found, version))
        print("Set releaseCommon.ENGINE_VERSION to the engine you mean to ship.")
        shutil.rmtree(os.path.join(OPENHOI, releaseCommon.ENGINE_FOLDER), ignore_errors=True)
        return 1

    total = 0
    for root, _dirs, files in os.walk(OPENHOI):
        total += sum(os.path.getsize(os.path.join(root, f)) for f in files)
    print("\nReady: engine %s and its launcher, %.0f MB unpacked." % (version, total / 1048576))
    return 0


def main():
    parser = argparse.ArgumentParser(description="Fetch the OpenHOI3 engine the mod is made for.")
    parser.add_argument("--from", dest="source", metavar="FOLDER",
                        help="take the release's files from this folder instead of downloading them")
    parser.add_argument("--force", action="store_true",
                        help="fetch again even if the right version is already unpacked")
    arguments = parser.parse_args()
    return fetch(arguments.source, arguments.force)


if __name__ == "__main__":
    sys.exit(main())
