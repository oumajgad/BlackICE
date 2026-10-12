"""The check a release build runs: stop on what leaves a file unreadable, report the rest.

Called by installer/buildInstaller.py. Only the library is used, so a build machine needs
nothing beyond Python - no PySide6.
"""

from collections import Counter

from . import review, rules, runner
from .baseline import Baseline
from .config import Config


def check(root, out=print):
    """Validate \\p root in code mode. Returns True if the release may go ahead.

    A new finding of a rule listed in validator.json's `release_blocking` stops it; every
    other new finding is counted, so the build log says how much is outstanding.
    """
    config = Config.for_mod(root)
    result = runner.run(root, [rules.CODE])
    items = review.classify(result.diagnostics, config, Baseline(config.baseline_path))
    new = [i for i in items if i.is_new]
    blocking = [i for i in new if i.diagnostic.rule in config.release_blocking]
    counts = Counter(i.diagnostic.severity for i in new)
    summary = ", ".join("%d %s" % (counts[s], s) for s in rules.SEVERITIES if counts[s])
    out("  validator: %d files in %.1fs, %d new findings (%s)"
        % (result.checked, result.seconds, len(new), summary or "none"))
    if blocking:
        out("\nThese stop the build - a file cannot be read past them:")
        for item in blocking:
            out("  " + item.diagnostic.format())
            if item.diagnostic.hint:
                out("      " + item.diagnostic.hint)
        out("\nFix them, or look at them in tools/BiceValidator/dist/BiceValidator.exe.")
    return not blocking
