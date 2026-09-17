// Hands one function back to ApplyBiceLibFindings.
//
// That script never touches a name or a signature you set yourself: it keeps them and says
// so in the console. This undoes that for a single function, so the next run applies the
// findings to it again - for when the findings have since learned something your own edit
// was standing in for.
//
// Put the cursor in the function and run it, or give it an address:
//   headless: -postScript ResetBiceLibFunction.java 0x0042f210
//
// It lowers the name and signature from "you set this" to "a script set this", clears
// custom storage, and leaves everything else - the body, your comments, the data types -
// alone. Nothing else in the program is touched, which is what makes it different from
// running the Overwrite variant.
//
//@author BiceLib
//@category C++
//@keybinding
//@menupath
//@toolbar

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;

public class ResetBiceLibFunction extends GhidraScript {

	@Override
	public void run() throws Exception {
		if (currentProgram == null) {
			println("No program open.");
			return;
		}
		Address address = where();
		if (address == null) {
			println("No address: put the cursor in a function, or pass one as an argument.");
			return;
		}
		Function function = getFunctionContaining(address);
		if (function == null) {
			// Deleting the function does not take the name with it: it stays as a label, and
			// the next function made here takes it up again. So that label is what has to go.
			int removed = 0;
			for (Symbol symbol : currentProgram.getSymbolTable().getSymbols(address)) {
				if (symbol.getSource() == SourceType.USER_DEFINED) {
					println("Removing your label " + symbol.getName(true) + ", which a function made here "
						+ "would take up again.");
					symbol.delete();
					removed++;
				}
			}
			println(removed == 0 ? "No function and no label of yours at " + address + "."
				: "Run ApplyBiceLibFindings to have the function made and named again.");
			return;
		}

		Symbol symbol = function.getSymbol();
		String was = function.getName(true) + " " + function.getPrototypeString(false, false);
		boolean nameWasYours = symbol.getSource() == SourceType.USER_DEFINED;
		boolean signatureWasYours = function.getSignatureSource() == SourceType.USER_DEFINED;

		if (nameWasYours) {
			symbol.setSource(SourceType.ANALYSIS);
		}
		if (function.hasCustomVariableStorage()) {
			function.setCustomVariableStorage(false);
		}
		function.setSignatureSource(SourceType.ANALYSIS);

		println(function.getEntryPoint() + "  " + was);
		println("  name: " + (nameWasYours ? "was yours, now a script's" : "was not yours, left as it is"));
		println("  signature: " + (signatureWasYours ? "was yours, now a script's" : "was not yours, lowered anyway"));
		println("Run ApplyBiceLibFindings to have the findings applied to it again.");
	}

	/** The address given as an argument, or wherever the cursor is. */
	private Address where() {
		for (String arg : getScriptArgs()) {
			try {
				return currentProgram.getAddressFactory().getAddress(arg.replaceFirst("^0[xX]", ""));
			}
			catch (Exception ignored) {
				println("Not an address: " + arg);
			}
		}
		return currentAddress;
	}
}
