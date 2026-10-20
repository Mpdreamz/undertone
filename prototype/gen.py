"""Prototype renderer: every style, tonality and overlay Undertone draws, in numpy. The Swift renderer ports this;
it is kept as the reference the snapshots were judged against. python3 -m venv .venv && .venv/bin/pip install
numpy pillow scipy && .venv/bin/python gen.py [styles|tones|spaces|options]."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy.ndimage import map_coordinates, gaussian_filter
import sys, os

W, H = 1512, 982  # 14" MacBook Pro in points
FONT = "/System/Library/Fonts/SFNS.ttf"

# ---------- colour ----------
def hx(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) / 255 for i in (0, 2, 4)])

def to_lin(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)

M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566], [0.0883024619, 0.2817188376, 0.6299787005]])
M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099], [0.0259040371, 0.7827717662, -0.8086757660]])
def oklab(rgb): return np.cbrt(to_lin(rgb) @ M1.T) @ M2.T
def from_oklab(lab): return to_srgb((((lab @ np.linalg.inv(M2).T) ** 3) @ np.linalg.inv(M1).T))

def ramp(t, cols):
    """Map t in [0,1] through the colours, interpolated in OkLab."""
    labs = np.array([oklab(c) for c in cols])
    xs = np.linspace(0, 1, len(cols))
    t = np.clip(t, 0, 1)
    out = np.stack([np.interp(t, xs, labs[:, i]) for i in range(3)], -1)
    return from_oklab(out)

# ---------- tonalities ----------
# dark: base + accents; light: base + accents. Each is the same family in the other theme.
TONES = {
    "ember":   dict(dark=["#08090B", "#3D2C10", "#FFB03D", "#A96BFF", "#2A1A4D"],
                    light=["#FBF6EE", "#FFE2B0", "#FFB03D", "#C9A6FF", "#F3E9FF"]),
    "tide":    dict(dark=["#05080F", "#0B2545", "#1F6FEB", "#36C5F0", "#0A3D62"],
                    light=["#F2F7FC", "#CFE6FF", "#6FA8FF", "#8EE3F5", "#E4F1FF"]),
    "aurora":  dict(dark=["#04090A", "#08332E", "#2EE6A6", "#7B5CFF", "#0E1F3D"],
                    light=["#F1FAF7", "#C4F2E0", "#5FE0B2", "#B9A8FF", "#E6F4FF"]),
    "dusk":    dict(dark=["#0B0710", "#3A1030", "#FF5E7E", "#FF9F45", "#2B1650"],
                    light=["#FFF5F3", "#FFD3DA", "#FF8FA3", "#FFC48A", "#EADCFF"]),
    "moss":    dict(dark=["#070906", "#1E2A14", "#9BC53D", "#E0C55A", "#123124"],
                    light=["#F6F8F0", "#E0EBC8", "#A9CF6A", "#F0DC8C", "#D9EEDD"]),
    "glacier": dict(dark=["#07090C", "#1A2230", "#A9C6E8", "#E8EEF6", "#3C4A63"],
                    light=["#F7F9FC", "#E3EAF3", "#B7CBE3", "#FFFFFF", "#D3DCE8"]),
    "citrus":  dict(dark=["#0A0805", "#3B2405", "#FF7A1A", "#FFD23F", "#5C1A1A"],
                    light=["#FFFAF0", "#FFE7B8", "#FF9A4D", "#FFE066", "#FFD6C9"]),
    "mono":    dict(dark=["#060606", "#1A1A1A", "#6E6E6E", "#D9D9D9", "#2C2C2C"],
                    light=["#F7F7F7", "#E4E4E4", "#BDBDBD", "#FFFFFF", "#D0D0D0"]),
}
def tone(name, theme): return [hx(c) for c in TONES[name][theme]]

# ---------- noise ----------
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
U, V = xx / W, yy / H          # 0..1
A = W / H
UX = U * A                     # aspect-correct x

def noise(x, y, freq, rng):
    g = rng.random((freq + 4, freq + 4)).astype(np.float32)
    g[-4:, :] = g[:4, :]; g[:, -4:] = g[:, :4]
    return map_coordinates(g, [(y * freq) % freq, (x * freq) % freq], order=3, mode="grid-wrap")

def fbm(x, y, rng, freq=2, oct=4):
    v, amp, tot = 0, 1, 0
    for i in range(oct):
        v = v + amp * noise(x, y, freq * 2 ** i, rng); tot += amp; amp *= 0.5
    return v / tot

def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)

def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t

def fill(c): return np.broadcast_to(c, (H, W, 3)).astype(np.float32).copy()

# ---------- styles ----------
def s_mesh(p, rng, dark):
    """curb's technique: soft radial blobs over the base."""
    img = fill(p[0])
    for i in range(6):
        cx, cy = rng.uniform(-0.1, A + 0.1), rng.uniform(-0.1, 1.1)
        r = 0.3 + rng.random() * 0.45
        col = p[[2, 3, 2, 3, 4, 1][i]]
        a = (0.7 if dark else 0.75) * rng.uniform(0.45, 1)
        d = np.hypot(UX - cx, V - cy) / r
        img = mix(img, col, a * np.exp(-d * d * 2.2))
    return img

