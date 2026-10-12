"""Event pictures: which file `picture = <name>` shows, and a PNG of it an editor can show.

The game looks for `gfx/pictures/events/<name>.tga` (a few are `.dds`), in the mod first and
then in the game's own folders - Their Finest Hour's `tfh/` before the base game's. So a
picture the mod does not ship may still exist, and finding it needs the game install,
which is found beside the mod or named in a setting (find_game).

An editor cannot show a TGA or a DDS, so the file is decoded here and written out as a
PNG, with nothing beyond the standard library, to a cache folder the hover links to. What the files hold was surveyed on
2026-10-12 across the mod and the game: run-length and plain TGA in 24 and 32 bits,
8-bit greyscale TGA, uncompressed 32-bit DDS, one DXT1 DDS, and two JPEGs saved under a
`.tga` name, which are passed on as JPEGs.
"""

import hashlib
import os
import pathlib
import struct
import tempfile
import threading
import zlib

FOLDER = os.path.join("gfx", "pictures", "events")
EXTENSIONS = (".tga", ".dds")
# Where the previews are written, one file per version of a picture.
CACHE = os.path.join(tempfile.gettempdir(), "bicevalidator-pictures")


class PictureError(Exception):
    """A file that is there but cannot be shown."""


# --- where the game is -------------------------------------------------------------------

def is_game(path):
    return bool(path) and os.path.isfile(os.path.join(path, "hoi3_tfh.exe")) \
        and os.path.isdir(os.path.join(path, "common"))


def find_game(root, configured=None):
    """The game install for the mod at \\p root: \\p configured if it is one; the install
    an installed mod sits in (`<game>/tfh/mod/<mod>`); a `Hearts of Iron 3` folder beside
    the mod or up to four levels above it; or Steam's usual place. None if none is."""
    if configured:
        return configured if is_game(configured) else None
    root = os.path.abspath(root)
    installed = os.path.dirname(os.path.dirname(os.path.dirname(root)))
    if os.path.basename(os.path.dirname(root)).lower() == "mod" and is_game(installed):
        return installed
    current = root
    for _ in range(5):
        current = os.path.dirname(current)
        candidate = os.path.join(current, "Hearts of Iron 3")
        if is_game(candidate):
            return candidate
    for steam in (os.environ.get("ProgramFiles(x86)"), os.environ.get("ProgramFiles")):
        if steam:
            candidate = os.path.join(steam, "Steam", "steamapps", "common", "Hearts of Iron 3")
            if is_game(candidate):
                return candidate
    return None


