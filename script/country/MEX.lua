
local P = {}
AI_MEX = P

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray
	
	-- Check to see if manpower is to low
	-- More than 100 brigades build stuff that does not use manpower
	if (voProductionData.ManpowerTotal < 40 and voProductionData.LandCountTotal > 20)
	or voProductionData.ManpowerTotal < 20 then
		laArray = {
			0.0, -- Land
			0.20, -- Air
			0.20, -- Sea
			0.60}; -- Other	
	elseif voProductionData.Year <= 1938 and not(voProductionData.IsAtWar) then
		laArray = {
			0.20, -- Land
			0.10, -- Air
			0.00, -- Sea
			0.80}; -- Other
	elseif voProductionData.IsAtWar then
		if voProductionData.Year <= 1940 then
			laArray = {
				0.70, -- Land
				0.20, -- Air
				0.10, -- Sea
				0.00}; -- Other
		else
			laArray = {
				0.50, -- Land
				0.10, -- Air
				0.40, -- Sea
				0.00}; -- Other
		end
	else
		laArray = {
			0.30, -- Land
			0.00, -- Air
			0.00, -- Sea
			0.70}; -- Other
	end
	
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
	if voDiploScoreObj.ministerCountry:GetFaction() == loAlliedFaction then
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
function P.ForeignMinister_Alignment(...)

		return Support.AlignmentPush("allies", ...)

end
return AI_MEX
