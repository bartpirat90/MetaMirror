from pipeline.models import ParseRecord
from pipeline.aggregate import trinket_view, build_trinket_table


def _rec(spec_id, content, t1, t2, il1=334, il2=334, b1=None, b2=None):
    # item_level default = aktuelles Season-2-Niveau (>= Floor), damit die Nutzungs-Tests
    # nicht am Vorsaison-Filter haengenbleiben. bonus_ids default = [12854] (Myth 6/6 = 334,
    # realistisch fuer Top-Parses) -> Nutzungs-Tests laufen ueber den Track-Bonus-Pfad, der
    # Ilvl-Ausreisser-Schutz greift dort nicht. Fuer Filter-Tests b1/b2 explizit setzen.
    b1 = [12854] if b1 is None else b1
    b2 = [12854] if b2 is None else b2
    gear = [
        {"slot": "TRINKET1", "item_id": t1, "item_level": il1, "enchant_id": 0, "gems": [], "bonus_ids": b1},
        {"slot": "TRINKET2", "item_id": t2, "item_level": il2, "enchant_id": 0, "gems": [], "bonus_ids": b2},
    ]
    return ParseRecord(class_id=9, spec_id=spec_id, content=content, stats={},
                       gear=gear, consumables={})


def _name(i):
    return f"item:{i}"


def test_trinket_view_pools_both_slots_and_tiers_by_usage():
    # 900 taucht in fast jedem Loadout auf (Top), 901 haeufig, 999 einmalig.
    recs = [
        _rec(266, "raid", 900, 901),
        _rec(266, "raid", 900, 901),
        _rec(266, "raid", 900, 999),
    ]
    view = trinket_view(recs, _name)
    by_id = {e["itemID"]: e["tier"] for e in view}
    # Counts: 900:3 (Top -> S), 901:2 (0.66 -> A), 999:1 (0.33 -> B)
    assert by_id[900] == "S"
    assert by_id[901] == "A"
    assert by_id[999] == "B"
    # nach Haeufigkeit sortiert
    assert view[0]["itemID"] == 900
    assert view[0]["name"] == "item:900"


def test_trinket_view_empty_without_trinkets():
    assert trinket_view([], _name) == []


def test_trinket_view_drops_previous_season_by_ilvl():
    # 900 = aktuelles S2-Trinket (Default-Track-Bonus 334). 700 = Season-1-Drop ohne
    # Track-Bonus, das NIEMAND ueber 298 traegt (nicht auf S2 hebbar) -> muss verschwinden.
    recs = [
        _rec(266, "raid", 900, 700, il1=334, il2=298, b2=[]),
        _rec(266, "raid", 900, 700, il1=331, il2=298, b2=[]),
    ]
    ids = {e["itemID"] for e in trinket_view(recs, _name)}
    assert 900 in ids and 700 not in ids


def test_trinket_view_keeps_upscaled_evergreen():
    # 193757 = altes Effekt-Trinket ohne Track-Bonus, das in ZWEI Parses auf S2-Ilvl (334)
    # getragen wird (der dritte traegt es niedrig, Vorsaison) -> bleibt, weil mindestens
    # TRINKET_MIN_LIFTABLE_PARSES (2) Parses es auf S2-Niveau zeigen (kein Ausreisser).
    recs = [
        _rec(266, "raid", 193757, 901, il1=298, il2=334, b1=[]),
        _rec(266, "raid", 193757, 901, il1=334, il2=334, b1=[]),
        _rec(266, "raid", 193757, 901, il1=334, il2=334, b1=[]),
    ]
    ids = {e["itemID"] for e in trinket_view(recs, _name)}
    assert 193757 in ids


