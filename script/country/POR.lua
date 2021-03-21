
local P = {}
AI_POR = P

function P.DiploScore_InviteToFaction(voDiploScoreObj)
	local spaTag = CCountryDataBase.GetTag("SPA")
	local sprTag = CCountryDataBase.GetTag("SPR")

	-- If Spanish Civil War is going on don't join any alliance
	if sprTag:GetCountry():GetRelation(spaTag):HasWar() then
		voDiploScoreObj.Score = 0 -- not interested in factions until we sorted out things at home

	-- Do not get involved as long as we are isolated (to easy for allies to get us)
	else
		local loAxis = CCurrentGameState.GetFaction("axis")

		if voDiploScoreObj.Faction == loAxis then
			local ministerContinent = voDiploScoreObj.TargetCountry:GetActingCapitalLocation():GetContinent()

			local loMadridContFaction = CCurrentGameState.GetProvince(4540):GetController():GetCountry():GetFaction() --Madrid controller is no axis, dont join
			if not( loMadridContFaction == loAxis) then
				return 0
			end
		end
	end

	return voDiploScoreObj.Score
end

return AI_POR