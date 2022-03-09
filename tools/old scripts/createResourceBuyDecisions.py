
CountryListAll = [
	"AFG",	"ALB",	"ARG",	"ARM",	"AST",	"AUS",	"AZB",	"BBU",
	"BEL",	"BHU",	"BIN",	"BLR",	"BOL",	"BRA",	"BUL",	"CAN",
	"CGX",	"CHC",	"CHI",	"CHL",	"COL",	"COS",	"CRO",	"CSX",
	"CUB",	"CXB",	"CYN",	"CYP",	"CZE",	"DDR",	"DEN",	"DFR",
	"DOM",	"ECU",	"EGY",	"ENG",	"EST",	"ETH",	"FIN",	"FRA",
	"GEO",	"GER",	"GRE",	"GUA",	"GUY",	"HAI",	"HOL",	"HON",
	"HUN",	"ICL",	"IDC",	"IND",	"INO",	"IRE",	"IRQ",	"ISR",
	"ITA",	"JAP",	"JOR",	"KOR",	"KWT",	"LAT",	"LEB",	"LIB",
	"LIT",	"LUX",	"MAD",	"MAN",	"MEN",	"MEX",	"MON",	"MTA",
	"MTN",	"NEP",	"NIC",	"NJG",	"NOR",	"NZL",	"OMG",	"OMN",
	"PAK",	"PAL",	"PAP",	"PAR",	"PER",	"POL",	# No PAN or PHI because they are bugged
	"POR",	"PRK",	"PRU",	"REB",	"RKK",	"RKM",	"RKO",	"RKU",
	"ROM",	"RSI",	"RUR",	"SAF",	"SAL",	"SAU",	"SCH",	"SER",
	"SIA",	"SIK",	"SLO",	"SLV",	"SOM",	"SOV",	"SPA",	"SPR",
	"SUD",	"SUR",	"SWE",	"SYR",	"TAN",	"TIB",	"TIM",	"TUR",
	"UKR",	"URU",	"USA",	"VEN",	"VIC",	"YEM",	"YUG",
]

resources = [
    "chromite",
	"aluminium",
	"rubber",
	"tungsten",
	"nickel",
	"copper",
	"zinc",
	"manganese",
	"molybdenum"
]

resource = "zinc"

with open("output.txt", "w") as openFile:
    i = 0
    for tag in CountryListAll:
        i = i + 1
        openFile.write(
           f"""
    buy_resource_{resource}_from_{tag} = {{
		potential = {{
			exists = {tag}
			has_country_flag = {resource}_trades_active

			not = {{
				has_country_modifier = trade_cooldown
				has_country_modifier = strategic_resources_break
				check_variable = {{
					which = {resource}_ActualBalance
					value = 1004
				}}
			}}
			{tag} = {{
				check_variable = {{
					which = {resource}_MaxSells
					value = 1
				}}

				not = {{
					has_country_modifier = trade_cooldown
				}}
			}}

			not = {{
				war_with = {tag}
				tag = {tag}
			}}
		}}
		allow = {{
			money = 2000
		}}
		effect = {{
			{tag} = {{
				country_event = 13308
				add_country_modifier = {{
					name = "trade_cooldown"
					duration = 7
				}}
			}}
			set_variable = {{
				which = pending_trade_wants_to_buy_from
				value = {i}
			}}
			add_country_modifier = {{
				name = "trade_cooldown"
				duration = 7
			}}
			clr_country_flag = aluminium_trades_active
			clr_country_flag = rubber_trades_active
			clr_country_flag = tungsten_trades_active
			clr_country_flag = chromite_trades_active
			clr_country_flag = copper_trades_active
			clr_country_flag = zinc_trades_active
			clr_country_flag = manganese_trades_active
			clr_country_flag = molybdenum_trades_active
			clr_country_flag = nickel_trades_active
		}}
		ai_will_do = {{
			factor = 1
		}}
	}}
"""
        )