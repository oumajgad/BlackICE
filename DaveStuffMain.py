from tkinter import *
import os
import time

folder = "DaveStuff/"

main = Tk()
main.title("MainMenu")


def getExec(name, index):

    buttons = [b_unitLeaders, b_ProdQuUnits, b_EventModifiers, b_UnitUpgrades, b_EventIDs, b_countryStats]

    os.system('cls')
    main.withdraw()
    os.system("python " + folder + name)
    main.deiconify()


b_unitLeaders = Button(main, text="unitLeaders", width=25, command= lambda: getExec("unitLeaders.py", 0 ))
b_ProdQuUnits = Button(main, text="ProdQuUnits", width=25, command= lambda: getExec("ProdQuUnits.py", 1 ))
b_EventModifiers = Button(main, text="EventModifiers", width=25, command= lambda: getExec("EventModifiers.py", 2 ))
b_UnitUpgrades = Button(main, text="UnitUpgrades", width=25, command= lambda: getExec("UnitUpgrades.py", 3 ))
b_EventIDs = Button(main, text="EventIDs", width=25, command= lambda: getExec("EventIDs.py", 4 ))
b_countryStats = Button(main, text="countryStats", width=25, command= lambda: getExec("countryStats.py", 5 ))

b_unitLeaders.grid(row=0, column=0, padx=10, pady=10)
b_ProdQuUnits.grid(row=1, column=0, padx=10, pady=10)
b_EventModifiers.grid(row=0, column=1, padx=10, pady=10)
b_UnitUpgrades.grid(row=1, column=1, padx=10, pady=10)
b_EventIDs.grid(row=2, column=0, padx=10, pady=10)
b_countryStats.grid(row=2, column=1, padx=10, pady=10)



main.mainloop()
