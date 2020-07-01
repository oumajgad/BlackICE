local P = {}
AI_CHI = P

-- Tech weights
--   1.0 = 100% the total needs to equal 1.0
function P.TechWeights(voTechnologyData)
	local laTechWeights = {
		0.5, -- landBasedWeight
		0.5, -- landDoctrinesWeight
		0.0, -- airBasedWeight
		0.0, -- airDoctrinesWeight
		0.0, -- navalBasedWeight
		0.0, -- navalDoctrinesWeight
		0.0, -- industrialWeight
		0.0, -- secretWeaponsWeight
		0.0}; -- otherWeight
	
	return laTechWeights
end
-- END OF TECH RESEARCH OVERIDES
-- #######################################


-- #######################################
-- Production Overides the main LUA with country specific ones

-- Production Weights
--   1.0 = 100% the total needs to equal 1.0
function P.ProductionWeights(voProductionData)
	local laArray
	local japTag = CCountryDataBase.GetTag("JAP")
	-- Check to see if manpower is to low
	-- More than 30 brigades so build stuff that does not use manpower
	
	-- More land focus vs JAP player
	if (voProductionData.humanTag == japTag) then
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

	-- More normal focus vs JAP AI
	else
		if voProductionData.ManpowerTotal < 100 then
			laArray = {
				0.0, -- Land
				0.50, -- Air
				0.0, -- Sea
				0.50}; -- Other	
		elseif voProductionData.IsAtWar then
			laArray = {
				0.90, -- Land
				0.0, -- Air
				0.0, -- Sea
				0.10}; -- Other	
		else
			laArray = {
				0.50, -- Land
				0.0, -- Air
				0.0, -- Sea
				0.50}; -- Other
		end
	end
	
	return laArray
end
-- Special Forces ratio distribution
-- Make sure China does not build any special forces
function P.SpecialForcesRatio(voProductionData)
	local laArray = {
		0, -- Land
		0}; -- Special Forces Unit
	
	return laArray, nil
end
-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 3, 
		cas = 1, 
		tactical_bomber = 2};
	
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

-- Convoy Ratio control
--- NOTE: If goverment is in Exile these parms are ignored
function P.ConvoyRatio(voProductionData)
	local laArray = {
		0, -- Percentage extra (adds to 100 percent so if you put 10 it will make it 110% of needed amount)
		5, -- If Percentage extra is less than this it will force it up to the amount entered
		10, -- If Percentage extra is greater than this it will force it down to this
		0} -- Escort to Convoy Ratio (Number indicates how many convoys needed to build 1 escort)
  
	return laArray
end

-- END OF PRODUTION OVERIDES
-- #######################################
function P.DiploScore_InviteToFaction(voDiploScoreObj)
	local japTag = CCountryDataBase.GetTag("JAP")
	
	-- if we are not at war with JAP, only join if we lost previously and they are busy with allies
	if not (voDiploScoreObj.TargetCountry:GetRelation(japTag):HasWar()) then
		if voDiploScoreObj.Faction == CCurrentGameState.GetFaction("allies") then
			if japTag:GetCountry():GetSurrenderLevel():Get() < 0.06 then -- they must have lost islands
				if (CCurrentGameState.GetProvince(5405):GetController() == japTag) then
					voDiploScoreObj.Score = 0
				end
			end
		end
	end
	
	return voDiploScoreObj.Score
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
	local lsCountry = tostring(voCountry)

	-- Do not let Japan in our territory
	if lsCountry == "JAP" then
		viScore = 0
	end
	
	return viScore
end

-- Want more troops, let them learn on the battlefield.
--   helps them produce troops faster
function P.CallLaw_training_laws(minister, voCurrentLaw)
	local _MINIMAL_TRAINING_ = 27
	return CLawDataBase.GetLaw(_MINIMAL_TRAINING_)
end

function P.ForeignMinister_Alignment(...)
	local usaTag = CCountryDataBase.GetTag("USA")
	local lousaCountry = usaTag:GetCountry()
	
	-- Make sure Germany is at war and has a border with us
	if lousaCountry:IsAtWar() then
		return Support.AlignmentPush("allies", ...)
	else
		return Support.AlignmentNeutral(...)
	end
end


return AI_CHI

