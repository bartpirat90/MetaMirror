"""Tests fuer den Wowhead-Fallback-Quellen-Fetcher (pipeline/sources.py).

Alle Requests laufen ueber httpx.MockTransport -- KEINE echten Netzwerkzugriffe. Der
Handler unterscheidet Host (www/de) und Pfad (/item=..&xml vs. normale Item-Seite)."""
import json
import os
import re

import httpx

from pipeline.sources import (
    collect_trinket_ids, fetch_item, is_delve_page, classify, resolve_all, emit_lua,
)

PATH_ID_RE = re.compile(r"item=(\d+)")


def _xml_body(name, source, sourcemore):
    # sourcemore-Objekt OHNE aeussere Klammern, wie Wowhead es liefert (json.dumps und
    # dann die aeusseren '{'/'}'  wieder abschneiden -- Gegenstueck zu fetch_item()).
    frag = json.dumps({"source": source, "sourcemore": sourcemore})[1:-1]
    return f"<html><name><![CDATA[{name}]]></name><json><![CDATA[{frag}]]></json></html>"


def _delve_html():
    return (
        "var listviews = [];\n"
        "listviews[0] = new Listview({template: 'item', id: 'contained-in-object', "
        "data: [{\"name\":\"Abundantly Bountiful Heavy Trunk\"},"
        "{\"name\":\"Bountiful Heavy Trunk\"}]});\n"
    )


def _dungeon_html():
    return (
        "var listviews = [];\n"
        "listviews[0] = new Listview({template: 'item', id: 'contained-in-object', "
        "data: [{\"name\":\"Challenger's Cache\"},{\"name\":\"Chest of Proven Valor\"}]});\n"
    )


def _make_transport(items):
    """items: {itemID: {"en": (name, source, sourcemore), "de": (name, source, sourcemore),
    "html": str}} -- fehlende Keys liefern leere Defaults."""
    calls = {"html": 0}

    def handler(request):
        m = PATH_ID_RE.search(request.url.path)
        item_id = int(m.group(1)) if m else None
        entry = items.get(item_id, {})
        is_xml = request.url.path.endswith("&xml")
        if is_xml:
            locale = "de" if request.url.host.startswith("de.") else "en"
            name, source, sourcemore = entry.get(locale, ("Item", [], []))
            return httpx.Response(200, text=_xml_body(name, source, sourcemore))
        calls["html"] += 1
        return httpx.Response(200, text=entry.get("html", "<html></html>"))

    return httpx.MockTransport(handler), calls


def _client(items):
    transport, calls = _make_transport(items)
    return httpx.Client(transport=transport), calls


# --- collect_trinket_ids ----------------------------------------------------

def test_collect_trinket_ids_unions_both_files_and_respects_data_block(tmp_path):
    trinkets_path = tmp_path / "MetaMirrorTrinkets.lua"
    trinkets_path.write_text(
        'MetaMirrorTrinkets = { specs = { [1] = { overall = { '
        '{ itemID = 100 }, { itemID = 200 } } } } }',
        encoding="utf-8",
    )
    data_path = tmp_path / "MetaMirrorData.lua"
    data_path.write_text(
        # itemID = 1 steht VOR 'trinkets = {' (Gear-Bereich) -> darf NICHT gezaehlt werden.
        'MetaMirrorData = { specs = { [7] = { [262] = { raid = { gear = { '
        '{ slot = "HEAD", itemID = 1 } } } } } },\n'
        'trinkets = { [262] = { overall = { { itemID = 2 }, { itemID = 200 } } } },\n'
        "}",
        encoding="utf-8",
    )
    ids = collect_trinket_ids(str(trinkets_path), str(data_path))
    assert ids == [2, 100, 200]
    assert 1 not in ids


# --- classify -----------------------------------------------------------

def test_classify_crafted():
    en = {"name": "Alchemist Stone", "source": [1], "sourcemore": []}
    de = {"name": "Alchemist Stone", "source": [1], "sourcemore": []}
    result = classify(en, de, html_getter=lambda: (_ for _ in ()).throw(AssertionError("html not needed")))
    assert result == {"kind": "crafted"}


def test_classify_pvp():
    en = {"name": "Gladiator's Badge", "source": [3], "sourcemore": []}
    de = {"name": "Gladiator's Badge", "source": [3], "sourcemore": []}
    result = classify(en, de, html_getter=lambda: (_ for _ in ()).throw(AssertionError("html not needed")))
    assert result == {"kind": "pvp"}


def test_classify_vendor_uses_german_name():
    en = {"name": "Trinket", "source": [2, 4, 5],
          "sourcemore": [{"z": 15947}, {"n": "Zah'ran", "t": 1}]}
    de = {"name": "Trinket", "source": [2, 4, 5],
          "sourcemore": [{"z": 15947}, {"n": "Zah'ran", "t": 1}]}
    result = classify(en, de, html_getter=lambda: (_ for _ in ()).throw(AssertionError("html not needed")))
    assert result == {"kind": "vendor", "name": {"enUS": "Zah'ran", "deDE": "Zah'ran"}}


def test_classify_order_crafted_wins_over_vendor():
    # source [1,5]: 1 (Handwerk) muss VOR 5 (Haendler) greifen.
    en = {"name": "X", "source": [1, 5], "sourcemore": [{"n": "Vendor", "t": 1}]}
    de = {"name": "X", "source": [1, 5], "sourcemore": [{"n": "Vendor", "t": 1}]}
    result = classify(en, de, html_getter=lambda: (_ for _ in ()).throw(AssertionError("html not needed")))
    assert result == {"kind": "crafted"}


