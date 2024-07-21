#include <iostream>
#include <intrin.h>

#include <CasualLibrary.hpp>

int DATA_SECTION_START = 0x12F5000;

inline const char* const BoolToString(bool b) {
    return b ? "OK" : "Failed";
}

template <typename I> std::string n2hexstr(I w, size_t hex_len = sizeof(I) << 1) {
    static const char* digits = "0123456789ABCDEF";
    std::string rc(hex_len, '0');
    for (size_t i = 0, j = (hex_len - 1) * 4; i < hex_len; ++i, j -= 4)
        rc[i] = digits[(w >> j) & 0x0f];
    return rc;
}

std::string toSignature(std::string &str) {
    std::string res(8 + 3, '0'); // 8 chars + 3 spaces
    int offset = 0;
    for (int i = 0; i < 8; i++) {
        res[i + offset] = str[i];
        if (i == 1 || i == 3 || i == 5) {
            res[i + offset + 1] = ' ';
            offset++;
        }
    }
    return res;
}


int main() {
    std::cout << "Running tests ...\n\n";

    Memory::External external = Memory::External("hoi3_tfh.exe", true);
    Address modulePtr = external.getModule("hoi3_tfh.exe");
    std::cout << modulePtr.get() << std::endl;

    /*
    long x = external.read<long>(modulePtr.get() + 0x11C1BA8, true);
    std::cout << x << std::endl;
    std::cout << n2hexstr(x) << std::endl;
    std::cout << n2hexstr(_byteswap_ulong(x)) << std::endl;
    */

    std::string hex_string = "28C55301";

    // std::string hex_string = n2hexstr(_byteswap_ulong(modulePtr.get() + 0x11C1BA8));
    std::cout << hex_string << std::endl;;

    std::string signature = toSignature(hex_string);
    std::cout << signature << std::endl;
    Address sig_address = external.findSignature(modulePtr.get() + DATA_SECTION_START, signature.c_str(), 256);
    std::cout << n2hexstr(sig_address.get()) << std::endl;
    

    /*
    Address namePtr = external.getAddress(modulePtr + 0x11C1BA8, { 0x40 }).get();

    std::cout << "Status external.read<std::string>(addToBeRead):       ";
    std::cout << BoolToString(external.read<std::string>(namePtr) == "CasualGamer") << std::endl;

    //std::cout << "Status readString(addToBeRead, size): ";
    //std::cout << BoolToString(external.readString(namePtr, 5) == "Casua") << std::endl;

    std::cout << "Status external.read<T>(addToBeRead):   ";
    std::cout << BoolToString(external.read<int>(namePtr) == 1970495811) << std::endl;

    Address address = external.findSignature(modulePtr, "BA ? ? ? ? CD", 100);
    std::cout << "Status findSignature(...):            ";
    std::cout << BoolToString(address.get()) << std::endl;

    std::cin.get();
    */
}