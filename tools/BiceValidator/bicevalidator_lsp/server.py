"""The language server: findings in the editor while typing, and after every save.

Two sources feed what a file shows:

- **Live**: the code-mode checks of the text in the editor, run a moment after typing
  stops. Only for open files, and from the unsaved text.
- **Background**: a run over the whole mod after each save (and at start-up) - the
  reference checks, which need every file, and in "workspace" scope the code checks of
  every file too. Read from disk, so it describes what was last saved.

For an open file, live findings replace the background run's code findings; reference
findings always come from the background run.
"""

import asyncio
import os
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field

from lsprotocol import types as T
from pygls.lsp.server import LanguageServer
from pygls.uris import from_fs_path, to_fs_path

from bicevalidator import __version__, lexer, rules, runner
from bicevalidator.baseline import Baseline
from bicevalidator.config import TOOL_IN_MOD
from bicevalidator.session import Session

SECTION = "blackice.validator"
SOURCE = "BICE Validator"
TYPING_DELAY = 0.3      # seconds of quiet before a changed file is checked
RUN_DELAY = 1.0         # seconds after a save before the background run starts

_SEVERITY = {rules.ERROR: T.DiagnosticSeverity.Error,
             rules.WARNING: T.DiagnosticSeverity.Warning,
             rules.INFO: T.DiagnosticSeverity.Information}


@dataclass
class Settings:
    """The extension's settings, `blackice.validator.*` in VS Code."""
    enable: bool = True
    disabled_rules: set = field(default_factory=set)
    minimum_severity: str = rules.INFO
    references: str = "onSave"          # "onSave" or "off"
    scope: str = "openFiles"            # "openFiles" or "workspace"
    hide_known_noise: bool = False

    @classmethod
    def from_client(cls, data):
        data = data or {}
        settings = cls()
        settings.enable = bool(data.get("enable", True))
        settings.disabled_rules = {str(r).upper() for r in data.get("disabledRules") or ()}
        level = data.get("minimumSeverity", rules.INFO)
        settings.minimum_severity = level if level in rules.SEVERITIES else rules.INFO
        settings.references = "off" if data.get("references") == "off" else "onSave"
        settings.scope = "workspace" if data.get("scope") == "workspace" else "openFiles"
        settings.hide_known_noise = bool(data.get("hideKnownNoise", False))
        return settings

    def shows(self, diagnostic):
        if not self.enable or diagnostic.rule in self.disabled_rules:
            return False
        if self.references == "off" and \
                rules.RULES[diagnostic.rule].mode == rules.REFERENCES:
            return False
        return rules.SEVERITIES.index(diagnostic.severity) <= \
            rules.SEVERITIES.index(self.minimum_severity)

    def background_modes(self):
        modes = []
        if self.enable and self.scope == "workspace":
            modes.append(rules.CODE)
        if self.enable and self.references == "onSave":
            modes.append(rules.REFERENCES)
        return modes


@dataclass
class Mod:
    """Everything the server holds for one mod folder."""
    root: str
    session: Session = None
    background: dict = field(default_factory=dict)   # rel -> [Diagnostic], last run
    published: set = field(default_factory=set)      # rels with findings shown now
    baseline: Baseline = None
    run_task: object = None
    run_again: bool = False


