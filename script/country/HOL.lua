
local P = {}
AI_HOL = P

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)

	local laArray

	if voProductionData.IsAtWar then
		-- War with Germany, all on land
		laArray = {
			1, -- Land
			0.0, -- Air
			0.0, -- Sea
			0.0}; -- Other
	else
		-- Pre war
		laArray = {
			0.30, -- Land
			0.10, -- Air
			0.00, -- Sea
			0.60}; -- Other
	end
	
	return laArray
end

-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray = {
		infantry_bat = 2,
		infantry_brigade = 3,
		garrison_brigade = 1
	};

	return laArray
end

function P.DiploScore_Embargo(voDiploScoreObj)
	-- If Japan then do some special checks
	if tostring(voDiploScoreObj.EmbargoTag) == "JAP" then
		-- If we are part of the allies
		if voDiploScoreObj.Faction == CCurrentGameState.GetFaction("allies") then
			local usaTag = CCountryDataBase.GetTag("USA")
			local loRelation = usaTag:GetCountry():GetRelation(voDiploScoreObj.EmbargoTag)
			
			-- USA is currently embargoing Japan
			if loRelation:HasEmbargo() then
				voDiploScoreObj.Score = 100
				
			-- Do not embargo japan unless the USA does so first
			else
				voDiploScoreObj.Score = 0
			end
			
		-- Never embargo Japan then
		else
			voDiploScoreObj.Score = 0
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		JAP = {Score = 150}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	-- Whatever their chance is lower it by 10 makes it harder to get them in
	return (voDiploScoreObj.Score - 10)
end

return AI_HOL

