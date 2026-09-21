#include <Hooks/EffectText/TriggerIndentText.hpp>

#include <Hooks/Hooks.hpp>
#include <MemScan.hpp>
#include <Patches.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>

namespace {
    // **How a requirement line is built.** A container renders one line per child as
    //
    //     indent(depth) + icon + the child's content
    //
    // where the icon is `(§R*§W)` or `(§G*§W)` by whether the child evaluates true. So
    // the *parent* indents the line, icon and all - and then a container child's own
    // content begins with its header, which indents itself a second time. The two add
    // up, which is why the text of a nested block drifts right of its icon.
    //
    // Three things have to be true for a tree to come out square, and the game gets all
    // three wrong:
    //
    //   1. a block's header must **not** indent itself - its parent already did;
    //   2. the per-child indent must be one deeper than the block's own depth;
    //   3. a child block must be told its real depth, so its own children carry on from
    //      there - the game passes a constant, 0 from `and` and 1 from `or`.
    //
    // Six patches, three to each container. Each site is a whole number of instructions
    // ending where the stub rejoins.

    // ---- 1. the header indents itself -------------------------------------------------
    //
    // **One byte each**, and it has to be this rather than zeroing the depth. The
    // register holding it is read twice: as the count for the header's indent loop, and
    // again afterwards as "am I the top of the tree?" - an `or` draws an icon for its
    // own header only when nothing above it did. Zeroing the register satisfied the
    // first and broke the second, and every nested `or` came out with two asterisks.
    //
    // So the loop's own `jle <past it>` becomes an unconditional `jmp`: the indent never
    // runs, and the depth is still the depth when the icon test reads it.
    const uintptr_t AND_HEADER_JUMP = 0x5D07A9;     // jle 0x5D0807
    const uintptr_t OR_HEADER_JUMP = 0x5D0D9B;      // jle 0x5D0DF0
    const unsigned char CONDITIONAL[1] = { 0x7E };  // jle rel8
    const unsigned char ALWAYS[1] = { 0xEB };       // jmp rel8, same displacement

    // ---- 2. the per-child indent, one level deeper -------------------------------------
    const uintptr_t AND_PERCHILD_SITE = 0x5D0B6E;
    const unsigned char AND_PERCHILD_BYTES[11] =
        { 0x8B, 0x45, 0x14, 0xC6, 0x84, 0x24, 0xEC, 0x00, 0x00, 0x00, 0x0F };
    const uintptr_t AND_PERCHILD_RESUME = 0x5D0B79;

    const uintptr_t OR_PERCHILD_SITE = 0x5D1127;
    const unsigned char OR_PERCHILD_BYTES[7] =
        { 0x8B, 0x45, 0x14, 0xC6, 0x45, 0xFC, 0x0F };
    const uintptr_t OR_PERCHILD_RESUME = 0x5D112E;

    // ---- 3. the base renderer's own block children -------------------------------------
    //
    // `CTrigger::GetBlockText` renders each child in one of two ways: a child with a
    // line of its own gets `indent + icon + line`, and a child that is a **block**
    // answers nothing for its line, so the walk skips all that and appends the block
    // bare. It could, because the block indented its own header.
    //
    // It no longer does - see 1 - so that child would come out flush left, and it never
    // had an asterisk either. This puts both back on the one path that skipped them, by
    // pointing the branch that skips them at a stub that draws them first. The branch is
    // **the only way in** to that path, so nothing else changes.
    const uintptr_t BASE_SKIP_SITE = 0x5D04F4;          // je 0x5D05DA, six bytes
    const unsigned char BASE_SKIP_BYTES[6] =
        { 0x0F, 0x84, 0xE0, 0x00, 0x00, 0x00 };
    const uintptr_t BASE_SKIP_TARGET = 0x5D05DA;
    // The accumulating text is at `ebp - 0x34` in that frame - its length at `-0x24`
    // and capacity at `-0x20` confirm the string starts there. **The stub writes that
    // offset as a literal.** Naming a C constant inside an inline-asm memory operand
    // makes MSVC emit the *address of the constant* as the displacement: the first
    // attempt compiled to `lea eax, [ebp + 0x101142bc]` and crashed the game the first
    // time a tooltip took that path.
    const uintptr_t APPEND_CHARS = 0x33B40;

