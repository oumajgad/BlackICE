// Applies what BiceLib's reversing has worked out about hoi3_tfh.exe: the C++ functions
// behind the Lua API, with their signatures, and the functions, globals, hook sites and
// class layouts recorded across the rest of the project.
//
// The data is bicelib_findings.json, next to this script, built by buildFindings.py. The
// Lua half of it is recovered from the executable itself by luabindExtract.py - see that
// file for how - so every name there is tied to an address the registration code proves.
//
// Run it after ReconstructClassesFromRtti, so the class namespaces already exist; it
// creates any that are missing the same way that script does.
//
// Safe to re-run, and by default it defers to you:
//   - a name or signature you set by hand is never replaced; the finding is added as a
//     secondary label and reported instead
//   - a name another script gave is only replaced when it is a placeholder (FUN_..., the
//     vf_NN names ReconstructClassesFromRtti gives virtual functions)
//   - struct fields are only placed where the structure is still undefined
//
// Pass the argument `overwrite` to have the findings win instead: every name and signature
// they cover is replaced, whoever set it, conflicting struct fields are cleared to make
// room, and existing enums of the same name take the recorded values. Comments are still
// never removed - the script only ever replaces its own [BiceLib] text. In the GUI, where
// a script cannot be given arguments, run ApplyBiceLibFindingsOverwrite instead; headless,
// `-postScript ApplyBiceLibFindings.java overwrite`.
//
// Addresses are image-base relative, so this still works if the program is rebased.
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
import java.util.regex.Pattern;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.listing.Function.FunctionUpdateType;
import ghidra.program.model.symbol.Namespace;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolTable;
import ghidra.program.model.symbol.SymbolType;

public class ApplyBiceLibFindings extends GhidraScript {

	private static final String DATA_FILE = "bicelib_findings.json";

	/** Where structures and enums that belong to no class namespace are created. */
	private static final CategoryPath CATEGORY = new CategoryPath("/BiceLib");

	/**
	 * Where this script's text starts and ends in a comment, so a re-run replaces exactly
	 * that and keeps whatever else is written around it.
	 */
	private static final String MARKER = "[BiceLib]";
	private static final String END_MARKER = "[/BiceLib]";

	/** Names that carry no information, and may be replaced by a real one. */
	private static final Pattern PLACEHOLDER = Pattern.compile(
		"^(FUN_|thunk_FUN_|LAB_|SUB_|vf[0-9a-f]*_\\d+$).*");

	/** Whether the findings replace what is already there, whoever put it there. */
	private boolean overwrite;

	/** Struct fields this run has placed, so overwriting never clears one of its own. */
	private final Set<String> placedThisRun = new HashSet<>();

	private DataTypeManager dtm;
	private SymbolTable symbols;
	private Address base;

	private int named, labelled, signatures, fields, kept, failed;
	private final List<String> notes = new ArrayList<>();

	@Override
	public void run() throws Exception {
		if (currentProgram == null) {
			println("No program open.");
			return;
		}
		File data = new File(getSourceFile().getParentFile().getFile(false), DATA_FILE);
		if (!data.isFile()) {
			data = askFile("Where is " + DATA_FILE + "?", "Use");
		}
		JsonObject root;
		try (Reader reader = new FileReader(data)) {
			root = JsonParser.parseReader(reader).getAsJsonObject();
		}

		for (String arg : getScriptArgs()) {
			if (arg.replaceFirst("^-+", "").equalsIgnoreCase("overwrite")) {
				overwrite = true;
			}
		}

		dtm = currentProgram.getDataTypeManager();
		symbols = currentProgram.getSymbolTable();
		base = currentProgram.getImageBase();
		println("Image base " + base + ", data " + data);
		println(overwrite ? "Overwriting: the findings replace names, signatures and fields, including yours."
			: "Keeping your edits: pass 'overwrite' to have the findings replace them.");

		// Types first, so the signatures and fields below can refer to them.
		for (JsonElement e : array(root, "enums")) {
			monitor.checkCancelled();
			applyEnum(e.getAsJsonObject());
		}
		for (JsonElement e : array(root, "structs")) {
			monitor.checkCancelled();
			structFor(e.getAsJsonObject().get("name").getAsString(), true);
		}
		for (JsonElement e : array(root, "structs")) {
			monitor.checkCancelled();
			applyStruct(e.getAsJsonObject());
		}
		for (JsonElement e : array(root, "functions")) {
			monitor.checkCancelled();
			try {
				applyFunction(e.getAsJsonObject());
			}
			catch (Exception ex) {
				failed++;
				notes.add("! " + describe(e.getAsJsonObject()) + ": " + ex.getMessage());
			}
		}
		for (JsonElement e : array(root, "labels")) {
			monitor.checkCancelled();
			try {
				applyLabel(e.getAsJsonObject());
			}
			catch (Exception ex) {
				failed++;
				notes.add("! " + describe(e.getAsJsonObject()) + ": " + ex.getMessage());
			}
		}

		println("");
		for (String note : notes) {
			println("  " + note);
		}
		println("");
		println(String.format("functions named: %d, labels: %d, signatures: %d, struct fields: %d, " +
			"%s: %d, failed: %d", named, labelled, signatures, fields,
			overwrite ? "replaced" : "left as you had them", kept, failed));
	}

