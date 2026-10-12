"""Every rule the validator has, with what it means and why it matters.

Ids are stable - the baseline and the hidden-rule list store them - so a rule is never
renumbered; a retired one keeps its id unused.

Severity:
    error    the game will not do what the file says
    warning  very likely wrong, but the tool is relying on an inference
    info     worth knowing; often deliberate

Mode decides which run reports it: "code" is whether each file is valid script on its
own, "references" is whether what it names exists elsewhere in the mod.

Confidence follows the fact base's vocabulary. "confirmed" rests on the engine's own
keyword switches; "inferred" rests on how the mod writes things.
"""

from dataclasses import dataclass

ERROR, WARNING, INFO = "error", "warning", "info"
CODE, REFERENCES = "code", "references"
SEVERITIES = (ERROR, WARNING, INFO)
MODES = (CODE, REFERENCES)


@dataclass(frozen=True)
class Rule:
    id: str
    name: str
    severity: str
    mode: str
    confidence: str
    title: str
    explanation: str


_RULES = [
    # --- syntax --------------------------------------------------------------------------
    Rule("BV001", "extra-closing-bracket", ERROR, CODE, "confirmed",
         "Closing bracket with nothing open",
         "A `}` closes a block that was never opened, so everything after it is read at the "
         "wrong level. The fault is almost never at the bracket itself: a block above it has "
         "lost its opening line, or an earlier `}` closed a block too soon. The hint points "
         "at where the indentation stops agreeing with the brackets, which is usually the "
         "real spot."),
    Rule("BV002", "unclosed-block", ERROR, CODE, "confirmed",
         "Block never closed",
         "This block is still open when the file ends, so everything after the missing `}` "
         "is read as part of it. The hint points at where the indentation suggests the "
         "`}` was lost."),
    Rule("BV003", "unterminated-string", ERROR, CODE, "confirmed",
         "Quoted text never closed",
         "A `\"` opens text that runs to the end of the file, swallowing every key after "
         "it."),
    Rule("BV004", "missing-value", ERROR, CODE, "confirmed",
         "Key with no value",
         "`key =` is followed by nothing usable - a `}`, another `=`, or the end of the "
         "file. The key is dropped, and often the next key with it."),
    Rule("BV005", "stray-operator", ERROR, CODE, "confirmed",
         "Operator with no key",
         "An `=` with no key before it. Usually a key was deleted and its `=` left behind."),
    Rule("BV006", "string-spans-lines", WARNING, CODE, "inferred",
         "Quoted text runs over several lines and contains script",
         "Quoted text may legitimately run over lines, but this one contains `=` or `{`, "
         "which usually means a closing `\"` is missing further up and the script after it "
         "is being read as text."),
    Rule("BV007", "utf8-file", WARNING, CODE, "confirmed",
         "File saved as UTF-8",
         "The game reads Windows-1252. A UTF-8 file's accented letters become two "
         "characters each in game - `Göring` shows as `GÃ¶ring`. Re-save the file as "
         "Windows-1252."),
    Rule("BV008", "byte-order-mark", ERROR, CODE, "inferred",
         "File starts with a UTF-8 byte order mark",
         "The three invisible bytes become part of the first key, so the first event or "
         "decision in the file is not recognised."),
    Rule("BV009", "undefined-byte", WARNING, CODE, "confirmed",
         "Byte with no Windows-1252 character",
         "One of the five bytes Windows-1252 leaves undefined. Usually the remains of a "
         "UTF-8 character after a bad conversion."),
    Rule("BV010", "mixed-block", WARNING, CODE, "inferred",
         "Bare word inside a block of keys",
         "A block is either `key = value` pairs or a plain list like `{ 0 0 1 }`. A bare "
         "word among pairs is usually a key that lost its `= value`, or a typo."),

    # --- schema --------------------------------------------------------------------------
    Rule("BV101", "unknown-key", ERROR, CODE, "confirmed",
         "Key the engine does not recognise",
         "This key is neither a trigger or effect keyword nor the name of anything the mod "
         "declares (a technology, building, unit, ideology, country, province, region). "
         "**The engine drops it silently**: the condition never fires or the effect never "
         "happens, and nothing is logged. See docs/script/README.md, \"When a key is "
         "wrong, nothing happens\"."),
    Rule("BV102", "known-bad-key", ERROR, CODE, "confirmed",
         "Key that looks right and does nothing",
         "One of the keys listed in docs/script/triggers.md, \"Keys that do not work\", or "
         "found in the mod by reversing/findings/FINDINGS-script.md. The engine drops it "
         "silently. The message says what to write instead."),
    Rule("BV103", "wrong-context", ERROR, CODE, "confirmed",
         "Keyword used where it does not belong",
         "This keyword exists, but not in this kind of block: an effect inside a condition "
         "block (`trigger`, `limit`, `allow`, `potential`), or a condition inside an "
         "effect block (`option`, `effect`). Each block is read by one loader, which drops "
         "a key from the other."),
    Rule("BV104", "misplaced-key", ERROR, CODE, "inferred",
         "Key not allowed directly in this block",
         "An event, option or decision accepts a fixed set of keys at its own level. A "
         "script key directly in an event, outside any `option` or `trigger`, usually means "
         "an `option = {` or `trigger = {` line has been lost."),
    Rule("BV105", "value-type", WARNING, CODE, "inferred",
         "Value of the wrong kind",
         "The keyword's syntax in docs/script asks for a different kind of value - yes/no, "
         "a number, a country tag, a province id or a block."),
    Rule("BV106", "duplicate-key", WARNING, CODE, "inferred",
         "Key given twice where only one is kept",
         "Keys like `id`, `title` or `desc` are read once; which of two the loader keeps is "
         "not something to rely on."),
    Rule("BV107", "event-without-option", WARNING, CODE, "inferred",
         "Event with no option",
         "Every event needs at least one `option`."),
    Rule("BV108", "event-without-trigger", WARNING, CODE, "inferred",
         "Event that can never fire",
         "An event that is not `is_triggered_only = yes` needs a `trigger` block saying "
         "when it may fire."),
    # BV109 is retired. It flagged `not` with several conditions and no `and`, after the
    # docs' advice; but `CNotTrigger::Evaluate` is a NOR - false at the first true child
    # (reversing/findings/FINDINGS-triggereval.md) - so `not = { a b }` already means
    # "neither", and adding the `and` would change it to "not both".
    Rule("BV110", "does-nothing", WARNING, CODE, "confirmed",
         "Keyword that does nothing",
         "The engine accepts this keyword but it has no effect - see its entry in "
         "docs/script."),
    Rule("BV111", "unknown-field", WARNING, CODE, "inferred",
         "Unexpected field inside a keyword's block",
         "Blocks like `add_country_modifier`, `relation` or `set_variable` take named "
         "fields. This field is not one the mod uses anywhere else in that block."),
    Rule("BV112", "unknown-top-level", ERROR, CODE, "inferred",
         "Unrecognised entry at the top of the file",
         "An event file holds `country_event` and `province_event` blocks, and a decision "
         "file holds decision categories. Anything else at the top is ignored."),
    Rule("BV113", "missing-equals", ERROR, CODE, "confirmed",
         "Bare word in a script block",
         "Everything inside an event, option, decision or condition block is `key = value`. "
         "A bare word - most often `factor 100` with its `=` left out - is not read as "
         "anything."),

    # --- references ----------------------------------------------------------------------
    Rule("BV201", "undefined-event", ERROR, REFERENCES, "confirmed",
         "Event fired that does not exist",
         "`country_event` or `province_event` names an id no event in `events/` has."),
    Rule("BV202", "duplicate-event-id", ERROR, REFERENCES, "confirmed",
         "Event id used twice",
         "Two events share an id, so one of them can never be fired by it."),
    Rule("BV203", "missing-oob", ERROR, REFERENCES, "confirmed",
         "Order of battle file not found",
         "`load_oob` names a file that is not in `history/units/`."),
    Rule("BV204", "unknown-tag", ERROR, REFERENCES, "confirmed",
         "Country tag that does not exist",
         "The tag is not declared in `common/countries.txt`."),
    Rule("BV205", "unknown-province", ERROR, REFERENCES, "confirmed",
         "Province id that does not exist",
         "The number is not a province in `map/definition.csv`."),
    Rule("BV206", "missing-localisation", WARNING, REFERENCES, "inferred",
         "Localisation key with no text",
         "This looks like a localisation key, and no `.csv` in `localisation/` defines it, "
         "so the player sees the key itself."),
    Rule("BV207", "unknown-modifier", ERROR, REFERENCES, "confirmed",
         "Modifier that does not exist",
         "The modifier is not declared in `common/event_modifiers.txt`."),
    Rule("BV208", "flag-never-set", WARNING, REFERENCES, "inferred",
         "Flag tested but never set",
         "No event, decision, history file or Lua script sets this flag, so the test is "
         "always false (or always true under `not`). Often a typo in one of the two names."),
    Rule("BV209", "flag-never-tested", INFO, REFERENCES, "inferred",
         "Flag set but never tested",
         "Nothing in events, decisions or Lua tests this flag. Harmless, but often the other "
         "half of a typo."),
    Rule("BV210", "missing-flag-image", ERROR, REFERENCES, "confirmed",
         "Country without a flag image",
         "A tag with no `gfx/flags/<TAG>.tga` stops the game at \"Processing Flags\"."),
    Rule("BV211", "unknown-name-value", WARNING, REFERENCES, "inferred",
         "Value names something that does not exist",
         "The keyword expects a name of a particular kind - an ideology, a government, a "
         "region, a building, a strategic resource - and this one is not declared."),
]

RULES = {rule.id: rule for rule in _RULES}
