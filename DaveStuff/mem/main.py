import time

from pymem import Pymem

from utils import utils


def write_out(out: str):
    with open("./tfh/mod/out.json", "w") as f:
        f.write(out)


def main():
    pm = Pymem("hoi3_tfh.exe")
    print(pm.base_address)
    res = pm.pattern_scan_all(
        pattern=utils.rawbytes(
            (pm.base_address + 0x11EC0B4).to_bytes(length=4, byteorder="little", signed=False).hex()
        ),
        return_multiple=True,
    )
    print(len(res))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(e)
        time.sleep(5)
