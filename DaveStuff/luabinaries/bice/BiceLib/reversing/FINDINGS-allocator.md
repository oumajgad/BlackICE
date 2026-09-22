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

## The new handler, and the two globals behind it

`_callnewh` was described above as fetching the handler. Followed through, because a
crash-save on out of memory would stand on it:

```
_callnewh                            0xB9F4F7   rva 0x79F4F7
  8B FF 55 8B EC                     mov edi,edi; push ebp; mov ebp,esp
  FF 35 <_pnhHeap>                   push the encoded handler      rva 0x134CC04
  FF 15 <DecodePointer>              decode it                     rva 0x92B040
  test eax,eax; je out
  push [ebp+8]; call eax             the handler, cdecl, given the size
  test eax,eax; je out
  xor eax,eax; inc eax               nonzero: tell the caller to try again
```

**`_pnhHeap` is at rva `0x134CC04`** and **nothing installs anything in it**. It is
written from exactly one instruction in the whole executable, `0xB9F4F0` inside the raw
setter at **rva `0x79F4E8`**, and that setter has exactly one caller: `0xB9845B`, a CRT
startup routine that calls `EncodePointer` and hands the result straight on. It encodes
**null**. So the first allocation the heap refuses throws, which is what the section
above says and this is why.

**`_newmode` is at rva `0x134D3C0`**, and it is **read three times and written never**.
`malloc` consults it before bothering with the handler:

```
0xB96D17  39 05 <_newmode>    cmp dword ptr [_newmode], eax   ; eax is 0 here
0xB96D1D  74 0D               je -> set errno and return null
0xB96D1F  push ebx
0xB96D20  call _callnewh
0xB96D26  test eax,eax; jne -> retry the HeapAlloc
```

Being permanently 0 means **`malloc` never asks the handler** - only `operator new`
does. Setting it to 1 is additive: a handler that gives up still leaves `malloc`
returning null exactly as before, because the give-up path falls into the same errno
and return.

The other two `_callnewh` callers are at `0xB993C2`/`0xB993D2` and `0xBA776F`, each
behind its own read of `_newmode`.

### Installing one from BiceLib

**Our own `_set_new_handler` is useless here.** BiceLib links its own CRT, so it would
write our copy of `_pnhHeap` while the game reads its own. The global has to be written
directly. `EncodePointer`'s cookie is per process rather than per module, so a pointer
encoded in BiceLib decodes correctly in the game.

`GameState/OutOfMemory.cpp` does it, and finds the two globals **by reading the operands
out of the instructions above** rather than trusting the addresses written here: the
seven bytes before the operand must match, the operand must be where it is expected, the
`DecodePointer` import must be the one named in the import table, and the slot must still
hold an encoded null. Anything else and it writes nothing.

## What the instrumentation measured

Six deliberate squeezes on 2026-09-21, with `GameState/OutOfMemory.cpp` armed. Every
one produced the same thing, and all of it is **seen**, not read:

```
fire 1  size 2097152  largest free 216 KB  free total 18240 KB
        parachute released  told the game to retry
    frame 0  exe+0x0079f511
    frame 1  exe+0x00796d25
    frame 2..5  absolute, inside BiceLib.dll
--- squeeze over: 173 chunks, 919 MB taken, malloc succeeded ---
```

**Frame 0 is `0x79F511`**, the instruction after `call eax` in `_callnewh`, and
**frame 1 is `0x796D25`**, the instruction after `malloc`'s `call _callnewh`. Both are
exactly where the disassembly above says they would be, so:

- The handler is installed and reached. `_pnhHeap` at rva `0x134CC04` is the right
  global, and a pointer encoded in BiceLib decodes correctly in the game.
- **Setting `_newmode` works.** The fire came through `malloc`, which by the section
  above would not have asked a handler at all with the global left at 0.
- The frame pointer walk holds for the CRT frames, and reaches the caller: frames 2 to
  5 are in BiceLib, which is what called the game's `malloc` for the test.
- The parachute works. 919 MB was taken away, the allocation failed, releasing 64 MB
  let the retry succeed, and the game carried on.

**What this does not yet show** is that the game's *own* allocation failures arrive
here: the squeeze provoked the failure from BiceLib's own call to the game's `malloc`,
with the render thread parked inside the page that has the button. The handler only
ever covers the exe's CRT heap, so a graphics driver allocation, a direct `HeapAlloc`
or a `new` in another module still goes past it without a word, and whether the game
catches `std::bad_alloc` anywhere is unestablished.

That one is answered by leaving it armed and playing until a real failure: a fire whose
**frame 1 is `0x796041`** came through `operator new`, one with `0x796D25` through
`malloc`, and frame 2 then names the game code that was allocating.

## Played to death with 30 MB left, and the handler never ran

2026-09-21, second run. The ballast took **859 MB in 121 reservations**, leaving 30 MB
free with a largest block of 960 KB. The game was played until it crashed, about a
minute later. The log for the whole run:

```
--- armed 2026-09-21 21:21:32  handler at exe+0x0134cc04  parachute 64 MB reserved ---
--- ballast: 121 reservations, 859 MB held, 30 MB left free (largest block 960 KB) ---
```

**No fires at all.** Neither `operator new` nor `malloc` in the executable refused a
single allocation before the process died.

### The handler was there to be asked

Zero fires can mean nothing asked, or nothing was installed to ask. The dump settles
it: `hoi3_tfh.exe.27508.dmp` has `_newmode` at `exe+0x134D3C0` reading **1**. Nothing
in the executable ever writes that global - three reads, no writes, and `.bss` starts
it at 0 - so the 1 can only have come from BiceLib's `arm()`, which writes it *after*
the handler and restores both together. **The handler was installed and live at the
moment of death, and it was never called.**

