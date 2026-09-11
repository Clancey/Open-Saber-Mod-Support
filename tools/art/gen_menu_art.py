"""Original artwork for the Open Saber main menu, in the spirit of Beat Saber's
menu but drawn from scratch: gradient tiles with saber-wielding silhouettes,
ring icons, and neon stroke lettering for the logo."""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

OUT = r"D:\Projects\Open-Saber-Mod-Support\game\assets\beatsaber\ui"
FONT = r"C:\Users\james\AppData\Local\Temp\claude\D--Projects-Open-Saber-Mod-Support\66f514bf-f0d7-4c6d-9d62-d125c421c556\scratchpad\fonts\Roboto-Bold.ttf"
SS = 3  # supersampling

# ---------------------------------------------------------------- helpers
def gradient(w, h, top, bottom):
    a = np.linspace(0.0, 1.0, h)[:, None, None]
    arr = (np.array(top)[None, None, :] * (1 - a) + np.array(bottom)[None, None, :] * a)
    arr = np.repeat(arr, w, axis=1)
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")

def rounded_mask(w, h, r):
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * SS - 1, h * SS - 1), radius=r * SS, fill=255)
    return m.resize((w, h), Image.LANCZOS)

def glow_layer(size, draw_fn, color, blur, strength=1.0):
    """draw_fn draws white shapes on an L layer (supersampled); returns an RGBA glow."""
    w, h = size
    layer = Image.new("L", (w * SS, h * SS), 0)
    draw_fn(ImageDraw.Draw(layer))
    layer = layer.resize((w, h), Image.LANCZOS)
    core = layer
    halo = layer.filter(ImageFilter.GaussianBlur(blur))
    alpha = np.maximum(np.asarray(core).astype(float), np.asarray(halo).astype(float) * strength)
    rgb = np.zeros((h, w, 3), dtype=np.uint8); rgb[:, :] = color
    return Image.fromarray(np.dstack([rgb, alpha.clip(0, 255).astype(np.uint8)]), "RGBA")

def silhouette(draw, cx, base_y, scale, pose):
    """A dancer holding two sabers: head, torso, legs, arms. Coordinates in
    supersampled pixels; pose = (left arm angle, right arm angle, lean) in degrees."""
    s = scale * SS
    la, ra, lean = pose
    black = 255
    # torso as a tapered polygon (shoulders wider than hips), slight lean
    shx = cx * SS + math.sin(math.radians(lean)) * 0.55 * s
    shy = base_y * SS - 1.05 * s
    hipy = base_y * SS - 0.55 * s
    hipx = cx * SS
    draw.polygon([(shx - 0.24 * s, shy), (shx + 0.24 * s, shy), (hipx + 0.17 * s, hipy), (hipx - 0.17 * s, hipy)], fill=black)
    # head
    hr = 0.13 * s
    draw.ellipse((shx - hr, shy - 0.30 * s - hr, shx + hr, shy - 0.30 * s + hr), fill=black)
    # neck
    draw.line([(shx, shy - 0.2 * s), (shx, shy)], fill=black, width=int(0.09 * s))
    # legs (one planted, one stepping)
    draw.line([(hipx - 0.1 * s, hipy), (hipx - 0.22 * s, base_y * SS)], fill=black, width=int(0.13 * s))
    draw.line([(hipx + 0.1 * s, hipy), (hipx + 0.3 * s, base_y * SS - 0.05 * s)], fill=black, width=int(0.13 * s))
    # arms with sabers: arm from shoulder along angle, saber continues further
    hands = []
    for side, ang in ((-1, la), (1, ra)):
        sx = shx + side * 0.22 * s
        ex = sx + math.cos(math.radians(ang)) * 0.5 * s
        ey = shy - math.sin(math.radians(ang)) * 0.5 * s
        draw.line([(sx, shy), (ex, ey)], fill=black, width=int(0.1 * s))
        hands.append((ex, ey, ang))
    return hands

def sabers(draw, hands, scale, colors):
    s = scale * SS
    for (hx, hy, ang), color in zip(hands, colors):
        tx = hx + math.cos(math.radians(ang)) * 0.9 * s
        ty = hy - math.sin(math.radians(ang)) * 0.9 * s
        draw.line([(hx, hy), (tx, ty)], fill=color, width=int(0.06 * s))

