import sys
import time

from pymem import Pymem

from classes.CCountry import dump_country


def write_out(out: str):
    with open("./tfh/mod/out.json", "w") as f:
        f.write(out)


def main():
    pm = Pymem(int(sys.argv[1]))
    if sys.argv[2] == "country":
        write_out(dump_country(pm, sys.argv[3]))
        # print(dump_country(pm, sys.argv[3]))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(e)
        time.sleep(5)
