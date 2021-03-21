-----------------------------------------------------------
-- LUA Hearts of Iron 3 Norway File
-- Created By: Dr Johnson 23/06/11
-----------------------------------------------------------

local P = {}
AI_NOR = P

-- END OF TECH RESEARCH OVERIDES
-- #######################################

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
	local lsActorTag = tostring(voDiploScoreObj.TagName)

	if lsActorTag == "AST"
	or lsActorTag == "BEL"
	or lsActorTag == "BBU"
	or lsActorTag == "BHU"
	or lsActorTag == "IND"
	or lsActorTag == "CAN"
	or lsActorTag == "DEN"
	or lsActorTag == "EGY"
	or lsActorTag == "FRA"
	or lsActorTag == "GRE"
	or lsActorTag == "HOL"
	or lsActorTag == "NEP"
	or lsActorTag == "POL"
	or lsActorTag == "NZL"
	or lsActorTag == "OMN"
	or lsActorTag == "SAF"
	or lsActorTag == "YEM" then
		voDiploScoreObj.Score = voDiploScoreObj.Score + 20

	elseif lsActorTag == "ENG" or lsActorTag == "USA" then
		voDiploScoreObj.Score = voDiploScoreObj.Score + 50
	end

	return voDiploScoreObj.Score
end

function P.HandleMobilization(minister)
	local ministerCountry = minister:GetCountry()

	if not(ministerCountry:IsMobilized()) then
		local ministerTag =  minister:GetCountryTag()
		local ai = minister:GetOwnerAI()

		if CCurrentGameState.GetCurrentDate():GetYear() >= 1940 then
			ai:Post(CToggleMobilizationCommand( ministerTag, true ))
		end
	end
end

--[[
function P.HandleLiberation(minister)
	local ministerCountry = minister:GetCountry()
	local gerTag = CCountryDataBase.GetTag("GER")

	if ministerCountry:MayLiberateCountries() then
		for loMember in ministerCountry:GetPossibleLiberations() do
			if minister:IsCapitalSafeToLiberate(loMember) then
				if not(ministerCountry:GetRelation(gerTag):HasWar()) then
					ai:Post(CLiberateCountryCommand(loMember, ministerTag))
				else
					return nil
				end
			end
		end
	end
end
]]

return AI_NOR