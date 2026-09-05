# Season-abhaengige, von Hand gepflegte Daten. Zu jedem Patch/Season pruefen.
# Stand: Midnight (Expansion 7).
SEASON_NAME = "Midnight-S2"

# --- Trinket-Season-Filter (Bloodmallet listet ALLE Seasons) ----------------
# Bloodmallet simuliert jedes Trinket bei seinem hoechsten Item-Level; dieses Cap
# trennt die Seasons sauber. In Midnight-S2 (via Demonology-Sim 2026-09-01 geprueft):
#   Season 2 (aktuell):  331 / 334 / 344   <- behalten
#   aktuelle PvP-Season:            315     <- raus (PvE-Meta-Addon)
#   Season 1 (veraltet):     292 / 298      <- raus
# Ein Trinket bleibt nur, wenn sein Sim-Cap >= diesem Floor liegt (auf S2-Niveau).
# Uralte Effekt-Trinkets, die Bloodmallet SELBST auf 334 hochskaliert (z.B. Rubin-
# welpenschale), liegen damit ueber dem Floor und bleiben -> genau "auf S2 gehoben".
# ZU JEDER SEASON PRUEFEN: knapp unter das neue Season-Cap setzen (hier zwischen 315
# und 331), damit Vorsaison + PvP herausfallen, aber alle S2-Difficulties bleiben.
TRINKET_MIN_ILVL = 320

# --- Trinket-Season-Erkennung ueber Bonus-IDs (praeziser als Ilvl) ---------------
# Aus 1226 Gear-Eintraegen (2026-09-02) abgeleitet: jede dieser
# Bonus-IDs kommt AUSSCHLIESSLICH mit genau einem Item-Level vor -> Upgrade-Track-Stufe.
#   Hero-Track : 12843=311 (3/6)  12844=315 (4/6)  12845=318 (5/6)  12846=321 (6/6)
#   Myth-Track : 12849=318 (1/6)  12850=321  12851=324  12852=328  12853=331  12854=334
# Champion-Track und Hero 1/6-2/6 sind in den Daten zu selten belegt -> nicht geraten;
# solche Items laufen ueber den Ilvl-Pfad (TRINKET_MIN_ILVL + Ausreisser-Schutz).
# Ein Gear-Eintrag mit Track-Bonus ist ein POSITIVBEWEIS fuer "aktuelle Season", auch
# wenn sein Ilvl unter dem Floor liegt (Hero 5/6 = 318).
TRINKET_CURRENT_TRACK_BONUS = frozenset({
    12843, 12844, 12845, 12846,                    # Hero 3/6 .. 6/6
    12849, 12850, 12851, 12852, 12853, 12854,      # Myth 1/6 .. 6/6
})
# Vorsaison-Marker: 13654 haengt an 25/26 der 298er-Items (S1-Voidforged-Cap) und an
# keinem einzigen S2-Item. Ein Eintrag mit diesem Bonus zaehlt NIE als hebbar.
TRINKET_PREV_SEASON_BONUS = frozenset({13654})
# ZU JEDER SEASON PRUEFEN: Track-Bonus-Familie und Vorsaison-Marker neu ableiten
# (Bonus-IDs, die an genau EIN Ilvl im dominanten Cluster gebunden sind, bzw. die
# exklusiv am isolierten Vorsaison-Cluster haengen).

# ---- Kuratierte Verbrauchsgueter -------------------------------------------
# Das Sim-Profil nennt Flask und Augment-Rune; Kampftrank, Speise und Waffenoel
# stehen dort nicht oder nicht in der Form, die ein Spieler kaufen kann. Darum
# einmal pro Season kuratiert (IDs via Wowhead, im Spiel per Shift-Klick
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

# ---- SimC-Verbrauchsgueter-Slugs -> (Kategorie, itemID) --------------------
# Die SimulationCraft-Profile (profiles/MID2/*.simc) nennen Verbrauchsgueter als Slug
# (z.B. "flask_of_the_shattered_sun_2"); der Rang-Suffix "_<n>" wird vor dem Lookup
# abgeschnitten (simc_profile.consumable_item_ids). IDs identisch zu den oben bereits
# verifizierten Item-IDs (CONSUMABLE_SPELL_TO_ITEM / CURATED_OIL_BY_STAT) -- keine neuen
# erfunden, nur der Slug->ID-Pfad ergaenzt.
SIMC_CONSUMABLE_ITEMS = {
    "flask_of_the_shattered_sun": ("flask", 241326),
    "flask_of_the_magisters": ("flask", 241322),
    "flask_of_the_blood_knights": ("flask", 241325),
    "void_touched_augment_rune": ("rune", 259085),
    # Das DK-Profil (MID2) schreibt nur "augmentation=void_touched" -- gleiches Item.
    "void_touched": ("rune", 259085),
    "ethereal_augment_rune": ("rune", 243191),
    "thalassian_phoenix_oil": ("oil", 243733),
}