class Pictures:
    """The event pictures the mod at \\p root can name, by lower-case name."""

    def __init__(self, root, configured_game=None):
        self.root = root
        self._lock = threading.Lock()
        self._configured = configured_game
        self._game = None
        self._names = None          # lower name -> path, the first folder's winning
        self._previews = {}         # (path, mtime) -> (mime, bytes, width, height)

    def set_game(self, configured):
        """Use \\p configured as the game install, or find it again if it is empty."""
        with self._lock:
            if configured != self._configured:
                self._configured = configured
                self._names = None

    def forget(self):
        """The folders changed: list them again when next asked."""
        with self._lock:
            self._names = None

    @property
    def game(self):
        self._table()
        return self._game

    def folders(self):
        """(label, folder) searched in order: the mod's, then the game's."""
        out = [("mod", os.path.join(self.root, FOLDER))]
        if self._game:
            out.append(("game", os.path.join(self._game, "tfh", FOLDER)))
            out.append(("game", os.path.join(self._game, FOLDER)))
        return out

    def _table(self):
        with self._lock:
            if self._names is None:
                self._game = find_game(self.root, self._configured)
                names = {}
                for _, folder in self.folders():
                    if not os.path.isdir(folder):
                        continue
                    for entry in sorted(os.listdir(folder)):
                        stem, ext = os.path.splitext(entry)
                        if ext.lower() in EXTENSIONS:
                            names.setdefault(stem.lower(), os.path.join(folder, entry))
                self._names = names
            return self._names

    def find(self, name):
        """The file `picture = <name>` shows, or None."""
        return self._table().get(name.lower())

    def names(self):
        """Every name a picture can be given, as the files spell them."""
        return sorted(os.path.splitext(os.path.basename(p))[0]
                      for p in self._table().values())

    def where(self, path):
        """\\p path as a reader would say it: relative to the mod or to the game."""
        bases = [b for b in (self.root, self._game) if b]
        for base in sorted(bases, key=len, reverse=True):     # the most specific first
            if os.path.abspath(path).lower().startswith(os.path.abspath(base).lower() + os.sep):
                label = "" if base == self.root else "the game's "
                return label + os.path.relpath(path, base).replace("\\", "/")
        return path

    def preview(self, path):
        """(mime type, image bytes, width, height) of the picture at \\p path, made once
        per version of the file. Raises PictureError for a file it cannot read."""
        key = (path, os.path.getmtime(path))
        found = self._previews.get(key)
        if found is None:
            with open(path, "rb") as handle:
                found = to_image(handle.read())
            if len(self._previews) > 64:
                self._previews.clear()
            self._previews[key] = found
        return found

    def file_uri(self, path):
        """(file URI, width, height) of a PNG or JPEG of the picture at \\p path.

        Written to a cache folder rather than put in the hover as a data URI: VS Code
        cuts a hover's markdown at 100,000 characters, and a picture in base64 runs to
        two to four times that, which left the markdown of the image showing as text.
        """
        mime, data, width, height = self.preview(path)
        stamp = "%s|%s" % (os.path.abspath(path).lower(), os.path.getmtime(path))
        name = hashlib.sha1(stamp.encode("utf-8")).hexdigest()[:16]
        target = os.path.join(CACHE, name + (".jpg" if mime == "image/jpeg" else ".png"))
        if not os.path.exists(target):
            os.makedirs(CACHE, exist_ok=True)
            partial = target + ".part"
            with open(partial, "wb") as handle:
                handle.write(data)
            os.replace(partial, target)
        return pathlib.Path(target).as_uri(), width, height


# --- decoding ----------------------------------------------------------------------------

def to_image(data):
    """(mime type, bytes, width, height) an editor can show, from a picture file's bytes."""
    if data[:2] == b"\xff\xd8":
        width, height = _jpeg_size(data)
        return "image/jpeg", data, width, height
    if data[:4] == b"DDS ":
        width, height, channels, pixels = _dds(data)
    else:
        width, height, channels, pixels = _tga(data)
    return "image/png", png(width, height, channels, pixels), width, height


def _tga(data):
    if len(data) < 18:
        raise PictureError("too short to be a TGA")
    id_length, colour_map, kind = data[0], data[1], data[2]
    width, height, bits, descriptor = struct.unpack_from("<HHBB", data, 12)
    if colour_map != 0 or kind not in (2, 3, 10, 11):
        raise PictureError("a TGA of a kind not read here (type %d)" % kind)
    size = bits // 8
    if (kind in (3, 11) and size != 1) or (kind in (2, 10) and size not in (3, 4)):
        raise PictureError("a %d-bit TGA of type %d" % (bits, kind))
    count = width * height
    start = 18 + id_length
    if kind in (2, 3):
        raw = data[start:start + count * size]
    else:
        raw = _tga_rle(data, start, count, size)
    if len(raw) < count * size:
        raise PictureError("the file ends before its last pixel")
    if size == 1:
        pixels, channels = bytes(raw[:count]), 1
    else:
        # BGR or BGRA to RGB. An alpha channel is left out: many of these files carry
        # one that is zero throughout, which would show an empty picture.
        pixels = bytearray(count * 3)
        pixels[0::3] = raw[2::size]
        pixels[1::3] = raw[1::size]
        pixels[2::3] = raw[0::size]
        channels = 3
    if not descriptor & 0x20:
        # Stored from the bottom row up.
        row = width * channels
        pixels = b"".join(pixels[i:i + row] for i in range((height - 1) * row, -1, -row))
    return width, height, channels, bytes(pixels)


