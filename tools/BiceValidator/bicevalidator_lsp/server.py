"""The language server: findings in the editor while typing, and after every save.

Two sources feed what a file shows:

- **Live**: the code-mode checks of the text in the editor, run a moment after typing
  stops. Only for open files, and from the unsaved text.
- **Background**: a run over the whole mod after each save (and at start-up) - the
  reference checks, which need every file, and in "workspace" scope the code checks of
  every file too. Read from disk, so it describes what was last saved.

For an open file, live findings replace the background run's code findings; reference
findings always come from the background run.

Everything else - hover, go to definition, references, the outline, completion, the
titles after fired events - is answered by the library's Navigator (bicevalidator/
navigate.py), from the session's index; this file only turns its answers into the
protocol's types.
"""

import asyncio
import os
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field

from lsprotocol import types as T
from pygls.lsp.server import LanguageServer
from pygls.uris import from_fs_path, to_fs_path

from bicevalidator import __version__, lexer, navigate as N, rules, runner
from bicevalidator.baseline import Baseline
from bicevalidator.config import TOOL_IN_MOD
from bicevalidator.session import Session

SECTION = "blackice.validator"
SOURCE = "BICE Validator"
NEXT_EVENT_ID = "blackice.nextEventId"
TYPING_DELAY = 0.3      # seconds of quiet before a changed file is checked
RUN_DELAY = 1.0         # seconds after a save before the background run starts
WATCH_DELAY = 1.0       # seconds to gather files changed outside the editor, as a git pull

_SEVERITY = {rules.ERROR: T.DiagnosticSeverity.Error,
             rules.WARNING: T.DiagnosticSeverity.Warning,
             rules.INFO: T.DiagnosticSeverity.Information}

_COMPLETION_KINDS = {
    "condition": T.CompletionItemKind.Function, "combat condition": T.CompletionItemKind.Function,
    "effect": T.CompletionItemKind.Method, "scope": T.CompletionItemKind.Module,
    "keyword": T.CompletionItemKind.Keyword, "snippet": T.CompletionItemKind.Snippet,
    "name": T.CompletionItemKind.Reference, "value": T.CompletionItemKind.Value,
    "event": T.CompletionItemKind.Event, "file": T.CompletionItemKind.File,
    "event header key": T.CompletionItemKind.Property,
    "option key": T.CompletionItemKind.Property,
}
_SYMBOL_KINDS = {"event": T.SymbolKind.Event, "option": T.SymbolKind.EnumMember,
                 "decision": T.SymbolKind.Function, "category": T.SymbolKind.Namespace,
                 "block": T.SymbolKind.Object, "field": T.SymbolKind.Field}


