# -*- coding: utf-8 -*-
"""Baut die MetaMirror-Galerie aus den echten Ingame-Screenshots.

Optik = Style.lua: neutraler fast schwarzer Grund, Violett nur als Akzent,
Tiefe durch Verlauf/Schatten. Beschriftung englisch (Projektkonvention).
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, ".."))
BRAND = os.path.abspath(os.path.join(HERE, "..", "..", "branding"))
os.makedirs(OUT, exist_ok=True)

W, H = 1560, 980

BG        = (15, 15, 18)
BG_DEEP   = (10, 10, 13)
ACCENT    = (168, 85, 247)
ACCENT_L  = (192, 132, 252)
TXT_TITLE = (255, 255, 255)
TXT_PRI   = (230, 230, 234)
TXT_SEC   = (138, 138, 150)
TXT_DIM   = (74, 74, 85)
BORDER    = (51, 51, 62)
GREEN     = (74, 222, 128)

F = "C:/Windows/Fonts/"
def font(name, size):
    return ImageFont.truetype(F + name, size)

BOLD, SEMI, REG, LIGHT = "segoeuib.ttf", "seguisb.ttf", "segoeui.ttf", "segoeuil.ttf"


# ---------------------------------------------------------------- Grundfläche
def canvas():
    """Fast schwarzer Grund mit senkrechtem Verlauf und weichem Violettschimmer."""
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(BG[i] + (BG_DEEP[i] - BG[i]) * t) for i in range(3))
        d.line([(0, y), (W, y)], fill=c)

    glow = Image.new("L", (W // 4, H // 4), 0)
    ImageDraw.Draw(glow).ellipse([-40, -70, 250, 150], fill=90)
    glow = glow.resize((W, H), Image.BILINEAR).filter(ImageFilter.GaussianBlur(60))
    im = Image.composite(Image.new("RGB", (W, H), (58, 28, 92)), im, glow)
    return im


def shadow(im, box, radius=26, spread=14, alpha=150):
    """Weicher Schlagschatten unter einem Rechteck (box = l,t,r,b)."""
    l, t, r, b = box
    lay = Image.new("L", (W, H), 0)
    ImageDraw.Draw(lay).rectangle([l - spread // 2, t + 6, r + spread // 2, b + spread],
                                  fill=alpha)
    lay = lay.filter(ImageFilter.GaussianBlur(radius))
    return Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), im, lay)


# ---------------------------------------------------------------------- Text
def wrap(draw, text, fnt, width):
    lines, cur = [], ""
    for word in text.split():
        probe = (cur + " " + word).strip()
        if draw.textlength(probe, font=fnt) <= width or not cur:
            cur = probe
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def tracked(draw, xy, text, fnt, fill, track=3):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + track
    return x


# ------------------------------------------------------------------ Tab-Karte
def tab_card(panel_path, eyebrow, headline, subtitle, bullets, out_name):
    im = canvas()

    panel = Image.open(panel_path).convert("RGB")
    pw, ph = panel.size
    scale = 890 / ph
    panel = panel.resize((int(pw * scale), 890), Image.LANCZOS)
    pw, ph = panel.size
    px, py = W - 78 - pw, (H - ph) // 2 - 10

    im = shadow(im, (px, py, px + pw, py + ph))
    im.paste(panel, (px, py))
    d = ImageDraw.Draw(im)
    d.rectangle([px - 1, py - 1, px + pw, py + ph], outline=BORDER, width=1)
    d.line([(px, py), (px + pw - 1, py)], fill=(58, 58, 70))

    f_eye = font(SEMI, 20)
    f_head = font(BOLD, 44)
    f_sub = font(REG, 26)
    f_bul = font(REG, 24)

    colw = px - 90 - 60
    head_lines = wrap(d, headline, f_head, colw)
    sub_lines = wrap(d, subtitle, f_sub, colw)

    block = 20 + 30 + len(head_lines) * 56 + 18 + len(sub_lines) * 38 + 46
    block += len(bullets) * 56
    y = (H - block) // 2

    tracked(d, (90, y), eyebrow.upper(), f_eye, ACCENT_L, track=3)
    y += 50

    for ln in head_lines:
        d.text((90, y), ln, font=f_head, fill=TXT_TITLE)
        y += 56
    y += 18

    for ln in sub_lines:
        d.text((90, y), ln, font=f_sub, fill=TXT_SEC)
        y += 38
    y += 46

    for b in bullets:
        d.ellipse([92, y + 11, 102, y + 21], fill=ACCENT)
        for ln in wrap(d, b, f_bul, colw - 34):
            d.text((122, y), ln, font=f_bul, fill=TXT_PRI)
            y += 34
        y += 22

    f_note = font(REG, 18)
    note = "In-game panel, German game client"
    d.text((px + pw - d.textlength(note, font=f_note), py + ph + 16),
           note, font=f_note, fill=TXT_DIM)

    im.save(os.path.join(OUT, out_name))
    print("geschrieben:", out_name, im.size)


# ----------------------------------------------------------------- Hero-Karte
def hero(out_name="00-hero.png"):
    im = canvas()
    d = ImageDraw.Draw(im)

    logo = Image.open(os.path.join(BRAND, "logo-square.png")).convert("RGBA")
    logo = logo.resize((236, 236), Image.LANCZOS)
    lx, ly = 300, 118
    im.paste(logo, (lx, ly), logo)

    f_word = font(BOLD, 104)
    f_tag = font(LIGHT, 34)
    tx = lx + 236 + 44
    d.text((tx, ly + 30), "Meta", font=f_word, fill=TXT_TITLE)
    wmeta = d.textlength("Meta", font=f_word)
    d.text((tx + wmeta, ly + 30), "Mirror", font=f_word, fill=ACCENT)
    d.text((tx + 4, ly + 152), "Sim reference, right beside your character sheet",
           font=f_tag, fill=TXT_SEC)

    f_bul = font(REG, 30)
    bullets = [
        "Secondary-stat targets per spec, split by Mythic+ and Raid",
        "The season's SimulationCraft reference gear set, with a traffic light",
        "Trinket tiers S to D from bloodmallet's simulated DPS",
        "Enchants, gems and consumables on a single page",
        "Tooltip hints, and an alert when a reference item drops",
    ]
    y = 470
    bx = 396
    for b in bullets:
        d.ellipse([bx, y + 12, bx + 14, y + 26], fill=(28, 60, 40),
                  outline=GREEN, width=2)
        d.line([(bx + 4, y + 19), (bx + 6, y + 23)], fill=GREEN, width=2)
        d.line([(bx + 6, y + 23), (bx + 11, y + 15)], fill=GREEN, width=2)
        d.text((bx + 38, y), b, font=f_bul, fill=TXT_PRI)
        y += 62

    f_foot = font(SEMI, 24)
    foot = "World of Warcraft  ·  Midnight (Interface 120100)  ·  /mm"
    d.text(((W - d.textlength(foot, font=f_foot)) / 2, 826), foot,
           font=f_foot, fill=(122, 98, 156))
    f_src = font(REG, 20)
    src = "Data from bloodmallet.com and SimulationCraft  ·  item sources from Wowhead"
    d.text(((W - d.textlength(src, font=f_src)) / 2, 872), src,
           font=f_src, fill=TXT_DIM)

    im.save(os.path.join(OUT, out_name))
    print("geschrieben:", out_name, im.size)


hero()

tab_card(
    os.path.join(HERE, "panel-a.png"), "Stats tab",
    "Stat targets from public sims",
    "One target for Raid (single-target sim), one for Mythic+ (five-target sim).",
    [
        "Your live secondary stats, measured against the sim target",
        "Averaged over every distribution within 0.5% of the best, so the "
        "target is finer than the sim's 10% grid",
        "Every header carries a data stamp, so you see how fresh the numbers are",
    ],
    "01-stats.png")

tab_card(
    os.path.join(HERE, "panel-b.png"), "Gear tab",
    "The season's reference set",
    "Items, gems and enchants taken from the SimulationCraft profile for your spec.",
    [
        "Traffic light per slot: equipped, sitting in your bags, or missing",
        "Every row names where the item actually drops",
        "One profile per spec, so Mythic+ and Raid share the same set",
    ],
    "02-gear.png")

tab_card(
    os.path.join(HERE, "panel-c.png"), "Trinkets tab",
    "Trinket tiers, S down to D",
    "Simulated DPS from bloodmallet.com, ranked for your spec.",
    [
        "Gold rows are the two trinkets the reference profile actually wears",
        "bloodmallet sims trinkets single-target, so M+ and Raid share one list",
        "Drop source named for every trinket in the list",
    ],
    "03-trinkets.png")

tab_card(
    os.path.join(HERE, "panel-d.png"), "Upgrades tab",
    "Enchants, gems and consumables",
    "Everything you still have to craft or buy, collected on one page.",
    [
        "The exact enchant and gem the reference profile uses, per slot",
        "Flask, potion and food for your spec",
        "Each section folds away with one click",
    ],
    "04-upgrades.png")