def s_flow(p, rng, dark):
    """Domain-warped noise through the palette ramp: liquid marbling."""
    qx = fbm(U, V, rng, 1, 3); qy = fbm(U + 5.2, V + 1.3, rng, 1, 3)
    f = fbm(U + 1.1 * qx, V + 1.1 * qy, rng, 1, 3)
    f = smooth(0.25, 0.8, f)
    cols = [p[0], p[1], p[3], p[2], p[4]] if dark else [p[0], p[4], p[3], p[2], p[1]]
    img = ramp(f, cols)
    if dark: img = mix(img, p[0], 0.45 * smooth(0.2, 0.9, V))
    return img

def s_waves(p, rng, dark):
    """Layered ribbons with a lit edge, back to front."""
    img = ramp(V * 0.9, [p[0], p[1]] if dark else [p[0], p[4]])
    n = 6
    for i in range(n):
        base = 0.25 + i * 0.12
        ph, fr = rng.random() * 6.28, rng.uniform(1.2, 2.6)
        y0 = base + 0.07 * np.sin(UX * fr + ph) + 0.04 * np.sin(UX * fr * 2.3 + ph * 1.7)
        t = i / (n - 1)
        col = ramp(np.array(t), [p[1], p[3], p[2], p[4]] if dark else [p[4], p[3], p[2], p[1]])
        body = smooth(0, 0.004, V - y0)
        shade = 1 - 0.35 * smooth(0, 0.35, V - y0)
        layer = col * shade[..., None] if dark else mix(col, p[0], 0.3 * smooth(0, 0.4, V - y0))
        rim = np.exp(-((V - y0) / 0.006) ** 2) * (0.35 if dark else 0.5)
        shadow = np.exp(-np.clip(y0 - V, 0, None) / 0.03) * (V < y0) * (0.35 if dark else 0.12)
        img = mix(img, np.zeros(3), shadow)
        img = mix(img, layer, body)
        img = mix(img, np.ones(3), rim * body)
    return img

def s_orbs(p, rng, dark):
    """Large overlapping spheres with soft light, like glass marbles."""
    img = s_mesh(p, rng, dark) * (0.6 if dark else 1)
    for _ in range(5):
        cx, cy, r = rng.uniform(0.1, A - 0.1), rng.uniform(0.1, 0.9), rng.uniform(0.12, 0.34)
        col = p[rng.integers(2, 5)]
        d = np.hypot(UX - cx, V - cy)
        inside = smooth(r + 0.003, r - 0.003, d)
        lx, ly = cx - r * 0.35, cy - r * 0.4
        light = np.exp(-(np.hypot(UX - lx, V - ly) / (r * 0.9)) ** 2)
        sphere = mix(col * (0.35 if dark else 0.75), np.minimum(col * 1.25, 1), light)
        glow = np.exp(-np.clip(d - r, 0, None) / 0.05) * (1 - inside) * 0.25
        img = mix(img, col, glow)
        img = mix(img, sphere, inside * 0.92)
    return img

def s_rings(p, rng, dark):
    """Concentric bands from an off-screen centre, each band a soft cylinder."""
    cx, cy = rng.choice([-0.2, A + 0.2]), rng.uniform(0.9, 1.4)
    d = np.hypot(UX - cx, V - cy)
    band = 0.11
    k = d / band
    idx, fr = np.floor(k), k - np.floor(k)
    cols = [p[1], p[3], p[2], p[4], p[1]] if dark else [p[4], p[3], p[2], p[1], p[4]]
    t = (idx % 9) / 8
    col = ramp(t, cols)
    shade = 0.55 + 0.45 * np.sin(fr * np.pi)
    img = col * (shade[..., None] if dark else (0.8 + 0.2 * shade)[..., None])
    img = mix(img, p[0], 0.65 * smooth(0.6, 2.4, d) if dark else 0.5 * smooth(0.8, 2.6, d))
    return img

