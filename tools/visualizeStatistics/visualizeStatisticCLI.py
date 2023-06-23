import matplotlib.pyplot as plt
import os
import sys
import time

from mplcursors import cursor  # separate package must be installed


def plot():
    basePath = f"tfh\\mod\\BlackICE {Version}"
    for tag in Tags:
        for stat in Stats:
            if verify(basePath, tag, stat):
                plot_line(basePath, tag, stat)
    cursor(hover=True)
    plt.show()


def plot_line(basePath, tag, stat):
    file = f".\\{basePath}\\stats\\{Ident}\\{tag}\\{stat}"
    dates, stats = read_csv(file)
    dates, stats = removeduplicates(dates, stats)
    plt.plot(dates, stats, ls="-.", label=f"{tag}-{stat}")
    plt.legend()
    plt.xlabel("Day")
    plt.ylabel(stat)
    plt.grid(visible=True)
    plt.xlim(0)
    plt.ylim(0)
    plt.title("Stats")
    plt.autoscale()


# Removes duplicate dates from the dataset which can be introduced due to crashing or save reloading
def removeduplicates(dates, stats):
    ret_dates = list()
    ret_stats = list()
    highest_day = 0
    x = 0
    for day in dates:
        if day > highest_day:
            highest_day = day
        elif day < highest_day:
            for j in range(len(ret_dates)):
                if ret_dates[j] >= day:
                    ret_dates = ret_dates[:j]
                    ret_stats = ret_stats[:j]
                    break
            highest_day = day

        ret_dates.append(day)
        ret_stats.append(stats[x])
        x += 1

    return ret_dates, ret_stats


def read_csv(file):
    dates = list()
    stats = list()
    with open(file, "r") as file:
        lines = file.readlines()[1:]
        for line in lines:
            split = line.split(",")
            dates.append(int(split[0]))
            stats.append(float(split[1]))
    return dates, stats


def verify(basePath, tag, stat):
    if not stat or stat.strip() == "" or not tag or tag == "":
        return False
    path = f".\\{basePath}\\stats\\{Ident}\\{tag}\\{stat}"
    if len(tag) != 3:
        print(f"Not found: {tag}")
        return False
    if os.path.exists(path):
        return True
    print(f"Not found: {path}")
    return False


def main():
    plot()


if __name__ == "__main__":
    try:
        print(f"Args: {sys.argv[1]} {sys.argv[2]} {sys.argv[3]} {sys.argv[4]}")
        Version = sys.argv[1]
        Ident = sys.argv[2]
        Tags = sys.argv[3].split(",")
        Stats = sys.argv[4].split(",")
        print("\nClosing this window will also close the statistic window!\n")
        main()
    except Exception as e:
        print(e)
        time.sleep(5)
