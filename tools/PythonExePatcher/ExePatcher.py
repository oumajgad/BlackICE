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
    print("Patch_LargeAddressAware")
    print("\tThis will make the EXE able to use up to 4GB of RAM")
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
    print("Patch_MinisterTechDecay")
    print("\tThis makes the tech decay effect ministers have work")
    print(f'Old: {ReadHex("hoi3_tfh.exe", 0xDD7ED, 1)}')
    WriteHex("hoi3_tfh.exe", 0xDD7ED, "01")
    print(f'New: {ReadHex("hoi3_tfh.exe", 0xDD7ED, 1)}')


def PatchMinisterWarExhaustionNeutralityReset():
    print("Patch_MinisterWarExhaustionNeutralityReset")
    print("\tThis makes it so that war exhaustion is not added to neutrality after a war")
    hex_n = "3BC37E1153518BCC8919E868F3010090909090909083BF6801"
    print(f'Old: {ReadHex("hoi3_tfh.exe", 0xDC009, 25)}')
    WriteHex("hoi3_tfh.exe", 0xDC009, hex_n)
    print(f'New: {ReadHex("hoi3_tfh.exe", 0xDC009, 25)}')

    print(f'Old: {ReadHex("hoi3_tfh.exe", 0xDBFD3, 14)}')
    WriteHex("hoi3_tfh.exe", 0xDBFD3, "C786D00A00000000000090909090")
    print(f'New: {ReadHex("hoi3_tfh.exe", 0xDBFD3, 14)}')


def RevertOffmapIcPatch():
    print("RevertOffmapIcPatch")
    print("\tRevert the old patch since its replaced with a new, better one via BiceLib.dll")

    print(f'Old: {ReadHex("hoi3_tfh.exe", 0xF03A9, 6)}')
    WriteHex("hoi3_tfh.exe", 0xF03A9, "69C0E8030000")
    print(f'New: {ReadHex("hoi3_tfh.exe", 0xF03A9, 6)}')

    print("\tRevert UI patch")
    print(f'Old: {ReadHex("hoi3_tfh.exe", 0xF0390, 3)}')
    WriteHex("hoi3_tfh.exe", 0xF0390, "F76D08")
    print(f'New: {ReadHex("hoi3_tfh.exe", 0xF0390, 3)}')


if __name__ == "__main__":
    try:
        PatchLargeAddressAware()
        PatchMinisterTechDecay()
        PatchMinisterWarExhaustionNeutralityReset()
        RevertOffmapIcPatch()
        print("\nSuccess\n")
        os.system("pause")
    except Exception as e:
        print(f"Something went wrong: {e}")
        os.system("pause")