def s_dunes(p, rng, dark):
    """Stacked hills, each lit from above, receding into haze."""
    sky = ramp(V, [p[1], p[0]] if dark else [p[4], p[0]])
    img = sky
    n = 7
    for i in range(n):
        y0 = 0.3 + i * 0.1 + 0.08 * (fbm(UX * 0.4 + i * 3.1, np.full_like(U, i * 0.7), rng, 2, 3) - 0.5) * 2
        t = i / (n - 1)
        col = ramp(np.array(t), [p[4], p[3], p[2], p[1], p[0]] if dark else [p[3], p[2], p[1], p[4], p[0]])
        body = smooth(0, 0.003, V - y0)
        lit = mix(np.minimum(col * 1.3 + 0.03, 1), col, smooth(0, 0.12, V - y0))
        img = mix(img, np.zeros(3), np.exp(-np.clip(y0 - V, 0, None) / 0.04) * (V < y0) * 0.25)
        img = mix(img, lit, body)
    return img

def s_contour(p, rng, dark):
    """Topographic lines over a soft gradient."""
    bg = s_mesh(p, rng, dark) * (0.55 if dark else 1)
    f = fbm(U * 1.2, V * 1.2, rng, 2, 4)
    levels = f * 26
    fr = np.abs(levels - np.round(levels))
    px = np.hypot(*np.gradient(levels))  # line width in pixels
    line = smooth(1.1, 0.2, fr / np.maximum(px, 1e-4))
    major = (np.round(levels) % 5 == 0)
    a = line * np.where(major, 0.55, 0.22)
    lc = p[2] if dark else p[1] * 0.6
    return mix(bg, lc, a)

def s_silk(p, rng, dark):
    """Twisting ribbons with a sheen across their width."""
    img = s_mesh(p, rng, dark) * (0.7 if dark else 1)
    for j in range(3):
        ph, fr = rng.random() * 6.28, rng.uniform(1.0, 2.0)
        c = 0.3 + j * 0.2 + 0.18 * np.sin(UX * fr + ph)
        w = 0.06 + 0.07 * np.abs(np.sin(UX * 1.3 + ph * 0.5 + j))
        t = (V - c) / w + 0.5
        on = smooth(-0.01, 0.02, t) * smooth(1.01, 0.98, t)
        twist = np.cos(UX * 1.3 + ph * 0.5 + j)
        sheen = 0.5 + 0.5 * np.cos((t - 0.5 + 0.3 * twist) * np.pi * 1.4)
        col = ramp(U, [p[2], p[3], p[4]] if dark else [p[3], p[2], p[1]])
        rib = col * (0.35 + 0.75 * sheen[..., None]) if dark else mix(col * 0.82, np.ones(3), sheen * 0.7)
        img = mix(img, np.zeros(3), (0.25 if dark else 0.08) * np.exp(-((V - c - w * 0.6) / 0.05) ** 2) * (1 - on))
        img = mix(img, np.clip(rib, 0, 1), on * 0.95)
    return img

def s_aurora(p, rng, dark):
    """Curtains of light hanging from a wandering line."""
    img = ramp(V, [p[0], p[1] * 0.6 + p[0] * 0.4] if dark else [p[4], p[0]])
    for j in range(3):
        cy = 0.35 + j * 0.12 + 0.12 * (fbm(UX * 0.5 + j, np.zeros_like(U) + j, rng, 2, 3) - 0.5) * 2
        streak = fbm(UX * 0.37 + j * 0.31 + 0.02 * V, np.zeros_like(U) + j * 0.2, rng, 7, 4)
        below = np.clip(V - cy, 0, None); above = np.clip(cy - V, 0, None)
        curtain = np.exp(-above / 0.25) * np.exp(-below / 0.03) * (0.4 + 1.2 * streak ** 2)
        col = ramp(np.clip(above / 0.35, 0, 1), [p[2], p[3]] if j % 2 == 0 else [p[3], p[4]])
        img = img + col * curtain[..., None] * 0.8 if dark else mix(img, col, np.clip(curtain * 0.8, 0, 1))
    return np.clip(img, 0, 1)

