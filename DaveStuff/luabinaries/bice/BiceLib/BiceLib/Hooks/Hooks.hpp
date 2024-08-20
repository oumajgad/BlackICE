#include <Windows.h>

namespace Hooks {
    extern DWORD MODULE_BASE;
    bool hook(void* hookAddress, void* hookFunc, int len, int NOPs);
}
