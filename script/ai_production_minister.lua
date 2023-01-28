
-- ######################
-- Global Variables
--    CAREFUL: Variables are remembered from country to country
-- ######################
local ProductionData = {} -- Gets reset each time the tick starts
-- When adding new ones the main arrays in the Production object need to be updated

--	militia_brigade = { 					#### Brigade now as specified in the units folder
--		Index = 3, 							#### Location of where the item is stored in the UnitNeeds, Counts etc.... arrays
--		Serial = 4, 						#### How long should the serial run be (default 1)
--		Size = 3, 							#### How many of this brigade type should be used when building the division (default 1)
--		Support = 1, 						#### How many support brigades to attach to the unit (default 0)
--		SupportVariation = 0				#### Variation of number of Support, positive or negative (default 0)
-- 		SecondaryMain = "motorized_brigade" #### Add one unit of this type to the division always
--		SupportGroup = "Infantry", 			#### What support group to use Look at SupportType for groups
--		Type = "Land", 						#### What is the main type of the unit (Land, Naval, Air)
--		SubType = "Militia", 				#### What is the Subtype of the unitProductionMinister_Tick
--		SupportType = {						#### The SupportGroup that the support unit can be used with
--			"Garrison",
--			"Militia",
--			"Marine",
--			"Infantry",
--			"Motor",
--			"Armor"},
--		SubUnit = "cag",					#### Secondary unit that needs to be built for this primary unit
--		SubQuantity = 1},                   #### Quantity of the secondary unit that needs to be built for this primary unit

local UnitTypes = {
	-- Land Units
	hq_brigade = {
		Index = 1,
		Type = "Land",
		SubType = "Headquarters"},
	mot_hq_brigade = {
		Index = 2,
		Type = "Land",
		SubType = "Headquarters"},
	mech_hq_brigade = {
		Index = 3,
		Type = "Land",
		SubType = "Headquarters"},
	armor_hq_brigade = {
		Index = 4,
		Type = "Land",
		SubType = "Headquarters"},
	shock_hq_brigade = {
		Index = 5,
		Type = "Land",
		SubType = "Headquarters"},
	para_hq_brigade = {
		Index = 6,
		Type = "Land",
		SubType = "Headquarters"},
	garrison_brigade = {
		Index = 7,
		Serial = 1,
		Size = 1,
		--SecondaryMain = "anti_air_brigade",
		Support = 3,
		SupportVariation = 2,
		SupportGroup = "Garrison",
		Type = "Land",
		SubType = "Infantry"},
	militia_brigade = {
		Index = 8,
		Serial = 1,
		Size = 1,
		Support = 3,
		SupportGroup = "Militia",
		SupportVariation = 2,
		Type = "Land",
		SubType = "Infantry"},
	infantry_brigade = {
		Index = 9,
		Serial = 1,
		Size = 1,
		Support = 2,
		SupportVariation = 1,
		SecondaryMain = "artillery_brigade",
		TertiaryMain = "division_hq_standard",
		TransportMain = "horse_transport",
		SupportGroup = "Infantry1",
		Type = "Land",
		SubType = "Infantry"},
	cavalry_brigade = {
		Index = 10,
		Serial = 1,
		Size = 1,
		Support = 1,
		SupportVariation = 1,
		SecondaryMain = "division_hq_standard",
		TransportMain = "horse_transport",
		SupportGroup = "Cav",
		Type = "Land",
		SubType = "Infantry"},
	bergsjaeger_brigade = {
		Index = 11,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Mountain",
		TertiaryMain = "division_hq_standard",
		TransportMain = "horse_transport",
		Type = "Land",
		SubType = "Special Forces"},
	marine_brigade = {
		Index = 12,
		Serial = 1,
		Size = 1,
		Support = 4,
		TertiaryMain = "division_hq_standard",
		TransportMain = "light_transport",
		SupportGroup = "Marine",
		Type = "Land",
		SubType = "Special Forces"},
	paratrooper_brigade = {
		Index = 13,
		Serial = 1,
		Size = 2,
		CanPara = true,
		Support = 4,
		SupportGroup = "Airborne",
		TertiaryMain = "division_hq_standard",
		Type = "Land",
		SubType = "Special Forces"},
	partisan_brigade = {
		Index = 14,
		Type = "Land",
		SubType = "Partisan"},
	light_armor_brigade = {
		Index = 15,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Armor",
		TertiaryMain = "division_hq_standard",
		TransportMain = "light_transport",
		Type = "Land",
		SubType = "Armor"},
	armor_brigade = {
		Index = 16,
		Serial = 1,
		Size = 1,
		Support = 3,
		SecondaryMain = "motorized_infantry_bat",
		TertiaryMain = "division_hq_standard",
		TransportMain = "truck_transport",
		SupportGroup = "Armor",
		Type = "Land",
		SubType = "Armor"},
	heavy_armor_brigade = {
		Index = 17,
		Serial = 1,
		Size = 1,
		Support = 3,
		SecondaryMain = "semi_motorized_brigade",
		TertiaryMain = "division_hq_standard",
		TransportMain = "hftrack_transport",
		SupportGroup = "harm",
		Type = "Land",
		SubType = "Armor"},
	mechanized_brigade = {
		Index = 18,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Armor",
		TertiaryMain = "division_hq_standard",
		TransportMain = "hftrack_transport",
		Type = "Land",
		SubType = "Mech"},
	motorized_brigade = {
		Index = 19,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Motor",
		TertiaryMain = "division_hq_standard",
		TransportMain = "truck_transport",
		Type = "Land",
		SubType = "Motor"},

	-- Support Brigades
	anti_air_brigade = {
		Index = 20,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry",
			"Infantry1",
			"Mountain",
			"Marine",
			"GINF",
			"Garrison",
			"Militia"}},
	anti_tank_brigade = {
		Index = 21,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry1",
			"Infantry",
			"Mountain",
			"GINF",
			"Garrison",
			"Militia",
			"Motor",
			"arm1",
			"harm",
			"nkvd",
			"sovh",
			"sovm",
			"Armor"}},
	artillery_brigade = {
		Index = 22,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry",
			"Marine",
			"GINF",
			"Garrison",
			"Militia",
			"Motor",
			"arm1",
			"harm",
			"nkvd",
			"sovh",
			"sovm",
			"Armor"}},
	engineer_brigade = {
		Index = 23,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Mountain",
			"Infantry",
			"Infantry1",
			"Motor",
			"EMarine",
			"Marine",
			"harm",
			"sovh",
			"Cav",
			"Armor"}},
	rocket_artillery_brigade = {
		Index = 24,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry",
			"Infantry1",
			"Militia"}
		},
	police_brigade = {
		Index = 25,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Militia",
			"Garrison"
		}},
	armored_car_brigade = {
		Index = 26,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry",
			"Motor",
			"arm1",
			"Blitz",
			"grind",
			"harm1",
			"Armor",
			"Cav"}},
	sp_artillery_brigade = {
		Index = 27,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Motor",
			"harm",
			"harm1",
			"grind",
			"Armor"}},
	sp_rct_artillery_brigade = {
		Index = 28,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Motor",
			"Armor"}},
	tank_destroyer_brigade = {
		Index = 29,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Blitz",
			"Armor"}},
	-- mot_aa_brigade = {
	--	Index = 30,
	--	Type = "Land",
	--	SubType = "Support"},
	super_heavy_armor_brigade = {
		Index = 30,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {"Infantry",
		"Infantry1"}},
	-- Naval Units
	battlecruiser = {
		Index = 31,
		Type = "Naval",
		SubType = "Capital Ship"},
	battleship = {
		Index = 32,
		Type = "Naval",
		SubType = "Capital Ship"},
	super_heavy_battleship = {
		Index = 33,
		Type = "Naval",
		SubType = "Capital Ship"},
	carrier = {
		Index = 34,
		Type = "Naval",
		SubType = "Carrier",
		SubUnit = "cag",
		SubQuantity = 2},
	escort_carrier = {
		Index = 35,
		Serial = 1,
		Type = "Naval",
		SubType = "Carrier",
		SubUnit = "cag",
		SubQuantity = 0},
	cag = {
		Index = 36,
		Type = "Naval",
		SubType = "Carrier Plane"},
	destroyer_actual = {
		Index = 37,
		Serial = 1,
		Type = "Naval",
		SubType = "Escort"},
	light_cruiser = {
		Index = 38,
		Type = "Naval",
		SubType = "Cruiser"},
	heavy_cruiser = {
		Index = 39,
		Type = "Naval",
		SubType = "Cruiser"},
	submarine = {
		Index = 40,
		Serial = 1,
		Type = "Naval",
		SubType = "Submarine"},
	Aux_vessel = {
		Index = 41,
		Type = "Naval",
		SubType = "Transport"},
	-- Transport Craft (The Order matters as the last one available via tech is what the AI will build
	transport_ship = {
		Index = 42,
		Serial = 1,
		Type = "Naval",
		SubType = "Transport"},

	-- Invasion Craft (The Order matters as the last one available via tech is what the AI will build
	landing_craft = {
		Index = 43,
		Serial = 1,
		Type = "Naval",
		SubType = "Invasion"},
	assault_ship = {
		Index = 44,
		Serial = 1,
		Type = "Naval",
		SubType = "Invasion"},

	-- Air Units
	cas = {
		Index = 45,
		Serial = 1,
		Type = "Air",
		SubType = "Ground"},
	interceptor = {
		Index = 46,
		Serial = 1,
		Type = "Air",
		SubType = "Fighter"},
	multi_role = {
		Index = 47,
		Serial = 1,
		Type = "Air",
		SubType = "Fighter"},
	rocket_interceptor = {
		Index = 48,
		Serial = 1,
		Type = "Air",
		SubType = "Fighter"},
	naval_bomber = {
		Index = 49,
		Serial = 1,
		Type = "Air",
		SubType = "Naval"},
	strategic_bomber = {
		Index = 50,
		Serial = 1,
		Type = "Air",
		SubType = "Strategic"},
	light_bomber = {
		Index = 51,
		Serial = 1,
		Type = "Air",
		SubType = "Tactical"},
	tactical_bomber = {
		Index = 52,
		Serial = 1,
		Type = "Air",
		SubType = "Tactical"},
	fascist_militia_brigade = {
		Index = 53,
		Serial = 1,
		Size = 1,
		Support = 3,
		SupportGroup = "Militia",
		SupportVariation = 2,
		Type = "Land",
		SubType = "Infantry"},
	captured_armor_brigade = {
		Index = 54,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Armor",
		Type = "Land",
		SubType = "Armor"},
	railway_artillery_brigade = {
		Index = 55,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Infantry",
		Type = "Land",
		SubType = "Armor"},
	commando_brigade = {
		Index = 56,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Airborne",
			"Mountain",
			"Marine",
			"Marine1",
			"EMarine"}},
	light_infantry_brigade = {
		Index = 57,
		Serial = 1,
		Size = 1,
		Support = 2,
		SupportVariation = 1,
		SecondaryMain = "artillery_brigade",
		TertiaryMain = "division_hq_standard",
		TransportMain = "horse_transport",
		SupportGroup = "Infantry1",
		Type = "Land",
		SubType = "Infantry"},
	semi_motorized_brigade = {
		Index = 58,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Motor",
		TertiaryMain = "division_hq_standard",
		TransportMain = "truck_transport",
		Type = "Land",
		SubType = "Motor"},
	guard_armor_brigade = {
		Index = 59,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Armor",
		TertiaryMain = "division_hq_guard_veteran",
		TransportMain = "hftrack_transport",
		Type = "Land",
		SubType = "Armor"},
	guard_cavalry_brigade = {
		Index = 60,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Motor",
		Type = "Land",
		SubType = "Infantry"},
	guard_infantry_brigade = {
		Index = 61,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Infantry",
		TertiaryMain = "division_hq_guard_veteran",
		TransportMain = "hftrack_transport",
		Type = "Land",
		SubType = "Infantry"},
	guard_motorized_brigade = {
		Index = 62,
		Serial = 1,
		Size = 1,
		Support = 3,
		SecondaryMain = "tank_destroyer_brigade",
		TertiaryMain = "division_hq_guard_veteran",
		TransportMain = "truck_transport",
		SupportGroup = "Motor",
		Type = "Land",
		SubType = "Motor"},
	guard_paratrooper_brigade = {
		Index = 63,
		Serial = 1,
		Size = 1,
		Type = "Land",
		TertiaryMain = "division_hq_guard_veteran",
		TransportMain = "light_transport",
		SubType = "Special Forces"},
	ss_bergsjaeger_brigade = {
		Index = 64,
		Serial = 1,
		Size = 1,
		Type = "Land",
		SubType = "Special Forces"},
	ss_cavalry_brigade = {
		Index = 65,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Motor",
		TransportMain = "light_transport",
		Type = "Land",
		SubType = "Infantry"},
	ss_infantry_brigade = {
		Index = 66,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "ssinf",
		TertiaryMain = "division_hq_ss_standard",
		TransportMain = "truck_transport",
		Type = "Land",
		SubType = "Armor"},
	ss_mechanized_brigade = {
		Index = 67,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "ssarm",
		TertiaryMain = "division_hq_ss_standard",
		TransportMain = "hftrack_transport",
		Type = "Land",
		SubType = "Armor"},
	ss_motorized_brigade = {
		Index = 68,
		Serial = 1,
		Size = 1,
		Support = 3,
		SecondaryMain = "ss_tank_destroyer_brigade",
		TertiaryMain = "division_hq_ss_standard",
		TransportMain = "truck_transport",
		SupportGroup = "ssmot",
		Type = "Land",
		SubType = "Motor"},
	ss_armor_brigade = {
		Index = 69,
		Serial = 1,
		Size = 1,
		Support = 3,
		SecondaryMain = "ss_mechanized_brigade",
		TertiaryMain = "division_hq_ss_standard",
		TransportMain = "hftrack_transport",
		SupportGroup = "ssarm",
		Type = "Land",
		SubType = "Armor"},
	naval_infantry_brigade = {
		Index = 70,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "EMarine",
		Type = "Land",
		SubType = "Infantry"},
	air_cavalry_brigade = {
		Index = 71,
		Serial = 1,
		Size = 1,
		Support = 3,
		SecondaryMain = "tank_destroyer_brigade",
		SupportGroup = "Motor",
		Type = "Land",
		SubType = "Motor"},
	NKVD_brigade = {
		Index = 72,
		Serial = 1,
		Size = 1,
		Support = 3,
		SecondaryMain = "heavy_armor_brigade",
		TransportMain = "truck_transport",
		SupportGroup = "nkvd",
		Type = "Land",
		SubType = "Motor"},
	ski_brigade = {
		Index = 73,
		Serial = 1,
		Size = 1,
		Support = 3,
		TertiaryMain = "division_hq_standard",
		TransportMain = "horse_transport",
		SupportVariation = 1,
		SupportGroup = "Infantry1",
		Type = "Land",
		SubType = "Special Forces"},
	assault_gun_brigade = {
		Index = 74,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry",
			"SSMotor",
			"Motor",
			"Armor"}},
	infantry_tank_brigade = {
		Index = 75,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry"}},
	heavy_anti_air_brigade = {
		Index = 76,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry",
			"Motor",
			"arm1",
			"harm1",
			"sovm",
			"nkvd",
			"Armor"}},
	medium_artillery_brigade = {
		Index = 77,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry",
			"harm",
			"nkvd",
			"sovh"}},
	pack_artillery_brigade = {
		Index = 78,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Marine",
			"Mountain"}},
	coastal_battleship = {
		Index = 79,
		Type = "Naval",
		SubType = "Capital Ship"},
	pocket_battleship = {
		Index = 80,
		Type = "Naval",
		SubType = "Capital Ship"},
	anti_air_cruiser = {
		Index = 81,
		Type = "Naval",
		SubType = "Cruiser"},

	Convoy_raider_ship = {
		Index = 82,
		Serial = 1,
		Type = "Naval",
		SubType = "Escort"},
	torpedo_boat = {
		Index = 83,
		Serial = 1,
		Type = "Naval",
		SubType = "Escort"},
	frigate = {
		Index = 84,
		Serial = 1,
		Type = "Naval",
		SubType = "Escort"},
	kamikaze_brigade = {
		Index = 85,
		Type = "Air",
		SubType = "Naval"},
	air_commando_brigade = {
		Index = 86,
		Type = "air",
		SubType = "Tactical"},
	twin_engine_fighters = {
		Index = 87,
		Serial = 1,
		Type = "Air",
		SubType = "Fighter"},
	Flying_boat = {
		Index = 88,
		Serial = 1,
		Type = "Air",
		SubType = "Naval"},
	elite_light_infantry_brigade = {
		Index = 89,
		Serial = 1,
		Size = 1,
		Support = 3,
		SecondaryMain = "pack_artillery_brigade",
		TertiaryMain = "division_hq_standard",
		TransportMain = "horse_transport",
		SupportGroup = "Infantry1",
		Type = "Land",
		SubType = "Infantry"},
	amph_armour_brigade = {
		Index = 90,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Airborne",
			"Marine"}},
	light_carrier = {
		Index = 91,
		Type = "Naval",
		SubType = "Carrier",
		SubUnit = "cag",
		SubQuantity = 1},
	super_carrier = {
		Index = 92,
		Type = "Naval",
		SubType = "Carrier",
		SubUnit = "cag",
		SubQuantity = 3},
	airborne_artillery_brigade = {
		Index = 93,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Airborne"}},
	armored_engineers_brigade = {
		Index = 94,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Marine1",
			"Motor",
			"grind",
			"harm1",
			"SSMotor",
			"Armor"}},
	sp_anti_air_brigade  = {
		Index = 95,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Motor",
			"Armor"}},
	Recon_cavalry_brigade  = {
		Index = 96,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry",
			"Cav"}},
	guard_sp_rct_artillery_brigade = {
		Index = 97,
		Type = "Land",
		SubType = "Support"},
	heavy_assault_gun_brigade = {
		Index = 98,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry",
			"Infantry1",
			"SSMotor"}},
	medium_tank_destroyer_brigade = {
		Index = 99,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Motor",
			"Armor"}},
	heavy_tank_destroyer_brigade = {
		Index = 100,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Infantry"}},
	motorcycle_recon_brigade = {
		Index = 101,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Motor",
			"Airborne",
			"Mountain",
			"Armor",
			"Cav"}},
	HQDEF_brigade = {
		Index = 102,
		Type = "Land",
		SubType = "Support"},

	leader_brigade = {
		Index = 103,
		Type = "Land",
		SubType = "Headquarters"},

	guard_heavy_armor_brigade = {
		Index = 104,
		Type = "Land",
		SubType = "Support Motor"},

	ss_tank_destroyer_brigade = {
		Index = 105,
		Type = "Land",
		SubType = "SSMotor"},

	midget_submarine = {
		Index = 106,
		Type = "Naval",
		SubType = "Submarine"},

	guard_mechanized_brigade = {
		Index = 107,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Armor",
		Type = "Land",
		SubType = "Armor"},

	jet_bomber = {
		Index = 108,
		Serial = 1,
		Type = "Air",
		SubType = "Fighter"},

	rocket_interceptor_van = {
		Index = 109,
		Serial = 1,
		Type = "Air",
		SubType = "Fighter"},

	gliders = {
		Index = 110,
		Serial = 1,
		Type = "Air",
		SubType = "Transport Plane"},

	airlanding_infantry_brigade = {
		Index = 111,
		Serial = 1,
		Size = 2,
		SupportGroup = "Infantry",
		Type = "Land",
		SubType = "Infantry",
		SupportType = Utils.Set {
			"Airborne"}},

	transport_plane = {
		Index = 112,
		Serial = 1,
		Type = "Air",
		SubType = "Transport Plane"},
	quad_engine_transport = {
		Index = 113,
		Serial = 1,
		Type = "Air",
		SubType = "Transport Plane"},
	-- Secret Weapon
	flying_bomb = {
		Index = 114,
		Serial = 1,
		Type = "Secret",
		SubType = "Bomb"},

	flying_rocket = {
		Index = 115,
		Serial = 1,
		Type = "Secret",
		SubType = "Rocket"},

	armor_bat = {
		Index = 116,
		Type = "Land",
		SubType = "Support Motor"},

	infantry_bat = {
		Index = 117,
		Serial = 1,
		Size = 1,
		Support = 1,
		SupportVariation = 1,
		TertiaryMain = "division_hq_standard",
		TransportMain = "horse_transport",
		SupportGroup = "Infantry1",
		Type = "Land",
		SubType = "Infantry"},

	motorized_infantry_bat = {
		Index = 118,
		Type = "Land",
		SubType = "Support Motor"},


	mechanized_infantry_bat = {
		Index = 119,
		Type = "Land",
		SubType = "Support Motor",
		SupportType = Utils.Set {
			"grind"}},

	light_armor_bat = {
		Index = 120,
		Type = "Land",
		SubType = "Support Motor"},

	mixed_support_brigade = {
		Index = 121,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Airborne",
			"Militia",
			"Garrison",
			"Mountain",
			"Marine",
			"Infantry1"}},

	motorized_support_brigade = {
		Index = 122,
		Type = "Land",
		SubType = "Support"},


	nuclear_submarine = {
		Index = 123,
		Type = "Naval",
		SubType = "Submarine"},


	ss_sp_artillery_brigade = {
		Index = 124,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"ssarm"}},

	ss_heavy_armor_brigade = {
		Index = 125,
		Type = "Land",
		SubType = "Support"},

	ss_artillery_brigade = {
		Index = 126,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"ssinf"}},

	ss_anti_air_brigade = {
		Index = 127,
		Type = "Land",
		SupportType = Utils.Set {
			"ssinf"}},

	ss_anti_tank_brigade = {
		Index = 128,
		Type = "Land",
		SubType = "Support"},

	ss_armored_car_brigade = {
		Index = 129,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"ssarm"}},

	ss_armored_support_brigade = {
		Index = 130,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"ssinf"}},

	ss_armored_engineers_brigade = {
		Index = 131,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"ssarm",
			"ssmot"}},

	ss_engineer_brigade = {
		Index = 132,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"ssinf"}},

	ss_armor_bat = {
		Index = 133,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"ssmot"}},

	ss_motorcycle_recon_brigade = {
		Index = 134,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"ssmot"}},

	ss_motorized_support_brigade = {
		Index = 135,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"ssarm"}},


	ss_sp_anti_air_brigade = {
		Index = 136,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"ssarm"}},

	destroyer = {
		Index = 137,
		Serial = 1,
		Type = "Naval",
		SubType = "Escort"},

	seaplane_tender = {
		Index = 138,
		Serial = 1,
		Type = "Naval",
		SubType = "Escort"},

	heavy_artillery_brigade = {
		Index = 139,
		Type = "Land"
		--SubType = "Support",
	},
	motorized_engineer_brigade = {
		Index = 140,
		Type = "Land",
		SubType = "Support",
		SupportType = Utils.Set {
			"Motor",
			"EMarine",
			"harm",
			"sovh",
			"Cav",
			"Armor"}},
	Communist_militia_brigade = {
		Index = 141,
		Serial = 1,
		Size = 1,
		Support = 3,
		SupportGroup = "Militia",
		SupportVariation = 2,
		Type = "Land",
		SubType = "Infantry"},
	command_carrier = {
		Index = 142,
		Type = "Naval",
		SubType = "Carrier",
		SubUnit = "cag",
		SubQuantity = 0},
	command_battleship = {
		Index = 143,
		Type = "Naval",
		SubType = "Capital Ship"},
	long_range_submarine = {
		Index = 144,
		Serial = 1,
		Type = "Naval",
		SubType = "Submarine"},

	-- Colonials
	colonial_light_infantry_brigade = {
		Index = 145,
		Serial = 1,
		Size = 1,
		TertiaryMain = "division_hq_standard",
		TransportMain = "horse_transport",
		Support = 3,
		SupportGroup = "Militia",
		SupportVariation = 1,
		Type = "Land",
		SubType = "Infantry"},
	colonial_infantry_brigade = {
		Index = 146,
		Serial = 1,
		Size = 1,
		TertiaryMain = "division_hq_standard",
		TransportMain = "horse_transport",
		Support = 3,
		SupportGroup = "Militia",
		SupportVariation = 1,
		Type = "Land",
		SubType = "Infantry"},
	colonial_militia_brigade = {
		Index = 147,
		Serial = 1,
		Size = 1,
		Support = 1,
		SupportGroup = "Infantry",
		SupportVariation = 1,
		Type = "Land",
		SubType = "Infantry"},
	colonial_garrison_brigade = {
		Index = 148,
		Serial = 1,
		Size = 1,
		Support = 3,
		SupportVariation = 2,
		SupportGroup = "Garrison",
		Type = "Land",
		SubType = "Infantry"},
	colonial_cavalry_brigade = {
		Index = 149,
		Serial = 1,
		Size = 1,
		Support = 1,
		SupportVariation = 1,
		SupportGroup = "Cav",
		Type = "Land",
		SubType = "Infantry"},
	colonial_bergsjaeger_brigade = {
		Index = 150,
		Serial = 1,
		Size = 1,
		Support = 4,
		SupportGroup = "Mountain",
		TertiaryMain = "division_hq_standard",
		TransportMain = "horse_transport",
		Type = "Land",
		SubType = "Special Forces"},
	garrison_detachment = {
		Index = 151,
		Serial = 1,
		Size = 1,
		Support = 1,
		SupportVariation = 0,
		SupportGroup = "Garrison",
		Type = "Land",
		SubType = "Infantry"}
}

