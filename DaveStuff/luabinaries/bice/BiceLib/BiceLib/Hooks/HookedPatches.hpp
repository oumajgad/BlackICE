#include <wtypes.h>
#include <array>

namespace Hooks {
	namespace Patches {
		// Offmap IC
		extern DWORD jumpback_fixOffmapIc_CountLocalIc;
		extern DWORD jumpback_fixOffmapIc_SetBaseIc;
		extern int localIcEffectPerCountry[300];
		void fixOffmapIc_CountLocalIc();
		void fixOffmapIc_SetBaseIc();
	}
}