@dataclass
class Settings:
    """The extension's settings, `blackice.validator.*` in VS Code."""
    enable: bool = True
    disabled_rules: set = field(default_factory=set)
    minimum_severity: str = rules.INFO
    references: str = "onSave"          # "onSave" or "off"
    scope: str = "openFiles"            # "openFiles" or "workspace"
    hide_known_noise: bool = False
    event_titles: bool = True
    model_technologies: bool = True     # name the technology after each level of a model
    game_folder: str = ""               # empty: found beside the mod (pictures.find_game)

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
        settings.event_titles = bool(data.get("eventTitles", True))
        settings.model_technologies = bool(data.get("modelTechnologies", True))
        settings.game_folder = str(data.get("gameFolder") or "").strip()
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
        self.parses = {}        # uri -> (version, parse) of the text last read
        self.changed = {}       # root -> rels changed outside the editor, not yet read
        self.watch_task = None
        # What the editor waits for - a check while typing, a list of references - never
        # queues behind a run over the whole mod, which has a thread of its own.
        self.executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="bicevalidator")
        self.background = ThreadPoolExecutor(max_workers=1, thread_name_prefix="bicevalidator-run")

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
        loading = self.loading.get(root)
        if loading is None or (loading.done() and (loading.cancelled()
                                                   or loading.exception() is not None)):
            loop = asyncio.get_running_loop()
            loading = self.loading[root] = loop.run_in_executor(self.executor, Session, root)
        # Every request waits on this one load. VS Code cancels a request it no longer
        # needs, and cancelling a task cancels what it awaits - so without the shield the
        # first cancelled request would cancel the load for everyone, for good.
        session = await asyncio.shield(loading)
        if root not in self.mods:
            session.pictures.set_game(self.settings.game_folder)
            self.mods[root] = Mod(root, session)
            asyncio.get_running_loop().run_in_executor(self.background, session.index.warm)
            self.schedule_run(self.mods[root], delay=0)
            # The editor asked for the colouring as the file opened, before the mod was read,
            # and does not ask again on its own; tell it to.
            self.refresh_semantic_tokens()
        return self.mods[root]

    def refresh_semantic_tokens(self):
        workspace = self.client_capabilities.workspace
        tokens = workspace.semantic_tokens if workspace is not None else None
        if tokens is not None and tokens.refresh_support:
            self.workspace_semantic_tokens_refresh(None)

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
        text, version = document.source, document.version
        loop = asyncio.get_running_loop()
        found, parsed = await loop.run_in_executor(self.executor, mod.session.analyse,
                                                   rel, text)
        if (root, rel) in self.open:
            self.parses[uri] = (version, parsed)
            self.live[(root, rel)] = found
            self.publish(mod, rel)

    # --- questions about an open file --------------------------------------------------

    async def at(self, uri):
        """(navigator, rel, parse of the current text) for \\p uri, or None outside a mod."""
        root, rel = self.locate(uri)
        if root is None:
            return None
        mod = await self.mod(root)
        document = self.workspace.get_text_document(uri)
        cached = self.parses.get(uri)
        if cached is None or cached[0] != document.version:
            cached = (document.version, Session.parse(document.source))
            self.parses[uri] = cached
        return mod.session.navigator, rel, cached[1]

    def location(self, mod_root, place):
        path = place.file if os.path.isabs(place.file) else os.path.join(mod_root, place.file)
        start = T.Position(place.line - 1, max(0, place.col - 1))
        end = T.Position(place.line - 1, max(start.character, place.end - 1))
        return T.Location(uri=from_fs_path(path), range=T.Range(start, end))

    # --- files changed outside the editor ----------------------------------------------

    def files_changed(self, uris):
        for uri in uris:
            root, rel = self.locate(uri)
            if root is None or root not in self.mods or (root, rel) in self.open:
                # An open file's part comes from its text, and its save is handled
                # by did_save.
                continue
            self.changed.setdefault(root, set()).add(rel)
        if self.changed and (self.watch_task is None or self.watch_task.done()):
            self.watch_task = asyncio.ensure_future(self._read_changed())

    async def _read_changed(self):
        try:
            await asyncio.sleep(WATCH_DELAY)
            loop = asyncio.get_running_loop()
            while self.changed:
                root, rels = self.changed.popitem()
                mod = self.mods[root]
                declared = await loop.run_in_executor(self.executor, mod.session.files_changed,
                                                      sorted(rels))
                if declared:
                    for (r, _), open_uri in list(self.open.items()):
                        if r == root:
                            self.schedule_check(open_uri, 0)
                self.schedule_run(mod)
        except Exception as error:
            self.window_log_message(T.LogMessageParams(
                T.MessageType.Error, "BICE Validator: reading changed files failed: %r"
                % error))

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
                game = self.settings.game_folder or None
                result = await loop.run_in_executor(
                    self.background, lambda: runner.run(mod.root, modes, workers=1, game=game))
                for note in result.notes:
                    self.window_log_message(T.LogMessageParams(
                        T.MessageType.Warning, "BICE Validator: " + note))
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
        for mod in self.mods.values():
            mod.session.pictures.set_game(self.settings.game_folder)


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
    titles = (ls.settings.event_titles, ls.settings.model_technologies)
    await ls.refresh_settings()
    ls.publish_all()
    for mod in ls.mods.values():
        ls.schedule_run(mod, delay=0)
    capabilities = ls.client_capabilities.workspace
    if titles != (ls.settings.event_titles, ls.settings.model_technologies) \
            and capabilities is not None \
            and capabilities.inlay_hint is not None and capabilities.inlay_hint.refresh_support:
        ls.workspace_inlay_hint_refresh(None)


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
    ls.parses.pop(uri, None)
    if root in ls.mods:
        mod = ls.mods[root]
        ls.publish(mod, rel)
        # The index held the unsaved text; what counts now is the file on disk.
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(ls.executor, mod.session.index.reload_file, rel)


@server.feature(T.WORKSPACE_DID_CHANGE_WATCHED_FILES)
async def watched_files_changed(ls: BiceServer, params: T.DidChangeWatchedFilesParams):
    ls.files_changed([change.uri for change in params.changes])


def _range_of(token):
    width = len(token.text) + (2 if token.kind == lexer.STRING else 0)
    return T.Range(T.Position(token.line - 1, token.col - 1),
                   T.Position(token.line - 1, token.col - 1 + width))


async def _target(ls, params):
    found = await ls.at(params.text_document.uri)
    if found is None:
        return None, None
    navigator, rel, parsed = found
    position = params.position
    return navigator, navigator.target(rel, parsed, position.line + 1, position.character + 1)


