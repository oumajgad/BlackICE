#include <unordered_map>

namespace Hooks {
	namespace CArmy {
		struct CommandLimitTrait {
			std::string traitName;
			int limitEffect;
		};

		// JUMP BACKS
		extern DWORD jumpBack_unitAttachmentLimitHook;

		// activation Member variables
		extern bool isUnitAttachmentLimitHookActive;

		// Vars
		extern DWORD armyGroupUnitLimit;
		extern DWORD armyUnitLimit;
		extern DWORD corpsUnitLimit;
		extern int armyGroupUnitLimitPerCountry[300];
		extern int armyUnitLimitPerCountry[300];
		extern int corpsUnitLimitPerCountry[300];

		extern std::unordered_map<std::string, CommandLimitTrait*>* commandLimitTraits;

		// NAKED Functions
		void unitAttachmentLimitHook();
	}
}