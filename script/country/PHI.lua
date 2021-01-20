-----------------------------------------------------------
-- LUA Hearts of Iron 3 Philipines File
-- Created By: Dr Johnson 20/08/11
-----------------------------------------------------------

local P = {}
AI_PHI = P

function P.ProductionWeights(voProductionData)
	local laArray

	laArray = {
		0.5, -- Land
		0.2, -- Air
		0.0, -- Sea
		0.3}; -- Other

	return laArray
end

function P.Call_ForeignMinister_Tick(minister)
	local ministerTag = minister:GetCountryTag()
	local ministerCountry = ministerTag:GetCountry()

	if not(ministerCountry:HasFaction()) then
		local loAction = CInfluenceAllianceLeader(ministerTag, CCurrentGameState.GetFaction("allies"):GetFactionLeader())
			
		if loAction:IsSelectable() then
			minister:GetOwnerAI():PostAction(loAction)
		end
	end
end

return AI_PHI