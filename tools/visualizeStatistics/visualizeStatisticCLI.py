import matplotlib.pyplot as plt
import os
import sys

def plot(version, ident, tags, stats):
    basePath = f"tfh\\mod\\BlackICE {version}"
    for tag in tags:
        for stat in stats:
            if verify(basePath, ident=ident, tag=tag, stat=stat):
                plot_line(basePath, ident=ident, tag=tag,stat=stat)
    plt.show()


def plot_line(basePath, ident, tag, stat: str):
    file = f".\\{basePath}\\stats\\{ident}\\{tag}\\{stat}"
    dates, stats = read_csv(file, stat)
    print(dates)
    print(stats)
    dates, stats = removeduplicates(dates, stats)
    print(dates)
    print(stats)
    plt.plot(dates, stats)
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


def read_csv(file, stat):
    dates = list()
    stats = list()
    with open(file, "r") as file:
        lines = file.readlines()[1:]
        for line in lines:
            split = line.split(",")
            dates.append(int(split[0]))
            stats.append(float(split[1]))
    return dates, stats


def verify(basePath, ident, tag, stat):
    path = f".\\{basePath}\\stats\\{ident}\\{tag}\\{stat}"
    if len(tag) != 3:
        print(f"Not found: {tag}")
        return False
    if os.path.exists(path):
        return True
    print(f"Not found: {path}")
    return False


def main():
    print(sys.argv[1])
    print(sys.argv[2])
    print(sys.argv[3])
    print(sys.argv[4])
    version = sys.argv[1]
    ident = sys.argv[2]
    tags = sys.argv[3].split(",")
    stats = sys.argv[4].split(",")
    plot(version, ident, tags, stats)


if __name__ == "__main__":
    try:
        print("\nClosing this window will also close the statistic window!\n")
        main()
    except Exception as e:
        print(e)
