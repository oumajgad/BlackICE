#include <Hooks/Tooltips/CombatUnitStats.hpp>

#include <GameClasses/CRegiment.hpp>
#include <GameClasses/CSubUnitDefinition.hpp>
#include <GameClasses/CUnit.hpp>
#include <GameClasses/GameString.hpp>
#include <HoiDataStructures.hpp>
#include <Hooks/Hooks.hpp>
#include <Hooks/Tooltips/CombatUnitDamage.hpp>
#include <Hooks/Tooltips/TooltipFont.hpp>
#include <MemScan.hpp>
#include <TextTable.hpp>
#include <utils.hpp>

#include <Windows.h>
#include <cstdio>
#include <string>

namespace {
    // ---------------------------------------------------------------------------------
    // Two sites in the battle unit tooltip, `0x329D40`.
    // ---------------------------------------------------------------------------------

    /**
     * **Where the unit is still in EDI**: `mov [esp + 0xA0], eax` at `0x32AFC8`, the store
     * of the text object the `BATTLE_ATTACKMOD` line was just fetched with. Seven bytes,
     * replaced by a five byte jump and two NOPs.
     *
     * Nothing is written here - this only remembers which unit the tooltip being built is
     * about, because by the time the finished text is handed over EDI has been reused for
     * the hand-over itself. The two run in that order in one call on one thread, so a
     * single slot is enough; it is cleared as it is read so a path that reaches the
     * hand-over without coming through here cannot pick up the last unit's stats.
     */
    const uintptr_t UNIT_SITE = 0x32AFC8;
    const unsigned char UNIT_BYTES[7] = { 0x89, 0x84, 0x24, 0xA0, 0x00, 0x00, 0x00 };
    const uintptr_t UNIT_RESUME = 0x32AFCF;

    /**
     * **Where the finished tooltip is handed over**: `call 0x40C560` at `0x32BD43`.
     *
     * That function copies the tooltip out of EDI into the caller's buffer and `0x40C500`
     * destroys the original right after, so this call is the last moment the text exists
     * in the form the builder left it - which is what makes it the place to add to.
     *
     * **EDI is the text itself**, a `Hoi3CString` at `+0`. The copy reads what look like
     * two more strings after it, but only the first really is one; see `bodyOf`.
     *
     * **Appending here rather than through the localisation is deliberate.** The game
     * appends `": <value>"` to a line *after* rendering that line's key, so text put in a
     * key's own string lands between the label and its number - `Defend Modifier`, the
     * added block, then `149.50%` on the end of it. There is no way to place a variable after
     * the value from inside the key.
     */
    const uintptr_t HANDOVER_SITE = 0x32BD43;
    const uintptr_t HANDOVER_CALL = 0xC560;
    const uintptr_t HANDOVER_RESUME = 0x32BD48;

    /**@brief `std::string(int value, int decimals)`, the game's own; it constructs into
       the string it is given, so that one has to be empty*/
    const uintptr_t FORMAT_NUMBER = 0x65ACA0;
    typedef void* (__stdcall* FormatNumber)(void* out, int value, int decimals);

    /**@brief `Hoi3CString::append(const char*, unsigned)`, `this` in ECX*/
    const uintptr_t APPEND_CHARS = 0x33B40;
    typedef void* (__thiscall* AppendChars)(void* self, const char* text, unsigned int length);

    /**@brief the game's own colour escapes, in Windows-1252 as the localisation stores them*/
    const char* const YELLOW = "\xA7Y";
    const char* const WHITE = "\xA7W";

    /**@brief the game's numbers are thousandths; one decimal is what the tooltip uses*/
    const int DECIMALS = 1;

    /**@brief longer than this is not a tooltip but a bad read; the one measured is 281*/
    const unsigned MAX_TOOLTIP = 0x4000;

