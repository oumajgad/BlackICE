#include <wtypes.h>

#include <utils.hpp>

char* utils::getCString(DWORD* addr) {
    DWORD stringLength = *(addr + (0x10/4));
    char* res;
    if (stringLength > 15) {
        res = (char*)*addr;
    }
    else {
        res = (char*)addr;
    }
    return res;
}