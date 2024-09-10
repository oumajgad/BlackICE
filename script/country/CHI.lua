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
			0.90, -- Land
			0.10, -- Air
			0.00, -- Sea
			0.00}; -- Other
		end

	-- More normal focus vs JAP AI
	else

		local JapRelation = voProductionData.ministerCountry:GetRelation(japTag)
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
				0.10, -- Air
				0.0, -- Sea
				0.0}; -- Other
		else
			laArray = {
				0.90, -- Land
				0.10, -- Air
				0.0, -- Sea
				0.00}; -- Other
		end
	end

	return laArray
end

-- Land ratio distribution
function P.LandRatio(voProductionData)

	-- More basic stuff to survive against JAP
	if voProductionData.IsAtWar or voProductionData.Year < 1940 then
		local laArray = {
			infantry_brigade = 4,
			infantry_bat = 1,
			militia_brigade = 8,
			garrison_brigade = 1,
			cavalry_brigade = 2
		};

		return laArray;
	-- Back to tier based Ratio if survived JAP
	else
		return AI_DEFAULT_LAND.LandRatio(voProductionData)
	end
end

-- Air ratio distribution
function P.AirRatio(voProductionData)
	local laArray = {
		interceptor = 1
	};

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

function P.Build_militia_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	voType.TransportMain = "horse_transport"
	voType.TertiaryMain = "division_hq_standard"
	voType.second = "artillery_brigade"
	voType.third = "Recon_cavalry_brigade"
	voType.Support = 0
	voType.SupportVariation = 0

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

function P.Build_infantry_brigade(vIC, viManpowerTotal, voType, voProductionData, viUnitQuantity)
	voType.TransportMain = "horse_transport"
	voType.TertiaryMain = "division_hq_standard"
	voType.first = "anti_tank_brigade"
	voType.second = "artillery_brigade"
	voType.third = "Recon_cavalry_brigade"
	voType.SecondaryMain = "engineer_brigade"
	voType.Support = 0
	voType.SupportVariation = 0

	return Support.CreateUnit(voType, vIC, viUnitQuantity, voProductionData)
end

-- END OF PRODUTION OVERIDES
-- #######################################
function P.DiploScore_InviteToFaction(voDiploScoreObj)
	-- Dont join any faction even if allies. Not meant to still exist during historical joining after Pearl Harbor
	return 0
end

function P.DiploScore_GiveMilitaryAccess(viScore, voAI, voCountry)
	local lsCountry = tostring(voCountry)

	-- Do not let Japan in our territory
	if lsCountry == "JAP" then
		viScore = 0
	end

	return viScore
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