function CustomBalanceProductionSlidersAi(ministerCountry, variables, dissent)
	-- Utils.LUA_DEBUGOUT(" --- Executing CustomBalanceProductionSlidersAi --- ")
	local totalIc = ministerCountry:GetTotalIC()
	local supplies = ministerCountry:GetPool():Get( CGoodsPool._SUPPLIES_ ):Get()

	if totalIc <= 0 then
		return
	end

	-- Needed ICs
	local needsIc = {
		upgrade = ministerCountry:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_UPGRADE_):GetNeeded():Get(),
		reinforce = ministerCountry:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_REINFORCEMENT_):GetNeeded():Get(),
		supply = ministerCountry:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_SUPPLY_):GetNeeded():Get(),
		production = ministerCountry:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_PRODUCTION_):GetNeeded():Get(),
		consumer = ministerCountry:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_CONSUMER_):GetNeeded():Get(),
		lendLease = ministerCountry:GetProductionDistributionAt(CDistributionSetting._PRODUCTION_LENDLEASE_):GetNeeded():Get()
	}

	-- Needed ICs as Percentage
	local needsPercent = {
		upgrade = needsIc.upgrade/totalIc,
		reinforce = needsIc.reinforce/totalIc,
		supply = needsIc.supply/totalIc,
		production = needsIc.production/totalIc,
		consumer = needsIc.consumer/totalIc,
		lendLease = needsIc.lendLease/totalIc
	}

	local amounts = {
		upgrade = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_upgradeAmount")):Get(),
		reinforce = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_reinforceAmount")):Get(),
		supply = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_supplyAmount")):Get(),
		production = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_productionAmount")):Get(),
		consumer = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_consumerAmount")):Get(),
		lendLease = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_lendLeaseAmount")):Get()
	}

	-- Modes: 1 = Use percentages, 2 = Use flat IC
	local amountModes = {
		upgrade = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_upgradeInvestMode")):Get(),
		reinforce = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_reinforceInvestMode")):Get(),
		supply = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_supplyInvestMode")):Get(),
		production = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_productionInvestMode")):Get(),
		consumer = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_consumerInvestMode")):Get(),
		lendLease = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_lendLeaseInvestMode")):Get()
	}

	local priorities = {
		upgrade = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_upgradePrio")):Get(),
		reinforce = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_reinforcePrio")):Get(),
		supply = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_supplyPrio")):Get(),
		production = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_productionPrio")):Get(),
		consumer = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_consumerPrio")):Get(),
		lendLease = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_lendLeasePrio")):Get()
	}

	-- Utils.LUA_DEBUGOUT("needsIc: ")
	-- Utils.INSPECT_TABLE(needsIc)
	-- Utils.LUA_DEBUGOUT("needsPercent: ")
	-- Utils.INSPECT_TABLE(needsPercent)

	-- reduce dissent
	if dissent > 0.01 and variables:GetVariable(CString("zzDsafe_CustomProductionSliders_reduceDissent")):Get() == 1 then
		needsPercent.consumer = math.max(0.075, needsPercent.consumer * 1.5) -- math.max incase CG demand is 0% but there is dissent
	end

	-- enforce upgrade IC limit
	if variables:GetVariable(CString("zzDsafe_CustomProductionSliders_upgradeLimit_active")):Get() == 1 then
		local upgradeLimit = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_upgradeLimit")):Get()
		if needsIc.upgrade > upgradeLimit then
			needsPercent.upgrade = upgradeLimit/totalIc
		end
	end

	-- enforce reinforce IC limit
	if variables:GetVariable(CString("zzDsafe_CustomProductionSliders_reinforceLimit_active")):Get() == 1 then
		local reinforceLimit = variables:GetVariable(CString("zzDsafe_CustomProductionSliders_reinforceLimit")):Get()
		if needsIc.reinforce > reinforceLimit then
			needsPercent.reinforce = reinforceLimit/totalIc
		end
	end

	-- increase supply production if goal is not met
	if variables:GetVariable(CString("zzDsafe_CustomProductionSliders_supplyGoal_active")):Get() == 1 then
		if supplies < variables:GetVariable(CString("zzDsafe_CustomProductionSliders_supplyGoal")):Get() then
			if totalIc > 100 then
				-- at least 10 more IC for more powerful countries
				needsPercent.supply = math.max((needsIc.supply + 10)/totalIc, needsPercent.supply * 1.2)
			else
				needsPercent.supply = math.max((needsIc.supply + 3)/totalIc, needsPercent.supply * 1.2)
			end
		end
	end

	local prioritiesSorted = {}
	for k, v in pairs(priorities) do
		prioritiesSorted[v] = k
	end

	-- Utils.INSPECT_TABLE(priorities)
	-- Utils.INSPECT_TABLE(prioritiesSorted)

	local freePercentage = 1
	local final = {}
	for priority, category in ipairs(prioritiesSorted) do
		if amountModes[category] == 0 then -- Percentages
			final[category] = math.min(freePercentage, needsPercent[category] * (amounts[category] / 100))
			freePercentage = freePercentage - final[category]
		elseif amountModes[category] == 1 then -- Flat ICs
			local asPercent = amounts[category]/totalIc
			final[category] = math.min(freePercentage, asPercent)
			freePercentage = freePercentage - final[category]
		end
	end

	-- Utils.LUA_DEBUGOUT("final: ")
	-- Utils.INSPECT_TABLE(final)
	-- Utils.LUA_DEBUGOUT(freePercentage)

	if freePercentage > 0.01 then
		final.production = final.production + freePercentage
	end

	-- Utils.LUA_DEBUGOUT("final: ")
	-- Utils.INSPECT_TABLE(final)

	return final.lendLease, final.consumer, final.production, final.supply, final.reinforce, final.upgrade