def tile(name, top, bottom, figures, hover):
    w, h = 304, 500
    boost = 1.0 if hover else 0.55
    bg = gradient(w, h, [c * boost for c in top], [c * boost for c in bottom])
    # soft light rays
    rays = Image.new("L", (w * SS, h * SS), 0)
    rd = ImageDraw.Draw(rays)
    for i in range(6):
        x = 20 + i * 60
        rd.polygon([((x - 40) * SS, 0), ((x + 10) * SS, 0), ((x + 160) * SS, h * SS), ((x + 100) * SS, h * SS)], fill=40)
    rays = rays.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(6))
    rays_rgba = Image.fromarray(np.dstack([np.full((h, w, 3), 255, np.uint8), np.asarray(rays)]), "RGBA")
    bg.alpha_composite(rays_rgba)
    # silhouettes (black) and sabers (glowing)
    sil = Image.new("L", (w * SS, h * SS), 0)
    sd = ImageDraw.Draw(sil)
    hand_sets = []
    for (cx, base, scale, pose) in figures:
        hand_sets.append((silhouette(sd, cx, base, scale, pose), scale))
    sil = sil.resize((w, h), Image.LANCZOS)
    bg.alpha_composite(Image.fromarray(np.dstack([np.zeros((h, w, 3), np.uint8), np.asarray(sil)]), "RGBA"))
    for hands, scale in hand_sets:
        for (hx, hy, ang), color in zip(hands, [(255, 40, 40), (40, 160, 255)]):
            def draw_blade(d, hx=hx, hy=hy, ang=ang, scale=scale):
                s = scale * SS
                tx = hx + math.cos(math.radians(ang)) * 0.95 * s
                ty = hy - math.sin(math.radians(ang)) * 0.95 * s
                d.line([(hx, hy), (tx, ty)], fill=255, width=int(0.055 * s))
            blade = glow_layer((w, h), draw_blade, color, 6 if hover else 4, 1.4 if hover else 0.9)
            bg.alpha_composite(blade)
            core = glow_layer((w, h), draw_blade, (255, 255, 255), 1, 0.0)
            core.putalpha(core.getchannel("A").point(lambda v: int(v * 0.85)))
            bg.alpha_composite(core)
    # rounded corners + slight vignette
    bg.putalpha(rounded_mask(w, h, 14))
    bg.save(os.path.join(OUT, f"tile_{name}{'_hover' if hover else ''}.png"))

def icon(name, draw_glyph, hover):
    w = h = 106
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ring = Image.new("L", (w * SS, h * SS), 0)
    rd = ImageDraw.Draw(ring)
    rd.ellipse((6 * SS, 6 * SS, (w - 6) * SS, (h - 6) * SS), outline=255, width=5 * SS)
    draw_glyph(rd, w * SS, h * SS)
    ring = ring.resize((w, h), Image.LANCZOS)
    level = 255 if hover else 175
    fill = Image.fromarray(np.dstack([np.full((h, w, 3), level, np.uint8), np.asarray(ring)]), "RGBA")
    if hover:
        halo = ring.filter(ImageFilter.GaussianBlur(4))
        img.alpha_composite(Image.fromarray(np.dstack([np.full((h, w, 3), 255, np.uint8), (np.asarray(halo) * 0.6).astype(np.uint8)]), "RGBA"))
    img.alpha_composite(fill)
    img.save(os.path.join(OUT, f"icon_{name}{'_hover' if hover else ''}.png"))

def gear(d, W, H):
    cx, cy = W / 2, H / 2
    r_out, r_in, hub = W * 0.30, W * 0.22, W * 0.09
    pts = []
    teeth = 8
    for i in range(teeth * 2):
        a = math.pi * 2 * i / (teeth * 2)
        r = r_out if i % 2 == 0 else r_in
        for da in (-0.13, 0.13):
            pts.append((cx + math.cos(a + da) * r, cy + math.sin(a + da) * r))
    d.polygon(pts, fill=255)
    d.ellipse((cx - hub, cy - hub, cx + hub, cy + hub), fill=0)

def question(d, W, H):
    f = ImageFont.truetype(FONT, int(W * 0.52))
    bbox = d.textbbox((0, 0), "?", font=f)
    d.text((W / 2 - (bbox[2] + bbox[0]) / 2, H / 2 - (bbox[3] + bbox[1]) / 2), "?", font=f, fill=255)

def pencil(d, W, H):
    cx, cy = W / 2, H / 2
    L, T = W * 0.24, W * 0.075
    ang = math.radians(-45)
    ux, uy = math.cos(ang), math.sin(ang)
    px, py = -uy, ux
    body = [(cx - ux * L + px * T, cy - uy * L + py * T), (cx + ux * L * 0.55 + px * T, cy + uy * L * 0.55 + py * T),
            (cx + ux * L * 0.55 - px * T, cy + uy * L * 0.55 - py * T), (cx - ux * L - px * T, cy - uy * L - py * T)]
    d.polygon(body, fill=255)
    tip = [(cx + ux * L * 0.55 + px * T, cy + uy * L * 0.55 + py * T), (cx + ux * L, cy + uy * L), (cx + ux * L * 0.55 - px * T, cy + uy * L * 0.55 - py * T)]
    d.polygon(tip, fill=255)

def exit_glyph(d, W, H):
    cx, cy = W / 2, H / 2
    s = W * 0.3
    d.rectangle((cx - s, cy - s, cx - s * 0.15, cy + s), outline=255, width=int(W * 0.06))
    d.line([(cx - s * 0.4, cy), (cx + s * 0.9, cy)], fill=255, width=int(W * 0.06))
    d.polygon([(cx + s * 0.95, cy), (cx + s * 0.45, cy - s * 0.4), (cx + s * 0.45, cy + s * 0.4)], fill=255)

