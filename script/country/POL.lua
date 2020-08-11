
local P = {}
AI_POL = P

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray
	local gerTag = CCountryDataBase.GetTag("GER")
	-- Check to see if manpower is to low
	-- More than 30 brigades so build stuff that does not use manpower
	
	-- More land focus vs GER player
	if (voProductionData.humanTag == gerTag) then
		if voProductionData.ManpowerTotal < 100 then
			laArray = {
			0.0, -- Land
			0.50, -- Air
			0.0, -- Sea
			0.50}; -- Other
		else
			laArray = {
			0.80, -- Land
			0.15, -- Air
			0.00, -- Sea
			0.05}; -- Other	
		end	

		-- Still develop pre 38
		if voProductionData.Year < 1938 then
			laArray = {
				0.25, -- Land
				0.0, -- Air
				0.0, -- Sea
				0.75}; -- Other
		end

	-- More normal focus vs GER AI
	else

		local JapRelation = voProductionData.ministerCountry:GetRelation(gerTag)
		local JapWar = JapRelation:HasWar()

		if voProductionData.ManpowerTotal < 100 then
			laArray = {
				0.0, -- Land
				0.50, -- Air
				0.0, -- Sea
				0.50}; -- Other	
		elseif JapWar then
			laArray = {
				0.90, -- Land
				0.0, -- Air
				0.0, -- Sea
				0.10}; -- Other	
		else
			laArray = {
				0.25, -- Land
				0.0, -- Air
				0.0, -- Sea
				0.75}; -- Other
		end
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