# PyInstaller spec for BiceValidator.exe: one file, no console, Python and Qt inside.
# Build with `python build.py` from this folder, which also tries the result.
# -*- mode: python ; coding: utf-8 -*-

import datetime
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(SPEC))
DOCS = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "script"))

# The keyword pages go inside the exe, so it can check a mod with no docs/ of its own -
# an installed copy under tfh/mod. A mod that has docs/script is still read from those.
# The stamp says which pages these were.
stamp_dir = os.path.join(HERE, "build", "keywords")
os.makedirs(stamp_dir, exist_ok=True)
try:
    commit = subprocess.run(["git", "-C", HERE, "rev-parse", "--short", "HEAD"],
                            capture_output=True, text=True).stdout.strip()
except OSError:
    commit = ""
with open(os.path.join(stamp_dir, "BUILT.txt"), "w", encoding="utf-8") as handle:
    handle.write("%s%s\n" % (datetime.date.today().isoformat(),
                             ", commit %s" % commit if commit else ""))
keyword_pages = [(os.path.join(DOCS, page + ".md"), "keywords")
                 for page in ("triggers", "effects", "scopes")]
keyword_pages.append((os.path.join(stamp_dir, "BUILT.txt"), "keywords"))
# The schemas of the data files, beside the module that reads them (schemas/__init__.py).
keyword_pages.append((os.path.join(HERE, "bicevalidator", "schemas", "*.json"),
                      os.path.join("bicevalidator", "schemas")))

a = Analysis(
    [os.path.join(HERE, "BiceValidator.pyw")],
    pathex=[HERE],
    datas=keyword_pages,
    # Nothing here uses these, and PyInstaller would otherwise follow stray imports
    # into them.
    excludes=["tkinter", "unittest", "pydoc", "PySide6.QtNetwork", "PySide6.QtQml",
              "PySide6.QtQuick", "PySide6.QtOpenGL", "PySide6.QtPdf", "PySide6.QtSvg"],
)

# The window uses QtCore, QtGui and QtWidgets and nothing else. The PySide6 hook still
# packs Qt's software OpenGL renderer, the translations and image plugins for formats the
# window never shows; dropping them roughly halves the exe.
DROP = (
    "opengl32sw.dll",
    "qt6pdf", "qt6svg", "qt6network", "qt6qml", "qt6quick", "qt6opengl", "qt6virtualkeyboard",
    "translations",
    "imageformats",
    "iconengines",      # only the SVG one, whose Qt6Svg is dropped above
    "qtvirtualkeyboard",
    "networkinformation", "tls",
)


def wanted(entry):
    name = entry[0].replace("\\", "/").lower()
    return not any(part in name for part in DROP)


a.binaries = [b for b in a.binaries if wanted(b)]
a.datas = [d for d in a.datas if wanted(d)]

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="BiceValidator",
    console=False,
    # UPX-packed executables are what virus scanners most often flag by mistake.
    upx=False,
)