# ---------------------------------------------------------------- neon lettering (logo)
def arc(cx, cy, rx, ry, a0, a1, n=24):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

def letter_paths(L):
    if L == "O": return [arc(0.5, 0.5, 0.42, 0.5, 0, 360, 48)]
    if L == "P": return [[(0.1, 1.0), (0.1, 0.0)], [(0.1, 0.0), (0.55, 0.0)] + arc(0.55, 0.27, 0.3, 0.27, -90, 90) + [(0.1, 0.54)]]
    if L == "E": return [[(0.85, 0.0), (0.1, 0.0), (0.1, 1.0), (0.85, 1.0)], [(0.1, 0.5), (0.7, 0.5)]]
    if L == "N": return [[(0.1, 1.0), (0.1, 0.0), (0.9, 1.0), (0.9, 0.0)]]
    if L == "S": return [arc(0.5, 0.27, 0.36, 0.25, -30, -270, 30) + arc(0.5, 0.73, 0.36, 0.25, -90, 200, 32)]
    if L == "A": return [[(0.05, 1.0), (0.5, 0.0), (0.95, 1.0)], [(0.22, 0.64), (0.78, 0.64)]]
    if L == "B": return [[(0.1, 1.0), (0.1, 0.0), (0.5, 0.0)] + arc(0.5, 0.25, 0.32, 0.25, -90, 90) + [(0.1, 0.5), (0.55, 0.5)] + arc(0.55, 0.75, 0.34, 0.25, -90, 90) + [(0.1, 1.0)]]
    if L == "R": return [[(0.1, 1.0), (0.1, 0.0), (0.55, 0.0)] + arc(0.55, 0.27, 0.3, 0.27, -90, 90) + [(0.1, 0.54)], [(0.45, 0.54), (0.9, 1.0)]]
    return []

def neon_text(letters, filename, W=1024, H=256, lh=150, lw=150, gap=1.32, x0=None):
    def shear(p, k=0.2):
        x, y = p; return (x + (H / 2 - y) * k, y)
    total = len(letters) * lw * gap - lw * (gap - 1)
    x0 = (W - total) / 2 if x0 is None else x0
    top = (H - lh) / 2
    img = Image.new("L", (W * SS, H * SS), 0); d = ImageDraw.Draw(img)
    for i, L in enumerate(letters):
        for path in letter_paths(L):
            pts = [shear((x0 + i * lw * gap + px * lw, top + py * lh)) for px, py in path]
            pts = [(x * SS, y * SS) for x, y in pts]
            d.line(pts, fill=255, width=13 * SS, joint="curve")
            for (x, y) in (pts[0], pts[-1]):
                r = 6.5 * SS; d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    core = img.resize((W, H), Image.LANCZOS)
    glow = core.filter(ImageFilter.GaussianBlur(10)); glow2 = core.filter(ImageFilter.GaussianBlur(3))
    a = np.maximum(np.asarray(core).astype(float), np.maximum(np.asarray(glow2).astype(float) * 0.9, np.asarray(glow).astype(float) * 0.7))
    Image.fromarray(np.dstack([np.full((H, W, 3), 255, np.uint8), a.clip(0, 255).astype(np.uint8)]), "RGBA").save(os.path.join(OUT, filename))

# ---------------------------------------------------------------- build everything
if __name__ == "__main__":
    # tiles: (name, top colour, bottom colour, figures[(cx, base_y, scale, (left arm deg, right arm deg, lean))])
    specs = [
        ("solo", (0, 150, 200), (0, 35, 70), [(150, 470, 210, (140, 55, -6))]),
        ("online", (200, 40, 80), (60, 10, 40), [(105, 470, 175, (150, 70, -8)), (215, 455, 150, (120, 30, 8))]),
        ("campaign", (150, 60, 220), (40, 10, 80), [(150, 470, 210, (110, 100, 0))]),
        ("party", (0, 180, 140), (0, 50, 60), [(80, 470, 150, (160, 60, -10)), (160, 480, 175, (130, 40, 0)), (240, 465, 150, (120, 20, 10))]),
    ]
    for name, top, bottom, figs in specs:
        tile(name, top, bottom, figs, False); tile(name, top, bottom, figs, True)
    for name, fn in (("options", gear), ("help", question), ("editor", pencil), ("exit", exit_glyph)):
        icon(name, fn, False); icon(name, fn, True)
    neon_text("OP N", "logo_open.png", x0=60)
    # the E lives in its own sprite so it can flicker; same canvas positions
    neon_text("E", "logo_open_e.png", x0=60 + 2 * 150 * 1.32)
    neon_text("SABER", "logo_saber.png", lh=150, lw=140, gap=1.25)
    print("menu art written")
