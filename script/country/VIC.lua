
local P = {}
AI_VIC = P

function P.LandRatio(voProductionData)
	local laArray
	if voProductionData.Year < 1939 then
		laArray = {infantry_brigade = 4,
			semi_motorized_brigade = 2,
			light_armor_brigade = 1,
			armor_brigade = 1};
	else
		laArray = {infantry_brigade = 4,
			semi_motorized_brigade = 2,
			armor_brigade = 1};
	end
	return laArray
end

function P.HandleMobilization(minister)
	-- Do not do anything as we never want to mobilize
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	-- Stay out of the war, we do not care whats happening around us
	if not(voDiploScoreObj.IsAtWar) then
		voDiploScoreObj.Score = 0
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_Alliance(voDiploScoreObj)
	-- Stay out of the war, we do not care whats happening around us
	if not(voDiploScoreObj.IsAtWar) then
		voDiploScoreObj.Score = 0
	end
	
	return voDiploScoreObj.Score
end

function P.ForeignMinister_Alignment(...)
	return Support.AlignmentNeutral(...)
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
	-- We stay out of everything
	return 0
end

return AI_VIC
