#!/usr/bin/env python3
"""Icônes pixel-art dédiées (32x32 agrandies x8) : Pocket Speaker et Pocket Chat.
Usage : python3 tools/make_icons.py  -> ~/pocket-speaker/icon.png, ~/pocket-chat/icon.png (+ aperçu)."""
import math, os
from PIL import Image

S = 32
OUT = (8, 20, 26, 255)


def new(): return Image.new("RGBA", (S, S), (0, 0, 0, 0))
def put(im, x, y, c):
    if 0 <= x < S and 0 <= y < S: im.putpixel((x, y), c)
def rect(im, x0, y0, x1, y1, c, cut=0):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx = min(x - x0, x1 - x); dy = min(y - y0, y1 - y)
            if dx + dy < cut: continue
            put(im, x, y, c)


def tile(bands, glow):
    im = new()
    h = S // len(bands)
    for y in range(S):
        c = bands[min(y // h, len(bands) - 1)]
        for x in range(S):
            put(im, x, y, c + (255,))
    for r, a in ((13, 0.10), (9, 0.10)):  # halo derrière le motif
        for y in range(S):
            for x in range(S):
                if math.hypot(x - 15.5, y - 15.5) < r:
                    p = im.getpixel((x, y)); put(im, x, y, tuple(int(p[i] * (1 - a) + glow[i] * a) for i in range(3)) + (255,))
    for i, (x, y) in enumerate([(4, 5), (27, 4), (26, 27), (5, 26), (22, 7), (8, 22)]):  # étoiles
        put(im, x, y, (255, 255, 255, 120 if i % 2 else 200))
    for x in range(S):  # liseré clair en haut, ombre en bas
        put(im, x, 0, (255, 255, 255, 40)); put(im, x, S - 1, (0, 0, 0, 90))
    mask = new()
    rect(mask, 0, 0, S - 1, S - 1, (255, 255, 255, 255), cut=5)
    out = new()
    for y in range(S):
        for x in range(S):
            if mask.getpixel((x, y))[3]: out.putpixel((x, y), im.getpixel((x, y)))
    return out


def outline(glyph):
    base = glyph.copy()
    for y in range(S):
        for x in range(S):
            if glyph.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < S and 0 <= ny < S and glyph.getpixel((nx, ny))[3] and glyph.getpixel((nx, ny)) != OUT:
                        base.putpixel((x, y), OUT); break
    return base


def speaker():
    g = new()
    MINT, SHADE, LIGHT = (77, 225, 180, 255), (47, 184, 143, 255), (170, 247, 220, 255)
    rect(g, 5, 12, 10, 19, MINT, 1)                       # caisson
    for x in range(10, 17):                               # cône qui s'évase
        h = 4 + (x - 10)
        for y in range(int(15.5 - h + 0.5), int(15.5 + h + 0.5) + 1):
            put(g, x, y, SHADE if y > 15 else MINT)
    for x in range(5, 17): put(g, x, 12 if x < 10 else 11 - (x - 10), LIGHT)
    for x in range(5, 10): put(g, x, 13, LIGHT)
    g = outline(g)
    for r, col in ((6, (170, 247, 220, 255)), (9, (77, 225, 180, 255)), (12, (47, 184, 143, 200))):  # ondes sonores
        for a in range(-50, 51, 2):
            put(g, int(round(18 + r * math.cos(math.radians(a)))), int(round(15.5 + r * math.sin(math.radians(a)))), col)
    return g


def chat():
    g = new()
    BLUE, BSH, BLI = (106, 168, 255, 255), (74, 128, 214, 255), (170, 205, 255, 255)
    MINT, SHADE, LIGHT = (77, 225, 180, 255), (47, 184, 143, 255), (170, 247, 220, 255)
    rect(g, 4, 6, 19, 15, BLUE, 2); rect(g, 4, 14, 19, 15, BSH, 2); rect(g, 5, 6, 17, 6, BLI)
    for x, y in ((6, 16), (7, 16), (6, 17), (5, 17)): put(g, x, y, BSH)       # queue de la bulle bleue
    rect(g, 11, 13, 27, 23, MINT, 2); rect(g, 11, 22, 27, 23, SHADE, 2); rect(g, 12, 13, 25, 13, LIGHT)
    for x, y in ((23, 24), (24, 24), (24, 25), (25, 25)): put(g, x, y, SHADE)  # queue de la bulle menthe
    for x in (15, 19, 23):                                                     # trois points
        put(g, x, 17, OUT); put(g, x + 1, 17, OUT); put(g, x, 18, OUT); put(g, x + 1, 18, OUT)
    return outline(g)


def make(name, bands, glow, glyph):
    im = tile(bands, glow)
    im.alpha_composite(glyph)
    return im.resize((256, 256), Image.NEAREST)


a = make("speaker", [(24, 56, 58), (19, 46, 50), (14, 36, 42), (11, 28, 34)], (77, 225, 180), speaker())
b = make("chat", [(30, 42, 74), (24, 34, 62), (18, 27, 50), (13, 20, 40)], (106, 168, 255), chat())
home = os.path.expanduser("~")
a.save(f"{home}/pocket-speaker/icon.png"); b.save(f"{home}/pocket-chat/icon.png")
prev = Image.new("RGBA", (540, 280), (14, 17, 22, 255)); prev.alpha_composite(a, (8, 12)); prev.alpha_composite(b, (276, 12))
prev.save(f"{home}/pocket-speaker/build/icons_preview.png") if os.path.isdir(f"{home}/pocket-speaker/build") else prev.save("/tmp/icons_preview.png")
print("ok")
