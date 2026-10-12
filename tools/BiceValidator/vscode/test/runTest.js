// Starts a fresh copy of VS Code with this extension loaded and a small mod as the
// workspace, and runs suite/index.js inside it. `npm test`; build.py runs it.
//
// The server is the bundled server/bicevalidator-lsp.exe, unless BLACKICE_SERVER_COMMAND
// holds a JSON array to run instead, e.g. ["python", ".../BiceValidatorLsp.py"].

const fs = require("fs");
const os = require("os");
const path = require("path");
const { runTests } = require("@vscode/test-electron");

function writeMod() {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "blackice-script-test-"));
    const write = (rel, bytes) => {
        const file = path.join(root, rel);
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, bytes);
    };
    write("common/countries.txt", 'GER = "countries/Germany.txt"\r\n');
    write("units/infantry_brigade.txt", "infantry_brigade = { }\r\n");
    fs.mkdirSync(path.join(root, "decisions"));
    // Windows-1252 on disk: 0xF6 is the "o" of Goring with its umlaut.
    write("events/test.txt", Buffer.concat([
        Buffer.from('country_event = {\r\n\tid = 1\r\n\tis_triggered_only = yes\r\n\ttitle = "G'),
        Buffer.from([0xF6]),
        Buffer.from('ring"\r\n\toption = {\r\n\t\tname = A\r\n\t\tinfanty_brigade = 1\r\n\t}\r\n}\r\n'),
    ]));
    write("events/other.txt", 'country_event = {\r\n\tid = 2\r\n\tis_triggered_only = yes\r\n' +
        '\ttitle = "Second"\r\n\toption = {\r\n\t\tname = B\r\n\t}\r\n}\r\n');
    const command = process.env.BLACKICE_SERVER_COMMAND;
    if (command) {
        write(".vscode/settings.json", JSON.stringify(
            { "blackice.validator.serverCommand": JSON.parse(command) }, null, 2));
    }
    return root;
}

async function main() {
    // Run from inside VS Code - its terminal, or a tool it hosts - the running editor's
    // variables are inherited: ELECTRON_RUN_AS_NODE makes the test copy start as plain
    // Node, and the VSCODE_* ones point it at the running editor's caches and sockets.
    for (const name of Object.keys(process.env)) {
        if (name.startsWith("VSCODE_") || name.startsWith("ELECTRON_")) {
            delete process.env[name];
        }
    }
    const mod = writeMod();
    try {
        await runTests({
            extensionDevelopmentPath: path.resolve(__dirname, ".."),
            extensionTestsPath: path.resolve(__dirname, "suite", "index.js"),
            launchArgs: [mod, "--disable-extensions", "--disable-workspace-trust"],
        });
    } catch (error) {
        console.error("The tests failed:", error);
        process.exitCode = 1;
    } finally {
        fs.rmSync(mod, { recursive: true, force: true });
    }
}

main();
