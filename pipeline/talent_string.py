"""Blizzard Talent-Loadout-Export (C_Traits) de-/serialisieren.

Format (verifiziert gegen einen echten In-Game-exportString, Warlock Demonology 266):
Standard-Base64-Charset, Bitstrom LSB-first. Kopf:
    version   : 8 bit   (aktuell 2)
    specID    : 16 bit
    treeHash  : 128 bit  (16 Bytes; identifiziert den Talentbaum-Stand)
Danach je Knoten IN DER REIHENFOLGE von C_Traits.GetTreeNodes(treeID):
    selected(1); wenn selected:
        purchased(1); wenn purchased:
            partiallyRanked(1); wenn partial: rank(6)
        choiceNode(1); wenn choice: entryIndex(2)
Der Bitstrom wird am Ende mit Null-Bits auf ein Vielfaches von 6 aufgefuellt.

Zweck: aus einem Meta-Build (Knotenauswahl der Top-Parses) + lokalem Kopf (version,
specID, treeHash der eigenen Spec) einen Import-String bauen, den der Spieler einfuegen
kann. Die Reihenfolge/Der Hash kommen zur Laufzeit aus C_Traits; dieses Modul ist die
getestete Referenz fuer den Lua-Port und erlaubt spaeter das Emittieren im Pipeline-Lauf.
"""
from dataclasses import dataclass

_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
_IDX = {c: i for i, c in enumerate(_CHARS)}

VERSION = 2


@dataclass
class Node:
    selected: bool = False
    purchased: bool = False
    partial: bool = False
    rank: int = 0
    choice: bool = False
    entry_index: int = 0


@dataclass
class Loadout:
    version: int
    spec_id: int
    tree_hash: list      # 16 Bytes
    nodes: list          # [Node]


class _Reader:
    def __init__(self, s):
        self.bits = []
        for ch in s:
            v = _IDX[ch]
            for b in range(6):
                self.bits.append((v >> b) & 1)
        self.pos = 0

    def remaining(self):
        return len(self.bits) - self.pos

    def read(self, n):
        val = 0
        for i in range(n):
            val |= self.bits[self.pos + i] << i
        self.pos += n
        return val


class _Writer:
    def __init__(self):
        self.bits = []

    def write(self, val, n):
        for i in range(n):
            self.bits.append((val >> i) & 1)

    def to_string(self):
        # auf Vielfaches von 6 mit Null-Bits auffuellen
        while len(self.bits) % 6 != 0:
            self.bits.append(0)
        out = []
        for i in range(0, len(self.bits), 6):
            v = 0
            for b in range(6):
                v |= self.bits[i + b] << b
            out.append(_CHARS[v])
        return "".join(out)


def decode(s):
    r = _Reader(s)
    version = r.read(8)
    spec_id = r.read(16)
    tree_hash = [r.read(8) for _ in range(16)]
    nodes = []
    # Bis maximal ein Knoten-Minimum (1 bit) nicht mehr passt. Trailing-Null-Padding
    # (< 6 Bit) erzeugt hoechstens unselektierte Leerknoten am Ende -> unschaedlich fuer
    # den Round-Trip, da das Padding beim Re-Encode identisch wieder entsteht.
    while r.remaining() >= 1:
        n = Node()
        n.selected = bool(r.read(1))
        if n.selected:
            n.purchased = bool(r.read(1))
            if n.purchased:
                n.partial = bool(r.read(1))
                if n.partial:
                    n.rank = r.read(6)
            n.choice = bool(r.read(1))
            if n.choice:
                n.entry_index = r.read(2)
        nodes.append(n)
    return Loadout(version, spec_id, tree_hash, nodes)


def encode(loadout):
    w = _Writer()
    w.write(loadout.version, 8)
    w.write(loadout.spec_id, 16)
    for byte in loadout.tree_hash:
        w.write(byte, 8)
    for n in loadout.nodes:
        w.write(1 if n.selected else 0, 1)
        if n.selected:
            w.write(1 if n.purchased else 0, 1)
            if n.purchased:
                w.write(1 if n.partial else 0, 1)
                if n.partial:
                    w.write(n.rank, 6)
            w.write(1 if n.choice else 0, 1)
            if n.choice:
                w.write(n.entry_index, 2)
    return w.to_string()
