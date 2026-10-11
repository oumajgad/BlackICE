"""Double-click to open the BICE Validator window. Needs PySide6: pip install PySide6

This is also the entry point of the bundled BiceValidator.exe (BiceValidator.spec).
"""

import multiprocessing
import os
import sys

if __name__ == "__main__":
    # The guard matters: the run's worker processes re-import this file on Windows, and
    # must not open a window each. freeze_support() is what lets a worker started from
    # the bundled exe run its task instead of starting another copy of the program.
    multiprocessing.freeze_support()
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from bicevalidator_gui.app import main
    sys.exit(main())
