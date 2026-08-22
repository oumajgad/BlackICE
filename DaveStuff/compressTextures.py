"""Converts the mod's uncompressed .dds art to DXT, in place.

    python compressTextures.py --dry-run              # what it would do, changes nothing
    python compressTextures.py                        # convert gfx/interface and gfx/mapitems
    python compressTextures.py gfx/interface
    python compressTextures.py --sheet worst.png      # eyeball the ugliest conversions

An uncompressed texture costs its full size in video memory; DXT1 costs an eighth of
that and DXT5 a quarter. The engine already reads both - a few hundred of the files it
ships are DXT - so this only changes how the art is stored, not how it is used.

Every file is encoded, decoded again, and compared against the original before anything
is written, and three rules decide what is left alone. Art under --min-pixels is skipped
outright: everything below 128x128 put together is under 2 MB of the 300-odd on offer,
and it is the art that shows block artifacts worst. What is left has to come through
both --max-error, on the mean, and --max-spike, on the worst one percent of pixels -
an icon can average an error of 8 and still have one corner turned to mush.

An earlier pass without those checks damaged icons badly enough to be reverted.

Nothing is backed up, because gfx/ is in git: `git checkout -- gfx` undoes the lot.
"""

import argparse
import io
import os
import struct
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DDSD_MIPMAPCOUNT = 0x20000
DDPF_FOURCC = 0x4
DDSCAPS_COMPLEX = 0x8
DDSCAPS_TEXTURE = 0x1000
DDSCAPS_MIPMAP = 0x400000


def readHeader(path):
    """The parts of a .dds header that decide whether we can touch the file."""
    with open(path, "rb") as f:
        head = f.read(128)
    if len(head) < 128 or head[:4] != b"DDS ":
        return None
    size, flags, height, width, pitch, depth, mips = struct.unpack_from("<7I", head, 4)
    pfFlags, = struct.unpack_from("<I", head, 80)
    return dict(width=width, height=height, mips=mips,
                compressed=bool(pfFlags & DDPF_FOURCC))


def encode(image, fourcc):
    """One mip level as raw DXT blocks, without the header Pillow puts in front."""
    buffer = io.BytesIO()
    image.save(buffer, format="DDS", pixel_format=fourcc)
    return buffer.getvalue()[128:]


def decode(blocks, width, height, fourcc):
    """Back to pixels, so the result can be compared with what went in."""
    header = bytearray(128)
    header[0:4] = b"DDS "
    struct.pack_into("<7I", header, 4, 124, 0x81007, height, width, len(blocks), 0, 0)
    struct.pack_into("<I", header, 76, 32)
    struct.pack_into("<I", header, 80, DDPF_FOURCC)
    header[84:88] = fourcc.encode("ascii")
    struct.pack_into("<I", header, 108, DDSCAPS_TEXTURE)
    return Image.open(io.BytesIO(bytes(header) + blocks)).convert("RGBA")


def error(original, decoded):
    """How far the compressed image strayed, in levels out of 255.

    The mean alone is not enough to judge by: an icon can average an error of 8 and
    still have one block turned to mush, because the flat pixels around it average the
    damage away. So the 99th percentile of the colour error comes back too - that is
    the number that separates a photograph, which strays a little everywhere, from a
    flat icon with one ruined corner."""
    a = numpy.asarray(original, dtype=numpy.int16)
    b = numpy.asarray(decoded, dtype=numpy.int16)
    difference = numpy.abs(a - b)
    colour = difference[:, :, :3]
    return (float(colour.mean()), float(difference[:, :, 3].mean()),
            float(numpy.percentile(colour, 99)))


