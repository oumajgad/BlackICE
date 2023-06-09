import pandas as pd
import matplotlib.pyplot as plt
import tkinter as tk
import os

################# INFO #################
# Create Plots of collected statistics #
########################################
#
# Place the script within the Stats folder and run
#

def plot_line(tag = None, stat = None, forceSameChart = False):
    if not tag or not stat:
        tag, stat = verify(forceSameChart)

    if not tag:
        return
    
    data = pd.read_csv(f'{tag}_{stat}')
    data = removeduplicates(data, [stat])
    dates = data["Date"]
    plt.plot(dates, data[stat], label=f"{tag}-{stat}")
    plt.legend()
    plt.xlabel("Day")
    plt.ylabel(f"{tag}-{stat}")
    plt.grid(visible=True)
    plt.xlim(0)
    plt.ylim(0)
    plt.title(stat)
    plt.autoscale()
    plt.show()

def plot_line_no_show(tag = None, stat = None, forceSameChart = False, title=None):

    if not title:
        title = stat
    if not tag or not stat:
        tag, stat = verify(forceSameChart)
    else:
        verify(forceSameChart)

    if not tag:
        return
    
    data = pd.read_csv(f'{tag}_{stat}')
    data = removeduplicates(data, [stat])
    dates = data["Date"]
    plt.plot(dates, data[stat], label=f"{tag}-{stat}")
    plt.legend()
    plt.xlabel("Day")
    plt.ylabel(title)
    plt.grid(visible=True)
    plt.xlim(0)
    plt.ylim(0)
    plt.title(title)


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


def verify(forceSameChart):
    tag = e_TAG.get()
    stat = lb_STAT.get(lb_STAT.curselection())
    if same_chart.get() == 0 and not forceSameChart:
        plt.figure()
    if len(tag) != 3:
        return False
    if os.path.exists(f"{tag}_{stat}"):
        return tag, stat
    return False


def quickStart():
    tag = e_TAG.get()
    if len(tag) != 3:
        return
    plot_line_no_show(tag, "domSpy", False)
    plot_line_no_show(tag, "FreeSpies", True, "Spies")

    plot_line_no_show(tag, "TotalSpiesAbroad", False)

    plot_line_no_show(tag, "PercentEspionage", False)

    # plot_line_no_show(tag, "Popularity_fascistic", False)
    # plot_line_no_show(tag, "Popularity_left_wing_radical", True)
    # plot_line_no_show(tag, "Popularity_leninist", True)
    # plot_line_no_show(tag, "Popularity_market_liberal", True)
    # plot_line_no_show(tag, "Popularity_national_socialist", True)
    # plot_line_no_show(tag, "Popularity_paternal_autocrat", True)
    # plot_line_no_show(tag, "Popularity_social_conservative", True)
    # plot_line_no_show(tag, "Popularity_social_democrat", True)
    # plot_line_no_show(tag, "Popularity_social_liberal", True)
    # plot_line_no_show(tag, "Popularity_stalinist", True, "Popularity")

    plot_line_no_show(tag, "Popularity_Group_communism", False)
    plot_line_no_show(tag, "Popularity_Group_democracy", True)
    plot_line_no_show(tag, "Popularity_Group_fascism", True, "Popularity Group")
    plt.autoscale()
    plt.show()


def setPossibleStatSelection():
    stats = set()
    for root, dirs, files in os.walk("./"):
        for file in files:
            if file in ["visualizeStatistic.py", "zzSetup"]:
                continue
            stat_name = file[4:]
            stats.add(stat_name)
    stats = list(stats)
    stats = sorted(stats)
    for i in range(len(stats)):
        lb_STAT.insert(i, stats[i])


app = tk.Tk()
app.title("visualizeStatistics.py")

e_TAG = tk.Entry(app, width=25, border=5)
e_TAG.insert(0, "Enter TAG")

lb_STAT = tk.Listbox(app, selectmode=tk.SINGLE, width=40, height=20)

same_chart = tk.IntVar()
same_chart.set(0)
cb = tk.Checkbutton(app, text="Same Chart", variable=same_chart, onvalue=1, offvalue=0)


button_ShowLine = tk.Button(app, text="Show Line", width=25, command= lambda: plot_line())
button_QuickStart = tk.Button(app, text="Party & Spies", width=25, command= lambda: quickStart())



e_TAG.grid(row=0, column=0, padx=10, pady=10)
lb_STAT.grid(row=0, column=1, padx=10, pady=10)
cb.grid(row=0, column=2, padx=10, pady=10)
button_ShowLine.grid(row=1, column=0, padx=10, pady=10)
button_QuickStart.grid(row=1, column=1, padx=10, pady=10)
if __name__ == "__main__":
    setPossibleStatSelection()
    app.mainloop()
