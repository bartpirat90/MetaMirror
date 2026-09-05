# -*- coding: utf-8 -*-
"""Macht aus den Beschreibungstexten HTML zum Einfuegen bei CurseForge.

Bewusst nur der Tag-Vorrat, den CurseForge stehen laesst: h2/h3, p, strong,
em, code, ul/li, a, hr. Die H1-Zeile faellt weg -- den Titel zeigt die
Projektseite selbst.
"""
import io
import os
import re

SRC = "E:/claude-projekt/MetaMirror/release/"
OUT = SRC + "curseforge/"
os.makedirs(OUT, exist_ok=True)

HEAD = """<!doctype html>
<meta charset="utf-8">
<title>{title}</title>
<style>
 body{{max-width:52em;margin:2rem auto;padding:0 1.5rem;
      font:16px/1.6 "Segoe UI",system-ui,sans-serif;color:#1a1a1a;background:#fff}}
 h2{{margin:2.2rem 0 .6rem;font-size:1.5rem;border-bottom:1px solid #ddd;padding-bottom:.3rem}}
 h3{{margin:1.6rem 0 .4rem;font-size:1.15rem}}
 p,li{{margin:.6rem 0}} hr{{border:0;border-top:1px solid #ddd;margin:2rem 0}}
 code{{background:#f0f0f3;padding:.1em .35em;border-radius:3px;font-size:.92em}}
</style>
"""


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def inline(t):
    t = esc(t)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![*\w])\*([^*]+)\*(?!\w)", r"<em>\1</em>", t)
    return t


def convert(md):
    out, para, in_list = [], [], False

    def flush_para():
        if para:
            out.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()

    def close_list():
        nonlocal in_list
        if in_list:
            out.append("</ul>")
            in_list = False

    for raw in md.splitlines():
        line = raw.rstrip()
        if not line.strip():
            flush_para()
            close_list()
            continue
        if line.startswith("# "):                      # H1 = Projekttitel, faellt weg
            flush_para(); close_list()
            continue
        if line.startswith("### "):
            flush_para(); close_list()
            out.append("<h3>" + inline(line[4:]) + "</h3>")
            continue
        if line.startswith("## "):
            flush_para(); close_list()
            out.append("<h2>" + inline(line[3:]) + "</h2>")
            continue
        if line.strip() == "---":
            flush_para(); close_list()
            out.append("<hr>")
            continue
        if line.lstrip().startswith("- "):
            flush_para()
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append("  <li>" + inline(line.lstrip()[2:]) + "</li>")
            continue
        if in_list:                                    # Fortsetzungszeile im Listenpunkt
            out[-1] = out[-1][:-len("</li>")] + " " + inline(line.strip()) + "</li>"
            continue
        para.append(line.strip())

    flush_para()
    close_list()
    return "\n".join(out) + "\n"


for lang, title in (("en", "MetaMirror - CurseForge description (EN)"),
                    ("de", "MetaMirror - CurseForge-Beschreibung (DE)")):
    md = io.open(SRC + f"description-{lang}.md", encoding="utf-8").read()
    body = convert(md)
    io.open(OUT + f"description-{lang}.html", "w", encoding="utf-8",
            newline="\n").write(HEAD.format(title=title) + body)
    print(f"description-{lang}.html  {len(body)} Zeichen Rumpf")
