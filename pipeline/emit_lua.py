from pipeline.specs import CONTENTS


def _q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def _spec_block(agg, indent):
    p = " " * indent
    p2 = " " * (indent + 4)
    lines = [f"{p}sampleSize = {agg.sample_size},"]

    lines.append(f"{p}stats = {{")
    for s in agg.stats:
        lines.append(f'{p2}{{ key = {_q(s["key"])}, rating = {int(s["rating"])} }},')
    lines.append(f"{p}}},")

    lines.append(f"{p}gear = {{")
    for g in agg.gear:
        bonus = ", ".join(str(int(b)) for b in g.get("bonusIDs", []))
        lines.append(
            f'{p2}{{ slot = {_q(g["slot"])}, itemID = {int(g["itemID"])}, '
            f'itemLevel = {int(g.get("itemLevel", 0))}, bonusIDs = {{ {bonus} }}, '
            f'name = {_q(g["name"])} }},'
        )
    lines.append(f"{p}}},")

    lines.append(f"{p}gems = {{")
    for g in agg.gems:
        lines.append(f'{p2}{{ slot = {_q(g["slot"])}, itemID = {int(g["itemID"])}, name = {_q(g["name"])} }},')
    lines.append(f"{p}}},")

    lines.append(f"{p}enchants = {{")
    for e in agg.enchants:
        lines.append(
            f'{p2}{{ slot = {_q(e["slot"])}, id = {int(e["id"])}, '
            f'itemID = {int(e.get("itemID", 0))}, name = {_q(e["name"])} }},'
        )
    lines.append(f"{p}}},")

    cons = ", ".join(f"{k} = {int(v)}" for k, v in sorted(agg.consumables.items()))
    lines.append(f"{p}consumables = {{ {cons} }},")
    return "\n".join(lines)


def _extra_literal(value):
    """Ein extra-Wert (String/Zahl/verschachteltes Dict) -> Lua-Literal. Dict-Keys werden
    fuer deterministische Ausgabe sortiert; verschachtelte Dicts rekursiv als Inline-Table."""
    if isinstance(value, dict):
        parts = [f"{k} = {_extra_literal(value[k])}" for k in sorted(value)]
        return "{ " + ", ".join(parts) + " }"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if value is None:
        return "nil"
    return _q(value)


def _trinket_block(trinkets, indent):
    """trinkets: {specID: {overall,raid,dungeon}} -> Lua-Block 'trinkets = { ... }'."""
    p = " " * indent
    p2 = " " * (indent + 4)
    p3 = " " * (indent + 8)
    lines = [f"{p}trinkets = {{"]
    for spec_id in sorted(trinkets):
        views = trinkets[spec_id]
        lines.append(f"{p2}[{int(spec_id)}] = {{")
        for key in ("overall", "raid", "dungeon"):
            entries = views.get(key) or []
            parts = [f'{{ itemID = {int(e["itemID"])}, tier = {_q(e["tier"])}, '
                     f'name = {_q(e["name"])} }}' for e in entries]
            lines.append(f"{p3}{key} = {{ " + ", ".join(parts) + " },")
        lines.append(f"{p2}}},")
    lines.append(f"{p}}},")
    return "\n".join(lines)


def emit_lua(data, version, season, trinkets=None,
             attribution="Data from bloodmallet.com (SimulationCraft)", extra=None):
    """data: {classID: {specID: {content: AggregatedSpec}}} -> Lua-Quelltext.
    trinkets: optionale {specID: {overall,raid,dungeon}}-Tierliste (aktuell ungenutzt --
             die Schmuckliste steht in Data/MetaMirrorTrinkets.lua).
    extra: zusaetzliche Top-Level-Felder nach 'season' (z.B. fightStyles, generated,
    simcHash, sources) -- Werte sind String/Zahl/verschachteltes Dict, deterministisch
    (Keys sortiert) ausgegeben."""
    out = ["-- Generiert von der MetaMirror-Pipeline. NICHT von Hand bearbeiten.",
           "MetaMirrorData = {",
           f"    version = {_q(version)},",
           f"    season = {_q(season)},"]
    for key in sorted(extra or {}):
        out.append(f"    {key} = {_extra_literal(extra[key])},")
    out.append(f"    attribution = {_q(attribution)},")
    out.append("    specs = {")
    for class_id in sorted(data):
        out.append(f"        [{class_id}] = {{")
        for spec_id in sorted(data[class_id]):
            out.append(f"            [{spec_id}] = {{")
            for content in CONTENTS:
                agg = data[class_id][spec_id].get(content)
                if not agg:
                    continue
                out.append(f"                {content} = {{")
                out.append(_spec_block(agg, 20))
                out.append("                },")
            out.append("            },")
        out.append("        },")
    out.append("    },")
    if trinkets:
        out.append(_trinket_block(trinkets, 4))
    out.append("}")
    return "\n".join(out) + "\n"
