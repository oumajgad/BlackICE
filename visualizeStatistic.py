def plot_line_ls():
    import pandas as pd
    import matplotlib.pyplot as plt

    data = pd.read_csv('GER_LsSlidersPercentage')
    dates = data["Date"]
    plt.plot(dates, data["Research"], label="Research")
    plt.plot(dates, data["Spies"], label="Spies")
    plt.plot(dates, data["Diplo"], label="Diplo")
    plt.plot(dates, data["Officers"], label="Officers")
    plt.legend()
    plt.xlabel("Day")
    plt.ylabel("Investments %")
    plt.grid()
    plt.xlim(0)
    plt.ylim(0)
    plt.title("Leadershipsliders")
    plt.show()


def plot_line_icEfficiency():
    import pandas as pd
    import matplotlib.pyplot as plt

    data = pd.read_csv('GER_ICEfficiency')
    data = removeduplicates(data, ["ICEfficiency"])
    dates = data["Date"]
    plt.plot(dates, data["ICEfficiency"], label="ICEfficiency")
    plt.legend()
    plt.xlabel("Day")
    plt.ylabel("IC Efficiency")
    plt.grid()
    plt.xlim(0)
    plt.ylim(0)
    plt.title("ICEfficiency")
    plt.show()


def plot_line_ic():
    import pandas as pd
    import matplotlib.pyplot as plt

    data = pd.read_csv('GER_EffectiveIC')
    data = removeduplicates(data, ["EffectiveIC"])
    dates = data["Date"]
    plt.plot(dates, data["EffectiveIC"], label="EffectiveIC")
    plt.legend()
    plt.xlabel("Day")
    plt.ylabel("Effective IC")
    plt.grid()
    plt.xlim(0)
    plt.ylim(0)
    plt.title("EffectiveIC")
    plt.show()


def plot_bar():
    import pandas as pd
    import matplotlib.pyplot as plt
    import numpy as np

    data = pd.read_csv('GER_LsSlidersPercentage')
    dates = data["Date"]
    dates_range = np.arange(len(dates))
    width = 0.2
    plt.bar(dates_range - width, data["Research"], label="Research", width=width)
    plt.bar(dates_range, data["Spies"], label="Spies", width=width)
    plt.bar(dates_range + width, data["Diplo"], label="Diplo", width=width)
    plt.bar(dates_range + width * 2 , data["Officers"], label="Officers", width=width)
    plt.legend()
    plt.xlabel("Day")
    plt.xticks(ticks=dates_range, labels=dates)
    plt.ylabel("Investments %")
    plt.grid()
    plt.xlim(0)
    plt.ylim(0)
    plt.title("Leadershipsliders")
    plt.show()


import pandas as pd
# Removes duplicate dates from the dataset which can be introduced due to crashing or save reloading
def removeduplicates(data: pd.DataFrame, columns: list[str]):
    ret = {}
    ret["Date"] = [None] * (len(data["Date"]))
    for column in columns:
        ret[column] = [None] * (len(data["Date"]))

    for day in data["Date"]:
        ret["Date"][day - 1] = day
        for column in columns:
            ret[column][day - 1] = data[column][day - 1]

    for c in ret:
        ret[c] = [x for x in ret[c] if x is not None]

    return ret

if __name__ == "__main__":
    plot_line_icEfficiency()
