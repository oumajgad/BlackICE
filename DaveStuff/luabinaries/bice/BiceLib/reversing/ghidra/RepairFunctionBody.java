// Why the decompiler stops part way through a function, and how to make it stop stopping.
//
//   RepairFunctionBody                        report on the function under the cursor
//   RepairFunctionBody 0x00689be0 ...         report on these
//   RepairFunctionBody fix 0x00689be0         repair these
//   RepairFunctionBody sweep                  every function in the program this happens to
//   RepairFunctionBody sweep fix 0x00b95f9b   repair all of them, for the callees named
//
// The symptom is a decompilation that ends mid function while the listing plainly has more
// code. Ghidra decompiles a function's *body*, which is a set of address ranges settled when
// the function was made - not the bytes between its entry and the next function. So a body
// that stops early takes the decompilation with it, and the listing gives no sign beyond one
// line in the instruction's own field.
//
// **What truncates one is a call the program believes never comes back**, and that happens two
// ways which look identical from the decompiler:
//
//   1. **The callee is marked No Return.**
//   2. **The call site carries a `CALL_RETURN` flow override**, which the listing shows as
//      `Flow Override: CALL_RETURN (CALL_TERMINATOR)`. This one lives on the instruction, so
//      clearing the callee's mark does not touch it, and vice versa.
//
// Either way the call has no fall-through, everything after it is unreachable, it never joins
// the body, and code only reachable that way is often never disassembled either. Ghidra's
// "Non-Returning Functions - Discovered" analyzer lays down both, guessing from the shape of a
// function, and on an MSVC CRT it guesses wrong: `free` here is the five-byte thunk
// `mov edi,edi; push ebp; mov ebp,esp; pop ebp; jmp <body>`, which is exactly what it mistakes
// for one. `free` has 35868 call sites in this executable, so one wrong guess hides a large
// part of the program - which is what `sweep` is for.
//
// The repair is to clear whichever of the two is there, disassemble what the truncation left
// as raw bytes, and recompute the body from the flow. The function keeps its name, its
// signature and its comments; only its range set changes.
//
// **It reports before it changes anything, and clears nothing until told which callee.** Some
// of these are right - a real `abort` or `_CxxThrowException` truncates its callers correctly -
// and nothing in the shape of a function separates the two. That judgement stays with the
// reader, which is why `sweep fix` takes addresses.
//@category C++

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.FlowOverride;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;

public class RepairFunctionBody extends GhidraScript {

    private static final String REPORT_ONE = "Report on the function at the cursor";
    private static final String FIX_ONE = "Repair the function at the cursor";
    private static final String REPORT_ALL = "Report on the whole program";
    private static final String FIX_ALL = "Repair the whole program, for callees I name";

    @Override
    public void run() throws Exception {
        boolean fix = false;
        boolean sweep = false;
        Set<Address> given = new LinkedHashSet<>();
        for (String arg : getScriptArgs()) {
            if (arg.equalsIgnoreCase("fix")) {
                fix = true;
            } else if (arg.equalsIgnoreCase("sweep")) {
                sweep = true;
            } else {
                given.add(currentProgram.getAddressFactory().getAddress(arg));
            }
        }

        // **The GUI passes no arguments**, so with none at all, ask. Running it from the Script
        // Manager would otherwise only ever report, and the repair would be reachable headless
        // only - which is the wrong way round, since the symptom is something you see while
        // reading a decompilation.
        if (getScriptArgs().length == 0 && !isRunningHeadless()) {
            String choice = askChoice("RepairFunctionBody", "What should it do?",
                    List.of(REPORT_ONE, FIX_ONE, REPORT_ALL, FIX_ALL), REPORT_ONE);
            fix = choice.equals(FIX_ONE) || choice.equals(FIX_ALL);
            sweep = choice.equals(REPORT_ALL) || choice.equals(FIX_ALL);
            if (choice.equals(FIX_ALL)) {
                for (String part : askString("RepairFunctionBody",
                        "Addresses of the callees whose No Return is wrong, space separated"
                                + " (free is 0x00b95f9b)").trim().split("[ ,;]+")) {
                    if (!part.isEmpty()) {
                        given.add(currentProgram.getAddressFactory().getAddress(part));
                    }
                }
            }
        }

        if (sweep) {
            sweep(fix, given);
            return;
        }

        if (given.isEmpty()) {
            if (currentAddress == null) {
                println("RepairFunctionBody: no cursor and no address given");
                return;
            }
            given.add(currentAddress);
        }
        for (Address at : given) {
            Function function = getFunctionContaining(at);
            println("=== " + at + " ===");
            if (function == null) {
                println("  no function contains this address");
                continue;
            }
            report(function, fix);
        }
    }