    /**
     * **The two combat modifiers, as the tooltip works them out.** `CUnit + 0xEC` times
     * `+0xF4` is the attack side (`0x32AE39`) and `+0xF0` times `+0xF8` the defend side
     * (`0x32AE8A`), each product over a thousand. That the second of each pair is a
     * multiplier rather than a value is the game's own doing: both are compared against
     * `0x3E8` before use, at `0x32ABC6` and `0x32ACF6`, and the equal case skips the whole
     * block - which is only worth doing for a factor of one.
     *
     * **They multiply rather than add**, which the printed numbers bear out: on a division
     * showing Combined Arms +22.5%, Terrain -10%, Night -70% and Leader +35.7%, the attack
     * modifier printed was 44.70% and 1.225 x 0.9 x 0.30 x 1.357 is 0.449, while the
     * defend modifier printed 149.50% and the same product without the night term is
     * 1.496.
     *
     * Named for the arithmetic they take part in, not for what they are - see
     * `reversing/ghidra/project.json`, where the same caution is recorded.
     */
    const uintptr_t ATTACK_A = 0xEC;
    const uintptr_t ATTACK_B = 0xF4;
    const uintptr_t DEFEND_A = 0xF0;
    const uintptr_t DEFEND_B = 0xF8;

    /**@brief a thousandths factor of one*/
    const int ONE = 1000;

    /**@brief Hoi3CString keeps its length here; Game::rawChars finds the characters*/
    const uintptr_t STRING_LENGTH = 0x10;

    DWORD unitResume = 0;
    DWORD handoverCall = 0;
    DWORD handoverResume = 0;
    FormatNumber formatNumber = nullptr;
    AppendChars appendChars = nullptr;
    uintptr_t armyVFTable = 0;
    uintptr_t navyVFTable = 0;
    uintptr_t airVFTable = 0;

    bool installedFlag = false;
    const char* statusText = "not installed";

    /**@brief the unit the tooltip being built is about, from the first site to the second*/
    uintptr_t pendingUnit = 0;

    /**@brief the same, kept rather than consumed, for the reversing probes to arm on*/
    uintptr_t rememberedUnit = 0;

    /**
    @brief what a division's brigades add up to

    Summed over the brigades, which is what a bigger division really does get more of.
    Piercing and armour are not here: the game's own tooltip prints both already.
    */
    struct Totals
    {
        int softAttack = 0;
        int hardAttack = 0;
        int defensiveness = 0;
        int toughness = 0;

        int brigades = 0;

        bool any() const { return brigades > 0; }
    };

    /**@brief one field of a subunit's own definition, or 0 where it cannot be read*/
    int stat(uintptr_t definition, uintptr_t offset) {
        int value = 0;
        return Mem::tryRead(definition + offset, value) ? value : 0;
    }

    /**
    @brief totals the unit's brigades

    Walks `CUnit::regiments` as a list and reads each regiment's **own** definition
    (`CRegiment + 0x58`), which `CSubUnit::ApplyTechnologies` has already rebuilt from the
    type's template plus every technology scaled by its level. Nothing here re-derives
    research; a brigade that cannot be read is skipped rather than counted as zero.
    */
    bool aggregate(uintptr_t unit, Totals& out) {
        uintptr_t node = 0;
        if (!Mem::tryRead(unit + CUnit::Offsets::regiments + HDS::ListOffsets::first, node)) {
            return false;
        }

        // A list the game is rebuilding mid-walk would otherwise spin: no division has
        // anything like this many brigades, so a longer walk is a broken read.
        const int LIMIT = 256;
        for (int seen = 0; node != 0 && seen < LIMIT; ++seen) {
            uintptr_t regiment = 0;
            uintptr_t next = 0;
            if (!Mem::tryRead(node + HDS::NodeOffsets::data, regiment)
                || !Mem::tryRead(node + HDS::NodeOffsets::next, next)) {
                return false;
            }

            uintptr_t definition = 0;
            if (regiment != 0
                && Mem::tryRead(regiment + CRegiment::Offsets::sub_unit_definition_ptr, definition)
                && definition != 0) {
                out.softAttack += stat(definition, CSubUnitDefinition::Offsets::soft_attack);
                out.hardAttack += stat(definition, CSubUnitDefinition::Offsets::hard_attack);
                out.defensiveness += stat(definition, CSubUnitDefinition::Offsets::defensiveness);
                out.toughness += stat(definition, CSubUnitDefinition::Offsets::toughness);
                ++out.brigades;
            }
            node = next;
        }
        return out.any();
    }

