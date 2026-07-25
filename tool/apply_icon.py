"""Word Sprint icons from the ORIGINAL running-book art (no title text), which
is already on a black background.
- Android launcher: book on BLACK, rounded.
- Adaptive foreground: book on black, safe-zone.
- iOS: book on BLACK, full square, opaque.
- In-app logo: book on TRANSPARENT (black knocked out)."""
from PIL import Image, ImageDraw

SZ = 1024
SRC = r"C:\Users\timga\OneDrive\Desktop\Sprinting Dictionary.png"

src = Image.open(SRC).convert("RGBA")  # book on black


def on_black(content_px, radius, out):
    canvas = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 255))
    art = src.resize((content_px, content_px), Image.LANCZOS)
    off = (SZ - content_px) // 2
    canvas.paste(art, (off, off))
    if radius > 0:
        mask = Image.new("L", (SZ, SZ), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, SZ - 1, SZ - 1], radius=radius, fill=255)
        result = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
        result.paste(canvas, (0, 0), mask)
        result.save(out)
    else:
        canvas.save(out)
    print("wrote", out)


def transparent_logo(content_frac, out):
    im = src.copy()
    w, h = im.size
    for s in [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2),
              (w // 2, 1), (w // 2, h - 2), (1, h // 2), (w - 2, h // 2)]:
        ImageDraw.floodfill(im, s, (0, 0, 0, 0), thresh=60)
    m = im.crop(im.getbbox())
    canvas = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    target = int(SZ * content_frac)
    ratio = target / max(m.size)
    m = m.resize((int(m.size[0] * ratio), int(m.size[1] * ratio)),
                 Image.LANCZOS)
    canvas.alpha_composite(m, ((SZ - m.size[0]) // 2, (SZ - m.size[1]) // 2))
    canvas.save(out)
    print("wrote", out)


on_black(1024, 210, "assets/icon/icon_full.png")  # Android launcher
on_black(640, 0, "assets/icon/icon_fg.png")        # adaptive foreground
on_black(880, 0, "assets/icon/icon_ios.png")       # iOS (opaque square)
transparent_logo(0.96, "assets/icon/logo.png")     # in-app logo
