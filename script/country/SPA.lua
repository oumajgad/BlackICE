
local P = {}
AI_SPA = P


function P.ProductionWeights(voProductionData)
	local laArray
	
	-- Check to see if manpower is to low
	if (voProductionData.ManpowerTotal < 60 and voProductionData.LandCountTotal > 30)
	or voProductionData.ManpowerTotal < 30 then
		laArray = {
			0.00, -- Land
			0.50, -- Air
			0.50, -- Sea
			0.00}; -- Other
			
	elseif voProductionData.IsAtWar then
			laArray = {
				0.40, -- Land
				0.35, -- Air
				0.25, -- Sea
				0.00}; -- Other
		else
           laArray = {
				0.10, -- Land
				0.50, -- Air
				0.40, -- Sea
				0.00}; -- Other
            end
	return laArray
end

-- Land ratio distribution
function P.LandRatio(voProductionData)
	local laArray
	if voProductionData.Year < 1939 then
		laArray = {infantry_brigade = 4,
			semi_motorized_brigade = 2,
			garrison_brigade = 0.5,
			light_armor_brigade = 1,
			armor_brigade = 1};
	else
		laArray = {infantry_brigade = 4,
			garrison_brigade = 0.5,
			semi_motorized_brigade = 2,
			armor_brigade = 1};
	end
	return laArray
end

-- Special Forces ratio distribution
function P.SpecialForcesRatio(voProductionData)
	local laRatio = {
		5, -- Land
		1}; -- Special Force Unit

	local laUnits = {bergsjaeger_brigade = 1};
	
	return laRatio, laUnits	
end

-- Transport to Land unit distribution
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
	local sprTag = CCountryDataBase.GetTag("SPR")
	
	-- Is Spanish Civil War still going on?
	if voDiploScoreObj.TargetCountry:GetRelation(sprTag):HasWar() then
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
				voDiploScoreObj.Score = voDiploScoreObj.Score - 50
			end
		elseif voDiploScoreObj.Faction == CCurrentGameState.GetFaction("comintern") then
			voDiploScoreObj.Score = 0
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)

	-- We stay out of everything
	return 0
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		GER = {Score = 50},
		ITA = {Score = 50},
		POR = {Score = 20}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

return AI_SPA
