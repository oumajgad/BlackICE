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

# Read every file back once the copy is done, so the first launch after a deploy is
# not the one that pays for it.
#
# A deploy rewrites all ~66k mod files, and the first process to touch one afterwards
# gets the slow path: the antivirus rescans it because it changed, and anything the
# write cache has already dropped comes off the disk again. That lands on the game,
# which reads them all while loading, and its loading is where it is fragile - a
# 32-bit process with DXVK in the same 4 GB. Reading them here moves that cost into
# the deploy, where a slow minute does not matter.
#
# Set to False to skip it. It costs one pass over the mod - around 12 seconds for the
# current 2.9 GB, well under what the copy itself takes.
WARM_CACHE_AFTER_COPY = True
WARM_CHUNK = 1024 * 1024

def addUtilityResources():
    os.makedirs(os.path.abspath(os.path.join(BaseModPath, "utility")), exist_ok=True)
    for root, dirs, files in os.walk(f"./tools/wxWidget/projects/tfh/mod/BlackICE-utility-resources/"):
        for file in files:
            shutil.copyfile(os.path.abspath(os.path.join(root, file)), os.path.abspath(os.path.join(BaseModPath, f"utility/{file}")))

def addStatsCLI():
    os.makedirs(os.path.abspath(os.path.join(BaseModPath, "stats")), exist_ok=True)
    shutil.copyfile("./tools/visualizeStatistics/visualizeStatisticCLI.exe", os.path.abspath(os.path.join(BaseModPath, "stats/visualizeStatisticCLI.exe")))

def addFiles():
    print("Collecting files...")
    addUtilityResources()
    addStatsCLI()
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

def warmJob():
    while True:
        try:
            path = FILE_QUEUE.get_nowait()
        except queue.Empty:
            return
        try:
            with open(path, "rb") as f:
                while f.read(WARM_CHUNK):
                    pass
        except OSError:
            # Nothing to do about a file that will not open, and the game will
            # complain about it far more clearly than this script could.
            pass
        FILE_QUEUE.task_done()

def warmCache():
    print("Warming the file cache...")
    count = 0
    for root, dirs, files in os.walk(BaseModPath):
        for file in files:
            FILE_QUEUE.put(os.path.join(root, file))
            count += 1
    print(f"Reading back {count} files")

    THREAD_POOL.clear()
    for _ in range(THREAD_AMOUNT):
        x = threading.Thread(target=warmJob, daemon=True)
        THREAD_POOL.append(x)
        x.start()

    while threads_running():
        print(f"Queue size: {FILE_QUEUE.qsize()} - Active threads: {ACTIVE_THREADS}", flush=True)
        time.sleep(1)
    print("File cache warmed")

def threads_running():
    n = 0
    for t in THREAD_POOL:
        if t.is_alive():
            n += 1
    global ACTIVE_THREADS
    ACTIVE_THREADS = n
    return n

def moveIt():
    time1 = time.time()
    clearTarget()
    addFiles()

    for _ in range(THREAD_AMOUNT):
        x = threading.Thread(target=job, args=(()), daemon=True)
        THREAD_POOL.append(x)
        x.start()

    while threads_running():
        print(f"Queue size: {FILE_QUEUE.qsize()} - Active threads: {ACTIVE_THREADS}", flush=True)
        time.sleep(1)

    if WARM_CACHE_AFTER_COPY:
        warmCache()

    time2 = time.time()
    rounded_time = round((time2 - time1), 2)
    print("All done! :)" )
    print("Took " + str(rounded_time) + " seconds")
    os.system("pause")

moveIt()
