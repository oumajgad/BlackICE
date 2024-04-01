
local P = {}
AI_POL = P

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray

	if voProductionData.ManpowerTotal < 100 then
		laArray = {
		0.0, -- Land
		0.50, -- Air
		0.0, -- Sea
		0.50}; -- Other
	else
		laArray = {
		0.85, -- Land
		0.15, -- Air
		0.00, -- Sea
		0.00}; -- Other
	end

	-- Develop a bit pre 37
	if voProductionData.Year < 1937 then
		laArray = {
			0.6, -- Land
			0.2, -- Air
			0.1, -- Sea
			0.1}; -- Other
	end

	return laArray
end

-- Transport to Land unit distribution
-- UNUSED
function P.TransportLandRatio(voProductionData)
	local laArray = {
		0, -- Land
		0,  -- transport
		0}  -- invasion craft

	return laArray
end

function P.Build_Fort(ic, voProductionData)
	return ic, true
end

function P.Build_AntiAir(ic, voProductionData)
	return ic, false
end
function P.Build_Infrastructure(ic, voProductionData)
	return ic, false
end
function P.Build_NavalBase(ic, voProductionData)
	return ic, false
end
function P.Build_CoastalFort(ic, voProductionData)
	return ic, false
end
function P.Build_AirBase(ic, voProductionData)
	return ic, false
end
function P.Build_Radar(ic, voProductionData)
	return ic, false
end

function P.ForeignMinister_CallAlly(voForeignMinisterData)
	-- almost the same as normal logic, but with an exception for the "Soviet invasion of Poland"

	-- Get a list of all your allies
	local laAllies = {}
	for loAllyTag in voForeignMinisterData.ministerCountry:GetAllies() do
		local loAllyCountry = loAllyTag:GetCountry()

		-- Exclude Puppets from this list /dont
		--if not(loAllyCountry:IsPuppet()) then
		local loAlly = {
			AllyTag = loAllyTag,
			AllyCountry = loAllyCountry
		}

		laAllies[tostring(loAllyTag)] = loAlly
		--end
	end

	for loDiploStatus in voForeignMinisterData.ministerCountry:GetDiplomacy() do
		local loTargetTag = loDiploStatus:GetTarget()

		if loTargetTag:IsValid() and loDiploStatus:HasWar() then
			local loWar = loDiploStatus:GetWar()
			if loWar:IsLimited() or tostring(loTargetTag) == "SOV" then
				-- do nothing
			else
				-- Call in all potential allies
				for k, v in pairs(laAllies) do
					if not(v.AllyCountry:GetRelation(loTargetTag):HasWar()) then
						Support.ExecuteCallAlly(voForeignMinisterData.ministerAI, voForeignMinisterData.ministerTag, v, loTargetTag)
					end
				end
			end
		end
	end
end

function P.HandleMobilization(minister)
	local ai = minister:GetOwnerAI()
	local ministerTag =  minister:GetCountryTag()
	local gerTag = CCountryDataBase.GetTag("GER")

	-- If Germany Controls Czechoslovakia then
	if CCurrentGameState.GetProvince(2562):GetController() == gerTag then -- Praha check
		ai:Post(CToggleMobilizationCommand( ministerTag, true ))
	else
		-- Check if a neighbor is starting to look threatening
		-- This code should be idential to the one in ai_politics_minsiter.lua
		local ministerCountry = ministerTag:GetCountry()
		local liTotalIC = ministerCountry:GetTotalIC()
		local liNeutrality = ministerCountry:GetNeutrality():Get() * 0.9

		for loCountryTag in ministerCountry:GetNeighbours() do
			local liThreat = ministerCountry:GetRelation(loCountryTag):GetThreat():Get()

			if (liNeutrality - liThreat) < 10 then
				local loCountry = loCountryTag:GetCountry()

				liThreat = liThreat * CalculateAlignmentFactor(ai, ministerCountry, loCountry)

				if liTotalIC > 50 and loCountry:GetTotalIC() < liTotalIC then
					liThreat = liThreat / 2 -- we can handle them if they descide to attack anyway
				end

				if liThreat > 30 then
					if CalculateWarDesirability(ai, loCountry, ministerTag) > 70 then
						ai:Post(CToggleMobilizationCommand( ministerTag, true ))
					end
				end
			end
		end
	end
end


return AI_POL