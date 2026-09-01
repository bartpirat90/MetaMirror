from dataclasses import dataclass


@dataclass
class ParseRecord:
    """Eine ausgewertete Top-Parse eines Spielers. Grenze zwischen fetch.py und aggregate.py."""
    class_id: int
    spec_id: int
    content: str                    # "mythicplus" | "raid"
    stats: dict                     # {"haste": rating_int, "crit": .., "mastery": .., "vers": ..}
    gear: list                      # [{"slot": "HEAD", "item_id": int, "item_level": int, "enchant_id": int, "gems": [int], "bonus_ids": [int]}, ..]
    consumables: dict               # {"flask": itemID|None, "phial": .., "potion": .., "food": .., "oil": .., "rune": ..}


@dataclass
class AggregatedSpec:
    """Aggregiertes Ergebnis pro Spec x Content — entspricht 1:1 dem Lua-Datenvertrag."""
    sample_size: int
    stats: list                     # [{"key": "haste", "rating": int}, ..] absteigend nach rating
    gear: list                      # [{"slot": str, "itemID": int, "itemLevel": int, "bonusIDs": [int], "name": str}]
    gems: list                      # [{"slot": str, "itemID": int, "name": str}]
    enchants: list                  # [{"slot": str, "id": int, "itemID": int, "name": str}]
    consumables: dict               # {"flask": itemID, ...} (nur belegte Keys)
