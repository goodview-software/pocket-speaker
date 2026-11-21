#!/usr/bin/env python3
"""Génère la mascotte « Goody » (sprite sheet 32x32 pixel-art) : mascot/goody.png + icon.png.
Lignes = animations, colonnes = images. Voir ANIMS pour (ligne, nb images, fps)."""
from PIL import Image, ImageDraw

BODY = (77, 225, 180, 255); SHADE = (47, 184, 143, 255); LIGHT = (170, 247, 220, 255)
DARK = (14, 17, 22, 255); WHITE = (255, 255, 255, 255); PINK = (255, 139, 164, 255)
BLUE = (120, 190, 255, 255); NOTE = (255, 214, 120, 255)
S = 32


def px(d, x, y, w, h, c):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def note(d, x, y):
    px(d, x + 2, y, 1, 4, NOTE); px(d, x, y + 3, 2, 2, NOTE); px(d, x + 3, y, 2, 1, NOTE)


def zed(d, x, y):
    px(d, x, y, 3, 1, LIGHT); px(d, x + 1, y + 1, 1, 1, LIGHT); px(d, x, y + 2, 3, 1, LIGHT)


def frame(lift=0, squash=0, eye="open", look=0, mouth="smile", arms="down", extra=None):
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
    if extra:
        extra(d)
    return im


ANIMS = {
    "idle": [frame(), frame(), frame(squash=1), frame(eye="blink")],
    "happy": [frame(eye="happy", arms="up", mouth="open", extra=lambda d: note(d, 26, 2)),
              frame(lift=2, eye="happy", mouth="smile", extra=lambda d: note(d, 27, 0)),
              frame(eye="happy", arms="up", mouth="open", extra=lambda d: note(d, 1, 3)),
              frame(lift=1, eye="happy", mouth="smile", extra=lambda d: note(d, 0, 1))],
    "wait": [frame(look=-1, mouth="flat"), frame(mouth="flat"), frame(look=1, mouth="flat"), frame(mouth="o")],
    "off": [frame(eye="sleep", mouth="flat", squash=1, extra=lambda d: zed(d, 25, 6)),
            frame(eye="sleep", mouth="flat", extra=lambda d: (zed(d, 25, 6), zed(d, 28, 2))),
            frame(eye="sleep", mouth="flat", squash=1, extra=lambda d: zed(d, 26, 4)),
            frame(eye="sleep", mouth="flat", extra=lambda d: zed(d, 25, 6))],
    "sad": [frame(eye="sad", mouth="sad"), frame(eye="sad", mouth="sad", squash=1)] * 2,
}
sheet = Image.new("RGBA", (S * 4, S * len(ANIMS)), (0, 0, 0, 0))
for row, (name, fr) in enumerate(ANIMS.items()):
    for i, im in enumerate(fr):
        sheet.paste(im, (i * S, row * S))
    print(f'"{name}": [{row}, {len(fr)}],')
sheet.save("mascot/goody.png")
bg = Image.new("RGBA", (256, 256), (14, 17, 22, 255))
bg.alpha_composite(ANIMS["idle"][0].resize((224, 224), Image.NEAREST), (16, 16))
bg.save("icon.png")
