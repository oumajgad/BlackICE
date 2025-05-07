namespace Hooks {
	namespace CNavy {
		// JUMP BACKS
		extern DWORD origJmp_screenPenaltyHook;

		// activation Member variables
		extern bool isNavyScreenPenaltyHookActive;

		// Vars
		extern DWORD screenPenalty;
		extern DWORD screensPerCapital;

		// NAKED Functions
		void screenPenaltyCalulation();
	}
}