def _tga_rle(data, start, count, size):
    out = bytearray()
    pos, total = start, count * size
    while len(out) < total and pos < len(data):
        header = data[pos]
        pos += 1
        run = (header & 0x7F) + 1
        if header & 0x80:
            out += data[pos:pos + size] * run
            pos += size
        else:
            out += data[pos:pos + run * size]
            pos += run * size
    return out


def _dds(data):
    if len(data) < 128:
        raise PictureError("too short to be a DDS")
    height, width = struct.unpack_from("<II", data, 12)
    flags, fourcc, bits = struct.unpack_from("<I4sI", data, 80)
    masks = struct.unpack_from("<IIII", data, 92)
    body = data[128:]
    if flags & 0x4:
        if fourcc not in (b"DXT1", b"DXT3", b"DXT5"):
            raise PictureError("a DDS compressed as %s" % fourcc.decode("latin-1"))
        return width, height, 3, _dxt(body, width, height, fourcc)
    if bits not in (24, 32):
        raise PictureError("a %d-bit DDS" % bits)
    size = bits // 8
    count = width * height
    if len(body) < count * size:
        raise PictureError("the file ends before its last pixel")
    pixels = bytearray(count * 3)
    for channel, mask in enumerate(masks[:3]):
        if mask == 0 or mask not in (0xFF, 0xFF00, 0xFF0000, 0xFF000000):
            raise PictureError("a DDS with colour masks not read here")
        offset = (mask.bit_length() - 1) // 8
        pixels[channel::3] = body[offset:count * size:size]
    return width, height, 3, bytes(pixels)


def _dxt(body, width, height, fourcc):
    """The colour of a DXT1, DXT3 or DXT5 image; the alpha blocks are skipped."""
    block = 8 if fourcc == b"DXT1" else 16
    skip = 0 if fourcc == b"DXT1" else 8
    across, down = (width + 3) // 4, (height + 3) // 4
    if len(body) < across * down * block:
        raise PictureError("the file ends before its last block")
    out = bytearray(width * height * 3)
    pos = 0
    for by in range(down):
        for bx in range(across):
            c0, c1, bits = struct.unpack_from("<HHI", body, pos + skip)
            pos += block
            palette = [_rgb565(c0), _rgb565(c1)]
            if c0 > c1 or fourcc != b"DXT1":
                palette.append(tuple((2 * a + b) // 3 for a, b in zip(palette[0], palette[1])))
                palette.append(tuple((a + 2 * b) // 3 for a, b in zip(palette[0], palette[1])))
            else:
                palette.append(tuple((a + b) // 2 for a, b in zip(palette[0], palette[1])))
                palette.append((0, 0, 0))
            for i in range(16):
                x, y = bx * 4 + i % 4, by * 4 + i // 4
                if x < width and y < height:
                    at = (y * width + x) * 3
                    out[at:at + 3] = bytes(palette[(bits >> (2 * i)) & 3])
    return bytes(out)


def _rgb565(value):
    r, g, b = (value >> 11) & 0x1F, (value >> 5) & 0x3F, value & 0x1F
    return (r << 3 | r >> 2, g << 2 | g >> 4, b << 3 | b >> 2)


def _jpeg_size(data):
    pos = 2
    while pos + 9 < len(data):
        if data[pos] != 0xFF:
            pos += 1
            continue
        marker = data[pos + 1]
        length = struct.unpack_from(">H", data, pos + 2)[0]
        if marker in (0xC0, 0xC1, 0xC2):
            height, width = struct.unpack_from(">HH", data, pos + 5)
            return width, height
        pos += 2 + length
    return 0, 0


def png(width, height, channels, pixels):
    """A PNG of \\p pixels: rows top first, 1 (grey) or 3 (RGB) bytes a pixel."""
    row = width * channels
    raw = b"".join(b"\x00" + pixels[i:i + row] for i in range(0, row * height, row))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + \
            struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    colour = 0 if channels == 1 else 2
    return b"\x89PNG\r\n\x1a\n" + \
        chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, colour, 0, 0, 0)) + \
        chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