    // ---- 4. the asterisks inside a scope --------------------------------------------
    //
    // **The sign of the depth is a flag.** `CTrigger::GetBlockText` negates a depth that
    // arrives negative, remembers that it did, and later draws a child's asterisk only
    // when the depth was 0 *or* had been negative. So "indent this, and still colour the
    // conditions" is spelt as a negative depth, and every scope renderer passes a
    // positive one - which is why nothing inside a scope had an asterisk.
    //
    // **That suppression is right for most of them, and it took a measurement to see
    // why.** An asterisk is coloured by evaluating the condition against the scope the
    // renderer holds. `any_owned_province` and its like do not *have* the scope their
    // conditions are about: the block's own Evaluate walks every owned province looking
    // for one that satisfies all of them, and what it passes down is the country. So
    // `Has Heavy Water` evaluated there is asking whether *Germany* is a province, which
    // is false whatever the answer for any province. Forcing those asterisks on drew
    // them all red for ever - and the log said so plainly: the block false, and both
    // conditions false, against a country scope.
    //
    // A **country scope** is the exception: `AUS = { ... }` builds a real scope for
    // Austria and hands it down, so its conditions do evaluate to something true. That
    // one gets its depth negated, which is the engine's own way of asking for the
    // asterisks. The five iterating scopes are left as they are.
    const uintptr_t CONTEXT_DEPTH_SITE = 0x5D20A1;
    const unsigned char CONTEXT_DEPTH_BYTES[5] = { 0x8B, 0x55, 0x10, 0x41, 0x51 };
    const uintptr_t CONTEXT_DEPTH_RESUME = 0x5D20A6;

    // ---- 5. a child block's own depth --------------------------------------------------
    // These two fetch the child's block renderer out of its vftable and are followed by
    // the push of the depth, which the stub replaces - so the resume is past the push.
    const uintptr_t AND_BLOCK_SITE = 0x5D0A4F;
    const unsigned char AND_BLOCK_BYTES[5] = { 0x8B, 0x06, 0x8B, 0x40, 0x24 };
    const uintptr_t AND_BLOCK_RESUME = 0x5D0A55;        // past `push ebx`, one byte

    const uintptr_t OR_BLOCK_SITE = 0x5D102E;
    const unsigned char OR_BLOCK_BYTES[5] = { 0x8B, 0x16, 0x8B, 0x52, 0x24 };
    const uintptr_t OR_BLOCK_RESUME = 0x5D1035;         // past `push 1`, two bytes

    bool installedFlag = false;
    const char* statusText = "not installed yet";

    // Read by the naked stubs, so plain words.
    DWORD baseSkipTarget = 0;
    DWORD contextDepthResume = 0;
    DWORD appendChars = 0;
    DWORD andPerChildResume = 0;
    DWORD orPerChildResume = 0;
    DWORD andBlockResume = 0;
    DWORD orBlockResume = 0;

    /**@brief how the game itself adds one level of indent, called that many times*/
    typedef void(__thiscall* AppendChars)(void* text, const char* add, unsigned int n);

    /**
    @brief puts \p depth levels of indent on the end of the text being built

    Through the game's own `appendChars` rather than by rebuilding the string, so what
    lands here is byte for byte what its own indent loops produce.
    */
    void __cdecl indentInto(void* text, int depth) {
        // A tree this deep is a runaway rather than a requirement.
        if (text == nullptr || appendChars == 0 || depth <= 0 || depth > 32) {
            return;
        }
        const AppendChars append = reinterpret_cast<AppendChars>(appendChars);
        for (int i = 0; i < depth; i++) {
            append(text, "   ", 3);
        }
    }

    /**@brief a trigger's Evaluate, slot 6 of its vftable*/
    typedef bool(__thiscall* EvaluateTrigger)(void* trigger, void* scope);

    // The same seven characters the game appends: a red or a green asterisk in brackets.
    const char* const ICON_UNMET = "(\xA7R*\xA7W)";
    const char* const ICON_MET = "(\xA7G*\xA7W)";

