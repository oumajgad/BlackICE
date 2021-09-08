import os


### Looks for flags that get checked but are never set


folders = ["./events" , "./decisions"]

setflags = []
searchedflags = []

i = 0
j = 0

for folder in folders:
    for root, dirs, files in os.walk(folder):
        for file1 in files:
            with open(root + "/" + file1, "r" , errors="ignore") as file:
                #print(file.name)
                for line in file:
                    if "set_country_flag" in line and not line.strip().startswith("#"):
                        i += 1
                        flag = line.split("set_country_flag")[1].split("=")[1].strip().split(" ")[0].replace("}","").strip().lower()
                        #print(flag)
                        setflags.append(flag)
                        #if i % 10 == 0:
                            #os.system("pause")


for folder in folders:
    for root, dirs, files in os.walk(folder):
        for file1 in files:
            with open(root + "/" + file1, "r" , errors="ignore") as file:
                #print(file.name)
                for line in file:
                    if "has_country_flag" in line and not line.strip().startswith("#"):
                        j += 1
                        flag = line.split("has_country_flag")[1].split("=")[1].strip().split(" ")[0].replace("}","").strip().lower()
                        #print(flag)
                        searchedflags.append(flag)
                        #if flag == "4":
                            #print(line.split("has_country_flag")[1].split("=")[1].strip().split(" ")[0].replace("}","").strip().lower())
                            #os.system("pause")
                        #if j % 10 == 0:
                            #os.system("pause")

#remove duplicates from the lists
setflagsclean = list(dict.fromkeys(setflags))
searchedflagsclean = list(dict.fromkeys(searchedflags))

print("Flags checked, but not set!\n")

for searchedflag in searchedflagsclean:
    if searchedflag not in setflagsclean:
        print(searchedflag)