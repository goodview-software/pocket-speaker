#!/usr/bin/env python3
"""Mascotte « Goody » (pixel-art 32x32) - source unique, définie par le Goodview Launcher.
Sorties : mascot/goody.png  (ligne = variante*5 + animation ; colonnes = images ; animations :
          idle, happy, wait, off, sad)  et  mascot/variants.png (image idle de chaque variante).
Usage : python3 tools/make_mascot.py [--icon]  (--icon : écrit aussi icon.png)"""
import sys
from PIL import Image, ImageDraw

BODIES = [(77, 225, 180), (255, 143, 177), (106, 168, 255), (255, 162, 77), (181, 139, 255),
          (255, 216, 77), (255, 107, 107), (201, 209, 218)]
ACCESSORIES = [None, "bow", "headphones", "glasses", "beanie", "antenna", "crown", "shades"]
WHITE_A = (255, 255, 255, 255)
LIGHT = (170, 247, 220, 255)
DARK = (14, 17, 22, 255); WHITE = (255, 255, 255, 255); PINK = (255, 139, 164, 255)
BLUE = (120, 190, 255, 255); NOTE = (255, 214, 120, 255)
S = 32


def px(d, x, y, w, h, c):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def note(d, x, y):
    px(d, x + 2, y, 1, 4, NOTE); px(d, x, y + 3, 2, 2, NOTE); px(d, x + 3, y, 2, 1, NOTE)


def zed(d, x, y):
    px(d, x, y, 3, 1, LIGHT); px(d, x + 1, y + 1, 1, 1, LIGHT); px(d, x, y + 2, 3, 1, LIGHT)


def tone(c, k): return tuple(max(0, min(255, int(v * k))) for v in c) + (255,)


def accessory(d, kind, top, c, acc_c):
    y = top - 8  # les coordonnées ci-dessous sont données pour top = 8
    def P(x, yy, w, h, col): px(d, x, yy + y, w, h, col)
    if kind == "headphones":
        P(8, 4, 16, 1, DARK); P(7, 5, 1, 4, DARK); P(24, 5, 1, 4, DARK)
        P(4, 10, 3, 7, DARK); P(25, 10, 3, 7, DARK); P(5, 11, 1, 5, c); P(26, 11, 1, 5, c)
    elif kind == "glasses":
        for x0 in (9, 18):
            P(x0, 13, 5, 1, WHITE_A); P(x0, 19, 5, 1, WHITE_A); P(x0, 13, 1, 7, WHITE_A); P(x0 + 4, 13, 1, 7, WHITE_A)
        P(14, 15, 4, 1, WHITE_A)
    elif kind == "beanie":
        P(8, 3, 16, 4, acc_c); P(7, 6, 18, 2, WHITE_A); P(14, 1, 4, 2, WHITE_A)
    elif kind == "bow":
        P(19, 3, 3, 3, WHITE_A); P(23, 3, 3, 3, WHITE_A); P(22, 4, 1, 1, c)
    elif kind == "antenna":
        P(15, 3, 2, 5, acc_c); P(14, 0, 4, 3, WHITE_A)
    elif kind == "crown":
        P(9, 5, 14, 3, NOTE)
        for x0 in (9, 15, 21): P(x0, 2, 2, 3, NOTE)
        P(15, 6, 2, 1, c)
    elif kind == "shades":
        P(9, 14, 5, 4, DARK); P(18, 14, 5, 4, DARK); P(14, 14, 4, 1, DARK); P(10, 14, 1, 1, WHITE_A); P(19, 14, 1, 1, WHITE_A)


