import mmap
import os


def ReadHex(file: str, offset: int, length: int):
    with open(file, "rb+") as file:
        mm = mmap.mmap(file.fileno(), 0)
        mm.seek(offset, os.SEEK_SET)
        return mm.read(length).hex()


def WriteHex(file: str, offset: int, hex_n: str):
    with open(file, "rb+") as file:
        mm = mmap.mmap(file.fileno(), 0)
        mm.seek(offset, os.SEEK_SET)
        mm.write(bytes.fromhex(hex_n))


def PatchLargeAddressAware():
    print("PatchLargeAddressAware")
    WriteHex("hoi3_tfh.exe", 0x138, "9165E5")
    WriteHex("hoi3_tfh.exe", 0x146, "22")
    WriteHex("hoi3_tfh.exe", 0x188, "67B1")
    WriteHex("hoi3_tfh.exe", 0x1180524, "9165E5")
    WriteHex("hoi3_tfh.exe", 0x11FB60D, "313A35363A3436")
    WriteHex("hoi3_tfh.exe", 0x11FB618, "4A616E202033")
    WriteHex("hoi3_tfh.exe", 0x11FB622, "33")
    WriteHex("hoi3_tfh.exe", 0x120D77C, "6E68DAD73DE05F4394C72CD557D09411")
    WriteHex("hoi3_tfh.exe", 0x12F34B4, "4C64E5")
    print("LAA done")


def PatchMinisterTechDecay():
    print("PatchMinisterTechDecay")
    print(f'Old: {ReadHex("hoi3_tfh.exe", 0xDD7ED, 1)}')
    WriteHex("hoi3_tfh.exe", 0xDD7ED, "01")
    print(f'New: {ReadHex("hoi3_tfh.exe", 0xDD7ED, 1)}')


def PatchMinisterWarExhaustionNeutralityReset():
    print("PatchMinisterWarExhaustionNeutralityReset")
    hex_n = "3BC37E1153518BCC8919E868F3010090909090909083BF6801"
    print(f'Old: {ReadHex("hoi3_tfh.exe", 0xDC009, 25)}')
    WriteHex("hoi3_tfh.exe", 0xDC009, hex_n)
    print(f'New: {ReadHex("hoi3_tfh.exe", 0xDC009, 25)}')


if __name__ == "__main__":
    try:
        PatchLargeAddressAware()
        PatchMinisterTechDecay()
        PatchMinisterWarExhaustionNeutralityReset()
        print("\nSuccess\n")
        os.system("pause")
    except Exception as e:
        print(f"Something went wrong: {e}")
        os.system("pause")
