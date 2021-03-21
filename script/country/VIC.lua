
local P = {}
AI_VIC = P

function P.ProductionWeights(voProductionData)
	local laArray

	laArray = {
		0, -- Land
		0, -- Air
		0, -- Sea
		1}; -- Other

	return laArray
end

function P.HandleMobilization(minister)
	-- Do not do anything as we never want to mobilize
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	-- Stay out of the war, we do not care whats happening around us

	return -100
end

function P.DiploScore_Alliance(voDiploScoreObj)
	-- Stay out of the war, we do not care whats happening around us


	return 0
end

function P.ForeignMinister_Alignment(...)
	return Support.AlignmentNeutral(...)
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
	-- We stay out of everything
	return 0
end

return AI_VIC