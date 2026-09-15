// Runs ApplyBiceLibFindings with `overwrite`: the findings replace names, signatures and
// struct fields even where you set them by hand. Comments are kept.
//
// Its own script only because the Script Manager cannot pass a script arguments; headless,
// `-postScript ApplyBiceLibFindings.java overwrite` does the same.
//
//@author BiceLib
//@category C++
//@keybinding
//@menupath
//@toolbar

import ghidra.app.script.GhidraScript;

public class ApplyBiceLibFindingsOverwrite extends GhidraScript {

	@Override
	public void run() throws Exception {
		if (!isRunningHeadless() && !askYesNo("Overwrite your edits?",
			"The findings will replace function names, signatures and struct fields,\n" +
				"including ones you set by hand. Comments are kept.\n\nContinue?")) {
			println("Nothing changed.");
			return;
		}
		runScript("ApplyBiceLibFindings.java", new String[] { "overwrite" });
	}
}