@server.feature(T.TEXT_DOCUMENT_HOVER)
async def hover(ls: BiceServer, params: T.HoverParams):
    navigator, target = await _target(ls, params)
    if target is None:
        return None
    text = navigator.hover(target)
    if not text:
        return None
    return T.Hover(contents=T.MarkupContent(kind=T.MarkupKind.Markdown, value=text),
                   range=_range_of(target.token))


@server.feature(T.TEXT_DOCUMENT_DEFINITION)
async def definition(ls: BiceServer, params: T.DefinitionParams):
    navigator, target = await _target(ls, params)
    if target is None:
        return None
    root = navigator.session.root
    return [ls.location(root, place) for place in navigator.definitions(target)] or None


@server.feature(T.TEXT_DOCUMENT_REFERENCES)
async def references(ls: BiceServer, params: T.ReferenceParams):
    navigator, target = await _target(ls, params)
    if target is None:
        return None
    loop = asyncio.get_running_loop()
    # A flag's references search the Lua scripts and the histories the first time.
    places = await loop.run_in_executor(
        ls.executor, navigator.references, target, params.context.include_declaration)
    if places is None:
        return None
    return [ls.location(navigator.session.root, place) for place in places]


def _document_symbol(symbol):
    start = T.Position(symbol.line - 1, max(0, symbol.col - 1))
    end = T.Position(symbol.end_line - 1, max(0, symbol.end_col - 1))
    if (end.line, end.character) < (start.line, start.character):
        end = start
    return T.DocumentSymbol(name=symbol.name or "?", detail=symbol.detail or None,
                            kind=_SYMBOL_KINDS.get(symbol.kind, T.SymbolKind.Object),
                            range=T.Range(start, end), selection_range=T.Range(start, start),
                            children=[_document_symbol(c) for c in symbol.children] or None)


@server.feature(T.TEXT_DOCUMENT_DOCUMENT_SYMBOL)
async def document_symbols(ls: BiceServer, params: T.DocumentSymbolParams):
    found = await ls.at(params.text_document.uri)
    if found is None:
        return None
    navigator, rel, parsed = found
    return [_document_symbol(s) for s in navigator.outline(rel, parsed)]


@server.feature(T.WORKSPACE_SYMBOL)
async def workspace_symbols(ls: BiceServer, params: T.WorkspaceSymbolParams):
    out = []
    for mod in list(ls.mods.values()):
        for symbol in mod.session.navigator.symbols(params.query):
            place = N.Place(symbol.file, symbol.line, symbol.col, symbol.col)
            out.append(T.SymbolInformation(
                name=symbol.name, kind=_SYMBOL_KINDS.get(symbol.kind, T.SymbolKind.Object),
                location=ls.location(mod.root, place), container_name=symbol.file))
    return out


@server.feature(T.TEXT_DOCUMENT_INLAY_HINT)
async def inlay_hints(ls: BiceServer, params: T.InlayHintParams):
    settings = ls.settings
    if not (settings.event_titles or settings.model_technologies):
        return []
    found = await ls.at(params.text_document.uri)
    if found is None:
        return []
    navigator, rel, parsed = found
    first, last = params.range.start.line + 1, params.range.end.line + 1
    hints = []
    if settings.event_titles:
        hints += [T.InlayHint(position=T.Position(line - 1, col - 1), label=title,
                              padding_left=True)
                  for line, col, title in navigator.event_titles(parsed, first, last)]
    if settings.model_technologies:
        hints += [T.InlayHint(position=T.Position(line - 1, col - 1), label=tech,
                              padding_left=True, padding_right=True)
                  for line, col, tech in navigator.model_hints(parsed, first, last)]
    return hints


# Semantic colouring: one token type of the extension's own, which package.json maps to the
# scope the grammar gives an event's own keys, so a data file's keys look the same.
SEMANTIC_LEGEND = T.SemanticTokensLegend(token_types=["dataKey"], token_modifiers=[])


@server.feature(T.TEXT_DOCUMENT_SEMANTIC_TOKENS_FULL, SEMANTIC_LEGEND)
async def semantic_tokens(ls: BiceServer, params: T.SemanticTokensParams):
    found = await ls.at(params.text_document.uri)
    if found is None:
        return T.SemanticTokens(data=[])
    navigator, rel, parsed = found
    data = []
    previous_line, previous_col = 0, 0
    for line, col, length in navigator.data_keys(rel, parsed):
        line, col = line - 1, col - 1
        delta_col = col - previous_col if line == previous_line else col
        data += [line - previous_line, delta_col, length, 0, 0]
        previous_line, previous_col = line, col
    return T.SemanticTokens(data=data)