	// ---- functions --------------------------------------------------------------------

	private void applyFunction(JsonObject item) throws Exception {
		Address address = base.add(item.get("rva").getAsLong());
		String name = item.get("name").getAsString();
		Namespace namespace = namespaceFor(string(item, "namespace"));
		String confidence = string(item, "confidence");

		if (!currentProgram.getMemory().contains(address)) {
			failed++;
			notes.add("! " + address + " " + name + ": not in the program's memory");
			return;
		}

		Function function = getFunctionAt(address);
		if (function == null) {
			Function containing = getFunctionContaining(address);
			if (containing != null) {
				// A finding at a proven entry point that lands inside an existing function
				// means that function's boundaries are wrong, not the finding. Say so rather
				// than guess which to trust.
				failed++;
				notes.add("! " + address + " " + name + ": inside " + containing.getName(true) +
					" (entry " + containing.getEntryPoint() + ") - boundaries need a look");
				return;
			}
			disassemble(address);
			function = createFunction(address, null);
		}
		if (function == null) {
			failed++;
			notes.add("! " + address + " " + name + ": could not create a function");
			return;
		}

		Symbol symbol = function.getSymbol();
		boolean ours = symbol.getSource() == SourceType.DEFAULT
			|| PLACEHOLDER.matcher(function.getName()).matches()
			|| (function.getName().equals(name) && function.getParentNamespace().equals(namespace))
			|| hasOurComment(address);
		if (overwrite || (ours && symbol.getSource() != SourceType.USER_DEFINED)) {
			String previous = function.getName(true);
			boolean renamed = !function.getParentNamespace().equals(namespace)
				|| !function.getName().equals(name);
			if (!function.getParentNamespace().equals(namespace)) {
				function.setParentNamespace(namespace);
			}
			if (!function.getName().equals(name)) {
				// A label of this name here is the same finding, added while the name was kept;
				// Ghidra will not have two symbols of one name at one address.
				for (Symbol other : symbols.getSymbols(address)) {
					if (!other.isPrimary() && other.getSymbolType() == SymbolType.LABEL
						&& other.getName().equals(name)) {
						other.delete();
					}
				}
				function.setName(name, SourceType.ANALYSIS);
			}
			named++;
			if (renamed && !ours) {
				kept++;
				notes.add(address + " replaced '" + previous + "' with " + qualified(namespace, name));
			}
		}
		else {
			addLabel(address, name, namespace);
			kept++;
			notes.add(address + " kept '" + function.getName(true) + "', added label " +
				qualified(namespace, name));
		}

		for (JsonElement e : array(item, "labels")) {
			JsonObject label = e.getAsJsonObject();
			addLabel(address, label.get("name").getAsString(), namespaceFor(string(label, "namespace")));
		}

		setOurPlate(address, qualified(namespace, name) + "  " + MARKER + " " + confidence + "\n" +
			string(item, "evidence"));

		if (item.has("signature") && !item.get("signature").isJsonNull()) {
			applySignature(function, item.getAsJsonObject("signature"));
		}
	}