class BiceServer(LanguageServer):
    def __init__(self):
        super().__init__("bicevalidator-lsp", __version__,
                         text_document_sync_kind=T.TextDocumentSyncKind.Incremental)
        self.settings = Settings()
        self.mods = {}          # root -> Mod
        self.loading = {}       # root -> Future of its Session
        self.open = {}          # (root, rel) -> uri, for the files open in the editor
        self.live = {}          # (root, rel) -> [Diagnostic]
        self.timers = {}        # uri -> pending check
        self.executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="bicevalidator")

    # --- mods --------------------------------------------------------------------------

    def locate(self, uri):
        """(root, rel) of a document, or (None, None) if it is not in a mod."""
        if not uri.startswith("file:"):
            return None, None
        path = to_fs_path(uri)
        root = runner.find_mod_root(os.path.dirname(path))
        if root is None:
            return None, None
        rel = os.path.relpath(path, root).replace("\\", "/")
        return root, rel

    async def mod(self, root):
        """The loaded Mod for \\p root, loading it the first time it is asked for."""
        if root in self.mods and self.mods[root].session is not None:
            return self.mods[root]
        if root not in self.loading:
            loop = asyncio.get_running_loop()
            self.loading[root] = loop.run_in_executor(self.executor, Session, root)
        session = await self.loading[root]
        if root not in self.mods:
            self.mods[root] = Mod(root, session)
            self.schedule_run(self.mods[root], delay=0)
        return self.mods[root]

    # --- checking ----------------------------------------------------------------------

    def schedule_check(self, uri, delay):
        pending = self.timers.pop(uri, None)
        if pending is not None:
            pending.cancel()
        self.timers[uri] = asyncio.ensure_future(self._check_later(uri, delay))

    async def _check_later(self, uri, delay):
        try:
            if delay:
                await asyncio.sleep(delay)
            await self.check(uri)
        except asyncio.CancelledError:
            pass
        except Exception as error:      # a failed check must not take the server down
            self.window_log_message(T.LogMessageParams(
                T.MessageType.Error, "BICE Validator: checking %s failed: %r" % (uri, error)))

    async def check(self, uri):
        root, rel = self.locate(uri)
        if root is None:
            return
        mod = await self.mod(root)
        if not mod.session.is_script(rel):
            return
        document = self.workspace.get_text_document(uri)
        text = document.source
        loop = asyncio.get_running_loop()
        found = await loop.run_in_executor(self.executor, mod.session.check_text, rel, text)
        if (root, rel) in self.open:
            self.live[(root, rel)] = found
            self.publish(mod, rel)

    def schedule_run(self, mod, delay=RUN_DELAY):
        """A background run over the whole mod, unless one is already on its way."""
        if not self.settings.background_modes():
            return
        if mod.run_task is not None and not mod.run_task.done():
            mod.run_again = True
            return
        mod.run_task = asyncio.ensure_future(self._run_later(mod, delay))

    async def _run_later(self, mod, delay):
        try:
            await asyncio.sleep(delay)
            while True:
                mod.run_again = False
                modes = self.settings.background_modes()
                if not modes:
                    return
                loop = asyncio.get_running_loop()
                # One process: the server runs hidden under VS Code, and worker processes
                # of a console program started without a console can each open a window.
                result = await loop.run_in_executor(
                    self.executor, lambda: runner.run(mod.root, modes, workers=1))
                grouped = {}
                for d in result.diagnostics:
                    grouped.setdefault(d.file, []).append(d)
                mod.background = grouped
                mod.baseline = None         # read again, in case it changed
                self.publish_mod(mod)
                if not mod.run_again:
                    return
        except asyncio.CancelledError:
            pass
        except Exception as error:
            self.window_log_message(T.LogMessageParams(
                T.MessageType.Error, "BICE Validator: the run over %s failed: %r"
                % (mod.root, error)))

    # --- publishing --------------------------------------------------------------------

    def findings(self, mod, rel):
        """What \\p rel shows now: live code findings if it is open, else the background
        run's; reference findings from the background run either way."""
        background = mod.background.get(rel, [])
        if (mod.root, rel) in self.open:
            found = list(self.live.get((mod.root, rel), []))
            found += [d for d in background if rules.RULES[d.rule].mode == rules.REFERENCES]
        elif self.settings.scope == "workspace":
            found = list(background)
        else:
            found = []
        found = [d for d in found if self.settings.shows(d)]
        if self.settings.hide_known_noise and found:
            baseline = self.baseline(mod)
            if baseline is not None:
                known = baseline.known(found)
                found = [d for i, d in enumerate(found) if i not in known]
        return found

    def baseline(self, mod):
        if mod.baseline is None:
            path = os.path.join(mod.root, TOOL_IN_MOD, "baseline.json")
            mod.baseline = Baseline(path) if os.path.exists(path) else False
        return mod.baseline or None

    def uri_for(self, mod, rel):
        return self.open.get((mod.root, rel)) or from_fs_path(os.path.join(mod.root, rel))

    def lines_for(self, mod, rel):
        uri = self.open.get((mod.root, rel))
        if uri is not None:
            return self.workspace.get_text_document(uri).lines
        try:
            return lexer.read(mod.root, rel).lines
        except OSError:
            return []

    def publish(self, mod, rel):
        found = self.findings(mod, rel)
        lines = self.lines_for(mod, rel) if found else []
        items = [to_lsp(d, lines, mod) for d in found]
        self.text_document_publish_diagnostics(T.PublishDiagnosticsParams(
            uri=self.uri_for(mod, rel), diagnostics=items))
        if items:
            mod.published.add(rel)
        else:
            mod.published.discard(rel)

    def publish_mod(self, mod):
        """Everything of \\p mod that shows findings, or did until now."""
        wanted = {rel for (root, rel) in self.open if root == mod.root}
        if self.settings.scope == "workspace":
            wanted |= set(mod.background)
        for rel in sorted(wanted | set(mod.published)):
            self.publish(mod, rel)

    def publish_all(self):
        for mod in self.mods.values():
            self.publish_mod(mod)

    async def refresh_settings(self):
        try:
            values = await self.workspace_configuration_async(T.ConfigurationParams(
                items=[T.ConfigurationItem(section=SECTION)]))
            data = values[0] if values else None
        except Exception:
            data = None
        self.settings = Settings.from_client(data)


