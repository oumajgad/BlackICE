namespace Hooks {
	namespace CArmy {
		// JUMP BACKS
		extern DWORD jumpBack_unitAttachmentLimitHook;

		// activation Member variables
		extern bool isUnitAttachmentLimitHookActive;

		// NAKED Functions
		void unitAttachmentLimitHook();
	}
}