end



-- ###################################
-- # Main Method called by the EXE
-- #####################################
function BalanceProductionSliders(ai, ministerCountry, prioSelection,
                                  vLendLease, vConsumer, vProduction, vSupply, vReinforce, vUpgrade, bHasReinforceBonus)
	local liOrigPrio = prioSelection
	local lbIsMajor = ministerCountry:IsMajor()
	local ministerCountryTag = ministerCountry:GetCountryTag()

	local vLendLeaseOriginal = vLendLease
	local vConsumerOriginal = vConsumer
	local vProductionOriginal = vProduction
	local vSupplyOriginal = vSupply
	local vReinforceOriginal = vReinforce
	local vUpgradeOriginal = vUpgrade
	local lbAtWar = ministerCountry:IsAtWar()
	local dissent = ministerCountry:GetDissent():Get()

	-- CustomBalanceProductionSlidersAi
	local factor_left = 0
	local variables = ministerCountry:GetVariables()
	if variables:GetVariable(CString("zzDsafe_CustomProductionSliders_isActive")):Get() == 1 and prioSelection == 2 then
		-- Utils.LUA_DEBUGOUT("CustomBalanceProductionSlidersAi")
		-- local t = os.clock()
		vLendLease, vConsumer, vProduction, vSupply, vReinforce, vUpgrade = CustomBalanceProductionSlidersAi(ministerCountry, variables, dissent)
		local command = CChangeInvestmentCommand(ministerCountryTag, vLendLease, vConsumer, vProduction, vSupply, vReinforce, vUpgrade)
		ai:Post( command )
		-- Utils.LUA_DEBUGOUT("CustomBalanceProductionSlidersAi: " .. os.clock() - t)
		return
	end

	-- If country just started mobilizing (or gets bonus reinforcements for some other reason), boost reinforcements
	if ( prioSelection == 0 or prioSelection == 3 )then
		--local reinforcement_multiplier = ministerCountry:CalculateReinforcementMultiplier():Get()
		--if reinforcement_multiplier > 1.0 then
		if bHasReinforceBonus then
			prioSelection = 3
		end
		if prioSelection == 4 then
			prioSelection = 3
		end
	end


	-- If Dissent is present add 10% to the Production of Consumer Goods
	if dissent > 0.01 then -- fight dissent
		vConsumer = vConsumer + 0.8
	end

	local ic = ministerCountry:GetTotalIC()
	-- Performance check make sure its above 0 before we even look at this
	if vSupply > 0 then
		local supplyStockpile = ministerCountry:GetPool():Get( CGoodsPool._SUPPLIES_ ):Get()
		--local weeksSupplyUse = ministerCountry:GetDailyExpense( CGoodsPool._SUPPLIES_ ):Get() * 7

		-- IC based supply production
		-- https://www.desmos.com/calculator/qiq9xi33wo
		local targetSupply = 90 * ic + 7500
		if targetSupply > 99999 then
			targetSupply = 99999
		end

		-- Ration between stockpile and target
		local percent = targetSupply / supplyStockpile

		-- Quadratic percent
		percent = percent * percent

		-- Maximum 200% of Needed
		if percent > 2 then
			percent = 2
		end

		-- Puppets dont need as much supplies
		if ministerCountry:IsPuppet() then
			if percent >= 2 then
				percent = 1.3
			end
		end

		-- Different logic for the player
		-- limit the IC wasted into producing excess
		if CCurrentGameState.IsPlayer( ministerCountry:GetCountryTag()) then
			if supplyStockpile >= 50000 then
				percent = 1
			end
			if supplyStockpile >= 75000 then
				percent = 0.5
			end
			if supplyStockpile >= 90000 then
				percent = 0.1
			end
		end

		-- Apply percentage of Needed
		vSupply = vSupply * percent

		--[[
		if ministerCountry:GetCountryTag() == CCountryDataBase.GetTag("SOV") then
			Utils.LUA_DEBUGOUT(ic)
			Utils.LUA_DEBUGOUT(supplyStockpile)
			Utils.LUA_DEBUGOUT(targetSupply)
			Utils.LUA_DEBUGOUT(percent)
			Utils.LUA_DEBUGOUT(vSupply)
		end
		]]

	end

	-- Lend-Lease priority
	if (liOrigPrio == 0) then -- if not using full auto we let player set this slider completely
		if ministerCountry:HasActiveLendLeaseToAnyone() then
			local liMaxGivenLL = 0.3
			if lbAtWar then
				--Default
				liMaxGivenLL = 0.1
			end
			-- Puppets will give X% of the maximum amount possible (90% of effective ic at 0 neutrality, higher neutrality lowers it)
			if tostring(ministerCountry:GetOverlord():GetCountry():GetCountryTag()) ~= "---" then
				liMaxGivenLL = 1*GetLendLeaseMultiplier()
				-- Utils.LUA_DEBUGOUT("liMaxGivenLL: " .. tostring(liMaxGivenLL))
			end

			-- Call country specific Max Lend Lease
			if Utils.HasCountryAIFunction(ministerCountryTag , "MaxLendLease") then
				liMaxGivenLL = Utils.CallCountryAI(ministerCountryTag , "MaxLendLease", lbAtWar)
			end

			-- The maximum amount of LL (as a fraction) you can give, since it is limited by exe * the desired fraction
			-- So of 100 IC game lets you give 90 max and you multiply that with your desired value
			local liPreferredLL = ministerCountry:GetMaxLendLeaseFraction():Get() * liMaxGivenLL
			if vLendLease == 0 then
				vLendLease = liPreferredLL
			end
			if vLendLease < liPreferredLL * 0.95 then
				vLendLease = vLendLease * 1.05
			elseif vLendLease > liPreferredLL then
				vLendLease = vLendLease * 0.95
			end
		else
			vLendLease = 0
		end
	end

	-- observe this uses the original prio orders from PRIO_SETTING, so if you mod that you cant use this function
	-- and have to roll the commented out code above
	vLendLease, vConsumer, vProduction, vSupply, vReinforce, vUpgrade, factor_left = CAI.FastNormalizeByPriority( prioSelection, vLendLease, vConsumer, vProduction, vSupply, vReinforce, vUpgrade )
	--factor_left = math.max(factor_left, 0.0)
	if liOrigPrio == 0 then

		local liProdUpgradeTotalPercentage = vUpgrade + vProduction + factor_left

		-- If the total needed for Upgrading exceedes the total amount available between
		--   Production and Upgrades then divide the number in half so something gets produced.
		if (vUpgradeOriginal > liProdUpgradeTotalPercentage or
			vUpgradeOriginal > (liProdUpgradeTotalPercentage / 2))
		then
			vUpgrade = (liProdUpgradeTotalPercentage / 2)
			vProduction = (liProdUpgradeTotalPercentage / 2)

		-- Upgrades is covered put everything extra into Production
		elseif
			vUpgrade > (liProdUpgradeTotalPercentage / 2) then
			vUpgrade = (liProdUpgradeTotalPercentage / 3)
		else
			vUpgrade = vUpgradeOriginal
			vProduction = liProdUpgradeTotalPercentage - vUpgradeOriginal
		end
	else
		-- We have some dessent so put extra IC to lower it
		if dissent > 0.01 then
			vConsumer = vConsumer + factor_left
		else
			vProduction = vProduction + factor_left
		end
	end

	local checksum = math.abs(vLendLease - vLendLeaseOriginal) +
	                 math.abs(vConsumer - vConsumerOriginal) +
	                 math.abs(vProduction - vProductionOriginal) +
					 math.abs(vSupply - vSupplyOriginal) +
					 math.abs(vReinforce - vReinforceOriginal) +
					 math.abs(vUpgrade - vUpgradeOriginal)
	if checksum > 0.01 then
		local command = CChangeInvestmentCommand( ministerCountry:GetCountryTag(), vLendLease, vConsumer, vProduction, vSupply, vReinforce, vUpgrade )
		ai:Post( command )
	end
end


-- ###################################
-- # Main Method called by the EXE
-- #####################################
function BalanceLendLeaseSliders(ai, ministerCountry, cCountryTags, values)
	--[[
	-- this implementation is wrong wrong wrong
	-- the values do not get normalized to anything
	-- instead they are interpreted as a flat IC value
	local countryFunRef = Utils.HasCountryAIFunction(ministerCountry:GetCountryTag(), "BalanceLendLeaseSliders")
	if countryFunRef then -- override
		countryFunRef(ai, ministerCountry, countryTags, values)
	else
		for i=0, countryTags:GetSize()-1 do
    		local ToTag = countryTags:GetAt(i)
    		values:SetAt( i, CFixedPoint( ToTag:GetCountry():GetMaxIC() ) ) -- it gets normalized anyway / WRONG, NOT TRUE, SEE ABOVE
  		end
		-- Do this to confirm LL sliders distribution
		local command = CChangeLendLeaseDistributionCommand( ministerCountry:GetCountryTag() )
		command:SetData( countryTags, values )
		ai:Post( command )
	end
	]]

	local totalCountries = cCountryTags:GetSize()
	local totalLendLeaseIC = ministerCountry:GetICPart(CDistributionSetting._PRODUCTION_LENDLEASE_):Get()
	local luaCountryTags = {}
	-- get country specific weights
	local countryWeights = Utils.CallLendLeaseWeights(ministerCountry:GetCountryTag(), "LendLeaseWeights")

	-- Utils.LUA_DEBUGOUT("totalCountries: " .. totalCountries)
	-- Utils.LUA_DEBUGOUT("totalLendLeaseIC: " .. totalLendLeaseIC)

	-- save countries and weights to a temporary table
	-- Utils.LUA_DEBUGOUT("save countries and weights to a temporary table")
	for i=0, totalCountries-1 do
		local toTag = cCountryTags:GetAt(i)
		local toTagString = tostring(toTag)
		-- Utils.LUA_DEBUGOUT(toTagString)
		if countryWeights[toTagString] == nil or countryWeights[toTagString] <= 0 then
			countryWeights[toTagString] = 10
		end
		luaCountryTags[toTagString] = math.max(10, countryWeights[toTagString])
	end
	-- Utils.INSPECT_TABLE(luaCountryTags)
	local weightSum = table.sum(luaCountryTags) -- get the total value of all weights
	-- then normalize the total IC to those weights
	for k, v in pairs(luaCountryTags) do
		luaCountryTags[k] = v * (totalLendLeaseIC / weightSum)
	end
	-- Utils.INSPECT_TABLE(luaCountryTags)
	-- Utils.LUA_DEBUGOUT("fill c table")
	for i=0, totalCountries-1 do
		local toTag = cCountryTags:GetAt(i)
		local toTagString = tostring(toTag)
		-- Utils.LUA_DEBUGOUT(toTagString)
		-- Utils.LUA_DEBUGOUT("LL old: " .. values:GetAt(i):Get())
		-- Utils.LUA_DEBUGOUT("LL new: " .. luaCountryTags[toTagString])
		values:SetAt( i, CFixedPoint( luaCountryTags[toTagString] ) )
		end
	local command = CChangeLendLeaseDistributionCommand( ministerCountry:GetCountryTag() )
	command:SetData( cCountryTags, values )
	ai:Post( command )
end


-- ##################################
-- # Called by the EXE
-- ##################################
-- # Happens around 05:00 each day
-- ##################################
function ProductionMinister_Tick(minister)
	local isOMG = false
	if tostring(minister:GetCountryTag()) == "OMG" then
		isOMG = true
	end

	local t = nil
	if benchmarkLUA then
		t = os.clock()
	end

	HandleProductionMinister_Tick(minister)

	if benchmarkLUA then
		Utils.addTime("Production", os.clock() - t, isOMG)
	end
end

