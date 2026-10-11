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
}

module.exports = { run };
