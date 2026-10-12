"""The command line, for the release pipeline and for anyone without the window.

    python -m bicevalidator                       # code mode, the whole mod
    python -m bicevalidator --mode all            # code and references
    python -m bicevalidator --changed             # only files git sees as changed
    python -m bicevalidator --update-baseline     # accept everything found as known noise

Run from tools/BiceValidator, or with that folder on PYTHONPATH. Prints one finding per line
as `file:line:col: severity id message`, which VS Code's terminal turns into links, and
exits 1 when a new finding is at or above --fail-on.
"""

import argparse
import json
import os
import subprocess
import sys

from . import rules, runner, review
from .baseline import Baseline
from .config import Config


def changed_files(root):
    """Files git reports as modified, added or untracked under \\p root, relative to it."""
    try:
        top = subprocess.run(["git", "-C", root, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, check=True).stdout.strip()
        status = subprocess.run(["git", "-C", root, "status", "--porcelain", "-uall"],
                                capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        raise SystemExit("--changed needs git: %s" % error)
    out = set()
    for line in status.splitlines():
        path = line[3:].strip().strip('"')
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        full = os.path.normpath(os.path.join(top, path))
        rel = os.path.relpath(full, root).replace("\\", "/")
        if not rel.startswith(".."):
            out.add(rel)
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(prog="bicevalidator", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mod", help="the BlackICE checkout (default: found from here)")
    parser.add_argument("--mode", choices=("code", "references", "all"), default="code")
    parser.add_argument("--changed", action="store_true",
                        help="report only on files git sees as changed")
    parser.add_argument("--fail-on", choices=("error", "warning", "info", "never"),
                        default="error", help="exit 1 if a new finding is this bad or worse")
    parser.add_argument("--show-known", action="store_true",
                        help="also print findings the baseline accepts")
    parser.add_argument("--show-hidden", action="store_true",
                        help="also print findings of rules validator.json hides")
    parser.add_argument("--no-baseline", action="store_true", help="ignore the baseline")
    parser.add_argument("--update-baseline", action="store_true",
                        help="make the baseline exactly what this run finds (needs a full "
                             "run: --mode all, no --changed)")
    parser.add_argument("--json", action="store_true", help="print findings as JSON")
    parser.add_argument("--rules", action="store_true", help="list the rules and stop")
    parser.add_argument("--workers", type=int, help="processes for the syntax pass")
    parser.add_argument("--game", help="the Hearts of Iron 3 folder, for event pictures the "
                                       "mod does not ship (default: found beside the mod)")
    args = parser.parse_args(argv)

    if args.rules:
        for rule in rules.RULES.values():
            print("%s  %-7s  %-10s  %-9s  %s" % (rule.id, rule.severity, rule.mode,
                                                  rule.confidence, rule.title))
        return 0

    root = args.mod or runner.find_mod_root(os.getcwd()) or \
        runner.find_mod_root(os.path.dirname(os.path.abspath(__file__)))
    if root is None:
        raise SystemExit("No BlackICE checkout found here or above; pass --mod")
    modes = {"code": [rules.CODE], "references": [rules.REFERENCES],
             "all": [rules.CODE, rules.REFERENCES]}[args.mode]
    only = changed_files(root) if args.changed else None
    if args.update_baseline and (args.changed or args.mode != "all"):
        raise SystemExit("--update-baseline needs --mode all and no --changed, or it would "
                         "drop every accepted finding the run did not look at")

    def progress(done, total, message):
        if sys.stderr.isatty():
            sys.stderr.write("\r%5d/%d  %-60s" % (done, total, message[:60]))
            sys.stderr.flush()

    result = runner.run(root, modes, only=only, progress=progress, workers=args.workers,
                        game=args.game)
    if sys.stderr.isatty():
        sys.stderr.write("\r" + " " * 80 + "\r")

    config = Config.for_mod(root)
    baseline = None if args.no_baseline else Baseline(config.baseline_path)
    if args.update_baseline:
        baseline = Baseline(config.baseline_path)
        baseline.replace(result.diagnostics)
        baseline.save()
        print("Baseline now holds %d findings: %s" % (len(baseline), config.baseline_path))
        return 0

    items = review.classify(result.diagnostics, config, baseline)
    shown = [i for i in items if (i.is_new or (args.show_known and i.known)
                                  or (args.show_hidden and i.hidden))]
    for note in result.notes:
        print("note: %s" % note, file=sys.stderr)
    if args.json:
        json.dump([dict(rule=i.diagnostic.rule, severity=i.diagnostic.severity,
                        file=i.diagnostic.file, line=i.diagnostic.line, col=i.diagnostic.col,
                        message=i.diagnostic.message, context=i.diagnostic.context,
                        hint=i.diagnostic.hint, known=i.known, hidden=i.hidden)
                   for i in shown], sys.stdout, indent=1)
        print()
    else:
        for item in shown:
            tag = " (known)" if item.known else " (hidden)" if item.hidden else ""
            print(item.diagnostic.format() + tag)
    new = [i for i in items if i.is_new]
    counts = {s: sum(1 for i in new if i.diagnostic.severity == s) for s in rules.SEVERITIES}
    print("%d files, %.1fs: %d new (%d errors, %d warnings, %d info), %d known, %d hidden"
          % (result.checked, result.seconds, len(new),
             counts["error"], counts["warning"], counts["info"],
             sum(1 for i in items if i.known), sum(1 for i in items if i.hidden and not i.known)),
          file=sys.stderr)
    return 1 if review.fails(items, args.fail_on) else 0


if __name__ == "__main__":
    sys.exit(main())
