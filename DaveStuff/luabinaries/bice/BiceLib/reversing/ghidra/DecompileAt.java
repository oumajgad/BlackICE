// Decompiles the functions at the addresses given and prints the C.
//
// Headless, so a function can be read without opening the project:
//   analyzeHeadless <project dir> <name> -process hoi3_tfh.exe -noanalysis \
//       -scriptPath <this folder> -postScript DecompileAt.java 0x005baf70 ...
//
// Creates the function where there is none, which is what makes it usable on an
// address found by hand rather than one Ghidra already knows about.
//@category C++

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;

public class DecompileAt extends GhidraScript {

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length == 0) {
            println("DecompileAt: give one or more addresses");
            return;
        }

        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);
        decompiler.setSimplificationStyle("decompile");

        for (String arg : args) {
            Address at = currentProgram.getAddressFactory().getAddress(arg);
            Function function = getFunctionContaining(at);
            if (function == null) {
                function = createFunction(at, null);
            }
            if (function == null) {
                println("=== " + arg + ": no function, and one could not be made");
                continue;
            }

            println("=== " + function.getName() + " at " + function.getEntryPoint()
                    + " ===");
            DecompileResults results = decompiler.decompileFunction(function, 120, monitor);
            if (results == null || results.getDecompiledFunction() == null) {
                println("(decompilation failed: "
                        + (results == null ? "no result" : results.getErrorMessage()) + ")");
                continue;
            }
            println(results.getDecompiledFunction().getC());
        }
        decompiler.dispose();
    }
}
