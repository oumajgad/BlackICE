import glob
import shutil
import os
import sys

######### INFO ##########
# Organize history/units
#########################

toOrg = []
for oob in os.listdir(os.getcwd() + "/history/units/"):

    #Patterns
    folder = ""
    if oob.startswith("GER_") or "_GER_" in oob or "-SS-" in oob or "_ger" in oob or oob.startswith("ger_") or "-GER_" in oob or "-GER-" in oob or oob.startswith("SS_") or oob.startswith("Osttruppen"):
        folder = "GER"
    if oob.startswith("SOV_") or "_SOV_" in oob or "-SOV_" in oob or "-SOV-" in oob or "_sov" in oob or oob.startswith("Red_") or oob.startswith("red_") or oob.startswith("proletariet_"):
        folder = "SOV"
    if oob.startswith("FRA_") or "_FRA_" in oob or "-FRA_" in oob:
        folder = "FRA"
    if oob.startswith("ENG_") or "_ENG_" in oob or "_UK_" in oob or "-UK_" in oob or "_RAF." in oob or oob.startswith("eng_") or "-UK-" in oob:
        folder = "ENG"
    if oob.startswith("JAP_") or "_JAP_" in oob or "_jap" in oob or oob.startswith("Collab_") or "-JAP_" in oob or "-JAP-" in oob or "_Japan_" in oob or oob.startswith("jap_"):
        folder = "JAP"
    if oob.startswith("ITA_") or "_ITA_" in oob or "_ita" in oob or "-ITA_" in oob:
        folder = "ITA"
    if oob.startswith("USA_") or "_USA_" in oob or "-USA_" in oob or "_US_" in oob or oob.startswith("USPacificGarrison") or oob.startswith("usa-") or oob.startswith("usa_") or oob.startswith("DDay_"):
        folder = "USA"
    if oob.startswith("YUG_") or "_YUG_" in oob:
        folder = "YUG"
    if oob.startswith("can_") or oob.startswith("CAN_") :
        folder = "CAN"
    if "-ROM_" in oob or "-ROM-" in oob:
        folder = "ROM"
    if oob.startswith("SPA_") or "-SPA_" in oob:
        folder = "SPA"
    if oob.startswith("SPR_") or "-SPR_" in oob:
        folder = "SPR"
    if oob.startswith("FIN_") or oob.startswith("Finlandair") or "-FIN_" in oob:
        folder = "FIN"
    if "-AST_" in oob:
        folder = "AST"
    if "-Vichy_" in oob:
        folder = "Vichy"

    #No pattern found
    if folder == "":
        continue

    print(oob, flush=True)

    foundReferene = False

    #Find load_oob and replace in events
    for event in os.listdir(os.getcwd() + "/events/"):
        #print("\t" + event, flush=True)
        data = ""
        with open(os.path.join(os.getcwd() + "/events/", event), 'r', encoding="ISO-8859-1") as file:
            data = file.read()

            if oob not in data and (folder + "/" + oob) not in data:
                continue

            print("\tFound OOB in events")
            data = data.replace(oob, folder + "/" + oob)

            foundReferene = True

        if folder != "":
            f = open(os.path.join(os.getcwd() + "/events/", event), "w", encoding="ISO-8859-1")
            f.write(data)
            f.close()

    #Find load_oob and replace in decisions
    for decision in os.listdir(os.getcwd() + "/decisions/"):
        #print("\t" + decision, flush=True)
        data = ""
        with open(os.path.join(os.getcwd() + "/decisions/", decision), 'r', encoding="ISO-8859-1") as file:
            data = file.read()

            if oob not in data and (folder + "/" + oob) not in data:
                continue

            print("\tFound OOB in decisions")
            data = data.replace(oob, folder + "/" + oob)

            foundReferene = True

        if folder != "":
            f = open(os.path.join(os.getcwd() + "/decisions/", decision), "w", encoding="ISO-8859-1")
            f.write(data)
            f.close()        

    #Move to folder if found reference
    if foundReferene and folder != "":
        if not os.path.isdir('./history/units/' + folder):
            os.mkdir('./history/units/' + folder)
        shutil.move("./history/units/" + oob, "./history/units/" + folder + "/" + oob)
    #Move to unused folder if not found and not 1936 OOB
    elif "1936." not in oob and folder != "":
        if not os.path.isdir('./history/units/Unused'):
            os.mkdir('./history/units/Unused')
        shutil.move("./history/units/" + oob, "./history/units/Unused/" + oob)