	private void applySignature(Function function, JsonObject sig) throws Exception {
		if (function.getSignatureSource() == SourceType.USER_DEFINED) {
			kept++;
			if (!overwrite) {
				notes.add(function.getEntryPoint() + " kept your signature for " + function.getName(true));
				return;
			}
			notes.add(function.getEntryPoint() + " replaced your signature for " + function.getName(true));
		}
		String convention = sig.get("convention").getAsString();
		boolean hiddenReturn = sig.has("hiddenReturn") && sig.get("hiddenReturn").getAsBoolean();
		DataType returned = resolve(sig.get("return").getAsString());

		if (!sig.has("params") || sig.get("params").isJsonNull()) {
			// The parameters could not all be typed with a known size. Setting only some of
			// them would move the ones after onto the wrong stack slots, so none are set,
			// and neither is a return that needs a hidden parameter to go with it.
			function.setCallingConvention(convention);
			if (!hiddenReturn) {
				function.setReturnType(returned, SourceType.ANALYSIS);
			}
			signatures++;
			return;
		}

		List<Variable> params = new ArrayList<>();
		if (hiddenReturn) {
			// A class returned by value comes back through a pointer the caller passes as the
			// first stack argument, and eax holds that pointer on return. Written out as it is
			// in the machine code, because Ghidra would place a four byte struct in eax.
			//
			// Not named __return_storage_ptr__: Ghidra reserves that for its own automatic
			// parameter, drops one passed in under that name, and puts the struct back in eax.
			returned = new PointerDataType(returned, dtm);
			params.add(new ParameterImpl("result", returned, currentProgram));
		}
		int n = 1;
		for (JsonElement e : sig.getAsJsonArray("params")) {
			JsonObject p = e.getAsJsonObject();
			String pname = p.has("name") && !p.get("name").isJsonNull() ? p.get("name").getAsString()
				: "arg" + n;
			params.add(new ParameterImpl(pname, resolve(p.get("type").getAsString()), currentProgram));
			n++;
		}
		function.updateFunction(convention, new ReturnParameterImpl(returned, currentProgram), params,
			FunctionUpdateType.DYNAMIC_STORAGE_ALL_PARAMS, true, SourceType.ANALYSIS);
		signatures++;
	}

	// ---- labels ------------------------------------------------------------------------

	private void applyLabel(JsonObject item) throws Exception {
		Address address = base.add(item.get("rva").getAsLong());
		String name = item.get("name").getAsString();
		Namespace namespace = namespaceFor(string(item, "namespace"));
		if (!currentProgram.getMemory().contains(address)) {
			failed++;
			notes.add("! " + address + " " + name + ": not in the program's memory");
			return;
		}
		Symbol primary = symbols.getPrimarySymbol(address);
		Symbol label = addLabel(address, name, namespace);
		if (label != null && (overwrite || primary == null || primary.getSource() == SourceType.DEFAULT)) {
			label.setPrimary();
		}
		String text = qualified(namespace, name) + "  " + MARKER + " " + string(item, "confidence") +
			"\n" + string(item, "evidence");
		if ("instruction".equals(string(item, "kind"))) {
			setPreComment(address, withOurBlock(getPreComment(address), text));
		}
		else {
			setOurPlate(address, text);
		}
		if (item.has("type") && !item.get("type").isJsonNull()) {
			applyDataType(address, name, item.get("type").getAsString());
		}
		labelled++;
	}

	/**
	 * Gives a global its type, so the decompiler reads through it: a global typed
	 * `CCountryDataBase*` shows `g_CCountryDataBase->countries_first`, where an untyped one
	 * only ever shows an offset. "string" means a terminated C string.
	 */
	private void applyDataType(Address address, String name, String typeText) throws Exception {
		DataType type = "string".equals(typeText) ? TerminatedStringDataType.dataType : resolve(typeText);
		Data existing = getDataAt(address);
		boolean undefinedHere = existing == null || !existing.isDefined()
			|| Undefined.isUndefined(existing.getDataType());
		if (!undefinedHere) {
			if (existing.getDataType().isEquivalent(type)) {
				return;                                         // typed by an earlier run
			}
			if (!overwrite) {
				kept++;
				notes.add(address + " kept the type " + existing.getDataType().getName() + " on " + name +
					" (would have been " + type.getName() + ")");
				return;
			}
			kept++;
			notes.add(address + " replaced the type " + existing.getDataType().getName() + " on " + name +
				" with " + type.getName());
		}
		try {
			DataUtilities.createData(currentProgram, address, type, -1,
				overwrite ? DataUtilities.ClearDataMode.CLEAR_ALL_CONFLICT_DATA
					: DataUtilities.ClearDataMode.CLEAR_ALL_UNDEFINED_CONFLICT_DATA);
		}
		catch (Exception ex) {
			failed++;
			notes.add("! " + address + " " + name + ": could not type as " + type.getName() + ": " + ex.getMessage());
		}
	}

