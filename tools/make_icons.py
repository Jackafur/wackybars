#!/usr/bin/env python3
"""Draws WackyBars' two job icons in the style of WoW's spell icons: full-bleed square, painted background, no border
(the button draws its own frame). Drawn at 512 and scaled to 64 x 64 for smooth edges. Usage: make_icons.py <out_dir>"""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 512
OUT = sys.argv[1]


def radial(inner, outer, centre=(0.5, 0.45), power=1.3):
    img = Image.new("RGB", (S, S))
    px = img.load()
    cx, cy = centre[0] * S, centre[1] * S
    maxd = math.hypot(S, S) * 0.62
    for y in range(S):
        for x in range(S):
            t = min(1.0, (math.hypot(x - cx, y - cy) / maxd)) ** power
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    return img.convert("RGBA")


def vgrad(size, top, bottom):
    w, h = size
    g = Image.new("RGBA", size)
    d = ImageDraw.Draw(g)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return g


def paint(base, mask, fill_img):
    """Paints fill_img onto base through mask (L)."""
    base.alpha_composite(Image.composite(fill_img, Image.new("RGBA", (S, S), (0, 0, 0, 0)), mask))


def shadow(base, mask, offset=(10, 14), blur=14, alpha=170):
    sh = Image.new("L", (S, S), 0)
    sh.paste(mask, offset)
    sh = sh.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: v * alpha // 255)
    base.alpha_composite(Image.composite(Image.new("RGBA", (S, S), (0, 0, 0, 255)),
                                         Image.new("RGBA", (S, S), (0, 0, 0, 0)), sh))


def outline(mask, width):
    return mask.filter(ImageFilter.MaxFilter(width * 2 + 1))


def vignette(img, strength=150):
    v = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(v)
    for i in range(60):
        a = int(strength * (1 - i / 60) ** 2)
        d.rectangle([i, i, S - 1 - i, S - 1 - i], outline=a, width=1)
    img.alpha_composite(Image.composite(Image.new("RGBA", (S, S), (0, 0, 0, 255)),
                                        Image.new("RGBA", (S, S), (0, 0, 0, 0)), v))


def gear_mask(cx, cy, r_out, r_in, teeth, hole):
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    pts = []
    steps = teeth * 4
    for i in range(steps):
        a0 = 2 * math.pi * i / steps
        r = r_out if i % 4 in (1, 2) else r_in
        # slight taper on the teeth
        for k in (0.0, 1.0):
            a = a0 + (2 * math.pi / steps) * k * (0.82 if r == r_out else 1.0)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=255)
    d.ellipse([cx - hole, cy - hole, cx + hole, cy + hole], fill=0)
    return m


def interact():
    img = radial((44, 92, 120), (8, 20, 30))
    cx, cy = S * 0.5, S * 0.5
    gm = gear_mask(cx, cy, 200, 160, 10, 64)
    shadow(img, gm)
    paint(img, outline(gm, 7), Image.new("RGBA", (S, S), (40, 24, 6, 255)))
    paint(img, gm, vgrad((S, S), (255, 230, 140), (160, 100, 22)))
    # inner ring bevel: a darker ring and a highlight arc
    ring = Image.new("L", (S, S), 0)
    ImageDraw.Draw(ring).ellipse([cx - 120, cy - 120, cx + 120, cy + 120], outline=255, width=16)
    paint(img, Image.composite(ring, Image.new("L", (S, S), 0), gm), Image.new("RGBA", (S, S), (120, 72, 14, 255)))
    hl = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hl).arc([cx - 178, cy - 178, cx + 178, cy + 178], 200, 320, fill=200, width=14)
    hl = hl.filter(ImageFilter.GaussianBlur(4))
    paint(img, Image.composite(hl, Image.new("L", (S, S), 0), gm), Image.new("RGBA", (S, S), (255, 250, 220, 255)))
    vignette(img)
    return img


def clip():
    img = radial((150, 40, 60), (26, 6, 14))
    # the board
    bx0, by0, bx1, by1 = 92, 210, 420, 430
    board = Image.new("L", (S, S), 0)
    ImageDraw.Draw(board).rounded_rectangle([bx0, by0, bx1, by1], 18, fill=255)
    # the hinged arm, tilted up
    arm = Image.new("L", (S, S), 0)
    ImageDraw.Draw(arm).rounded_rectangle([bx0, 150, bx1, 205], 10, fill=255)
    arm = arm.rotate(-14, center=(bx0, 205), resample=Image.BICUBIC)
    top = Image.new("L", (S, S), 0)
    ImageDraw.Draw(top).rectangle([bx0, by0, bx1, by0 + 50], fill=255)
    both = Image.composite(Image.new("L", (S, S), 255), arm, board)
    shadow(img, both)
    paint(img, outline(both, 7), Image.new("RGBA", (S, S), (10, 8, 12, 255)))
    paint(img, board, vgrad((S, S), (70, 70, 82), (30, 30, 38)))
    # stripes on the arm and on the board's top band
    stripes = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(stripes)
    for i in range(-4, 12):
        x = bx0 + i * 56
        d.polygon([(x, 120), (x + 28, 120), (x + 128, 470), (x + 100, 470)], fill=255)
    black = vgrad((S, S), (34, 34, 40), (20, 20, 26))
    white = vgrad((S, S), (250, 248, 240), (205, 200, 190))
    for part in (arm, top):
        paint(img, part, black)
        paint(img, Image.composite(stripes, Image.new("L", (S, S), 0), part), white)
    # the line between band and board, and the record dot
    ImageDraw.Draw(img).line([(bx0, by0 + 52), (bx1, by0 + 52)], fill=(10, 8, 12, 255), width=6)
    dot = Image.new("L", (S, S), 0)
    ImageDraw.Draw(dot).ellipse([206, 296, 306, 396], fill=255)
    paint(img, outline(dot, 8), Image.new("RGBA", (S, S), (255, 150, 170, 255)))
    paint(img, dot, vgrad((S, S), (255, 96, 96), (190, 20, 30)))
    hl = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hl).ellipse([226, 310, 262, 340], fill=170)
    paint(img, hl.filter(ImageFilter.GaussianBlur(5)), Image.new("RGBA", (S, S), (255, 230, 230, 255)))
    vignette(img)
    return img


for name, fn in (("interact", interact), ("clip", clip)):
    big = fn()
    big.save(f"{OUT}/{name}-512.png")
    small = big.resize((64, 64), Image.LANCZOS).convert("RGBA")
    small.save(f"{OUT}/{name}.tga")
    small.resize((256, 256), Image.NEAREST).save(f"{OUT}/{name}-preview.png")
print("ok")