function HandleProductionMinister_Tick(minister)
	-- Reset Global Array Container
	ProductionData = {
		minister = minister,
		ministerAI = nil,
		ministerTag = nil,
		ministerCountry = nil,
		humanTag = nil,
		Year = nil,
		CapitalPrvID = nil,
		IsAtWar = nil, -- Boolean are they atwar with someone
		IsMajor = nil, -- Boolean are they a major power
		IsNaval = nil, -- Boolean do they have the min requirements to build ships
		IsFirepower = nil, -- Boolean indicating if the have Superior Firepower tech
		IsExile	= nil, -- Boolean are the in exile
		TechStatus = nil, -- TechStatus Object
		BuildingCounts = {},
		CurrentCounts = {},
		TotalCounts = {},
		UnitNeeds = {},
		LandCountTotal = 0, -- Total amount of Land units including ones in build que
		AirCountTotal = 0, -- Total amount of Air units including ones in build que
		NavalCountTotal = 0, -- Total amount of Naval units including ones in build que
		SpecialForcesCountTotal = 0, -- Total amount of Special Forces units including ones in build que
		FlyingBombsCountTotal = 0, -- Total amount of Flying Bombs units including ones in build que
		ParaCountTotal = 0, -- Total amount of units, that can paradrop, including ones in build que
		icTotal = nil, -- Grant Total IC the country has
		icAllocated = nil, -- IC currently allocated to production
		icAvailable = nil, -- IC currently available for production
		PortsTotal = 0, -- Total amount of ports
		AirfieldsTotal = 0, -- Total amount of airfields
		ManpowerMobilize = nil, -- Boolean do they have enough MP stored to mobilize
		ManpowerTotal = 0, -- Total MP currently available to them
		ManpowerCap = 0, -- Coming Soon
		BuiltRocketSite = false,
		UnitTypes = UnitTypes}

	-- Initialize Production Object
	-- #################
	ProductionData.ministerTag = minister:GetCountryTag()
	ProductionData.ministerCountry = ProductionData.ministerTag:GetCountry()
	ProductionData.icAllocated = ProductionData.ministerCountry:GetICPart(CDistributionSetting._PRODUCTION_PRODUCTION_):Get()
	ProductionData.icAvailable = ProductionData.icAllocated - ProductionData.ministerCountry:GetUsedIC():Get()
	-- End Initialize Production Object
	-- #################

	if ProductionData.ministerCountry:GetFlags():IsFlagSet("province_request_flag") then
		-- t = os.clock()
		-- Utils.LUA_DEBUGOUT(tostring(ProductionData.ministerTag))
		BuildPlayersRequestedBuildings(minister)
		-- Utils.LUA_DEBUGOUT(os.clock() - t .. " - BuildPlayersRequestedBuildings")
	end


	-- Performance check
	--   if no IC just exit completely so no objects get created
	if ProductionData.icAvailable < 0.1 then
		return
	end

	-- Initialize Production Object
	-- #################
	for x = 1, table.getn(UnitTypes) do
		ProductionData.BuildingCounts[x] = 0
		ProductionData.CurrentCounts[x] = 0
		ProductionData.TotalCounts[x] = 0
		ProductionData.UnitNeeds[x] = 0
	end

	ProductionData.ministerAI = minister:GetOwnerAI()
	ProductionData.humanTag = CCurrentGameState.GetPlayer()
	ProductionData.Year = CCurrentGameState.GetCurrentDate():GetYear()
	ProductionData.Month = CCurrentGameState.GetCurrentDate():GetMonthOfYear()
	ProductionData.CapitalPrvID = ProductionData.ministerCountry:GetActingCapitalLocation():GetProvinceID()
	ProductionData.icTotal = ProductionData.ministerCountry:GetTotalIC()
	ProductionData.IsMajor = ProductionData.ministerCountry:IsMajor()
	ProductionData.IsExile = ProductionData.ministerCountry:IsGovernmentInExile()
	ProductionData.TechStatus = ProductionData.ministerCountry:GetTechnologyStatus()
	ProductionData.IsFirepower = (ProductionData.TechStatus:GetLevel(CTechnologyDataBase.GetTechnology("superior_firepower")) ~= 0)
	ProductionData.ManpowerMobilize = ProductionData.ministerCountry:HasExtraManpowerLeft()
	ProductionData.PortsTotal = ProductionData.ministerCountry:GetNumOfPorts()
	ProductionData.AirfieldsTotal = ProductionData.ministerCountry:GetNumOfAirfields() * 4 --Include fake_air_bases
	ProductionData.IsAtWar = ProductionData.ministerCountry:IsAtWar()
	ProductionData.IsNaval = (ProductionData.PortsTotal > 0 and ProductionData.icTotal >= 20)
	ProductionData.ManpowerTotal = ProductionData.ministerCountry:GetManpower():Get()
	-- End Initialize Production Object
	-- #################

	-- Build Convoys first above all (they count against Other toward the end
	ProductionData.icAvailable = ConstructConvoys(ProductionData.icAvailable)

	--    IC check added for performance. If none dont bother executing.
	if ProductionData.icAvailable > 0.1 then
		--Utils.LUA_DEBUGOUT("Country: " .. tostring(ProductionData.ministerTag))

		-- Get the counts of the unit types currently being produced
		local laTempProd = ProductionData.ministerAI:GetProductionSubUnitCounts()
		local laTempCurrent = ProductionData.ministerAI:GetDeployedSubUnitCounts()
		--local laTempTReq = ProductionData.ministerAI:GetTheatreSubUnitNeedCounts()

		-- Get the build counts
		for subUnit in CSubUnitDataBase.GetSubUnitList() do
			local lsUnitType = subUnit:GetKey():GetString()

			if not(UnitTypes[lsUnitType] == nil) then
				local nIndex = subUnit:GetIndex()
				local liBuildCount = laTempProd:GetAt(nIndex)
				local liCurrentCount = laTempCurrent:GetAt(nIndex)
				ProductionData.BuildingCounts[UnitTypes[lsUnitType].Index] = liBuildCount
				ProductionData.CurrentCounts[UnitTypes[lsUnitType].Index] =  liCurrentCount
				ProductionData.TotalCounts[UnitTypes[lsUnitType].Index] = liBuildCount + liCurrentCount
			end
		end

		-- One loop to do all the counting (Performance)
		for k, v in pairs(UnitTypes) do
			if v.Type == "Land" and (v.SubType == "Infantry" or v.SubType == "Armor" or v.SubType == "Mech" or v.SubType == "Motor") then
				ProductionData.LandCountTotal = ProductionData.LandCountTotal + ProductionData.TotalCounts[v.Index]
			end
			if v.Type == "Land" and v.SubType == "Special Forces" then ProductionData.SpecialForcesCountTotal = ProductionData.SpecialForcesCountTotal + ProductionData.TotalCounts[v.Index] end
			if v.Type == "Air" then ProductionData.AirCountTotal = ProductionData.AirCountTotal + ProductionData.TotalCounts[v.Index] end
			if v.Type == "Naval" then ProductionData.NavalCountTotal = ProductionData.NavalCountTotal + ProductionData.TotalCounts[v.Index] end
			if v.Type == "Secret" then ProductionData.FlyingBombsCountTotal = ProductionData.FlyingBombsCountTotal + ProductionData.TotalCounts[v.Index] end
			if v.CanPara == true then ProductionData.ParaCountTotal = ProductionData.ParaCountTotal + ProductionData.TotalCounts[v.Index] end
		end
		-- End of Counting

		-- Verify Build Ratios against available units
		local laLandRatio = IsUnitsAvailable(GetBuildRatio("LandRatio"))

		--local usaTag = CCountryDataBase.GetTag("USA")

--if ProductionData.ministerTag == usaTag then
--	Utils.LUA_DEBUGOUT("USA UnitTypes:")
--	Utils.INSPECT_TABLE(UnitTypes)
--end

		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA laLandRatio:")
			--Utils.INSPECT_TABLE(laLandRatio)
		--end

		local laAirRatio = GetBuildRatio("AirRatio")
		--if ministerCountry:GetCountryTag() == CCountryDataBase.GetTag("USA") then
		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA laAirRatio:")
			--Utils.INSPECT_TABLE(laAirRatio)
		--end

		local laNavalRatio = GetBuildRatio("NavalRatio")
		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA laNavalRatio:")
			--Utils.INSPECT_TABLE(laNavalRatio)
		--end

		local laEliteUnits = GetEliteUnitBuildCount(GetBuildRatio("EliteUnits"))
		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA laEliteUnits:")
			--Utils.INSPECT_TABLE(laEliteUnits)
		--end

		local laSpecialForcesRatio, laSpecialRatio = GetBuildRatio("SpecialForcesRatio")
		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA laSpecialForcesRatio:")
			--Utils.INSPECT_TABLE(laSpecialForcesRatio)
		--end

		local laProdWeights = GetBuildRatio("ProductionWeights")

--		if laProdWeights == nil then
--			Utils.LUA_DEBUGOUT(tostring(ProductionData.ministerTag) .. " all null")
--		end
--		if laProdWeights[1] == nil then
--			Utils.LUA_DEBUGOUT(tostring(ProductionData.ministerTag) .. " 1 null")
--		end
--		if laProdWeights[2] == nil then
--			Utils.LUA_DEBUGOUT(tostring(ProductionData.ministerTag) .. " 2 null")
--		end
--		if laProdWeights[3] == nil then
--			Utils.LUA_DEBUGOUT(tostring(ProductionData.ministerTag) .. " 3 null")
--		end
--		if laProdWeights[4] == nil then
--			Utils.LUA_DEBUGOUT(tostring(ProductionData.ministerTag) .. " 4 null")
--		end

		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA laProdWeights:")
			--Utils.INSPECT_TABLE(laProdWeights)
		--end

		local laRocketRatio = GetBuildRatio("RocketRatio")
		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA laRocketRatio:")
			--Utils.INSPECT_TABLE(laRocketRatio)
		--end

		local laLandToAirRatio = GetBuildRatio("LandToAirRatio")
		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA laLandToAirRatio:")
			--Utils.INSPECT_TABLE(laLandToAirRatio)
		--end

		local laTransportLandRatio = GetBuildRatio("TransportLandRatio")
		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA laTransportLandRatio:")
			--Utils.INSPECT_TABLE(laTransportLandRatio)
		--end

		local laFirePower = GetBuildRatio("FirePower")
		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA laFirePower:")
			--Utils.INSPECT_TABLE(laFirePower)
		--end
		if ProductionData.ministerAI:GetCountry():IsPuppet() then
			-- Puppet Military Focus (Override production ratios)
			if ProductionData.ministerAI:GetCountry():GetVariables():GetVariable(CString("puppet_focus_variable")):Get() == 6 then
				laProdWeights[1] = 1
				laProdWeights[2] = 0
				laProdWeights[3] = 0
				laProdWeights[4] = 0
			end
			if ProductionData.ministerAI:GetCountry():GetVariables():GetVariable(CString("puppet_focus_variable")):Get() == 5 then
				laProdWeights[1] = 0
				laProdWeights[2] = 1
				laProdWeights[3] = 0
				laProdWeights[4] = 0
			end
			if ProductionData.ministerAI:GetCountry():GetVariables():GetVariable(CString("puppet_focus_variable")):Get() == 4 then
				laProdWeights[1] = 0
				laProdWeights[2] = 0
				laProdWeights[3] = 1
				laProdWeights[4] = 0
			end
		end

		laProdWeights = CheckUnitAmounts(ProductionData.ministerTag, ProductionData.IsMajor, ProductionData.LandCountTotal, ProductionData.AirCountTotal, ProductionData.NavalCountTotal, laProdWeights)

		-- If no air fields do not build any air units
		-- If more air units than air fields do not build any air units
		if (ProductionData.AirfieldsTotal <= 0 and laProdWeights[2] > 0) or (ProductionData.AirfieldsTotal < ProductionData.AirCountTotal) then
			laAirRatio = {} -- Set it to an empty array

			-- Land ratio is greater than 0 so add it to land
			if laProdWeights[1] > 0 then
				-- Now move the Air IC over to the Land section
				laProdWeights[1] = laProdWeights[1] + laProdWeights[2]

			-- Add it to Naval
			elseif ProductionData.PortsTotal > 0 and laProdWeights[3] > 0 then
				laProdWeights[3] = laProdWeights[3] + laProdWeights[2]

			-- Add it to the Other Category
			else
				laProdWeights[4] = laProdWeights[4] + laProdWeights[2]
			end

			laProdWeights[2] = 0
		end

		-- If no ports do not build any naval units
		if ProductionData.PortsTotal <= 0 and laProdWeights[3] > 0 then
			laNavalRatio = {} -- Set it to an empty array

			-- If Land Ratio greater than 0 then add it there
			if laProdWeights[1] > 0 then
				laProdWeights[4] = laProdWeights[4] + laProdWeights[3]

			-- If Air Ratio greater than 0 add it to there
			elseif ProductionData.AirfieldsTotal > 0 and ProductionData.AirfieldsTotal > ProductionData.AirCountTotal and laProdWeights[2] > 0 then
				laProdWeights[2] = laProdWeights[2] + laProdWeights[3]

			-- Add it to the Other Category
			else
				-- Now move the Naval IC over to the Land section
				laProdWeights[1] = laProdWeights[1] + laProdWeights[3]
			end

			laProdWeights[3] = 0
		end

		-- Figure out how much IC is suppose to be designated in the appropriate area
		local liPotentialLandIC = tonumber(tostring(ProductionData.icAllocated * laProdWeights[1]))
		local liPotentialAirIC = tonumber(tostring(ProductionData.icAllocated * laProdWeights[2]))
		local liPotentialNavalIC = tonumber(tostring(ProductionData.icAllocated * laProdWeights[3]))
		local liPotentialOtherIC = tonumber(tostring(ProductionData.icAllocated * laProdWeights[4]))

		local liNeededLandIC = 0
		local liNeededAirIC = 0
		local liNeededNavalIC = 0
		local liNeededOtherIC = 0

		-- Figure out what the AI is currently producing in each category
		for loBuildItem in ProductionData.ministerCountry:GetConstructions() do
			if loBuildItem:IsMilitary() then
				local loMilitary = loBuildItem:GetMilitary()

				if loMilitary:IsLand() then
					liNeededLandIC = liNeededLandIC + loBuildItem:GetCost()
				elseif loMilitary:IsAir() then
					for loConstDef in loMilitary:GetBrigades() do
						local loSubUnit = loConstDef:GetType()

						-- If it is a cag add it to naval IC count instead of air
						if loSubUnit:IsCag() then
							liNeededNavalIC = liNeededNavalIC + loBuildItem:GetCost()
						else
							liNeededAirIC = liNeededAirIC + loBuildItem:GetCost()
						end

						-- Exit the loop right away
						break
					end
				elseif loMilitary:IsNaval() then
					liNeededNavalIC = liNeededNavalIC + loBuildItem:GetCost()
				end
			else
				liNeededOtherIC = liNeededOtherIC + loBuildItem:GetCost()
			end
		end

		-- Now figure out what it needs
		liNeededLandIC = liPotentialLandIC - liNeededLandIC
		liNeededAirIC = liPotentialAirIC - liNeededAirIC
		liNeededNavalIC = liPotentialNavalIC - liNeededNavalIC
		liNeededOtherIC = liPotentialOtherIC - liNeededOtherIC

		-- Normalize the IC counts in case of shifts
		local liOverIC = 0

		-- Variables are negative numbers so add them
		if liNeededLandIC < 0 then
			liOverIC = liOverIC + liNeededLandIC
		end
		if liNeededAirIC < 0 then
			liOverIC = liOverIC + liNeededAirIC
		end
		if liNeededNavalIC < 0 then
			liOverIC = liOverIC + liNeededNavalIC
		end
		if liNeededOtherIC < 0 then
			liOverIC = liOverIC + liNeededOtherIC
		end

		if liOverIC > 0 then
			if liNeededNavalIC > 0 and liOverIC > 0 then
				if liNeededNavalIC >= liOverIC then
					liNeededNavalIC = liNeededNavalIC - liOverIC
					liOverIC = 0
				else
					liOverIC = liOverIC - liNeededNavalIC
					liNeededNavalIC = 0
				end
			end
			if liNeededAirIC > 0 and liOverIC > 0 then
				if liNeededAirIC >= liOverIC then
					liNeededAirIC = liNeededAirIC - liOverIC
					liOverIC = 0
				else
					liOverIC = liOverIC - liNeededAirIC
					liNeededAirIC = 0
				end
			end
			if liNeededLandIC > 0 and liOverIC > 0 then
				if liNeededLandIC >= liOverIC then
					liNeededLandIC = liNeededLandIC - liOverIC
					liOverIC = 0
				else
					liOverIC = liOverIC - liNeededLandIC
					liNeededLandIC = 0
				end
			end
			if liNeededOtherIC > 0 and liOverIC > 0 then
				if liNeededOtherIC >= liOverIC then
					liNeededOtherIC = liNeededOtherIC - liOverIC
					liOverIC = 0
				else
					liOverIC = liOverIC - liNeededOtherIC
					liNeededOtherIC = 0
				end
			end
		end
		-- End of IC Normalization

		-- Process Land Units
		-- Used to figure out Air to Land Ratio
		--local liTotalLandRatio = CalculateRatio(ProductionData.LandCountTotal, laLandToAirRatio[1])
		--local liTotalAirRatio = CalculateRatio(ProductionData.AirCountTotal, laLandToAirRatio[2])

		--if ProductionData.ministerTag == usaTag then
			--Utils.LUA_DEBUGOUT("USA liTotalLandRatio:" .. liTotalLandRatio)
			--Utils.LUA_DEBUGOUT("USA liTotalAirRatio:" .. liTotalAirRatio)
			--Utils.INSPECT_TABLE(laFirePower)
		--end

		-- If the Air ratio is higher than the Land ration then move all the Air IC into Land
		---   This means the country could have suffered massive losses via an encirclement
--		if liTotalAirRatio > liTotalLandRatio then
--			liNeededLandIC = liNeededLandIC + liNeededAirIC
--			liNeededAirIC = 0
--		end

		-- PERFORMANCE: only process if IC has been allocated
		local laLandUnitRatio = {} -- Regular Land Units
		local laSpecialUnitRatio = {} -- Special Forces

		-- Naval check is adding for Convoy ratio calculating.
		if liNeededLandIC > 0 or liNeededNavalIC > 0 then
			-- PERFORMANCE: Make sure you need the rest of this to run
			if liNeededLandIC > 0 then
				-- Calculate what the ratio is for each unit type
				for k, v in pairs(laLandRatio) do
					laLandUnitRatio[k] = CalculateRatio(ProductionData.TotalCounts[UnitTypes[k].Index], laLandRatio[k])
				end

--if ProductionData.ministerTag == usaTag then
--	Utils.LUA_DEBUGOUT("USA laLandUnitRatio:")
--	Utils.INSPECT_TABLE(laLandUnitRatio)
--end

				-- Multiplier used to figure out how many units of each type you need
				--   to keep the ratio
				local liMultiplier = GetMultiplier(laLandUnitRatio, laLandRatio)

				-- Now Figure out what the Unit needs are
				for k, v in pairs(laLandUnitRatio) do
					ProductionData.UnitNeeds[UnitTypes[k].Index] = (laLandRatio[k] * liMultiplier) - ProductionData.TotalCounts[UnitTypes[k].Index]
				end

--if ProductionData.ministerTag == usaTag then
--	Utils.LUA_DEBUGOUT("USA ProductionData.UnitNeeds:")
--	Utils.INSPECT_TABLE(ProductionData.UnitNeeds)
--end

				-- Setup Elite Units and add them to the Regular Land Array but with a priority of 0
				for k, v in pairs(laEliteUnits) do
					ProductionData.UnitNeeds[UnitTypes[k].Index] = laEliteUnits[k]
					laLandUnitRatio[k] = -1000
				end

				--[[ SPECIAL FORCES RATIO SYSTEM WAS UNIFIED WITH REGULAR LAND RATIO

				-- Special Forces
				-- Calculate how many Special Forces are needed
				local liTotalSFNeeded = 0

				if laSpecialRatio ~= nil and laSpecialForcesRatio[2] > 0 then
					liTotalSFNeeded = math.max(0, math.ceil((ProductionData.LandCountTotal / laSpecialForcesRatio[1]) * laSpecialForcesRatio[2]) - ProductionData.SpecialForcesCountTotal)

--if ProductionData.ministerTag == usaTag then
--	Utils.LUA_DEBUGOUT("USA ProductionData.LandCountTotal: " .. ProductionData.LandCountTotal)
--	Utils.LUA_DEBUGOUT("USA ProductionData.SpecialForcesCountTotal: " .. ProductionData.SpecialForcesCountTotal)
--end


					-- Do we need special forces
					if liTotalSFNeeded > 0 then
						laSpecialRatio = IsUnitsAvailable(laSpecialRatio)

--if ProductionData.ministerTag == usaTag then
--	Utils.LUA_DEBUGOUT("USA liTotalSFNeeded: " .. liTotalSFNeeded)
--	Utils.LUA_DEBUGOUT("USA laSpecialRatio:")
--	Utils.INSPECT_TABLE(laSpecialRatio)
--end

						for k, v in pairs(laSpecialRatio) do
							laSpecialUnitRatio[k] = CalculateRatio(ProductionData.TotalCounts[UnitTypes[k].Index], laSpecialRatio[k])
						end

						liMultiplier = GetMultiplier(laSpecialUnitRatio, laSpecialRatio)

--if ProductionData.ministerTag == usaTag then
--	Utils.LUA_DEBUGOUT("USA liMultiplier: " .. liMultiplier)
--end

						-- Now Figure out what the Unit needs are
						for k, v in pairs(laSpecialUnitRatio) do
							ProductionData.UnitNeeds[UnitTypes[k].Index] = (laSpecialRatio[k] * liMultiplier) - ProductionData.TotalCounts[UnitTypes[k].Index]
						end

--if ProductionData.ministerTag == usaTag then
--	Utils.LUA_DEBUGOUT("USA ProductionData.UnitNeeds AFTER SF:")
--	Utils.INSPECT_TABLE(ProductionData.UnitNeeds)
--end

						-- Modify the counts based on the max amount allowed
						ModifyUnitNeeds(laSpecialUnitRatio, liTotalSFNeeded)
					end
				end

				]]

			end
		end

		-- Process Air Units
		local laAirUnitRatio = {}

		-- PERFORMANCE: only process if IC has been allocated
		if liNeededAirIC > 0 then
			-- Calculate what the ratio is for each unit type
			for k, v in pairs(laAirRatio) do
				laAirUnitRatio[k] = CalculateRatio(ProductionData.TotalCounts[UnitTypes[k].Index], laAirRatio[k])
			end

			local liMultiplier = GetMultiplier(laAirUnitRatio, laAirRatio)

			-- Now Figure out what the Unit needs are
			for k, v in pairs(laAirRatio) do
				ProductionData.UnitNeeds[UnitTypes[k].Index] = (laAirRatio[k] * liMultiplier) - ProductionData.TotalCounts[UnitTypes[k].Index]
			end

			-- Do we need Air Transports
			local liTotalParas = ProductionData.TotalCounts[UnitTypes.paratrooper_brigade.Index]
			local liTotalAirInf = ProductionData.TotalCounts[UnitTypes.airlanding_infantry_brigade.Index]

			if liTotalParas > 0 then
				local liTotalAirTrans = ProductionData.TotalCounts[UnitTypes.transport_plane.Index]
				local liTotalAirTransNeeded = math.floor(liTotalParas / 9)

				if liTotalAirTransNeeded > liTotalAirTrans then
					ProductionData.UnitNeeds[UnitTypes.transport_plane.Index] = liTotalAirTransNeeded - liTotalAirTrans
					laAirUnitRatio["transport_plane"] = 0
				end
			end

			if liTotalAirInf > 0 then
			--Utils.LUA_DEBUGOUT("Country: " .. tostring(ProductionData.ministerTag))
				local liTotalAirTrans = ProductionData.TotalCounts[UnitTypes.gliders.Index]
				local liTotalAirTransNeeded = math.floor(liTotalAirInf / 12)

				if liTotalAirTransNeeded > liTotalAirTrans then
				--Utils.LUA_DEBUGOUT("Country1: " .. tostring(ProductionData.ministerTag))
					ProductionData.UnitNeeds[UnitTypes.gliders.Index] = liTotalAirTransNeeded - liTotalAirTrans
					laAirUnitRatio["gliders"] = 0
				end
			end
--old
--			if ProductionData.ParaCountTotal > 0 then
--				local liTotalAirTrans = ProductionData.TotalCounts[UnitTypes.transport_plane.Index]
--				local liTotalAirTransNeeded = math.floor(ProductionData.ParaCountTotal / 3)

--				if liTotalAirTransNeeded > liTotalAirTrans then
--					ProductionData.UnitNeeds[UnitTypes.transport_plane.Index] = liTotalAirTransNeeded - liTotalAirTrans
--					laAirUnitRatio["transport_plane"] = -1000
--				end
--			end

			-- Does the country have a Secret Ratio
			if laRocketRatio[1] > 0 then
				local liSNeeded = math.max(0, math.ceil((ProductionData.AirCountTotal / laRocketRatio[1]) * laRocketRatio[2]) - ProductionData.FlyingBombsCountTotal)

				-- Do they need any
				if liSNeeded > 0 then
					local lsUnitType = GetHighestUnit("Secret")

					if lsUnitType ~= nil then
						-- Pick a secret weapon randomly
						ProductionData.UnitNeeds[UnitTypes[lsUnitType].Index] = liSNeeded
						laAirUnitRatio[lsUnitType] = 1
					end
				end
			end
		end

		-- Process Naval Units
		local laNavalUnitRatio = {} -- This Array is passed to the BuildNavalUnit method

		--    PERFORMANCE: only process if IC has been allocated
		if liNeededNavalIC > 0 then
			-- Calculate what the ratio is for each unit type
			for k, v in pairs(laNavalRatio) do
				laNavalUnitRatio[k] = CalculateRatio(ProductionData.TotalCounts[UnitTypes[k].Index], laNavalRatio[k])
			end

			local liMultiplier = GetMultiplier(laNavalUnitRatio, laNavalRatio)

			-- Now Figure out what the Unit needs are
			for k, v in pairs(laNavalRatio) do
				ProductionData.UnitNeeds[UnitTypes[k].Index] = (laNavalRatio[k] * liMultiplier) - ProductionData.TotalCounts[UnitTypes[k].Index]
			end

			-- Transport production not working, moved to naval ratio

			--[[ Transport Ships
			if ProductionData.TechStatus:GetLevel(CTechnologyDataBase.GetTechnology("transport_ship_activation")) then
				if laTransportLandRatio[2] > 0 then
					local liTotalTransportsNeeded = math.ceil((ProductionData.LandCountTotal / laTransportLandRatio[1]) * laTransportLandRatio[2]) - ProductionData.TotalCounts[UnitTypes.transport_ship.Index]

					if liTotalTransportsNeeded > 0 then
						local lsUnitType = GetHighestUnit("transport_ship")

						if lsUnitType ~= nil then
							ProductionData.UnitNeeds[UnitTypes[lsUnitType].Index] = liTotalTransportsNeeded
							laNavalUnitRatio[lsUnitType] = 1
						end
					end
				end
			else
			-- Invasion Craft
			if ProductionData.TechStatus:GetLevel(CTechnologyDataBase.GetTechnology("amphibious_invasion_craft")) then
				if laTransportLandRatio[3] > 0 then
					local liTotalInvasionTransportsNeeded = math.ceil((ProductionData.LandCountTotal / laTransportLandRatio[1]) * laTransportLandRatio[3]) - ProductionData.TotalCounts[UnitTypes.landing_craft.Index]

					if liTotalInvasionTransportsNeeded > 0 then
						local lsUnitType = GetHighestUnit("landing_craft")

						if lsUnitType ~= nil then
							ProductionData.UnitNeeds[UnitTypes[lsUnitType].Index] = liTotalInvasionTransportsNeeded
							laNavalUnitRatio[lsUnitType] = 1
						end
					end
				end
			end
			]]

			-- Figure out if we need any CAGs TODO - Make this tech based carrier_size
			local liCAGsNeeded = ProductionData.TotalCounts[UnitTypes.carrier.Index] * 2 + ProductionData.TotalCounts[UnitTypes.light_carrier.Index] * 1 + ProductionData.TotalCounts[UnitTypes.super_carrier.Index] * 3
			local liCAGsCount = ProductionData.TotalCounts[UnitTypes.cag.Index]

			if liCAGsNeeded > liCAGsCount then
				ProductionData.UnitNeeds[UnitTypes.cag.Index] = liCAGsNeeded - liCAGsCount
				-- Give it a ratio of 1 so the AI will push them to be built first
				laNavalUnitRatio["cag"] = 1
			end
		end

		-- Percentage reduce unit needs to allow better distribution
		for k, v in pairs(ProductionData.UnitNeeds) do
			ProductionData.UnitNeeds[k] = Utils.Round(v * math.random() * 0.25)
		end

		-- Build Land Units
		if liNeededLandIC > 0.1 then
			local liNewICCount = ProcessUnits(liNeededLandIC, laSpecialUnitRatio, laFirePower)
			liNewICCount = ProcessUnits(liNewICCount, laLandUnitRatio, laFirePower)
			ProductionData.icAvailable = ProductionData.icAvailable - (liNeededLandIC - liNewICCount)
			liNeededLandIC = liNewICCount
		end

		-- Build Air Units
		if liNeededAirIC > 0.1 then
			--Utils.LUA_DEBUGOUT("TAG: " .. tostring(ProductionData.ministerTag))
			local liNewICCount = ProcessUnits(liNeededAirIC, laAirUnitRatio)
			ProductionData.icAvailable = ProductionData.icAvailable - (liNeededAirIC - liNewICCount)
			liNeededAirIC = liNewICCount
		end

		-- Build Naval Units
		if liNeededNavalIC > 0.1 then
			local liNewICCount = ProcessUnits(liNeededNavalIC, laNavalUnitRatio)
			ProductionData.icAvailable = ProductionData.icAvailable - (liNeededNavalIC - liNewICCount)
			liNeededNavalIC = liNewICCount
		end

		-- Build Buildings
		if liNeededOtherIC > 0.1 then
			local liNewICCount = BuildOtherUnits(liNeededOtherIC)
			ProductionData.icAvailable = ProductionData.icAvailable - (liNeededOtherIC - liNewICCount)
			liNeededOtherIC = liNewICCount
		end
	end

	if math.mod( CCurrentGameState.GetAIRand(), 7) == 0 then
		ProductionData.minister:PrioritizeBuildQueue()
	end
end

-- #######################
-- Helper Build Methods
-- #######################
function ProcessUnits(ic, vaUnitRatio, vaFirePower)
	--local liLoopCount = table.getn(vaUnitRatio)

	-- Performance check, make sure there is enough IC to actually do something
	if ic > 0.1 then
		local lsLowestUnit
		local liLowestValue = -1
		local laUnitProcess = {}

		-- Main Loop Determines how many passess we actually have to make
		for i, z in pairs(vaUnitRatio) do
			for k, v in pairs(vaUnitRatio) do
				if not(laUnitProcess[k] == true) then
					if (not(lsLowestUnit == k) and liLowestValue >= vaUnitRatio[k])
					or liLowestValue == -1 then
						liLowestValue = vaUnitRatio[k]
						lsLowestUnit = k
					end
				end
			end

			laUnitProcess[lsLowestUnit] = true

			ic = BuildUnit(ic,
					lsLowestUnit,
					vaFirePower)

			liLowestValue = -1
		end
	end

	return ic
end

function ModifyUnitNeeds(vaUnitRatio, viUnitNeeds)
	local lsLowestUnit
	local liLowestValue = -1
	local laUnitProcess = {}

	-- Main Loop Determines how many passess we actually have to make
	for i, z in pairs(vaUnitRatio) do
		for k, v in pairs(vaUnitRatio) do
			if not(laUnitProcess[k] == true) then
				if (not(lsLowestUnit == k) and liLowestValue >= vaUnitRatio[k])
				or liLowestValue == -1 then
					liLowestValue = vaUnitRatio[k]
					lsLowestUnit = k
				end
			end
		end

		laUnitProcess[lsLowestUnit] = true

		-- Subtract from the special forces till it = 0
		if ProductionData.UnitNeeds[UnitTypes[lsLowestUnit].Index] > viUnitNeeds then
			ProductionData.UnitNeeds[UnitTypes[lsLowestUnit].Index] = viUnitNeeds
			viUnitNeeds = 0;
		else
			viUnitNeeds = viUnitNeeds - ProductionData.UnitNeeds[UnitTypes[lsLowestUnit].Index];
		end

		liLowestValue = -1
	end
end

-- Figures out if the unit call has to go to an AI specific file or not
function BuildUnit(vIC, vsType, vaFirePower)

	-- Prevent the AI from building/licensing certain unit types.  If they try to license them, they get other units instead  -Marneman
	-- NOTE: this won't work, as the ratios will still not be satisfied, and the AI will continue to try to build/license the original units,
	-- which will in turn continue to build more of the replacement units instead. -Marneman
	-- local origVsType = vsType
	-- if (vsType == "twin_engine_fighters" and not(ProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("twin_engine_fighters")))) then
		-- vsType = "multi_role"
	-- end
	-- if (vsType == "Flying_boat" and not(ProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("Flying_boat")))) then
		-- vsType = "naval_bomber"
	-- end
	-- if (vsType == "gliders" and not(ProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit("gliders")))) then
		-- vsType = "transport_plane"
	-- end

	-- Copy the object so the original is not changed
	-- The templates can be found at the top of this file
	-- Country specific LUA may overwrite this using P.Build_<UNITTYPE>_brigade
	local loType = {Name = vsType}
	for k, v in pairs(UnitTypes[vsType]) do
		loType[k] = UnitTypes[vsType][k]
	end

	-- Setup Parameter defaults
	if loType.Serial == nil then loType.Serial = 1 end
	if loType.Size == nil then loType.Size = 1 end
	if loType.Support == nil then loType.Support = 0 end -- How many Support Brigades to attach
	if loType.SupportVariation == nil then loType.SupportVariation = 0 end -- A range to either increase or reduce the Support amount

	-- Support number variation -- If the support Variation is larger than the actual amount of supports to assign set them to be equal
	if loType.SupportVariation > loType.Support then
		loType.SupportVariation = loType.Support
	end
	-- If we have a Variation randomly build a larger or smaller one.
	if loType.SupportVariation ~= 0 then
		local sign = math.random(2) - 1 -- Only matters if below 100IC
		local amount = math.random(loType.SupportVariation + 1) - 1 -- +1 and -1 needed because of LUA weirdness
		-- Good amount of IC (100) always use max support
		-- 50% Chance for minors to build a bigger div
		if sign == 0 or ProductionData.icTotal > 100 then
			loType.Support = loType.Support + amount
		elseif sign == 1 then
			loType.Support = loType.Support - amount
		end
		if loType.Support < 0 then
			loType.Support = 0
		end
	end

	local lbLicenseRequired = false
	lbLicenseRequired, ProductionData.ManpowerTotal =  Support_License.ProductionCheck(loType, ProductionData)