    // ---- what a truncation looks like ----------------------------------------------------

    /**
     * Where execution can go from this instruction, inside its own function.
     *
     * **Ask where the flow goes, not what follows the body's last byte.** Taking the address
     * after the end reports the alignment padding behind every `ret` as code the function
     * lost. What a truncation really leaves is an instruction *inside* the body whose own
     * continuation nothing covers.
     */
    private Set<Address> continuations(Instruction instruction) {
        Set<Address> onward = new LinkedHashSet<>();
        Address fallThrough = instruction.getFallThrough();
        if (fallThrough != null) {
            onward.add(fallThrough);
        } else if (instruction.getFlowType().isCall()) {
            // A call with no recorded fall-through is the whole of this bug - whether that is
            // the callee's No Return mark or a CALL_RETURN override on the site itself.
            Address next = instruction.getMaxAddress().next();
            if (next != null) {
                onward.add(next);
            }
        }
        if (!instruction.getFlowType().isCall()) {
            for (Address flow : instruction.getFlows()) {
                onward.add(flow);
            }
        }
        return onward;
    }

    /** true when neither this function nor any other accounts for the address */
    private boolean uncovered(Function function, Address onward) {
        return currentProgram.getMemory().contains(onward)
                && !function.getBody().contains(onward)
                && getFunctionContaining(onward) == null;
    }

    // ---- one function -------------------------------------------------------------------

    private void report(Function function, boolean fix) throws Exception {
        println("  " + function.getName(true) + "  entry " + function.getEntryPoint());
        println("  body  " + function.getBody() + "  (" + function.getBody().getNumAddresses()
                + " bytes)");

        Set<Function> marked = new LinkedHashSet<>();         // callees claiming not to return
        Set<Instruction> overridden = new LinkedHashSet<>();  // sites carrying a flow override
        Set<Address> escapes = new LinkedHashSet<>();         // where the flow leaves the body

        InstructionIterator instructions =
                currentProgram.getListing().getInstructions(function.getBody(), true);
        while (instructions.hasNext()) {
            Instruction instruction = instructions.next();

            boolean leaks = false;
            for (Address next : continuations(instruction)) {
                if (uncovered(function, next)) {
                    escapes.add(next);
                    leaks = true;
                }
            }
            if (!leaks) {
                continue;
            }

            if (instruction.getFlowOverride() != FlowOverride.NONE) {
                println("  ! " + instruction.getAddress() + "   " + instruction
                        + "   Flow Override: " + instruction.getFlowOverride()
                        + " (" + instruction.getFlowType() + ")");
                overridden.add(instruction);
            }
            if (instruction.getFlowType().isCall()) {
                for (Address flow : instruction.getFlows()) {
                    Function callee = getFunctionAt(flow);
                    if (callee != null && callee.hasNoReturn()) {
                        println("  ! " + instruction.getAddress() + " calls " + callee.getName()
                                + " at " + flow + ", marked No Return");
                        marked.add(callee);
                    }
                }
            }
        }

        for (Address onward : escapes) {
            Instruction there = getInstructionAt(onward);
            println("  the flow reaches " + onward + ", which the body does not cover: "
                    + (there == null ? "undefined bytes - never disassembled" : there.toString()));
        }

        if (escapes.isEmpty()) {
            println("  nothing to repair: the body reaches every instruction the flow does");
            return;
        }
        if (!fix) {
            println("  (report only - run with `fix` to repair)");
            return;
        }

        for (Instruction instruction : overridden) {
            instruction.setFlowOverride(FlowOverride.NONE);
            println("  cleared the flow override at " + instruction.getAddress());
        }
        for (Function callee : marked) {
            callee.setNoReturn(false);
            println("  cleared No Return on " + callee.getName());
        }
        repair(function, escapes);
    }

