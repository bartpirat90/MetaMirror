from dataclasses import dataclass, field
from typing import Optional


@dataclass
class ParseRecord:
    """Eine ausgewertete Top-Parse eines Spielers. Grenze zwischen fetch.py und aggregate.py."""
    class_id: int
    spec_id: int
    content: str                    # "mythicplus" | "raid"
    stats: dict                     # {"haste": rating_int, "crit": .., "mastery": .., "vers": ..}
    talent_import: str              # Blizzard-Export-String, falls vorhanden, sonst ""
    talent_sig: str                 # stabile Signatur der Talentauswahl (Gruppierungsschluessel)
    gear: list                      # [{"slot": "HEAD", "item_id": int, "enchant_id": int, "gems": [int]}, ..]
    consumables: dict               # {"flask": itemID|None, "phial": .., "potion": .., "food": .., "oil": .., "rune": ..}


@dataclass
class AggregatedSpec:
    """Aggregiertes Ergebnis pro Spec x Content — entspricht 1:1 dem Lua-Datenvertrag."""
    sample_size: int
    stats: list                     # [{"key": "haste", "pct": float}, ..] absteigend nach pct
    talents: list                   # [{"importString": str, "usagePct": int}]
    gear: list                      # [{"slot": str, "itemID": int, "name": str}]
    gems: list                      # [{"slot": str, "itemID": int, "name": str}]
    enchants: list                  # [{"slot": str, "id": int, "name": str}]
    consumables: dict               # {"flask": itemID, ...} (nur belegte Keys)