	private Symbol addLabel(Address address, String name, Namespace namespace) throws Exception {
		for (Symbol s : symbols.getSymbols(address)) {
			if (s.getName().equals(name) && s.getParentNamespace().equals(namespace)) {
				return s;
			}
		}
		return symbols.createLabel(address, name, namespace, SourceType.ANALYSIS);
	}

	// ---- types -------------------------------------------------------------------------

	private void applyEnum(JsonObject item) {
		String name = sanitizeType(item.get("name").getAsString());
		DataType existing = findType(name);
		if (existing != null && !(overwrite && existing instanceof ghidra.program.model.data.Enum)) {
			return;
		}
		EnumDataType e = new EnumDataType(CATEGORY, name, item.has("size") ? item.get("size").getAsInt() : 4, dtm);
		for (JsonElement v : array(item, "values")) {
			JsonObject value = v.getAsJsonObject();
			e.add(value.get("name").getAsString(), value.get("value").getAsLong());
		}
		if (item.has("comment")) {
			e.setDescription(item.get("comment").getAsString());
		}
		if (existing != null) {
			existing.replaceWith(e);                         // overwriting: same enum, recorded values
			return;
		}
		dtm.addDataType(e, DataTypeConflictHandler.KEEP_HANDLER);
	}

	private void applyStruct(JsonObject item) {
		String name = item.get("name").getAsString();
		Structure struct = structFor(name, true);
		if (item.has("size") && !item.get("size").isJsonNull()) {
			int size = item.get("size").getAsInt();
			if (struct.isNotYetDefined() || struct.getLength() < size) {
				struct.growStructure(size - (struct.isNotYetDefined() ? 0 : struct.getLength()));
			}
		}
		for (JsonElement e : array(item, "fields")) {
			JsonObject field = e.getAsJsonObject();
			int offset = field.get("offset").getAsInt();
			String fname = field.get("name").getAsString();
			String comment = string(field, "comment");
			DataType type = resolve(field.get("type").getAsString());
			int length = type.getLength();
			if (length <= 0 || (type instanceof Structure s && s.isNotYetDefined())) {
				// A class whose size is not known: name the offset, and leave the extent open.
				comment = field.get("type").getAsString() + " (size unknown). " + comment;
				type = Undefined1DataType.dataType;
				length = 1;
			}
			if (struct.isNotYetDefined() || struct.getLength() < offset + length) {
				struct.growStructure(offset + length - (struct.isNotYetDefined() ? 0 : struct.getLength()));
			}
			DataTypeComponent existing = struct.getDefinedComponentAtOrAfterOffset(offset);
			if (existing != null && existing.getOffset() == offset && fname.equals(existing.getFieldName())) {
				continue;                                   // placed by an earlier run
			}
			List<DataTypeComponent> blocking = blockers(struct, offset, length);
			if (!blocking.isEmpty()) {
				DataTypeComponent first = blocking.get(0);
				String what = first.getFieldName() == null ? first.getDataType().getName() : first.getFieldName();
				boolean ownField = false;
				for (DataTypeComponent c : blocking) {
					ownField |= placedThisRun.contains(struct.getName() + "@" + c.getOffset());
				}
				if (!overwrite || ownField) {
					kept++;
					notes.add(struct.getName() + "+0x" + Integer.toHexString(offset) + " holds '" + what +
						"', not placing " + fname + (ownField ? " (a field this run placed)" : ""));
					continue;
				}
				for (DataTypeComponent c : blocking) {
					struct.clearAtOffset(c.getOffset());
				}
				kept++;
				notes.add(struct.getName() + "+0x" + Integer.toHexString(offset) + " replaced '" + what +
					"' with " + fname);
			}
			try {
				struct.replaceAtOffset(offset, type, length, fname, comment);
				placedThisRun.add(struct.getName() + "@" + offset);
				fields++;
			}
			catch (IllegalArgumentException ex) {
				failed++;
				notes.add("! " + struct.getName() + "+0x" + Integer.toHexString(offset) + " " + fname + ": " +
					ex.getMessage());
			}
		}
	}

