import glob
import os
import sys
import unicodedata
from googletrans import Translator

######### INFO ##########
# Populates common/countries with country language unit names
#########################

# Strip accents
def strip_accents(text):
    try:
        text = unicode(text, 'utf-8')
    except NameError: # unicode is a default on python 3 
        pass
    text = unicodedata.normalize('NFD', text)\
           .encode('ascii', 'ignore')\
           .decode("utf-8")
    return str(text)

# Strip accents and upper case word start
def prepare(text):
    return strip_accents(text).title()

#Languages for each country
languages = {
    "Afghanistan": "uz", #Persian/Pashto dont have pronounciation in Google Translate yet so use 3rd most used language, Uzbek
    "Portugal": "pt",
    "Communist China": "zh-cn",
    "Nationalist China": "zh-cn"
}

#Unit string
units = {
    "infantry_brigade": "Infantry Brigade",
    "light_infantry_brigade": "Light Infantry Brigade",
    "anti_tank_brigade": "Anti Tank Brigade"
}

#Setup translator
translator = Translator()

#Process each country file
print("Processing...", flush=True)
for path, subdirs, files in os.walk("common/countries/"):
    for file in files:
        if ".txt" in file:
            with open(os.path.join(path, file), 'r', errors='ignore') as data:
                text = data.read()

                print("\n" + file, flush=True)

                #Start of unit names
                if "unit_names" not in text:
                    continue
                unitNameStart = text.index("unit_names") + len("unit_names = {")

                #End of unit names
                unitNameEnd = 0
                bracketCount = 1
                for x in range(unitNameStart, len(text)):
                    if text[x] == "{":
                        bracketCount = bracketCount + 1
                    if text[x] == "}":
                        bracketCount = bracketCount - 1
                    if bracketCount == 0:
                        unitNameEnd = x
                        break

                #print(unitNameStart, flush=True)
                #print(text[unitNameStart], flush=True)
                #print(unitNameEnd, flush=True)
                #print(text[unitNameEnd], flush=True)

                #Check language exists
                if file[:-4] in languages:
                    #For each unit
                    f = open(os.path.join(path, file), "r+")
                    final = f.read(-1)
                    for key in units:

                        #Check unit names not already in file
                        if(key in text[unitNameStart:unitNameEnd]):
                            print(key + " already present, ignoring")
                            continue

                        #Translate
                        res = translator.translate(units[key], src="en", dest=languages[file[:-4]])

                        #Setup text
                        translation = ""
                        if res.pronunciation == None:
                            translation = prepare(res.text)
                        else:
                            translation = prepare(res.pronunciation)

                        print(units[key] + " -> " + translation, flush=True)

                        #Build sequence
                        sequence = ""
                        for i in range(1, 201):
                            instance = translation + " " + str(i)
                            instance = "\"" + instance + "\" "
                            sequence = sequence + instance
                        sequence = "\n\t" + key + " = { " + sequence + " }\n"

                        #Add sequence to correct position
                        final = final[:unitNameEnd] + sequence + final[unitNameEnd:]
                        unitNameEnd = unitNameEnd + len(sequence)     
                        
                    #Add to file
                    f.seek(0)
                    f.truncate()
                    f.write(final)

                    #Close file
                    f.close() 
                else:
                    print("Language not found")

        #break #One file for testing