# Season-abhaengige, von Hand gepflegte Daten. Zu jedem Patch/Season pruefen.
# Stand: Midnight (Expansion 7), via WCL-API verifiziert 2026-08-31.
SEASON_NAME = "Midnight-S2"

# --- Rating -> Prozent (KALIBRIERUNG NOETIG) --------------------------------
# Midnight hat die Sekundaerwerte gesquisht -> diese Konstanten sind PLATZHALTER
# und liefern noch KEINE korrekten Prozente. Kalibrieren mit einem bekannten
# Datenpunkt (eigener Char: GetCombatRating(stat) vs. GetCritChance() usw.):
# rating_per_pct = rating / prozent. Mastery zusaetzlich * MASTERY_COEFF[specID].
RATING_PER_PCT = {"haste": 35.0, "crit": 35.0, "vers": 40.0, "mastery": 35.0}
MASTERY_COEFF = {}   # {specID: faktor}; fehlt -> 1.0

# --- WCL-Content-IDs (verifiziert) ------------------------------------------
RAID_ZONE_ID = 53                # "The Venomous Abyss"
RAID_DIFFICULTY = 5              # 5 = Mythic
RAID_ENCOUNTER_IDS = [3470, 3445, 3455, 3497, 3420, 3421, 3429, 3492, 3379]

MPLUS_ZONE_ID = 55               # "Mythic+ Season 2"
MPLUS_DIFFICULTY = 10            # 10 = Dungeon
MPLUS_ENCOUNTER_IDS = [12993, 12825, 61762, 12813, 112521, 61877, 12859, 12923]

# --- Consumable-Buff (aura.ability = Spell-ID) -> Kategorie + Item-ID --------
# Aus CombatantInfo-Auren; die Item-ID (fuer klickbare Links) muss ergaenzt werden
# (z.B. via Wowhead). Beispiel aus echten Logs: "Flask of the Magisters" = Buff 1235108.
# Format: {spellID: {"cat": "flask"|"phial"|"potion"|"food"|"oil"|"rune", "item": itemID}}
CONSUMABLE_SPELL_TO_ITEM = {}

# Parses pro Spec x Content. Kosten ~2.6 WCL-Punkte/Parse; Limit 3600 Punkte/Stunde.
# 15 -> ganzer Lauf (39 Specs x 2 Modi) bleibt unter einer Stunde, kein Rate-Limit-Abbruch.
# Hoeher (Richtung 50) erst, wenn der Client stundenweise pausieren kann (offen).
SAMPLE_TARGET = 15
