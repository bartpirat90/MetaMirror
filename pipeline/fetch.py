from pipeline.models import ParseRecord

_STAT_FIELD = {"haste": "Haste", "crit": "Crit", "mastery": "Mastery", "vers": "Versatility"}
_CONS_CATS = ["flask", "phial", "potion", "food", "oil", "rune"]

# WoW-inventoryType (CombatantInfo gear[].slot) -> Vertrags-Slotname.
DEFAULT_SLOT_NAME = {
    0: "HEAD", 1: "NECK", 2: "SHOULDER", 4: "CHEST", 5: "WAIST", 6: "LEGS",
    7: "FEET", 8: "WRIST", 9: "HANDS", 10: "RING1", 11: "RING2",
    12: "TRINKET1", 13: "TRINKET2", 14: "BACK", 15: "MAINHAND", 16: "OFFHAND",
}


def parse_combatant_info(data, class_id, spec_id, content, season):
    """WCL-CombatantInfo-'data' -> ParseRecord. Kapselt alle Struktur-Annahmen."""
    slot_name = season.get("SLOT_NAME", DEFAULT_SLOT_NAME)
    stats = {}
    src = data.get("stats", {})
    for key, field_name in _STAT_FIELD.items():
        entry = src.get(field_name) or {}
        stats[key] = int(entry.get("rating", 0))

    gear = []
    for g in data.get("gear", []):
        slot = slot_name.get(g.get("slot"))
        if not slot or not g.get("id"):
            continue
        gear.append({
            "slot": slot, "item_id": int(g["id"]),
            "enchant_id": int(g.get("permanentEnchant") or 0),
            "gems": [int(x) for x in (g.get("gems") or []) if x],
        })

    consumables = {c: None for c in _CONS_CATS}
    whitelist = season.get("CONSUMABLE_SPELL_TO_ITEM", {})
    for aura in data.get("auras", []):
        info = whitelist.get(aura.get("ability"))
        if info and consumables.get(info["cat"]) is None:
            consumables[info["cat"]] = info["item"]

    tree = data.get("talentTree") or []
    talent_sig = "|".join(f"{n['id']}:{n.get('rank', 1)}" for n in tree)

    return ParseRecord(
        class_id=class_id, spec_id=spec_id, content=content, stats=stats,
        talent_import=str(data.get("talentImportString", "")),
        talent_sig=talent_sig, gear=gear, consumables=consumables,
    )
