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


def downtime():
    """Downtime's menu (camp, hearths, professions between fights): a campfire at dusk, in Downtime's purple."""
    img = radial((96, 60, 150), (16, 8, 34), centre=(0.5, 0.62))
    # the glow on the ground
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([96, 300, 416, 470], fill=150)
    paint(img, glow.filter(ImageFilter.GaussianBlur(40)), Image.new("RGBA", (S, S), (255, 150, 60, 255)))
    # two crossed logs
    logs = Image.new("L", (S, S), 0)
    for ang in (18, -18):
        log = Image.new("L", (S, S), 0)
        ImageDraw.Draw(log).rounded_rectangle([110, 380, 402, 430], 24, fill=255)
        logs = Image.composite(Image.new("L", (S, S), 255), logs, log.rotate(ang, center=(256, 405), resample=Image.BICUBIC))
    shadow(img, logs)
    paint(img, outline(logs, 6), Image.new("RGBA", (S, S), (24, 10, 4, 255)))
    paint(img, logs, vgrad((S, S), (150, 92, 50), (80, 44, 20)))
    # the flame: three tongues, outer orange, inner yellow, a white-hot core
    def flame(cx, base, w, h):
        m = Image.new("L", (S, S), 0)
        d = ImageDraw.Draw(m)
        d.ellipse([cx - w, base - w * 1.2, cx + w, base + w * 0.5], fill=255)
        d.polygon([(cx - w * 0.98, base - w * 0.5), (cx + w * 0.98, base - w * 0.5), (cx + w * 0.15, base - h), (cx - w * 0.1, base - h * 0.96)], fill=255)
        return m.filter(ImageFilter.GaussianBlur(3))
    outer = flame(256, 380, 112, 330)
    for side, (dx, sh) in enumerate(((-70, 220), (72, 240))):
        outer = Image.composite(Image.new("L", (S, S), 255), outer, flame(256 + dx, 385, 60, sh))
    paint(img, outer.filter(ImageFilter.GaussianBlur(10)), Image.new("RGBA", (S, S), (255, 120, 30, 255)))
    paint(img, outer, vgrad((S, S), (255, 170, 40), (230, 70, 20)))
    paint(img, flame(256, 385, 70, 230), vgrad((S, S), (255, 235, 120), (255, 160, 40)))
    paint(img, flame(256, 390, 34, 130), Image.new("RGBA", (S, S), (255, 252, 230, 255)))
    vignette(img)
    return img


def hideui():
    """Toggle the UI: an eye with a slash, on night blue."""
    img = radial((52, 70, 120), (8, 12, 28))
    eye = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(eye)
    d.ellipse([70, 150, 442, 362], fill=255)
    # almond shape: cut by two big circles
    cut = Image.new("L", (S, S), 0)
    dc = ImageDraw.Draw(cut)
    dc.ellipse([-60, 40, 572, 560], fill=255)
    dc2 = Image.new("L", (S, S), 0)
    ImageDraw.Draw(dc2).ellipse([-60, -48, 572, 472], fill=255)
    from PIL import ImageChops
    eye = ImageChops.multiply(ImageChops.multiply(eye, cut), dc2)
    shadow(img, eye)
    paint(img, outline(eye, 7), Image.new("RGBA", (S, S), (10, 10, 20, 255)))
    paint(img, eye, vgrad((S, S), (250, 250, 245), (200, 205, 215)))
    iris = Image.new("L", (S, S), 0)
    ImageDraw.Draw(iris).ellipse([196, 196, 316, 316], fill=255)
    paint(img, iris, vgrad((S, S), (110, 200, 255), (30, 90, 170)))
    pupil = Image.new("L", (S, S), 0)
    ImageDraw.Draw(pupil).ellipse([230, 230, 282, 282], fill=255)
    paint(img, pupil, Image.new("RGBA", (S, S), (8, 10, 20, 255)))
    hl = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hl).ellipse([236, 214, 262, 240], fill=230)
    paint(img, hl, Image.new("RGBA", (S, S), (255, 255, 255, 255)))
    # the slash
    sl = Image.new("L", (S, S), 0)
    ImageDraw.Draw(sl).line([(110, 420), (402, 92)], fill=255, width=40)
    paint(img, outline(sl, 7), Image.new("RGBA", (S, S), (20, 4, 4, 255)))
    paint(img, sl, vgrad((S, S), (255, 90, 80), (190, 30, 30)))
    vignette(img)
    return img


def foot(img, cx, cy, ang, scale, colour):
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    k = scale
    d.ellipse([cx - 34 * k, cy - 40 * k, cx + 34 * k, cy + 50 * k], fill=255)       # sole
    d.ellipse([cx - 28 * k, cy + 52 * k, cx + 28 * k, cy + 96 * k], fill=255)       # heel
    for i, (dx, dy, r) in enumerate(((-30, -62, 12), (-12, -74, 13), (8, -76, 13), (26, -68, 12), (40, -52, 10))):
        d.ellipse([cx + (dx - r) * k, cy + (dy - r) * k, cx + (dx + r) * k, cy + (dy + r) * k], fill=255)
    m = m.rotate(ang, center=(cx, cy), resample=Image.BICUBIC)
    shadow(img, m, offset=(6, 8), blur=8)
    paint(img, outline(m, 5), Image.new("RGBA", (S, S), (20, 12, 4, 255)))
    paint(img, m, colour)


