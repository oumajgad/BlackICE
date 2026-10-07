// Runs ApplyBiceLibFindings with `overwrite organise`, **three times**: the findings replace
// names, signatures and struct fields even where you set them by hand, and every type the
// findings carry is filed into its folder under /BiceLib - `classes`, `classes/containers`,
// `vftables`, `vftables/slots`, `enums`. Comments are kept.
//
// Its own script only because the Script Manager cannot pass a script arguments; headless,
// `-postScript ApplyBiceLibFindings.java overwrite organise` does the same, run three times.
//
// **Why three.** The slot sweep runs before the vftable pass, and that pass creates slot
// definitions after it, so the first run leaves a tail. Measured on a fresh copy of the
// project: the first run moves 2273 types, the second 393, the third none - and from the
// third on it is idempotent, with `struct fields: 0` and `failed: 0`. Running it once is not
// wrong, it is just not finished, and the only cost of the extra passes is time.
//
// Nothing moves whose name the findings do not carry, so what you made by hand stays where
// you put it. The SDK and CRT categories, and the demangler's own (`_A0x...` and friends),
// are left alone on purpose - `ghidra/README.md` says why.
//
//@author BiceLib
//@category C++
//@keybinding
//@menupath
//@toolbar

import ghidra.app.script.GhidraScript;

public class ApplyBiceLibFindingsOrganise extends GhidraScript {

	private static final int PASSES = 3;

	@Override
	public void run() throws Exception {
		if (!isRunningHeadless() && !askYesNo("Overwrite your edits and reorganise the types?",
			"The findings will replace function names, signatures and struct fields,\n" +
				"including ones you set by hand. Comments are kept.\n\n" +
				"Every type the findings carry is also moved into its folder under\n" +
				"/BiceLib - classes, classes/containers, vftables, vftables/slots, enums.\n" +
				"Types you created yourself are not moved, and the SDK and demangler\n" +
				"categories are left alone.\n\n" +
				"This runs the apply " + PASSES + " times, because the first pass leaves a\n" +
				"tail of slot definitions for the second to finish. Expect it to take\n" +
				"a few minutes per pass.\n\nContinue?")) {
			println("Nothing changed.");
			return;
		}
		for (int pass = 1; pass <= PASSES; pass++) {
			println("=== organise pass " + pass + " of " + PASSES + " ===");
			runScript("ApplyBiceLibFindings.java", new String[] { "overwrite", "organise" });
			monitor.checkCancelled();
		}
		println("Done. The last pass should read 'struct fields: 0, moved: 0, failed: 0' -");
		println("if it does not, run this once more and read the '!' lines.");
	}
}
