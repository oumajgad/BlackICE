"""Event pictures: each kind of file the mod and the game hold, decoded to the same pixels."""

import os
import struct
import unittest
import zlib

from bicevalidator.pictures import PictureError, Pictures, find_game, png, to_image

from .helpers import TinyMod

# A 2 x 2 picture, top row first: red, green / blue, white.
PIXELS = [[(255, 0, 0), (0, 255, 0)], [(0, 0, 255), (255, 255, 255)]]


def read_png(data):
    """(width, height, rows of RGB tuples) of a PNG this module wrote."""
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, chunks = 8, {}
    while pos < len(data):
        length = struct.unpack_from(">I", data, pos)[0]
        kind = data[pos + 4:pos + 8]
        chunks[kind] = chunks.get(kind, b"") + data[pos + 8:pos + 8 + length]
        pos += 12 + length
    width, height, depth, colour = struct.unpack_from(">IIBB", chunks[b"IHDR"])
    channels = 1 if colour == 0 else 3
    raw = zlib.decompress(chunks[b"IDAT"])
    stride = width * channels + 1
    rows = []
    for y in range(height):
        line = raw[y * stride + 1:(y + 1) * stride]
        if channels == 1:
            rows.append([(v, v, v) for v in line])
        else:
            rows.append([tuple(line[x * 3:x * 3 + 3]) for x in range(width)])
    return width, height, rows


def tga(kind=2, bits=24, top_first=True, rle=False):
    rows = PIXELS if top_first else list(reversed(PIXELS))
    pixels = []
    for row in rows:
        for r, g, b in row:
            if bits == 8:
                pixels.append(bytes([r]))
            elif bits == 24:
                pixels.append(bytes([b, g, r]))
            else:
                pixels.append(bytes([b, g, r, 0]))     # alpha zero, as many files have
    if rle:
        # One raw packet of the first pixel, then a run of the last pixel repeated once.
        body = bytes([0x00]) + pixels[0] + bytes([0x00]) + pixels[1] + \
            bytes([0x00]) + pixels[2] + bytes([0x80]) + pixels[3]
    else:
        body = b"".join(pixels)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, kind, 0, 0, 0, 0, 0, 2, 2, bits,
                         0x20 if top_first else 0)
    return header + body


def dds_rgb():
    header = bytearray(128)
    header[0:4] = b"DDS "
    struct.pack_into("<II", header, 12, 2, 2)                      # height, width
    struct.pack_into("<II4sI", header, 76, 32, 0x41, b"\0\0\0\0", 32)
    struct.pack_into("<IIII", header, 92, 0xFF0000, 0xFF00, 0xFF, 0xFF000000)
    body = b"".join(bytes([b, g, r, 255]) for row in PIXELS for r, g, b in row)
    return bytes(header) + body


def dds_dxt1():
    header = bytearray(128)
    header[0:4] = b"DDS "
    struct.pack_into("<II", header, 12, 4, 4)
    struct.pack_into("<II4sI", header, 76, 32, 0x4, b"DXT1", 0)
    # c0 white, c1 black, c0 > c1: index 0 is white, 1 black. Top row white, the rest black.
    block = struct.pack("<HHI", 0xFFFF, 0x0000, 0x55555500)
    return bytes(header) + block