-- if(origVsType == "twin_engine_fighters" and lbLicenseRequired) then
	-- Utils.LUA_DEBUGOUT("LICENSE REQUIRED: ORIG: " .. origVsType)
	-- Utils.LUA_DEBUGOUT("VSTYPE AFTER: " .. tostring(vsType))
	-- Utils.LUA_DEBUGOUT("LOTYPE AFTER:")
	-- Utils.INSPECT_TABLE(loType)
-- end


	if not(lbLicenseRequired) then
		if vIC > 1 and ProductionData.UnitNeeds[loType.Index] > 0 then
			-- Firepower Check, if present and on list add one to support count
			if ProductionData.IsFirepower and vaFirePower ~= nil and loType.Support > 0 then
				for i = 0, table.getn(vaFirePower) do
					if vaFirePower[i] == vsType then
						loType.Support = loType.Support + 1
					end
				end
			end

			local lsMethodOveride = "Build_" .. vsType

			-- Check to see if the Country AI file has an overide or Defaults Do
			local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, lsMethodOveride)
			if loFunRef then
				vIC, ProductionData.ManpowerTotal, ProductionData.UnitNeeds[loType.Index] = loFunRef(vIC, ProductionData.ManpowerTotal, loType, ProductionData, ProductionData.UnitNeeds[loType.Index])
			else
				vIC, ProductionData.ManpowerTotal, ProductionData.UnitNeeds[loType.Index] = Support.CreateUnit(loType, vIC, ProductionData.UnitNeeds[loType.Index], ProductionData, nil)
			end
		end
	end

	return vIC
