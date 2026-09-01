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
    gear: list                      # [{"slot": "HEAD", "item_id": int, "item_level": int, "enchant_id": int, "gems": [int], "bonus_ids": [int]}, ..]
    consumables: dict               # {"flask": itemID|None, "phial": .., "potion": .., "food": .., "oil": .., "rune": ..}
    talent_nodes: list = field(default_factory=list)
    # [{"nodeID": int, "entryID": int, "rank": int}, ..] -> das Addon baut daraus in-game
    # den Import-String (nodeID+entryID+rank = alles, was der Serialisierer braucht).


@dataclass
class AggregatedSpec:
    """Aggregiertes Ergebnis pro Spec x Content — entspricht 1:1 dem Lua-Datenvertrag."""
    sample_size: int
    stats: list                     # [{"key": "haste", "rating": int}, ..] absteigend nach rating
    talents: list                   # [{"importString": str, "usagePct": int, "nodes": [{"nodeID","entryID","rank"}]}]
    gear: list                      # [{"slot": str, "itemID": int, "itemLevel": int, "bonusIDs": [int], "name": str}]
    gems: list                      # [{"slot": str, "itemID": int, "name": str}]
    enchants: list                  # [{"slot": str, "id": int, "itemID": int, "name": str}]
    consumables: dict               # {"flask": itemID, ...} (nur belegte Keys)