class DecodingTest(unittest.TestCase):
    def assertPixels(self, data):
        mime, image, width, height = to_image(data)
        self.assertEqual((mime, width, height), ("image/png", 2, 2))
        self.assertEqual(read_png(image)[2], PIXELS)

    def test_plain_tga_either_way_up(self):
        self.assertPixels(tga(top_first=True))
        self.assertPixels(tga(top_first=False))

    def test_run_length_tga(self):
        # Three one-pixel raw packets and a one-pixel run.
        self.assertPixels(tga(kind=10, rle=True))

    def test_32_bit_tga_ignores_an_empty_alpha(self):
        self.assertPixels(tga(bits=32))

    def test_greyscale_tga(self):
        mime, image, width, height = to_image(tga(kind=3, bits=8))
        self.assertEqual(read_png(image)[2], [[(255,) * 3, (0,) * 3], [(0,) * 3, (255,) * 3]])

    def test_uncompressed_dds(self):
        self.assertPixels(dds_rgb())

    def test_dxt1_dds(self):
        _, image, width, height = to_image(dds_dxt1())
        rows = read_png(image)[2]
        self.assertEqual(rows[0], [(255, 255, 255)] * 4)
        self.assertEqual(rows[1], [(0, 0, 0)] * 4)

    def test_a_jpeg_under_a_tga_name_is_passed_on(self):
        jpeg = b"\xff\xd8\xff\xc0\x00\x11\x08\x00\x10\x00\x20" + b"\x00" * 20
        mime, image, width, height = to_image(jpeg)
        self.assertEqual((mime, width, height), ("image/jpeg", 32, 16))
        self.assertEqual(image, jpeg)

    def test_what_cannot_be_read_says_so(self):
        with self.assertRaises(PictureError):
            to_image(b"\x00\x01\x01" + b"\x00" * 30)

    def test_png_is_well_formed(self):
        data = png(1, 1, 3, b"\x01\x02\x03")
        self.assertEqual(read_png(data), (1, 1, [[(1, 2, 3)]]))


class FindingTest(unittest.TestCase):
    def setUp(self):
        self.mod = TinyMod()
        self.mod.write("gfx/pictures/events/Supply-GER.tga", tga().decode("latin-1"),
                       encoding="latin-1")
        self.game = os.path.join(self.mod.root, "game")
        for rel in ("hoi3_tfh.exe", "tfh/gfx/pictures/events/OnlyInTfh.tga",
                    "gfx/pictures/events/OnlyInBase.tga",
                    "gfx/pictures/events/supply-ger.tga"):
            path = os.path.join(self.game, rel)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "wb") as handle:
                handle.write(tga())
        os.makedirs(os.path.join(self.game, "common"))

    def tearDown(self):
        self.mod.close()

    def test_the_mod_comes_first_then_the_game(self):
        pictures = Pictures(self.mod.root, self.game)
        self.assertTrue(pictures.find("SUPPLY-ger").startswith(self.mod.root + os.sep + "gfx"))
        self.assertIn(os.path.join("tfh", "gfx"), pictures.find("OnlyInTfh"))
        self.assertIsNotNone(pictures.find("onlyinbase"))
        self.assertIsNone(pictures.find("nowhere"))
        self.assertEqual(pictures.where(pictures.find("OnlyInBase")),
                         "the game's gfx/pictures/events/OnlyInBase.tga")
        uri, width, height = pictures.file_uri(pictures.find("Supply-GER"))
        self.assertTrue(uri.startswith("file:///") and uri.endswith(".png"), uri)
        self.assertEqual((width, height), (2, 2))
        from urllib.request import url2pathname
        written = url2pathname(uri[len("file:"):])
        with open(written, "rb") as handle:
            self.assertEqual(read_png(handle.read())[2], PIXELS)

    def test_the_game_is_found_beside_the_mod_or_named(self):
        mod = os.path.join(self.mod.root, "checkouts", "BlackICE")
        os.makedirs(mod)
        os.rename(self.game, os.path.join(self.mod.root, "Hearts of Iron 3"))
        found = find_game(mod)
        self.assertEqual(found, os.path.join(self.mod.root, "Hearts of Iron 3"))
        self.assertIsNone(find_game(mod, configured=os.path.join(self.mod.root, "nowhere")))

    def test_an_installed_mod_finds_the_game_it_is_in(self):
        installed = os.path.join(self.game, "tfh", "mod", "BlackICE")
        os.makedirs(installed)
        self.assertEqual(find_game(installed), self.game)


if __name__ == "__main__":
    unittest.main()
