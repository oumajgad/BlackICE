"""One validation run: find the files, read them once, run the checks the modes ask for."""

import glob
import os
import time
from dataclasses import dataclass, field

from . import lexer, parser, rules
from .declarations import Declarations
from .pictures import Pictures
from .schema import Schema, locate_keyword_pages
from .checks import syntax
from .checks.script import ScriptChecker

# Folders read as script, and the patterns in each. Every one is the same language, so
# all get the syntax check; events and decisions also get the script check.
SCRIPT_FOLDERS = (
    ("events", "**/*.txt"),
    ("decisions", "**/*.txt"),
    ("common", "**/*.txt"),
    ("history", "**/*.txt"),
    ("technologies", "**/*.txt"),
    ("units", "**/*.txt"),
    ("map", "*.txt"),
    ("interface", "**/*.gfx"),
    ("interface", "**/*.gui"),
)


# Folders whose parsed trees the reference checks need after the per-file pass.
KEEP = ("events/", "decisions/", "common/")


@dataclass
class ParsedFile:
    source: object
    result: object


@dataclass
class Result:
    root: str
    modes: set
    diagnostics: list = field(default_factory=list)
    files: dict = field(default_factory=dict)     # relpath -> ParsedFile
    notes: list = field(default_factory=list)     # setup problems worth showing the user
    seconds: float = 0.0
    checked: int = 0                              # files reported on
    keywords_from: str = ""                       # which copy of the keyword pages was read


