from pipeline.models import ParseRecord

_CONS_CATS = ["flask", "phial", "potion", "food", "oil", "rune"]

# CombatantInfo.gear[] steht in Ausruestungs-Reihenfolge; der Listen-Index = Slot.
# (3 = Hemd, 17 = Wappenrock/Fernkampf -> kein Meta-Wert, ignoriert.)
GEAR_SLOT_BY_INDEX = {
    0: "HEAD", 1: "NECK", 2: "SHOULDER", 4: "CHEST", 5: "WAIST", 6: "LEGS",
    7: "FEET", 8: "WRIST", 9: "HANDS", 10: "RING1", 11: "RING2",
    12: "TRINKET1", 13: "TRINKET2", 14: "BACK", 15: "MAINHAND", 16: "OFFHAND",
}


def _stat(event, *fields):
    # Melee/Ranged/Spell-Varianten sind identisch; max() ist robust gegen 0-Felder.
    return max(int(event.get(f) or 0) for f in fields)


def parse_combatant_info(event, class_id, spec_id, content, season):
    """Ein CombatantInfo-Event -> ParseRecord. Kapselt alle WCL-Struktur-Annahmen."""
    stats = {
        "haste": _stat(event, "hasteMelee", "hasteRanged", "hasteSpell"),
        "crit": _stat(event, "critMelee", "critRanged", "critSpell"),
        "mastery": int(event.get("mastery") or 0),
        "vers": _stat(event, "versatilityDamageDone"),
    }

    gear = []
    for idx, g in enumerate(event.get("gear") or []):
        slot = GEAR_SLOT_BY_INDEX.get(idx)
        item_id = int((g or {}).get("id") or 0)
        if not slot or not item_id:
            continue
        gear.append({
            "slot": slot,
            "item_id": item_id,
            "item_level": int(g.get("itemLevel") or 0),
            "enchant_id": int(g.get("permanentEnchant") or 0),
            "gems": [int(gem.get("id")) for gem in (g.get("gems") or []) if gem.get("id")],
            # bonusIDs kodieren Upgrade-Track/Ilvl/Sockel -> ohne sie rendert der Client die Grundform.
            "bonus_ids": [int(b) for b in (g.get("bonusIDs") or [])],
        })

    consumables = {c: None for c in _CONS_CATS}
    whitelist = season.get("CONSUMABLE_SPELL_TO_ITEM", {})
    for aura in event.get("auras") or []:
        info = whitelist.get(aura.get("ability"))
        if info and consumables.get(info["cat"]) is None:
            consumables[info["cat"]] = info["item"]

    return ParseRecord(
        class_id=class_id, spec_id=spec_id, content=content, stats=stats,
        gear=gear, consumables=consumables,
    )