def frame(lift=0, squash=0, eye="open", look=0, mouth="smile", arms="down", extra=None, v=0):
    BODY = BODIES[v] + (255,); SHADE = tone(BODIES[v], 0.78)
    LIGHT = tuple(min(255, int(c + (255 - c) * 0.5)) for c in BODIES[v]) + (255,)
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    px(d, 9, 29, 14 - lift, 1, (0, 0, 0, 80))  # ombre au sol
    top = 8 + squash - lift
    bot = 26 - lift
    px(d, 10, bot, 4, 2, SHADE); px(d, 18, bot, 4, 2, SHADE)  # pieds
    # oreilles
    px(d, 7, top - 3, 3, 4, BODY); px(d, 22, top - 3, 3, 4, BODY)
    px(d, 8, top - 2, 1, 2, PINK); px(d, 23, top - 2, 1, 2, PINK)
    # corps arrondi
    px(d, 6, top, 20, bot - top, BODY)
    for cx, cy in ((6, top), (25, top)):
        px(d, cx, cy, 1, 1, (0, 0, 0, 0))
    im.paste((0, 0, 0, 0), (6, top, 7, top + 1)); im.paste((0, 0, 0, 0), (25, top, 26, top + 1))
    px(d, 6, bot - 2, 20, 2, SHADE)
    px(d, 8, top + 2, 3, 1, LIGHT); px(d, 8, top + 3, 1, 1, LIGHT)
    # bras
    ay = top + 9
    if arms == "up":
        px(d, 3, top + 1, 3, 5, BODY); px(d, 26, top + 1, 3, 5, BODY)
    else:
        px(d, 4, ay, 2, 5, SHADE); px(d, 26, ay, 2, 5, SHADE)
    # yeux
    ey = top + 6
    for ex in (10, 19):
        x = ex + look
        if eye == "open":
            px(d, x, ey, 3, 5, DARK); px(d, x, ey, 1, 1, WHITE)
        elif eye == "blink" or eye == "sleep":
            px(d, x, ey + 3, 3, 1, DARK)
        elif eye == "happy":
            px(d, x, ey + 3, 1, 1, DARK); px(d, x + 1, ey + 2, 1, 1, DARK); px(d, x + 2, ey + 3, 1, 1, DARK)
        elif eye == "sad":
            px(d, x, ey, 3, 5, DARK); px(d, x, ey, 1, 1, WHITE); px(d, x + 1, ey + 5, 1, 2, BLUE)
    px(d, 8, ey + 5, 2, 2, PINK + ()); px(d, 22, ey + 5, 2, 2, PINK)  # joues
    my = top + 13
    if mouth == "smile":
        px(d, 13, my, 1, 1, DARK); px(d, 14, my + 1, 4, 1, DARK); px(d, 18, my, 1, 1, DARK)
    elif mouth == "open":
        px(d, 14, my, 4, 3, DARK); px(d, 15, my + 2, 2, 1, PINK)
    elif mouth == "o":
        px(d, 15, my, 2, 2, DARK)
    elif mouth == "flat":
        px(d, 14, my + 1, 4, 1, DARK)
    elif mouth == "sad":
        px(d, 13, my + 2, 1, 1, DARK); px(d, 14, my + 1, 4, 1, DARK); px(d, 18, my + 2, 1, 1, DARK)
    accessory(d, ACCESSORIES[v], top, BODY, tone(BODIES[v], 0.55))
    if extra:
        extra(d)
    return im


def anims(v):
    return {
    "idle": [frame(v=v), frame(v=v), frame(squash=1, v=v), frame(eye="blink", v=v)],
    "happy": [frame(eye="happy", arms="up", mouth="open", extra=lambda d: note(d, 26, 2), v=v),
              frame(lift=2, eye="happy", mouth="smile", extra=lambda d: note(d, 27, 0), v=v),
              frame(eye="happy", arms="up", mouth="open", extra=lambda d: note(d, 1, 3), v=v),
              frame(lift=1, eye="happy", mouth="smile", extra=lambda d: note(d, 0, 1), v=v)],
    "wait": [frame(look=-1, mouth="flat", v=v), frame(mouth="flat", v=v), frame(look=1, mouth="flat", v=v), frame(mouth="o", v=v)],
    "off": [frame(eye="sleep", mouth="flat", squash=1, extra=lambda d: zed(d, 25, 6), v=v),
            frame(eye="sleep", mouth="flat", extra=lambda d: (zed(d, 25, 6), zed(d, 28, 2))),
            frame(eye="sleep", mouth="flat", squash=1, extra=lambda d: zed(d, 26, 4), v=v),
            frame(eye="sleep", mouth="flat", extra=lambda d: zed(d, 25, 6), v=v)],
    "sad": [frame(eye="sad", mouth="sad", v=v), frame(eye="sad", mouth="sad", squash=1, v=v)] * 2,
}
NAMES = ["idle", "happy", "wait", "off", "sad"]
sheet = Image.new("RGBA", (S * 4, S * 5 * len(BODIES)), (0, 0, 0, 0))
variants = Image.new("RGBA", (S * len(BODIES), S), (0, 0, 0, 0))
for v in range(len(BODIES)):
    A = anims(v)
    for row, name in enumerate(NAMES):
        for i, im in enumerate(A[name]):
            sheet.paste(im, (i * S, (v * 5 + row) * S))
    variants.paste(A["idle"][0], (v * S, 0))
sheet.save("mascot/goody.png")
variants.save("mascot/variants.png")
if "--icon" in sys.argv:
    bg = Image.new("RGBA", (256, 256), (14, 17, 22, 255))
    bg.alpha_composite(anims(0)["idle"][0].resize((224, 224), Image.NEAREST), (16, 16))
    bg.save("icon.png")
print(len(BODIES), "variantes x", len(NAMES), "animations")
