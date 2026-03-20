import enum
import sys
from pathlib import Path

sys.setrecursionlimit(2000)
SPACE_CHARS = [" ", "\t", "\n", "\r"]
CURRENT_FILE_PATH = ""
CURRENT_FILE_CONTENT = ""
DEBUG = False


def debug_out(message: str, idx: int, throw: bool = False):
    line_number = CURRENT_FILE_CONTENT.count("\n", 0, idx)
    msg = f"{CURRENT_FILE_PATH}:{line_number}/{idx}: {message}"
    if throw:
        raise Exception(msg)
    if DEBUG:
        print(msg)


class Types(int, enum.Enum):
    object = 0
    pair = 1
    list = 2


def next_char(content: str, idx: int) -> tuple[str, int]:
    i = idx
    while i < len(content):
        char: str = content[i]
        if char == "#":
            x = content.find("\n", i)
            if x == -1:
                return
            else:
                i = x
        elif char not in SPACE_CHARS:
            return content[i], i
        i += 1
    debug_out("Failed to find next char", idx, True)


def determine_type(content: str, idx: int) -> int | None:
    char, i = next_char(content, idx)
    if char == "=":
        char, i = next_char(content, i + 1)
        if char == "{":
            closing = content.find("}", i)
            if closing == -1:
                debug_out("Closing bracket not found", i, True)
            if content.find("=", i, closing) == -1:
                return Types.list
            else:
                return Types.object
        else:
            return Types.pair

    return Types.list


def parse_string(content: str, idx: int) -> tuple[str, int]:
    quoted = False
    current = idx
    start = current
    if content[current] == '"':
        current += 1
        quoted = True
    while current <= len(content):
        char = content[current]
        if (
            (char in SPACE_CHARS and not quoted)
            or (char == "}" and not quoted)
            or (char == "=" and not quoted)
            or (char == '"' and quoted)
            or (char == "#")
        ):
            if quoted:
                res = str(content[start + 1 : current])
                current += 1
            else:
                res = str(content[start:current])
            return res, current
        current += 1


def parse_list(content: str, idx: int) -> tuple[list, int]:
    res = []
    i = idx
    for x in range(10000):
        char, i = next_char(content, i)
        if char == "{":
            char, i = next_char(content, i + 1)
        if char == "}":
            return res, i + 1
        val, i = parse_string(content, i)
        res.append(val)
    debug_out("parse_list exceeded limit", idx, True)


CASE_OVERRIDES = {
    "not": "NOT",
    "or": "OR",
    "and": "AND",
    "tag": "TAG",
    "this": "THIS",
    "from": "FROM",
    "limit": "LIMIT",
}


def insert(_dict: dict, key, val):
    if _dict.get(key, None) is not None:
        if isinstance(_dict[key], list):
            _dict[key].append(val)
        else:
            temp = _dict[key]
            _dict[key] = [temp, val]
    else:
        _dict[key] = val
    return


def parse_object(content: str, idx: int) -> tuple[dict, int]:
    res = {}
    i = idx
    while True:
        char, i = next_char(content, i)
        if char == "{":
            char, i = next_char(content, i + 1)
        if char == "}":
            return res, i + 1

        key, i = parse_string(content, i)
        if CASE_OVERRIDES.get(key.lower()):
            key = CASE_OVERRIDES[key.lower()]
        debug_out(f"{key = }", i)

        value_type = determine_type(content, i)
        char, i = next_char(content, i)  # should always be "="
        if char != "=":
            debug_out(f"Expected '=' but got '{char}'", i, True)
        i += 1

        if value_type == Types.object:
            _, i = next_char(content, i)
            val, i = parse_object(content, i)
            insert(res, key, val)
        elif value_type == Types.list:
            _, i = next_char(content, i)
            val, i = parse_list(content, i)
            insert(res, key, val)
        elif value_type == Types.pair:
            _, i = next_char(content, i)
            val, i = parse_string(content, i)
            insert(res, key, val)


def parse_file(path: Path) -> dict:
    with open(path, "r", encoding="ISO-8859-1") as f:
        content = f.read()
    global CURRENT_FILE_CONTENT
    CURRENT_FILE_CONTENT = content
    global CURRENT_FILE_PATH
    CURRENT_FILE_PATH = str(path.parts[-2]) + "/" + str(path.parts[-1])

    parsed, _ = parse_object("{ " + content + " \n}", 0)
    return parsed
