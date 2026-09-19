// Clears names this script put down and no longer stands behind.
//
// ApplyBiceLibFindings marks everything it names with a [BiceLib] plate comment. When the
// findings stop claiming an address - the name was wrong and has been withdrawn, or moved
// to another address - re-running does not clear it: the script only ever writes, so the
// old name and its plate sit there saying something false.
//
// This finds them: every function carrying a [BiceLib] plate whose address the findings no
// longer name. It takes the name off (so it goes back to FUN_...), lowers the signature and
// removes the script's block from the plate comment, keeping anything you wrote around it.
//
// A name you set by hand is left alone and reported, whatever its plate says.
//
//   list                  say what would be cleared and change nothing
//   0x005c0540 0x004b83d0 clear exactly these, claimed or not
//
// headless: -postScript ResetBiceLibOrphans.java list
//
//@author BiceLib
//@category C++
//@keybinding
//@menupath
//@toolbar

import java.io.File;
import java.io.FileReader;
import java.io.Reader;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;

public class ResetBiceLibOrphans extends GhidraScript {

	private static final String DATA_FILE = "bicelib_findings.json";
	private static final String MARKER = "[BiceLib]";
	private static final String END_MARKER = "[/BiceLib]";

	@Override
	public void run() throws Exception {
		if (currentProgram == null) {
			println("No program open.");
			return;
		}

		boolean listOnly = false;
		List<Address> only = new ArrayList<>();
		for (String arg : getScriptArgs()) {
			String a = arg.replaceFirst("^-+", "");
			if (a.equalsIgnoreCase("list")) {
				listOnly = true;
				continue;
			}
			try {
				only.add(currentProgram.getAddressFactory().getAddress(a.replaceFirst("^0[xX]", "")));
			}
			catch (Exception ignored) {
				println("Not an address and not 'list': " + arg);
			}
		}

		Set<Long> claimed = claimedByTheFindings();
		if (claimed == null) {
			return;
		}
		println("The findings name " + claimed.size() + " addresses.");

		List<Function> orphans = new ArrayList<>();
		if (!only.isEmpty()) {
			for (Address at : only) {
				Function f = getFunctionContaining(at);
				if (f == null) {
					println("  no function at " + at);
					continue;
				}
				orphans.add(f);
			}
		}
		else {
			FunctionIterator it = currentProgram.getFunctionManager().getFunctions(true);
			while (it.hasNext()) {
				monitor.checkCancelled();
				Function f = it.next();
				String plate = getPlateComment(f.getEntryPoint());
				if (plate == null || !plate.contains(MARKER)) {
					continue;
				}
				if (!claimed.contains(f.getEntryPoint().getOffset())) {
					orphans.add(f);
				}
			}
		}

		int cleared = 0, kept = 0;
		for (Function f : orphans) {
			Symbol symbol = f.getSymbol();
			String was = f.getName(true);
			if (symbol != null && symbol.getSource() == SourceType.USER_DEFINED) {
				println("  " + f.getEntryPoint() + "  " + was + " - yours, left as it is");
				kept++;
				continue;
			}
			if (listOnly) {
				println("  " + f.getEntryPoint() + "  " + was + " - would be cleared");
				continue;
			}
			Address at = f.getEntryPoint();
			try {
				// setName(null, DEFAULT) is what puts a function back to FUN_...; the
				// namespace has to go too, or the class keeps an empty member.
				f.setParentNamespace(currentProgram.getGlobalNamespace());
				f.setName(null, SourceType.DEFAULT);
				if (f.hasCustomVariableStorage()) {
					f.setCustomVariableStorage(false);
				}
				f.setSignatureSource(SourceType.DEFAULT);
				setPlateComment(at, withoutOurBlock(getPlateComment(at)));
				println("  " + at + "  " + was + " - cleared, now " + f.getName());
				cleared++;
			}
			catch (Exception ex) {
				println("  " + at + "  " + was + " - could not be cleared: " + ex.getMessage());
			}
		}

		println("");
		if (orphans.isEmpty()) {
			println("Nothing to clear: every [BiceLib] name in the program is one the findings still make.");
		}
		else if (listOnly) {
			println(orphans.size() + " would be cleared, " + kept + " are yours. Run it without 'list' to do it.");
		}
		else {
			println("cleared: " + cleared + ", yours and left alone: " + kept
				+ ". Run ApplyBiceLibFindings to name whatever the findings now put there.");
		}
	}

	/** Every address the findings name: functions, labels, and the globals among them. */
	private Set<Long> claimedByTheFindings() throws Exception {
		File data = new File(getSourceFile().getParentFile().getFile(false), DATA_FILE);
		if (!data.isFile()) {
			data = askFile("Where is " + DATA_FILE + "?", "Use");
		}
		JsonObject root;
		try (Reader reader = new FileReader(data)) {
			root = JsonParser.parseReader(reader).getAsJsonObject();
		}
		long base = currentProgram.getImageBase().getOffset();
		Set<Long> out = new HashSet<>();
		for (String section : new String[] { "functions", "labels" }) {
			if (!root.has(section)) {
				continue;
			}
			for (JsonElement e : root.getAsJsonArray(section)) {
				out.add(base + e.getAsJsonObject().get("rva").getAsLong());
			}
		}
		if (out.isEmpty()) {
			println("No functions or labels in " + data + " - is it the built file?");
			return null;
		}
		return out;
	}

	/** The comment with this script's block taken out, and whatever you wrote kept. */
	private static String withoutOurBlock(String comment) {
		if (comment == null) {
			return null;
		}
		int marker = comment.indexOf(MARKER);
		if (marker < 0) {
			return comment;
		}
		int end = comment.indexOf(END_MARKER, marker);
		String before = comment.substring(0, marker);
		String after = end < 0 ? "" : comment.substring(end + END_MARKER.length());
		String left = (before + after).strip();
		return left.isEmpty() ? null : left;
	}
}
