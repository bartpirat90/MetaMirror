"""Wowhead-Fallback-Quellen fuer Trinkets, die NICHT im Abenteuerfuehrer (Encounter
Journal) stehen -> Data/MetaMirrorSources.lua.

Der Schmuck-Tab zeigt die Quelle eines Trinkets normalerweise ueber den Journal-Scan im
Addon (Source.lua, klickbarer Boss-Link). Handwerk-, Haendler-, Tiefen- und PvP-Items
stehen im Journal NICHT drin -> hier per Wowhead-XML/HTML nachgeschlagen und als eigene
Lua-Datei ausgegeben, die das Addon als unklickbaren Fallback einliest (UI.lua,
pipelineSourceText). Das Journal hat immer Vorrang; eine Fehlklassifikation eines
Boss-Drops hier ist darum harmlos.

Ablauf pro Item:
  1. XML (www + de) -> source[]-Codes (1=Handwerk, 2=Drop, 3=PvP, 4=Quest, 5=Haendler)
     und sourcemore[] (Haendler-Name bei t==1, sonst nur Zone).
  2. Reihenfolge Handwerk > PvP > Haendler > (HTML-Delve-Check) > Drop (= im Journal,
     wird NICHT ausgegeben).
  3. Delve-Erkennung nur bei Bedarf ueber die normale Item-Seite (contained-in-object
     Listview): Truhen mit "Bountiful" im Namen oder "Pilfered Trunk" -> Tiefen-Loot.

Aufruf:  python -m pipeline.sources [--out Data/MetaMirrorSources.lua]
"""
import argparse
import json
import re
import sys
import time

import httpx

UA = "Mozilla/5.0"

ID_RE = re.compile(r"itemID\s*=\s*(\d+)")
NAME_XML_RE = re.compile(r"<name><!\[CDATA\[(.*?)\]\]></name>", re.DOTALL)
JSON_XML_RE = re.compile(r"<json><!\[CDATA\[(.*?)\]\]></json>", re.DOTALL)
NAME_JSON_RE = re.compile(r'"name":"((?:[^"\\]|\\.)*)"')

# Truhen-Namen, die Tiefen-Loot (Delves) markieren -> steht nicht im Journal.
_DELVE_MARKERS = ("Bountiful",)
_DELVE_EXACT = ("Pilfered Trunk",)

SLEEP_S = 0.4


def collect_trinket_ids(trinkets_path, data_path):
    """Vereinigte, sortierte itemID-Liste aus Trinkets-Datei + dem 'trinkets = {'-Block
    der Data-Datei (Rest der Data-Datei -- Gear/Schmuck-IDs -- zaehlt NICHT mit)."""
    ids = set()
    with open(trinkets_path, encoding="utf-8") as f:
        for m in ID_RE.finditer(f.read()):
            ids.add(int(m.group(1)))

    with open(data_path, encoding="utf-8") as f:
        text = f.read()
    idx = text.find("trinkets = {")
    if idx >= 0:
        for m in ID_RE.finditer(text[idx:]):
            ids.add(int(m.group(1)))

    return sorted(ids)


def fetch_item(client, item_id, locale="www"):
    """Holt Name + source/sourcemore fuer ein Item ueber die Wowhead-XML-Schnittstelle."""
    url = f"https://{locale}.wowhead.com/item={item_id}&xml"
    r = client.get(url, headers={"User-Agent": UA}, follow_redirects=True, timeout=30.0)
    r.raise_for_status()
    text = r.text

    name_m = NAME_XML_RE.search(text)
    json_m = JSON_XML_RE.search(text)
    data = json.loads("{" + json_m.group(1) + "}") if json_m else {}

    return {
        "name": name_m.group(1) if name_m else "",
        "source": data.get("source") or [],
        "sourcemore": data.get("sourcemore") or [],
    }


def _listview_line(html, tab):
    i = html.find(f"id: '{tab}'")
    if i < 0:
        i = html.find(f'id:"{tab}"')
    if i < 0:
        return None
    j = html.find("data:", i)
    if j < 0:
        return None
    return html[j:html.find("\n", j)]