def _end_col(line, start):
    """Where the token starting at \\p start (0-based) on \\p line ends."""
    if start >= len(line):
        return len(line)
    c = line[start]
    if c == '"':
        close = line.find('"', start + 1)
        return close + 1 if close >= 0 else len(line)
    if c in "{}=<>":
        return start + 1
    end = start
    while end < len(line) and not line[end].isspace() and line[end] not in '{}=<>#"':
        end += 1
    return max(end, start + 1)


def _range(lines, line, col):
    row = max(0, line - 1)
    start = max(0, col - 1)
    text = lines[row].rstrip("\r\n") if row < len(lines) else ""
    return T.Range(T.Position(row, start), T.Position(row, _end_col(text, start)))


def to_lsp(d, lines, mod):
    """One finding as VS Code shows it: the message, then the hint on a line of its own."""
    message = d.message.replace("`", "")
    if d.hint:
        message += "\n" + d.hint.replace("`", "")
    related = []
    for r in d.related:
        related.append(T.DiagnosticRelatedInformation(
            location=T.Location(uri=from_fs_path(os.path.join(mod.root, r.file)),
                                range=T.Range(T.Position(r.line - 1, max(0, r.col - 1)),
                                              T.Position(r.line - 1, max(0, r.col - 1)))),
            message=r.label))
    return T.Diagnostic(range=_range(lines, d.line, d.col), message=message,
                        severity=_SEVERITY[d.severity], code=d.rule, source=SOURCE,
                        related_information=related or None)


server = BiceServer()


@server.feature(T.INITIALIZED)
async def initialized(ls: BiceServer, params: T.InitializedParams):
    await ls.refresh_settings()


@server.feature(T.WORKSPACE_DID_CHANGE_CONFIGURATION)
async def configuration_changed(ls: BiceServer, params: T.DidChangeConfigurationParams):
    await ls.refresh_settings()
    ls.publish_all()
    for mod in ls.mods.values():
        ls.schedule_run(mod, delay=0)


@server.feature(T.TEXT_DOCUMENT_DID_OPEN)
async def did_open(ls: BiceServer, params: T.DidOpenTextDocumentParams):
    uri = params.text_document.uri
    root, rel = ls.locate(uri)
    if root is None:
        return
    ls.open[(root, rel)] = uri
    ls.schedule_check(uri, 0)


@server.feature(T.TEXT_DOCUMENT_DID_CHANGE)
async def did_change(ls: BiceServer, params: T.DidChangeTextDocumentParams):
    ls.schedule_check(params.text_document.uri, TYPING_DELAY)


@server.feature(T.TEXT_DOCUMENT_DID_SAVE)
async def did_save(ls: BiceServer, params: T.DidSaveTextDocumentParams):
    uri = params.text_document.uri
    root, rel = ls.locate(uri)
    if root is None:
        return
    mod = await ls.mod(root)
    if mod.session.declares(rel):
        # A technology, a unit or a tag may have appeared or gone: read the declarations
        # again, then check every open file against them.
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(ls.executor, mod.session.reload)
        for (r, _), open_uri in list(ls.open.items()):
            if r == root:
                ls.schedule_check(open_uri, 0)
    else:
        ls.schedule_check(uri, 0)
    ls.schedule_run(mod)


@server.feature(T.TEXT_DOCUMENT_DID_CLOSE)
async def did_close(ls: BiceServer, params: T.DidCloseTextDocumentParams):
    uri = params.text_document.uri
    pending = ls.timers.pop(uri, None)
    if pending is not None:
        pending.cancel()
    root, rel = ls.locate(uri)
    if root is None:
        return
    ls.open.pop((root, rel), None)
    ls.live.pop((root, rel), None)
    if root in ls.mods:
        ls.publish(ls.mods[root], rel)


def main():
    server.start_io()
