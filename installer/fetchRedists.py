"""Downloads the Microsoft runtimes the installer bundles, from Microsoft.

The list is not the usual "install everything back to 2005" advice - it is what
the shipped binaries actually import:

    VC++ 2005 SP1 x86   lua51.dll, lua5.1.dll, script/lfs.dll  (Microsoft.VC80.CRT)
    VC++ 2008 SP1 x86   PdxConnect.dll, script/wx.dll          (Microsoft.VC90.CRT)
    VC++ 2010 SP1 x86   tbb.dll, tbbmalloc.dll, hoi3game.exe   (msvcr100.dll)
    VC++ 2015-2022 x86  script/BiceLib.dll                     (vcruntime140, UCRT)
    VC++ 2015-2022 x64  stats/visualizeStatisticCLI.exe        (64 bit tool)
    DirectX 9.0c        hoi3_tfh.exe imports d3dx9_42.dll

VC++ 2012 and 2013 are deliberately absent: nothing in the game or the mod links
against them. .NET 3.5 is absent too - it is a Windows feature, not a download,
and the installer enables it through DISM.

The DirectX end user runtime is a 95 MB bundle of which we need three support
files and one cab, so it is downloaded, unpacked and trimmed rather than shipped
whole. Run this once before building; the output is gitignored.
"""
import fnmatch
import os
import shutil
import subprocess
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REDIST = os.path.join(HERE, "redist")

# Official Microsoft download URLs. aka.ms links are Microsoft's own permalinks
# and always resolve to the current servicing build.
DOWNLOADS = [
    # (file name, url, what needs it)
    ("vcredist2005_x86.exe",
     "https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE",
     "lua51.dll, lfs.dll (Microsoft.VC80.CRT)"),
    ("vcredist2008_x86.exe",
     "https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe",
     "PdxConnect.dll, wx.dll (Microsoft.VC90.CRT)"),
    ("vcredist2010_x86.exe",
     "https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe",
     "tbb.dll, hoi3game.exe (msvcr100.dll)"),
    ("vcredist2022_x86.exe",
     "https://aka.ms/vs/17/release/vc_redist.x86.exe",
     "BiceLib.dll (vcruntime140.dll, UCRT)"),
    ("vcredist2022_x64.exe",
     "https://aka.ms/vs/17/release/vc_redist.x64.exe",
     "visualizeStatisticCLI.exe (64 bit)"),
]

DIRECTX_URL = ("https://download.microsoft.com/download/8/4/A/"
               "84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe")

# DXSETUP needs its loader, its update cab and the cab holding the one library
# the game imports. Everything else in the bundle is for APIs HoI3 never calls,
# which is what takes it from 95 MB to about 3 MB.
DIRECTX_KEEP = [
    "DXSETUP.exe",
    "dsetup32.dll",
    "DSETUP.dll",
    "dxupdate.cab",
    "dxdllreg_x86.cab",
]

# Matched as a pattern rather than a fixed name: the cabs are named after the
# SDK release that introduced the library, not the release of the bundle, so
# d3dx9_42 lives in Aug2009_d3dx9_42_x86.cab inside the June 2010 download.
DIRECTX_KEEP_PATTERNS = [
    "*d3dx9_42_x86.cab",
]


def _sevenZip():
    for candidate in (r"C:\Program Files\7-Zip\7z.exe",
                      r"C:\Program Files (x86)\7-Zip\7z.exe"):
        if os.path.exists(candidate):
            return candidate
    found = shutil.which("7z")
    if found:
        return found
    return None


def _download(url, target):
    if os.path.exists(target):
        print("  have   %s (%.1f MB)" % (os.path.basename(target),
                                         os.path.getsize(target) / 1048576))
        return

    print("  get    %s" % os.path.basename(target))
    print("         %s" % url)
    request = urllib.request.Request(url, headers={"User-Agent": "BlackICE-installer-build"})
    temporary = target + ".part"
    with urllib.request.urlopen(request) as response, open(temporary, "wb") as handle:
        shutil.copyfileobj(response, handle)
    os.replace(temporary, target)
    print("         %.1f MB" % (os.path.getsize(target) / 1048576))


