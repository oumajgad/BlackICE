import glob
import os
import sys
import unicodedata
from googletrans import Translator

######### INFO ##########
# Populates common/countries with country language unit names
#########################
# https://py-googletrans.readthedocs.io/en/latest/

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
    "Germany": "de",
    "Reichkommissariat Ostland": "de",
    "Reichkommissariat Ukraine": "de",
    "Reichkommissariat Moskowien": "de",
    "Reichkommissariat Kaukasien": "de",
    "Reichkommissariat Ural": "de",
    "United Kingodm": "en",
    "Soviet Union": "ru",
    "USA": "en",
    "Japan": "ja",
    "Italy": "it",
    "France": "fr",
    "Denmark": "da",
    "Iceland": "is",
    "Estonia": "et",
    "Finland": "fi",
    "Latvia": "la",
    "Lithuania": "lt",
    "Norway": "no",
    "Sweden": "sv",
    "Belgium": "nl",
    "Netherlands": "nl",
    "Ireland": "ga",
    "Luxemburg": "lb",
    "Vichy France": "fr",
    "Austria": "de",
    "Czechoslovakia": "cs",
    "Croatia": "hr",
    "DDR": "de",
    "FRG": "de",
    "Hungary": "hu",
    "Poland": "pl",
    "Romania": "ro",
    "Slovakia": "sk",
    "Switzerland": "de",
    "Malta": "en",
    "Portugal": "pt",
    "Italian Social Republic": "it",
    "Nationalist Spain": "es",
    "Republican Spain": "es",
    "Albania": "sq",
    "Bulgaria": "bg",
    "Cyprus": "el",
    "Greece": "el",
    "Yugoslavia": "hr",
    "Montenegro": "hr",
    "Serbia": "hr",
    "Slovenia": "sl",
    "Ukraine": "uk",
    "Belarus": "be",
    "Armenia": "hy",
    "Azerbaijan": "az",
    "Georgia": "ka",
    "Afghanistan":"uz", #Persian/Pashto dont have pronounciation in Google Translate yet so use 3rd most used language, Uzbek
    "Iraq": "ar",
    "Jordan": "ar",
    "Lebanon": "ar",
    "Oman": "ar",
    "Palestine": "ar",
    "Persia": "az", #Persian dont have pronounciation in Google Translate yet so use 2nd most used Azerbaijani
    "Saudi Arabia": "ar",
    "Syria": "ar",
    "Turkey": "tr",
    "Yemen": "ar",
    "Kuwait": "ar",
    "Bhutan": "ne",
    "India": "hi",
    "Nepal": "ne",
    "Pakistan": "ur",
    "British India": "en",
    "British Burma": "en",
    "Guangxi Clique": "zh-tw",
    "Communist China": "zh-tw",
    "Nationalist China": "zh-tw",
    "Shanxi": "zh-tw",
    "Xibei San Ma": "zh-tw",
    "Yunnan": "zh-tw",
    "Korea": "ko",
    "Manchukuo": "zh-tw",
    "Mengkukuo": "zh-tw",
    "Mongolia": "mn",
    "Republic of China-Nanjing": "zh-tw",
    "People's Republic of Korea": "ko",
    "Sinkiang": "ug",
    "Tannu Tuva": "ru",
    "Tibet": "zh-tw",
    "Indochina": "vi",
    "Indonesia": "id",
    "Philippines": "tl",
    "Siam": "th",
    "Egypt": "ar",
    "Liberia": "ar",
    "Ethiopia": "am",
    "South Africa": "af",
    "Sudan": "ar",
    "Somalia": "ar",
    "Madagascar": "mg",
    "Australia": "en",
    "New Zealand": "en",
    "Papua New Guinea": "en",
    "Canada": "en",
    "Cuba": "es",
    "Costa Rica": "es",
    "Dominican Republic": "es",
    "Guatemala": "es",
    "Haiti": "es",
    "Honduras": "es",
    "Mexico": "es",
    "Nicaragua": "es",
    "Panama": "es",
    "El Salvador": "es",
    "Argentina": "es",
    "Bolivia": "es",
    "Brazil": "pt",
    "Chile": "es",
    "Colombia": "es",
    "Ecuador": "es",
    #"Guyana": "es",
    "Paraguay": "es",
    "Peru": "es",
    "Uruguay": "es",
    "Venezuela": "es",
    "Suriname": "es"
}

