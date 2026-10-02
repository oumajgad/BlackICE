# How the game measures text

Worked out to lay a stat block out in columns inside a tooltip
(`BiceLib/Hooks/Tooltips/CombatUnitStats.cpp`, through `BiceLib/TextTable.cpp`). The
tooltip font is proportional, so anything that lines up has to be measured in pixels, and
the only measurement worth trusting is the one the game makes itself.

## The font's glyph table

`CEU3BitmapFont::GetStringWidth` (`0x6FD700`, virtual slot 10) reaches a glyph as

    glyph = *(CEU3BitmapFontGlyph**)(font + character * 4 + 0x94)

so the font carries **256 glyph pointers at `+0x94`**, indexed by the raw byte. A
character the font does not list has a null there and contributes nothing.

The table's length is not a guess: `0x94 + 256 * 4` is `0x494`, and `0x494` is exactly the
next field the loader writes (`0x6FA26D`).

Each glyph is a fixed **`0x820` byte** record:

| offset | what |
| --- | --- |
| `0x00` | x in the texture |
| `0x04` | y |
| `0x08` | width |
| `0x0C` | height |
| `0x10` | xoffset |
| `0x14` | yoffset |
| `0x18` | **xadvance** - what the pen moves by |
| `0x1C` | kerning pairs, `{int second; int amount;}` each |
| `0x81C` | how many pairs |

`(0x81C - 0x1C) / 8` is 256, so a glyph can hold up to 256 pairs.

## The descriptor is read positionally

`gfx/fonts/<fontName>.fnt` is an AngelCode BMFont descriptor in plain text, and the mod
and the game both ship the usual `char id=32 x=192 ... xadvance=3 page=0` lines.

**The game never reads those key names.** `CEU3BitmapFont::LoadGlyphs` (`0x6F9FD0`)
matches only the first token of a line - against `char` at `0x6FA2E3` and `kerning` at
`0x6FA4AC` - and then takes the numbers after it **in file order**, one `atoi` at a time:

    char     id  x  y  width  height  xoffset  yoffset  xadvance
    kerning  first  second  amount

which is why `grep xadvance hoi3_tfh.exe` finds nothing. That was the thing worth
establishing: it means the numbers in the `.fnt` reach the renderer unchanged, so
measuring from the file gives the same answer the game gets, as long as it is the right
file.

A `char` line whose id is `0x20` has its **height forced to zero** (`0x6FA3BD`), whatever
the file says.

A kerning line is applied to the glyph it names first:

    n = glyph->kerning_count
    glyph->kerning[n].second = second
    glyph->kerning[n].amount = amount
    glyph->kerning_count = n + 1

`garamond_16` has 199 of them, nearly all `-1`.

`CEU3BitmapFont::Load` (`0x6F9EA0`, slot 5) is the one above it: it builds
`gfx/fonts/<fontName>.tga`, loads the texture, and then calls `LoadGlyphs` for the
descriptor beside it.

**`0x6F9EA0` and `0x6F9FD0` are two functions with no padding between them**, which is the
trap `image.functionStart` walks into - it answers `0x6F9EA0` for any address in either.
The tell is the frame: the first reserves `0x58` bytes and the second `0x1B4`, and the
parser addresses `[ebp - 0x1C0]`, which the first could not have.

## What `GetStringWidth` counts

`int __thiscall GetStringWidth(const char* text, int length)`, `length` negative meaning
"to the NUL". It walks the bytes and, for each:

- **`0xA7` and the byte after it are skipped entirely** - the colour escape draws nothing.
  Only when the font says it handles escapes (virtual slot at `+0x4C` returns true);
  otherwise `0xA7` is measured as an ordinary glyph.
- `0x40` takes three bytes and adds an icon's width (virtual `+0x68`); `0xA3` takes a
  `[A-Za-z_]` name and adds another (virtual `+0x64`); `0xA4` adds a flat 8, and `{` adds
  8 and takes two bytes.
- an ordinary glyph adds its `xadvance`, **and then the kerning pair between it and the
  next byte, if the glyph has one**. The partner is the literal next byte - the game does
  not skip an escape to find the next drawn character.
- `\n` ends a line; the result is the widest line, not the sum.

Leaving kerning out is what made a hand-built column miss by a few pixels.

## Padding can only land on a 4 pixel grid

Padding a column has to be made of characters, and in `garamond_16` the only two glyphs
that draw nothing are the space (`32`) and the non-breaking space (`160`) - **both advance
4 pixels**. There is no thinner blank, and none of the escapes moves the pen by an
arbitrary amount. So a column placed by padding can only ever land within **2 pixels** of
where it was aimed at.

That is a property of the medium. It is under a third of a digit wide, and no better
measurement removes it. `Text::Table` rounds to the nearest space and carries the achieved
position forward rather than the intended one, so the error stays at ±2 instead of
accumulating down a row.

## Tooltips are drawn in Arial14

`interface/core.gui` says so, in every copy - the base game's, `tfh`'s and the mod's:

    textBoxType={
        name = "ToolTip"
        font = "Arial14"
        ...
    }

**`ToolTip_Font` is a different thing and belongs to the console.** `core.gfx` defines a
`bitmapfont` of that name over `garamond_16`, and the one element that asks for it is
`console_text`. Two names a letter apart, one of them not the tooltip's.

That cost three builds, and the mistake was in the searching rather than in the data.
The search was

    grep -riE "tool_?tip" interface/*.gui | grep -i font

which only finds a line holding both words - and in a `textBoxType` the name and the font
are on separate lines. The only thing that could match was the literal `font =
"ToolTip_Font"`, which is the console's. **Grep a block-structured file with context, not
with a pipeline that needs one line to carry the whole answer.**

## Identifying it from the game, which is what settled it

Before `core.gui` was read properly the font was taken from the running game, and that
remains how `Text::Table` measures - it is the stronger arrangement, because it does not
depend on reading any of this correctly. `Hooks::Tooltips::TooltipFont` patches
`GetStringWidth` for as long as it takes one tooltip to be measured and keeps the `this`
it was called with. That object's own measurements identify it:

| measured through the game | value |
| --- | --- |
| a space | **3** pixels (garamond_16's is 4) |
| `max("Soft Attack:", "Defensiveness:")` | **87** pixels |
| `max("Hard Attack:", "Toughness:")` | **70** pixels |

The last two are read back out of the laid out block: `Text::Table` reports each column's
start, and a column's width is `start[n+1] - start[n] - gap`, with the gap two spaces.

Of every `.fnt` in the game and the mod, **exactly one** matches all three - `Arial14` -
and no other font with a 3 pixel space comes within 6 pixels on either column, which
agrees with what `core.gui` says. The mod ships its own `Arial14.fnt`, whose header says
`size=12` against the game's `size=15`, but the two agree on every advance and all 67
kerning pairs, so which one is loaded makes no difference to the layout.

`Arial14` is now what `Text::Font` reads for the first tooltip of a session. Everything
after it is measured by the game, which is worth keeping even though the answer is in
`core.gui`: a `textBoxType` can name any font, and this way nothing has to be re-read when
one does.

## What is still open

`Text::Font`'s descriptor path still measures the `@`, `0xA3` and `0xA4` icon escapes as
ordinary glyphs, since it has no font object to ask for an icon's width. Only the first
tooltip of a session is laid out that way, and nothing BiceLib writes contains one.