def fetchDirectX():
    """Download the June 2010 runtime and keep only the d3dx9_42 pieces."""
    directory = os.path.join(REDIST, "directx")
    marker = os.path.join(directory, "DXSETUP.exe")
    if os.path.exists(marker):
        print("  have   directx/ (trimmed)")
        return

    sevenZip = _sevenZip()
    if sevenZip is None:
        print("  SKIP   DirectX: 7-Zip not found, cannot unpack the bundle.")
        print("         Install 7-Zip, or unpack directx_Jun2010_redist.exe by hand into")
        print("         %s and delete everything except:" % directory)
        print("         %s" % ", ".join(DIRECTX_KEEP))
        return

    bundle = os.path.join(REDIST, "directx_Jun2010_redist.exe")
    _download(DIRECTX_URL, bundle)

    unpacked = os.path.join(REDIST, "_directx_full")
    if os.path.exists(unpacked):
        shutil.rmtree(unpacked)
    print("  unpack directx_Jun2010_redist.exe")
    subprocess.run([sevenZip, "x", "-y", "-o" + unpacked, bundle],
                   check=True, stdout=subprocess.DEVNULL)

    os.makedirs(directory, exist_ok=True)

    # One walk, matching both the fixed names and the cab patterns.
    wanted = {name.lower(): name for name in DIRECTX_KEEP}
    found = {}
    for root, _dirs, files in os.walk(unpacked):
        for candidate in files:
            lower = candidate.lower()
            if lower in wanted and wanted[lower] not in found:
                found[wanted[lower]] = os.path.join(root, candidate)
                continue
            for pattern in DIRECTX_KEEP_PATTERNS:
                if fnmatch.fnmatch(lower, pattern.lower()) and candidate not in found:
                    found[candidate] = os.path.join(root, candidate)

    for name, source in found.items():
        shutil.copy2(source, os.path.join(directory, name))

    missing = [name for name in DIRECTX_KEEP if name not in found]
    if not any(fnmatch.fnmatch(name.lower(), pattern.lower())
               for name in found for pattern in DIRECTX_KEEP_PATTERNS):
        missing.append(" or ".join(DIRECTX_KEEP_PATTERNS))

    shutil.rmtree(unpacked)
    if missing:
        print("  WARN   DirectX bundle did not contain: %s" % ", ".join(missing))
        print("         The layout of the Microsoft bundle may have changed.")
    else:
        kept = sum(os.path.getsize(os.path.join(directory, f)) for f in found)
        print("  trim   kept %d files, %.1f MB (bundle was %.0f MB)"
              % (len(found), kept / 1048576, os.path.getsize(bundle) / 1048576))
        print("         %s" % ", ".join(sorted(found)))
    os.remove(bundle)


def main():
    os.makedirs(REDIST, exist_ok=True)
    print("Fetching Microsoft redistributables into %s\n" % REDIST)

    failures = []
    for name, url, reason in DOWNLOADS:
        print("%s  <- %s" % (name, reason))
        try:
            _download(url, os.path.join(REDIST, name))
        except Exception as error:
            print("  FAIL   %s" % error)
            failures.append(name)

    print("\ndirectx/  <- hoi3_tfh.exe imports d3dx9_42.dll")
    try:
        fetchDirectX()
    except Exception as error:
        print("  FAIL   %s" % error)
        failures.append("directx")

    total = 0
    for root, _dirs, files in os.walk(REDIST):
        total += sum(os.path.getsize(os.path.join(root, f)) for f in files)
    print("\nTotal bundled: %.1f MB" % (total / 1048576))

    if failures:
        print("\nFAILED: %s" % ", ".join(failures))
        print("The installer will still build, but will fall back to telling the")
        print("player what is missing instead of installing it.")
        return 1
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