end

-- For the specified SubType it gets the highest unit in the array that is Available
function GetHighestUnit(vsSubType)
	local lsUnitAvailable = nil

	for k, v in pairs(UnitTypes) do
		if v.SubType == vsSubType then
			if ProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit(k)) then
				lsUnitAvailable = k
			end
		end
	end

	return lsUnitAvailable
end

-- Converts the Unit ratio to a % based number. If there
--   are 0 units but a Ratio exists then it will set it to 1.
function CalculateRatio(viUnitCount, viUnitRatio)
	local rValue

	if viUnitRatio == 0 then
		rValue = 0
	elseif viUnitCount == 0 then
		rValue = 1
	else
		rValue = viUnitCount / viUnitRatio
	end

	return rValue
end
-- Returns the Ratio Array requested
function GetBuildRatio(vsType)
	return Utils.CallBuildFunction(ProductionData.ministerTag, ProductionData.IsNaval, vsType, ProductionData)
end

function GetMultiplier(vaUnitRatio, vaRatio)
	local liMultiplier = 0
	local liAddToMultiplier = 2

	for k, v in pairs(vaUnitRatio) do
		if vaRatio[k] > 0 then
			liMultiplier = math.max(liMultiplier, vaUnitRatio[k])
		end
	end

	-- Make sure some sort of multiplier gets past, AddToMultipler if 0 means Multiplier is something
	return math.max((liMultiplier + liAddToMultiplier), liAddToMultiplier)
end

-- Goes through the ratios and sets them to 0 if the country can't build any of those units
function IsUnitsAvailable(vaRatio)
	for k, v in pairs(vaRatio) do
		if not(ProductionData.TechStatus:IsUnitAvailable(CSubUnitDataBase.GetSubUnit(k))) then
			vaRatio[k] = 0
		end
	end

	return vaRatio
end

-- Looks for the elite units specified to see if they can be built and if so sets the need amount
function GetEliteUnitBuildCount(vaElitUnits)
	local laNewEliteUnits = {}

	if vaElitUnits ~= nil then
		for i = 1, table.getn(vaElitUnits) do
			laNewEliteUnits[vaElitUnits[i]] = ProductionData.ministerCountry:CountMaxUnitsStillBuildable(CSubUnitDataBase.GetSubUnit(vaElitUnits[i]))
		end
	end

	return laNewEliteUnits
end


-- #######################
-- End of Helper Build Methods
-- #######################

-- #######################
-- Building Construction
-- #######################
function BuildOtherUnits(ic)
	-- Buildings
	if ic > 0.1 then
		--Setup the building object
		local loBuildings = {
			coastal_fort = CBuildingDataBase.GetBuilding("coastal_fort" ),
			land_fort = CBuildingDataBase.GetBuilding( "land_fort" ),
			anti_air = CBuildingDataBase.GetBuilding("anti_air" ),
			industry = CBuildingDataBase.GetBuilding("industry" ),
			heavy_industry = CBuildingDataBase.GetBuilding("industry" ),
			radar_station = CBuildingDataBase.GetBuilding("radar_station" ),
			nuclear_reactor = CBuildingDataBase.GetBuilding("nuclear_reactor" ),
			rocket_test = CBuildingDataBase.GetBuilding("rocket_test" ),
			infra = CBuildingDataBase.GetBuilding("infra"),
			--railroad = CBuildingDataBase.GetBuilding("railroad"),
			air_base = CBuildingDataBase.GetBuilding("air_base"),
			naval_base = CBuildingDataBase.GetBuilding("naval_base"),
			underground = CBuildingDataBase.GetBuilding("underground"),
			-- Resource buildings
			steel_factory = CBuildingDataBase.GetBuilding("steel_factory"),
			coal_mining = CBuildingDataBase.GetBuilding("coal_mining"),
			sourcing_rares = CBuildingDataBase.GetBuilding("sourcing_rares"),
			oil_well = CBuildingDataBase.GetBuilding("oil_well"),
			oil_refinery = CBuildingDataBase.GetBuilding("oil_refinery"),
		}

		local liTotalBuildings = 17

		-- Setup which buildings can be built
		loBuildings.lbCoastal_fort = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.coastal_fort)
		loBuildings.lbLand_fort = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.land_fort)
		loBuildings.lbAnti_air = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.anti_air)
		loBuildings.lbIndustry = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.industry)
		loBuildings.lbHeavy_Industry = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.heavy_industry)
		loBuildings.lbRadar_station = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.radar_station)
		loBuildings.lbNuclear_reactor = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.nuclear_reactor)
		loBuildings.lbRocket_test = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.rocket_test)
		loBuildings.lbInfra = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.infra)
		--loBuildings.lbRailroad = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.railroad)
		loBuildings.lbAir_base = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.air_base)
		loBuildings.lbNaval_base = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.naval_base)
		loBuildings.lbUnderground = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.underground)
		loBuildings.lbSteel = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.steel_factory)
		loBuildings.lbCoal = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.coal_mining)
		loBuildings.lbRares = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.sourcing_rares)
		loBuildings.lbOil = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.oil_well)
		loBuildings.lbRefinery = ProductionData.TechStatus:IsBuildingAvailable(loBuildings.oil_refinery)

		-- Produce buildings until your out of IC that has been allocated
		--   Never have more than 1 rocket sites
		local liRocketCap = 1
		local liReactorCap = 2
		local loCorePrv = CoreProvincesLoop(loBuildings, liRocketCap, liReactorCap)

		-- Puppets are limited to resource buildings
		local isPuppet = ProductionData.ministerAI:GetCountry():IsPuppet()
		-- If no more resource buildings to do, act as if not a puppet
		if table.getn(loCorePrv.PrvOil) == 0 and table.getn(loCorePrv.PrvCoal) == 0 and table.getn(loCorePrv.PrvSteel) == 0 and table.getn(loCorePrv.PrvRares) == 0 then
			isPuppet = false
		end

		--Puppet focuses
		if ProductionData.ministerAI:GetCountry():GetVariables():GetVariable(CString("puppet_focus_variable")):Get() == 2 then
			ic = BuildBuilding(ic, loBuildings.coal_mining, loCorePrv.PrvCoal)
			return ic
		end
		if ProductionData.ministerAI:GetCountry():GetVariables():GetVariable(CString("puppet_focus_variable")):Get() == 3 then
			ic = BuildBuilding(ic, loBuildings.steel_factory, loCorePrv.PrvRefinery)
			return ic
		end
		if ProductionData.ministerAI:GetCountry():GetVariables():GetVariable(CString("puppet_focus_variable")):Get() == 1 then
			ic = BuildBuilding(ic, loBuildings.sourcing_rares, loCorePrv.PrvRares)
			return ic
		end
		if ProductionData.ministerAI:GetCountry():GetVariables():GetVariable(CString("puppet_focus_variable")):Get() == 7 then
			ic = BuildBuilding(ic, loBuildings.oil_well, loCorePrv.PrvOil)
			return ic
		end

		-- Try to find production building x times
		local x = liTotalBuildings * 4
		for i = 1, x, 1 do
			local liBuilding = math.random(liTotalBuildings)

			if liBuilding== 1 and isPuppet == false then
				-- Underground base
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_Underground")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				-- PERFORMANCE dont bother with Underground if not even at war
				if ic > 0.1 and loBuildings.lbUnderground and lbProcess and ProductionData.ministerCountry:IsAtWar() then
					local liProvinceID = ProductionData.ministerCountry:GetRandomUnderGroundTarget() -- Build on random target
					if liProvinceID > 0 then
						ic = BuildBuilding(ic, loBuildings.underground, liProvinceID)
					end
				end

			elseif liBuilding== 2 and isPuppet == false and ProductionData.icTotal > 200 then
				-- Nuclear Reactors stations
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_NuclearReactor")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				if ic > 0.1 and loBuildings.lbNuclear_reactor and lbProcess then
					ic = BuildBuilding(ic, loBuildings.nuclear_reactor, loCorePrv.PrvForBuilding)
				end

			elseif liBuilding== 3 and isPuppet == false and ProductionData.icTotal > 200 then
				-- Rocket Test Site stations
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_RocketTest")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				if ic > 0.1 and loBuildings.lbRocket_test and lbProcess then
					ic = BuildBuilding(ic, loBuildings.rocket_test, loCorePrv.PrvForBuilding)
				end

			elseif liBuilding== 4 and isPuppet == false then
				-- Industry
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_Industry")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				if ic > 0.1 and loBuildings.lbIndustry and lbProcess then
					ic = BuildBuilding(ic, loBuildings.industry, loCorePrv.PrvForBuildingIndustry)
				end

			elseif liBuilding== 5 and isPuppet == false then
				-- Build Forts
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_Fort")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				-- AI production disabled until candidate identification
				-- if ic > 0.1 and loBuildings.lbLand_fort and lbProcess then
				--	ic = BuildBuilding(ic, loBuildings.land_fort, loCorePrv.PrvForBuildingIndustry) -- Currently builds on industry
				-- end

			elseif liBuilding== 6 and isPuppet == false then
				-- Build Coastal Forts
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_CoastalFort")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				if ic > 0.1 and loBuildings.lbCoastal_fort and lbProcess then
					ic = BuildBuilding(ic, loBuildings.coastal_fort, loCorePrv.PrvCoastalFort)
				end

			elseif liBuilding== 7 and isPuppet == false then
				-- Build Anti Air
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_AntiAir")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				if ic > 0.1 and loBuildings.lbAnti_air and lbProcess then
					ic = BuildBuilding(ic, loBuildings.anti_air, loCorePrv.PrvAntiAir)
				end

			elseif liBuilding== 8 and isPuppet == false and ProductionData.icTotal > 100 then
				-- Radar stations
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_Radar")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				if ic > 0.1 and loBuildings.lbRadar_station and lbProcess then
					ic = BuildBuilding(ic, loBuildings.radar_station, loCorePrv.PrvRadarStation)
				end

			elseif liBuilding== 9 and isPuppet == false and ProductionData.icTotal > 50 then
				-- Build Airfields
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_AirBase")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				if ic > 0.1 and loBuildings.lbAir_base and lbProcess then
					ic = BuildBuilding(ic, loBuildings.air_base, loCorePrv.PrvAirBase)
				end

			-- Disabled until better candidate identification
			-- elseif liBuilding== 10 then
				-- Infrastructure

			-- Not actually buildable now but may change in future, candidate provinces shoul have >= 4 IC for 25% bonus
			elseif liBuilding== 99 and isPuppet == false then
				-- Heavy Industry
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_Heavy_Industry")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				if ic > 0.1 and loBuildings.lbHeavy_Industry and lbProcess then
					ic = BuildBuilding(ic, loBuildings.heavy_industry, loCorePrv.PrvForBuildingHeavy_Industry)
				end

			elseif liBuilding== 12 and isPuppet == false and ProductionData.icTotal > 50 then
				-- Naval Base
				local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, "Build_NavalBase")
				local lbProcess = true
				if loFunRef then
					ic, lbProcess = loFunRef(ic, ProductionData)
				end
				if ic > 0.1 and loBuildings.lbNaval_base and lbProcess then
					ic = BuildBuilding(ic, loBuildings.naval_base, loCorePrv.PrvNavalBase)
				end

			--Resources
			elseif liBuilding == 13 then

				-- vDailyHome + vConvoyedIn does not include trade
				-- vDailyExpense includes conversion
				-- vDailyBalance is final value, includes trade
				local loResource = CResourceValues()
				loResource:GetResourceValues( ProductionData.ministerCountry, CGoodsPool._ENERGY_ )

				-- If excess energy build industry instead
				if loResource.vDailyExpense * 1.25 < loResource.vDailyHome + loResource.vConvoyedIn and loBuildings.lbIndustry and isPuppet == false then
					if ic > 0.1 then
						ic = BuildBuilding(ic, loBuildings.industry, loCorePrv.PrvForBuildingIndustry)
					end
				-- Coal Mine
				else
					if ic > 0.1 and loBuildings.lbCoal then
						ic = BuildBuilding(ic, loBuildings.coal_mining, loCorePrv.PrvCoal)
					end
				end

			elseif liBuilding == 14 then

				-- vDailyHome + vConvoyedIn does not include trade
				-- vDailyExpense includes conversion
				-- vDailyBalance is final value, includes trade
				local loResource = CResourceValues()
				loResource:GetResourceValues( ProductionData.ministerCountry, CGoodsPool._METAL_ )

				-- If excess metal build industry instead
				if loResource.vDailyExpense * 1.25 < loResource.vDailyHome + loResource.vConvoyedIn and loBuildings.lbIndustry and isPuppet == false then
					if ic > 0.1 then
						ic = BuildBuilding(ic, loBuildings.industry, loCorePrv.PrvForBuildingIndustry)
					end
				-- Steel Factory
				else
					if ic > 0.1 and loBuildings.lbSteel then
						ic = BuildBuilding(ic, loBuildings.steel_factory, loCorePrv.PrvSteel)
					end
				end

			elseif liBuilding == 15 then

				-- vDailyHome + vConvoyedIn does not include trade
				-- vDailyExpense includes conversion
				-- vDailyBalance is final value, includes trade
				local loResource = CResourceValues()
				loResource:GetResourceValues( ProductionData.ministerCountry, CGoodsPool._RARE_MATERIALS_ )

				-- If excess rares build industry instead
				if loResource.vDailyExpense * 1.25 < loResource.vDailyHome + loResource.vConvoyedIn and loBuildings.lbIndustry and isPuppet == false then
					if ic > 0.1 then
						ic = BuildBuilding(ic, loBuildings.industry, loCorePrv.PrvForBuildingIndustry)
					end
				-- Rares Sourcing (limited to countries with more than 50 IC available)
				else
					if ic > 50 and loBuildings.lbRares then
						ic = BuildBuilding(ic, loBuildings.sourcing_rares, loCorePrv.PrvRares)
					end
				end

			elseif liBuilding == 16 then
				-- Oil Field
				if ic > 0.1 and loBuildings.lbOil then
					ic = BuildBuilding(ic, loBuildings.oil_well, loCorePrv.PrvOil)
				end

			elseif liBuilding == 17 then

				local loResource = CResourceValues()
				loResource:GetResourceValues( ProductionData.ministerCountry, CGoodsPool._CRUDE_OIL_ )
				local production = loResource.vDailyHome + loResource.vConvoyedIn

				-- Calculate total number of refineries (current + in construction)
				local totalRefineries = 0
				for liProvinceId in ProductionData.ministerCountry:GetControlledProvinces() do
					local loProvince = CCurrentGameState.GetProvince(liProvinceId)
					local refinery = loProvince:GetBuilding(loBuildings.oil_refinery)
					local buildingRefinery = loProvince:GetCurrentConstructionLevel(loBuildings.oil_refinery)
					local level = refinery:GetMax()
					totalRefineries = totalRefineries + level + buildingRefinery
				end

				-- 1 Refinery per 75 IC and per 40 oil produced
				local targetRefineries = math.floor(ProductionData.icAvailable / 75) + math.floor(production / 40)
				local enoughRefineries = false
				if targetRefineries <= totalRefineries then
					enoughRefineries = true
				end

				-- Build Refinery if not enough
				if enoughRefineries == false then
					-- Oil Refinery
					if ic > 0.1 and loBuildings.lbRefinery then
						ic = BuildBuilding(ic, loBuildings.oil_refinery, loCorePrv.PrvRefinery)
					end
				end
			end
		end
	end

	return ic
