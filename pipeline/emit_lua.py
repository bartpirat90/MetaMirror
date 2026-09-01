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

    lines.append(f"{p}talents = {{")
    for t in agg.talents:
        lines.append(f'{p2}{{ importString = {_q(t["importString"])}, usagePct = {int(t["usagePct"])} }},')
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


def emit_lua(data, version, season):
    """data: {classID: {specID: {content: AggregatedSpec}}} -> Lua-Quelltext."""
    out = ["-- Generiert von der MetaMirror-Pipeline. NICHT von Hand bearbeiten.",
           "MetaMirrorData = {",
           f"    version = {_q(version)},",
           f"    season = {_q(season)},",
           '    attribution = "Data from Warcraft Logs",',
           "    specs = {"]
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
    out.append("}")
    return "\n".join(out) + "\n"
