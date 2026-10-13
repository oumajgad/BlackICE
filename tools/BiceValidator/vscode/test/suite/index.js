// Runs inside the copy of VS Code that runTest.js starts, with the small mod open.

const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vscode = require("vscode");

const SOURCE = "BICE Validator";

function ours(uri) {
    return vscode.languages.getDiagnostics(uri).filter((d) => d.source === SOURCE);
}

async function waitFor(what, read, ready, timeout = 60000) {
    const deadline = Date.now() + timeout;
    for (;;) {
        const value = read();
        if (ready(value)) {
            return value;
        }
        if (Date.now() > deadline) {
            throw new Error("Timed out waiting for " + what + "; last: " + JSON.stringify(value));
        }
        await new Promise((resolve) => setTimeout(resolve, 200));
    }
}

const codes = (diagnostics) => diagnostics.map((d) => String(d.code));

async function run() {
    const root = vscode.workspace.workspaceFolders[0].uri.fsPath;
    const file = path.join(root, "events", "test.txt");
    const uri = vscode.Uri.file(file);
    const document = await vscode.workspace.openTextDocument(uri);
    const editor = await vscode.window.showTextDocument(document);

    // The language and the encoding the extension sets for it.
    assert.strictEqual(document.languageId, "blackice-script");
    assert.ok(document.getText().includes("Göring"),
        "the file was read as Windows-1252: " + JSON.stringify(document.lineAt(3).text));
    console.log("  ok  language and Windows-1252");

    // A finding while typing, at the right place, with its hint.
    const found = await waitFor("BV101", () => ours(uri), (ds) => codes(ds).includes("BV101"));
    const unknown = found.find((d) => String(d.code) === "BV101");
    const typoLine = 6;     // 0-based: the seventh line of the test file
    assert.strictEqual(unknown.range.start.line, typoLine);
    assert.strictEqual(document.getText(unknown.range), "infanty_brigade");
    assert.ok(unknown.message.includes("Did you mean infantry_brigade?"), unknown.message);
    assert.strictEqual(unknown.severity, vscode.DiagnosticSeverity.Error);
    console.log("  ok  finding while typing");

    // Fixing the typo clears it, before any save.
    await editor.edit((edit) => edit.replace(unknown.range, "infantry_brigade"));
    await waitFor("BV101 to go", () => ours(uri), (ds) => !codes(ds).includes("BV101"));
    console.log("  ok  the finding goes when the text is fixed");

    // Saving keeps Windows-1252 on disk: the umlaut is one byte, not two.
    await document.save();
    const bytes = fs.readFileSync(file);
    assert.ok(bytes.includes(Buffer.from([0x47, 0xF6, 0x72])), "saved as Windows-1252");
    assert.ok(!bytes.includes(Buffer.from([0xC3, 0xB6])), "not saved as UTF-8");
    console.log("  ok  saved as Windows-1252");

    // A setting hides a rule.
    await editor.edit((edit) => edit.replace(
        document.lineAt(typoLine).range, "\t\tinfanty_brigade = 1"));
    await waitFor("BV101 again", () => ours(uri), (ds) => codes(ds).includes("BV101"));
    const settings = vscode.workspace.getConfiguration("blackice.validator");
    await settings.update("disabledRules", ["BV101"], vscode.ConfigurationTarget.Workspace);
    await waitFor("BV101 hidden by the setting", () => ours(uri),
        (ds) => !codes(ds).includes("BV101"));
    await settings.update("disabledRules", undefined, vscode.ConfigurationTarget.Workspace);
    console.log("  ok  disabledRules hides a rule");

    // Colouring: the grammar is registered for the language.
    const extension = vscode.extensions.getExtension("blackice.blackice-script");
    assert.ok(extension && extension.isActive, "the extension is active");
    console.log("  ok  extension active");

    // A quick fix for the typo.
    const shown = await waitFor("BV101 back after the setting", () => ours(uri),
        (ds) => codes(ds).includes("BV101"));
    const typo = shown.find((d) => String(d.code) === "BV101");
    const actions = await vscode.commands.executeCommand(
        "vscode.executeCodeActionProvider", uri, typo.range, vscode.CodeActionKind.QuickFix.value);
    assert.ok(actions.some((a) => a.title === "Change to `infantry_brigade`"),
        JSON.stringify(actions.map((a) => a.title)));
    console.log("  ok  quick fix");

    // Hover and go to definition on an event fired from another file.
    const fireLine = typoLine + 1;
    await editor.edit((edit) => edit.insert(new vscode.Position(fireLine, 0), "\t\tcountry_event = 2\r\n"));
    const onId = new vscode.Position(fireLine, document.lineAt(fireLine).text.indexOf("2"));
    const hovers = await vscode.commands.executeCommand("vscode.executeHoverProvider", uri, onId);
    const hoverText = hovers.map((h) => h.contents.map((c) => c.value || c).join("")).join("");
    assert.ok(hoverText.includes("Second"), hoverText);
    const targets = await vscode.commands.executeCommand("vscode.executeDefinitionProvider", uri, onId);
    const target = targets[0].uri || targets[0].targetUri;
    assert.ok(target.fsPath.endsWith("other.txt"), target.fsPath);
    console.log("  ok  hover and go to definition");

    // The chain of events in the Call Hierarchy view: event 2 is fired by event 1, here -
    // once the unsaved line has reached the index, after the check's pause for typing.
    const [chainItem] = await vscode.commands.executeCommand("vscode.prepareCallHierarchy", uri, onId);
    assert.strictEqual(chainItem.name, "2 Second");
    let callers = [];
    const chainDeadline = Date.now() + 30000;
    while (callers.length === 0 && Date.now() < chainDeadline) {
        await new Promise((resolve) => setTimeout(resolve, 300));
        callers = await vscode.commands.executeCommand("vscode.provideIncomingCalls", chainItem);
    }
    assert.deepStrictEqual(callers.map((c) => c.from.name), ["1 Göring"]);
    assert.strictEqual(callers[0].fromRanges[0].start.line, fireLine);
    console.log("  ok  chain of events");

    // An event's picture is previewed as an image the hover can show.
    const other = await vscode.workspace.openTextDocument(vscode.Uri.file(path.join(root, "events", "other.txt")));
    const pictureLine = 4;
    const onPicture = new vscode.Position(pictureLine, other.lineAt(pictureLine).text.indexOf("Tiny") + 1);
    const pictureHovers = await vscode.commands.executeCommand("vscode.executeHoverProvider", other.uri, onPicture);
    const pictureText = pictureHovers.map((h) => h.contents.map((c) => c.value || c).join("")).join("");
    // A link to a PNG on disk: VS Code cuts a hover at 100,000 characters, which a
    // picture in base64 passes, and then shows the markdown as text.
    assert.ok(/!\[Tiny\]\(file:\/\/\/[^)]+\.png\)/.test(pictureText) && pictureText.includes("2 × 1"),
        pictureText.slice(0, 300));
    console.log("  ok  event picture preview");

    // A model's levels name the technologies they set: as hints, on hover, and rewritten.
    const queue = await vscode.workspace.openTextDocument(vscode.Uri.file(path.join(root, "history", "units", "queue.txt")));
    const modelLine = 2;
    const two = new vscode.Position(modelLine, queue.lineAt(modelLine).text.indexOf("2 }"));
    const levelHovers = await vscode.commands.executeCommand("vscode.executeHoverProvider", queue.uri, two);
    const levelText = levelHovers.map((h) => h.contents.map((c) => c.value || c).join("")).join("");
    assert.ok(levelText.includes("Level 2 of `late_tech`"), levelText);
    const hints = await vscode.commands.executeCommand("vscode.executeInlayHintProvider", queue.uri,
        new vscode.Range(0, 0, queue.lineCount, 0));
    const labels = hints.map((h) => (typeof h.label === "string" ? h.label : h.label.map((p) => p.value).join("")));
    assert.deepStrictEqual(labels, ["early_tech", "late_tech"]);
    const rewrites = await vscode.commands.executeCommand("vscode.executeCodeActionProvider", queue.uri,
        new vscode.Range(two, two), vscode.CodeActionKind.RefactorRewrite.value);
    assert.ok(rewrites.some((a) => a.title.startsWith("Write the model one level a line")),
        JSON.stringify(rewrites.map((a) => a.title)));
    console.log("  ok  model levels name their technologies");

    // The keys the loader takes are coloured as keywords: military_construction and model,
    // and not the unit type used as a key.
    const legend = await vscode.commands.executeCommand("vscode.provideDocumentSemanticTokensLegend", queue.uri);
    const tokens = await vscode.commands.executeCommand("vscode.provideDocumentSemanticTokens", queue.uri);
    assert.deepStrictEqual(legend.tokenTypes, ["dataKey"]);
    assert.strictEqual(tokens.data.length, 10, JSON.stringify(Array.from(tokens.data)));
    console.log("  ok  data file keys coloured");

    // The outline names events by id and title.
    const symbols = await vscode.commands.executeCommand("vscode.executeDocumentSymbolProvider", uri);
    assert.deepStrictEqual(symbols.map((s) => s.name), ["1 Göring"]);
    console.log("  ok  outline");

    // The next free id goes in at the cursor.
    const idLine = document.lineCount - 1;
    editor.selection = new vscode.Selection(idLine, 0, idLine, 0);
    await vscode.commands.executeCommand("blackice.insertNextEventId");
    assert.strictEqual(document.lineAt(idLine).text, "3");
    console.log("  ok  next free event id");

    // A file written outside the editor is found without reopening anything.
    fs.writeFileSync(path.join(root, "events", "third.txt"),
        'country_event = {\r\n\tid = 3\r\n\tis_triggered_only = yes\r\n\ttitle = "Third"\r\n' +
        '\toption = {\r\n\t\tname = C\r\n\t}\r\n}\r\n');
    let third = [];
    const deadline = Date.now() + 30000;
    while (third.length === 0 && Date.now() < deadline) {
        await new Promise((resolve) => setTimeout(resolve, 300));
        third = await vscode.commands.executeCommand("vscode.executeWorkspaceSymbolProvider", "Third");
    }
    assert.deepStrictEqual(third.map((s) => s.name), ["3 Third"]);
    console.log("  ok  files changed outside the editor");
}

module.exports = { run };
