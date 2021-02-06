import glob
import os
import sys
import re

######### INFO ##########
# Print country starting laws
#########################

minimal_training_land_tech = []
basic_training_land_tech = []
advanced_training_land_tech = []
specialist_training_land_tech = []

minimal_training_air_tech = []
basic_training_air_tech = []
advanced_training_air_tech = []
specialist_training_air_tech = []

minimal_training_naval_tech = []
basic_training_naval_tech = []
advanced_training_naval_tech = []
specialist_training_naval_tech = []

for path, subdirs, files in os.walk("history/countries"):
    for file in files:
        with open(os.path.join(path, file), 'r', encoding="ISO-8859-1") as data:
            lines = data.readlines()
            for line in lines:
                if "minimal_training_land_tech" in line:
                    minimal_training_land_tech.append(file.split(" - ")[0])
                if "basic_training_land_tech" in line:
                    basic_training_land_tech.append(file.split(" - ")[0])
                if "advanced_training_land_tech" in line:
                    advanced_training_land_tech.append(file.split(" - ")[0])
                if "specialist_training_land_tech" in line:
                    specialist_training_land_tech.append(file.split(" - ")[0])

                if "minimal_training_air_tech" in line:
                    minimal_training_air_tech.append(file.split(" - ")[0])
                if "basic_training_air_tech" in line:
                    basic_training_air_tech.append(file.split(" - ")[0])
                if "advanced_training_air_tech" in line:
                    advanced_training_air_tech.append(file.split(" - ")[0])
                if "specialist_training_air_tech" in line:
                    specialist_training_air_tech.append(file.split(" - ")[0])

                if "minimal_training_naval_tech" in line:
                    minimal_training_naval_tech.append(file.split(" - ")[0])
                if "basic_training_naval_tech" in line:
                    basic_training_naval_tech.append(file.split(" - ")[0])
                if "advanced_training_naval_tech" in line:
                    advanced_training_naval_tech.append(file.split(" - ")[0])
                if "specialist_training_naval_tech" in line:
                    specialist_training_naval_tech.append(file.split(" - ")[0])

for country in minimal_training_land_tech:
    print("defaultLandTraining[\"" + country + "\"] = 27")
for country in basic_training_land_tech:
    print("defaultLandTraining[\"" + country + "\"] = 28")
for country in advanced_training_land_tech:
    print("defaultLandTraining[\"" + country + "\"] = 29")
for country in specialist_training_land_tech:
    print("defaultLandTraining[\"" + country + "\"] = 30")

for country in minimal_training_air_tech:
    print("defaultAirTraining[\"" + country + "\"] = 31")
for country in basic_training_air_tech:
    print("defaultAirTraining[\"" + country + "\"] = 32")
for country in advanced_training_air_tech:
    print("defaultAirTraining[\"" + country + "\"] = 33")
for country in specialist_training_air_tech:
    print("defaultAirTraining[\"" + country + "\"] = 34")

for country in minimal_training_naval_tech:
    print("defaultNavalTraining[\"" + country + "\"] = 35")
for country in basic_training_naval_tech:
    print("defaultNavalTraining[\"" + country + "\"] = 36")
for country in advanced_training_naval_tech:
    print("defaultNavalTraining[\"" + country + "\"] = 37")
for country in specialist_training_naval_tech:
    print("defaultNavalTraining[\"" + country + "\"] = 38")