def find_mod_root(start):
    """The mod at or above \\p start: the folder with events, decisions and common beside
    each other. A git checkout and an installed copy under tfh/mod both qualify."""
    current = os.path.abspath(start)
    while True:
        if all(os.path.isdir(os.path.join(current, d))
               for d in ("events", "decisions", "common")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            return None
        current = parent


def list_files(root, only=None):
    """Every script file, relative with forward slashes; \\p only narrows to a set."""
    out = []
    for folder, pattern in SCRIPT_FOLDERS:
        for path in glob.glob(os.path.join(root, folder, pattern), recursive=True):
            rel = os.path.relpath(path, root).replace("\\", "/")
            if only is None or rel in only:
                out.append(rel)
    return sorted(set(out))


def check_file(source, parsed, checker, modes=(rules.CODE,)):
    """The per-file checks for one parsed file: syntax always, and the script checks for
    events and decisions in code mode. Shared by a run and the language server."""
    found = syntax.check(source, parsed)
    if rules.CODE in modes:
        folder = source.path.split("/", 1)[0]
        if folder == "events":
            found += checker.check_events(source, parsed.root)
        elif folder == "decisions":
            found += checker.check_decisions(source, parsed.root)
    return found


def _syntax_only(root, rels):
    """The syntax check for a batch of files, in a worker process."""
    out = []
    for rel in rels:
        source = lexer.read(root, rel)
        out.extend(syntax.check(source, parser.parse(source.text)))
    return len(rels), out


def _start_pool(root, rels, workers):
    """Hand \\p rels to a process pool in batches; (pool, futures), or None if a pool
    cannot be had here - the run then does everything in this process."""
    try:
        import multiprocessing
        from concurrent.futures import ProcessPoolExecutor
        # A script that calls run() without an `if __name__ == "__main__"` guard is
        # re-executed by every worker Windows spawns; never start a pool from a worker.
        if multiprocessing.parent_process() is not None:
            return None
        workers = workers or max(1, (os.cpu_count() or 2) - 1)
        if workers < 2:
            return None
        pool = ProcessPoolExecutor(max_workers=workers)
        size = max(50, len(rels) // (workers * 4))
        batches = [rels[i:i + size] for i in range(0, len(rels), size)]
        futures = [pool.submit(_syntax_only, root, batch) for batch in batches]
        return pool, futures, batches
    except (OSError, ImportError, NotImplementedError, RuntimeError):
        return None


def run(root, modes=(rules.CODE,), only=None, progress=None, workers=None, game=None):
    """Validate the mod at \\p root.

    \\p only limits which files are *reported on* (the changed-files mode); declarations
    and, for references, the whole mod are still read, since a reference is only
    meaningful against everything.
    \\p progress, if given, is called as progress(done, total, message).
    \\p workers is how many processes check the syntax-only files; None means one fewer
    than there are cores, and 1 keeps everything in this process.
    \\p game is the game install, for the event pictures the mod does not ship; None
    finds it beside the mod (pictures.find_game).
    """
    started = time.time()
    modes = set(modes)
    result = Result(root, modes)

    def tell(done, total, message):
        if progress is not None:
            progress(done, total, message)

    cache = {}

    def load(rel):
        if rel not in cache:
            if not os.path.exists(os.path.join(root, rel)):
                return None
            source = lexer.read(root, rel)
            cache[rel] = (source, parser.parse(source.text))
        return cache[rel]

    tell(0, 1, "Reading the keyword lists and what the mod declares")
    docs, result.keywords_from = locate_keyword_pages(root)
    schema = Schema(docs)
    declarations = Declarations(root, load)
    for missing in declarations.missing:
        result.notes.append("Not found, so names it declares are unknown: %s" % missing)
    checker = ScriptChecker(schema, declarations)

    files = list_files(root)
    report_on = set(files) if only is None else set(files) & set(only)
    need_all = rules.REFERENCES in modes
    if rules.CODE in modes:
        to_read = [f for f in files if f in report_on or (need_all and f.startswith(KEEP))]
    else:
        # References alone need only the folders they read; the other 18,000 files would
        # be parsed for nothing.
        to_read = [f for f in files if f.startswith(KEEP)]
    total = len(to_read)
    result.checked = len(report_on)

    # Files that only get the syntax check, and that nothing has parsed yet, go to other
    # processes: they are the province histories, nine tenths of every run.
    remote = [f for f in to_read if not f.startswith(KEEP) and f not in cache]
    local = [f for f in to_read if f.startswith(KEEP) or f in cache]
    pending = _start_pool(root, remote, workers) if len(remote) > 200 else None
    if pending is None:
        local = to_read

    done = 0
    for rel in local:
        done += 1
        if done % 25 == 0:
            tell(done, total, rel)
        source, parsed = load(rel)
        if rel.startswith(KEEP):
            result.files[rel] = ParsedFile(source, parsed)
        # The 18,000 province histories are checked and let go; keeping every tree
        # would cost gigabytes for files no later check reads.
        cache.pop(rel, None)
        if rel not in report_on:
            continue
        result.diagnostics.extend(check_file(source, parsed, checker, modes))

    if pending is not None:
        pool, futures, batches = pending
        try:
            for future, batch in zip(futures, batches):
                try:
                    count, found = future.result()
                except Exception:
                    # A broken pool is not a reason to lose the run: do the batch here.
                    count, found = _syntax_only(root, batch)
                done += count
                tell(done, total, "province and unit histories")
                result.diagnostics.extend(found)
        finally:
            pool.shutdown(cancel_futures=True)

    if rules.REFERENCES in modes:
        from .checks import references
        tell(total, total, "Checking references")
        # Without the game, every picture the mod takes from it would look missing.
        pictures = Pictures(root, game)
        if pictures.game is None:
            result.notes.append(
                "Event pictures were not checked (BV212): the game install was not found%s."
                % (" at %s" % game if game else " beside the mod; name it with --game, or "
                   "with blackice.validator.gameFolder in VS Code"))
            pictures = None
        found = references.check(root, result.files, declarations, schema, pictures)
        result.diagnostics.extend(d for d in found if d.file in report_on
                                  or d.file not in result.files)

    # Syntax findings belong to the code mode; a references-only run still shows the
    # ones that stop a file being read, since its other findings depend on them.
    if rules.CODE not in modes:
        result.diagnostics = [d for d in result.diagnostics
                              if rules.RULES[d.rule].mode == rules.REFERENCES
                              or d.rule in ("BV001", "BV002", "BV003")]
    result.diagnostics.sort(key=lambda d: (d.file, d.line, d.col, d.rule))
    result.seconds = time.time() - started
    tell(total, total, "Done")
    return result
