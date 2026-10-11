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


def try_exe(label, mod, expect_keywords):
    """Have the exe validate \\p mod; True if it finished and read the expected pages."""
    report = os.path.join(tempfile.mkdtemp(prefix="bicevalidator-"), "smoke.txt")
    started = time.time()
    result = subprocess.run([EXE, "--smoke-test", mod, report], timeout=600)
    if result.returncode != 0 or not os.path.exists(report):
        print("  %s: FAILED, exit code %d, report %s"
              % (label, result.returncode, "written" if os.path.exists(report) else "missing"))
        return False
    with open(report, encoding="utf-8") as handle:
        text = handle.read().strip()
    print("  %s: %s  (%.1fs with start-up)" % (label, text, time.time() - started))
    if expect_keywords not in text:
        print("  %s: FAILED, expected keywords from %s" % (label, expect_keywords))
        return False
    return True


def smoke_test():
    """Two runs: this checkout, through the exe's worker processes; and a mod with no
    docs/ folder, like an installed copy, which must fall back to the pages built in."""
    sys.path.insert(0, HERE)
    from bicevalidator import runner
    ok = True
    mod = runner.find_mod_root(HERE)
    if mod is None:
        print("  checkout test skipped: no BlackICE checkout around %s" % HERE)
    else:
        ok &= try_exe("this checkout", mod, "docs/script")

    bare = tempfile.mkdtemp(prefix="bicevalidator-bare-")
    for folder in ("events", "decisions", "common"):
        os.makedirs(os.path.join(bare, folder))
    with open(os.path.join(bare, "common", "countries.txt"), "w") as handle:
        handle.write('GER = "countries/Germany.txt"\n')
    with open(os.path.join(bare, "events", "test.txt"), "w") as handle:
        handle.write("country_event = {\n\tid = 1\n\tis_triggered_only = yes\n"
                     "\toption = { name = A war_with = GER }\n}\n")
    ok &= try_exe("a mod with no docs", bare, "built into the exe")
    return 0 if ok else 1


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
