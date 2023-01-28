
local P = {}
AI_AST = P

function P.ProductionWeights(voProductionData)
	local laArray

	-- Commonwealth Build

	-- Build up
	if voProductionData.Year <= 1939 then
		laArray = {
			0.15, -- Land
			0.15, -- Air
			0.20, -- Sea
			0.50  -- Other
		};
	else
		laArray = {
			0.30, -- Land
			0.10, -- Air
			0.50, -- Sea
			0.10  -- Other
		};
	end

	-- War Check
	if voProductionData.IsAtWar then
		laArray = {
			0.30, -- Land
			0.10, -- Air
			0.50, -- Sea
			0.10  -- Other
		};
	end

	-- Manpower Check
	if voProductionData.ManpowerTotal < 100 then
		laArray = {
			0.00, -- Land
			0.20, -- Air
			0.70, -- Sea
			0.10  -- Other
		};
	end

	return laArray
end

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		12, -- Land
		4,  -- transport
		1}  -- invasion craft

	return laArray
end

function P.ForeignMinister_Alignment(...)
	return Support.AlignmentPush("allies", ...)
end

function P.DiploScore_OfferTrade(voDiploScoreObj)

	-- Australian embargo on JAP due to war in China
	if CCountryDataBase.GetTag("AST"):GetCountry():GetFlags():IsFlagSet("australia_embargo_japan") and voDiploScoreObj.TagName == "JAP" then
		return 0
	end

	local laTrade = {
		ENG = {Score = 20},
		CAN = {Score = 20},
		SAF = {Score = 20},
		NZL = {Score = 20},
		FRA = {Score = 20}}

	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end

	return voDiploScoreObj.Score
end

function P.DiploScore_Embargo(voDiploScoreObj)

	-- Australian embargo on JAP due to war in China
	if CCountryDataBase.GetTag("AST"):GetCountry():GetFlags():IsFlagSet("australia_embargo_japan") and voDiploScoreObj.TagName == "JAP" then
		voDiploScoreObj.score = voDiploScoreObj.score + 200
	end
	return voDiploScoreObj.score
end

-- Request LendLease from CAN (CAN AI simply doesn't do anything with their army)
function P.DiploScore_RequestLendLease( liScore, voAI, voSenderTag )
	if tostring(voSenderTag) == "CAN" then
		return 100
	end
	return liScore
end

function P.CountryUnitLimits()
	local limits = {
		land = 500,
		air = 500,
		naval = 500
	}
	return limits
end

return AI_AST