	/** The defined components that overlap [offset, offset + length). */
	private static List<DataTypeComponent> blockers(Structure struct, int offset, int length) {
		List<DataTypeComponent> out = new ArrayList<>();
		DataTypeComponent inside = struct.getComponentContaining(offset);
		if (inside != null && inside.getOffset() < offset && isDefined(inside)) {
			out.add(inside);
		}
		for (DataTypeComponent c : struct.getDefinedComponents()) {
			if (c.getOffset() >= offset && c.getOffset() < offset + length && isDefined(c)) {
				out.add(c);
			}
		}
		return out;
	}

	/** Holds something: a type, or at least a name - a field of unknown size is a named undefined1. */
	private static boolean isDefined(DataTypeComponent c) {
		return c.getFieldName() != null
			|| (c.getDataType() != DataType.DEFAULT && !(c.getDataType() instanceof Undefined));
	}

	/**
	 * The structure for a class: the one Ghidra ties to the class namespace when one
	 * exists, so it becomes the type of `this`; otherwise one in /BiceLib.
	 */
	private Structure structFor(String cppName, boolean create) {
		String name = sanitizeType(cppName);
		Namespace ns = existingNamespace(cppName);
		if (ns instanceof GhidraClass cls) {
			return VariableUtilities.findOrCreateClassStruct(cls, dtm);
		}
		DataType existing = findType(name);
		if (existing instanceof Structure s) {
			return s;
		}
		if (!create) {
			return null;
		}
		return (Structure) dtm.addDataType(new StructureDataType(CATEGORY, name, 0, dtm),
			DataTypeConflictHandler.KEEP_HANDLER);
	}

	private DataType findType(String name) {
		DataType here = dtm.getDataType(CATEGORY, name);
		if (here != null) {
			return here;
		}
		List<DataType> found = new ArrayList<>();
		dtm.findDataTypes(name, found);
		for (DataType dt : found) {
			if (!(dt instanceof Pointer) && !(dt instanceof Array)) {
				return dt;
			}
		}
		return null;
	}

	/** 'CCountryTag const&' -> pointer to the CCountryTag structure, and so on. */
	private DataType resolve(String text) {
		String t = text.trim();
		java.util.regex.Matcher array = Pattern.compile("^(.*)\\[(\\d+)\\]$").matcher(t);
		if (array.matches()) {
			DataType element = resolve(array.group(1));
			int count = Integer.parseInt(array.group(2));
			return new ArrayDataType(element, count, element.getLength(), dtm);
		}
		int pointers = 0;
		while (true) {
			t = t.replaceAll("\\s+const$", "").trim();
			if (t.endsWith("&") || t.endsWith("*")) {
				pointers++;
				t = t.substring(0, t.length() - 1).trim();
			}
			else {
				break;
			}
		}
		t = t.replaceAll("^const\\s+", "").trim();
		DataType type = builtin(t);
		if (type == null) {
			type = findType(sanitizeType(t));
		}
		if (type == null) {
			type = structFor(t, true);
		}
		for (int i = 0; i < pointers; i++) {
			type = new PointerDataType(type, dtm);
		}
		return type;
	}

	private static DataType builtin(String t) {
		switch (t) {
			case "void": return VoidDataType.dataType;
			case "bool": return BooleanDataType.dataType;
			case "char": return CharDataType.dataType;
			case "signed char": return SignedCharDataType.dataType;
			case "unsigned char": return UnsignedCharDataType.dataType;
			case "short": return ShortDataType.dataType;
			case "unsigned short": return UnsignedShortDataType.dataType;
			case "int": return IntegerDataType.dataType;
			case "unsigned int": return UnsignedIntegerDataType.dataType;
			case "long": return LongDataType.dataType;
			case "unsigned long": return UnsignedLongDataType.dataType;
			case "__int64": return LongLongDataType.dataType;
			case "unsigned __int64": return UnsignedLongLongDataType.dataType;
			case "float": return FloatDataType.dataType;
			case "double": return DoubleDataType.dataType;
			case "undefined1": return Undefined1DataType.dataType;
			case "undefined4": return Undefined4DataType.dataType;
			default: return null;
		}
	}

