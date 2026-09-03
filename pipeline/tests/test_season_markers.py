from pipeline.models import ParseRecord
from pipeline.season_markers import (
    entries_from_records, bonus_levels, single_level_bonuses, check_markers,
)


def _rec(*items):
    gear = [{"slot": "TRINKET1" if i % 2 == 0 else "TRINKET2", "item_id": 1000 + i,
             "item_level": il, "enchant_id": 0, "gems": [], "bonus_ids": bs}
            for i, (il, bs) in enumerate(items)]
    return ParseRecord(class_id=9, spec_id=266, content="raid", stats={}, gear=gear,
                       consumables={})


# Abbild der Live-Verteilung: S2-Track-Stufen + Vorsaison-Rest bei 298 mit Marker 13654.
# Bewusst mit unteren Track-Stufen (Champion 292..) wie in einer breiten 50-Parse-Stichprobe.
S2 = ([(321, [6652, 12846])] * 20 + [(334, [6652, 12854])] * 8 + [(311, [12843])] * 6
      + [(315, [12844])] * 5 + [(318, [12845])] * 5 + [(331, [12853])] * 5
      + [(308, [6652])] * 5 + [(305, [6652])] * 5 + [(301, [6652])] * 5 + [(292, [6652])] * 5)
S1 = [(298, [6652, 13654])] * 6
TRACK = {12843, 12844, 12845, 12846, 12849, 12850, 12851, 12852, 12853, 12854}
PREV = {13654}


def test_entries_from_records_all_slots_with_ilvl():
    r = _rec((321, [1]), (334, [2]))
    r.gear.append({"slot": "HEAD", "item_id": 5, "item_level": 340, "bonus_ids": [9]})
    r.gear.append({"slot": "NECK", "item_id": 6, "item_level": 0, "bonus_ids": [7]})   # ohne Ilvl
    assert sorted(entries_from_records([r])) == [(321, [1]), (334, [2]), (340, [9])]
    assert sorted(entries_from_records([r], slots=("HEAD",))) == [(340, [9])]


def test_bonus_levels_respects_min_n():
    levels = bonus_levels(S2 + S1, min_n=5)
    assert dict(levels[12846]) == {321: 20}
    assert 13654 in levels and dict(levels[13654]) == {298: 6}
    assert 12843 in levels                       # n=6
    assert 12843 not in bonus_levels(S2, min_n=7)


def test_single_level_bonuses_finds_track_steps_not_generic():
    single = single_level_bonuses(S2 + S1)
    assert single[12846] == 321 and single[12854] == 334 and single[12843] == 311
    assert single[13654] == 298                  # auch der Vorsaison-Marker ist "ein Ilvl"
    assert 6652 not in single                    # generischer Bonus ueber viele Ilvls


def test_check_markers_ok_with_matching_constants():
    msgs = []
    assert check_markers(S2 + S1, TRACK, PREV, floor=320, log=msgs.append)
    assert msgs == []


def test_check_markers_ok_despite_low_tracks_in_broad_sample():
    # Regressionstest fuer den gescheiterten Cluster-Floor: Champion-Stufen 292..308 in
    # den Daten duerfen KEINE Warnung ausloesen, solange die Konstanten passen.
    broad = S2 + S1 + [(295, [6652])] * 8 + [(289, [6652])] * 8 + [(253, [])] * 8
    msgs = []
    assert check_markers(broad, TRACK, PREV, floor=320, log=msgs.append)
    assert msgs == []


def test_check_markers_warns_when_track_constants_absent():
    new = [(351, [14001])] * 30 + [(364, [14012])] * 8
    msgs = []
    assert not check_markers(new, TRACK, PREV, floor=320, log=msgs.append)
    assert any("Season-Wechsel" in m for m in msgs)


def test_check_markers_warns_when_data_exceed_known_tracks():
    # S2-Konstanten bekannt, aber die Daten reichen bis 351 (neuer Track) -> Warnung
    new = S2 + [(344, [14020])] * 10 + [(351, [14022])] * 10
    msgs = []
    assert not check_markers(new, TRACK, PREV, floor=320, log=msgs.append)
    assert any("Season-Wechsel" in m and "351" in m for m in msgs)


def test_check_markers_warns_when_prev_marker_sits_in_track_band():
    data = S2 + [(321, [13654])] * 6
    msgs = []
    assert not check_markers(data, TRACK, PREV, floor=320, log=msgs.append)
    assert any("Vorsaison-Marker" in m for m in msgs)


def test_check_markers_warns_on_floor_problems():
    msgs = []
    assert not check_markers(S2 + S1, TRACK, PREV, floor=340, log=msgs.append)
    assert any("Floor 340" in m for m in msgs)
    msgs = []
    assert not check_markers(S2 + S1, TRACK, PREV, floor=298, log=msgs.append)
    assert any("Floor 298" in m and "Vorsaison" in m for m in msgs)


def test_check_markers_silent_on_sparse_data():
    msgs = []
    assert check_markers([(321, [12846])] * 3, TRACK, PREV, floor=320, log=msgs.append)
    assert msgs == []