def is_delve_page(html):
    """True, wenn eine der 'contained-in-object'-Truhen auf eine Tiefe hindeutet."""
    line = _listview_line(html, "contained-in-object")
    if not line:
        return False
    for name in NAME_JSON_RE.findall(line):
        if name in _DELVE_EXACT or any(marker in name for marker in _DELVE_MARKERS):
            return True
    return False


def _vendor_entry(payload):
    for sm in payload.get("sourcemore") or []:
        if sm.get("t") == 1 and sm.get("n"):
            return sm["n"]
    return None


def classify(en, de, html_getter):
    """en/de: fetch_item-Ergebnisse (www/de). html_getter: liefert die Item-Seite --
    wird NUR aufgerufen, wenn Handwerk/PvP/Haendler nicht bereits greifen (Delve-Check)."""
    source = en.get("source") or []

    if 1 in source:
        return {"kind": "crafted"}
    if 3 in source:
        return {"kind": "pvp"}
    if 5 in source:
        vendor_en = _vendor_entry(en)
        if vendor_en:
            vendor_de = _vendor_entry(de) or vendor_en
            return {"kind": "vendor", "name": {"enUS": vendor_en, "deDE": vendor_de}}

    if is_delve_page(html_getter()):
        return {"kind": "delve"}
    return {"kind": "drop"}


def resolve_all(client, ids, sleep=time.sleep, log=print):
    """Ruft Wowhead fuer jede itemID ab und klassifiziert die Quelle. Ein fehlschlagendes
    Item wird geloggt und uebersprungen (kein Abbruch der ganzen Liste)."""
    out = {}
    for item_id in ids:
        try:
            en = fetch_item(client, item_id, locale="www")
            sleep(SLEEP_S)
            de = fetch_item(client, item_id, locale="de")
            sleep(SLEEP_S)

            def html_getter(_id=item_id):
                r = client.get(
                    f"https://www.wowhead.com/item={_id}",
                    headers={"User-Agent": UA}, follow_redirects=True, timeout=30.0,
                )
                r.raise_for_status()
                sleep(SLEEP_S)
                return r.text

            result = classify(en, de, html_getter)
            result["itemName"] = en.get("name") or ""
            out[item_id] = result
            log(f"{item_id} {result['itemName']} -> {result['kind']}")
        except Exception as e:
            log(f"{item_id}: FEHLER ({e}) - uebersprungen")
            continue
    return out


def _q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def emit_lua(resolved, version):
    lines = [
        "-- Generiert aus wowhead.com: Quellen fuer Trinkets, die NICHT im Abenteuerfuehrer stehen",
        "-- (Handwerk / Haendler / Tiefen / PvP). NICHT von Hand bearbeiten: python -m pipeline.sources",
        "MetaMirrorItemSources = {",
        f"    version = {_q(version)},",
        "    items = {",
    ]
    for item_id in sorted(resolved):
        info = resolved[item_id]
        kind = info.get("kind")
        if kind == "drop":
            continue
        if kind == "vendor" and info.get("name"):
            n = info["name"]
            entry = (
                f'{{ kind = {_q(kind)}, name = {{ enUS = {_q(n["enUS"])}, '
                f'deDE = {_q(n["deDE"])} }} }}'
            )
        else:
            entry = f"{{ kind = {_q(kind)} }}"
        comment = f" -- {info['itemName']}" if info.get("itemName") else ""
        lines.append(f"        [{item_id}] = {entry},{comment}")
    lines.append("    },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Data/MetaMirrorSources.lua")
    ap.add_argument("--trinkets", default="Data/MetaMirrorTrinkets.lua")
    ap.add_argument("--data", default="Data/MetaMirrorData.lua")
    args = ap.parse_args(argv)

    ids = collect_trinket_ids(args.trinkets, args.data)
    if not ids:
        print("Keine Trinket-IDs gefunden", file=sys.stderr)
        return 1

    from datetime import date
    with httpx.Client(headers={"User-Agent": UA}) as client:
        resolved = resolve_all(client, ids)

    lua = emit_lua(resolved, version=f"wh-{date.today().isoformat()}")
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(lua)
    print(f"OK -> {args.out}  ({len(ids)} IDs geprueft, {len(resolved)} beantwortet)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