	// ---- namespaces ----------------------------------------------------------------------

	/** Creates (or reuses) the class namespace, the way ReconstructClassesFromRtti names it. */
	private Namespace namespaceFor(String qualified) throws Exception {
		Namespace parent = currentProgram.getGlobalNamespace();
		if (qualified == null || qualified.isEmpty()) {
			return parent;
		}
		List<String> parts = splitScopes(qualified);
		for (int i = 0; i < parts.size(); i++) {
			String part = sanitize(parts.get(i));
			boolean last = i == parts.size() - 1;
			Namespace existing = symbols.getNamespace(part, parent);
			if (existing != null) {
				parent = existing;
				continue;
			}
			parent = last ? symbols.createClass(parent, part, SourceType.ANALYSIS)
				: symbols.createNameSpace(parent, part, SourceType.ANALYSIS);
		}
		return parent;
	}

	private Namespace existingNamespace(String qualified) {
		Namespace parent = currentProgram.getGlobalNamespace();
		for (String part : splitScopes(qualified)) {
			parent = symbols.getNamespace(sanitize(part), parent);
			if (parent == null) {
				return null;
			}
		}
		return parent;
	}

	/** Splits on :: outside template brackets, so CList<A::B> stays one scope. */
	private static List<String> splitScopes(String qualified) {
		List<String> parts = new ArrayList<>();
		int depth = 0, start = 0;
		for (int i = 0; i < qualified.length(); i++) {
			char c = qualified.charAt(i);
			if (c == '<') {
				depth++;
			}
			else if (c == '>') {
				depth--;
			}
			else if (depth == 0 && c == ':' && i + 1 < qualified.length() && qualified.charAt(i + 1) == ':') {
				parts.add(qualified.substring(start, i));
				start = i + 2;
				i++;
			}
		}
		parts.add(qualified.substring(start));
		return parts;
	}

	/** The same rule ReconstructClassesFromRtti applies, so the namespaces coincide. */
	private static String sanitize(String s) {
		StringBuilder sb = new StringBuilder(s.length());
		for (char ch : s.toCharArray()) {
			sb.append(Character.isLetterOrDigit(ch) || ch == '_' ? ch : '_');
		}
		String out = sb.toString();
		return out.isEmpty() ? "anon" : out;
	}

	private static String sanitizeType(String qualified) {
		List<String> parts = splitScopes(qualified);
		return sanitize(parts.get(parts.size() - 1));
	}

	// ---- comments and small helpers --------------------------------------------------------

	private boolean hasOurComment(Address address) {
		String plate = getPlateComment(address);
		return plate != null && plate.contains(MARKER);
	}

	private void setOurPlate(Address address, String text) {
		setPlateComment(address, withOurBlock(getPlateComment(address), text));
	}

	/**
	 * The comment with this script's block replaced by text, or text added below it.
	 *
	 * Everything outside the block is kept: text written above or below it by hand survives
	 * a re-run. A block from before the end marker existed runs to the end of the comment,
	 * which is where the script always put it.
	 */
	private static String withOurBlock(String comment, String text) {
		String block = text + "\n" + END_MARKER;
		if (comment == null || comment.isBlank()) {
			return block;
		}
		int marker = comment.indexOf(MARKER);
		if (marker < 0) {
			return comment + "\n\n" + block;
		}
		int start = comment.lastIndexOf('\n', marker) + 1;
		int end = comment.indexOf(END_MARKER, marker);
		String after = end < 0 ? "" : comment.substring(end + END_MARKER.length());
		return comment.substring(0, start) + block + after;
	}

	private static String qualified(Namespace ns, String name) {
		return ns.isGlobal() ? name : ns.getName(true) + "::" + name;
	}

	private static String describe(JsonObject item) {
		return (item.has("rva") ? "rva 0x" + Long.toHexString(item.get("rva").getAsLong()) + " " : "") +
			(item.has("name") ? item.get("name").getAsString() : "");
	}

	private static JsonArray array(JsonObject o, String key) {
		return o.has(key) && o.get(key).isJsonArray() ? o.getAsJsonArray(key) : new JsonArray();
	}

	private static String string(JsonObject o, String key) {
		return o.has(key) && !o.get(key).isJsonNull() ? o.get(key).getAsString() : "";
	}
}
