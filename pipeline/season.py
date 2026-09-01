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
# Quelle: CombatantInfo-Auren realer Top-Parses (2026-08-31 verifiziert). Nur Buffs,
# die zum Pull als *dauerhafte* Aura anliegen, sind hier ableitbar -> zuverlaessig
# befuellbar: flask, rune (und das generische Food-Aura). NICHT ableitbar:
#   - potion: Kampftrank wird erst im Kampf gezuendet, steht nicht im Pull-Snapshot
#   - phial:  in Midnight durch Flasks abgeloest (keine Phiolen in den Logs)
#   - oil:    keine Waffenoel-Aura in den Stichproben
#   - food:   das Aura ("Hearty Well Fed") ist generisch; Festmahl vs. Einzelportion
#             ist daraus nicht unterscheidbar
# potion/oil/food werden darum unten kuratiert (apply_curated_consumables) und
# ueberlagern das aus den Logs Abgeleitete. flask/rune bleiben log-abgeleitet.
# Format: {spellID: {"cat": "flask"|"phial"|"potion"|"food"|"oil"|"rune", "item": itemID}}
# Buff-IDs sind die in den Logs beobachteten (teils PTR-Varianten); sie zeigen aber
# eindeutig auf das jeweilige Live-Item. Item-IDs via Wowhead nachgeschlagen.
CONSUMABLE_SPELL_TO_ITEM = {
    # Flasks (jeder Buff = genau ein Flask-Item)
    1235108: {"cat": "flask", "item": 241322},   # Flask of the Magisters
    1235110: {"cat": "flask", "item": 241325},   # Flask of the Blood Knights (Tempo)
    1235111: {"cat": "flask", "item": 241326},   # Flask of the Shattered Sun
    # Augment Runes (Void-Touched ist die aktuelle, +25 Primaerwert; Ethereal aelter)
    1264426: {"cat": "rune", "item": 259085},    # Void-Touched Augment Rune
    1234969: {"cat": "rune", "item": 243191},    # Ethereal Augment Rune
    # Food: "Hearty Well Fed" ist ein generischer Buff vieler Speisen; die genaue
    # Speise ist aus dem Buff nicht ableitbar -> wird unten kuratiert ueberlagert.
    1285644: {"cat": "food", "item": 222781},    # Hearty Feast of the Midnight Masquerade
}

# ---- Kuratierte, NICHT aus den Logs ableitbare Verbrauchsgueter -------------
# Kampftrank + Waffenoel stehen nicht im Pull-Snapshot, das Food-Aura ist generisch.
# Darum einmal pro Season kuratiert (IDs via Wowhead, im Spiel per Shift-Klick
# gegengeprueft). Food + Trank geben PRIMAERWERT -> fuer jede DPS-Spec brauchbar
# (universell). Das Oel (+Krit/Tempo) ist stat-/klassenabhaengig -> nur fuer
# Int-Caster hinterlegt; Melee (Agi/Str) nutzen eher Schleif-/Wetzsteine.
CURATED_FOOD   = 242275   # Koeniglicher Braten (+Primaerwert, im AH kaufbar)
CURATED_POTION = 241308   # Potenzial des Lichts (+140 Primaerwert, 30 Sek)
CURATED_OIL_BY_STAT = {
    "int": 243733,        # Thalassisches Phoenixoel (+Krit/Tempo) - Caster/Int
}

# specID -> Primaerstat. Bestimmt die statabhaengige Empfehlung (aktuell nur Oel).
SPEC_PRIMARY_STAT = {
    71: "str", 72: "str", 73: "str",                       # Warrior
    65: "int", 66: "str", 70: "str",                       # Paladin
    253: "agi", 254: "agi", 255: "agi",                    # Hunter
    259: "agi", 260: "agi", 261: "agi",                    # Rogue
    256: "int", 257: "int", 258: "int",                    # Priest
    250: "str", 251: "str", 252: "str",                    # DeathKnight
    262: "int", 263: "agi", 264: "int",                    # Shaman
    62: "int", 63: "int", 64: "int",                       # Mage
    265: "int", 266: "int", 267: "int",                    # Warlock
    268: "agi", 269: "agi", 270: "int",                    # Monk
    102: "int", 103: "agi", 104: "agi", 105: "int",        # Druid
    577: "agi", 581: "agi",                                # DemonHunter
    1467: "int", 1468: "int", 1473: "int",                 # Evoker
}


