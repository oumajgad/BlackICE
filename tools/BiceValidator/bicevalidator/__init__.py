"""BICE Validator: checks BlackICE's script files before the game silently drops them.

The library is plain Python with no third-party dependency, so the release pipeline and
the command line can use it on any machine. The window in `bicevalidator_gui` is the only
part that needs PySide6.

    from bicevalidator import runner
    result = runner.run(modRoot, modes={"code", "references"})
"""

__version__ = "0.3.11"