    /**
     * Walk the flow from the entry point and make that the body.
     *
     * **Only `GhidraScript`'s own methods and the program model.** The obvious way to write
     * this is `DisassembleCommand` and `CreateFunctionCmd.fixupFunctionBody`, and it compiles
     * and runs headless - but in the GUI the script's bundle is not wired to
     * `ghidra.app.cmd.*` and it dies at run time with `NoClassDefFoundError`. Anything under
     * `ghidra.app.cmd` is off limits here; `disassemble(Address)` is the script API's own.
     */
    private boolean rebuild(Function function, Set<Address> escapes) throws Exception {
        for (Address onward : escapes) {
            if (getInstructionAt(onward) == null && getFunctionContaining(onward) == null) {
                disassemble(onward);
            }
        }

        AddressSet was = new AddressSet(function.getBody());
        AddressSet body = new AddressSet();
        Set<Address> visited = new LinkedHashSet<>();
        Deque<Address> queue = new ArrayDeque<>();
        queue.add(function.getEntryPoint());
        while (!queue.isEmpty()) {
            monitor.checkCancelled();
            Address at = queue.poll();
            if (!visited.add(at) || !currentProgram.getMemory().contains(at)) {
                continue;
            }
            // Stop at anything another function already owns, and at any other function's
            // entry point, so a repair can only ever take in code that belongs to nobody.
            Function owner = getFunctionContaining(at);
            if (owner != null && !owner.equals(function)) {
                continue;
            }
            if (!at.equals(function.getEntryPoint()) && getFunctionAt(at) != null) {
                continue;
            }
            Instruction instruction = getInstructionAt(at);
            if (instruction == null) {
                disassemble(at);
                instruction = getInstructionAt(at);
                if (instruction == null) {
                    continue;
                }
            }
            body.addRange(instruction.getMinAddress(), instruction.getMaxAddress());
            queue.addAll(continuations(instruction));
        }
        function.setBody(body);
        return !function.getBody().equals(was);
    }

    /** rebuild one function's body and say what happened */
    private void repair(Function function, Set<Address> escapes) throws Exception {
        AddressSet was = new AddressSet(function.getBody());
        if (rebuild(function, escapes)) {
            println("  " + function.getName() + ": body now " + function.getBody() + "  ("
                    + function.getBody().getNumAddresses() + " bytes, was "
                    + was.getNumAddresses() + ")");
        } else {
            println("  " + function.getName() + ": the body did not change"
                    + " - the flow still stops where it did");
        }
    }

    // ---- the whole program --------------------------------------------------------------

    /** everything one callee's truncations add up to */
    private static class Truncation {
        final Set<Function> callers = new LinkedHashSet<>();
        final Set<Instruction> sites = new LinkedHashSet<>();
        int overrides;
        boolean noReturn;
    }

