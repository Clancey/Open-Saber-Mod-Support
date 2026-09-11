"""Procedural gameplay textures: drawn from scratch with PIL/numpy at the
sizes the shaders and materials expect."""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r"D:\Projects\Open-Saber-Mod-Support\game\assets\beatsaber\textures"
rng = np.random.default_rng(7)

def save_rgba(name, alpha, rgb=255):
    h, w = alpha.shape
    a = alpha.clip(0, 1) * 255
    rgbarr = np.full((h, w, 3), rgb, np.uint8) if np.isscalar(rgb) else rgb
    Image.fromarray(np.dstack([rgbarr, a.astype(np.uint8)]), "RGBA").save(os.path.join(OUT, name))

def blur(a, r):
    return np.asarray(Image.fromarray((a.clip(0, 1) * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(r))).astype(float) / 255.0

# arrow_glow 256x128: soft glow in the shape of the note arrow (a flat chevron)
def arrow_glow():
    w, h = 256, 128
    img = Image.new("L", (w * 3, h * 3), 0)
    d = ImageDraw.Draw(img)
    d.polygon([(52 * 3, 42 * 3), (204 * 3, 42 * 3), (128 * 3, 92 * 3)], fill=255)
    core = np.asarray(img.resize((w, h), Image.LANCZOS)).astype(float) / 255.0
    a = np.maximum(core, blur(core, 9) * 1.1)
    save_rgba("arrow_glow.png", a)

# note_circle_glow 256x256: radial glow for dot notes
def circle_glow():
    n = 256
    y, x = np.mgrid[0:n, 0:n]
    r = np.hypot(x - n / 2 + 0.5, y - n / 2 + 0.5) / (n / 2)
    core = (r < 0.36).astype(float)
    a = np.maximum(core, blur(core, 12) * 1.2)
    save_rgba("note_circle_glow.png", a)

# obstacle_fake_glow 600x600: glowing rounded square outline (wall frame glow)
def obstacle_glow():
    n = 600
    img = Image.new("L", (n, n), 0)
    ImageDraw.Draw(img).rounded_rectangle((70, 70, n - 70, n - 70), radius=18, outline=255, width=10)
    core = np.asarray(img).astype(float) / 255.0
    a = np.maximum(core, np.maximum(blur(core, 8) * 1.0, blur(core, 28) * 0.7))
    save_rgba("obstacle_fake_glow.png", a)

# laser_glow_0 / laser_glow_1 64x128: soft vertical glow strips (thin / wide)
def laser_glow(name, width_frac, blur_r):
    w, h = 64, 128
    y, x = np.mgrid[0:h, 0:w]
    cx = (x - w / 2 + 0.5) / (w / 2)
    cy = (y - h / 2 + 0.5) / (h / 2)
    core = ((np.abs(cx) < width_frac) & (np.abs(cy) < 0.82)).astype(float)
    ends = np.clip(1.0 - (np.abs(cy) - 0.6) / 0.25, 0, 1)
    a = np.maximum(core, blur(core, blur_r)) * ends
    save_rgba(name, a)

# blade_noise 512x512: tileable low-frequency value noise for the blade flicker
def blade_noise():
    n = 512
    base = rng.random((16, 16))
    tiled = np.tile(base, (3, 3))
    big = np.asarray(Image.fromarray((tiled * 255).astype(np.uint8), "L").resize((n * 3, n * 3), Image.BICUBIC)).astype(float) / 255.0
    a = big[n:2 * n, n:2 * n]
    a = (a - a.min()) / (a.max() - a.min())
    save_rgba("blade_noise.png", np.ones_like(a), rgb=np.dstack([a * 255] * 3).astype(np.uint8))

# floor_grid_dirt 512x512: tileable grid lines with faint diagonal scratches
def floor_grid():
    n = 512
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    for i in range(0, n, 128):
        d.line([(i, 0), (i, n)], fill=200, width=2)
        d.line([(0, i), (n, i)], fill=200, width=2)
    grid = np.asarray(img).astype(float) / 255.0
    y, x = np.mgrid[0:n, 0:n]
    scratches = ((np.sin((x + y) * 0.9) > 0.85).astype(float) * 0.25)
    noise = blur(rng.random((n, n)), 3) * 0.2
    a = np.clip(grid + scratches + noise, 0, 1)
    save_rgba("floor_grid_dirt.png", a)

# full_trail 128x128 RGB: vertical gradient used by the saber trail shader
def full_trail():
    n = 128
    y = np.linspace(0.0, 1.0, n)[:, None]
    g = np.repeat(np.clip((y - 0.15) / 0.85, 0, 1) ** 1.3, n, axis=1)
    arr = (g * 255).astype(np.uint8)
    Image.fromarray(np.dstack([arr, arr, arr]), "RGB").save(os.path.join(OUT, "full_trail.png"))

# notes_reflection 512x512: soft blobby environment reflection for the note shader
def notes_reflection():
    n = 512
    blobs = np.zeros((n, n))
    y, x = np.mgrid[0:n, 0:n]
    for _ in range(14):
        cx, cy = rng.random(2) * n
        r = 40 + rng.random() * 120
        blobs += np.exp(-(((x - cx) ** 2 + (y - cy) ** 2) / (2 * r * r))) * (0.4 + rng.random() * 0.8)
    a = (blobs - blobs.min()) / (blobs.max() - blobs.min())
    a = blur(a, 6)
    save_rgba("notes_reflection.png", np.ones_like(a), rgb=np.dstack([a * 255] * 3).astype(np.uint8))

if __name__ == "__main__":
    arrow_glow(); circle_glow(); obstacle_glow()
    laser_glow("laser_glow_0.png", 0.12, 6); laser_glow("laser_glow_1.png", 0.2, 4)
    blade_noise(); floor_grid(); full_trail(); notes_reflection()
    print("textures written")