    /**
    @brief opens the line for a block child - its indent and its asterisk

    The base renderer draws `indent + icon` only for a child that has a line of its own;
    a child that is a *block* skipped all of it. This does the same two things for that
    child, so an `and` or an `or` nested inside a scope is drawn like any other line.

    **Only below the top.** At depth 0 a block still draws its own icon - that is what an
    `or`'s header does when nothing above it has - so doing it here as well would give it
    two.

    @param text    the text being built
    @param child   the trigger about to be appended
    @param scope   what to evaluate it against
    @param redWhen the result that counts as unmet; only its low byte is the game's
    @param depth   how deep this line sits
    */
    void __cdecl blockLine(void* text, void* child, void* scope, int redWhen, int depth) {
        if (text == nullptr || depth <= 0) {
            return;
        }
        indentInto(text, depth);
        if (child == nullptr || appendChars == 0) {
            return;
        }
        void** vftable = *reinterpret_cast<void***>(child);
        if (vftable == nullptr) {
            return;
        }
        const EvaluateTrigger evaluate =
            reinterpret_cast<EvaluateTrigger>(vftable[6]);
        const bool met = evaluate(child, scope);
        const bool unmet = (met ? 1 : 0) == (redWhen & 0xFF);
        reinterpret_cast<AppendChars>(appendChars)(text, unmet ? ICON_UNMET : ICON_MET, 7);
    }

    /**
    @brief opens a block child's line before the base renderer appends it

    Reached only from the branch that used to skip straight to the append. The frame is
    still `CTrigger::GetBlockText`'s, so everything wanted is where it keeps it: the
    child in `esi`, the scope, the polarity and the depth in its arguments, and the text
    at `ebp - 0x34`. The depth has already been made positive by the sign test at its
    top.
    */
    __declspec(naked) void baseBlockIndent() {
        __asm {
            pushad
            pushfd
            push dword ptr [ebp + 0x14]     // the depth, already absolute
            push dword ptr [ebp + 0x10]     // which result counts as unmet
            push dword ptr [ebp + 0x0C]     // the scope
            push esi                        // the child about to be appended
            lea eax, [ebp - 0x34]           // the text being built - a literal,
                                            // never a named constant: MSVC puts a C
                                            // name's *address* in the operand
            push eax
            call blockLine
            add esp, 20
            popfd
            popad
            jmp [baseSkipTarget]
        }
    }

    /**
    @brief a country scope asks for its conditions to be coloured

    `not ecx` is `-(depth + 1)` exactly, which is the depth wanted and the flag that says
    the conditions under it can be evaluated - the scope it hands down is a real one.
    */
    __declspec(naked) void contextDepth() {
        __asm {
            mov edx, dword ptr [ebp + 0x10]
            not ecx
            push ecx
            jmp [contextDepthResume]
        }
    }

    /**@brief each child of an `and` sits one level inside it*/
    __declspec(naked) void andPerChild() {
        __asm {
            mov eax, dword ptr [ebp + 0x14]
            inc eax
            mov byte ptr [esp + 0xec], 0xf
            jmp [andPerChildResume]
        }
    }

    /**@brief each child of an `or` sits one level inside it*/
    __declspec(naked) void orPerChild() {
        __asm {
            mov eax, dword ptr [ebp + 0x14]
            inc eax
            mov byte ptr [ebp - 4], 0xf
            jmp [orPerChildResume]
        }
    }

    /**@brief a block inside an `and` is told how deep it really is*/
    __declspec(naked) void andBlock() {
        __asm {
            mov eax, dword ptr [esi]
            mov eax, dword ptr [eax + 0x24]
            push dword ptr [ebp + 0x14]
            inc dword ptr [esp]
            jmp [andBlockResume]
        }
    }

    /**@brief a block inside an `or`, which the game drew one level in whatever it was*/
    __declspec(naked) void orBlock() {
        __asm {
            mov edx, dword ptr [esi]
            mov edx, dword ptr [edx + 0x24]
            push dword ptr [ebp + 0x14]
            inc dword ptr [esp]
            jmp [orBlockResume]
        }
    }

    struct Site {
        uintptr_t site;
        const unsigned char* bytes;
        int length;
        uintptr_t resume;
        DWORD* resumeWord;
        void* stub;
        const char* what;
    };
}