def mipChain(image, levels):
    """The image and its halvings, down to 1x1 - the sizes D3DX walks a chain by.

    Levels smaller than a 4x4 block still cost one whole block, which is why the
    chain can go below 4 pixels at all."""
    chain = [image]
    width, height = image.size
    while len(chain) < levels and (width > 1 or height > 1):
        width = max(1, width // 2)
        height = max(1, height // 2)
        chain.append(image.resize((width, height), Image.LANCZOS))
    return chain


def convert(path, limits, dryRun):
    """Returns (status, detail) and rewrites the file unless dryRun."""
    maxError, maxSpike, minPixels = limits

    header = readHeader(path)
    if header is None:
        return "not a dds", None
    if header["compressed"]:
        return "already dxt", None

    width, height = header["width"], header["height"]
    if width % 4 or height % 4 or width < 4 or height < 4:
        return "not a multiple of 4", None
    if width * height < minPixels:
        # All the art below this is icons, and all of it together is under 2 MB of the
        # 300-odd on offer. It is the art where block artifacts show most and buy least.
        return "too small to bother", None

    try:
        image = Image.open(path)
        image.load()
        image = image.convert("RGBA")
    except Exception as exc:
        return "unreadable", str(exc)[:70]

    if image.size != (width, height):
        return "unreadable", "header says %dx%d, decoded %dx%d" % (
            width, height, image.size[0], image.size[1])

    # DXT1 where there is no alpha to lose, and it is half the size of the rest.
    # Otherwise DXT5 - never DXT3, whose four-bit alpha the encoder here quantises
    # badly enough to turn an alpha of 217 into 119, for exactly the same file size.
    opaque = numpy.asarray(image)[:, :, 3].min() == 255
    fourcc = "DXT1" if opaque else "DXT5"

    try:
        blocks = encode(image, fourcc)
    except Exception as exc:
        return "would not encode", str(exc)[:70]

    rgbError, alphaError, spike = error(image, decode(blocks, width, height, fourcc))
    if max(rgbError, alphaError) > maxError:
        return "too lossy", "%s rgb %.1f alpha %.1f" % (fourcc, rgbError, alphaError)
    if spike > maxSpike:
        return "too blocky", "%s worst 1%% of pixels off by %.0f" % (fourcc, spike)
    score = max(rgbError, alphaError)

    original = os.path.getsize(path)
    levels = max(1, header["mips"])
    payload = blocks
    if levels > 1:
        chain = mipChain(image, levels)
        payload = b"".join(encode(level, fourcc) for level in chain)
        levels = len(chain)

    out = bytearray(128)
    out[0:4] = b"DDS "
    flags = 0x81007 | (DDSD_MIPMAPCOUNT if levels > 1 else 0)
    struct.pack_into("<7I", out, 4, 124, flags, height, width, len(blocks), 0,
                     levels if levels > 1 else 0)
    struct.pack_into("<I", out, 76, 32)
    struct.pack_into("<I", out, 80, DDPF_FOURCC)
    out[84:88] = fourcc.encode("ascii")
    caps = DDSCAPS_TEXTURE | (DDSCAPS_COMPLEX | DDSCAPS_MIPMAP if levels > 1 else 0)
    struct.pack_into("<I", out, 108, caps)

    if not dryRun:
        with open(path, "wb") as f:
            f.write(bytes(out) + payload)

    return "converted", dict(fourcc=fourcc, before=original,
                             after=128 + len(payload), score=score,
                             rgb=rgbError, alpha=alphaError, mips=levels)


def job(arguments):
    path, limits, dryRun = arguments
    try:
        status, detail = convert(path, limits, dryRun)
    except Exception as exc:                      # one bad file must not stop the run
        status, detail = "failed", "%s: %s" % (type(exc).__name__, str(exc)[:60])
    return path, status, detail


def collect(folders):
    for folder in folders:
        for root, dirs, files in os.walk(folder):
            for name in sorted(files):
                if name.lower().endswith(".dds"):
                    yield os.path.join(root, name)


def contactSheet(path, worst):
    """Original above, DXT below, for the conversions that lost the most."""
    tiles = []
    for score, filePath, fourcc in worst:
        image = Image.open(filePath).convert("RGBA")
        blocks = encode(image, fourcc)
        tiles.append((os.path.basename(filePath), score, image,
                      decode(blocks, image.size[0], image.size[1], fourcc)))
    if not tiles:
        return
    cell = 160
    sheet = Image.new("RGBA", (cell * len(tiles), cell * 2), (32, 32, 32, 255))
    for index, (name, score, before, after) in enumerate(tiles):
        # Scaled to fill the cell, nearest neighbour and the same scale for both, so
        # a 16-pixel icon is actually inspectable and the two rows line up.
        scale = min(cell / float(before.size[0]), cell / float(before.size[1]))
        size = (max(1, int(before.size[0] * scale)), max(1, int(before.size[1] * scale)))
        for row, image in ((0, before), (1, after)):
            thumb = image.resize(size, Image.NEAREST)
            sheet.paste(thumb, (index * cell + (cell - size[0]) // 2,
                                row * cell + (cell - size[1]) // 2), thumb)
    sheet.save(path)
    print("\nworst conversions written to %s (top row original, bottom row DXT)" % path)
    for name, score, _, _ in tiles:
        print("    %-44s error %.1f" % (name[:44], score))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("folders", nargs="*",
                        default=["gfx/interface", "gfx/mapitems"])
    parser.add_argument("--max-error", type=float, default=8.0,
                        help="skip a file whose mean per-channel error is above this")
    parser.add_argument("--max-spike", type=float, default=24.0,
                        help="skip a file whose worst 1%% of pixels stray more than this")
    parser.add_argument("--min-pixels", type=int, default=128 * 128,
                        help="skip art smaller than this many pixels - icons, mostly")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 4) - 2))
    parser.add_argument("--sheet", default="", help="write a before/after PNG here")
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args()

    folders = [f if os.path.isabs(f) else os.path.join(REPO, f) for f in args.folders]
    for folder in folders:
        if not os.path.isdir(folder):
            sys.exit("no such folder: %s" % folder)

    files = list(collect(folders))
    if args.limit:
        files = files[:args.limit]
    print("%d .dds files under %s%s"
          % (len(files), ", ".join(os.path.relpath(f, REPO) for f in folders),
             "   (dry run)" if args.dry_run else ""))

    counts = {}
    weight = {}
    before = after = 0
    lossy = []
    converted = []
    problems = []

    limits = (args.max_error, args.max_spike, args.min_pixels)
    work = [(path, limits, args.dry_run) for path in files]
    with ProcessPoolExecutor(max_workers=args.jobs) as pool:
        for done, (path, status, detail) in enumerate(
                pool.map(job, work, chunksize=16), 1):
            counts[status] = counts.get(status, 0) + 1
            try:
                weight[status] = weight.get(status, 0) + os.path.getsize(path)
            except OSError:
                pass
            if status == "converted":
                before += detail["before"]
                after += detail["after"]
                converted.append((detail["score"], path, detail["fourcc"]))
            elif status in ("too lossy", "too blocky"):
                lossy.append((path, detail))
            elif status in ("failed", "unreadable"):
                problems.append((path, detail))
            if done % 1000 == 0:
                print("    %d/%d" % (done, len(files)))

    print("\n%-22s %6s %9s" % ("outcome", "files", "MB"))
    for status in sorted(counts, key=lambda s: -counts[s]):
        print("%-22s %6d %9.0f"
              % (status, counts[status], weight.get(status, 0) / 2.0 ** 20))

    print("\n%.0f MB of art becomes %.0f MB, saving %.0f MB"
          % (before / 2.0 ** 20, after / 2.0 ** 20, (before - after) / 2.0 ** 20))

    if lossy:
        print("\nleft alone as too damaged:")
        for path, detail in lossy[:12]:
            print("    %-52s %s" % (os.path.relpath(path, REPO)[-52:], detail))
        if len(lossy) > 12:
            print("    ... and %d more" % (len(lossy) - 12))
    if problems:
        print("\nproblems:")
        for path, detail in problems[:12]:
            print("    %-52s %s" % (os.path.relpath(path, REPO)[-52:], detail))
        if len(problems) > 12:
            print("    ... and %d more" % (len(problems) - 12))

    if args.sheet and converted:
        converted.sort(reverse=True)
        contactSheet(args.sheet, converted[:12])


if __name__ == "__main__":
    main()
