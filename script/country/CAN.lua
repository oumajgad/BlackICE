
local P = {}
AI_CAN = P

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

function P.Build_CoastalFort(vIC, voProductionData)
	return vIC, false
end

function P.Build_AntiAir(vIC, voProductionData)
	return vIC, false
end

function P.ForeignMinister_Alignment(...)
	return Support.AlignmentPush("allies", ...)
end

-- Send LendLease to AST/NZL (CAN AI simply doesn't do anything with their army)
function P.DiploScore_RequestLendLease( liScore, voAI, voActorTag )
	if tostring(voActorTag) == "AST" or tostring(voActorTag) == "NZL"  then
		return 100
	end
	return liScore
end

-- AI CAN doesn't use its units at all, better Lend Lease
function P.MaxLendLease()
	return 0.8
end

function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		ENG = {Score = 20},
		AST = {Score = 20},
		SAF = {Score = 20},
		NZL = {Score = 20},
		FRA = {Score = 20}}

	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end

	return voDiploScoreObj.Score
end

return AI_CAN