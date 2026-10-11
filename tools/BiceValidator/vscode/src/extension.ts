// The BlackICE Script extension: starts the BICE Validator language server and hands it
// the script files. Everything it knows about the language is in the server; this file
// only finds the server and connects it.

import * as fs from "fs";
import * as path from "path";
import { commands, ExtensionContext, window, workspace } from "vscode";
import { LanguageClient, LanguageClientOptions, ServerOptions } from "vscode-languageclient/node";

let client: LanguageClient | undefined;

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
        synchronize: { configurationSection: "blackice.validator" },
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

export async function activate(context: ExtensionContext): Promise<void> {
    context.subscriptions.push(commands.registerCommand("blackice.validator.restart", async () => {
        await stop();
        await start(context);
    }));
    await start(context);
}

export function deactivate(): Thenable<void> | undefined {
    return stop();
}
