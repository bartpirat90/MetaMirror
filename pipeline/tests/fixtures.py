# Realer CombatantInfo-'data'-Block (gekuerzt), wie ihn die WCL-API liefert.
# Struktur 2026-08-31 gegen echte Antworten verifiziert.
COMBATANT_INFO = {
    "specID": 262, "sourceID": 25,
    "critMelee": 1021, "critRanged": 1021, "critSpell": 1021,
    "hasteMelee": 734, "hasteRanged": 734, "hasteSpell": 734,
    "mastery": 936,
    "versatilityDamageDone": 203, "versatilityDamageReduction": 203,
    "gear": [
        {"id": 271483, "itemLevel": 311, "permanentEnchant": 7961, "bonusIDs": [6652]},   # 0 HEAD
        {"id": 268265, "itemLevel": 308, "bonusIDs": [6652, 13668],                        # 1 NECK
         "gems": [{"id": 240983}, {"id": 240908}]},
        {"id": 0},                                                                        # 2 leer -> skip
    ],
    "auras": [
        {"ability": 1235108, "name": "Flask of the Magisters"},
        {"ability": 1285644, "name": "Hearty Well Fed"},
        {"ability": 6673, "name": "Battle Shout"},
    ],
    "talentTree": [
        {"id": 101844, "rank": 1, "nodeID": 80978},
        {"id": 101850, "rank": 1, "nodeID": 80981},
    ],
}
