
local P = {}
AI_SWE = P

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		0, -- Land
		0,  -- transport
		0}  -- invasion craft
  
	return laArray
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		GER = {Score = 100},
		ITA = {Score = 20},
		FIN = {Score = 20},
		NOR = {Score = 20},
		DEN = {Score = 20},
		SOV = {Score = -20},
		ENG = {Score = -20},
		FRA = {Score = -20}}
	
	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end
	
	return voDiploScoreObj.Score
end

function P.ForeignMinister_EvaluateDecision(voDecision, voForeignMinisterData)
	if voDecision.Name == 'finnish_winter_war_swedish_intervention' then
		return 100 	-- lets help
	elseif voDecision.Name == 'finnish_winter_war_swedish_direct_intervention' then
		return 0 -- but not too much
	end

	return voDecision.Score
end

function P.DiploScore_Alliance(voAI, voActorTag, voRecipientTag, voObserverTag)
	
	local gerTag = CCountryDataBase.GetTag("GER")
	local humanTag = CCurrentGameState.GetPlayer()
	
	if (humanTag == gerTag) then	
	-- viScore is undefined ... whatever the original intent was this doesn't work
	--	return viScore
		return 0
	else	
		return 0
	end
end	

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)

	local itaTag = CCountryDataBase.GetTag("ITA")
	local gerTag = CCountryDataBase.GetTag("GER")
	local humanTag = CCurrentGameState.GetPlayer()
	
	if (humanTag == gerTag) or (humanTag == itaTag)  then	
		return viScore
	else	
		return 0
	end
	
end

function P.ForeignMinister_Alignment(...)
	return Support.AlignmentNeutral(...)
end

return AI_SWE