end

-- Generic building construction
-- As "provinces" Argument this function can take both tables of potential provinces or a single province
function BuildBuilding(ic, building, provinces)
	if type(provinces) == "table" then
		local nProvinces = table.getn(provinces)
		if nProvinces > 0 then
			local id = math.random(nProvinces)
			local constructCommand = CConstructBuildingCommand(ProductionData.ministerTag, building, provinces[id], 1 )

			if constructCommand:IsValid() then

				-- If already building this building in this province ignore it (ideally would randomize until finding vacant province but this is fine)
				local province = CCurrentGameState.GetProvince(provinces[id])
				if province:GetCurrentConstructionLevel(building) > 0 then
					return ic
				end

				table.remove(provinces, id)

				ProductionData.ministerAI:Post( constructCommand )
				local liCost = ProductionData.ministerCountry:GetBuildCost(building):Get()
				ic = ic - liCost
			end
		end

	elseif type(provinces) == "number" then
		local constructCommand = CConstructBuildingCommand(ProductionData.ministerTag, building, provinces, 1 )
		if constructCommand:IsValid() then

			-- If already building this building in this province ignore it (ideally would randomize until finding vacant province but this is fine)
			local province = CCurrentGameState.GetProvince(provinces)
			if province:GetCurrentConstructionLevel(building) > 0 then
				return ic
			end

			ProductionData.ministerAI:Post( constructCommand )
			local liCost = ProductionData.ministerCountry:GetBuildCost(building):Get()
			ic = ic - liCost
		end

	end
	return ic
end
-- function to blindly queue buildings which were requested by the player via the covert ops menu
function BuildPlayersRequestedBuildings(minister)
	local variables = ProductionData.ministerCountry:GetVariables()
	-- cleanup the old variables which remembered which provinces we already build in for that request period
	if variables:GetVariable(CString("zDsafe_requestedBuildings_cleanUp")):Get() == 1 then
		-- Utils.LUA_DEBUGOUT("Cleanup requested!")
		for provinceId in ProductionData.ministerCountry:GetControlledProvinces() do
			if variables:GetVariable(CString("zDsafe_requestedBuildingAirbase_" .. provinceId .. "_queuedThisPeriod")):Get() == 1 then
				local command = CSetVariableCommand(
					ProductionData.ministerTag, CString("zDsafe_requestedBuildingAirbase_" .. provinceId .. "_queuedThisPeriod"), CFixedPoint(0))
				minister:GetOwnerAI():Post( command )
			end
			if variables:GetVariable(CString("zDsafe_requestedBuildingInfra_" .. provinceId .. "_queuedThisPeriod")):Get() == 1 then
				local command = CSetVariableCommand(
					ProductionData.ministerTag, CString("zDsafe_requestedBuildingInfra_" .. provinceId .. "_queuedThisPeriod"), CFixedPoint(0))
				minister:GetOwnerAI():Post( command )
			end
		end
		local command = CSetVariableCommand(
			ProductionData.ministerTag, CString("zDsafe_requestedBuildings_cleanUp"), CFixedPoint(0))
		minister:GetOwnerAI():Post( command )
		-- exit early in this case because manipulating the same variables in the same tick is unkown behavior to me
		-- losing this 1 day doesnt matter as we have 5 days to spare and productionminister runs everyday
		return
	end
	local cRequestAirbase = CBuildingDataBase.GetBuilding("request_airbase")
	local cRequestInfra = CBuildingDataBase.GetBuilding("request_infra")
	for provinceId in ProductionData.ministerCountry:GetControlledProvinces() do
		local province = CCurrentGameState.GetProvince(provinceId)
		if province:GetOwner() == ProductionData.ministerTag then

			-- Airbases
			local requestAirbaseLevelCurrent = province:GetBuilding(cRequestAirbase):GetCurrent():Get()
			if requestAirbaseLevelCurrent >= 1 then
				-- Utils.LUA_DEBUGOUT("provinceId: " .. tostring(provinceId))
				-- Utils.LUA_DEBUGOUT("requestAirbaseLevelCurrent: " .. tostring(requestAirbaseLevelCurrent))
				local cAirbase = CBuildingDataBase.GetBuilding("air_base")
				local cAirbaseCount = province:GetBuilding(cAirbase):GetCurrent():Get()
				local cAirbasePlanned = province:GetCurrentConstructionLevel(cAirbase)
				-- Utils.LUA_DEBUGOUT("cAirbaseCount: " .. tostring(cAirbaseCount))
				-- Utils.LUA_DEBUGOUT("cAirbasePlanned: " .. tostring(cAirbasePlanned))
				if variables:GetVariable(CString("zDsafe_requestedBuildingAirbase_" .. provinceId .. "_queuedThisPeriod")):Get() ~= 1 and
				cAirbaseCount + cAirbasePlanned <= 10 then
					-- Utils.LUA_DEBUGOUT("BUILD IT!")
					local constructCommand = CConstructBuildingCommand(ProductionData.ministerTag, cAirbase, provinceId, 1 )
					minister:GetOwnerAI():Post( constructCommand )
					local command = CSetVariableCommand(
						ProductionData.ministerTag, CString("zDsafe_requestedBuildingAirbase_" .. provinceId .. "_queuedThisPeriod"), CFixedPoint(1))
					minister:GetOwnerAI():Post( command )
				end
			end

			-- Infra
			local requestInfraLevelCurrent = province:GetBuilding(cRequestInfra):GetCurrent():Get()
			if requestInfraLevelCurrent >= 1 then
				-- Utils.LUA_DEBUGOUT("provinceId: " .. tostring(provinceId))
				-- Utils.LUA_DEBUGOUT("requestInfraLevelCurrent: " .. tostring(requestInfraLevelCurrent))
				local cInfra = CBuildingDataBase.GetBuilding("infra")
				local cInfraCount = province:GetBuilding(cInfra):GetCurrent():Get()
				local cInfraPlanned = province:GetCurrentConstructionLevel(cInfra)
				-- Utils.LUA_DEBUGOUT("cInfraCount: " .. tostring(cInfraCount))
				-- Utils.LUA_DEBUGOUT("cInfraPlanned: " .. tostring(cInfraPlanned))
				if variables:GetVariable(CString("zDsafe_requestedBuildingInfra_" .. provinceId .. "_queuedThisPeriod")):Get() ~= 1 and
				cInfraCount + cInfraPlanned <= 10 then
					-- Utils.LUA_DEBUGOUT("BUILD IT!")
					local constructCommand = CConstructBuildingCommand(ProductionData.ministerTag, cInfra, provinceId, 1 )
					minister:GetOwnerAI():Post( constructCommand )
					local command = CSetVariableCommand(
						ProductionData.ministerTag, CString("zDsafe_requestedBuildingInfra_" .. provinceId .. "_queuedThisPeriod"), CFixedPoint(1))
					minister:GetOwnerAI():Post( command )
				end
			end
		end
	end
end

