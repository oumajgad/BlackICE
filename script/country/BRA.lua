local P = {}
AI_BRA = P

-- #######################################
-- Start of Tech Research

-- END OF TECH RESEARCH OVERIDES
-- #######################################

function P.ProductionWeights(voProductionData)
	local laArray
	
	if voProductionData.Year <= 1942 then
		-- Develop until 42
		laArray = {
			0.10, -- Land
			0.00, -- Air
			0.00, -- Sea
			0.90}; -- Other
	else
		-- Build up for potential late join
		laArray = {
			0.30, -- Land
			0.00, -- Air
			0.30, -- Sea
			0.40}; -- Other
	end

	if voProductionData.IsAtWar then
		-- At war, full production
		laArray = {
			0.60, -- Land
			0.00, -- Air
			0.40, -- Sea
			0.0}; -- Other
	end
	
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		5, -- Land
		1}; -- Special Force Unit

	local laUnits = {marine_brigade = 1};
	
	return laRatio, laUnits	
end



-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		16, -- Land
		4,  -- transport
		1}  -- invasion craft
  
	return laArray
end

function P.ForeignMinister_Alignment(voForeignMinisterData)
	-- If USA is leaning toward the allies and UK is at war start shifting
	if not(voForeignMinisterData.HasFaction) then
		local loUSACountry = CCountryDataBase.GetTag("USA"):GetCountry()
		local loAllyFaction = CCurrentGameState.GetFaction("allies")
	
		if Support.IsFriend(voForeignMinisterData.ministerAI, loAllyFaction, loUSACountry) then
			return Support.AlignmentPush("allies", voForeignMinisterData, true)
		end
	end
	
	return true
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	local loAlliedFaction = CCurrentGameState.GetFaction("allies")
	
	-- If the Allies are calling make sure USA is involved
	if voDiploScoreObj.Faction == loAlliedFaction then
		local usaTag = CCountryDataBase.GetTag("USA")
		local loUSACountry = usaTag:GetCountry()
	
		if Support.IsFriend(voDiploScoreObj.ministerAI, loAlliedFaction, loUSACountry) then
			local loUSACountry = usaTag:GetCountry()
			
			-- USA not in the allies yet so don't join
			if not(loUSACountry:GetFaction() == loAlliedFaction) then
				voDiploScoreObj.Score = 0
			end
		end
	end
	
	return voDiploScoreObj.Score
end

return AI_BRA
