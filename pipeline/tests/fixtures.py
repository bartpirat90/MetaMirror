# Minimaler CombatantInfo-'data'-Block, wie fetch.parse_combatant_info ihn erwartet.
COMBATANT_INFO = {
    "specID": 71,
    "stats": {"Haste": {"rating": 7000}, "Crit": {"rating": 5600},
              "Mastery": {"rating": 4200}, "Versatility": {"rating": 3120}},
    "talentTree": [{"id": 111, "rank": 1}, {"id": 222, "rank": 2}],
    "gear": [
        {"slot": 0, "id": 21001, "permanentEnchant": 0, "gems": []},
        {"slot": 15, "id": 21050, "permanentEnchant": 7001, "gems": [90001]},
    ],
    "auras": [{"ability": 431971}, {"ability": 999999}],  # 1. = Flask (Whitelist), 2. = irrelevant
}

SLOT_NAME = {0: "HEAD", 15: "MAINHAND"}
