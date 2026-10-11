"""Tokens to a tree, which carries on past a broken file rather than stopping at the first fault.

A node is one of three shapes:

    key = value         a pair: op is "=" (or "<", ">"), value is a string
    key = { ... }       a block: children is a list of nodes
    value               a bare item, as in `model = { 0 0 1 }`: op and value are None
    { ... }             an anonymous block: key is None

The parser never raises. What it could not make sense of is returned beside the tree, so
the syntax checks can say where and the schema checks can still look at the rest.
"""

from dataclasses import dataclass, field

from . import lexer


class Node:
    __slots__ = ("key", "key_tok", "op", "value", "value_tok", "children",
                 "open_tok", "close_tok", "parent")

    def __init__(self, key=None, key_tok=None, parent=None):
        self.key = key
        self.key_tok = key_tok
        self.op = None
        self.value = None
        self.value_tok = None
        self.children = None
        self.open_tok = None
        self.close_tok = None
        self.parent = parent

    @property
    def is_block(self):
        return self.children is not None

    @property
    def is_pair(self):
        return self.op is not None and self.children is None

    @property
    def line(self):
        token = self.key_tok or self.open_tok
        return token.line if token else 0

    @property
    def col(self):
        token = self.key_tok or self.open_tok
        return token.col if token else 0

    @property
    def lkey(self):
        return self.key.lower() if self.key is not None else None

    def child(self, key):
        """The first child pair or block named \\p key, case-insensitively."""
        key = key.lower()
        for node in self.children or ():
            if node.lkey == key and node.op is not None:
                return node
        return None

    def __repr__(self):
        if self.children is not None:
            return "<%s = {%d} @%d>" % (self.key, len(self.children), self.line)
        return "<%s %s %s @%d>" % (self.key, self.op, self.value, self.line)


@dataclass
class ParseResult:
    root: Node
    tokens: list
    extra_closers: list = field(default_factory=list)   # "}" tokens with nothing open
    unclosed: list = field(default_factory=list)        # block nodes still open at the end
    missing_values: list = field(default_factory=list)  # pair nodes with "=" and nothing after
    stray_ops: list = field(default_factory=list)       # "=" tokens with no key before them
    unterminated: object = None                         # a string token that never closed


def parse(text):
    tokens, unterminated = lexer.tokenize(text)
    root = Node()
    root.children = []
    result = ParseResult(root, tokens, unterminated=unterminated)
    stack = [root]
    i, n = 0, len(tokens)
    while i < n:
        tok = tokens[i]
        top = stack[-1]
        if tok.kind in (lexer.WORD, lexer.STRING):
            node = Node(tok.text, tok, top)
            top.children.append(node)
            nxt = tokens[i + 1] if i + 1 < n else None
            if nxt is not None and nxt.kind == lexer.OP:
                node.op = nxt.text
                val = tokens[i + 2] if i + 2 < n else None
                if val is None or val.kind in (lexer.CLOSE, lexer.OP):
                    result.missing_values.append(node)
                    i += 2
                    continue
                if val.kind == lexer.OPEN:
                    node.children = []
                    node.open_tok = val
                    stack.append(node)
                    i += 3
                    continue
                # A word or a string. A word followed by "=" would be the next pair's key,
                # meaning this one's value is missing - `a = b = c` is never intended.
                after = tokens[i + 3] if i + 3 < n else None
                if val.kind == lexer.WORD and after is not None and after.kind == lexer.OP \
                        and after.text == "=":
                    # Kept on the node so the report can say what the game will make of it.
                    node.value_tok = val
                    result.missing_values.append(node)
                    i += 2
                    continue
                node.value = val.text
                node.value_tok = val
                i += 3
                continue
            i += 1
            continue
        if tok.kind == lexer.OPEN:
            node = Node(None, None, top)
            node.children = []
            node.open_tok = tok
            top.children.append(node)
            stack.append(node)
            i += 1
            continue
        if tok.kind == lexer.CLOSE:
            if len(stack) > 1:
                stack.pop().close_tok = tok
            else:
                result.extra_closers.append(tok)
            i += 1
            continue
        if tok.kind == lexer.OP:
            result.stray_ops.append(tok)
            i += 1
            continue
        i += 1
    result.unclosed = stack[1:]
    return result


def walk(node):
    """Every node under \\p node, depth first, in file order."""
    pending = list(reversed(node.children or ()))
    while pending:
        current = pending.pop()
        yield current
        if current.children:
            pending.extend(reversed(current.children))
