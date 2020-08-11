
local P = {}
AI_TIB = P

-- END OF PRODUTION OVERIDES
-- #######################################

-- Want more troops, let them learn on the battlefield.
--   helps them produce troops faster
function P.CallLaw_training_laws(minister, voCurrentLaw)
	local _MINIMAL_TRAINING_ = 27
	return CLawDataBase.GetLaw(_MINIMAL_TRAINING_)
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
	-- We stay out of everything
	return 0
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	voDiploScoreObj.Score = voDiploScoreObj.Score - 40
	return (voDiploScoreObj.Score)
end

function P.ForeignMinister_Alignment(...)
	return Support.AlignmentNeutral(...)
end

return AI_TIB