    /**
    @brief the unit's attack and defend modifiers, as thousandths of one

    Returns false where either pair cannot be read, and the block then shows the base
    values alone rather than an effective value it cannot stand behind.
    */
    bool modifiers(uintptr_t unit, int& attack, int& defend) {
        int a = 0, b = 0, c = 0, d = 0;
        if (!Mem::tryRead(unit + ATTACK_A, a) || !Mem::tryRead(unit + ATTACK_B, b)
            || !Mem::tryRead(unit + DEFEND_A, c) || !Mem::tryRead(unit + DEFEND_B, d)) {
            return false;
        }
        attack = static_cast<int>(static_cast<long long>(a) * b / ONE);
        defend = static_cast<int>(static_cast<long long>(c) * d / ONE);
        return true;
    }

    /**@brief a base value scaled by a thousandths modifier*/
    int scaled(int base, int modifier) {
        return static_cast<int>(static_cast<long long>(base) * modifier / ONE);
    }

    /**
    @brief a line that sets the block apart from the game's own text

    The two headings are the one place yellow is used on words. Everything the game
    itself writes is a white caption and a coloured number, and a block with no heading at
    all runs straight on from the line above it.
    */
    std::string heading(const char* text) {
        return std::string(YELLOW) + text + WHITE;
    }

    /**
    @brief a caption, which the game leaves white

    **The game colours the number, not the words** - its own lines are `Piercing Attack:`
    in white and `5` in yellow. The escape is written even though white is the default,
    because the cell before it ends in a number and left the colour yellow.
    */
    std::string caption(const char* text) {
        return std::string(WHITE) + text;
    }

    /**@brief a number, which is the part the game colours*/
    std::string value(const char* text) {
        return std::string(YELLOW) + text + WHITE;
    }

    /**@brief a thousandths value as the tooltip prints its own numbers*/
    void number(int value, char* out, size_t size) {
        Game::String text;
        formatNumber(text.raw(), value, DECIMALS);
        _snprintf_s(out, size, _TRUNCATE, "%s", text.text());
    }

    unsigned lengthOf(uintptr_t string) {
        unsigned length = 0;
        return Mem::tryRead(string + STRING_LENGTH, length) ? length : 0;
    }

    /**
    @brief `base -> effective`, or just the base where there is no modifier to apply

    An arrow that points at the same number says nothing, so a modifier of exactly one is
    written as the base alone - which is also what a unit out of combat shows.
    */
    void pair(int base, int modifier, bool scale, char* out, size_t size) {
        char first[32];
        number(base, first, sizeof first);
        if (!scale || modifier == ONE) {
            _snprintf_s(out, size, _TRUNCATE, "%s%s%s", YELLOW, first, WHITE);
            return;
        }
        char second[32];
        number(scaled(base, modifier), second, sizeof second);
        // The arrow is not a number, so it stays white between the two that are.
        _snprintf_s(out, size, _TRUNCATE, "%s%s%s -> %s%s%s",
            YELLOW, first, WHITE, YELLOW, second, WHITE);
    }

    /**
    @brief the tooltip's text, or 0 if what is there does not look like a string

    **The body is the string at +0, and nothing else here is a string.** `0x40C560`
    appears to copy three of them, at +0, +0x18 and +0x30, but its source stride is not the
    `Hoi3CString + 1` the decompilation reads as: +0x18 holds a length of two billion and a
    pointer that is not one, so **treating it as a string and appending to it crashes the
    game**. Nothing needs the real stride - the builder appends everything to one
    accumulator, and that accumulator is the string at +0.

    The length is checked against what a tooltip can plausibly be before anything is
    written, because the cost of being wrong here is a crash rather than a wrong number.
    */
    uintptr_t bodyOf(uintptr_t tooltip) {
        const unsigned length = lengthOf(tooltip);
        if (length > MAX_TOOLTIP) {
            ERROR_OUT(printf("CombatUnitStats: %#010x is %u chars, which is not a tooltip\n",
                static_cast<unsigned>(tooltip), length));
            return 0;
        }
        return tooltip;
    }

