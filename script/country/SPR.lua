
local P = {}
AI_SPR = P

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		12, -- Land
		1,  -- transport
		1}  -- invasion craft

	return laArray
end

function P.Build_CoastalFort(ic, voProductionData)
	return ic, false
end

function P.Build_AntiAir(ic, voProductionData)
	return ic, false
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)

	-- SPR join faction disabled
	return 0

	--[[

	local spaTag = CCountryDataBase.GetTag("SPA")

	-- Is Spanish Civil War still going on?
	if voDiploScoreObj.TargetCountry:GetRelation(spaTag):HasWar() then
		voDiploScoreObj.Score = 0 -- not interested in factions until we sorted out things at home

	-- Penalty hit if Gibraltar and London are both controlled by the UK
	--   Make sure UK is not part of the Axis as well in the check in case they are a puppet
	else
		local loAxis = CCurrentGameState.GetFaction("axis")
		local engTag = CCountryDataBase.GetTag("ENG")

		if voDiploScoreObj.Faction == loAxis
		and not(engTag:GetCountry():GetFaction() == loAxis) then
			if CCurrentGameState.GetProvince(1964):GetController() == engTag -- London check
			and CCurrentGameState.GetProvince(5191):GetController() == engTag then -- Gibraltar check
				voDiploScoreObj.Score = 0
			end
		elseif voDiploScoreObj.Faction == CCurrentGameState.GetFaction("allies") then -- dont join if bordering germany
			if voDiploScoreObj.TargetCountry:IsNonExileNeighbour( CCountryDataBase.GetTag("GER") ) then
				voDiploScoreObj.Score = 0
			end
		end
	end

	return voDiploScoreObj.Score

	]]
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)

	-- We stay out of everything
	return 0
end

function P.TechMinister_OfficerRatio(StandardDataObject, Leadership, freePercentage)
	if CCurrentGameState.GetCurrentDate():GetYear() < 1941 then
		if Leadership.OfficerRatio < 0.5 then
			Leadership.Percent_NCO = math.min(1, freePercentage)
		elseif Leadership.OfficerRatio < 0.8 then
			Leadership.Percent_NCO = math.min(0.6, freePercentage)
		else
			Leadership.Percent_NCO = math.min(0.025, freePercentage)
		end
	else
		if Leadership.OfficerRatio < 0.5 then
			Leadership.Percent_NCO = math.min(1, freePercentage)
		elseif Leadership.OfficerRatio < 0.8 then
			Leadership.Percent_NCO = math.min(0.95, freePercentage)
		elseif Leadership.OfficerRatio  < 0.99 then
			Leadership.Percent_NCO = math.min(0.85, freePercentage)
		elseif Leadership.OfficerRatio  < 1.099 then
			Leadership.Percent_NCO = math.min(0.4, freePercentage)
		else
			Leadership.Percent_NCO = math.min(0.025, freePercentage)
		end
	end

	return Leadership.Percent_NCO
end

return AI_SPR