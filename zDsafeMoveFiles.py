import os
import shutil
import time
import threading
import queue

Modfolders = ["./battleplans","./cgm","./common","./decisions","./events", "./gfx", "./history","./localisation","./map",
                "./interface","./music","./script","./sound","./technologies","./units"]
BaseModPath = "C:/Users/David/Hearts of Iron 3/tfh/mod/BlackICE GitHub"

THREAD_AMOUNT = 5
THREAD_POOL = []
ACTIVE_THREADS = 0
FILE_QUEUE = queue.Queue()


def addUtilityResources():
    os.makedirs(os.path.abspath(os.path.join(BaseModPath, "utility")), exist_ok=True)
    for root, dirs, files in os.walk(f"./tools/wxWidget/projects/tfh/mod/BlackICE-utility-resources/"):
        for file in files:
            shutil.copyfile(os.path.abspath(os.path.join(root, file)), os.path.abspath(os.path.join(BaseModPath, f"utility/{file}")))

def addStatsCLI():
    os.makedirs(os.path.abspath(os.path.join(BaseModPath, "stats")), exist_ok=True)
    shutil.copyfile("./tools/visualizeStatistics/visualizeStatisticCLI.exe", os.path.abspath(os.path.join(BaseModPath, "stats/visualizeStatisticCLI.exe")))

def addReversingProbes():
    """Puts the probe files beside BiceLib.dll, where it looks for them.

    Copied rather than queued, like the other resources that are not mod content: the
    queue is for the ~66k files walked out of the mod folders, and these are two.

    A missing folder is not a problem worth reporting - the probes are BiceLib's, and
    the mod deploys without them.
    """
    if not os.path.isdir(ReversingProbes):
        return
    target = os.path.abspath(os.path.join(BaseModPath, "script"))
    os.makedirs(target, exist_ok=True)
    placed = 0
    for file in os.listdir(ReversingProbes):
        if not file.lower().endswith(".txt"):
            continue
        shutil.copyfile(os.path.abspath(os.path.join(ReversingProbes, file)),
                        os.path.join(target, file))
        placed += 1
    if placed:
        print(f"Placed {placed} reverse engineering probe file(s) in ./script")

def addFiles():
    print("Collecting files...")
    addUtilityResources()
    addStatsCLI()
    addReversingProbes()
    for root, dirs, files in os.walk("./"):
        if root.split("\\")[0] not in Modfolders:
            continue
        else:
            for file in files:
                os.makedirs(os.path.abspath(os.path.join(BaseModPath, root)), exist_ok=True)
                FILE_QUEUE.put(
                    (
                        os.path.abspath(os.path.join(root, file)),
                        os.path.abspath(os.path.join(BaseModPath, root, file))
                    )
                )

    print("Collecting files done")

# What BiceLib writes next to its DLL, which lives in ./script and would therefore be
# destroyed by clearTarget() along with everything else in there. These are the player's
# and the developer's, not the mod's: settings, the overlay's dock layout, saved console
# scripts and the per campaign combat records. Set to [] to go back to losing them.
PreserveInScript = [
    "BiceLibSettings.ini",
    "BiceLibImGui.ini",
    "BiceLibScripts",
    "combat_reports",
    # Crash reports are the whole evidence of a crash somebody has reported, and a
    # deploy is exactly what happens next after one arrives.
    "crash_reports",
    # What the reverse engineering probes wrote. A campaign's worth of evidence about
    # what the game actually does, and nothing in the source tree can recreate it.
    #
    # Only the .csv. The .txt beside each one is the question rather than the answer, it
    # comes from ReversingProbes below, and a deploy is meant to refresh it - preserving
    # it here would put the stashed copy back over the one just deployed.
    "BiceLibCounters.csv",
    "BiceLibWatch.csv",
]

# The reverse engineering probes: which addresses to count, and which fields to watch.
# BiceLib reads them from beside its DLL, which is ./script, but they are not mod content
# and do not live in ./script - they are kept with the tools that produce them, under
# version control, and put in place from here.
ReversingProbes = "./DaveStuff/luabinaries/bice/BiceLib/reversing/probes"

PreserveStash = os.path.abspath("./.deploy-preserved")