@server.feature(T.TEXT_DOCUMENT_FOLDING_RANGE)
async def folding_ranges(ls: BiceServer, params: T.FoldingRangeParams):
    found = await ls.at(params.text_document.uri)
    if found is None:
        return None
    navigator, rel, parsed = found
    lines = ls.workspace.get_text_document(params.text_document.uri).lines
    return [T.FoldingRange(start_line=first - 1, end_line=last - 1,
                           kind=T.FoldingRangeKind.Comment if comment else None)
            for first, last, comment in navigator.folds(parsed, lines)]


@server.feature(T.TEXT_DOCUMENT_CODE_ACTION,
                T.CodeActionOptions(code_action_kinds=[T.CodeActionKind.QuickFix,
                                                       T.CodeActionKind.RefactorRewrite]))
async def code_actions(ls: BiceServer, params: T.CodeActionParams):
    found = await ls.at(params.text_document.uri)
    if found is None:
        return None
    navigator, rel, parsed = found
    lines = ls.workspace.get_text_document(params.text_document.uri).lines
    actions = []
    start = params.range.start
    model = navigator.model_at(parsed, start.line + 1, start.character + 1)
    if model is not None and model.open_tok is not None and model.close_tok is not None:
        key_line = lines[model.line - 1] if model.line - 1 < len(lines) else ""
        indent = key_line[:len(key_line) - len(key_line.lstrip())]
        span = T.Range(T.Position(model.open_tok.line - 1, model.open_tok.col - 1),
                       T.Position(model.close_tok.line - 1, model.close_tok.col))
        actions.append(T.CodeAction(
            title="Write the model one level a line, naming each technology",
            kind=T.CodeActionKind.RefactorRewrite,
            edit=T.WorkspaceEdit(changes={params.text_document.uri: [T.TextEdit(
                range=span, new_text=navigator.annotated_model(model, indent))]})))
    for diagnostic in params.context.diagnostics:
        if diagnostic.source != SOURCE:
            continue
        span = diagnostic.range
        line = lines[span.start.line] if span.start.line < len(lines) else ""
        word = line[span.start.character:span.end.character]
        edit = None
        if diagnostic.code == "BV113" and "missing its =" in diagnostic.message:
            edit = (T.TextEdit(range=T.Range(span.end, span.end), new_text=" ="),
                    "Insert the missing `=`")
        else:
            better = navigator.replacement(diagnostic.code, word) if word else None
            if better:
                edit = (T.TextEdit(range=span, new_text=better), "Change to `%s`" % better)
        if edit is None:
            continue
        actions.append(T.CodeAction(
            title=edit[1], kind=T.CodeActionKind.QuickFix, diagnostics=[diagnostic],
            is_preferred=True,
            edit=T.WorkspaceEdit(changes={params.text_document.uri: [edit[0]]})))
    return actions or None


@server.feature(T.TEXT_DOCUMENT_COMPLETION,
                T.CompletionOptions(trigger_characters=["="], resolve_provider=True))
async def completion(ls: BiceServer, params: T.CompletionParams):
    found = await ls.at(params.text_document.uri)
    if found is None:
        return None
    navigator, rel, parsed = found
    position = params.position
    items, incomplete = navigator.completions(rel, parsed, position.line + 1,
                                              position.character + 1)
    out = []
    for item in items:
        out.append(T.CompletionItem(
            label=item.label, kind=_COMPLETION_KINDS.get(item.kind, T.CompletionItemKind.Text),
            detail=item.detail or None,
            documentation=T.MarkupContent(kind=T.MarkupKind.Markdown, value=item.documentation)
            if item.documentation else None,
            insert_text=item.insert or None,
            insert_text_format=T.InsertTextFormat.Snippet if item.insert else None,
            filter_text=item.filter or None,
            # A picture's preview is made only for the item VS Code shows the details of.
            data={"root": navigator.session.root, "picture": item.picture}
            if item.picture else None))
    return T.CompletionList(is_incomplete=incomplete, items=out)


@server.feature(T.COMPLETION_ITEM_RESOLVE)
async def completion_resolve(ls: BiceServer, item: T.CompletionItem):
    data = item.data if isinstance(item.data, dict) else {}
    mod = ls.mods.get(data.get("root"))
    if mod is not None and data.get("picture"):
        loop = asyncio.get_running_loop()
        text = await loop.run_in_executor(ls.executor, mod.session.navigator.picture_preview,
                                          data["picture"])
        item.documentation = T.MarkupContent(kind=T.MarkupKind.Markdown, value=text)
    return item


@server.command(NEXT_EVENT_ID)
async def next_event_id(ls: BiceServer, uri: str, line: int):
    """The id to give a new event written at \\p line (0-based) of \\p uri."""
    root, rel = ls.locate(uri)
    if root is None:
        return None
    mod = await ls.mod(root)
    return mod.session.index.next_event_id(rel, line + 1)


def main():
    server.start_io()