    /**
    @brief writes the stat block onto the end of the finished tooltip

    Takes the unit remembered at the first site, clearing it either way, so a tooltip that
    did not come past there adds nothing rather than repeating the last one's numbers.
    */
    void appendStats(uintptr_t tooltip) {
        const uintptr_t unit = pendingUnit;
        pendingUnit = 0;
        rememberedUnit = unit;

        uintptr_t vftable = 0;
        if (tooltip == 0 || unit == 0 || !Mem::tryRead(unit, vftable)
            || (vftable != armyVFTable && vftable != navyVFTable && vftable != airVFTable)) {
            return;
        }

        // **Before anything is measured.** The probe put on GetStringWidth by the last
        // tooltip has by now seen this font being used, so it is taken out and its answer
        // wired in, and everything below is laid out with the game's own widths. The
        // first tooltip of a session is laid out from the descriptor and may sit crooked;
        // the second and every one after it does not.
        if (!Hooks::Tooltips::TooltipFont::known()) {
            Hooks::Tooltips::TooltipFont::stopWatching();
        }

        Totals totals;
        if (!aggregate(unit, totals)) {
            return;
        }
        const uintptr_t body = bodyOf(tooltip);
        if (body == 0) {
            return;
        }

        int attack = ONE;
        int defend = ONE;
        const bool scale = modifiers(unit, attack, defend);

        // **Piercing and armour are left out**: the game's own tooltip already prints both,
        // and neither is scaled by the combat modifiers anyway - they are compared against
        // each other directly - so repeating them here would add a line and no meaning.
        char soft[48], hard[48], defence[48], tough[48];
        pair(totals.softAttack, attack, scale, soft, sizeof soft);
        pair(totals.hardAttack, attack, scale, hard, sizeof hard);
        pair(totals.defensiveness, defend, scale, defence, sizeof defence);
        pair(totals.toughness, defend, scale, tough, sizeof tough);

        // Laid out through Text::Table rather than with spaces written into the format
        // string: the tooltip font is proportional, so a column padded to a fixed number
        // of characters lands wherever the words and figures happen to end.
        Text::Table stats;
        stats.indent("  ");
        stats.cell(caption("Soft Attack:")).cell(soft).row();
        stats.cell(caption("Hard Attack:")).cell(hard).row();
        stats.cell(caption("Defensiveness:")).cell(defence).row();
        stats.cell(caption("Toughness:")).cell(tough).row();

        std::string block = "\n" + heading("Base") + " -> " + heading("effective") + "\n"
            + stats.text();

        // Dealt and taken come from CombatUnitDamage, which counts them off the game's own
        // damage call. They only appear once that hook has seen this unit fight: a unit
        // that has not been in a battle has no figures, and showing it two zeroes would
        // read as "hit nothing" rather than "not yet measured".
        // Organisation is counted where CSubUnit::SettleDamage spends it, after the
        // clamp, rather than where CUnit::TakeDamage works it out - the raw total is
        // damage attempted and is several times what a division actually loses.
        if (Hooks::Tooltips::CombatUnitDamage::known(unit)) {
            char dealt[32], orgDealt[32], taken[32], org[32];
            number(Hooks::Tooltips::CombatUnitDamage::dealtBy(unit), dealt, sizeof dealt);
            number(Hooks::Tooltips::CombatUnitDamage::dealtOrganisationBy(unit),
                orgDealt, sizeof orgDealt);
            number(Hooks::Tooltips::CombatUnitDamage::takenBy(unit), taken, sizeof taken);
            number(Hooks::Tooltips::CombatUnitDamage::takenOrganisationBy(unit), org, sizeof org);

            // `str` and `org` are column headings rather than a prefix on every figure.
            // They are right aligned with the figures under them, so each sits over the
            // end of its column rather than over the widest number in it.
            Text::Table damage;
            damage.indent("  ").align(1, Text::RIGHT).align(2, Text::RIGHT);
            damage.cell("").cell(caption("Strength")).cell(caption("Organisation")).row();
            damage.cell(caption("Dealt:")).cell(value(dealt)).cell(value(orgDealt)).row();
            damage.cell(caption("Taken:")).cell(value(taken)).cell(value(org)).row();

            block += "\n" + heading("Damage") + "\n"
                + damage.text();
        }

        appendChars(reinterpret_cast<void*>(body), block.c_str(),
            static_cast<unsigned>(block.size()));

        // The tooltip is complete and about to be measured for drawing, which is the
        // moment to listen. `effective` is a word from the block above, chosen for being
        // short rather than for being distinctive: any tooltip's text identifies the font,
        // and a string the interface has already broken up for wrapping arrives at the
        // measuring one piece at a time, so a phrase would not match.
        if (!Hooks::Tooltips::TooltipFont::known()) {
            Hooks::Tooltips::TooltipFont::watchFor("effective");
        }
    }

