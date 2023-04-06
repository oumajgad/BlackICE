local P = {}
AI_FIN = P
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.20, -- landBasedWeight
		0.20, -- landDoctrinesWeight
		0.10, -- airBasedWeight
		0.10, -- airDoctrinesWeight
		0.00, -- navalBasedWeight
		0.00, -- navalDoctrinesWeight
		0.30, -- industrialWeight
		0.00, -- secretWeaponsWeight
		0.10}; -- otherWeight

	return laTechWeights
end

function P.ProductionWeights(voProductionData)
	local laArray

	-- Develop pre 1939
	if voProductionData.Year < 1938 then
		laArray = {
			0.3, -- Land
			0.0, -- Air
			0.0, -- Sea
			0.7}; -- Other
	-- Build up after
	else
		laArray = {
			0.60, -- Land
			0.10, -- Air
			0.00, -- Sea
			0.30}; -- Other
	end

	-- War check
	if voProductionData.IsAtWar then
		laArray = {
			0.8, -- Land
			0.2, -- Air
			0.0, -- Sea
			0.0}; -- Other
	end

	-- Manpower check
	if voProductionData.ManpowerTotal < 100 then
		laArray = {
			0.00, -- Land
			0.50, -- Air
			0.00, -- Sea
			0.50}; -- Other
	end

	return laArray
end

-- END OF TECH RESEARCH OVERIDES
-- ######################################
function P.LandRatio(voProductionData)
	local laArray
	if voProductionData.Year < 1939 then
		laArray = {infantry_brigade = 2,
			light_infantry_brigade = 8,
			garrison_brigade = 1};
	else
		laArray = {infantry_brigade = 3,
			light_infantry_brigade = 8,
			garrison_brigade = 0.5,
			semi_motorized_brigade = 1,
			armor_brigade = 1};
	end

	laArray.ski_brigade = 2

	return laArray
end

function P.HandleMobilization( minister )
	local ministerTag = minister:GetCountryTag()
	local ministerCountry = ministerTag:GetCountry()
	local ai = minister:GetOwnerAI()

	-- mobilize before winter war
	local sovTag = CCountryDataBase.GetTag('SOV')
	local estTag = CCountryDataBase.GetTag('EST')

	--if (not sovTag:GetCountry():IsAtWar())
	--and
	if ((not estTag:GetCountry():Exists()) or estTag:GetCountry():IsGovernmentInExile())
	then
		local command = CToggleMobilizationCommand( ministerTag, true )
		ai:Post( command )
		return
	end


	local year = ai:GetCurrentDate():GetYear()
	local month = ai:GetCurrentDate():GetMonthOfYear()
	local gerTag = CCountryDataBase.GetTag('GER')

	local warTime = ( year >= 1940 ) or ( year == 1939 and month >= 6 )

	if warTime
	and ( not ministerCountry:HasFaction() )
	and ( not ministerCountry:IsFriend( sovTag, false ) )
	and ( not ministerCountry:IsFriend( gerTag, false ) )
	then
		local finnishBorder = { [0] = 377, 353, 329, 286, 268, 253, 237, 210, 183 }
		local troupCount = 0
		for tmpIndex, provID in pairs(finnishBorder) do
			local province = CCurrentGameState.GetProvince( provID )
			troupCount = troupCount + province:GetNumberOfUnits()
		end

		if troupCount > 5
		then
			local command = CToggleMobilizationCommand( ministerTag, true )
			ai:Post( command )
			return
		end
	end

	-- general check of neighbors
	for neighborCountry in ministerCountry:GetNeighbours() do
		local threat = ministerCountry:GetRelation(neighborCountry):GetThreat():Get()
		if  threat > 30 then
			--Utils.LUA_DEBUGOUT( "MOBILIZE " .. tostring(ministerTag) .. " " .. tostring(threat) .. "towards" .. tostring(neighborCountry) )
			local warDesirability = CalculateWarDesirability( ai, neighborCountry:GetCountry(), ministerTag )
			if warDesirability > 70 then
				local command = CToggleMobilizationCommand( ministerTag, true )
				ai:Post( command )
				return
			end
		end
	end
end

function P.ForeignMinister_CallAlly(voForeignMinisterData)
	return false
end


function P.DiploScore_OfferTrade(voDiploScoreObj)
	local laTrade = {
		GER = {Score = 100},
		NOR = {Score = 20},
		SOV = {Score = -50},
		SWE = {Score = 100}}

	if laTrade[voDiploScoreObj.TagName] then
		return voDiploScoreObj.Score + laTrade[voDiploScoreObj.TagName].Score
	end

	return voDiploScoreObj.Score
end

--##########################
-- Foreign Minister Hooks

function P.ForeignMinister_Alignment(voForeignMinisterData)
	if not(voForeignMinisterData.HasFaction) and voForeignMinisterData.Year <= 1942 then
		local loSOVTag = CCountryDataBase.GetTag("SOV")

		-- Align with Germany if we go to war with the soviets
		if CCurrentGameState.GetProvince(698):GetOwner() == loSOVTag -- Viipuri
		or voForeignMinisterData.ministerCountry:GetRelation(loSOVTag):HasWar() then
			return Support.AlignmentPush("axis", voForeignMinisterData, true, true)
		end
	end

	return true
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)

	-- FIN dont join axis if at war with SOV (Winter War)
	local loSOVTag = CCountryDataBase.GetTag("SOV")
	if voDiploScoreObj.ministerCountry:GetRelation(loSOVTag):HasWar() and tostring(voDiploScoreObj.ministerTag:GetCountry():GetFaction():GetTag()) == "axis" then
		return 0
	end
	return voDiploScoreObj.Score
end

return AI_FIN