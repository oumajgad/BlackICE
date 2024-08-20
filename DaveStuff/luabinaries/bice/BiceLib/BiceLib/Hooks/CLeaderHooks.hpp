#include <vector>

namespace Hooks {
	namespace CLeader {
		extern DWORD jumpBack_PatchLeaderSkillLossOnPromotion;
		extern DWORD jumpBack_patchLeaderListShowMaxSkill;
		extern DWORD jumpBack_patchLeaderListShowMaxSkillSelected;
		extern std::vector<DWORD>* skillTraits;

		int getPureSkilleAndTraitListNode(DWORD* leaderAddress, HDS::LinkedListNodeSingle** out);

		bool checkTraitSkillLevelConsistency(DWORD* leaderAddress);

		void adjustSkillLevel(DWORD* leaderAddress, DWORD* CPromoteLeaderCommand, DWORD newRank);

		// NAKED
		void patchLeaderSkillLossOnPromotion();
		void patchLeaderListShowMaxSkill();
		void patchLeaderListShowMaxSkillSelected();
	}
}