"""Build dist/BiceValidator.exe, a single exe that needs no Python on the machine.

    pip install pyinstaller PySide6
    python build.py

Then tries the exe: it validates this checkout through the exe's own worker processes,
which is the part of a bundle most likely to break, and says how it went. The build
workflow (.github/workflows/build-validator.yml) runs exactly this.
"""

import os
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
DIST = os.path.join(HERE, "dist")
BUILD = os.path.join(HERE, "build")
EXE = os.path.join(DIST, "BiceValidator.exe")


def build():
    command = [sys.executable, "-m", "PyInstaller", "--noconfirm", "--clean",
               "--distpath", DIST, "--workpath", BUILD,
               os.path.join(HERE, "BiceValidator.spec")]
    print("  " + " ".join(command))
    return subprocess.run(command, cwd=HERE).returncode


def smoke_test():
    sys.path.insert(0, HERE)
    from bicevalidator import runner
    mod = runner.find_mod_root(HERE)
    if mod is None:
        print("  smoke test skipped: no BlackICE checkout around %s" % HERE)
        return 0
    report = os.path.join(tempfile.mkdtemp(prefix="bicevalidator-"), "smoke.txt")
    started = time.time()
    # A windowed exe returns at once from a plain call; wait for it explicitly.
    result = subprocess.run([EXE, "--smoke-test", mod, report], timeout=600)
    if result.returncode != 0 or not os.path.exists(report):
        print("  smoke test FAILED: exit code %d, report %s"
              % (result.returncode, "written" if os.path.exists(report) else "missing"))
        return 1
    with open(report, encoding="utf-8") as handle:
        print("  smoke test: %s  (%.1fs with start-up)" % (handle.read().strip(),
                                                         time.time() - started))
    return 0


def main():
    if build() != 0:
        print("PyInstaller failed.")
        return 1
    size = os.path.getsize(EXE) / 1048576
    print("\n  %s\n  %.0f MB" % (EXE, size))
    if "--no-test" in sys.argv:
        return 0
    return smoke_test()


if __name__ == "__main__":
    sys.exit(main())
