from pipeline.specs import SPECS, STAT_KEYS, CONTENTS


def test_all_specs_unique():
    # WoW hat aktuell 39 Specs (13 Klassen: 10x3 + Druide 4 + Daemonenjaeger 2 + Rufer 3).
    keys = {(s.class_id, s.spec_id) for s in SPECS}
    assert len(keys) == 39
    assert len(SPECS) == 39


def test_class_ids_in_range():
    assert all(1 <= s.class_id <= 13 for s in SPECS)


def test_stat_and_content_constants():
    assert STAT_KEYS == ["haste", "crit", "mastery", "vers"]
    assert CONTENTS == ["mythicplus", "raid"]
