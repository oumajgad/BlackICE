G_AiStrategicTradeAggression = 4
G_PlayerCountries = {} -- init globally to avoid errors in other functions

CountryListA = {
	["AFG"]=true;	["ALB"]=true;	["ARG"]=true;	["ARM"]=true;	["AST"]=true;	["AUS"]=true;	["AZB"]=true;	["BBU"]=true;
	["BEL"]=true;	["BHU"]=true;	["BIN"]=true;	["BLR"]=true;	["BOL"]=true;	["BRA"]=true;	["BUL"]=true;	["CAN"]=true;
	["CGX"]=true;	["CHC"]=true;	["CHI"]=true;	["CHL"]=true;	["COL"]=true;	["COS"]=true;	["CRO"]=true;	["CSX"]=true;
	["CUB"]=true;	["CXB"]=true;	["CYN"]=true;	["CYP"]=true;	["CZE"]=true;	["DDR"]=true;	["DEN"]=true;	["DFR"]=true;
	["DOM"]=true;	["ECU"]=true;	["EGY"]=true;	["ENG"]=true;	["EST"]=true;	["ETH"]=true;	["FIN"]=true;	["FRA"]=true;
	["GEO"]=true;	["GER"]=true;
}
CountryListB = {
	["GRE"]=true;	["GUA"]=true;	["GUY"]=true;	["HAI"]=true;	["HOL"]=true;	["HON"]=true;	["HUN"]=true;	["ICL"]=true;
	["IDC"]=true;	["IND"]=true;	["INO"]=true;	["IRE"]=true;	["IRQ"]=true;	["ISR"]=true;	["ITA"]=true;	["JAP"]=true;
	["JOR"]=true;	["KOR"]=true;	["KWT"]=true;	["LAT"]=true;	["LEB"]=true;	["LIB"]=true;	["LIT"]=true;	["LUX"]=true;
	["MAD"]=true;	["MAN"]=true;	["MEN"]=true;	["MEX"]=true;	["MON"]=true;	["MTA"]=true;	["MTN"]=true;	["NEP"]=true;
	["NIC"]=true;	["NJG"]=true;	["NOR"]=true;	["NZL"]=true;	["OMG"]=true;	["OMN"]=true;	["PAK"]=true;	["PAL"]=true;
	["PAN"]=true;	["PAP"]=true;
}
CountryListC = {
	["PAR"]=true;	["PER"]=true;	["PHI"]=true;	["POL"]=true;	["POR"]=true;	["PRK"]=true;	["PRU"]=true;	["REB"]=true;
	["RKK"]=true;	["RKM"]=true;	["RKO"]=true;	["RKU"]=true;	["ROM"]=true;	["RSI"]=true;	["RUR"]=true;	["SAF"]=true;
	["SAL"]=true;	["SAU"]=true;	["SCH"]=true;	["SER"]=true;	["SIA"]=true;	["SIK"]=true;	["SLO"]=true;	["SLV"]=true;
	["SOM"]=true;	["SOV"]=true;	["SPA"]=true;	["SPR"]=true;	["SUD"]=true;	["SUR"]=true;	["SWE"]=true;	["SYR"]=true;
	["TAN"]=true;	["TIB"]=true;	["TIM"]=true;	["TUR"]=true;	["UKR"]=true;	["URU"]=true;	["USA"]=true;	["VEN"]=true;
	["VIC"]=true;	["YEM"]=true;	["YUG"]=true;
}

G_CountryListAll = {
	"AFG";	"ALB";	"ARG";	"ARM";	"AST";	"AUS";	"AZB";	"BBU"; -- 1 - 8
	"BEL";	"BHU";	"BIN";	"BLR";	"BOL";	"BRA";	"BUL";	"CAN"; -- 9 - 16
	"CGX";	"CHC";	"CHI";	"CHL";	"COL";	"COS";	"CRO";	"CSX"; -- 17 - 24
	"CUB";	"CXB";	"CYN";	"CYP";	"CZE";	"DDR";	"DEN";	"DFR"; -- 25 - 32
	"DOM";	"ECU";	"EGY";	"ENG";	"EST";	"ETH";	"FIN";	"FRA"; -- 33 - 40
	"GEO";	"GER";	"GRE";	"GUA";	"GUY";	"HAI";	"HOL";	"HON"; -- 41 - 48
	"HUN";	"ICL";	"IDC";	"IND";	"INO";	"IRE";	"IRQ";	"ISR"; -- 49 - 56
	"ITA";	"JAP";	"JOR";	"KOR";	"KWT";	"LAT";	"LEB";	"LIB"; -- 57 - 64
	"LIT";	"LUX";	"MAD";	"MAN";	"MEN";	"MEX";	"MON";	"MTA"; -- 65 - 72
	"MTN";	"NEP";	"NIC";	"NJG";	"NOR";	"NZL";	"OMG";	"OMN"; -- 73 - 80
	"PAK";	"PAL";	"PAN";	"PAP";	"PAR";	"PER";	"PHI";	"POL"; -- 81 - 88
	"POR";	"PRK";	"PRU";	"REB";	"RKK";	"RKM";	"RKO";	"RKU"; -- 89 - 96
	"ROM";	"RSI";	"RUR";	"SAF";	"SAL";	"SAU";	"SCH";	"SER"; -- 97 - 104
	"SIA";	"SIK";	"SLO";	"SLV";	"SOM";	"SOV";	"SPA";	"SPR"; -- 105 - 112
	"SUD";	"SUR";	"SWE";	"SYR";	"TAN";	"TIB";	"TIM";	"TUR"; -- 113 - 120
	"UKR";	"URU";	"USA";	"VEN";	"VIC";	"YEM";	"YUG";	-- 121 - 127
}

G_StratResourceListGlobal = {
	"chromite";		-- 1
	"aluminium";	-- 2
	"rubber";		-- 3
	"tungsten";		-- 4
	"nickel";		-- 5
	"copper";		-- 6
	"zinc";			-- 7
	"manganese";	-- 8
	"molybdenum"	-- 9
}


CustomTradeAiDefaults = {
	TradeLimits = {
		MONEY = {
			Buffer = 1,
			BufferSaleCap = 20
		},
		METAL = {
			Buffer = 2.5, 			-- Amount extra to keep abouve our needs
			BufferSaleCap = 20000, 	-- Amount we need in reserve before we sell the resource
			BufferBuyCap = 15000, 	-- Amount we need before we stop actively buying (existing trades are NOT cancelled)
			BufferCancelCap = 15000, -- Amount we need before we cancel trades simply because we have to much
		},
		ENERGY = {
			Buffer = 5,
			BufferSaleCap = 40000,
			BufferBuyCap = 30000,
			BufferCancelCap = 30000,
		},
		RARE_MATERIALS = {
			Buffer = 1,
			BufferSaleCap = 10000,
			BufferBuyCap = 7500,
			BufferCancelCap = 7500,
		},
		CRUDE_OIL = {
			Buffer = 0.25,
			BufferSaleCap = 20000,
			BufferBuyCap = 15000,
			BufferCancelCap = 15000,
		},
		SUPPLIES = {
			Buffer = 1000,
			BufferSaleCap = 5000, -- Ignored for supplies
			BufferBuyCap = 1, -- never buy supplies
			BufferCancelCap = 1,
		},
		FUEL = {
			Buffer = 1,
			BufferSaleCap = 30000,
			BufferBuyCap = 20000,
			BufferCancelCap = 20000,
		}
	}
}
