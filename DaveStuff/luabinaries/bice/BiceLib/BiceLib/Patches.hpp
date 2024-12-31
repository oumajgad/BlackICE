#include <Windows.h>
#include <iostream>

namespace Patches {
    bool patchBytes(void* address, BYTE values[], int len);
    bool fixOffMapIC(uintptr_t moduleBase);
    bool fixMinisterTechDecay(uintptr_t moduleBase);
    bool disableWarExhaustionNeutralityReset(uintptr_t moduleBase);
    bool disableInterAiExpeditionaries(uintptr_t moduleBase);
}