#include <wtypes.h>
#include <array>

namespace Hooks {
	namespace Patches {
		// Offmap IC
		extern DWORD jumpback_fixOffmapIc_CountLocalIc;
		extern DWORD jumpback_fixOffmapIc_SetBaseIc;
		extern int localIcEffectPerCountry[300];    // x1000
		extern int offmapIcPerCountry[300];         // offmap IC to be used in Utility display
		void fixOffmapIc_CountLocalIc();
		void fixOffmapIc_SetBaseIc();

		// Placing Buildings
		extern DWORD jumpback_enablePlacingNonResearchedBuildings;
		extern DWORD jumpback_enablePlacingNonResearchedBuildings_OriginalReturn; // Where it jumps if you are not allowed to place the building
		void enablePlacingNonResearchedBuildings();
	}
}