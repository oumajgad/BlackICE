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

    // ---- 3. a child block's own depth --------------------------------------------------
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
    DWORD andPerChildResume = 0;
    DWORD orPerChildResume = 0;
    DWORD andBlockResume = 0;
    DWORD orBlockResume = 0;

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

    // The two header jumps are checked with the rest, before anything is written.
    if (!Hooks::bytesAre(base + AND_HEADER_JUMP, CONDITIONAL, 1)
        || !Hooks::bytesAre(base + OR_HEADER_JUMP, CONDITIONAL, 1)) {
        statusText = "the header indent loops are not where this build expects";
        ERROR_OUT(printf("TriggerIndent: a header's loop jump is not a jle\n"));
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
