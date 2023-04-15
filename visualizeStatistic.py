import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import tkinter as tk
import os

def plot_line_LsSlidersPercentage():
    tag = prep("LsSlidersPercentage")
    if not tag:
        return
    data = pd.read_csv(f'{tag}_LsSlidersPercentage')
    dates = data["Date"]
    plt.plot(dates, data["Research"], label="Research")
    plt.plot(dates, data["Spies"], label="Spies")
    plt.plot(dates, data["Diplo"], label="Diplo")
    plt.plot(dates, data["Officers"], label="Officers")
    plt.legend()
    plt.xlabel("Day")
    plt.ylabel("Investments %")
    plt.grid(visible=True)
    plt.xlim(0)
    plt.ylim(0)
    plt.title("Leadershipsliders")
    plt.show()


def plot_bar_LsSlidersPercentage():
    tag = prep("LsSlidersPercentage")
    if not tag:
        return
    data = pd.read_csv(f'{tag}_LsSlidersPercentage')
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
    plt.grid(visible=True)
    plt.xlim(0)
    plt.ylim(0)
    plt.title("Leadershipsliders")
    plt.show()


def plot_line_ICEfficiency():
    tag = prep("ICEfficiency")
    if not tag:
        return
    
    data = pd.read_csv(f'{tag}_ICEfficiency')
    data = removeduplicates(data, ["ICEfficiency"])
    dates = data["Date"]
    plt.plot(dates, data["ICEfficiency"], label=f"{tag}")
    plt.legend()
    plt.xlabel("Day")
    plt.ylabel("IC Efficiency")
    plt.grid(visible=True)
    plt.xlim(0)
    plt.ylim(0)
    plt.title("ICEfficiency")
    plt.show()


def plot_line_EffectiveIC():
    tag = prep("EffectiveIC")
    if not tag:
        return
    data = pd.read_csv(f'{tag}_EffectiveIC')
    data = removeduplicates(data, ["EffectiveIC"])
    dates = data["Date"]
    plt.plot(dates, data["EffectiveIC"], label=f"{tag}")
    plt.legend()
    plt.xlabel("Day")
    plt.ylabel("Effective IC")
    plt.grid(visible=True)
    plt.xlim(0)
    plt.ylim(0)
    plt.title("EffectiveIC")
    plt.show()



# Removes duplicate dates from the dataset which can be introduced due to crashing or save reloading
def removeduplicates(data: pd.DataFrame, columns: list[str]):
    ret = {}
    ret["Date"] = {}
    for column in columns:
        ret[column] = {}
    x = 0
    for day in data["Date"]:
        for k in ret.keys():
            ret[k][day] = data[k][x]
        x += 1

    vals = {}
    for k in ret.keys():
        vals[k] = ret[k].values()
    return vals


def prep(file: str):
    if same_chart.get() == 0:
        plt.figure()
    tag = e_TAG.get()
    if len(tag) != 3:
        return False
    if os.path.exists(f"{tag}_{file}"):
        return tag
    return False



app = tk.Tk()
app.title("visualizeStatistics.py")

e_TAG = tk.Entry(app, width=25, border=5)

same_chart = tk.IntVar()
same_chart.set(0)
cb = tk.Checkbutton(app, text="Same Chart", variable=same_chart, onvalue=1, offvalue=0)


button_icEfficiency = tk.Button(app, text="IC Efficiency", width=25, command= lambda: plot_line_ICEfficiency())
button_EffectiveIC = tk.Button(app, text="Effective IC", width=25, command= lambda: plot_line_EffectiveIC())
button_lsPercentage_line = tk.Button(app, text="LS Sliders % - Line", width=25, command= lambda: plot_line_LsSlidersPercentage())



e_TAG.grid(row=0, column=0)
cb.grid(row=0, column=1)
button_icEfficiency.grid(row=1, column=0)
button_EffectiveIC.grid(row=1, column=1)
button_lsPercentage_line.grid(row=2, column=0)
if __name__ == "__main__":
    app.mainloop()
