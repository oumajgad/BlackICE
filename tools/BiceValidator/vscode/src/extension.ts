// The BlackICE Script extension: starts the BICE Validator language server and hands it
// the script files. Everything it knows about the language is in the server; this file
// only finds the server and connects it.

import * as fs from "fs";
import * as path from "path";
import { commands, ExtensionContext, window, workspace } from "vscode";
import { ExecuteCommandRequest, LanguageClient, LanguageClientOptions, ServerOptions } from "vscode-languageclient/node";

let client: LanguageClient | undefined;

// The server's own command; the client registers it under this name by itself, so the
// one the palette shows needs a name of its own.
const NEXT_EVENT_ID = "blackice.nextEventId";

function serverOptions(context: ExtensionContext): ServerOptions | undefined {
    const configured = workspace.getConfiguration("blackice.validator").get<string[]>("serverCommand") ?? [];
    if (configured.length > 0) {
        return { command: configured[0], args: configured.slice(1) };
    }
    const bundled = context.asAbsolutePath(path.join("server", "bicevalidator-lsp.exe"));
    if (!fs.existsSync(bundled)) {
        window.showErrorMessage(`BlackICE Script: the language server is missing (${bundled}). Reinstall the extension.`);
        return undefined;
    }
    return { command: bundled, args: [] };
}

async function start(context: ExtensionContext): Promise<void> {
    const server = serverOptions(context);
    if (server === undefined) {
        return;
    }
    const clientOptions: LanguageClientOptions = {
        documentSelector: [{ scheme: "file", language: "blackice-script" }],
        synchronize: {
            configurationSection: "blackice.validator",
            // Files changed outside the editor - a git pull, a localisation table - so the
            // server's index and declarations follow them.
            fileEvents: workspace.createFileSystemWatcher("**/*.{txt,csv,lua}"),
        },
    };
    client = new LanguageClient("blackice-script", "BlackICE Script", server, clientOptions);
    await client.start();
}

async function stop(): Promise<void> {
    if (client !== undefined) {
        const running = client;
        client = undefined;
        await running.stop();
    }
}

async function insertNextEventId(): Promise<void> {
    const editor = window.activeTextEditor;
    if (editor === undefined || client === undefined) {
        return;
    }
    const id = await client.sendRequest(ExecuteCommandRequest.type, {
        command: NEXT_EVENT_ID,
        arguments: [editor.document.uri.toString(), editor.selection.active.line],
    });
    if (typeof id !== "number") {
        window.showWarningMessage("BlackICE Script: this file is not part of a mod.");
        return;
    }
    await editor.edit((edit) => {
        for (const selection of editor.selections) {
            edit.replace(selection, String(id));
        }
    });
}

export async function activate(context: ExtensionContext): Promise<void> {
    context.subscriptions.push(commands.registerCommand("blackice.validator.restart", async () => {
        await stop();
        await start(context);
    }));
    context.subscriptions.push(commands.registerCommand("blackice.insertNextEventId", insertNextEventId));
    await start(context);
}

export function deactivate(): Thenable<void> | undefined {
    return stop();
}
