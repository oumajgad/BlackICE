local P = {}
Support_Trade = P


-- ###########################
-- Called by the EXE and handles the Analyzing of offered trades
-- ###########################
function DiploScore_OfferTrade(voAI, voFromTag, voToTag, voObserverTag, voTradeAction, voTradedFrom, voTradedTo)

	local isOMG = false
	if tostring(voFromTag) == "OMG" then
		isOMG = true
	end

	local t = nil
	if benchmarkLUA then
		t = os.clock()
	end

	local loDiploScoreObj = {
		Score = 0,
		DefaultScore = 50,
		ministerAI = voAI,
		TradeRoute = voTradeAction:GetRoute(),
		TagName = nil,
		BuyerTag = nil,
		BuyerCountry = nil,
		BuyerContinent = nil,
		BuyerIdeology = nil,
		SellerTag = nil,
		SellerCountry = nil,
		SellerContinent = nil,
		SellerIdeology = nil,
		SellerStrategy = nil,
		Money = nil,
		IsNeighbor = nil,
		ResourceRequest = nil,
		Relation = nil,
		FreeTrade = false,
		NeedConvoy = false,
		HumanSelling = false,
		BuyerResources = nil,
		SellerResources = nil}

	--Utils.LUA_DEBUGOUT("==== Deciding trade offer ====")

	loDiploScoreObj.Relation = loDiploScoreObj.ministerAI:GetRelation(voToTag, voFromTag)
	loDiploScoreObj.FreeTrade = Support_Trade.FreeTradeCheck(voAI, voToTag, voFromTag, loDiploScoreObj.Relation)

	-- Two way trade get out!
	-- 0 cost trade but make sure they are not Commintern
	if (voTradedTo.vMoney > 0 and voTradedFrom.vMoney > 0)
	or (voTradedTo.vMoney == 0 and voTradedFrom.vMoney == 0 and not(loDiploScoreObj.FreeTrade)) then
		return 0
	end

	local liFromCount = 0
	local liToCount = 0

	-- They can trade freely between eachother
	if loDiploScoreObj.FreeTrade then
		liFromCount = voTradedFrom.vMetal + voTradedFrom.vEnergy + voTradedFrom.vRareMaterials + voTradedFrom.vCrudeOil + voTradedFrom.vSupplies + voTradedFrom.vFuel
		liToCount = voTradedTo.vMetal + voTradedTo.vEnergy + voTradedTo.vRareMaterials + voTradedTo.vCrudeOil + voTradedTo.vSupplies + voTradedTo.vFuel
	end

	if (voTradedTo.vMoney > 0)
	or (loDiploScoreObj.FreeTrade and liFromCount > 0 and liToCount <= 0) then
		-- Get the Money amount
		loDiploScoreObj.Money = voTradedTo.vMoney
		loDiploScoreObj.ResourceRequest = voTradedFrom

		loDiploScoreObj.BuyerTag = loDiploScoreObj.TradeRoute:GetTo()
		loDiploScoreObj.SellerTag = loDiploScoreObj.TradeRoute:GetFrom()
		loDiploScoreObj.BuyerCountry = loDiploScoreObj.BuyerTag:GetCountry()
		loDiploScoreObj.SellerCountry = loDiploScoreObj.SellerTag:GetCountry()

	else
		-- Get the Money amount
		loDiploScoreObj.Money = voTradedFrom.vMoney
		loDiploScoreObj.ResourceRequest = voTradedTo

		loDiploScoreObj.BuyerTag = loDiploScoreObj.TradeRoute:GetFrom()
		loDiploScoreObj.SellerTag = loDiploScoreObj.TradeRoute:GetTo()
		loDiploScoreObj.BuyerCountry = loDiploScoreObj.BuyerTag:GetCountry()
		loDiploScoreObj.SellerCountry = loDiploScoreObj.SellerTag:GetCountry()
	end

	-- If the FromTag and SellerTag same person that means its a human selling
	if voFromTag == loDiploScoreObj.SellerTag then
		loDiploScoreObj.HumanSelling = true
		--Utils.LUA_DEBUGOUT("Is human selling")
	end

	-- Don't buy/sell Fuel (Player only exception not working)
	-- Utils.LUA_DEBUGOUT("Fuel proposed: " .. loDiploScoreObj.ResourceRequest["vFuel"])
	--if not (loDiploScoreObj.ResourceRequest["vFuel"] == 0) --[[ and (CCurrentGameState.GetPlayer() == voFromTag or CCurrentGameState.GetPlayer() == voToTag) ]] then
	--	return 0
	--end

	loDiploScoreObj.NeedConvoy = loDiploScoreObj.BuyerCountry:NeedConvoyToTradeWith(loDiploScoreObj.SellerTag)

	-- Do we need transports for this?
	if loDiploScoreObj.NeedConvoy then
		if loDiploScoreObj.BuyerCountry:GetTransports() == 0 then
			--Utils.LUA_DEBUGOUT("Don't have convoys for trade")
			return 0
		end
	end

	loDiploScoreObj.BuyerResources = Support_Trade.Trade_GetResources(loDiploScoreObj.BuyerTag, loDiploScoreObj.BuyerCountry)
	loDiploScoreObj.SellerResources = Support_Trade.Trade_GetResources(loDiploScoreObj.SellerTag, loDiploScoreObj.SellerCountry, loDiploScoreObj.HumanSelling)

	local lbNeedMoney = loDiploScoreObj.BuyerCountry:GetFlags():IsFlagSet("need_money")

	if lbNeedMoney then
                loDiploScoreObj.ResourceRequest["vFuel"] = 0
                loDiploScoreObj.ResourceRequest["vCrudeOil"] = 0
       		-- Utils.LUA_DEBUGOUT( "need money" )

	end

	local lbFoundOne = false
	for k, v in pairs(loDiploScoreObj.BuyerResources) do
		if not(v.ByPass) then
			if loDiploScoreObj.ResourceRequest[v.TradeOBJ] > 0 then
				if lbFoundOne then
					return 0 -- We only process one resource at a time
				end
				if loDiploScoreObj.HumanSelling then
					--Utils.LUA_DEBUGOUT("Requested: " .. loDiploScoreObj.ResourceRequest[v.TradeOBJ])
					--Utils.LUA_DEBUGOUT("Buying: " .. v.Buy)
					--Utils.LUA_DEBUGOUT("Trade Away: " .. v.TradeAway)
					if loDiploScoreObj.ResourceRequest[v.TradeOBJ] <= v.Buy and v.TradeAway <= 0 then
						--Utils.LUA_DEBUGOUT("Money to spend: " .. loDiploScoreObj.BuyerResources.MONEY.CanSpend)
						--Utils.LUA_DEBUGOUT("Money cost of trade: " .. loDiploScoreObj.Money)
						if loDiploScoreObj.Money <= loDiploScoreObj.BuyerResources.MONEY.CanSpend then
							loDiploScoreObj.Score = (((loDiploScoreObj.ResourceRequest[v.TradeOBJ] * v.ScoreFactor) * v.ShortPercentage) + loDiploScoreObj.DefaultScore)
						end
					end
				else
					if loDiploScoreObj.ResourceRequest[v.TradeOBJ] <= loDiploScoreObj.SellerResources[k].Sell then
						loDiploScoreObj.Score = (((loDiploScoreObj.ResourceRequest[v.TradeOBJ] * v.ScoreFactor) * v.ShortPercentage) + loDiploScoreObj.DefaultScore)
					end
				end

				lbFoundOne = true
			end
		end
	end

	--Utils.LUA_DEBUGOUT("Base trade score: " .. loDiploScoreObj.Score)

	-- Now shift the score based on Diplomatic relations!
	if loDiploScoreObj.Score > 0 then
		-- Political checks
		loDiploScoreObj.SellerStrategy = loDiploScoreObj.SellerCountry:GetStrategy()

		loDiploScoreObj.Score = loDiploScoreObj.Score - loDiploScoreObj.SellerStrategy:GetAntagonism(loDiploScoreObj.BuyerTag) / 15
		loDiploScoreObj.Score = loDiploScoreObj.Score + loDiploScoreObj.SellerStrategy:GetFriendliness(loDiploScoreObj.BuyerTag) / 10
		loDiploScoreObj.Score = loDiploScoreObj.Score - loDiploScoreObj.Relation:GetThreat():Get() / 5
		loDiploScoreObj.Score = loDiploScoreObj.Score + tonumber(tostring(loDiploScoreObj.Relation:GetValue():GetTruncated())) / 3

		if loDiploScoreObj.Relation:IsGuaranteed() then
			loDiploScoreObj.Score = loDiploScoreObj.Score + 5
		end
		if loDiploScoreObj.Relation:HasFriendlyAgreement() then
			loDiploScoreObj.Score = loDiploScoreObj.Score + 10
		end
		if loDiploScoreObj.Relation:IsFightingWarTogether() then
			loDiploScoreObj.Score = loDiploScoreObj.Score + 15
		end

		loDiploScoreObj.IsNeighbor = loDiploScoreObj.BuyerCountry:IsNonExileNeighbour(loDiploScoreObj.SellerTag)
		loDiploScoreObj.SellerContinent = loDiploScoreObj.SellerCountry:GetActingCapitalLocation():GetContinent()
		loDiploScoreObj.BuyerContinent = loDiploScoreObj.BuyerCountry:GetActingCapitalLocation():GetContinent()

		if loDiploScoreObj.IsNeighbor then
			loDiploScoreObj.Score = loDiploScoreObj.Score + 25
		else
			loDiploScoreObj.Score = loDiploScoreObj.Score + 15
		end

		if loDiploScoreObj.SellerContinent == loDiploScoreObj.BuyerContinent then
			loDiploScoreObj.Score = loDiploScoreObj.Score + 15
		else
			loDiploScoreObj.Score = loDiploScoreObj.Score + 10
		end

		loDiploScoreObj.BuyerIdeology = tostring(loDiploScoreObj.BuyerCountry:GetRulingIdeology():GetGroup():GetKey())
		loDiploScoreObj.SellerIdeology = tostring(loDiploScoreObj.SellerCountry:GetRulingIdeology():GetGroup():GetKey())

		if loDiploScoreObj.BuyerIdeology == loDiploScoreObj.SellerIdeology then
			loDiploScoreObj.Score = loDiploScoreObj.Score + 10
		end

		if Support.IsFriend(loDiploScoreObj.ministerAI, loDiploScoreObj.BuyerCountry:GetFaction(), loDiploScoreObj.SellerCountry) then
			loDiploScoreObj.Score = loDiploScoreObj.Score + 5
		end

		-- Land Route gets bigger bonus
		if not(loDiploScoreObj.NeedConvoy) then
			loDiploScoreObj.Score = loDiploScoreObj.Score + 10
		else
			loDiploScoreObj.Score = loDiploScoreObj.Score + 5
		end
	end

	if loDiploScoreObj.Score > 0 then
		loDiploScoreObj.TagName = tostring(voFromTag)
		loDiploScoreObj.Score = Utils.CallGetScoreAI(voToTag, "DiploScore_OfferTrade", loDiploScoreObj)

		-- Special EMBARGO - REFUSE TRADE checks

		-- Allies embargo Japan due to war in China
		if CCountryDataBase.GetTag("JAP"):GetCountry():GetFlags():IsFlagSet("steel_embargo") then
			local faction = tostring(voToTag:GetCountry():GetFaction():GetTag())
			if faction == "allies" then
				if tostring(loDiploScoreObj.TagName) == "JAP" then
					return 0;
				end
			end
		end

		-- USA embargo on Japan (entire America complies due to US influence)
		if CCountryDataBase.GetTag("JAP"):GetCountry():GetFlags():IsFlagSet("steel_embargo") then
			local continent = tostring(voToTag:GetCountry():GetCapitalLocation():GetContinent():GetTag())
			if continent == "north_america" or continent == "south_america" then
				if tostring(loDiploScoreObj.TagName) == "JAP" then
					return 0;
				end
			end
		end
	end

	if benchmarkLUA then
		Utils.addTime("Trade", os.clock() - t, isOMG)
	end

	return loDiploScoreObj.Score