def stashPreserved():
    """Moves the files worth keeping out of the way, before the target is cleared."""
    if not PreserveInScript:
        return
    shutil.rmtree(PreserveStash, ignore_errors=True)
    kept = 0
    for name in PreserveInScript:
        source = os.path.abspath(os.path.join(BaseModPath, "script", name))
        if not os.path.exists(source):
            continue
        os.makedirs(PreserveStash, exist_ok=True)
        destination = os.path.join(PreserveStash, name)
        if os.path.isdir(source):
            shutil.copytree(source, destination)
        else:
            shutil.copy2(source, destination)
        kept += 1
    if kept:
        print(f"Kept {kept} BiceLib file(s) from ./script")

def restorePreserved():
    """Puts them back, after the copy has recreated ./script."""
    if not os.path.isdir(PreserveStash):
        return
    target = os.path.abspath(os.path.join(BaseModPath, "script"))
    os.makedirs(target, exist_ok=True)
    for name in os.listdir(PreserveStash):
        source = os.path.join(PreserveStash, name)
        destination = os.path.join(target, name)
        if os.path.isdir(source):
            shutil.copytree(source, destination, dirs_exist_ok=True)
        else:
            shutil.copy2(source, destination)
    shutil.rmtree(PreserveStash, ignore_errors=True)
    print("Restored BiceLib files to ./script")

def clearTarget():
    print("Removing files in target directory...")
    for folder in Modfolders:
        path = os.path.abspath(os.path.join(BaseModPath, folder))
        print(f"Removing {path}")
        shutil.rmtree(path, ignore_errors=True)
    print("Removed files")

def job():
    while not FILE_QUEUE.empty():
        entry = FILE_QUEUE.get()
        shutil.copyfile(entry[0], entry[1])
        FILE_QUEUE.task_done()

def threads_running():
    n = 0
    for t in THREAD_POOL:
        if t.is_alive():
            n += 1
    global ACTIVE_THREADS
    ACTIVE_THREADS = n
    return n

def askAboutGfx():
    """Whether to deploy ./gfx. Yes unless the dialog is answered No.

    gfx is the slowest part of a deploy by a wide margin - it is where the large files
    are - and most changes do not touch it.

    Skipping it drops it from Modfolders, which means the target's gfx is neither cleared
    nor recopied: the copy already there is left exactly as it is. That only works while
    it is up to date, which is why the dialog says so rather than leaving it to be
    remembered.

    Falls back to a complete deploy if the dialog cannot be shown - running without a
    desktop is not a reason to quietly ship a partial mod.
    """
    try:
        import ctypes
        MB_YESNO = 0x4
        MB_ICONQUESTION = 0x20
        MB_SETFOREGROUND = 0x10000
        IDNO = 7
        answer = ctypes.windll.user32.MessageBoxW(
            0,
            "Include the gfx folder?\n\n"
            "gfx is the slowest part of the deploy - it holds the large files.\n\n"
            "Yes  -  deploy everything, as usual.\n"
            "No  -  skip gfx entirely. The copy already in the mod folder is left "
            "untouched, not deleted.\n\n"
            "Choose No only if you have not changed anything under gfx since the last "
            "deploy.",
            "Deploy BlackICE",
            MB_YESNO | MB_ICONQUESTION | MB_SETFOREGROUND)
        return answer != IDNO
    except Exception as problem:
        print(f"Could not ask about gfx ({problem}), deploying everything")
        return True

def moveIt():
    time1 = time.time()

    global Modfolders
    if askAboutGfx():
        print("Deploying everything, gfx included")
    else:
        Modfolders = [f for f in Modfolders if f != "./gfx"]
        print("Skipping gfx - the copy in the mod folder is left as it is")

    stashPreserved()
    clearTarget()
    addFiles()

    for _ in range(THREAD_AMOUNT):
        x = threading.Thread(target=job, args=(()), daemon=True)
        THREAD_POOL.append(x)
        x.start()

    while threads_running():
        print(f"Queue size: {FILE_QUEUE.qsize()} - Active threads: {ACTIVE_THREADS}", flush=True)
        time.sleep(1)

    restorePreserved()

    time2 = time.time()
    rounded_time = round((time2 - time1), 2)
    print("All done! :)" )
    print("Took " + str(rounded_time) + " seconds")
    os.system("pause")

moveIt()
