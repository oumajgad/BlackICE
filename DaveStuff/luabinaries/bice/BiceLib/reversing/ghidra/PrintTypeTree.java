// Censuses the data type category tree: where every structure, union, enum and typedef
// actually lives, and which of them this folder's apply script is responsible for.
//
// Headless:
//   analyzeHeadless <project dir> <name> -process hoi3_tfh.exe -noanalysis \
//       -scriptPath <this folder> -postScript PrintTypeTree.java [--all]
//
// Written 2026-10-06 because the type tree in the GUI is chaotic and nobody had measured
// *how*. ApplyBiceLibFindings creates a new structure in `/BiceLib` and sets a vftable
// definition's category to `/BiceLib/vftables`, but it finds an existing type by name
// **wherever it already lives** and then edits it in place - so any type Ghidra's own RTTI,
// demangler or decompiler passes created first keeps Ghidra's location for ever. This
// prints the resulting distribution so the scale of each case is a number rather than an
// impression.
//
// Per category: how many types, how many carry our marker, and a sample. Then a summary
// that buckets the categories by the pattern that produced them.
//@category C++

import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.Category;
import ghidra.program.model.data.CategoryPath;
import ghidra.program.model.data.DataType;
import ghidra.program.model.data.DataTypeManager;
import ghidra.program.model.data.Enum;
import ghidra.program.model.data.Structure;
import ghidra.program.model.data.TypeDef;
import ghidra.program.model.data.Union;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class PrintTypeTree extends GhidraScript {

	// The marker ApplyBiceLibFindings writes into every comment it owns.
	private static final String MARKER = "(BiceLib)";

	private static class Bucket {
		int types, structs, enums, unions, typedefs, ours, vftableNamed;
		List<String> sample = new ArrayList<>();
	}

	@Override
	public void run() throws Exception {
		boolean all = false, dump = false;
		for (String a : getScriptArgs()) {
			all |= "--all".equals(a);
			dump |= "--dump".equals(a);
		}
		if (dump) {
			// name<TAB>kind<TAB>category, for joining against bicelib_findings.json offline.
			// Ownership cannot be read off the type itself: the apply's marker goes into field
			// comments, not into a type's description, so the only honest way to ask "is this
			// one ours" is to join on the generated record's own list of names.
			DataTypeManager m = currentProgram.getDataTypeManager();
			java.util.Iterator<DataType> i2 = m.getAllDataTypes();
			while (i2.hasNext()) {
				DataType dt = i2.next();
				String kind = dt instanceof Structure ? "struct"
					: dt instanceof Enum ? "enum"
						: dt instanceof Union ? "union"
							: dt instanceof TypeDef ? "typedef" : "other";
				println("DUMP\t" + dt.getName() + "\t" + kind + "\t"
					+ (dt.getCategoryPath() == null ? "" : dt.getCategoryPath().getPath()));
			}
			return;
		}
		DataTypeManager dtm = currentProgram.getDataTypeManager();
		Map<String, Bucket> byCategory = new LinkedHashMap<>();

		java.util.Iterator<DataType> it = dtm.getAllDataTypes();
		while (it.hasNext()) {
			DataType dt = it.next();
			CategoryPath path = dt.getCategoryPath();
			String key = path == null ? "(null)" : path.getPath();
			Bucket b = byCategory.computeIfAbsent(key, k -> new Bucket());
			b.types++;
			if (dt instanceof Structure) {
				b.structs++;
			}
			else if (dt instanceof Enum) {
				b.enums++;
			}
			else if (dt instanceof Union) {
				b.unions++;
			}
			else if (dt instanceof TypeDef) {
				b.typedefs++;
			}
			String desc = String.valueOf(dt.getDescription());
			if (desc.contains(MARKER)) {
				b.ours++;
			}
			if (dt.getName().contains("vftable") || dt.getName().contains("vtable")) {
				b.vftableNamed++;
			}
			if (b.sample.size() < 4) {
				b.sample.add(dt.getName());
			}
		}

		List<Map.Entry<String, Bucket>> rows = new ArrayList<>(byCategory.entrySet());
		rows.sort(Comparator.comparingInt((Map.Entry<String, Bucket> e) -> -e.getValue().types));

		println("== category census: " + byCategory.size() + " categories, "
			+ dtm.getDataTypeCount(true) + " types");
		println(String.format("%-46s %6s %6s %6s %6s %6s %6s", "category", "types",
			"struct", "enum", "tdef", "ours", "vft"));
		int shown = 0;
		for (Map.Entry<String, Bucket> e : rows) {
			Bucket b = e.getValue();
			if (!all && b.types < 3 && shown > 40) {
				continue;
			}
			shown++;
			println(String.format("%-46s %6d %6d %6d %6d %6d %6d",
				e.getKey().length() > 46 ? "..." + e.getKey().substring(e.getKey().length() - 43)
					: e.getKey(),
				b.types, b.structs, b.enums, b.typedefs, b.ours, b.vftableNamed));
		}
		if (!all && shown < rows.size()) {
			println("   ... and " + (rows.size() - shown) + " more categories (--all to list)");
		}

		// --- the patterns, counted
		int rootTypes = 0, rootOurs = 0, biceTypes = 0, biceOurs = 0, vftCat = 0;
		int anonCats = 0, anonTypes = 0, mangledCats = 0, mangledTypes = 0;
		int demangler = 0, demanglerTypes = 0, strayVft = 0;
		for (Map.Entry<String, Bucket> e : rows) {
			String p = e.getKey();
			Bucket b = e.getValue();
			if ("/".equals(p)) {
				rootTypes += b.types;
				rootOurs += b.ours;
			}
			else if ("/BiceLib".equals(p)) {
				biceTypes += b.types;
				biceOurs += b.ours;
			}
			else if ("/BiceLib/vftables".equals(p)) {
				vftCat += b.types;
			}
			else {
				if (p.contains("_A0x") || p.contains("anon")) {
					anonCats++;
					anonTypes += b.types;
				}
				// a category whose leaf starts with a mangling letter run, e.g. `VCCountry`
				String leaf = p.substring(p.lastIndexOf('/') + 1);
				if (leaf.matches("^[A-Z]C[A-Z].*") || leaf.startsWith("__")) {
					mangledCats++;
					mangledTypes += b.types;
				}
				demangler++;
				demanglerTypes += b.types;
			}
			if (!"/BiceLib/vftables".equals(p)) {
				strayVft += b.vftableNamed;
			}
		}
		println("");
		println("== the patterns");
		println(String.format("  /                      %5d types (%d carry our marker)"
			+ "   <- Ghidra's own passes, and anything we edited in place there",
			rootTypes, rootOurs));
		println(String.format("  /BiceLib               %5d types (%d ours)"
			+ "   <- where the apply CREATES a new structure", biceTypes, biceOurs));
		println(String.format("  /BiceLib/vftables      %5d types"
			+ "                 <- where the apply puts a vftable it defines", vftCat));
		println(String.format("  other categories       %5d categories, %d types",
			demangler, demanglerTypes));
		println(String.format("    of those, _A0x/anon  %5d categories, %d types"
			+ "   <- MSVC anonymous namespaces, demangler-made", anonCats, anonTypes));
		println(String.format("    mangled-looking leaf %5d categories, %d types"
			+ "   <- e.g. VCCountry/__CMessageDialog", mangledCats, mangledTypes));
		println(String.format("  vftable-named types OUTSIDE /BiceLib/vftables: %d", strayVft));
	}
}
