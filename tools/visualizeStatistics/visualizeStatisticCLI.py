import pandas as pd
import matplotlib.pyplot as plt
import os
import argparse

################# INFO #################
# Create Plots of collected statistics #
########################################
#
# Place the script within the Stats folder and run
#

def plot(version, ident, tag, stats):
    basePath = f"tfh\\mod\\BlackICE {version}"
    for stat in stats:
        if verify(basePath, ident=ident, tag=tag, stat=stat):
            plot_line(basePath, ident=ident, tag=tag,stat=stat)

    plt.show()


def plot_line(basePath, ident, tag, stat):    
    data = pd.read_csv(f".\\{basePath}\\stats\\{ident}\\{tag}\\{stat}")
    data = removeduplicates(data, [stat])
    dates = data["Date"]
    plt.plot(dates, data[stat], label=f"{tag}-{stat}")
    plt.legend()
    plt.xlabel("Day")
    plt.ylabel(stat)
    plt.grid(visible=True)
    plt.xlim(0)
    plt.ylim(0)
    plt.title("Stats")
    plt.autoscale()


# Removes duplicate dates from the dataset which can be introduced due to crashing or save reloading
def removeduplicates(data: pd.DataFrame, columns: list[str]):
    ret = {}
    ret["Date"] = {}
    for column in columns:
        ret[column] = {}
    highest_day = 0
    for k in ret.keys():
        x = 0
        for day in data["Date"]:
            if day > highest_day:
                highest_day = day
            elif day < highest_day:
                for j in range(day, highest_day + 1):
                    ret[k].pop(j, None)
                highest_day = day

            ret[k][day] = data[k][x]
            x += 1

    vals = {}
    for k in ret.keys():
        vals[k] = ret[k].values()
    return vals


def verify(basePath, ident, tag, stat):
    path = f".\\{basePath}\\stats\\{ident}\\{tag}\\{stat}"
    if len(tag) != 3:
        return False
    if os.path.exists(path):
        return True
    print(path)
    return False


def main():
    CLI=argparse.ArgumentParser()
    CLI.add_argument(
        "--version",
        type=str,
        default=None
    )
    CLI.add_argument(
        "--ident",
        type=int,
        default=None
    )
    CLI.add_argument(
        "--tag",
        type=str,
        default=None
    )
    CLI.add_argument(
        "--stats",
        nargs="*",
        type=str,
        default=None
    )
    args = CLI.parse_args()
    print(args.version)
    print(args.ident)
    print(args.tag)
    print(args.stats)
    version = args.version
    ident = args.ident
    tag = args.tag
    stats = args.stats
    plot(version, ident, tag, stats)

if __name__ == "__main__":
    try:
        print("Closing this window will also close the statistic window!")
        main()
    except Exception as e:
        print(e)
