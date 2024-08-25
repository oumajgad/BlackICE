#include <vector>
#include <unordered_map>

namespace Hooks {
	namespace CLeader {
		// Structs
		struct RankSpecificTrait {
			int rank;
			std::string inactiveName;
			DWORD inActiveTraitPtr;
			std::string activeName;
			DWORD activeTraitPtr;
		};

		// JUMP BACKS
		extern DWORD jumpBack_leaderRankChangeHook;
		extern DWORD jumpBack_patchLeaderListShowMaxSkill;
		extern DWORD jumpBack_patchLeaderListShowMaxSkillSelected;

		// activation Member variables
		extern bool isLeaderRankChangeHookActive;
		extern bool isLeaderSkillLossOnPromotionActive;
		extern bool isRankSpecificTraitsActive;

		// Vars
		// Pure Skill
		extern std::vector<DWORD>* skillTraits;
		// Rank Specific
		extern std::unordered_map<std::string, RankSpecificTrait*>* rankSpecificTraitsActive; // active name -> trait
		extern std::unordered_map<std::string, RankSpecificTrait*>* rankSpecificTraitsInActive; // inactive name -> trait

		// Functions
		// Pure Skill
		int getPureSkillAndTraitListNode(DWORD* leaderAddress, HDS::LinkedListNodeSingle** out);
		bool checkTraitSkillLevelConsistency(DWORD* leaderAddress);
		void adjustSkillLevel(DWORD* leaderAddress, DWORD* CPromoteLeaderCommand, DWORD newRank);
		// Rank Specific Traits
		void checkRankSpecificTraitsConsistency(DWORD* leaderAddress, DWORD newRank);

		// NAKED Functions
		void leaderRankChangeHook();
		void patchLeaderListShowMaxSkill();
		void patchLeaderListShowMaxSkillSelected();
	}
}