### What killed it was not the game's allocator

```
access violation (0xC0000005) at ucrtbase.dll+0x973FE  =  memcpy + 0x4e
  reading 0x00090F40, 0x800 bytes, into 0x1FBC2A00
```

**`hoi3_tfh.exe` does not import `ucrtbase.dll` at all** - its import table is 16 DLLs
and none of them is a CRT, which is the same fact as its allocator being the static one
this file is about. So that `memcpy` belongs to some other module in the process:
BiceLib, a Windows component, or one of the media and driver DLLs. Which one is not
established.

### So the ballast is a poor proxy for a real death

**30 MB of free address space is plenty for small allocations.** The heap only has to
ask the OS for more when it runs out of room in what it already holds, so a starved
process kills whoever next wants something *large* - and that was not the game. The
ballast starves every module in the process equally, and something else fell over
first.

This says the test is wrong, not that the idea is. What it does establish is that a
game under memory pressure does not necessarily reach `operator new` at all before the
process dies, which is worth knowing either way.

### The natural crash looks nothing like it

The dump from three hours earlier, before any of this existed, on an ordinary load:

```
access violation (0xC0000005) at hoi3_tfh.exe+0x33C38
  writing 0x713F27F4        esi = 0x713F27E4
  overlay closed, frames started 0
```

`0x33C38` is `mov dword ptr [esi+0x10], edi` inside **`std::string::appendChars`**
(rva `0x33B40`), and `esi+0x10` is exactly the `0x713F27F4` it faulted on - so it is
the string writing its own length field through a `this` that is not mapped. In the
game's own code, during loading, with the overlay never drawn.

**That** is the death worth catching, and the way to catch it is to leave the handler
armed with no ballast and reproduce it. The crash dump notes have those happening
35-110 s after launch at 2.0-3.3 GB private bytes.

## What was measured about the address space

Incidental, but worth keeping: the squeeze could take **919 MB** in 173 reservations
before the space was gone, so that session had 919 MB of free address space left in
pieces of 256 KB or more.

The **18 MB in holes smaller than 256 KB** it left behind says less than it looks like.
The squeeze stops at 256 KB chunks, so a 300 KB hole becomes a 44 KB one by its own
doing, and the residue is its own leftovers mixed with fragments that were already
there. Telling the two apart needs the free list measured *before* a squeeze, which is
what `Largest free block` on the Memory page already shows.

## The other empty handler slot: `_purecall`

Found while looking for somewhere the game could be caught before it dies, because the
new handler above turned out never to be asked. **This one is asked.**

```
_purecall                            0xB961D5   rva 0x7961D5
  FF 35 <__pPurecall>                push the handler, kept encoded   rva 0x134D238
  FF 15 <DecodePointer>              decode it                        rva 0x92B040
  85 C0                              test eax, eax
  74 02                              je  -> the abort path
  FF D0                              call eax        the handler: no arguments, no result
  6A 19                              push 25 = _RT_PUREVIRT
  ...                                and on into the CRT's runtime error and abort
```

**`push 0x19` is what identifies it**, and it is worth saying why: 25 is the CRT's
runtime error number for a pure virtual call, pushed on exactly the path taken when no
handler is installed. Without that, a function that decodes a pointer and calls it
could be any of the half dozen handler wrappers in this CRT - the shape alone does not
distinguish them.

`_purecall` is what the compiler puts in a **pure virtual's vftable slot**, and the
counts bear that out: **510 slots in the data sections hold this address, and nothing
calls it directly.** So it is reached only by ordinary virtual dispatch, through an
object used while it is still being constructed or after it has been destroyed.

### `__pPurecall`, rva `0x134D238`

Empty, the same way and for the same reason as `_pnhHeap`. It is `.bss`, so it starts
at zero; the CRT startup at `0xB9845B` encodes a null into it along with four other
handler globals; and **the only other instruction in the executable that writes it** is
the raw setter at rva **`0x79F96E`**, which has no caller at all.

That setter stores what it is given without encoding it, so anything calling it has to
encode first - which is what the startup does, and what BiceLib does.

### The five globals that startup clears

Worth keeping, because it is the list of every handler slot this CRT has, and three of
them are still unidentified:

| rva | set by | is |
| --- | --- | --- |
| `0x134CC04` | `0x79F4E8` | `_pnhHeap`, the new handler - read by `_callnewh` |
| `0x134D238` | `0x79F96E` | **`__pPurecall`** - read by `_purecall` |
| `0x134D23C` | `0x79F97D` | read at `0x79FADF`, which tail-jumps to it with arguments |
| `0x134D3D8` | `0x7A534A` | written, and never read in `.text` |
| `0x134D3C4`..`D0` | `0x7A5145` | four slots set together from one call |

### What BiceLib does with it

`GameState/PureCall.cpp` installs a handler, by writing `EncodePointer(&ours)` straight
into `__pPurecall` - **no instruction is patched**, because the CRT already provides the
slot and the game never used it. It verifies the two opcodes, both operands read out of
the instructions rather than trusted from this page, the `_RT_PUREVIRT` tail, and that
the slot still decodes to null, before writing anything.

The handler cannot return - returning lands back on the abort path - so it saves
synchronously by calling `CInGameIdler::AutosaveWrite` (rva `0x24FF80`) directly, then
says why and ends the process. `GameState/CrashSave.cpp` is the shared end of that and
of the out of memory watch.
