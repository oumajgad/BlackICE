"""Starts the language server over stdin and stdout. Run by the BlackICE Script extension
for VS Code - normally as the bundled bicevalidator-lsp.exe, which is built from this file
(bicevalidator-lsp.spec); from source by pointing the extension's
`blackice.validator.serverCommand` setting at `python <this file>`. Needs pygls.
"""

import multiprocessing
import os
import sys

if __name__ == "__main__":
    # The background run's worker processes re-import this file on Windows; the guard and
    # freeze_support() keep them from starting another server each.
    multiprocessing.freeze_support()
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from bicevalidator_lsp.server import main
    main()