def s_bauhaus(p, rng, dark):
    """A grid of soft-lit quarter and half circles."""
    img = fill(p[0])
    cols, rows = 6, 4
    cw, ch = A / cols, 1 / rows
    for gy in range(rows):
        for gx in range(cols):
            x0, y0 = gx * cw, gy * ch
            inc = ((UX >= x0) & (UX < x0 + cw) & (V >= y0) & (V < y0 + ch))
            col = p[rng.integers(1, 5)]
            bg = p[rng.integers(0, 5)] if rng.random() < 0.5 else p[0]
            kind = rng.integers(0, 3)
            corner = rng.integers(0, 4)
            ox = x0 + (cw if corner in (1, 2) else 0); oy = y0 + (ch if corner >= 2 else 0)
            if kind == 0:   d = np.hypot(UX - ox, V - oy) / min(cw, ch)      # quarter circle
            elif kind == 1: d = np.hypot(UX - (x0 + cw / 2), V - oy) / (cw / 2)  # half circle
            else:           d = np.hypot(UX - (x0 + cw / 2), V - (y0 + ch / 2)) / (min(cw, ch) * 0.42)
            shape = smooth(1.003, 0.997, d)
            lit = col * (0.75 + 0.25 * (1 - d))[..., None] if dark else mix(col, np.ones(3), 0.25 * (1 - np.clip(d, 0, 1)))
            cell = mix(fill(bg) * (0.9 if dark else 1), lit, shape)
            img = np.where(inc[..., None], cell, img)
    if dark: img = mix(img, p[0], 0.35)
    return img

def s_blobs(p, rng, dark):
    """Metaballs: a lava lamp with soft rims."""
    bg = ramp(V, [p[0], p[1]] if dark else [p[0], p[4]])
    field = np.zeros_like(U)
    for _ in range(9):
        cx, cy, r = rng.uniform(0, A), rng.uniform(0, 1), rng.uniform(0.08, 0.2)
        field += np.exp(-((UX - cx) ** 2 + (V - cy) ** 2) / (r * r))
    field = field * 2.2
    inside = smooth(0.97, 1.03, field)
    col = ramp(U * 0.8 + V * 0.2, [p[2], p[3], p[4]] if dark else [p[3], p[2], p[1]])
    depth = smooth(1, 3.5, field)
    blob = mix(col * 0.55, np.minimum(col * 1.15, 1), depth) if dark else mix(col, np.ones(3), depth * 0.5)
    glow = np.exp(-np.clip(1 - field, 0, None) * 4) * (1 - inside) * (0.35 if dark else 0.2)
    img = mix(bg, col, glow)
    return mix(img, blob, inside)

STYLES = dict(mesh=s_mesh, flow=s_flow, waves=s_waves, orbs=s_orbs, rings=s_rings, dunes=s_dunes,
              contour=s_contour, silk=s_silk, aurora=s_aurora, bauhaus=s_bauhaus, blobs=s_blobs)

# ---------- overlays ----------
def grain(img, rng, amount):
    n = rng.normal(0, 1, (H, W)).astype(np.float32)
    n = gaussian_filter(n, 0.6)
    return np.clip(img + n[..., None] * amount, 0, 1)

def vignette(img, dark):
    d = np.hypot((U - 0.5) * 1.2, V - 0.5)
    return mix(img, np.zeros(3), smooth(0.4, 1.0, d) * (0.35 if dark else 0.08))

def frame(im, notch, corners, menubar=37, radius=18):
    if not (notch or corners): return im
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    top = menubar if notch else 0
    if corners: d.rounded_rectangle([0, top, W - 1, H - 1], radius=radius, fill=255)
    else: d.rectangle([0, top, W, H], fill=255)
    black = Image.new("RGB", (W, H), (0, 0, 0))
    return Image.composite(im, black, mask)

def text(im, title, sub, dark):
    d = ImageDraw.Draw(im, "RGBA")
    fT = ImageFont.truetype(FONT, 76); fT.set_variation_by_axes([100, 60, 400, 600])
    fS = ImageFont.truetype(FONT, 22); fS.set_variation_by_axes([100, 17, 400, 500])
    fg = (255, 255, 255, 235) if dark else (20, 20, 24, 225)
    sg = (255, 255, 255, 150) if dark else (20, 20, 24, 140)
    cy = H * 0.46
    d.text((W / 2, cy), title, font=fT, fill=fg, anchor="ms")
    d.text((W / 2, cy + 44), sub.upper(), font=fS, fill=sg, anchor="ms", spacing=4)
    return im

