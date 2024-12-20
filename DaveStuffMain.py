from tkinter import *
import os

folder = "DaveStuff/"

main = Tk()
main.title("MainMenu")


def runExec(name):


    os.system('cls')
    main.withdraw()
    os.system("python " + folder + name)
    main.deiconify()


b_unitLeaders       = Button(main, text="unitLeaders",      width=25, command= lambda: runExec("unitLeaders.py"))
b_EventModifiers    = Button(main, text="EventModifiers",   width=25, command= lambda: runExec("EventModifiers.py"))
b_ProdQuUnits       = Button(main, text="ProdQuUnits",      width=25, command= lambda: runExec("ProdQuUnits.py"))
b_EventIDs          = Button(main, text="EventIDs",         width=25, command= lambda: runExec("EventIDs.py"))
b_countryStats      = Button(main, text="countryStats",     width=25, command= lambda: runExec("countryStats.py"))
b_unitInfraCheck    = Button(main, text="unitInfraCheck",   width=25, command= lambda: runExec("unitInfraCheck.py"))
b_techParser        = Button(main, text="techParser",       width=25, command= lambda: runExec("techParser.py"))
b_modelBuilder      = Button(main, text="modelBuilder",     width=25, command= lambda: runExec("modelBuilder.py"))
b_flagCheck         = Button(main, text="flagCheck",        width=25, command= lambda: runExec("flagCheck.py"))
b_leaderCheck       = Button(main, text="leaderCheck",      width=25, command= lambda: runExec("leaderCheck.py"))

b_unitLeaders.grid          (row=0, column=0, padx=10, pady=10)
b_EventModifiers.grid       (row=0, column=1, padx=10, pady=10)
b_ProdQuUnits.grid          (row=1, column=0, padx=10, pady=10)
b_leaderCheck.grid          (row=1, column=1, padx=10, pady=10)
b_EventIDs.grid             (row=2, column=0, padx=10, pady=10)
b_countryStats.grid         (row=2, column=1, padx=10, pady=10)
b_unitInfraCheck.grid       (row=3, column=0, padx=10, pady=10)
b_techParser.grid           (row=3, column=1, padx=10, pady=10)
b_modelBuilder.grid         (row=4, column=0, padx=10, pady=10)
b_flagCheck.grid            (row=4, column=1, padx=10, pady=10)

main.mainloop()