def test_classify_delve_via_html():
    en = {"name": "Delve Item", "source": [2], "sourcemore": []}
    de = {"name": "Delve Item", "source": [2], "sourcemore": []}
    result = classify(en, de, html_getter=lambda: _delve_html())
    assert result == {"kind": "delve"}


def test_classify_drop_stays_drop():
    en = {"name": "Dungeon Item", "source": [2], "sourcemore": []}
    de = {"name": "Dungeon Item", "source": [2], "sourcemore": []}
    result = classify(en, de, html_getter=lambda: _dungeon_html())
    assert result == {"kind": "drop"}


def test_classify_does_not_call_html_getter_for_crafted_or_vendor():
    calls = {"n": 0}

    def html_getter():
        calls["n"] += 1
        return _delve_html()

    en_crafted = {"name": "X", "source": [1], "sourcemore": []}
    classify(en_crafted, en_crafted, html_getter)
    en_vendor = {"name": "X", "source": [5], "sourcemore": [{"n": "Zah'ran", "t": 1}]}
    classify(en_vendor, en_vendor, html_getter)
    assert calls["n"] == 0


# --- is_delve_page --------------------------------------------------------

def test_is_delve_page_true_for_bountiful_trunk():
    assert is_delve_page(_delve_html()) is True


def test_is_delve_page_false_for_dungeon_chest():
    assert is_delve_page(_dungeon_html()) is False


def test_is_delve_page_false_when_no_listview():
    assert is_delve_page("<html>nothing here</html>") is False


# --- fetch_item (via MockTransport) --------------------------------------

def test_fetch_item_parses_xml_www_and_de():
    items = {
        241340: {
            "en": ("Magister's Alchemist Stone", [1], [{"n": "Alchemist Stone", "t": 6}]),
            "de": ("Alchemistenstein des Magisters", [1], [{"n": "Alchemist Stone", "t": 6}]),
        },
    }
    client, _ = _client(items)
    en = fetch_item(client, 241340, locale="www")
    de = fetch_item(client, 241340, locale="de")
    assert en["name"] == "Magister's Alchemist Stone"
    assert en["source"] == [1]
    assert de["name"] == "Alchemistenstein des Magisters"


# --- resolve_all -----------------------------------------------------------

def test_resolve_all_skips_failing_item_and_continues():
    items = {
        241340: {"en": ("Crafted Trinket", [1], []), "de": ("Crafted Trinket", [1], [])},
        999999: {},  # kein Eintrag -> Handler liefert leere Defaults, source=[] -> drop-Pfad -> HTML-Fetch
    }

    def handler(request):
        m = PATH_ID_RE.search(request.url.path)
        item_id = int(m.group(1)) if m else None
        if item_id == 999999:
            raise httpx.ConnectError("boom", request=request)
        entry = items.get(item_id, {})
        is_xml = request.url.path.endswith("&xml")
        if is_xml:
            locale = "de" if request.url.host.startswith("de.") else "en"
            name, source, sourcemore = entry.get(locale, ("Item", [], []))
            return httpx.Response(200, text=_xml_body(name, source, sourcemore))
        return httpx.Response(200, text="<html></html>")

    client = httpx.Client(transport=httpx.MockTransport(handler))

    sleep_calls = []
    logs = []
    result = resolve_all(client, [241340, 999999], sleep=sleep_calls.append, log=logs.append)

    assert 241340 in result and result[241340]["kind"] == "crafted"
    assert 999999 not in result
    assert any("999999" in line for line in logs)
    assert sleep_calls   # sleep() wurde fuer das erfolgreiche Item aufgerufen


def test_resolve_all_carries_item_name():
    items = {241340: {"en": ("Crafted Trinket", [1], []), "de": ("Crafted Trinket", [1], [])}}
    client, _ = _client(items)
    result = resolve_all(client, [241340], sleep=lambda s: None, log=lambda s: None)
    assert result[241340]["itemName"] == "Crafted Trinket"


# --- emit_lua ---------------------------------------------------------------

def test_emit_lua_only_non_drop_sorted_and_escaped():
    resolved = {
        274493: {"kind": "delve", "itemName": "Delve Item"},
        241340: {"kind": "crafted", "itemName": "Magister's Alchemist Stone"},
        999999: {"kind": "drop", "itemName": "In Journal"},
        248583: {"kind": "vendor", "itemName": "Vendor Item",
                  "name": {"enUS": 'Vendor "Bob"', "deDE": 'Haendler "Bob"'}},
    }
    lua = emit_lua(resolved, version="wh-2026-09-02")
    assert 'version = "wh-2026-09-02"' in lua
    assert "999999" not in lua
    # aufsteigend sortiert
    idx241 = lua.index("[241340]")
    idx248 = lua.index("[248583]")
    idx274 = lua.index("[274493]")
    assert idx241 < idx248 < idx274
    assert 'kind = "crafted"' in lua
    assert "-- Magister's Alchemist Stone" in lua   # Kommentar mit enUS-Itemname
    # Anfuehrungszeichen im Haendlernamen (echtes Lua-String-Literal) muessen escaped sein
    assert 'enUS = "Vendor \\"Bob\\""' in lua
    assert 'deDE = "Haendler \\"Bob\\""' in lua
    assert "MetaMirrorItemSources = {" in lua
