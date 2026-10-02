# How the game writes a save

Every `SaveContents` in the image goes through a family of free functions around rva
`0x678040`-`0x679640`. Nine are named; twenty-two more are not.

## The writers

| rva | name | what it writes |
| --- | --- | --- |
| `0x678B70` | `SaveWriteFixed` | a thousandths value as `%d.%03d` |
| `0x678CA0` | `SaveWriteInt` | a plain `%d` |
| `0x678CF0` | `SaveWriteUInt` | an unsigned `%d` |
| `0x678D40` | `SaveWriteBool` | `yes`/`no` |
| `0x678FB0` | `SaveWriteString` | a quoted string, **and no key** |
| `0x678BE0` | `SaveWriteNamedFixed` | a thousandths value under a *string* key |
| `0x6791E0` | `SaveWriteKeyToken` | a key and a token value |
| `0x679210` | `SaveWriteKeyString` | a key and a quoted string |
| `0x6694C0` | `MakeFixedToken` | the `%d.%03d` formatting itself |

**`0x678B70` is the fixed-point writer, not `SaveWriteInt`.** It was reported as the
latter in passing and it is not: on the text path it hands the value to `MakeFixedToken`,
which divides by 1000 and formats three decimals as `tok_fixed` (0xD); only the binary
path emits a raw `%d`. Its three call sites in `CProvince::SaveContents` are `manpower`,
`leadership` and `revolt_risk`, and a real save has

    manpower=0.100   leadership=0.100   revolt_risk=9.000
    points=0         out_of_supply_days=2109

where the last two are written by hand through `SaveWriteValue` as bare integers. Getting
this backwards would have been the expensive kind of wrong: **this is the function that
encodes the thousandths convention** the whole game's numbers use.

`SaveWriteString` writes only the quoted value and a newline - it contains no call to
`SaveWriteKey`, and all six of its `CProvince` call sites pair it with one. So
`owner="NOR"` is two calls, not one.

**No two of them share a calling convention.** The key is always in ECX, but the writer is
EDI in the two fixed writers, ESI in the int, uint, bool and key-pair writers, and a
*stack* argument in `SaveWriteString`. Reading one and assuming the rest is wrong five
times over.

## The writer, and how nesting works

`CSaveWriter` is `+0x4 depth`, `+0x8 stream`, `+0xC binary`. `+0x0` is read by nothing in
this family and is **not settled**.

**The writer tracks depth; the caller writes only the key.**

- `SaveBeginBlock` (rva `0x679750`) writes a newline, indents `depth-1` when `depth != 0`,
  writes `{`, a newline, and increments `depth`.
- The closing half is open-coded rather than a function: it is the tail of
  `CPersistent::Save` (rva `0x5BB10`) and appears verbatim in the block helpers at
  `0x678DA0` and `0x678E90` - `depth--`, indent, then `}` and a newline **unless depth is
  now -1**.
- Every key writer indents `depth-1` as well, so an object's keys sit one level deeper
  than its own brace.

**`depth` starts at -1**, and `SaveBeginBlock`'s -1 arm writes no brace at all and sets
depth to 1. That is why a save's top-level keys sit at column 0.

That asymmetry is observable and it checks out. The root object opens no brace, but its
epilogue still closes one, because after `depth--` it is 0 rather than -1. Counting the
whole of `autosave.hoi3`:

    open 1366917   close 1366918   difference 1

**A HoI3 save is unbalanced by exactly one closing brace, by construction.** Anything that
parses one has to tolerate that.

## Token ids

The writers pin the `CToken` type ids that `CLASSES.md` only half-listed: `0xC` `tok_int`,
`0xD` `tok_fixed`, `0xE` `tok_bool`, `0xF` `tok_word`, `0x14` `tok_uint`.

## Not settled

- **`CSaveWriter +0x0`.** Nothing in the family dereferences it.
- **Where a `CSaveWriter` is constructed.** No `mov dword [reg+4], -1` exists anywhere in
  `.text`, so `depth` reaches -1 some other way - a stack local, or a helper not yet
  reached - and the top-level save entry point is still unfound.
- **`0x679D40`**, which `SaveWriteIndent` calls to emit one token N times. It is a separate
  function that `image.functionStart` folds into `SaveWriteValue`.
- **Twenty-two more writers** in the same range, each with its own invented register
  convention. Naming them finishes the save side of the image.
