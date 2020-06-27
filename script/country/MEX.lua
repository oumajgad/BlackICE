
local P = {}
AI_MEX = P

function P.ForeignMinister_Alignment(voForeignMinisterData)
	-- If USA is leaning toward the allies and UK is at war start shifting
	if not(voForeignMinisterData.HasFaction) then
		local loUSACountry = CCountryDataBase.GetTag("USA"):GetCountry()
		local loAllyFaction = CCurrentGameState.GetFaction("allies")
	
		if Support.IsFriend(voForeignMinisterData.ministerAI, loAllyFaction, loUSACountry) then
			return Support.AlignmentPush("allies", voForeignMinisterData, true)
		end
	end
	
	return true
end

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	local loAlliedFaction = CCurrentGameState.GetFaction("allies")
	
	-- If the Allies are calling make sure USA is involved
	if voDiploScoreObj.ministerCountry:GetFaction() == loAlliedFaction then
		local usaTag = CCountryDataBase.GetTag("USA")
		local loUSACountry = usaTag:GetCountry()
	
		if Support.IsFriend(voDiploScoreObj.ministerAI, loAlliedFaction, loUSACountry) then
			local loUSACountry = usaTag:GetCountry()
			
			-- USA not in the allies yet so don't join
			if not(loUSACountry:GetFaction() == loAlliedFaction) then
				voDiploScoreObj.Score = 0
			end
		end
	end
	
	return voDiploScoreObj.Score
end
function P.ForeignMinister_Alignment(...)

		return Support.AlignmentPush("allies", ...)

end
return AI_MEX
