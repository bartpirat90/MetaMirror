"""Round-Trip-Beweis fuer den Talent-Export-Serialisierer gegen einen ECHTEN
In-Game-String (Warlock Demonology, specID 266). Wenn decode->encode bit-genau den
Originalstring reproduziert, ist das Format korrekt beherrscht."""
from pipeline.talent_string import decode, encode, Loadout, Node

# Echter exportString aus /mm dumptalents (Warlock Demonology).
REAL = ("CoQAMrNP5kak+EBqLfUa3dMm+yMzMzoZjx2MzMzyAAAAAAAAGzYYBGYb0CNsYMzYZWmZmxM"
        "AwMjZmxMDAzYmBAAYMzMjhhlZMgB")


def test_decode_header():
    lo = decode(REAL)
    assert lo.version == 2
    assert lo.spec_id == 266
    assert len(lo.tree_hash) == 16


def test_decode_node_stats():
    lo = decode(REAL)
    selected = [n for n in lo.nodes if n.selected]
    choices = [n for n in lo.nodes if n.choice]
    assert len(selected) == 73
    assert len(choices) == 12
    # Alle selektierten Knoten voll geskillt (kein partial in diesem Build)
    assert all(not n.partial for n in selected)


def test_roundtrip_is_bit_exact():
    """decode -> encode reproduziert den Originalstring exakt."""
    assert encode(decode(REAL)) == REAL


def test_encode_minimal_loadout():
    lo = Loadout(version=2, spec_id=266, tree_hash=[0] * 16,
                 nodes=[Node(selected=True, purchased=True),
                        Node(selected=False),
                        Node(selected=True, purchased=True, choice=True, entry_index=1)])
    s = encode(lo)
    back = decode(s)
    assert back.version == 2 and back.spec_id == 266
    # Erste drei Knoten muessen die gesetzten Eigenschaften zurueckliefern
    assert back.nodes[0].selected and back.nodes[0].purchased
    assert not back.nodes[1].selected
    assert back.nodes[2].choice and back.nodes[2].entry_index == 1