def render(style, tname, theme, seed, notch=False, corners=False, grain_amt=0.035, title=None, sub=None):
    rng = np.random.default_rng(seed)
    dark = theme == "dark"
    p = tone(tname, theme)
    img = STYLES[style](p, rng, dark)
    img = vignette(img, dark)
    if grain_amt: img = grain(img, rng, grain_amt)
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    if title: im = text(im, title, sub or "", dark)
    return frame(im, notch, corners)

def sheet(items, cols, path, label=True, scale=0.25):
    tw, th = int(W * scale), int(H * scale)
    gap, lh = 14, (26 if label else 0)
    rows = (len(items) + cols - 1) // cols
    S = Image.new("RGB", (cols * tw + (cols + 1) * gap, rows * (th + lh) + (rows + 1) * gap), (24, 24, 26))
    d = ImageDraw.Draw(S); f = ImageFont.truetype(FONT, 15)
    for i, (lab, im) in enumerate(items):
        x = gap + (i % cols) * (tw + gap); y = gap + (i // cols) * (th + lh + gap)
        S.paste(im.resize((tw, th), Image.LANCZOS), (x, y))
        if label: d.text((x, y + th + 5), lab, font=f, fill=(200, 200, 205))
    S.save(path)

if __name__ == "__main__":
    out = "out"; os.makedirs(out, exist_ok=True)
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    pick = {"mesh": "ember", "flow": "dusk", "waves": "tide", "orbs": "aurora", "rings": "citrus", "dunes": "dusk",
            "contour": "glacier", "silk": "ember", "aurora": "aurora", "bauhaus": "moss", "blobs": "dusk"}
    if which in ("all", "styles"):
        for theme in ("dark", "light"):
            items = []
            for k, (s, t) in enumerate(pick.items()):
                im = render(s, t, theme, 11 + k)
                im.save(f"{out}/{s}-{t}-{theme}.png"); items.append((f"{s} · {t} · {theme}", im))
            sheet(items, 3, f"{out}/sheet-styles-{theme}.png")
    if which in ("all", "tones"):
        items = []
        for t in TONES:
            for theme in ("dark", "light"):
                items.append((f"flow · {t} · {theme}", render("flow", t, theme, 7)))
        sheet(items, 4, f"{out}/sheet-tones-flow.png")
        items = []
        for i, t in enumerate(TONES):
            for s, th in (("mesh", "dark"), ("waves", "dark"), ("blobs", "light"), ("dunes", "light")):
                items.append((f"{s} · {t} · {th}", render(s, t, th, 30 + i)))
        sheet(items, 4, f"{out}/sheet-tones-mixed.png", scale=0.22)
    if which in ("all", "spaces"):
        items = [(f"space {i + 1} · waves · tide", render("waves", "tide", "dark", 100 + i, notch=True, corners=True)) for i in range(3)]
        items += [(f"space {i + 4} · dunes · tide", render("dunes", "tide", "dark", 200 + i, notch=True, corners=True)) for i in range(3)]
        sheet(items, 3, f"{out}/sheet-spaces.png")
    if which in ("all", "options"):
        base = dict(style="flow", tname="aurora", theme="dark", seed=42)
        items = [("plain", render(**base, grain_amt=0)),
                 ("grain", render(**base, grain_amt=0.06)),
                 ("hide notch", render(**base, notch=True)),
                 ("notch + round corners", render(**base, notch=True, corners=True)),
                 ("text", render(**base, notch=True, corners=True, title="workstation", sub="macOS 26 · arm64")),
                 ("text · light", render("mesh", "ember", "light", 5, notch=True, corners=True, title="workstation", sub="macOS 26 · arm64"))]
        sheet(items, 3, f"{out}/sheet-options.png")
        render(**base, notch=True, corners=True, grain_amt=0.05, title="workstation", sub="macOS 26 · arm64").save(f"{out}/hero-dark.png")
        render("silk", "dusk", "light", 9, notch=True, corners=True, grain_amt=0.04, title="workstation", sub="macOS 26 · arm64").save(f"{out}/hero-light.png")