def test_trinket_view_prev_season_marker_beats_ilvl():
    # 700 traegt trotz hohem Ilvl (334) in allen 3 Parses den Vorsaison-Marker (13654,
    # S1-Voidforged-Cap) -> zaehlt NIE als hebbar, egal wie hoch der Ilvl ist.
    recs = [
        _rec(266, "raid", 900, 700, il2=334, b2=[13654]),
        _rec(266, "raid", 900, 700, il2=334, b2=[13654]),
        _rec(266, "raid", 900, 700, il2=334, b2=[13654]),
    ]
    ids = {e["itemID"] for e in trinket_view(recs, _name)}
    assert 700 not in ids


def test_trinket_view_track_bonus_keeps_item_below_floor():
    # 901 traegt in einem einzigen Parse Hero 5/6 (Bonus 12845, Ilvl 318 -- unter dem
    # Floor 320), ist damit aber ein exakter Positivbeweis fuer S2 und bleibt trotzdem,
    # ohne dass ein zweiter Parse noetig waere (anders als der reine Ilvl-Pfad).
    recs = [
        _rec(266, "raid", 900, 901, il2=318, b2=[12845]),
    ]
    ids = {e["itemID"] for e in trinket_view(recs, _name)}
    assert 901 in ids


def test_trinket_view_ilvl_path_needs_min_parses():
    # Ohne Track-Bonus: ein einzelner hoher Ilvl-Parse (331) neben einem alten Parse
    # (298) reicht NICHT (Ausreisser-Schutz) -> 158374 faellt raus.
    recs_single = [
        _rec(266, "raid", 158374, 900, il1=331, b1=[]),
        _rec(266, "raid", 158374, 900, il1=298, b1=[]),
    ]
    ids_single = {e["itemID"] for e in trinket_view(recs_single, _name)}
    assert 158374 not in ids_single

    # Zwei Parses bei 331 (>= Floor, kein Track-Bonus noetig) -> bleibt.
    recs_double = [
        _rec(266, "raid", 158374, 900, il1=331, b1=[]),
        _rec(266, "raid", 158374, 900, il1=331, b1=[]),
    ]
    ids_double = {e["itemID"] for e in trinket_view(recs_double, _name)}
    assert 158374 in ids_double


def test_trinket_view_ranking_counts_all_usages():
    # 700 kommt in 3 Parses vor (2x Track-Bonus, 1x Vorsaison-Marker) -> bleibt UND
    # zaehlt alle 3 Vorkommen fuers Ranking (der Filter entscheidet nur bleiben/raus,
    # nicht wie viele Vorkommen gezaehlt werden). 900 kommt nur 1x vor -> 700 landet
    # dank hoeherem Count in einem hoeheren Tier als 900.
    recs = [
        _rec(266, "raid", 700, 900, b1=[12854]),
        _rec(266, "raid", 700, 901, b1=[12854]),
        _rec(266, "raid", 700, 902, b1=[13654]),
    ]
    view = trinket_view(recs, _name)
    by_id = {e["itemID"]: e for e in view}
    assert 700 in by_id
    assert by_id[700]["tier"] == "S"   # Top-Count (3) -> S
    assert by_id[900]["tier"] != "S"   # Count 1 < Top -> niedrigerer Tier


def test_build_trinket_table_splits_content_and_overall():
    recs = [
        _rec(266, "raid", 900, 901),
        _rec(266, "raid", 900, 901),
        _rec(266, "mythicplus", 800, 801),
        _rec(266, "mythicplus", 800, 802),
        _rec(71, "raid", 500, 501),
    ]
    table = build_trinket_table(recs, _name)
    demo = table[266]
    raid_ids = {e["itemID"] for e in demo["raid"]}
    dung_ids = {e["itemID"] for e in demo["dungeon"]}
    overall_ids = {e["itemID"] for e in demo["overall"]}
    assert raid_ids == {900, 901}
    assert dung_ids == {800, 801, 802}
    assert overall_ids == {900, 901, 800, 801, 802}   # gepoolt
    assert 71 in table


def test_build_trinket_table_respects_only_specs():
    recs = [_rec(266, "raid", 900, 901), _rec(71, "raid", 500, 501)]
    table = build_trinket_table(recs, _name, only_specs={266})
    assert set(table.keys()) == {266}
