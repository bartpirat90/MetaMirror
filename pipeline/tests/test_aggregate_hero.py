from pipeline.models import ParseRecord
from pipeline.aggregate import aggregate

# ===== Hero-Baum-Aufteilung der Talent-Builds =====
# Die Meta-Empfehlung wird pro Hero-Talent-Baum getrennt: aggregate() findet den
# SubTreeSelection-Knoten EMPIRISCH (der Knoten, dessen entryID einen grossen
# exklusiven Knoten-Cluster schaltet), gruppiert die Parses danach und emittiert je
# Hero-Baum den meistgenutzten Build. "strongest" = meistgenutzter Hero-Baum.

_STATS = {"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}
_CONS = {"flask": None, "food": None, "phial": None, "potion": None, "oil": None, "rune": None}

# Feste Bausteine: Klassenbaum (in allen Parses), zwei exklusive Hero-Cluster.
_SHARED = [{"nodeID": 10, "entryID": 1000, "rank": 1},
           {"nodeID": 11, "entryID": 1001, "rank": 1},
           {"nodeID": 12, "entryID": 1002, "rank": 2}]
_HERO_A = [{"nodeID": 20, "entryID": 2000, "rank": 1},
           {"nodeID": 21, "entryID": 2001, "rank": 1},
           {"nodeID": 22, "entryID": 2002, "rank": 1},
           {"nodeID": 23, "entryID": 2003, "rank": 1}]
_HERO_B = [{"nodeID": 30, "entryID": 3000, "rank": 1},
           {"nodeID": 31, "entryID": 3001, "rank": 1},
           {"nodeID": 32, "entryID": 3002, "rank": 1},
           {"nodeID": 33, "entryID": 3003, "rank": 1}]
_SUBTREE_NODE = 999


def _rec(hero, sig, nodes):
    return ParseRecord(
        class_id=9, spec_id=266, content="raid", stats=_STATS,
        talent_import="", talent_sig=sig,
        gear=[{"slot": "HEAD", "item_id": 100, "item_level": 300,
               "enchant_id": 0, "gems": [], "bonus_ids": []}],
        consumables=dict(_CONS), talent_nodes=nodes)


def _hero_rec(hero_entry, cluster, sig):
    nodes = list(_SHARED) + [{"nodeID": _SUBTREE_NODE, "entryID": hero_entry, "rank": 1}] + list(cluster)
    return _rec(hero_entry, sig, nodes)


def _name(i):
    return f"item{i}"


def test_splits_two_hero_trees_with_strongest_flag():
    # 6x Hero A (entry 700), 4x Hero B (entry 701) -> A ist der staerkste Build.
    recs = [_hero_rec(700, _HERO_A, "A") for _ in range(6)]
    recs += [_hero_rec(701, _HERO_B, "B") for _ in range(4)]
    agg = aggregate(recs, spec_id=266, season={}, item_name=_name)

    assert len(agg.talents) == 2
    strong = [t for t in agg.talents if t["strongest"]]
    assert len(strong) == 1
    s = strong[0]
    assert s["heroEntryID"] == 700          # der groessere Hero-Baum
    assert s["heroNode"] == _SUBTREE_NODE
    assert s["usagePct"] == 60              # 6 von 10
    other = [t for t in agg.talents if not t["strongest"]][0]
    assert other["heroEntryID"] == 701
    assert other["usagePct"] == 40
    # der staerkste steht zuerst
    assert agg.talents[0]["strongest"] is True
    # Repraesentanten-Knoten je Build vorhanden (fuer den Aktivieren-Button)
    assert any(nd["nodeID"] == _SUBTREE_NODE and nd["entryID"] == 700 for nd in s["nodes"])
    assert any(nd["nodeID"] == _SUBTREE_NODE and nd["entryID"] == 701 for nd in other["nodes"])


def test_single_hero_tree_yields_one_build():
    # Alle Top-Parses spielen denselben Hero-Baum: ohne Variation ist der Subtree-Knoten
    # nicht empirisch identifizierbar -> ein (unbeschrifteter) Build, als staerkster markiert.
    recs = [_hero_rec(700, _HERO_A, "A") for _ in range(8)]
    agg = aggregate(recs, spec_id=266, season={}, item_name=_name)
    assert len(agg.talents) == 1
    assert agg.talents[0]["strongest"] is True
    assert agg.talents[0]["heroEntryID"] == 0
    # der Build enthaelt trotzdem alle Knoten (Aktivieren-Button bleibt scharf)
    assert agg.talents[0]["nodes"]


def test_fringe_hero_tree_is_dropped():
    # 9x Hero A, 1x Hero B (Ausreisser) -> nur der dominante Build bleibt.
    recs = [_hero_rec(700, _HERO_A, "A") for _ in range(9)]
    recs += [_hero_rec(701, _HERO_B, "B")]
    agg = aggregate(recs, spec_id=266, season={}, item_name=_name)
    assert len(agg.talents) == 1
    assert agg.talents[0]["heroEntryID"] == 700


def test_fallback_without_node_data_keeps_sig_usage():
    # Ohne talent_nodes (alte Daten) -> ein Build, usagePct = Sig-Anteil (wie zuvor).
    recs = [_rec(0, "A", []) for _ in range(2)] + [_rec(0, "B", [])]
    agg = aggregate(recs, spec_id=266, season={}, item_name=_name)
    assert len(agg.talents) == 1
    assert agg.talents[0]["usagePct"] == 67       # 2 von 3 (meistgenutzte Signatur)
    assert agg.talents[0]["strongest"] is True
    assert agg.talents[0]["heroEntryID"] == 0
