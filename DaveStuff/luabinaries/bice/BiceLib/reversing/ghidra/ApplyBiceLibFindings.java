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
// Pass `organise` to file every recorded type into its folder under /BiceLib - `classes`,
// `classes/containers`, `vftables`, `vftables/slots`, `enums` - instead of only creating a
// new one there. Added 2026-10-06, because the tree had drifted to 203 categories over 9046
// types: 266 of the 309 recorded class structures were sitting at the root, since this
// script finds an existing type wherever it already lives and Ghidra's RTTI pass gets there
// first. It moves nothing whose name the findings do not carry, and leaves the SDK/CRT
// categories and the demangler's own (`_A0x...` and friends) alone - those are recreated by
// a pass that would undo the move. The constants' comment has the whole account.
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

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.lang.Register;
import ghidra.program.model.listing.Function.FunctionUpdateType;
import ghidra.program.model.pcode.HighFunction;
import ghidra.program.model.pcode.HighFunctionDBUtil;
import ghidra.program.model.pcode.HighSymbol;
import ghidra.program.model.pcode.LocalSymbolMap;
import ghidra.program.model.pcode.Varnode;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.Equate;
import ghidra.program.model.symbol.EquateTable;
import ghidra.program.model.symbol.Namespace;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolTable;
import ghidra.program.model.symbol.SymbolType;
import ghidra.util.InvalidNameException;

public class ApplyBiceLibFindings extends GhidraScript {

	private static final String DATA_FILE = "bicelib_findings.json";

	/** Where structures and enums that belong to no class namespace are created. */
	private static final CategoryPath CATEGORY = new CategoryPath("/BiceLib");
	private static final CategoryPath VFTABLE_CATEGORY = new CategoryPath(CATEGORY, "vftables");

	/**
	 * The rest of the tree, added 2026-10-06. Measured before it was written: the project
	 * held **203 categories over 9046 types**, and the shape was not chaos so much as two
	 * tools disagreeing in silence.
	 *
	 * - `/BiceLib/vftables` held **5592 slot function definitions** and no vftable at all,
	 *   so the folder's name meant the opposite of what it said. The definitions move to
	 *   `vftables/slots` and the tables themselves take the name.
	 * - **266 of the 309 recorded class structures sat at the root** and only 42 in
	 *   `/BiceLib`, because `structFor` finds an existing type *wherever it already lives*
	 *   and then edits it in place. Ghidra's RTTI pass runs first and creates most of them
	 *   at the root, so we were adding fields to them and never moving them.
	 *
	 * Hence `organise`: the category is set on **every** run rather than only on the run
	 * that creates the type, which is the only way this survives the next analysis pass
	 * inventing a type at the root. Nothing moves unless the name is one the findings
	 * carry, so what you made by hand stays where you put it - the same courtesy the field
	 * and signature rules already give.
	 *
	 * Two kinds are deliberately left alone, and both for the same reason: the SDK and CRT
	 * categories are correct and not ours, and the demangler's own categories (`_A0x...`,
	 * `/VCCountry/__CMessageDialog` and the rest) are **recreated from mangled names by a
	 * pass that will undo any move**, so emptying them is a fight rather than a fix.
	 */
	private static final CategoryPath CLASS_CATEGORY = new CategoryPath(CATEGORY, "classes");
	private static final CategoryPath CONTAINER_CATEGORY =
		new CategoryPath(CLASS_CATEGORY, "containers");
	private static final CategoryPath SLOT_CATEGORY = new CategoryPath(VFTABLE_CATEGORY, "slots");
	private static final CategoryPath ENUM_CATEGORY = new CategoryPath(CATEGORY, "enums");

	/**
	 * `CList<CUnit*>`, `CListNode<CCountryTag>`, `CArray<int>` - generated, and numerous.
	 *
	 * **Matched after `sanitize`, not before.** Ghidra names cannot hold `<`, `>` or `*`, so
	 * every one of those becomes `_`: the type is `CList_CAir__`, never `CList<CAir*>`. The
	 * first version of this matched the C++ spelling and so matched nothing at all, and the
	 * 55 containers sat in `classes` with everything else. The trailing underscore is what
	 * keeps the plain `CList` struct - a real class, with the shared head layout - out.
	 */
	private static final Pattern CONTAINER =
		Pattern.compile("^(CList|CListNode|CArray)_[A-Za-z0-9_]*_$");

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

	/** Whether a recorded type is moved into its category, not just created there. */
	private boolean organise;

	/** Struct fields this run has placed, so overwriting never clears one of its own. */
	private final Set<String> placedThisRun = new HashSet<>();

	private DataTypeManager dtm;
	private SymbolTable symbols;
	private Address base;

