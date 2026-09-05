from dataclasses import dataclass

STAT_KEYS = ["haste", "crit", "mastery", "vers"]
CONTENTS = ["mythicplus", "raid"]

# Heiler-Specs -> Ranking-Metrik "hps" (alle anderen "dps"), damit die Rangliste
# ueberhaupt Eintraege liefert. specIDs: Disc/HolyPr, HolyPal, RestoSham, Mistweaver,
# RestoDruid, Preservation.
HEALER_SPECS = {256, 257, 65, 264, 270, 105, 1468}



@dataclass(frozen=True)
class Spec:
    class_id: int
    spec_id: int
    class_name: str   # CamelCase, wird fuer bloodmallet/SimulationCraft zu snake_case
    spec_name: str    # CamelCase, dito


SPECS = [
    Spec(1, 71, "Warrior", "Arms"), Spec(1, 72, "Warrior", "Fury"), Spec(1, 73, "Warrior", "Protection"),
    Spec(2, 65, "Paladin", "Holy"), Spec(2, 66, "Paladin", "Protection"), Spec(2, 70, "Paladin", "Retribution"),
    Spec(3, 253, "Hunter", "BeastMastery"), Spec(3, 254, "Hunter", "Marksmanship"), Spec(3, 255, "Hunter", "Survival"),
    Spec(4, 259, "Rogue", "Assassination"), Spec(4, 260, "Rogue", "Outlaw"), Spec(4, 261, "Rogue", "Subtlety"),
    Spec(5, 256, "Priest", "Discipline"), Spec(5, 257, "Priest", "Holy"), Spec(5, 258, "Priest", "Shadow"),
    Spec(6, 250, "DeathKnight", "Blood"), Spec(6, 251, "DeathKnight", "Frost"), Spec(6, 252, "DeathKnight", "Unholy"),
    Spec(7, 262, "Shaman", "Elemental"), Spec(7, 263, "Shaman", "Enhancement"), Spec(7, 264, "Shaman", "Restoration"),
    Spec(8, 62, "Mage", "Arcane"), Spec(8, 63, "Mage", "Fire"), Spec(8, 64, "Mage", "Frost"),
    Spec(9, 265, "Warlock", "Affliction"), Spec(9, 266, "Warlock", "Demonology"), Spec(9, 267, "Warlock", "Destruction"),
    Spec(10, 268, "Monk", "Brewmaster"), Spec(10, 269, "Monk", "Windwalker"), Spec(10, 270, "Monk", "Mistweaver"),
    Spec(11, 102, "Druid", "Balance"), Spec(11, 103, "Druid", "Feral"), Spec(11, 104, "Druid", "Guardian"), Spec(11, 105, "Druid", "Restoration"),
    Spec(12, 577, "DemonHunter", "Havoc"), Spec(12, 581, "DemonHunter", "Vengeance"),
    Spec(13, 1467, "Evoker", "Devastation"), Spec(13, 1468, "Evoker", "Preservation"), Spec(13, 1473, "Evoker", "Augmentation"),
]