def apply_curated_consumables(spec_id, cons):
    """Ueberlagert die aus den Logs abgeleiteten Verbrauchsgueter mit den kuratierten:
    Einzelportions-Food statt Gruppen-Festmahl, Kampftrank, ggf. Waffenoel (nur Int).
    flask/rune (verlaesslich aus den Logs) bleiben unangetastet. Idempotent."""
    out = dict(cons)
    out["food"] = CURATED_FOOD
    out["potion"] = CURATED_POTION
    oil = CURATED_OIL_BY_STAT.get(SPEC_PRIMARY_STAT.get(spec_id))
    if oil:
        out["oil"] = oil
    else:
        out.pop("oil", None)   # kein passendes Oel fuer diese Spec -> Zeile entfaellt
    return out

# permanentEnchant-ID (aus CombatantInfo/Logs) -> itemID der Verzauberungs-Rolle.
# Diese Rolle ist im AH suchbar (Shift-Klick auf den Item-Link). Die permanentEnchant-
# Nummern sind NICHT ueber Wowhead aufloesbar; darum einmal pro Season kuratiert:
# Enchant-Namen via `/mm dumpench` im Spiel auslesen -> Name -> itemID via Wowhead.
# Nicht gemappte IDs -> enchantItemID 0 (Addon zeigt dann keinen Item-Link).
ENCHANT_ITEM_BY_ID = {
    # Kopf (Enchant Helm - Empowered ...)
    7961: 243951,   # Empowered Hex of Leeching
    7991: 243981,   # Empowered Blessing of Speed
    8017: 244007,   # Empowered Rune of Avoidance
    # Schultern
    7973: 243963,   # Akil'zon's Swiftness
    8001: 243990,   # Amirdrassil's Grace
    8031: 244021,   # Silvermoon's Mending
    # Brust
    7987: 243977,   # Mark of the Worldsoul
    8013: 244003,   # Mark of the Magister
    # Waffe / Nebenhand
    7981: 243971,   # Jan'alai's Precision
    7983: 243973,   # Berserker's Rage
    8039: 244029,   # Acuity of the Ren'dorei
    8041: 244030,   # Arcane Mastery
    8689: 273072,   # Rite of the Hash'ey
    # Ringe
    7967: 243957,   # Eyes of the Eagle
    7969: 243959,   # Zul'jin's Mastery
    7997: 243987,   # Nature's Fury
    8025: 244015,   # Silvermoon's Alacrity (dt. "Inbrunst von Silbermond", Haste)
    8027: 244017,   # Silvermoon's Tenacity
    # Fuesse
    7963: 243953,   # Lynx's Dexterity
    7993: 243983,   # Shaladrassil's Roots
    8019: 244009,   # Farstrider's Hunt
    # Beine
    7935: 240133,   # Sunfire Silk Spellthread (dt. "Zauberfaden aus Sonnenfeuerseide", Int + Ausdauer)
    7937: 240155,   # Arcanoweave Spellthread (Int + 4% Mana)
    8159: 244641,   # Forest Hunter's Armor Kit (Bewegl./Staerke + Ausdauer)
    8163: 244643,   # Blood Knight's Armor Kit (Bewegl./Staerke + Ruestung)
    # Bewusst KEIN Item (kein AH-Kauf): 6222 (Handgelenk "Ruheraffung", Legacy/Beruf),
    #   6241/6245 (DK-Runenschmiede), 2841/5445 (alte/Beruf-Handschuhverz.),
    #   3368/3847 (Legacy-Waffenrunen).
}

# Parses pro Spec x Content. Kosten ~2.6 WCL-Punkte/Parse; Limit 3600 Punkte/Stunde.
# 15 -> ganzer Lauf (39 Specs x 2 Modi) bleibt unter einer Stunde, kein Rate-Limit-Abbruch.
# Hoeher (Richtung 50) erst, wenn der Client stundenweise pausieren kann (offen).
SAMPLE_TARGET = 15
