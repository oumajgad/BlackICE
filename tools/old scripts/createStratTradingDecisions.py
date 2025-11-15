bugged_countries = ["PAN", "PHI"] # Skip those because they produce broken decisions (the game just stops reading the file after their events)
countryTags = [
    "AFG",  "ALB",    "ARG",  "___",    "AST",  "AUS",    "___",  "BBU",
    "BEL",  "BHU",    "___",  "___",    "BOL",  "BRA",    "BUL",  "CAN",
    "CGX",  "CHC",    "CHI",  "CHL",    "COL",  "COS",    "CRO",  "CSX",
    "CUB",  "CXB",    "CYN",  "CYP",    "CZE",  "___",    "DEN",  "___",
    "DOM",  "ECU",    "EGY",  "ENG",    "EST",  "ETH",    "FIN",  "FRA",
    "___",  "GER",    "GRE",  "GUA",    "___",  "HAI",    "HOL",  "HON",
    "HUN",  "ICL",    "IDC",  "IND",    "INO",  "IRE",    "IRQ",  "ISR",
    "ITA",  "JAP",    "JOR",  "KOR",    "___",  "LAT",    "LEB",  "LIB",
    "LIT",  "LUX",    "___",  "MAN",    "MEN",  "MEX",    "MON",  "MTA",
    "___",  "NEP",    "NIC",  "NJG",    "NOR",  "NZL",    "OMG",  "OMN",
    "PAK",  "PAL",    "PAN",  "PAP",    "PAR",  "PER",    "PHI",  "POL",
    "POR",  "___",    "PRU",  "REB",    "RKK",  "RKM",    "RKO",  "RKU",
    "ROM",  "RSI",    "RUR",  "SAF",    "SAL",  "SAU",    "SCH",  "___",
    "SIA",  "SIK",    "SLO",  "___",    "SOM",  "SOV",    "SPA",  "SPR",
    "SUD",  "___",    "SWE",  "SYR",    "TAN",  "TIB",    "___",  "TUR",
    "___",  "URU",    "USA",  "VEN",    "VIC",  "YEM",    "YUG"
]
resources = {
    "chromite": "13308",
    "aluminium": "13302",
    "rubber": "13304",
    "tungsten": "13306",
    "nickel": "13310",
    "copper": "13312",
    "zinc": "13300",
    "manganese": "13314",
    "molybdenum": "13316"
}
def make_header(resource: str) -> str:
    fileHeaderTemplateLines = [
        "###########################################",
        "{resource}",
        "###########################################",
        "diplomatic_decisions = {"
    ]
    secondLine = fileHeaderTemplateLines[1].format(resource=resource.upper())
    firstLineLength = len(fileHeaderTemplateLines[0])
    resLength = len(secondLine)
    remainingLength = firstLineLength - resLength - 6
    newLine = "###" + (" " * int(remainingLength/2)) + secondLine + (" " * int(remainingLength/2)) + "###"
    new = fileHeaderTemplateLines[0] + "\n" + newLine + "\n" + fileHeaderTemplateLines[2] + "\n" + fileHeaderTemplateLines[3]
    return new


decisionTemplate = """
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
                    which = {resource}_building_count
                    value = 1
                }}
            }}
        }}
        allow = {{
            money = 2000
            relation = {{
                who = {tag}
                value = -50
            }}
            not = {{
                war_with = {tag}
                tag = {tag}
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
        }}
        effect = {{
            {tag} = {{
                country_event = {event_id}
                add_country_modifier = {{
                    name = "trade_cooldown"
                    duration = 2
                }}
            }}
            set_variable = {{
                which = pending_trade_wants_to_buy_from
                value = {tag_index}
            }}
            add_country_modifier = {{
                name = "trade_cooldown"
                duration = 2
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

def make_decisions():
    for resource in resources:
        chunks = []
        fileName = f"resource_trading_{resource}.txt"
        fileHeader = make_header(resource)
        # print(fileHeader)
        chunks.append(fileHeader)
        i = 0
        for tag in countryTags:
            i += 1  # start at 1!
            if tag in bugged_countries or tag == "___":
                continue
            decision = decisionTemplate.format(tag=tag, tag_index=i,resource=resource, event_id=resources[resource])
            # print(decision)
            chunks.append(decision)

        with open(file=fileName, encoding="ISO-8859-1", mode="w") as f:
            chunks.append("}")
            f.writelines(chunks)

make_decisions()