#TODO Unit dictionary
units = {
    #Land
    "hq_brigade": "headquarters",

    "garrison_brigade": "garrison",
    "tropical_island_garrison_brigade": "tropical garrison",
    "garrison_detachment": "garrison detachment",
    "infantry_brigade": "infantry division",
    "infantry_bat": "infantry battalion",
    "light_infantry_brigade": "light infantry division",
    "elite_light_infantry_brigade": "elite light infantry division",
    "elite_light_infantry_battalion": "elite light infantry battalion",
    "commando_brigade": "special forces battalion",
    "militia_brigade": "militia brigade",
    "Communist_militia_brigade": "communist militia brigade",
    "fascist_militia_brigade": "fascist militia brigade",
    "police_brigade": "military police brigade",
    "conscript_brigade": "conscript brigade",
    "partisan_brigade": "partisan brigade",
    "bergsjaeger_brigade": "mountain infantry division",
    "naval_infantry_brigade": "naval infantry division",
    "marine_brigade": "marine division",
    "paratrooper_brigade": "paratrooper division",
    "airlanding_infantry_brigade": "airlanding infantry division",
    "ski_brigade": "ski division",

    "colonial_militia_brigade": "colonial militia brigade",
    "colonial_garrison_brigade": "colonial garrison",
    "colonial_cavalry_brigade": "colonial cavalry division",
    "colonial_bergsjaeger_brigade": "colonial mountain division",
    "colonial_light_infantry_brigade": "colonial light infantry division",
    "colonial_infantry_brigade": "colonial infantry division",

    "artillery_brigade": "artillery brigade",
    "medium_artillery_brigade": "medium artillery brigade",
    "heavy_artillery_brigade": "heavy artillery brigade",
    "pack_artillery_brigade": "mountain artillery brigade",
    "rocket_artillery_brigade": "rocket brigade",

    "horse_transport": "horse transport",
    "camel_transport": "camel transport",
    "light_transport": "light vehicle transport",
    "civilian_truck_transport": "civilian truck transport",
    "truck_transport": "truck transport",
    "hftrack_transport": "halftrack transport",

    "engineer_brigade": "engineer brigade",
    "motorized_engineer_brigade": "motorized engineer brigade",
    "armored_engineers_brigade": "armored engineer brigade",

    "airborne_engineer_bat": "airborne engineer brigade",
    "airborne_artillery_brigade": "airborne artillery brigade",
    "airborne_combined_arms_brigade": "airborne support brigade",

    "mixed_support_brigade": "mixed support brigade",
    "motorized_support_brigade": "motorized support brigade",
    "armored_support_brigade": "armored support brigade",

    "anti_tank_brigade": "anti tank brigade",
    "heavy_anti_tank_brigade": "heavy anti tank brigade",

    "anti_air_brigade": "anti aircraft brigade",
    "heavy_anti_air_brigade": "heavy anti aircraft brigade",
    
    "Recon_cavalry_brigade": "reconnaissance Cavalry brigade",
    "motorcycle_recon_brigade": "reconnaissance Motorcycle brigade",
    "armored_car_brigade": "armored car brigade",

    "cavalry_brigade": "cavalry division",
    "semi_motorized_brigade": "semi motorized division",
    "motorized_brigade": "motorized division",
    "motorized_infantry_bat": "motorized battalion",
    "mechanized_brigade": "mechanized division",
    "mechanized_infantry_bat": "mechanized battalion",

    "assault_gun_brigade": "assault gun division",
    "heavy_assault_gun_brigade": "heavy assault gun division",

    "amph_armour_brigade": "amphibious tank division",
    "light_armor_bat": "light tank battalion",
    "light_armor_brigade": "light tank division",
    "armor_bat": "tank battalion",
    "armor_brigade": "tank division",
    "heavy_armor_brigade": "heavy tank division",
    "super_heavy_armor_brigade": "super heavy tank division",
    "infantry_tank_brigade": "infantry tank division",

    "air_cavalry_brigade": "air cavalry division",

    "sp_artillery_brigade": "self propelled artillery brigade",
    "sp_anti_air_brigade": "self propelled anti aircraft brigade",
    "sp_rct_artillery_brigade": "self propelled rocket division",

    "tank_destroyer_brigade": "tank destroyer brigade",
    "medium_tank_destroyer_brigade": "medium tank destroyer brigade",
    "heavy_tank_destroyer_brigade": "heavy tank destroyer brigade",

    #Air
    "interceptor": "fighter squadron",
    "multi_role": "fighter-bomber squadron",
    "cas": "close-air-support squadron",
    "twin_engine_fighters": "twin engine fighter squadron",
    "transport_plane": "transport squadron",
    "tactical_bomber": "bomber squadron",
    "light_bomber": "light bomber squadron",
    "strategic_bomber": "heavy bomber squadron",
    "rocket_interceptor": "rocket fighter squadron",
    "naval_bomber": "naval bomber squadron",
    #"jet_fighter": "jet fighter squadron",
    "gliders": "glider squadron",
    "flying_rocket": "flying rocket",
    "flying_bomb": "flying bomb",
    "Flying_boat": "flying boat squadron",
    "cag": "aircraft carrier air group",
    "quad_engine_transport": "heavy transport squadron",

    #Navy minor vessels and submarines
    "submarine": "submarine",
    "coastal_submarine": "coastal submarine",
    "long_range_submarine": "long range submarine",
    "electro_submarine": "electric submarine",
    "nuclear_submarine": "nuclear submarine",

    "transport_ship": "transport ship",
    "seaplane_tender": "seaplane carrier",
    "Convoy_raider_ship": "auxiliary cruiser",

    "torpedo_boat": "torpedo boat",
    "motor_torpedo_boat": "motor torpedo boat",

    "frigate": "frigate",

    #Navy major vessels (these should use city/town/region names)
    #"destroyer_actual": "destroyer",
    #"light_cruiser": "light cruiser",    
    #"heavy_cruiser": "heavy cruiser",
    #"battlecruiser": "battlecruiser",
    #"battleship": "battleship",
    #...
}

#Setup translator
translator = Translator()

#Process each country file
print("Processing...", flush=True)
for path, subdirs, files in os.walk("common/countries/"):
    for file in files:
        if ".txt" in file:
            with open(os.path.join(path, file), 'r', errors='ignore') as data:

                #Setup translator again (Avoid API exceptions for too many requests)
                translator = Translator()
                
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

                        print("\t" + units[key] + " -> " + translation, flush=True)

                        #Build sequence
                        sequence = ""
                        for i in range(1, 101):
                            if i % 10 == 0:
                                sequence = sequence + "\n"
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