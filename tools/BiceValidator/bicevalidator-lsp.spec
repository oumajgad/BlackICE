# PyInstaller spec for bicevalidator-lsp.exe, the language server inside the BlackICE Script
# extension. A console program - VS Code talks to it over stdin and stdout - with Python and
# the keyword pages inside, and no Qt. Built by vscode/build.py.
# -*- mode: python ; coding: utf-8 -*-

import datetime
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(SPEC))
DOCS = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "script"))

# The same built-in keyword pages as BiceValidator.exe, for a mod with no docs/ folder.
stamp_dir = os.path.join(HERE, "build", "keywords-lsp")
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
    [os.path.join(HERE, "BiceValidatorLsp.py")],
    pathex=[HERE],
    datas=keyword_pages,
    excludes=["tkinter", "unittest", "pydoc", "PySide6", "shiboken6"],
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="bicevalidator-lsp",
    console=True,
    upx=False,
)