    private void sweep(boolean fix, Set<Address> distrust) throws Exception {
        // **Walk the instructions, not the references.** A call site is a reference to its
        // callee, so finding the callers that way looks obvious and is quietly incomplete:
        // `getReferencesTo` hands back at most 4096, and the reference manager itself stops
        // recording at 8191 to one address. `free` has 35868 call sites here, so the reference
        // route saw a fifth of them and reported the very function this was written for as
        // untruncated. One pass over the listing is slower and right.
        Map<Address, Truncation> found = new LinkedHashMap<>();
        Map<Function, Set<Address>> toDisassemble = new LinkedHashMap<>();
        int seen = 0;

        Function inside = null;             // the instructions arrive in address order, so the
                                            // containing function hardly ever changes
        InstructionIterator instructions = currentProgram.getListing().getInstructions(true);
        while (instructions.hasNext()) {
            monitor.checkCancelled();
            Instruction site = instructions.next();
            if ((++seen & 0xFFFFF) == 0) {
                monitor.setMessage("RepairFunctionBody: " + seen + " instructions");
            }
            if (!site.getFlowType().isCall()) {
                continue;
            }
            // **The No Return mark alone leaves the fall-through in place.** What Ghidra's
            // analyzer actually puts on the site is the CALL_RETURN override, and the mark on
            // the callee is a separate record. So a call whose fall-through is recorded can
            // still sit at the end of a truncated body - the body was cut when the function
            // was made and never grew back. Skipping those as healthy misses the case this
            // was written for.
            Address next = site.getFallThrough();
            if (next == null) {
                next = site.getMaxAddress().next();
            }
            if (next == null) {
                continue;
            }
            if (inside == null || !inside.getBody().contains(site.getAddress())) {
                inside = getFunctionContaining(site.getAddress());
            }
            if (inside == null || !uncovered(inside, next)) {
                continue;                   // tail position, or the remainder is someone else's
            }
            Function caller = inside;

            for (Address flow : site.getFlows()) {
                Function callee = getFunctionAt(flow);
                Truncation truncation = found.computeIfAbsent(flow, k -> new Truncation());
                truncation.callers.add(caller);
                truncation.sites.add(site);
                if (site.getFlowOverride() != FlowOverride.NONE) {
                    truncation.overrides++;
                }
                truncation.noReturn = callee != null && callee.hasNoReturn();
                toDisassemble.computeIfAbsent(caller, k -> new LinkedHashSet<>()).add(next);
            }
        }

        if (found.isEmpty()) {
            println("Nothing is truncated: every call in the program has a fall-through its"
                    + " caller's body covers.");
            return;
        }

        List<Address> wrong = new ArrayList<>();
        for (Map.Entry<Address, Truncation> entry : found.entrySet()) {
            Address flow = entry.getKey();
            Truncation truncation = entry.getValue();
            Function callee = getFunctionAt(flow);
            List<String> why = new ArrayList<>();
            if (truncation.noReturn) {
                why.add("No Return");
            }
            if (truncation.overrides > 0) {
                why.add(truncation.overrides + " flow override"
                        + (truncation.overrides == 1 ? "" : "s"));
            }
            println(String.format("  %-38s %s   %d truncated caller%s   [%s]",
                    callee == null ? "(no function)" : callee.getName(), flow,
                    truncation.callers.size(), truncation.callers.size() == 1 ? "" : "s",
                    String.join(", ", why)));
            int shown = 0;
            for (Function caller : truncation.callers) {
                if (shown++ == 3) {
                    println("      ...");
                    break;
                }
                println("      e.g. " + caller.getName() + " at " + caller.getEntryPoint());
            }
            if (distrust.contains(flow)) {
                wrong.add(flow);
            }
        }

        if (!fix) {
            println("");
            println("Report only. To repair, name the callees whose mark is wrong:");
            println("  RepairFunctionBody sweep fix 0x<callee> [0x<callee> ...]");
            return;
        }
        if (wrong.isEmpty()) {
            println("");
            println("`fix` given, but none of the addresses named truncates anything"
                    + " - nothing done.");
            return;
        }

        // Clear everything before repairing any body: a caller truncated twice would otherwise
        // be recomputed while the second cut still stood.
        println("");
        Set<Function> callers = new LinkedHashSet<>();
        for (Address flow : wrong) {
            Truncation truncation = found.get(flow);
            Function callee = getFunctionAt(flow);
            for (Instruction site : truncation.sites) {
                if (site.getFlowOverride() != FlowOverride.NONE) {
                    site.setFlowOverride(FlowOverride.NONE);
                }
            }
            if (callee != null && callee.hasNoReturn()) {
                callee.setNoReturn(false);
            }
            callers.addAll(truncation.callers);
            println("cleared " + (callee == null ? flow.toString() : callee.getName()) + ": "
                    + truncation.overrides + " flow override"
                    + (truncation.overrides == 1 ? "" : "s")
                    + (truncation.noReturn ? " and the No Return mark" : "") + ", "
                    + truncation.callers.size() + " caller"
                    + (truncation.callers.size() == 1 ? "" : "s") + " to repair");
        }

        int repaired = 0;
        for (Function caller : callers) {
            monitor.checkCancelled();
            if (rebuild(caller, toDisassemble.get(caller))) {
                repaired++;
            }
        }
        println("bodies that grew: " + repaired + " of " + callers.size());
        println("Run the sweep again afterwards: a body that grew may reach further code that"
                + " was never disassembled, and a second pass takes that in.");
    }
}