end
function EvalutateExistingTrades(voAI, ministerTag)
	local CTradeData = {
		ministerAI = voAI,
		ministerTag = ministerTag,
		ministerCountry = ministerTag:GetCountry(),
		Resources = nil}

	local hasCustomTradeAi = CTradeData.ministerCountry:GetVariables():GetVariable(CString("zzDsafe_CustomTradeAiActive")):Get()
	if hasCustomTradeAi == 1 then
		-- Utils.LUA_DEBUGOUT("EvalutateExistingTradesCustomAi")
		EvalutateExistingTradesCustomAi(CTradeData)
		return
	end

	local debugTag = "XXX"
	local lbDebugIt = false
	if (tostring(ministerTag) == tostring(debugTag)) then
		Utils.LUA_DEBUGOUT("Country: " .. tostring(ministerTag))
		lbDebugIt = true
	end

	CTradeData.Resources = Support_Trade.Trade_GetResources(CTradeData.ministerTag, CTradeData.ministerCountry)

	local laHighResource = {}
	local laShortResource = {}
	local laCancel = {}
	local lbContinue = false
	local lbBuying = false
	local liMoneyOverage = 0
	local lbNeedMoney = CTradeData.ministerCountry:GetFlags():IsFlagSet("need_money")


	-- Figure out if we have a glutten of resources coming in
	for k, v in pairs(CTradeData.Resources) do
		if not(v.Bypass) then
			if v.Buy > 0 then
				lbBuying = true
			end

			-- We are buying and selling the same resource
			if v.TradeFor > 0 and v.TradeAway > 0 then
				-- Cancel something
				if v.DailyBalance > v.Buffer then
					laHighResource[k] = true
					lbContinue = true
				else
					laShortResource[k] = true
					lbContinue = true
				end
			else
				if k == "SUPPLIES" or k == "CRUDE_OIL" then
					-- If we are loosing money (give the buffer some leasticity before canceling by cutting it in half
					if CTradeData.Resources.MONEY.DailyBalance < (CTradeData.Resources.MONEY.Buffer * 0.5)
					or (v.Pool > v.BufferCancelCap)
					or (lbNeedMoney and (v.Pool > v.BufferSaleCap * 2)) then
						if v.TradeFor > 0 then
							laHighResource[k] = true
							lbContinue = true
							if lbDebugIt then
								Utils.LUA_DEBUGOUT(" high on " .. tostring(k))
							end
						end
					end

					-- Selling needed oil
					if k == "CRUDE_OIL" and v.Pool < v.BufferSaleCap
					and v.TradeAway > 0 then -- ignore balance as it flux too much, depending on both energy and fuel
						laShortResource[k] = true
						lbContinue = true

						if lbDebugIt then
							Utils.LUA_DEBUGOUT(" low on " .. tostring(k))
						end

					end
				else
					-- Gluten Check
					if v.TradeFor > 0 and v.Buy <= 0 then
						if (v.DailyBalance > v.Buffer) then
							-- If we are higher than our cancel pool or our daily balance is greater than the buffer multiplied by 2 (give some elasticity)
							if (v.Pool > v.BufferCancelCap) or (v.DailyBalance > (v.Buffer * 1.5)) then
								laHighResource[k] = true
								lbContinue = true

								if lbDebugIt then
									Utils.LUA_DEBUGOUT(" glut " .. tostring(k))
								end
							end
						end

					-- Selling what we need check
					elseif v.TradeAway > 0 then
						if v.DailyBalance < (v.Buffer * 0.5) then
							laShortResource[k] = true
							lbContinue = true
							if lbDebugIt then
								Utils.LUA_DEBUGOUT(" trade away low " .. tostring(k))
							end
						end
					end
				end
			end
		end
	end

	-- Few extra checks in case we have to much or to little money
	if not(lbContinue) then
		-- We are loosing money so look for stuff to cancel
		if lbNeedMoney or (CTradeData.Resources.MONEY.DailyBalance < (CTradeData.Resources.MONEY.Buffer * 0.5)) then
			if CTradeData.Resources.FUEL.TradeFor > 0 then
				laHighResource["FUEL"] = true
				lbContinue = true
			end
		end

		-- Supply check to see if we should cancel cause we are buying to much
		if CTradeData.Resources.MONEY.DailyBalance > (CTradeData.Resources.MONEY.Buffer * 1.5) then
			if CTradeData.Resources.SUPPLIES.TradeFor > 0 then
				if CTradeData.Resources.SUPPLIES.DailyBalance > (CTradeData.Resources.SUPPLIES.Buffer * 1.5) then
					if CTradeData.Resources.SUPPLIES.DailyBalance > (CTradeData.Resources.MONEY.Buffer) then
						laHighResource["SUPPLIES"] = true
						lbContinue = true
					end
				end

			-- Check to see if we are trading away to much
			elseif CTradeData.Resources.SUPPLIES.TradeAway > 0 and not(lbBuying) then
				liMoneyOverage = CTradeData.Resources.MONEY.DailyBalance - CTradeData.Resources.MONEY.Buffer

				if liMoneyOverage > 0 then
					laShortResource["SUPPLIES"] = true
					lbContinue = true
				end
			end
		end
	end

	for loTradeRoute in CTradeData.ministerCountry:AIGetTradeRoutes() do

		-- Special EMBARGO - CANCEL TRADE Checks

		-- Australia embargo Japan due to war in China
		if CCountryDataBase.GetTag("JAP"):GetCountry():GetFlags():IsFlagSet("australia_embargo_japan") then
			local TradeJap = {
				Trade = loTradeRoute,
				Command = nil,
				Money = 0,
				Quantity = 0}

			local loCountryTag = loTradeRoute:GetFrom()
			if loCountryTag == CTradeData.ministerTag then
				loCountryTag = loTradeRoute:GetTo()
			end

			TradeJap.Command = CTradeAction(CTradeData.ministerTag, loCountryTag)

			local tag = tostring(CTradeData.ministerTag)
			if tag == "AST" then
				if tostring(loTradeRoute:GetTo()) == "JAP" or tostring(loTradeRoute:GetFrom()) == "JAP" then
					TradeJap.Command:SetRoute(TradeJap.Trade)
					TradeJap.Command:SetValue(false)
					CTradeData.ministerAI:PostAction(TradeJap.Command)
				end
			end
		end

		-- Allies embargo Japan following USA
		if CCountryDataBase.GetTag("JAP"):GetCountry():GetFlags():IsFlagSet("steel_embargo") then
			local TradeJap = {
				Trade = loTradeRoute,
				Command = nil,
				Money = 0,
				Quantity = 0}

			local loCountryTag = loTradeRoute:GetFrom()
			if loCountryTag == CTradeData.ministerTag then
				loCountryTag = loTradeRoute:GetTo()
			end

			TradeJap.Command = CTradeAction(CTradeData.ministerTag, loCountryTag)

			local faction = tostring(CTradeData.ministerCountry:GetFaction():GetTag())
			if faction == "allies" then
				if tostring(loTradeRoute:GetTo()) == "JAP" or tostring(loTradeRoute:GetFrom()) == "JAP" then
					TradeJap.Command:SetRoute(TradeJap.Trade)
					TradeJap.Command:SetValue(false)
					CTradeData.ministerAI:PostAction(TradeJap.Command)
				end
			end
		end

		-- USA embargo on Japan (entire America complies due to US influence)
		if CCountryDataBase.GetTag("JAP"):GetCountry():GetFlags():IsFlagSet("steel_embargo") then
			local TradeJap = {
				Trade = loTradeRoute,
				Command = nil,
				Money = 0,
				Quantity = 0}

			local loCountryTag = loTradeRoute:GetFrom()
			if loCountryTag == CTradeData.ministerTag then
				loCountryTag = loTradeRoute:GetTo()
			end

			TradeJap.Command = CTradeAction(CTradeData.ministerTag, loCountryTag)

			local continent = tostring(CTradeData.ministerCountry:GetCapitalLocation():GetContinent():GetTag())
			if continent == "north_america" or continent == "south_america" then
				if tostring(loTradeRoute:GetTo()) == "JAP" or tostring(loTradeRoute:GetFrom()) == "JAP" then
					TradeJap.Command:SetRoute(TradeJap.Trade)
					TradeJap.Command:SetValue(false)
					CTradeData.ministerAI:PostAction(TradeJap.Command)
				end
			end
		end

		-- Kill Inactive Trades
		if loTradeRoute:IsInactive() and CTradeData.ministerAI:HasTradeGoneStale(loTradeRoute) then
			local loCountryTag= loTradeRoute:GetFrom()

			if loCountryTag == CTradeData.ministerTag then
				loCountryTag = loTradeRoute:GetTo()
			end

			local loTradeAction = CTradeAction(CTradeData.ministerTag, loCountryTag)
			loTradeAction:SetRoute(loTradeRoute)
			loTradeAction:SetValue(false)

			if loTradeAction:IsSelectable() then
				CTradeData.ministerAI:PostAction(loTradeAction)
			end

		else
			-- If nothing to do skip this
			if lbContinue then
				local loCountryTag = loTradeRoute:GetFrom()

				if loCountryTag == CTradeData.ministerTag then
					loCountryTag = loTradeRoute:GetTo()
				end

				for k, v in pairs(CTradeData.Resources) do
					if not(v.Bypass) then
						local Trade = {
							Trade = loTradeRoute,
							Command = nil,
							Money = 0,
							Quantity = 0}

						-- Are we short or High on anything
						if laShortResource[k] or laHighResource[k] then
							if laShortResource[k] then
								Trade.Quantity = loTradeRoute:GetTradedFromOf(v.CGoodsPool):Get()
							elseif laHighResource[k] then
								Trade.Quantity = loTradeRoute:GetTradedToOf(v.CGoodsPool):Get()
							end

							--local GetTradedFromOf = loTradeRoute:GetTradedFromOf(v.CGoodsPool):Get()
							--local GetTradedToOf = loTradeRoute:GetTradedToOf(v.CGoodsPool):Get()

							-- Look for the lowest one to cancel
							if Trade.Quantity > 0 then
								if k == "SUPPLIES" and liMoneyOverage > 0 then
									Trade.Money = loTradeRoute:GetTradedToOf(CTradeData.Resources.MONEY.CGoodsPool):Get()

									-- Clean up our Over selling of supplies
									if Trade.Money <= liMoneyOverage and not(laCancel[k]) then
										if not(laCancel[k]) then
											Trade.Command = CTradeAction(CTradeData.ministerTag, loCountryTag)
											laCancel[k] = Trade
										else
											if laCancel[k].Money < Trade.Money then
												Trade.Command = CTradeAction(CTradeData.ministerTag, loCountryTag)
												laCancel[k] = Trade
											end
										end
									end
								elseif not(laCancel[k]) then
									Trade.Command = CTradeAction(CTradeData.ministerTag, loCountryTag)
									laCancel[k] = Trade
								else
									-- Regular resource check
									if laCancel[k].Quantity > Trade.Quantity then
										Trade.Command = CTradeAction(CTradeData.ministerTag, loCountryTag)
										laCancel[k] = Trade
									end
								end
							end
						end
					end
				end
			end
		end
	end

	for k, v in pairs(laCancel) do
		v.Command:SetRoute(v.Trade)
		v.Command:SetValue(false)
		CTradeData.ministerAI:PostAction(v.Command)
	end
end
function ProposeTrades(vAI, ministerTag)
	local TradeData = {
		ministerAI = vAI,
		ministerTag = ministerTag,
		ministerCountry = ministerTag:GetCountry(),
		Resources = nil
	}

	-- EvalutateExistingTrades() too so the custom AI feels more responsive
	if TradeData.ministerCountry:GetVariables():GetVariable(CString("zzDsafe_CustomTradeAiActive")):Get() == 1 then
		EvalutateExistingTrades(vAI, ministerTag)
	end

	TradeData.Resources = Support_Trade.Trade_GetResources(TradeData.ministerTag, TradeData.ministerCountry)

	local laTrades = {} -- Contains an array of trades we will try to execute
	local lbNeedTrades = false -- DO we need any actual Trades
	local liMinTradeAmount = 0.25 -- Another copy if this in Support_Trade.Trade_GetResources
	local liMaxTradeAmount = 50

	for k, v in pairs(TradeData.Resources) do
		-- Can We solve our problems by Canceling Trades
	--	if v.Buy > 0 and v.TradeAway > 0 then
	--		v.Buy = TradeData.ministerAI:EvaluateCancelTrades(v.Buy, v.CGoodsPool)
	--	end

		if v.Buy > 0 or v.Sell > 0 then
			lbNeedTrades = true
		end
	end

    --local lbNeedMoney = TradeData.ministerCountry:GetFlags():IsFlagSet("need_money")

	-- Performance check, skip if we have nothing to do
	if lbNeedTrades then
		for loTCountry in CCurrentGameState.GetCountries() do

			-- Special EMBARGO - REFUSE TRADE checks
			local embargoed = false

			-- Allies embargo Japan due to war in China
			if CCountryDataBase.GetTag("JAP"):GetCountry():GetFlags():IsFlagSet("steel_embargo") then
				local faction = tostring(TradeData.ministerCountry:GetFaction():GetTag())
				if faction == "allies" then
					if tostring(loTCountry:GetCountryTag()) == "JAP" then
						embargoed = true
					end
				end
			end

			-- USA embargo on Japan (entire America complies due to US influence)
			if CCountryDataBase.GetTag("JAP"):GetCountry():GetFlags():IsFlagSet("steel_embargo") then
				local continent = tostring(TradeData.ministerCountry:GetCapitalLocation():GetContinent():GetTag())
				if continent == "north_america" or continent == "south_america" then
					if tostring(loTCountry:GetCountryTag()) == "JAP" then
						embargoed = true
					end
				end
			end

			-- Not embargoed candidate
			if not embargoed then

				local loCountryTrade = {
					Tag = loTCountry:GetCountryTag(),
					Country = loTCountry,
					Resources = nil,
					SpamPenalty = nil,
					FreeTrade = false,
					Relation = nil}

				if loCountryTrade.Tag ~= TradeData.ministerTag then
					if not(TradeData.ministerCountry:HasDiplomatEnroute(loCountryTrade.Tag)) and loTCountry:Exists() then
						loCountryTrade.Relation = TradeData.ministerAI:GetRelation(TradeData.ministerTag, loCountryTrade.Tag)

						if P.Can_Click_Button(loCountryTrade, TradeData) then
							loCountryTrade.Resources = Support_Trade.Trade_GetResources(loCountryTrade.Tag, loCountryTrade.Country)
							loCountryTrade.SpamPenalty = TradeData.ministerAI:GetSpamPenalty(loCountryTrade.Tag)
							loCountryTrade.FreeTrade = Support_Trade.FreeTradeCheck(TradeData.ministerAI, loCountryTrade.Tag, TradeData.ministerTag, loCountryTrade.Relation)

							for k, v in pairs(loCountryTrade.Resources) do
								if not(v.Bypass) then
									local loTrade = {
										Resource = v.CGoodsPool,
										Score = 0,
										Buy = false,
										Sell = false,
										FreeTrade = loCountryTrade.FreeTrade,
										Command = nil,
										Quantity = 0}

									-- They have something we need
									if v.Sell > 0 and TradeData.Resources[k].Buy > 0 then
										loTrade.Buy = true
										loTrade.Quantity = math.min(v.Sell, TradeData.Resources[k].Buy, liMaxTradeAmount)
									else
										if loCountryTrade.Resources.MONEY.DailyIncome > 0 or loCountryTrade.FreeTrade then
											-- They need something we are selling
											if v.Buy > 0 and TradeData.Resources[k].Sell > 0 then
												loTrade.Sell = true
												loTrade.Quantity = math.min(v.Buy, TradeData.Resources[k].Sell, liMaxTradeAmount)
											end
										end
									end

									-- Now lets gets a score
									if loTrade.Buy then
										local loCommand = CTradeAction(TradeData.ministerTag, loCountryTrade.Tag)
										loCommand:SetTrading(CFixedPoint(loTrade.Quantity), v.CGoodsPool)

										if not(TradeData.ministerAI:AlreadyTradingDisabledResource(loCommand:GetRoute())) then
											if loCommand:IsValid() and loCommand:IsSelectable() then
												local liCost = loCommand:GetTrading(CGoodsPool._MONEY_, TradeData.ministerTag):Get()

												if liCost > TradeData.Resources.MONEY.CanSpend and not(loCountryTrade.FreeTrade) then
													local liMultiplier = liCost / loTrade.Quantity
													loTrade.Quantity = TradeData.Resources.MONEY.CanSpend / liMultiplier
													loCommand:SetTrading(CFixedPoint(loTrade.Quantity), v.CGoodsPool)
												end

												if loTrade.Quantity > liMinTradeAmount then
													loTrade.Score = loCommand:GetAIAcceptance() - loCountryTrade.SpamPenalty

													if loTrade.Score > 50 then
														loTrade.Command = loCommand
													end
												end
											end
										end

									elseif loTrade.Sell then
										local loCommand = CTradeAction(TradeData.ministerTag, loCountryTrade.Tag)
										loCommand:SetTrading(CFixedPoint(loTrade.Quantity * -1), v.CGoodsPool)

										if not(TradeData.ministerAI:AlreadyTradingDisabledResource(loCommand:GetRoute())) then
											if loCommand:IsValid() and loCommand:IsSelectable() then
												local liCost = loCommand:GetTrading(CGoodsPool._MONEY_, loCountryTrade.Tag):Get()

												if liCost > loCountryTrade.Resources.MONEY.CanSpend and not(loCountryTrade.FreeTrade) then
													local liMultiplier = liCost / loTrade.Quantity
													loTrade.Quantity = loCountryTrade.Resources.MONEY.CanSpend / liMultiplier
													loCommand:SetTrading(CFixedPoint(loTrade.Quantity * -1), v.CGoodsPool)
												end

												if loTrade.Quantity > liMinTradeAmount then
													loTrade.Score = loCommand:GetAIAcceptance() - loCountryTrade.SpamPenalty

													if loTrade.Score > 50 then
														loTrade.Command = loCommand
													end
												end
											end
										end
									end

									-- Add it to the processing Array
									if loTrade.Command then
										laTrades[tostring(loCountryTrade.Tag) .. tostring(k)] = loTrade
									end
								end
							end
						end
					end
				end

			end
		end

		local loFinalTrade = nil
		-- Do we have potential trades to process
		for k, v in pairs(laTrades) do
			if not(loFinalTrade) then
				loFinalTrade = v
			else
				-- Free Trades get priority
				if v.FreeTrade then
					if not(loFinalTrade.FreeTrade) then
						loFinalTrade = v
					elseif v.Score > loFinalTrade.Score then
						loFinalTrade = v
					end
				elseif v.Score > loFinalTrade.Score then
					loFinalTrade = v
				end
			end
		end

		if loFinalTrade then
			TradeData.ministerAI:PostAction(loFinalTrade.Command)
		end
	end
end

-- #######################
-- Support Methods
-- #######################
function P.Trade_IsMajor()
	local laResouces = {
		MONEY = {
			ByPass = true,
			Buffer = 0.5,   -- we need to finance a lot of options
			BufferSaleCap = 20,
			TradeOBJ = "vMoney",
			CGoodsPool = CGoodsPool._MONEY_},
		METAL = {
			Buffer = 1, 			-- Amount extra to keep abouve our needs
			BufferSaleCap = 5000, 	-- Amount we need in reserve before we sell the resource
			BufferBuyCap = 80000, 	-- Amount we need before we stop actively buying (existing trades are NOT cancelled)
			BufferCancelCap = 90000, -- Amount we need before we cancel trades simply because we have to much
			ScoreFactor = 2, 		-- Multiplier used when calculating the final trade score against the resource (resource count * ScoreFactor)
			Multiplier = 1, 		-- (DO NOT OVERIDE THIS IN COUNTRY FILES)
			TradeOBJ = "vMetal",	-- (DO NOT OVERIDE THIS IN COUNTRY FILES)
			CGoodsPool = CGoodsPool._METAL_},	-- (DO NOT OVERIDE THIS IN COUNTRY FILES)
		ENERGY = {
			Buffer = 5,
			BufferSaleCap = 600,
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 1,
			Multiplier = 2, 		-- Factor to use to calculate needs
			TradeOBJ = "vEnergy",
			CGoodsPool = CGoodsPool._ENERGY_},
		RARE_MATERIALS = {
			Buffer = 0.5,
			BufferSaleCap = 150,
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 4,
			Multiplier = 0.5, 		-- Factor to use to calculate needs
			TradeOBJ = "vRareMaterials",
			CGoodsPool = CGoodsPool._RARE_MATERIALS_},
		CRUDE_OIL = {
			BuyOveride = true,
			Buffer = 0.25,
			BufferSaleCap = 1500, -- need to be greater than flux
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 2,
			TradeOBJ = "vCrudeOil",
			CGoodsPool = CGoodsPool._CRUDE_OIL_},
		SUPPLIES = {
			BuyOveride = true,
			Buffer = 1,
			BufferSaleCap = 5000, -- Ignored for supplies
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 3,
			TradeOBJ = "vSupplies",
			CGoodsPool = CGoodsPool._SUPPLIES_},
		FUEL = {
			BuyOveride = true,
			Buffer = 0.25,     -- buffer of 0.25 doesn't make sense for majors, where flux can be 15K
			BufferSaleCap = 15000, -- need to be greater than flux
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 2,
			TradeOBJ = "vFuel",
			CGoodsPool = CGoodsPool._FUEL_}}

	return laResouces
end

function P.Trade_GetResources(voTag, voCountry, vbHumanSelling)
	local liMinTradeAmount = 0.51
	local ResourceData = {
		ministerTag = voTag,
		ministerCountry = voCountry,
		TechStatus = nil,
		BaseIC = nil,
		TotalIC = nil,
		ModifierICTech = nil,
		ModifierICGlobal = nil}
	local liMoney = CGoodsPool._MONEY_
	local laResouces

	if liMoney > 500 then
		laResouces = {
		MONEY = {
			ByPass = true,
			Buffer = 0.0001,
			BufferSaleCap = 20,
			TradeOBJ = "vMoney",
			CGoodsPool = CGoodsPool._MONEY_},
		METAL = {
			Buffer = 1, 			-- Amount extra to keep abouve our needs
			BufferSaleCap = 300, 	-- Amount we need in reserve before we sell the resource
			BufferBuyCap = 80000, 	-- Amount we need before we stop actively buying (existing trades are NOT cancelled)
			BufferCancelCap = 90000, -- Amount we need before we cancel trades simply because we have to much
			ScoreFactor = 2, 		-- Multiplier used when calculating the final trade score against the resource (resource count * ScoreFactor)
			Multiplier = 1, 		-- (DO NOT OVERIDE THIS IN COUNTRY FILES)
			TradeOBJ = "vMetal",	-- (DO NOT OVERIDE THIS IN COUNTRY FILES)
			CGoodsPool = CGoodsPool._METAL_},	-- (DO NOT OVERIDE THIS IN COUNTRY FILES)
		ENERGY = {
			Buffer = 5,
			BufferSaleCap = 600,
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 1,
			Multiplier = 2, 		-- Factor to use to calculate needs
			TradeOBJ = "vEnergy",
			CGoodsPool = CGoodsPool._ENERGY_},
		RARE_MATERIALS = {
			Buffer = 0.5,
			BufferSaleCap = 150,
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 4,
			Multiplier = 0.5, 		-- Factor to use to calculate needs
			TradeOBJ = "vRareMaterials",
			CGoodsPool = CGoodsPool._RARE_MATERIALS_},
		CRUDE_OIL = {
			BuyOveride = true,
			Buffer = 0.25,
			BufferSaleCap = 500,
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 2,
			TradeOBJ = "vCrudeOil",
			CGoodsPool = CGoodsPool._CRUDE_OIL_},
		SUPPLIES = {
			BuyOveride = true,
			Buffer = 1,
			BufferSaleCap = 5000, -- Ignored for supplies
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 3,
			TradeOBJ = "vSupplies",
			CGoodsPool = CGoodsPool._SUPPLIES_},
		FUEL = {
			BuyOveride = true,
			Buffer = 0.25,
			BufferSaleCap = 1500,
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 2,
			TradeOBJ = "vFuel",
			CGoodsPool = CGoodsPool._FUEL_}}
	else
		laResouces = {
		MONEY = {
			ByPass = true,
			Buffer = 0.1,
			BufferSaleCap = 20,
			TradeOBJ = "vMoney",
			CGoodsPool = CGoodsPool._MONEY_},
		METAL = {
			Buffer = 1, 			-- Amount extra to keep abouve our needs
			BufferSaleCap = 300, 	-- Amount we need in reserve before we sell the resource
			BufferBuyCap = 80000, 	-- Amount we need before we stop actively buying (existing trades are NOT cancelled)
			BufferCancelCap = 90000, -- Amount we need before we cancel trades simply because we have to much
			ScoreFactor = 2, 		-- Multiplier used when calculating the final trade score against the resource (resource count * ScoreFactor)
			Multiplier = 1, 		-- (DO NOT OVERIDE THIS IN COUNTRY FILES)
			TradeOBJ = "vMetal",	-- (DO NOT OVERIDE THIS IN COUNTRY FILES)
			CGoodsPool = CGoodsPool._METAL_},	-- (DO NOT OVERIDE THIS IN COUNTRY FILES)
		ENERGY = {
			Buffer = 5,
			BufferSaleCap = 600,
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 1,
			Multiplier = 2, 		-- Factor to use to calculate needs
			TradeOBJ = "vEnergy",
			CGoodsPool = CGoodsPool._ENERGY_},
		RARE_MATERIALS = {
			Buffer = 0.5,
			BufferSaleCap = 150,
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 4,
			Multiplier = 0.5, 		-- Factor to use to calculate needs
			TradeOBJ = "vRareMaterials",
			CGoodsPool = CGoodsPool._RARE_MATERIALS_},
		CRUDE_OIL = {
			BuyOveride = true,
			Buffer = 0.25,
			BufferSaleCap = 500,
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 2,
			TradeOBJ = "vCrudeOil",
			CGoodsPool = CGoodsPool._CRUDE_OIL_},
		SUPPLIES = {
			BuyOveride = true,
			Buffer = 1,
			BufferSaleCap = 5000, -- Ignored for supplies
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 3,
			TradeOBJ = "vSupplies",
			CGoodsPool = CGoodsPool._SUPPLIES_},
		FUEL = {
			BuyOveride = true,
			Buffer = 0.25,
			BufferSaleCap = 1500,
			BufferBuyCap = 80000,
			BufferCancelCap = 90000,
			ScoreFactor = 2,
			TradeOBJ = "vFuel",
			CGoodsPool = CGoodsPool._FUEL_}}
	end

       	local lbNeedMoney = ResourceData.ministerCountry:GetFlags():IsFlagSet("need_money")

       	if (lbNeedMoney) then
       	        laResouces.MONEY.Buffer = 10
       	end

	-- Need to do this formula because if any resource falls to O then GetTotalIC does not return their true max
	ResourceData.BaseIC = ResourceData.ministerCountry:GetMaxIC()
	ResourceData.TechStatus = ResourceData.ministerCountry:GetTechnologyStatus()
	ResourceData.ModifierICTech = ResourceData.TechStatus:GetIcModifier():Get()
	ResourceData.ModifierICGlobal = ResourceData.ministerCountry:GetGlobalModifier():GetValue(CModifier._MODIFIER_GLOBAL_IC_):Get()
	ResourceData.TotalIC = math.floor(ResourceData.BaseIC + (ResourceData.BaseIC * ResourceData.ModifierICTech) + (ResourceData.BaseIC * ResourceData.ModifierICGlobal))

	local loFunRef = Utils.HasCountryAIFunction(ResourceData.ministerTag, "TradeWeights")

    local lbIsMajor = ResourceData.ministerCountry:IsMajor()
	if lbIsMajor then -- before the country specific in case they want to change it.
		laResouces = Support_Trade.Trade_IsMajor()
	end

	if loFunRef then
		local laResourcePassed = loFunRef(ResourceData)

		if laResourcePassed then
			for k, v in pairs(laResourcePassed) do
				for x, y in pairs(laResourcePassed[k]) do
					laResouces[k][x] = laResourcePassed[k][x]
				end
			end
		end
	end

	local hasCustomTradeAi = ResourceData.ministerCountry:GetVariables():GetVariable(CString("zzDsafe_CustomTradeAiActive")):Get()
	if hasCustomTradeAi == 1 then
		-- Utils.LUA_DEBUGOUT("------ Pre ------")
		-- Utils.INSPECT_TABLE(laResouces)

		-- t = os.clock()
		laResouces = GetCustomTradeAiLimits(tostring(ResourceData.ministerTag), ResourceData.ministerTag, laResouces)
		-- Utils.LUA_DEBUGOUT('GetCustomTradeAiLimits')
		-- Utils.LUA_DEBUGOUT(os.clock() - t)

		-- Utils.LUA_DEBUGOUT("------ Post ------")
		-- Utils.INSPECT_TABLE(laResouces)
	end

	local lbBuying = false
	local loResource = CResourceValues()
	local loTradeAway = ResourceData.ministerCountry:GetTradedAwaySansAlliedSupply()
	local loTradeFor = ResourceData.ministerCountry:GetTradedForSansAlliedSupply()


	for k, v in pairs(laResouces) do
		loResource:GetResourceValues(ResourceData.ministerCountry, v.CGoodsPool)
		v.DailyBalance = loResource.vDailyBalance
		v.DailyExpense = loResource.vDailyExpense -- Modify this to use IC to count expense not resources
		v.DailyIncome = loResource.vDailyIncome
		v.DailyHome = Support.CalculateHomeProduced(loResource)
		v.Pool = loResource.vPool

		-- If we have a multiplier then check
		if v.Multiplier then
			-- This is to handle in case resources hit 0 so the AI knows it needs allot more
			v.DailyExpense = math.max(v.DailyExpense, (v.Multiplier * ResourceData.TotalIC))
			v.DailyBalance = v.DailyIncome - v.DailyExpense
		end

		v.Buy = 0
		v.Sell = 0
		v.TradeAway = 0
		v.TradeFor = 0
		v.ShortPercentage = 0

		-- Now Calculate what our needs are
		if not(v.ByPass) then
			v.TradeFor = loTradeFor:GetFloat(v.CGoodsPool)
			v.TradeAway = loTradeAway:GetFloat(v.CGoodsPool)

			if v.DailyBalance < v.Buffer and v.TradeAway <= 0 then
				-- Make sure we are not being a gluten with the resources before we buy
				if v.Pool < v.BufferBuyCap then
					local liBuy = (v.DailyBalance  * -1) + v.Buffer
					if liBuy >= liMinTradeAmount then
						v.Buy = liBuy

						if not(v.BuyOveride) then
							lbBuying = true
						end
					end
				end
			elseif (hasCustomTradeAi == 0) and (v.DailyBalance > v.Buffer) then
				if (v.TradeFor <= 0 or vbHumanSelling) and (v.Pool > v.BufferSaleCap) then
					v.Sell = v.DailyBalance - v.Buffer
				end
			end
			if (hasCustomTradeAi == 1) and (v.Pool > v.BufferSaleCap) and (v.TradeFor <= 0) then
				local MaxDailySell = CustomTradeAiValues[tostring(ResourceData.ministerTag)].MONEY.MaxDailySell
				v.Sell = math.max(0, (v.DailyBalance + MaxDailySell))
			end
		end

		-- Calculate Short Percentage
		if v.Buy > 0 and v.DailyIncome > 0 and v.DailyExpense > 0 then
			v.ShortPercentage = (1.0 - (v.DailyIncome / v.DailyExpense))
		elseif v.Buy > 0 then
			v.ShortPercentage = 1.0
		end
	end

	laResouces.MONEY.CanSpend = laResouces.MONEY.DailyBalance - laResouces.MONEY.Buffer

	-- custom trade AI will balance its money by selling resources when dropping below the buffer
	if hasCustomTradeAi == 1 then
		laResouces.MONEY.CanSpend = math.max(10,laResouces.MONEY.DailyBalance) -- can use at least 10 money for trades
	end

	-- Crude oil needs check, makes sure we don't buy crude and instead spend cash on supplies
	if laResouces.CRUDE_OIL.Buy > 0 then
		if (laResouces.FUEL.DailyBalance > laResouces.FUEL.Buffer
		and laResouces.CRUDE_OIL.DailyHome > (laResouces.FUEL.DailyBalance * 0.5)
		-- just raise FUEL.BufferSaleCap instead .. and laResouces.CRUDE_OIL.Pool < (laResouces.CRUDE_OIL.BufferSaleCap * 0.5) -- low on oil
		and laResouces.FUEL.Pool > laResouces.FUEL.BufferSaleCap)
		or lbBuying then
			laResouces.CRUDE_OIL.Buy = 0
		end
	end

	-- We are buying but short on money so setup Supply selling
	--Utils.LUA_DEBUGOUT("Money balance: " .. laResouces.MONEY.DailyBalance)
	--Utils.LUA_DEBUGOUT("Money buffer: " .. laResouces.MONEY.Buffer)
	--Utils.LUA_DEBUGOUT("Supplies Traded For: " .. laResouces.SUPPLIES.TradeFor)
	--Utils.LUA_DEBUGOUT("Supplies Traded Away: " .. laResouces.SUPPLIES.TradeAway)
	if laResouces.MONEY.DailyBalance <= laResouces.MONEY.Buffer and laResouces.SUPPLIES.TradeFor <= 0 then
		local liTotalIC = ResourceData.ministerCountry:GetTotalIC()
		laResouces.SUPPLIES.Buy = 0
		laResouces.SUPPLIES.Sell = math.min(50, (liTotalIC - laResouces.SUPPLIES.TradeAway))
		laResouces.SUPPLIES.ShortPercentage = 1.0
		if hasCustomTradeAi == 1 then
			laResouces.SUPPLIES.Sell = math.random(2,10) + (laResouces.MONEY.Buffer - laResouces.MONEY.DailyBalance)
		end

	-- We are not buying and have money to spend to pick up supplies
	elseif laResouces.MONEY.DailyBalance > laResouces.MONEY.Buffer and laResouces.SUPPLIES.TradeAway <= 0 then
		laResouces.SUPPLIES.Sell = 0
		laResouces.SUPPLIES.Buy = math.min(50, ((laResouces.SUPPLIES.DailyExpense * 1.2) - laResouces.SUPPLIES.TradeFor))
		laResouces.SUPPLIES.ShortPercentage = 1.0
		if hasCustomTradeAi == 1 then
			-- CustomAI never buys supplies
			laResouces.SUPPLIES.Buy = 0
		end

	-- Not buying or selling supplies so set it to 0
	else
		laResouces.SUPPLIES.Buy = 0
		laResouces.SUPPLIES.Sell = 0
	end

	return laResouces
end
function P.FreeTradeCheck(voAI, voToTag, voFromTag, voRelation)
	-- Commiterm Check or ALlow Debt check
	if voAI:CanTradeFreeResources(voToTag, voFromTag) or voRelation:AllowDebts() then
		return true
	else
		return false
	end
end
function P.Can_Click_Button(voTarget, voTradeData)
	if voTarget.Country:Exists() then
		if voTarget.Tag:IsReal() then
			if voTarget.Tag:IsValid() then
				if not(voTarget.Country:IsPuppet()) then
					if not(voTarget.Relation:HasWar()) then
						if not(voTradeData.ministerCountry:HasDiplomatEnroute(voTarget.Tag)) then
							return true
						end
					end
				end
			end
		end
	end

	return false
end
-- ###############################################
-- END OF Support methods
-- ###############################################


-- ###############################################
-- Custom trade AI
-- ###############################################

CustomTradeAiValues = {}

CustomTradeAiLimitsInitialized = false
function GetCustomTradeAiLimits(Tag, ministerTag, laResouces)
	if CustomTradeAiLimitsInitialized == false then
		InitCustomTradeAiData()
	end
	GetCustomTradeAiDataFromVariables(ministerTag)
	-- Utils.INSPECT_TABLE(CustomTradeAiValues[Tag])

	for k, v in pairs(CustomTradeAiValues[Tag]) do
		for x, y in pairs(CustomTradeAiValues[Tag][k]) do
			laResouces[k][x] = CustomTradeAiValues[Tag][k][x]
		end
	end

	return laResouces
end

-- This creates an array in memory with defaultvalues for every country, and then calls GetCustomTradeAiDataFromVariables to put the real values in
function InitCustomTradeAiData()
	-- Utils.LUA_DEBUGOUT("InitCustomTradeAiData")
	if CountryIterCacheCheck == 0 then
		CountryIterCache()
	end

	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
			CustomTradeAiValues[tag] = table.deepcopy(CustomTradeAiDefaults.TradeLimits)
			GetCustomTradeAiDataFromVariables(countryTag, false)
		end
	end
	CustomTradeAiLimitsInitialized = true
end

function GetCustomTradeAiDataFromVariables(countryTag, helper)
	-- local helper -- this variable is used to bypass the zzDsafe_usesCustomTradeAi check and set it too so the player can set values first and active the system after
	local country = countryTag:GetCountry()
	local tag = tostring(countryTag)
	if country:GetVariables():GetVariable(CString("zzDsafe_usesCustomTradeAi")):Get() == 1 or helper then
		CustomTradeAiValues[tag].MONEY.MaxDailySell = country:GetVariables():GetVariable(CString("zzDsafe_TradeAi_MaxDailySell")):Get()
		CustomTradeAiValues[tag].MONEY.Buffer = country:GetVariables():GetVariable(CString("zzDsafe_TradeAi_MONEY_Buffer")):Get()
		CustomTradeAiValues[tag].MONEY.BufferSaleCap = country:GetVariables():GetVariable(CString("zzDsafe_TradeAi_MONEY_BufferSaleCap")):Get()
		for x, y in pairs(CustomTradeAiValues[tag]) do
			if x ~= "MONEY" then
				CustomTradeAiValues[tag][x].Buffer = country:GetVariables():GetVariable(CString("zzDsafe_TradeAi_"..x.."_Buffer")):Get()
				CustomTradeAiValues[tag][x].BufferSaleCap = country:GetVariables():GetVariable(CString("zzDsafe_TradeAi_"..x.."_BufferSaleCap")):Get()
				CustomTradeAiValues[tag][x].BufferBuyCap = country:GetVariables():GetVariable(CString("zzDsafe_TradeAi_"..x.."_BufferBuyCap")):Get()
				CustomTradeAiValues[tag][x].BufferCancelCap = country:GetVariables():GetVariable(CString("zzDsafe_TradeAi_"..x.."_BufferCancelCap")):Get()
			end
		end
		if helper then
			local command = CSetVariableCommand(countryTag, CString("zzDsafe_usesCustomTradeAi"), CFixedPoint(1))
			CCurrentGameState.Post(command)
		end
	end
end

function CheckCountryWantsToChangeCustomTradeAi()
	if CustomTradeAiLimitsInitialized == false then
		InitCustomTradeAiData()
	end
	for k, v in pairs(CountryIterCacheDict) do
		local countryTag = v
		local tag = k
		if tag ~= "REB" and tag ~= "OMG" and tag ~= "---" then
			local country = countryTag:GetCountry()
			if country:GetVariables():GetVariable(CString("zzDsafe_WantsToChangeCustomTradeAi")):Get() == 1 then
				GetCustomTradeAiDataFromVariables(countryTag, true)
				local command = CSetVariableCommand(countryTag, CString("zzDsafe_WantsToChangeCustomTradeAi"), CFixedPoint(0))
				CCurrentGameState.Post(command)
			end
		end
	end
end


function EvalutateExistingTradesCustomAi(CTradeData)

	CTradeData.Resources = Support_Trade.Trade_GetResources(CTradeData.ministerTag, CTradeData.ministerCountry)
	local stopBuyingResource = {}
	local stopSellingResource = {}
	local laCancel = {}
	local lbContinue = false

	-- Utils.INSPECT_TABLE(CTradeData.Resources)

	-- Figure out if we have a glutten of resources coming in
	-- Utils.INSPECT_TABLE(CTradeData.Resources)
	for k, v in pairs(CTradeData.Resources) do
		if not(v.Bypass) then

			-- We are buying and selling the same resource
			if v.TradeFor > 0 and v.TradeAway > 0 then
				-- Cancel something
				if v.DailyBalance > v.Buffer then
					stopBuyingResource[k] = true
					lbContinue = true
					-- Utils.LUA_DEBUGOUT("two way trade - stopBuyingResource - " .. k)
				else
					stopSellingResource[k] = true
					lbContinue = true
					-- Utils.LUA_DEBUGOUT("two way trade - stopSellingResource - " .. k)
				end
			else
				-- consider a resource too high if its above cap + 10%
				if k ~= "MONEY" and k ~= "SUPPLIES" and v.TradeFor > 0 and v.Pool > (v.BufferCancelCap * 1.1) then
					stopBuyingResource[k] = true
					lbContinue = true
					-- Utils.LUA_DEBUGOUT("high on " .. k)
				elseif k ~= "MONEY" and k ~= "SUPPLIES" and v.TradeFor > 0 and v.DailyBalance > (v.Buffer * 1.1)  then
					stopBuyingResource[k] = true
					lbContinue = true
					-- Utils.LUA_DEBUGOUT("buying too much " .. k)
				elseif k == "SUPPLIES" and v.TradeFor > 0 and (
				(CTradeData.Resources.MONEY.DailyBalance < CTradeData.Resources.MONEY.Buffer)) then -- we are stupidly buying supplies
					stopBuyingResource[k] = true
					lbContinue = true
					-- Utils.LUA_DEBUGOUT("buying too many supplies")
				elseif k == "SUPPLIES" and v.TradeAway > 0 and (
				(CTradeData.Resources.MONEY.DailyBalance > (CTradeData.Resources.MONEY.Buffer * 1.5))) then -- we are making too much money
					stopSellingResource[k] = true
					lbContinue = true
					-- Utils.LUA_DEBUGOUT("selling too many supplies")
				elseif k ~= "MONEY" and k ~= "SUPPLIES" and v.TradeAway > 0 and (v.Pool < v.BufferSaleCap or v.DailyBalance < -CTradeData.Resources.MONEY.MaxDailySell) then
					stopSellingResource[k] = true
					lbContinue = true
					-- Utils.LUA_DEBUGOUT("selling too much " .. k)
				end
			end
		end
	end

	for loTradeRoute in CTradeData.ministerCountry:AIGetTradeRoutes() do

		-- Kill Inactive Trades
		if loTradeRoute:IsInactive() and CTradeData.ministerAI:HasTradeGoneStale(loTradeRoute) then
			local loCountryTag= loTradeRoute:GetFrom()

			if loCountryTag == CTradeData.ministerTag then
				loCountryTag = loTradeRoute:GetTo()
			end

			local loTradeAction = CTradeAction(CTradeData.ministerTag, loCountryTag)
			loTradeAction:SetRoute(loTradeRoute)
			loTradeAction:SetValue(false)

			if loTradeAction:IsSelectable() then
				CTradeData.ministerAI:PostAction(loTradeAction)
			end

		else
			-- If nothing to do skip this
			if lbContinue then
				local isBuying = false
				local tradePartnerTag = loTradeRoute:GetFrom()
				local ministerTagIsFrom = false

				if tradePartnerTag == CTradeData.ministerTag then
					tradePartnerTag = loTradeRoute:GetTo()
					ministerTagIsFrom = true
				end


				if ministerTagIsFrom and loTradeRoute:GetTradedFromOf(CGoodsPool._MONEY_):Get() > 0 then
					isBuying = true
				elseif not ministerTagIsFrom and loTradeRoute:GetTradedToOf(CGoodsPool._MONEY_):Get() > 0 then
					isBuying = true
				end


				for k, v in pairs(CTradeData.Resources) do
					if not(v.Bypass) then
						local Trade = {
							Trade = loTradeRoute,
							Command = nil,
							Money = 0,
							Quantity = 0,
							Trigger = nil}

						-- Are we short or High on anything
						if stopSellingResource[k] or stopBuyingResource[k] then
							-- if k == "RARE_MATERIALS" then
							-- 	if loTradeRoute:GetTradedToOf(v.CGoodsPool):Get() > 0 or loTradeRoute:GetTradedFromOf(v.CGoodsPool):Get() > 0 then
							-- 		Utils.Trade_Dumper(loTradeRoute)
							-- 		Utils.LUA_DEBUGOUT(tostring(isBuying))
							-- 	end
							-- end
							if isBuying == false and stopSellingResource[k] then
								if ministerTagIsFrom then
									Trade.Quantity = loTradeRoute:GetTradedFromOf(v.CGoodsPool):Get()
								else
									Trade.Quantity = loTradeRoute:GetTradedToOf(v.CGoodsPool):Get()
								end
								Trade.Trigger = "stopSellingResource"
								if Trade.Quantity > 0 then
									-- Utils.Trade_Dumper(loTradeRoute)
								end
							elseif isBuying == true and stopBuyingResource[k] then
								if ministerTagIsFrom then
									Trade.Quantity = loTradeRoute:GetTradedToOf(v.CGoodsPool):Get()
								else
									Trade.Quantity = loTradeRoute:GetTradedFromOf(v.CGoodsPool):Get()
								end
								Trade.Trigger = "stopBuyingResource"
								if Trade.Quantity > 0 then
									-- Utils.Trade_Dumper(loTradeRoute)
								end
							end
							-- local GetTradedFromOf = loTradeRoute:GetTradedFromOf(v.CGoodsPool):Get()
							-- local GetTradedToOf = loTradeRoute:GetTradedToOf(v.CGoodsPool):Get()

							-- Look for the lowest one to cancel
							if Trade.Quantity > 0 then
								if not(laCancel[k]) then
									Trade.Command = CTradeAction(CTradeData.ministerTag, tradePartnerTag)
									laCancel[k] = Trade
								else
									-- Regular resource check
									if laCancel[k].Quantity > Trade.Quantity then
										Trade.Command = CTradeAction(CTradeData.ministerTag, tradePartnerTag)
										laCancel[k] = Trade
									end
								end
							end
						end
					end
				end
			end
		end
	end

	-- Utils.INSPECT_TABLE(laCancel)
	for k, v in pairs(laCancel) do
		v.Command:SetRoute(v.Trade)
		v.Command:SetValue(false)
		CTradeData.ministerAI:PostAction(v.Command)
	end
end

return Support_Trade