	private int named, labelled, signatures, fields, kept, failed, vftables, enums,
			equates, variables, moved;
	/** made on the first function that declares locals, and only then */
	private DecompInterface decompiler;
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
			String flag = arg.replaceFirst("^-+", "");
			if (flag.equalsIgnoreCase("overwrite")) {
				overwrite = true;
			}
			else if (flag.equalsIgnoreCase("organise") || flag.equalsIgnoreCase("organize")) {
				organise = true;
			}
		}

		dtm = currentProgram.getDataTypeManager();
		symbols = currentProgram.getSymbolTable();
		base = currentProgram.getImageBase();
		println("Image base " + base + ", data " + data);
		println(overwrite ? "Overwriting: the findings replace names, signatures and fields, including yours."
			: "Keeping your edits: pass 'overwrite' to have the findings replace them.");
		println(organise
			? "Organising: every recorded type is moved into its /BiceLib folder."
			: "Leaving the type tree alone: pass 'organise' to file recorded types into /BiceLib.");

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
		// After the enums, which they name members of, and before anything else.
		for (JsonElement e : array(root, "equates")) {
			monitor.checkCancelled();
			try {
				applyEquate(e.getAsJsonObject());
			}
			catch (Exception ex) {
				failed++;
				notes.add("! equate: " + ex.getMessage());
			}
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
		// Last: a slot's type is the definition of the function filling it, so the functions
		// have to carry their signatures before these are built. The sweep goes first,
		// because `slotType` has to find a definition that already exists rather than make a
		// second copy of it in the other folder.
		sweepSlotDefinitions();
		for (JsonElement e : array(root, "vftables")) {
			monitor.checkCancelled();
			try {
				applyVftable(e.getAsJsonObject());
			}
			catch (Exception ex) {
				failed++;
				notes.add("! vftable " + e.getAsJsonObject().get("name").getAsString() + ": " + ex.getMessage());
			}
		}

		println("");
		for (String note : notes) {
			println("  " + note);
		}
		println("");
		println(String.format("functions named: %d, labels: %d, signatures: %d, struct fields: %d, " +
			"enums: %d, equates: %d, virtual tables: %d, locals: %d, moved: %d, %s: %d, failed: %d", named,
			labelled, signatures, fields, enums, equates, vftables, variables, moved,
			overwrite ? "replaced" : "left as you had them", kept, failed));
		if (decompiler != null) {
			decompiler.dispose();
			decompiler = null;
		}
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
		// After the signature: the decompiler below reads the function as it now stands, and a
		// parameter that arrives later moves the stack locals under it.
		if (item.has("locals")) {
			applyLocals(function, item.getAsJsonArray("locals"));
		}
	}

	/**
	 * Name and type the stack locals a finding declares.
	 *
	 * **Why this is not a struct field.** A local is built inside the function - here a queue
	 * of nodes from `operator new` - so no member of any class reaches it and nothing can
	 * propagate a type in. Ghidra calls it `local_30` and every use reads `*(iVar3 + 0x4c)`
	 * where the same field a line away reads `province->supply_depot_distance`, purely because
	 * one came through a typed vector and the other did not.
	 *
	 * **Typing the stack slot is enough; the register locals follow.** The value a slot is
	 * read into keeps the type across the assignment, so one line here settles a dozen reads.
	 * That is also why registers are not addressable in a finding - see parse_locals.
	 */
	private void applyLocals(Function function, JsonArray wanted) throws Exception {
		if (wanted.size() == 0) {
			return;
		}
		if (decompiler == null) {
			decompiler = new DecompInterface();
			decompiler.openProgram(currentProgram);
		}
		DecompileResults results = decompiler.decompileFunction(function, 120, monitor);
		HighFunction high = results == null ? null : results.getHighFunction();
		if (high == null) {
			failed++;
			notes.add("! " + function.getEntryPoint() + " " + function.getName() +
				": locals need the decompiler, and it did not produce a function" +
				(results == null ? "" : " (" + results.getErrorMessage() + ")"));
			return;
		}
		LocalSymbolMap locals = high.getLocalSymbolMap();

		for (JsonElement e : wanted) {
			JsonObject want = e.getAsJsonObject();
			int at = want.get("at").getAsInt();
			String name = want.get("name").getAsString();
			DataType type = resolve(want.get("type").getAsString());
			String where = function.getEntryPoint() + " " + function.getName() + " stack:" +
				(at < 0 ? "-0x" + Integer.toHexString(-at) : "0x" + Integer.toHexString(at));

			// Yours wins, the way a name or a signature does. A stack variable already in the
			// database is the only thing that can carry a source, so a slot the decompiler has
			// merely invented has none and is ours to take.
			Variable existing = null;
			for (Variable v : function.getLocalVariables()) {
				if (v.isStackVariable() && v.getStackOffset() == at) {
					existing = v;
					break;
				}
			}
			if (existing != null && existing.getSource() == SourceType.USER_DEFINED && !overwrite) {
				kept++;
				notes.add(where + " kept your '" + existing.getName() + "'");
				continue;
			}

			HighSymbol symbol = null;
			for (java.util.Iterator<HighSymbol> it = locals.getSymbols(); it.hasNext();) {
				HighSymbol candidate = it.next();
				VariableStorage storage = candidate.getStorage();
				if (storage != null && storage.isStackStorage() && storage.getStackOffset() == at) {
					symbol = candidate;
					break;
				}
			}
			if (symbol == null) {
				// Not a failure to shout about on its own, but it does mean the finding is
				// describing a slot this function has not got - most often the [ebp-N] from the
				// disassembly rather than Ghidra's own offset, which is four lower.
				failed++;
				notes.add("! " + where + " " + name + ": no local there" +
					" (Ghidra's offset, the number in its local_NN, is four below the [ebp-N])");
				continue;
			}

			DataType had = symbol.getDataType();
			if (name.equals(symbol.getName()) && had != null && had.isEquivalent(type)) {
				continue;                       // already so; a settled run reports none
			}
			if (existing != null && existing.getSource() == SourceType.USER_DEFINED) {
				notes.add(where + " replaced your '" + existing.getName() + "'");
			}
			HighFunctionDBUtil.updateDBVariable(symbol, name, type, SourceType.ANALYSIS);
			variables++;
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
		// Where a finding says which register or stack slot each argument arrives in, that is
		// laid out exactly: the compiler gives a function it keeps to itself whatever
		// convention suits it, and Ghidra reading such a call as a standard one puts the
		// wrong values in the arguments.
		boolean custom = false;
		int n = 1;
		for (JsonElement e : sig.getAsJsonArray("params")) {
			JsonObject p = e.getAsJsonObject();
			String pname = p.has("name") && !p.get("name").isJsonNull() ? p.get("name").getAsString()
				: "arg" + n;
			DataType type = resolve(p.get("type").getAsString());
			String where = string(p, "storage");
			if (where.isEmpty()) {
				params.add(new ParameterImpl(pname, type, currentProgram));
			}
			else {
				custom = true;
				params.add(new ParameterImpl(pname, type, storageFor(where, type), currentProgram));
			}
			n++;
		}
		if (!custom) {
			function.updateFunction(convention, new ReturnParameterImpl(returned, currentProgram), params,
				FunctionUpdateType.DYNAMIC_STORAGE_ALL_PARAMS, true, SourceType.ANALYSIS);
			signatures++;
			return;
		}
		String returnedIn = string(sig, "returnStorage");
		ReturnParameterImpl ret = returnedIn.isEmpty()
			? new ReturnParameterImpl(returned, currentProgram)
			: new ReturnParameterImpl(returned, storageFor(returnedIn, returned), currentProgram);
		function.setCustomVariableStorage(true);
		function.updateFunction(convention, ret, params,
			FunctionUpdateType.CUSTOM_STORAGE, true, SourceType.ANALYSIS);
		signatures++;
	}

	/** "ESI" or "stack:4" as somewhere an argument of this type is passed. */
	private VariableStorage storageFor(String where, DataType type) throws Exception {
		if (where.toLowerCase().startsWith("stack:")) {
			int offset = Integer.decode(where.substring("stack:".length()).trim());
			return new VariableStorage(currentProgram, new Varnode(
				currentProgram.getAddressFactory().getStackSpace().getAddress(offset), type.getLength()));
		}
		Register register = currentProgram.getRegister(where.trim());
		if (register == null) {
			throw new IllegalArgumentException("no register " + where);
		}
		return new VariableStorage(currentProgram, register);
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

	/**
	 * An enum has no room for a marker on each member, so the marker goes in its description
	 * and the category it sits in says whose it is: one this script made lives under
	 * /BiceLib and is its own to rewrite, which is what lets a rebuild add members to an
	 * enum already in the program. One of yours, anywhere else, it leaves and says so.
	 */
	/**
	 * Shows one constant as the enum member it is.
	 *
	 * Typing a field as an enum only reaches a comparison the decompiler can see *is* that
	 * field. Where the pointer was walked out of an untyped container - which is most of
	 * this game's loaders - nothing connects the two, and the constant stays a number
	 * however well the structure is typed. CBuildingDataBase's role ladder compares
	 * `[esi+0x24]` against five modifier ids that way.
	 *
	 * An equate binds the constant at one instruction to one member, with no type
	 * inference in between, which is what it is for.
	 */
	private void applyEquate(JsonObject item) throws Exception {
		Address address = base.add(item.get("rva").getAsLong());
		String enumName = item.get("enum").getAsString();
		int operand = item.has("operand") ? item.get("operand").getAsInt() : 1;

		Instruction instruction = getInstructionAt(address);
		if (instruction == null) {
			failed++;
			notes.add("! " + address + " equate: no instruction there");
			return;
		}
		Scalar scalar = instruction.getScalar(operand);
		if (scalar == null) {
			failed++;
			notes.add("! " + address + " equate: operand " + operand + " is not a constant");
			return;
		}
		// Through findType, not a fixed category: `organise` files enums under
		// /BiceLib/enums, and looking only in /BiceLib made every equate fail with
		// "no enum called ModifierId" the first time the flag was used.
		DataType type = findType(enumName);
		if (!(type instanceof ghidra.program.model.data.Enum)) {
			failed++;
			notes.add("! " + address + " equate: no enum called " + enumName);
			return;
		}
		ghidra.program.model.data.Enum values = (ghidra.program.model.data.Enum) type;
		long value = scalar.getUnsignedValue();
		String member = values.getName(value);
		if (member == null) {
			failed++;
			notes.add("! " + address + " equate: " + enumName + " has no member for 0x"
				+ Long.toHexString(value));
			return;
		}

		EquateTable table = currentProgram.getEquateTable();
		Equate equate = table.getEquate(member);
		if (equate != null && equate.getValue() != value) {
			// the name is taken by another value; qualifying it beats saying something false
			member = enumName + "_" + member;
			equate = table.getEquate(member);
		}
		if (equate == null) {
			equate = table.createEquate(member, value);
		}
		equate.addReference(address, operand);
		equates++;
	}

	private void applyEnum(JsonObject item) {
		String name = sanitizeType(item.get("name").getAsString());
		DataType existing = findType(name);
		boolean ours = existing instanceof ghidra.program.model.data.Enum
			&& (ENUM_CATEGORY.equals(existing.getCategoryPath())
				|| CATEGORY.equals(existing.getCategoryPath())
				|| String.valueOf(existing.getDescription()).contains(MARKER));
		if (existing != null && !overwrite && !ours) {
			kept++;
			notes.add("enum " + name + " is yours, left as it is");
			return;
		}
		if (existing != null && !(existing instanceof ghidra.program.model.data.Enum)) {
			kept++;
			notes.add("a " + existing.getClass().getSimpleName() + " already holds the name "
				+ name + ", so the enum was not made");
			return;
		}
		EnumDataType e = new EnumDataType(ENUM_CATEGORY, name, item.has("size") ? item.get("size").getAsInt() : 4, dtm);
		for (JsonElement v : array(item, "values")) {
			JsonObject value = v.getAsJsonObject();
			e.add(value.get("name").getAsString(), value.get("value").getAsLong());
		}
		e.setDescription((item.has("comment") ? item.get("comment").getAsString() + "  " : "") + MARKER);
		if (existing != null) {
			filed(existing, ENUM_CATEGORY);
			if (existing.isEquivalent(e)) {
				return;                                      // already what the findings hold
			}
			existing.replaceWith(e);
			enums++;
			return;
		}
		dtm.addDataType(e, DataTypeConflictHandler.KEEP_HANDLER);
		enums++;
	}

	private void applyStruct(JsonObject item) {
		String name = item.get("name").getAsString();
		Structure struct = structFor(name, true);
		if (item.has("size") && !item.get("size").isJsonNull()) {
			int size = item.get("size").getAsInt();
			if (struct.isNotYetDefined() || struct.getLength() < size) {
				struct.growStructure(size - (struct.isNotYetDefined() ? 0 : struct.getLength()));
			}
			else if (struct.getLength() > size) {
				shrinkToDeclared(struct, name, size);
			}
		}
		for (JsonElement e : array(item, "fields")) {
			JsonObject field = e.getAsJsonObject();
			int offset = field.get("offset").getAsInt();
			String fname = field.get("name").getAsString();
			String comment = string(field, "comment");
			DataType type = resolve(field.get("type").getAsString());
			if (type.getLength() <= 0 || (type instanceof Structure s && s.isNotYetDefined())) {
				// A class whose size is not known: name the offset, and leave the extent open.
				comment = field.get("type").getAsString() + " (size unknown). " + comment;
				type = Undefined1DataType.dataType;
			}
			placeField(struct, offset, fname, type, comment, field.get("type").getAsString());
		}
	}

	/**
	 * Cut a structure down to the extent the record declares.
	 *
	 * **Why this exists, 2026-10-05.** The script only ever *grew* a structure, so a type
	 * Ghidra held longer than the record intends silently swallowed whatever field was
	 * declared after a by-value member of it - and the next run put the swallowed field back
	 * and lost the member instead. That is what made the apply run in a **period-2 cycle**
	 * over five structures rather than settling: four passes over an unchanged record gave
	 * `struct fields: 6, 5, 6, 5`. `CLeaderHistory` is 0x24 by its own fields and was 0x44 in
	 * Ghidra, so `CLeader`'s `history` at +0x84 covered both `picture` (+0xA8) and
	 * `trait_gain_tracker` (+0xC4).
	 *
	 * The rule is now: **a declared `size` is the authority in both directions.** That is not
	 * a blunt instrument - of the 41 sized structures in the record exactly one was longer in
	 * Ghidra - but every component it drops is named in the notes, because a structural change
	 * nobody can see would be worse than the cycle it fixes. Without `overwrite` it only
	 * reports.
	 */
	private void shrinkToDeclared(Structure struct, String name, int size) {
		List<String> dropped = new ArrayList<>();
		for (DataTypeComponent c : struct.getDefinedComponents()) {
			if (c.getOffset() >= size) {
				dropped.add("+0x" + Integer.toHexString(c.getOffset()) + " " +
					(c.getFieldName() == null ? c.getDataType().getName() : c.getFieldName()));
			}
		}
		String what = name + ": record declares 0x" + Integer.toHexString(size) +
			", Ghidra holds 0x" + Integer.toHexString(struct.getLength());
		if (!overwrite) {
			kept++;
			notes.add(what + "; not shrinking without overwrite" +
				(dropped.isEmpty() ? "" : " (would drop " + String.join(", ", dropped) + ")"));
			return;
		}
		DataTypeComponent[] defined = struct.getDefinedComponents();
		for (int i = defined.length - 1; i >= 0; i--) {
			if (defined[i].getOffset() >= size) {
				struct.clearAtOffset(defined[i].getOffset());
			}
		}
		struct.setLength(size);
		notes.add(what + " -> shrunk" + (dropped.isEmpty()
			? " (the tail was undefined bytes)"
			: ", dropping " + String.join(", ", dropped)));
	}

	// ---- virtual tables ---------------------------------------------------------------------

	/**
	 * A structure for one class's virtual table, and a pointer to it on the class itself, so
	 * that a call through the table reads as a name: `unit->vftable->GetAverageOrganisation()`
	 * rather than `(**(*unit + 0x50))()`.
	 *
	 * An abstract base has no table in the image, since nothing of that class is ever made,
	 * but calls on a pointer to it still go through one; such a table comes with no address
	 * on the slots its descendants fill.
	 *
	 * A slot whose function is known takes a pointer to that function's own definition, which
	 * is what gives the call its arguments and return type; the rest are plain pointers, named
	 * for the slot they fill.
	 */
	private void applyVftable(JsonObject item) {
		String name = item.get("name").getAsString();
		String owner = item.get("class").getAsString();
		int at = item.get("objectOffset").getAsInt();
		Structure table = structFor(name, true);
		JsonArray slots = array(item, "slots");
		int size = slots.size() * 4;
		if (table.isNotYetDefined() || table.getLength() < size) {
			table.growStructure(size - (table.isNotYetDefined() ? 0 : table.getLength()));
		}
		for (JsonElement e : slots) {
			JsonObject slot = e.getAsJsonObject();
			int index = slot.get("slot").getAsInt();
			// A table the compiler never wrote - an abstract base's - has no address for a
			// slot the base leaves to its descendants.
			Address target = slot.get("rva").isJsonNull() ? null
				: base.add(slot.get("rva").getAsLong());
			String fname = slot.get("name").getAsString();
			String comment = string(slot, "comment");
			boolean typed = slot.get("typed").getAsBoolean();
			// Where the findings have no name for a slot, a name you gave the function in
			// Ghidra is the best one there is - as long as the body is this class's own or
			// inherited, which is what "own" says. A folded body is shared with classes that
			// have nothing to do with this one, and its name would not be about this slot.
			if (target != null && !slot.get("named").getAsBoolean() && slot.get("own").getAsBoolean()) {
				Function f = getFunctionAt(target);
				if (f != null && !PLACEHOLDER.matcher(f.getName()).matches()) {
					fname = sanitize(f.getName());
					comment += " - named " + f.getName(true) + " in this program";
					typed |= f.getSignatureSource() != SourceType.DEFAULT;
				}
			}
			// A slot the class itself leaves pure virtual has _purecall at its address, which
			// says nothing about the call; where the findings write the signature out, that is
			// what the slot is typed from.
			DataType type;
			if (slot.has("signature") && !slot.get("signature").isJsonNull()) {
				type = slotType(name, fname, slot.getAsJsonObject("signature"));
			}
			else {
				type = typed && target != null ? slotType(name, fname, target)
					: new PointerDataType(VoidDataType.dataType, dtm);
			}
			placeField(table, index * 4, fname, type, comment, "a function pointer");
		}
		Structure cls = structFor(owner, true);
		String field = at == 0 ? "vftable" : "vftable_at" + Integer.toHexString(at);
		placeField(cls, at, field, new PointerDataType(table, dtm),
			"the virtual table, " + name, name + "*");
		vftables++;
	}

	/**
	 * The same, from a signature the findings carry rather than from the body at the address.
	 * That is for a slot its own class leaves pure virtual: every derived class fills it, and
	 * what the base's table points at is _purecall, which would type the slot as taking
	 * nothing and answering nothing.
	 */
	private DataType slotType(String table, String fname, JsonObject sig) {
		FunctionDefinitionDataType definition =
			new FunctionDefinitionDataType(VFTABLE_CATEGORY, table + "_" + fname, dtm);
		definition.setReturnType(resolve(sig.get("return").getAsString()));
		List<ParameterDefinition> params = new ArrayList<>();
		int n = 1;
		for (JsonElement e : sig.getAsJsonArray("params")) {
			JsonObject p = e.getAsJsonObject();
			String pname = p.has("name") && !p.get("name").isJsonNull() ? p.get("name").getAsString()
				: "arg" + n;
			params.add(new ParameterDefinitionImpl(pname, resolve(p.get("type").getAsString()), null));
			n++;
		}
		definition.setArguments(params.toArray(new ParameterDefinition[0]));
		try {
			definition.setCallingConvention(sig.get("convention").getAsString());
		}
		catch (Exception ignored) {
			// A convention the program does not know is not worth losing the signature over.
		}
		DataType kept = dtm.getDataType(VFTABLE_CATEGORY, definition.getName());
		if (kept != null && kept.isEquivalent(definition)) {
			return new PointerDataType(kept, dtm);
		}
		return new PointerDataType(dtm.addDataType(definition, DataTypeConflictHandler.REPLACE_HANDLER), dtm);
	}

	/**
	 * A pointer to the function definition of whatever fills a slot. Only for a body that is
	 * the class's own: the linker folds identical bodies together, and one of those carries
	 * the signature of whichever class it was named for.
	 */
	private DataType slotType(String table, String fname, Address target) {
		Function f = getFunctionAt(target);
		if (f == null) {
			return new PointerDataType(VoidDataType.dataType, dtm);
		}
		FunctionDefinitionDataType definition = new FunctionDefinitionDataType(f, false);
		try {
			definition.setName(table + "_" + fname);
		}
		catch (InvalidNameException ex) {
			return new PointerDataType(VoidDataType.dataType, dtm);
		}
		// Under `organise` the slot definitions nest below the tables they belong to; without
		// it they stay exactly where they were, so a plain `overwrite` run rearranges nothing.
		// This matters more than it looks: moving them retypes every vftable structure's
		// fields, which is 1918 placements in one go - churn worth asking for rather than
		// delivering by surprise.
		// **Reuse an existing definition wherever it lives, and only choose a folder for a
		// new one.** Looking only in the folder the flag selects made a plain `overwrite`
		// run recreate every definition in the old folder and retype all 1918 vftable
		// fields - so running with the flag and then without it churned thousands of types
		// each way. `organise` decides where a definition is *created*; it never decides
		// where one is *found*.
		DataType kept = dtm.getDataType(SLOT_CATEGORY, definition.getName());
		if (kept == null) {
			kept = dtm.getDataType(VFTABLE_CATEGORY, definition.getName());
		}
		if (kept != null && kept.isEquivalent(definition)) {
			return new PointerDataType(kept, dtm);
		}
		definition.setCategoryPath(kept != null ? kept.getCategoryPath()
			: organise ? SLOT_CATEGORY : VFTABLE_CATEGORY);
		return new PointerDataType(dtm.addDataType(definition, DataTypeConflictHandler.REPLACE_HANDLER), dtm);
	}

	/**
	 * One field into a structure, under the rules the whole script keeps: what the findings
	 * placed before may be retyped, what you placed is left alone and reported.
	 */
	private void placeField(Structure struct, int offset, String fname, DataType type, String comment,
			String describedAs) {
		int length = type.getLength();
		if (struct.isNotYetDefined() || struct.getLength() < offset + length) {
			struct.growStructure(offset + length - (struct.isNotYetDefined() ? 0 : struct.getLength()));
		}
		// Marked, so a later run can tell a field it placed from one you typed. What
		// the findings say about a field changes as they are rebuilt - a class that
		// had no layout gets one, a list learns what its nodes hold - and its own
		// fields have to follow, while yours are left alone.
		String marked = comment + "  " + MARKER;
		DataTypeComponent existing = struct.getDefinedComponentAtOrAfterOffset(offset);
		boolean standing = existing != null && existing.getOffset() == offset && isDefined(existing);
		if (standing) {
			if (fname.equals(existing.getFieldName()) && existing.getDataType().isEquivalent(type)
				&& marked.equals(existing.getComment())) {
				return;                                 // already exactly this
			}
			// **A settled run places no fields.** When one is placed over a field that was
			// already standing, and placed again on the next run, the two disagree about
			// something that re-placing does not fix - and until this note existed that was
			// invisible, because a successful placement records nothing. Say which of the
			// three the run tripped on.
			if (ourField(existing, comment, type) || overwrite) {
				String differs = !fname.equals(existing.getFieldName())
					? "named " + existing.getFieldName()
					: !existing.getDataType().isEquivalent(type)
						? "typed " + existing.getDataType().getDisplayName() + ", findings say "
							+ type.getDisplayName()
						: "same name and type, comment differs";
				notes.add("~ " + struct.getName() + "+0x" + Integer.toHexString(offset) + " "
					+ fname + ": " + differs);
			}
			// One of ours may be renamed as well as retyped: a slot the findings could not
			// name takes the name the function has in this program, and that name changes
			// when you change it.
			if (!(ourField(existing, comment, type) || overwrite)) {
				kept++;
				notes.add(struct.getName() + "+0x" + Integer.toHexString(offset) + " " +
					existing.getFieldName() + " is yours (" + existing.getDataType().getDisplayName() +
					"), leaving it - the findings say " + fname + ", " + describedAs);
				return;
			}
		}
		comment = marked;
		List<DataTypeComponent> blocking = blockers(struct, offset, length);
		// What stands at this very offset was decided above; the rest are neighbours.
		blocking.removeIf(c -> c.getOffset() == offset);
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
				return;
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

	/**
	 * Whether a field standing at an offset the findings cover is one of ours, and so may
	 * be retyped: it carries the marker, or it is an undefined placeholder - the name with
	 * nothing behind it, which is what a class of unknown size was left as - or its comment
	 * is word for word the one the findings hold, which is how a field placed before the
	 * marker existed is recognised. A type set by hand is none of those.
	 */
	private static boolean ourField(DataTypeComponent existing, String comment, DataType type) {
		String standing = existing.getComment();
		if (standing != null && (standing.contains(MARKER) || standing.equals(comment) || generated(standing))) {
			return true;
		}
		DataType had = existing.getDataType();
		return (had instanceof Undefined || had == DataType.DEFAULT)
			&& !(type instanceof Undefined) && type != DataType.DEFAULT && !had.isEquivalent(type);
	}

	/**
	 * Whether a field comment reads as one of ours from before the marker: every comment
	 * the findings write either cites where it came from or says how the game reaches the
	 * field. The source line moves as files are edited, so the text itself cannot be
	 * compared; the shape of it can.
	 */
	private static boolean generated(String comment) {
		return comment.contains("(BiceLib/") || comment.contains("(reversing/")
			|| comment.startsWith("declared to Lua") || comment.startsWith("read by ")
			|| comment.contains("(size unknown).");
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
	 * exists, so it becomes the type of `this`; otherwise one in the right /BiceLib folder.
	 */
	private Structure structFor(String cppName, boolean create) {
		String name = sanitizeType(cppName);
		Namespace ns = existingNamespace(cppName);
		if (ns instanceof GhidraClass cls) {
			// Where the class has no structure yet this hands back a new one that belongs to
			// nobody: it has to be resolved into the manager, or everything written into it
			// is dropped when the script ends.
			Structure s = (Structure) dtm.resolve(
				VariableUtilities.findOrCreateClassStruct(cls, dtm),
				DataTypeConflictHandler.KEEP_HANDLER);
			return (Structure) filed(s, categoryFor(name));
		}
		DataType existing = findType(name);
		if (existing instanceof Structure s) {
			return (Structure) filed(s, categoryFor(name));
		}
		if (!create) {
			return null;
		}
		return (Structure) dtm.addDataType(new StructureDataType(categoryFor(name), name, 0, dtm),
			DataTypeConflictHandler.KEEP_HANDLER);
	}

	/**
	 * Move the slot function definitions between `/BiceLib/vftables` and its `slots` child,
	 * once, before any vftable is applied.
	 *
	 * **Without this the category change duplicates them instead of moving them.**
	 * `slotType` resolves a definition with `addDataType`, which is keyed by category *and*
	 * name - so changing the target folder creates a second copy and leaves the first
	 * orphaned, and the first run of `organise` took the project from 9046 types to 12885.
	 * Sweeping first means `slotType` finds the one that already exists wherever it is.
	 *
	 * It runs in both directions, so turning the flag off tidies up after itself, and it
	 * deletes rather than moves where both folders already hold the name - that is an
	 * orphan from exactly this bug, and the structures point at the one in the target.
	 */
	private void sweepSlotDefinitions() {
		// **Only forwards.** An earlier version swept back when the flag was absent, so that
		// turning it off tidied up after itself - but that makes a plain `overwrite` run
		// silently undo the organisation, and alternating the two churns thousands of types
		// each way. The flag adds; it does not toggle.
		if (!organise) {
			return;
		}
		CategoryPath from = VFTABLE_CATEGORY;
		CategoryPath to = SLOT_CATEGORY;
		Category source = dtm.getCategory(from);
		if (source == null) {
			return;
		}
		dtm.createCategory(to);
		int swept = 0, dropped = 0;   // dropped: left alone, counted, never deleted
		for (DataType dt : source.getDataTypes()) {
			// **The interface, not the class.** A definition resolved into the manager comes
			// back as Ghidra's own DB-backed implementation, so `instanceof
			// FunctionDefinitionDataType` is false for every one of them, and the first
			// version of this swept nothing at all while reporting success.
			//
			// **Definitions only - never the pointers.** Ghidra creates `X *` beside its
			// base and does not move it when the base moves, so the old folder keeps a
			// pointer per slot. Sweeping those as well looked tidier and does not converge:
			// the vftable pass recreates each one, so every run deleted them again and
			// re-placed the 666 structure fields that use them. They are generated types
			// Ghidra manages, and its own "Remove Unused Data Types" clears them; leaving
			// them is cosmetic, deleting them is a loop.
			if (!(dt instanceof FunctionDefinition)) {
				continue;                  // the tables themselves live here and stay
			}
			if (dtm.getDataType(to, dt.getName()) != null) {
				// Both folders hold the name, so this one is dead - but **do not delete it.**
				// A structure field still points at it through a pointer in this folder, and
				// removing the definition turns that pointer, and the field, into `-BAD-`.
				// The vftable pass then re-places the field, resolving a fresh pointer that
				// re-anchors a definition here, and the next run sweeps it again: 666 fields
				// churned on every run and nothing converged. Leaving it costs some dead
				// clutter that Ghidra's own "Remove Unused Data Types" clears.
				//
				// This only happens where a move was left half-done, which outside testing
				// means a run interrupted between the sweep and the vftable pass.
				dropped++;
				continue;
			}
			try {
				dt.setCategoryPath(to);
				swept++;
			}
			catch (ghidra.util.exception.DuplicateNameException ex) {
				// cannot happen - the name was just checked - but swallowing it silently
				// would hide a leak, so it is counted as kept and said out loud.
				kept++;
				notes.add("! slot definition " + dt.getName() + " stays in " + from.getPath());
			}
		}
		if (swept + dropped > 0) {
			moved += swept;
			notes.add("slot definitions: " + swept + " moved to " + to.getPath()
				+ (dropped > 0 ? ", " + dropped + " dead duplicates left alone" : ""));
		}
	}

	/** Which /BiceLib folder a recorded type belongs in, from its name alone. */
	private CategoryPath categoryFor(String name) {
		if (CONTAINER.matcher(name).matches()) {
			return CONTAINER_CATEGORY;
		}
		if (name.contains("vftable") || name.contains("vtable")) {
			return VFTABLE_CATEGORY;
		}
		return CLASS_CATEGORY;
	}

	/**
	 * Move a type into its category, when `organise` says to.
	 *
	 * **Only ever called for a name the findings carry**, which is what keeps it off
	 * anything you made yourself. Ghidra identifies a type by reference and not by path, so
	 * a move disturbs no field, signature or decompiled line - but a structure Ghidra ties
	 * to a class namespace is looked up through that namespace, so moving one is the case to
	 * watch: a second run has to find the moved type rather than create a fresh one beside
	 * it. That is checked by running the apply twice and seeing `struct fields: 0` with no
	 * new type, which is the same pass mark everything else here uses.
	 */
	private DataType filed(DataType dt, CategoryPath where) {
		if (!organise || dt == null || where.equals(dt.getCategoryPath())) {
			return dt;
		}
		CategoryPath from = dt.getCategoryPath();
		try {
			dtm.createCategory(where);
			dt.setCategoryPath(where);
			moved++;
			if (moved <= 12) {
				notes.add("moved " + dt.getName() + " from " + from.getPath()
					+ " to " + where.getPath());
			}
		}
		catch (ghidra.util.exception.DuplicateNameException ex) {
			// A different type of the same name already sits in the target folder. Leave this
			// one where it is and say so: silently merging two types of one name is how a
			// field table ends up describing the wrong object.
			kept++;
			notes.add("! " + dt.getName() + " stays in " + from.getPath()
				+ " - something of that name is already in " + where.getPath());
		}
		return dt;
	}

	private DataType findType(String name) {
		// The folders we own, nearest first. `findDataTypes` below would find these anyway;
		// asking directly keeps the common case off a whole-manager search.
		for (CategoryPath c : new CategoryPath[] { CLASS_CATEGORY, CONTAINER_CATEGORY,
			VFTABLE_CATEGORY, ENUM_CATEGORY, CATEGORY }) {
			DataType here = dtm.getDataType(c, name);
			if (here != null) {
				return here;
			}
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
			// Ghidra's own spellings. Without them a 64-bit field resolves to an empty
			// structure of that name - one byte wide - so it never covers its second half
			// and a field declared there fights it on every run.
			case "longlong": return LongLongDataType.dataType;
			case "long long": return LongLongDataType.dataType;
			case "ulonglong": return UnsignedLongLongDataType.dataType;
			case "unsigned long long": return UnsignedLongLongDataType.dataType;
			case "undefined2": return Undefined2DataType.dataType;
			case "undefined8": return Undefined8DataType.dataType;
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
