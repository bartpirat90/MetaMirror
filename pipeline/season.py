# Season-abhaengige, von Hand gepflegte Daten. Zu jedem Patch/Season pruefen.
SEASON_NAME = "TWW-S-TBD"      # sichtbar in der Datentabelle; zu Season-Start setzen

# Rating pro 1 % auf Maximalstufe. Crit/Haste/Vers teilen sich den Wert.
# Mastery: rating_per_pct["mastery"] = Rating pro 1 Mastery-Punkt; die %-Wirkung
# skaliert zusaetzlich mit dem spec-spezifischen Faktor MASTERY_COEFF.
RATING_PER_PCT = {"haste": 700.0, "crit": 700.0, "vers": 780.0, "mastery": 700.0}

# Mastery-%-Faktor je specID (1 Mastery-Punkt => COEFF % Effekt). Zu Season-Start pruefen.
MASTERY_COEFF = {}   # z.B. {71: 1.6, 64: 1.0}; fehlt ein Spec -> Fallback 1.0

# WCL-Konfiguration je Content. Zu Season-Start setzen.
RAID_ENCOUNTER_IDS = []          # Liste der Mythic-Raid-Encounter-IDs der aktuellen Season
RAID_DIFFICULTY = 5              # 5 = Mythic in WCL
MPLUS_ZONE_ID = None             # WCL-Zone-ID fuer M+ der Season
MPLUS_MIN_KEYSTONE = None        # optionaler Mindest-Keystone-Level-Filter

# Consumable-Aura (Spell-ID) -> Item-ID. Nur diese Auren zaehlen als Verbrauchsgut.
CONSUMABLE_SPELL_TO_ITEM = {}    # {spellID: {"cat": "flask"|"phial"|"potion"|"food"|"oil"|"rune", "item": itemID}}

SAMPLE_TARGET = 50               # angestrebte Parses pro Spec x Content
