// Prints the length and components of the structures named on the command line.
//
// Headless, so the types can be inspected without opening the project:
//   analyzeHeadless <project dir> <name> -process hoi3_tfh.exe -noanalysis \
//       -scriptPath <this folder> -postScript PrintStructs.java CFlags CLeaderHistory
//
// Written 2026-10-05 for the one question the record cannot answer about itself: **how long
// is the type Ghidra actually holds**. `project.json` may declare a `size` or leave it null,
// and ApplyBiceLibFindings only ever *grows* a structure, so a type Ghidra holds larger than
// the record intends silently swallows whatever field is declared after it - which is what
// made the apply cycle with period 2 over five structs instead of settling.
//
// Prints, per structure: its length, and every component with offset, length, name and the
// name of its data type. `undefined` components are marked, because a run of them past the
// record's intended end is what makes a shrink safe.
//@category C++

import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.DataType;
import ghidra.program.model.data.DataTypeComponent;
import ghidra.program.model.data.Structure;
import ghidra.program.model.data.Undefined;

public class PrintStructs extends GhidraScript {

	@Override
	public void run() throws Exception {
		String[] names = getScriptArgs();
		if (names.length == 0) {
			println("PrintStructs: give one or more structure names");
			return;
		}
		for (String name : names) {
			java.util.List<DataType> found = new java.util.ArrayList<>();
			currentProgram.getDataTypeManager().findDataTypes(name, found);
			Structure struct = null;
			for (DataType dt : found) {
				if (dt instanceof Structure) {
					struct = (Structure) dt;
					break;
				}
			}
			if (struct == null) {
				println("== " + name + ": no structure of that name");
				continue;
			}
			println(String.format("== %s  length 0x%X  (%s)  %d defined components",
				name, struct.getLength(), struct.getPathName(),
				struct.getNumDefinedComponents()));
			int undefinedRun = 0;
			for (DataTypeComponent c : struct.getDefinedComponents()) {
				DataType dt = c.getDataType();
				boolean undef = Undefined.isUndefined(dt);
				if (undef) {
					undefinedRun++;
				}
				println(String.format("   +0x%-5X len 0x%-4X %-26s %s%s",
					c.getOffset(), c.getLength(),
					c.getFieldName() == null ? "(unnamed)" : c.getFieldName(),
					dt.getName(), undef ? "   <- undefined" : ""));
			}
			println("   defined components that are undefined bytes: " + undefinedRun);
		}
	}
}
