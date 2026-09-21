# The allocator, and what a call site gives away

`FUN_00b9602f` is **`operator new`**, so it stands behind every object the game builds.
It is worth naming for its own sake - a named call reads better than a number - but the
reason to care is the argument: **`operator new` is told how big the object is**, in a
`push` right before the call, and that is a fact about a class sitting in plain sight at
eleven thousand places in the executable.

`switchmap.py` has assumed this address was the allocator since it was written
(`ALLOCATOR = 0x00B9602F`, so a case body's `new` is skipped when looking for the class a
case builds). What is new here is that it has been **followed through and confirmed**, and
written into `project.json` so Ghidra says `operator_new` instead of `FUN_00b9602f`.

## The chain

```
operator_new(size)                          0xB9602F   rva 0x79602F
  loop:
    eax = malloc(size)                      0xB96CC3
    if (eax) return eax
    if (!_callnewh(size)) break             0xB9F4F7
    goto loop
  throw std::bad_alloc                      vftable 0x159FCE8
                                            _CxxThrowException 0xB9894B
```

The standard MSVC body: ask the allocator, and if it says no, give the **new handler** a
chance to free something and ask again. **It never returns null** - when the handler gives
up it throws. A `test eax, eax` after one of these calls is the compiler being thorough
about a path that cannot happen, not a real check, and reading it as one has misled at
least one pass over this code.

**`malloc` (`0xB96CC3`)** rejects a size over `_HEAP_MAXREQ` - which compiles to
`cmp ebx, -0x20`, so anything above `0xFFFFFFE0` - rounds a zero request up to one byte,
and calls **`HeapAlloc(_crtheap, 0, size)`**. `_crtheap` is the global at `0x134D240`
(rva), made on first use. It is `HeapAlloc` for certain: the indirect call goes through
`0xD2B038`, which the import table names.

**`_callnewh` (`0xB9F4F7`)** fetches the installed new handler and reports whether to try
again. The handler is kept **encoded** at `0x134CC04` and restored with `DecodePointer`,
so it cannot be read out of memory directly. No handler has been found installed anywhere
in the game, which means the first allocation the heap refuses throws straight away.

**`std::bad_alloc`** is named from its own RTTI, behind the vftable at `0x159FCE8` - not
guessed from the shape of the code.

**`free` (`0xB95F9B`)** was already named, and is the other half: every string destructor
in the executable is `if (capacity > 15) free(pointer)`.

Both functions open with `mov edi, edi`, the two byte hot patch pad, so the body proper
starts at `+2`.

## Reading a call site

```
0040bfc9  push 0xda8            ; how big
0040bfce  call operator_new
0040bfd3  mov  esi, eax
0040bfd5  add  esp, 4
```

Counted across `.text`: **11,247 calls to `operator_new`**, of which **8,154** have a
literal `push` immediately before, in **172 distinct sizes**. The commonest:

| size | sites | |
| --- | --- | --- |
| `0xda8` | 3054 | one object, not 3054 - see below |
| `0x10` | 550 | |
| `0x14` | 469 | |
| `0x44` | 323 | |
| `0x57c` | 266 | the country database, among others |

**`0xda8` is a singleton's accessor, inlined.** Every one of those 3054 sites reads a
global, tests it, and only allocates when it is null:

```
cmp  eax, ebx                 ; the global against 0
jne  0x40c033                 ; already made - skip
push 0xda8
call operator_new
```

So the count measures **how many places fetch that object**, not how many exist. A high
count against one size means a singleton, and that is worth knowing on its own.

## Size to class: a real lead, and the wrong way to take it

If a size could be tied to the class being built, `PROGRESS.md`'s `size` column - which is
almost entirely empty - would fill itself. The obvious route is to follow the constructor
called just after the allocation and take the vftable it writes, which is what
`switchmap.classAt` already does.

**Tried, and it does not work as it stands.** Over a spread of 1165 sites it produced an
answer for 66% of them, and the answers are visibly wrong:

| class | sizes it was seen at |
| --- | --- |
| `std::out_of_range` | `0x10`, `0x20`, `0x3c`, `0x44`, `0x58`, `0x70`, `0x74`, `0x84`, `0x8c`, `0xd0`, `0x290` |
| `CCommand` | `0x3c`, `0x40`, `0x50`, `0x6c`, `0x90`, `0xac`, `0xb0`, `0xbc` |
| `CCurrentGameState` | `0x28`, `0x68`, `0x74`, `0xda8` |

One class cannot have eleven sizes. `classAt` recurses **three calls deep** looking for a
vftable, which is right where it is used - a switch case body, where the construction *is*
what the case does - and wrong here, because from an allocation site three calls of slack
is enough to wander into a bounds check or a shared helper and come back with its class.
A trustworthy version has to take **only the vftable the called constructor writes
itself**, accept a much lower hit rate, and drop anything where two sites disagree about a
class's size. Until somebody does that, **do not believe a size-to-class table**.

## Two traps

**Capstone's `X86_OP_IMM` is 2. `X86_OP_REG` is 1.** Writing `op.type == 1` for "is this
an immediate" silently asks for a register instead, and `op.imm` on a register operand
returns a number anyway - so nothing raises, the scan simply finds nothing, or finds
nonsense. This cost the first two attempts at the size scan above, which reported 0% and
looked like a fact about the game. It also produced the garbage `push 0x15` / `push 0x13`
that an earlier pass wrote off as disassembly desync: those were `push ebx` and
`push esi`, read as immediates. **Use `capstone.x86.X86_OP_IMM`, never the number.**

**Bytes before a call are not an instruction.** The scan above finds `push` by looking at
the five bytes in front of `E8`, which is not instruction-aligned and so invents a few
sizes - `0x58245c88` and `0x6000004` came out of it. Good enough for counting, not for a
table anybody relies on; disassemble forward from a known point to be sure, which is how
the `0xda8` sites above were checked.
