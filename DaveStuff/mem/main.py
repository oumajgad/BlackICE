import json
import sys
from time import sleep

from pymem import Pymem

from classes.CCountry import CCountry


def main():
    pm = Pymem(int(sys.argv[1]))
    countries = CCountry.get_countries(pm)
    for ptr in countries:
        country = CCountry.make(pm, ptr)
        if country.tag == "GER":
            flags = country.get_country_flags(pm)
            out = {"flags": [flag.name for flag in flags]}
            with open("./out.txt", "w") as f:
                f.write(json.dumps(out, indent=2))
            print(json.dumps(out, indent=2))
            return


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(e)
        sleep(5)