def follow():
    """Follow your target: two pairs of footprints walking up, on green."""
    img = radial((60, 120, 70), (10, 30, 14))
    col = vgrad((S, S), (250, 225, 160), (190, 140, 70))
    foot(img, 200, 380, 8, 0.9, col)
    foot(img, 312, 270, -8, 0.9, col)
    foot(img, 200, 160, 8, 0.9, col)
    vignette(img)
    return img


def sit():
    """Sit / stand: a wooden chair seen from the side (the front view read as a ladder: his "why is alt x a ladder lmao"),
    on warm brown."""
    img = radial((150, 100, 60), (36, 20, 10))
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    d.polygon([(150, 60), (196, 60), (214, 300), (168, 300)], fill=255)   # the back, leaning back a little
    d.rounded_rectangle([150, 270, 390, 318], 12, fill=255)              # the seat
    d.rounded_rectangle([158, 300, 200, 452], 10, fill=255)              # back leg
    d.rounded_rectangle([340, 300, 382, 452], 10, fill=255)              # front leg
    d.rounded_rectangle([170, 380, 370, 402], 8, fill=255)               # stretcher
    shadow(img, m)
    paint(img, outline(m, 7), Image.new("RGBA", (S, S), (30, 14, 4, 255)))
    paint(img, m, vgrad((S, S), (230, 170, 100), (140, 82, 36)))
    # a red cushion on the seat
    c = Image.new("L", (S, S), 0)
    ImageDraw.Draw(c).rounded_rectangle([196, 236, 384, 280], 20, fill=255)
    paint(img, outline(c, 6), Image.new("RGBA", (S, S), (40, 6, 6, 255)))
    paint(img, c, vgrad((S, S), (220, 70, 60), (140, 30, 30)))
    vignette(img)
    return img


def autorun():
    """Auto run: a winged boot, on sky blue."""
    img = radial((70, 140, 200), (10, 30, 60))
    wing = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(wing)
    for i in range(4):
        d.ellipse([230 + i * 18, 90 + i * 44, 460 - i * 10, 150 + i * 44], fill=255)
    wing = wing.rotate(-12, center=(300, 200), resample=Image.BICUBIC)
    boot = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(boot)
    d.rounded_rectangle([150, 120, 280, 360], 26, fill=255)      # shaft
    d.rounded_rectangle([110, 320, 400, 420], 40, fill=255)      # foot
    d.rectangle([100, 400, 410, 432], fill=255)                  # sole
    shadow(img, Image.composite(Image.new("L", (S, S), 255), wing, boot))
    paint(img, outline(wing, 6), Image.new("RGBA", (S, S), (20, 30, 50, 255)))
    paint(img, wing, vgrad((S, S), (255, 255, 255), (190, 210, 230)))
    paint(img, outline(boot, 7), Image.new("RGBA", (S, S), (24, 12, 4, 255)))
    paint(img, boot, vgrad((S, S), (190, 120, 60), (110, 60, 24)))
    band = Image.new("L", (S, S), 0)
    ImageDraw.Draw(band).rectangle([150, 150, 280, 178], fill=255)
    paint(img, Image.composite(band, Image.new("L", (S, S), 0), boot), Image.new("RGBA", (S, S), (240, 200, 90, 255)))
    vignette(img)
    return img


def assist():
    """Assist: take your friend's target. Red crosshairs over a target ring, on dark teal."""
    img = radial((40, 110, 110), (6, 24, 26))
    cx, cy = S / 2, S / 2
    ring = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(ring)
    d.ellipse([cx - 170, cy - 170, cx + 170, cy + 170], outline=255, width=34)
    d.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], fill=255)
    for x0, y0, x1, y1 in ((cx - 17, 40, cx + 17, 170), (cx - 17, S - 170, cx + 17, S - 40),
                           (40, cy - 17, 170, cy + 17), (S - 170, cy - 17, S - 40, cy + 17)):
        d.rounded_rectangle([x0, y0, x1, y1], 8, fill=255)
    shadow(img, ring)
    paint(img, outline(ring, 7), Image.new("RGBA", (S, S), (24, 4, 4, 255)))
    paint(img, ring, vgrad((S, S), (255, 110, 90), (190, 30, 30)))
    vignette(img)
    return img


for name, fn in (("interact", interact), ("assist", assist), ("clip", clip), ("downtime", downtime), ("hideui", hideui), ("follow", follow),
                 ("sit", sit), ("autorun", autorun)):
    big = fn()
    big.save(f"{OUT}/{name}-512.png")
    small = big.resize((64, 64), Image.LANCZOS).convert("RGBA")
    small.save(f"{OUT}/{name}.tga")
    small.resize((256, 256), Image.NEAREST).save(f"{OUT}/{name}-preview.png")
print("ok")
