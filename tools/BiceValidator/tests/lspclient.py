"""A small Language Server Protocol client, enough to drive the server the way VS Code does."""

import json
import queue
import subprocess
import threading
import time


class LspClient:
    def __init__(self, command, settings=None, cwd=None):
        self.settings = settings or {}
        self.process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, cwd=cwd)
        self.messages = queue.Queue()
        self.diagnostics = {}       # uri -> latest list
        self.updates = queue.Queue()
        self.next_id = 1
        self.responses = {}
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()
        threading.Thread(target=self._drain_stderr, daemon=True).start()
        self.stderr = []

    # --- wire --------------------------------------------------------------------------

    def _send(self, payload):
        body = json.dumps(payload).encode("utf-8")
        self.process.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
        self.process.stdin.flush()

    def _read(self):
        stream = self.process.stdout
        while True:
            headers = {}
            while True:
                line = stream.readline()
                if not line:
                    return
                line = line.strip()
                if not line:
                    break
                name, _, value = line.decode("ascii").partition(":")
                headers[name.strip().lower()] = value.strip()
            body = stream.read(int(headers["content-length"]))
            self._handle(json.loads(body))

    def _drain_stderr(self):
        for line in self.process.stderr:
            self.stderr.append(line.decode("utf-8", "replace"))

    def _handle(self, message):
        if "method" in message and "id" in message:
            # A request from the server: answer the ones VS Code would.
            method = message["method"]
            if method == "workspace/configuration":
                result = [self.settings for _ in message["params"]["items"]]
            else:
                result = None
            self._send({"jsonrpc": "2.0", "id": message["id"], "result": result})
        elif "method" in message:
            if message["method"] == "textDocument/publishDiagnostics":
                params = message["params"]
                self.diagnostics[params["uri"]] = params["diagnostics"]
                self.updates.put(params["uri"])
        elif "id" in message:
            self.responses[message["id"]] = message

    # --- protocol ----------------------------------------------------------------------

    def send_request(self, method, params):
        """Send a request without waiting for its answer; its id."""
        ident = self.next_id
        self.next_id += 1
        self._send({"jsonrpc": "2.0", "id": ident, "method": method, "params": params})
        return ident

    def request(self, method, params, timeout=30):
        ident = self.send_request(method, params)
        deadline = time.time() + timeout
        while ident not in self.responses:
            if time.time() > deadline:
                raise TimeoutError(method)
            time.sleep(0.01)
        return self.responses.pop(ident)

    def notify(self, method, params):
        self._send({"jsonrpc": "2.0", "method": method, "params": params})

    def start(self, root_uri):
        self.request("initialize", {"processId": None, "rootUri": root_uri,
                                    "capabilities": {"workspace": {"configuration": True}}})
        self.notify("initialized", {})

    def wait_for(self, uri, predicate, timeout=30):
        """Wait until the diagnostics of \\p uri satisfy \\p predicate; return them."""
        deadline = time.time() + timeout
        while True:
            current = self.diagnostics.get(uri)
            if current is not None and predicate(current):
                return current
            remaining = deadline - time.time()
            if remaining <= 0:
                raise TimeoutError("diagnostics for %s: last %r\n%s"
                                   % (uri, current, "".join(self.stderr[-20:])))
            try:
                self.updates.get(timeout=min(remaining, 0.5))
            except queue.Empty:
                pass

    def stop(self):
        try:
            self.request("shutdown", None, timeout=10)
            self.notify("exit", None)
            self.process.wait(timeout=10)
        except Exception:
            self.process.kill()
            self.process.wait(timeout=10)
        for stream in (self.process.stdin, self.process.stdout, self.process.stderr):
            try:
                stream.close()
            except OSError:
                pass
