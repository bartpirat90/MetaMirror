from dataclasses import dataclass


@dataclass
class AggregatedSpec:
    """Aggregiertes Ergebnis pro Spec x Content — entspricht 1:1 dem Lua-Datenvertrag."""
    sample_size: int
    stats: list                     # [{"key": "haste", "rating": int}, ..] absteigend nach rating
    gear: list                      # [{"slot": str, "itemID": int, "itemLevel": int, "bonusIDs": [int], "name": str}]
    gems: list                      # [{"slot": str, "itemID": int, "name": str}]
    enchants: list                  # [{"slot": str, "id": int, "itemID": int, "name": str}]
    consumables: dict               # {"flask": itemID, ...} (nur belegte Keys)