    /**
    @brief remembers the unit, then does the store it replaced

    `edi` is the unit and `eax` is the line's text object; the stub changes neither, and
    `pushad`/`popad` leave the frame exactly as the store below expects - which matters,
    because that store is `[esp + 0xA0]` and a stack that had moved would land elsewhere.
    */
    __declspec(naked) void unitInHand() {
        __asm {
            pushad
            pushfd
            mov pendingUnit, edi
            popfd
            popad

            mov dword ptr [esp + 0xA0], eax // exactly the instruction this replaced
            jmp [unitResume]
        }
    }

    /**
    @brief adds the block, then makes the call it replaced

    `edi` is the finished tooltip - three strings and two dwords - and the call below
    copies it out and is followed by its destruction, so this is the last point it can be
    added to. The argument the original call takes is already pushed on arrival, and the
    stub neither pushes nor pops outside its own pair.
    */
    __declspec(naked) void tooltipFinished() {
        __asm {
            pushad
            pushfd
            push edi                        // the tooltip about to be copied out
            call appendStats
            add esp, 4
            popfd
            popad

            call [handoverCall]             // exactly the call this replaced
            jmp [handoverResume]
        }
    }
}

bool Hooks::Tooltips::CombatUnitStats::install() {
    if (installedFlag) {
        return true;
    }

    const uintptr_t base = Mem::moduleBase("hoi3_tfh.exe");
    if (base == 0) {
        statusText = "hoi3_tfh.exe is not loaded";
        return false;
    }
    if (!Hooks::bytesAre(base + UNIT_SITE, UNIT_BYTES, 7)) {
        statusText = "the battle tooltip does not build the attack modifier where this "
            "build expects";
        ERROR_OUT(printf("CombatUnitStats: %#010x is not the instruction expected\n",
            static_cast<unsigned>(base + UNIT_SITE)));
        return false;
    }
    if (!Hooks::isCallTo(base + HANDOVER_SITE, base + HANDOVER_CALL)) {
        statusText = "the battle tooltip does not finish where this build expects";
        ERROR_OUT(printf("CombatUnitStats: %#010x is not the call expected\n",
            static_cast<unsigned>(base + HANDOVER_SITE)));
        return false;
    }

    formatNumber = reinterpret_cast<FormatNumber>(base + FORMAT_NUMBER);
    appendChars = reinterpret_cast<AppendChars>(base + APPEND_CHARS);
    unitResume = static_cast<DWORD>(base + UNIT_RESUME);
    handoverCall = static_cast<DWORD>(base + HANDOVER_CALL);
    handoverResume = static_cast<DWORD>(base + HANDOVER_RESUME);
    armyVFTable = base + CUnit::VFTable::CArmy;
    navyVFTable = base + CUnit::VFTable::CNavy;
    airVFTable = base + CUnit::VFTable::CAir;

    // The unit has to be remembered before the tooltip that reads it is finished, so the
    // first one built after this has something to say. Seven bytes at the first site means
    // two NOPs after the jump; the second is a call, and five for five.
    if (!Hooks::hook(reinterpret_cast<void*>(base + UNIT_SITE), &unitInHand, 5, 2)
        || !Hooks::hook(reinterpret_cast<void*>(base + HANDOVER_SITE), &tooltipFinished, 5, 0)) {
        statusText = "could not make the code writable";
        return false;
    }

    // The font descriptor is read here rather than at the first tooltip: it is a file, and
    // the hook that would otherwise trigger it runs while the game is drawing.
    Text::Font::toolTip();

    // The counting is a separate patch in separate code, so it is allowed to fail on its
    // own: the stat block is still worth having without the damage lines, and the reason
    // goes to the log rather than taking the whole tooltip down.
    if (!Hooks::Tooltips::CombatUnitDamage::install()) {
        ERROR_OUT(printf("CombatUnitStats: no damage counting - %s\n",
            Hooks::Tooltips::CombatUnitDamage::status()));
    }

    installedFlag = true;
    statusText = "installed";
    INFO_OUT(printf("CombatUnitStats: the battle unit tooltip gains a base stat block\n"));
    return true;
}

bool Hooks::Tooltips::CombatUnitStats::installed() {
    return installedFlag;
}

const char* Hooks::Tooltips::CombatUnitStats::status() {
    return statusText;
}

uintptr_t Hooks::Tooltips::CombatUnitStats::lastUnit() {
    return rememberedUnit;
}

void Hooks::Tooltips::CombatUnitStats::forgetUnit() {
    rememberedUnit = 0;
}