function CoreProvincesLoop(voBuildings, viRocketCap, viReactorCap)

	local loCorePrv = {}
	loCorePrv["RocketSites"] = ProductionData.ministerCountry:GetTotalCoreBuildingLevels(voBuildings.rocket_test:GetIndex()):Get()
	loCorePrv["ReactorSites"] = ProductionData.ministerCountry:GetTotalCoreBuildingLevels(voBuildings.nuclear_reactor:GetIndex()):Get()
	loCorePrv["PrvLowInfra69"] = {}
	loCorePrv["PrvLowInfra99"] = {}
	loCorePrv["PrvForBuilding"] = {}
	loCorePrv["PrvForBuildingIndustry"] = {}
	loCorePrv["PrvForBuildingHeavy_Industry"] = {}
	loCorePrv["PrvAntiAir"] = {}
	loCorePrv["PrvCoastalFort"] = {}
	loCorePrv["PrvRadarStation"] = {}
	loCorePrv["PrvAirBase"] = {}
	loCorePrv["PrvNavalBase"] = {}
	loCorePrv["PrvSteel"] = {}
	loCorePrv["PrvCoal"] = {}
	loCorePrv["PrvRares"] = {}
	loCorePrv["PrvOil"] = {}
	loCorePrv["PrvRefinery"] = {}

	for liProvinceId in ProductionData.ministerCountry:GetControlledProvinces() do
		local loProvince = CCurrentGameState.GetProvince(liProvinceId)
		local loProvinceInfra = loProvince:GetBuilding(voBuildings.infra)
		local liInfraSize = loProvinceInfra:GetMax():Get()

		if liInfraSize > 1 then

			local isFrontProvince = loProvince:IsFrontProvince(false)
			--local liConstructionLevel = loProvince:GetCurrentConstructionLevel(voBuildings.infra)
			local loOwnerTag = loProvince:GetOwner()

			-- Any province can have their infra improved not just owned ones
			--if voBuildings.lbInfra then
			--	if liInfraSize < 7 and not(liConstructionLevel > 0) and not(isFrontProvince) then
			--		table.insert(loCorePrv.PrvLowInfra69, liProvinceId)
			--	elseif liInfraSize < 10 and not(liConstructionLevel > 0) and not(isFrontProvince) then
			--		table.insert(loCorePrv.PrvLowInfra99, liProvinceId)
			--	end
			--end

			if not(isFrontProvince) then
				local lbHasNavalBase = loProvince:HasBuilding(voBuildings.naval_base)
				local lbHasIndustry = loProvince:HasBuilding(voBuildings.industry)
				local lbHasAirField = loProvince:HasBuilding(voBuildings.air_base)

				-- Provinces with Industry are candidate for proportional AA (1/5)
				if lbHasIndustry then
					if voBuildings.lbAnti_air then
						if loProvince:GetBuilding(voBuildings.anti_air):GetMax():Get() < math.floor(loProvince:GetBuilding(voBuildings.industry):GetMax():Get()/5) then
							if loProvince:GetCurrentConstructionLevel(voBuildings.anti_air) == 0 then
								table.insert(loCorePrv.PrvAntiAir, liProvinceId)
							end
						end
					end
				end

				-- Provinces with Air Base are candidate for proportional AA (1/5)
				if lbHasAirField then
					if voBuildings.lbAnti_air then
						if loProvince:GetBuilding(voBuildings.anti_air):GetMax():Get() < math.floor(loProvince:GetBuilding(voBuildings.air_base):GetMax():Get()/5) then
							if loProvince:GetCurrentConstructionLevel(voBuildings.anti_air) == 0 then
								table.insert(loCorePrv.PrvAntiAir, liProvinceId)
							end
						end
					end
				end

				-- Provinces with Naval Base are candidate for proportional AA (1/5)
				if lbHasNavalBase then
					if voBuildings.lbAnti_air then
						if loProvince:GetBuilding(voBuildings.anti_air):GetMax():Get() < math.floor(loProvince:GetBuilding(voBuildings.naval_base):GetMax():Get()/5) then
							if loProvince:GetCurrentConstructionLevel(voBuildings.anti_air) == 0 then
								table.insert(loCorePrv.PrvAntiAir, liProvinceId)
							end
						end
					end
				end

				-- Provinces with Industry, Air Base or Naval Base are candidates for Radar
				if lbHasNavalBase or lbHasIndustry or lbHasAirField then
					if voBuildings.lbRadar_station then
						if loProvince:GetBuilding(voBuildings.radar_station):GetMax():Get() < 3 then
							if loProvince:GetCurrentConstructionLevel(voBuildings.radar_station) == 0 then
								table.insert(loCorePrv.PrvRadarStation, liProvinceId)
							end
						end
					end
				end

				-- Provinces with Air Base are candidate for Air Base
				if lbHasAirField then
					if voBuildings.lbAir_base then
						if loProvince:GetBuilding(voBuildings.air_base):GetMax():Get() < 10 then
							if loProvince:GetCurrentConstructionLevel(voBuildings.air_base) == 0 then
								table.insert(loCorePrv.PrvAirBase, liProvinceId)
							end
						end
					end
				end

				-- Provinces with Naval Base are candidate for proportional Air Base (for defense) (1/4)
				if lbHasNavalBase then
					if voBuildings.lbAir_base then
						if loProvince:GetBuilding(voBuildings.air_base):GetMax():Get() < math.ceil(loProvince:GetBuilding(voBuildings.naval_base):GetMax():Get()/4) then
							if loProvince:GetCurrentConstructionLevel(voBuildings.air_base) == 0 then
								table.insert(loCorePrv.PrvAirBase, liProvinceId)
							end
						end
					end
				end

				-- Provinces with Naval Base are candidate for Naval Base
				if lbHasNavalBase then
					if voBuildings.lbNaval_base then
						if loProvince:GetBuilding(voBuildings.naval_base):GetMax():Get() < 10 then
							if loProvince:GetCurrentConstructionLevel(voBuildings.naval_base) == 0 then
								table.insert(loCorePrv.PrvNavalBase, liProvinceId)
							end
						end
					end
				end

				-- Provinces with Naval Base are candidate for proportional Coastal Defense (1/4)
				if lbHasNavalBase then
					if voBuildings.lbCoastal_fort then
						if loProvince:GetBuilding(voBuildings.coastal_fort):GetMax():Get() < math.floor(loProvince:GetBuilding(voBuildings.naval_base):GetMax():Get()/4) then
							if loProvince:GetCurrentConstructionLevel(voBuildings.coastal_fort) == 0 then
								table.insert(loCorePrv.PrvCoastalFort, liProvinceId)
							end
						end
					end
				end

				-- Provinces with resource buildings are candidates for industry
				if (loProvince:GetBuilding(voBuildings.coal_mining):GetMax():Get() > 0 or
				loProvince:GetBuilding(voBuildings.steel_factory):GetMax():Get() > 0 or
				loProvince:GetBuilding(voBuildings.sourcing_rares):GetMax():Get() > 0 or
				loProvince:GetBuilding(voBuildings.oil_well):GetMax():Get() > 0 or
				loProvince:GetBuilding(voBuildings.oil_refinery):GetMax():Get() > 0
				) then
					if loProvince:GetBuilding(voBuildings.industry):GetMax():Get() <= 9	and not(loProvince:GetCurrentConstructionLevel(voBuildings.industry) > 0) then
						table.insert(loCorePrv.PrvForBuildingIndustry, liProvinceId)
					end
				end

				-- Industry, Rocket and Nuclear
				if lbHasIndustry and ProductionData.ministerTag == loOwnerTag then
					-- Provinces that qualify for Nuclear Reactor and Rocket test sites
					if voBuildings.lbNuclear_reactor or voBuildings.lbRocket_test then
						if (voBuildings.lbRocket_test and loCorePrv.RocketSites < viRocketCap)
						or (voBuildings.lbNuclear_reactor and loCorePrv.ReactorSites < viReactorCap) then
							if not(loProvince:GetCurrentConstructionLevel(voBuildings.rocket_test) > 0) and not(loProvince:GetCurrentConstructionLevel(voBuildings.nuclear_reactor) > 0) then
								table.insert(loCorePrv.PrvForBuilding, liProvinceId)
							end
						end
					end

					-- If the Build Industry flag is set figure out provinces that qualify for Industry
					if voBuildings.lbIndustry then
						if loProvince:GetBuilding(voBuildings.industry):GetMax():Get() <= 9
						and not(loProvince:GetCurrentConstructionLevel(voBuildings.industry) > 0) then
							table.insert(loCorePrv.PrvForBuildingIndustry, liProvinceId)
						end
					end
				end

				-- Provinces with Resource Buildings are candidates for Resource Buildings
				if voBuildings.lbCoal then
					if loProvince:GetCurrentConstructionLevel(voBuildings.coal_mining) == 0 and loProvince:GetBuilding(voBuildings.coal_mining):GetMax():Get() > 0 and loProvince:GetBuilding(voBuildings.coal_mining):GetMax():Get() < 10 then
						table.insert(loCorePrv.PrvCoal, liProvinceId)
					end
				end
				if voBuildings.lbSteel then
					if loProvince:GetCurrentConstructionLevel(voBuildings.steel_factory) == 0 and loProvince:GetBuilding(voBuildings.steel_factory):GetMax():Get() > 0 and loProvince:GetBuilding(voBuildings.steel_factory):GetMax():Get() < 10 then
						table.insert(loCorePrv.PrvSteel, liProvinceId)
					end
				end
				if voBuildings.lbRares then
					if loProvince:GetCurrentConstructionLevel(voBuildings.sourcing_rares) == 0 and loProvince:GetBuilding(voBuildings.sourcing_rares):GetMax():Get() > 0 and loProvince:GetBuilding(voBuildings.sourcing_rares):GetMax():Get() < 10 then
						table.insert(loCorePrv.PrvRares, liProvinceId)
					end
				end
				if voBuildings.lbOil then
					if loProvince:GetCurrentConstructionLevel(voBuildings.oil_well) == 0 and loProvince:GetBuilding(voBuildings.oil_well):GetMax():Get() > 0 and loProvince:GetBuilding(voBuildings.oil_well):GetMax():Get() < 10 then
						table.insert(loCorePrv.PrvOil, liProvinceId)
					end
				end

				-- Provinces with Oil Well are candidates for Oil Refinery
				if voBuildings.lbRefinery then
					if loProvince:GetCurrentConstructionLevel(voBuildings.oil_refinery) == 0 and loProvince:GetBuilding(voBuildings.oil_well):GetMax():Get() > 0 and loProvince:GetBuilding(voBuildings.oil_refinery):GetMax():Get() < 10 then
						table.insert(loCorePrv.PrvRefinery, liProvinceId)
					end
				end

				-- Provinces with Industry are candidates for Oil Refinery
				if voBuildings.lbRefinery then
					if loProvince:GetCurrentConstructionLevel(voBuildings.oil_refinery) == 0 and loProvince:GetBuilding(voBuildings.industry):GetMax():Get() > 0 and loProvince:GetBuilding(voBuildings.oil_refinery):GetMax():Get() < 10 then
						table.insert(loCorePrv.PrvRefinery, liProvinceId)
					end
				end

			end

			-- Country Specific Province Overrides
			for k,v in pairs(loCorePrv) do
				loCorePrv[k] = OverrideProvinces(v, k)
			end

		end
	end

	return loCorePrv
end

-- Override province candidates with country specific
function OverrideProvinces(buildingProvinces, buildingProvincesType)

	-- Get country specific
	local loFunRef = Utils.GetFunctionReference(ProductionData.ministerTag, ProductionData.IsNaval, buildingProvincesType)

	if loFunRef then
		local replace = true
		local provinces
		provinces, replace = loFunRef(ProductionData)

		-- Clear table if replacing
		if replace == true then
			buildingProvinces = {}
		end

		-- Insert country specific
		for k,v in pairs(provinces) do
			table.insert(buildingProvinces, v)
		end
	end

	return buildingProvinces

end

-- #######################
-- End Building Construction
-- #######################


-- #######################
-- Convoy Building
-- #######################
function ConstructConvoys(viIC)
	if viIC > 0.1 and ProductionData.PortsTotal > 0 then
		local liNeeded = ProductionData.ministerCountry:GetTotalNeededConvoyTransports()
		local liCurrent = ProductionData.ministerCountry:GetTotalConvoyTransports()
		local liConstruction = ProductionData.minister:CountTransportsUnderConstruction()
		local maxSerial = 3

		-- Grab the Convoy Ratios and Calculate Convoys Needed
		local laConvoyRatio = GetBuildRatio("ConvoyRatio")
		local liNeededMultiplier = ((100 + laConvoyRatio[1]) * .01)
		local liLowCap = laConvoyRatio[2]
		local liHighCap = laConvoyRatio[3]
		local liEscortRatio = laConvoyRatio[4]

		local liActuallyNeeded = Utils.Round((((liNeeded * liNeededMultiplier) - liCurrent) - liConstruction ))
		local liLowCapNeeded = (liNeeded - (liCurrent + liConstruction)) + liLowCap
		local liHighCapNeeded = (liNeeded - (liCurrent + liConstruction)) + liHighCap

		if liLowCapNeeded > liActuallyNeeded then
			liActuallyNeeded = liLowCapNeeded
		elseif liActuallyNeeded > liHighCapNeeded then
			liActuallyNeeded = liHighCapNeeded
		end

		-- If their convoy reserves are to low then build smaller serial runs
		if liActuallyNeeded > 100 then maxSerial = 1 end

		if liActuallyNeeded > 0 then
			local liCost = ProductionData.ministerCountry:GetConvoyBuildCost():Get()
			local liRequested = math.ceil(liActuallyNeeded / defines.economy.CONVOY_CONSTRUCTION_SIZE)
			viIC = BuildTransportOrEscort(liRequested, maxSerial, false, liCost, viIC)
		end

		-- Now Process Escorts Check
		local liENeeded = 0
		-- Seperate line in case of Ratio of 0
		if liEscortRatio > 0 then
			liENeeded = math.ceil((liNeeded + liLowCap) / liEscortRatio)
		-- 0 escort ratio, early return
		else
			return viIC
		end

		local liECurrent = ProductionData.ministerCountry:GetEscorts()
		local liEConstruction = ProductionData.minister:CountEscortsUnderConstruction()
		local lEActuallyNeeded = liENeeded - (liECurrent + liEConstruction)

		-- If we need escorts lets build them
		if lEActuallyNeeded > 0 then
			local liCost = ProductionData.ministerCountry:GetEscortBuildCost():Get()
			local liRequested = math.ceil(lEActuallyNeeded / defines.economy.CONVOY_CONSTRUCTION_SIZE)
			viIC = BuildTransportOrEscort(liRequested, 5, true, liCost, viIC)
		end
	end

	return viIC
end
--vbConvoyOrEscort = is a boolean (true = escort, false = convoy)
function BuildTransportOrEscort(viNeeded, viMaxSerial, vbConvoyOrEscort, viICCost, viIC)
	while viNeeded > 0 do
		local liSerial = viMaxSerial
		if 	viNeeded < viMaxSerial then liSerial = viNeeded end
		viNeeded = viNeeded - liSerial

		if viIC > 0.1 then
			local loCommand = CConstructConvoyCommand(ProductionData.ministerTag, vbConvoyOrEscort, liSerial)
			ProductionData.ministerAI:Post(loCommand)
			viIC = viIC - viICCost
		end
	end

	return viIC
end


-- This function checks if the Unit numbers are above a set threshold and will set the productionweight for those affected to 0.
-- The productionweight of those affected gets split across the other categories
function CheckUnitAmounts(countryTag, isMajor, LandCountTotal, AirCountTotal, NavalCountTotal, laProdWeights)
	-- Utils.LUA_DEBUGOUT(tostring(countryTag) .. " - ".. tostring(isMajor) .. " - " .. LandCountTotal .. " - " .. AirCountTotal .. " - " .. NavalCountTotal)

	local limits = Utils.GetCountryUnitLimits(countryTag)
	if limits == nil then
		if isMajor then
			limits = {
				land = 1500,
				air = 1000,
				naval = 1000
			}
		else
			limits = {
				land = 500,
				air = 500,
				naval = 500
			}
		end
	end
	-- Utils.INSPECT_TABLE(limits)

	local LandCountHit = false
	local AirCountHit = false
	local NavalCountHit = false
	local HitCount = 0
	if LandCountTotal > limits.land then
		LandCountHit = true
		HitCount = HitCount + 1
	end
	if AirCountTotal > limits.air then
		AirCountHit = true
		HitCount = HitCount + 1
	end
	if NavalCountTotal > limits.naval then
		NavalCountHit = true
		HitCount = HitCount + 1
	end
	if HitCount == 1 then
		if LandCountHit == true then
			laProdWeights[2] = laProdWeights[2] + (laProdWeights[1] / 2)
			laProdWeights[3] = laProdWeights[3] + (laProdWeights[1] / 2)
			laProdWeights[1] = 0
		elseif AirCountHit == true then
			laProdWeights[1] = laProdWeights[1] + (laProdWeights[2] / 2)
			laProdWeights[3] = laProdWeights[3] + (laProdWeights[2] / 2)
			laProdWeights[2] = 0
		elseif NavalCountHit == true then
			laProdWeights[2] = laProdWeights[2] + (laProdWeights[3] / 2)
			laProdWeights[1] = laProdWeights[1] + (laProdWeights[3] / 2)
			laProdWeights[3] = 0
		end
	elseif HitCount == 2 then
		if LandCountHit == true and AirCountHit == true then
			laProdWeights[3] = laProdWeights[1] + laProdWeights[2] + laProdWeights[3]
			laProdWeights[1] = 0
			laProdWeights[2] = 0
		elseif LandCountHit == true and NavalCountHit == true then
			laProdWeights[2] = laProdWeights[1] + laProdWeights[2] + laProdWeights[3]
			laProdWeights[1] = 0
			laProdWeights[2] = 0
		elseif AirCountHit == true and NavalCountHit == true then
			laProdWeights[1] = laProdWeights[1] + laProdWeights[2] + laProdWeights[3]
			laProdWeights[2] = 0
			laProdWeights[3] = 0
		end
	elseif HitCount == 3 then
		laProdWeights[1] = 0
		laProdWeights[2] = 0
		laProdWeights[3] = 0
		laProdWeights[4] = laProdWeights[4]
	end
	return laProdWeights
end

G_LendLeaseMultiplier = 0
function GetLendLeaseMultiplier()
	-- Utils.LUA_DEBUGOUT("G_LendLeaseMultiplier: " .. G_LendLeaseMultiplier)
	if G_LendLeaseMultiplier ~= 0 then
		return G_LendLeaseMultiplier
	else
		G_LendLeaseMultiplier = CCountryDataBase.GetTag("OMG"):GetCountry():GetVariables():GetVariable(CString("LendLeaseMultiplier")):Get()
		return 1 -- return 1 in case it hasn't been set yet (GetVariable returned 0); gets checked frequently, a few days with higher LL don't matter
	end
end