bool Hooks::EffectText::TriggerIndent::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }

    const Site sites[] = {
        { CONTEXT_DEPTH_SITE, CONTEXT_DEPTH_BYTES, 5, CONTEXT_DEPTH_RESUME,
          &contextDepthResume, &contextDepth, "the conditions in a country scope" },
        { AND_PERCHILD_SITE, AND_PERCHILD_BYTES, 11, AND_PERCHILD_RESUME,
          &andPerChildResume, &andPerChild, "the lines inside an and" },
        { OR_PERCHILD_SITE, OR_PERCHILD_BYTES, 7, OR_PERCHILD_RESUME,
          &orPerChildResume, &orPerChild, "the lines inside an or" },
        { AND_BLOCK_SITE, AND_BLOCK_BYTES, 5, AND_BLOCK_RESUME, &andBlockResume,
          &andBlock, "a block inside an and" },
        { OR_BLOCK_SITE, OR_BLOCK_BYTES, 5, OR_BLOCK_RESUME, &orBlockResume,
          &orBlock, "a block inside an or" },
    };
    const int count = sizeof(sites) / sizeof(sites[0]);

    // **Checked before anything is written.** Six patches that only make sense
    // together - the header, the lines and the blocks of one container are three parts
    // of the same sum, and applying some of them would misalign the tree differently
    // rather than fix it. A build whose bytes differ is left alone.
    for (int i = 0; i < count; i++) {
        if (!Hooks::bytesAre(base + sites[i].site, sites[i].bytes, sites[i].length)) {
            statusText = "the trigger text code does not look the way this build expects";
            ERROR_OUT(printf("TriggerIndent: %#010x is not what was expected (%s)\n",
                static_cast<unsigned>(base + sites[i].site), sites[i].what));
            return false;
        }
    }

    // The two header jumps and the base renderer's branch are checked with the rest,
    // before anything is written.
    if (!Hooks::bytesAre(base + BASE_SKIP_SITE, BASE_SKIP_BYTES, 6)) {
        statusText = "the base renderer's block branch is not where this build expects";
        ERROR_OUT(printf("TriggerIndent: %#010x is not the branch expected\n",
            static_cast<unsigned>(base + BASE_SKIP_SITE)));
        return false;
    }
    if (!Hooks::bytesAre(base + AND_HEADER_JUMP, CONDITIONAL, 1)
        || !Hooks::bytesAre(base + OR_HEADER_JUMP, CONDITIONAL, 1)) {
        statusText = "the header indent loops are not where this build expects";
        ERROR_OUT(printf("TriggerIndent: a header's loop jump is not a jle\n"));
        return false;
    }

    // The branch keeps its condition and changes only where it goes: a `je rel32`, so
    // the four bytes after the opcode are the displacement from the end of it.
    baseSkipTarget = static_cast<DWORD>(base + BASE_SKIP_TARGET);
    appendChars = static_cast<DWORD>(base + APPEND_CHARS);
    const DWORD after = static_cast<DWORD>(base + BASE_SKIP_SITE + 6);
    const DWORD reach = reinterpret_cast<DWORD>(&baseBlockIndent) - after;
    BYTE displacement[4] = {
        static_cast<BYTE>(reach & 0xFF), static_cast<BYTE>((reach >> 8) & 0xFF),
        static_cast<BYTE>((reach >> 16) & 0xFF), static_cast<BYTE>((reach >> 24) & 0xFF)
    };
    if (!Patches::patchBytes(reinterpret_cast<void*>(base + BASE_SKIP_SITE + 2),
            displacement, 4)) {
        statusText = "could not make the code writable";
        return false;
    }

    BYTE always[1] = { ALWAYS[0] };
    if (!Patches::patchBytes(reinterpret_cast<void*>(base + AND_HEADER_JUMP), always, 1)
        || !Patches::patchBytes(reinterpret_cast<void*>(base + OR_HEADER_JUMP), always, 1)) {
        statusText = "could not make the code writable";
        return false;
    }

    for (int i = 0; i < count; i++) {
        *sites[i].resumeWord = static_cast<DWORD>(base + sites[i].resume);
        if (!Hooks::hook(reinterpret_cast<void*>(base + sites[i].site),
                sites[i].stub, 5, sites[i].length - 5)) {
            statusText = "could not make the code writable";
            return false;
        }
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("TriggerIndent: and/or blocks now indent what is inside them\n"));
    return true;
}

bool Hooks::EffectText::TriggerIndent::installed() {
    return installedFlag;
}

const char* Hooks::EffectText::TriggerIndent::status() {
    return statusText;
}
