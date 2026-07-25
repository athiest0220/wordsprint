"""Word Sprint app icon: a book that is clearly RUNNING — leaning forward with
bold bent striding legs, shoes, and speed lines."""
from PIL import Image, ImageDraw

SZ = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_background(img):
    top = (74, 158, 255)
    bot = (36, 96, 224)
    grad = Image.new("RGB", (1, SZ))
    gd = grad.load()
    for y in range(SZ):
        gd[0, y] = lerp(top, bot, y / SZ)
    grad = grad.resize((SZ, SZ))
    mask = Image.new("L", (SZ, SZ), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, SZ - 1, SZ - 1], radius=210, fill=255)
    img.paste(grad, (0, 0), mask)


def draw_content(img, cx, cy, scale):
    d = ImageDraw.Draw(img)

    def S(v):
        return int(v * scale)

    white = (255, 255, 255, 255)
    pageln = (176, 200, 245, 255)
    shadow = (24, 62, 140, 90)
    LEAN = 0.26  # forward lean: points above the pivot shift right

    def BP(x, y):
        # book point with a forward lean (skew around the vertical center)
        sy = S(y)
        return (cx + S(x) - int(LEAN * sy), cy + sy)

    def L(x, y):
        return (cx + S(x), cy + S(y))

    # --- speed / motion lines (behind everything), trailing left ---
    speed = (255, 255, 255, 240)
    for dy, x0, x1, w in [(-120, -470, -250, 30),
                          (-40, -510, -230, 36),
                          (40, -510, -230, 36),
                          (120, -470, -250, 30)]:
        d.line([L(x0, dy), L(x1, dy)], fill=speed, width=S(w))

    # --- running legs (drawn behind the book bottom) ---
    leg_w = S(52)
    # back leg: extended behind (to the left), pushing off
    back = [L(-30, 150), L(-120, 250), L(-235, 300)]
    d.line(back, fill=white, width=leg_w, joint="curve")
    # back shoe (heel down, toe left)
    d.line([L(-285, 322), L(-205, 300)], fill=white, width=S(40))
    d.ellipse([L(-300, 300)[0], L(-300, 300)[1], L(-250, 345)[0],
               L(-250, 345)[1]], fill=white)

    # front leg: knee driven up and forward (to the right), bent
    front = [L(35, 150), L(150, 205), L(120, 340)]
    d.line(front, fill=white, width=leg_w, joint="curve")
    # front shoe (toe right)
    d.line([L(95, 358), L(190, 350)], fill=white, width=S(40))
    d.ellipse([L(170, 330)[0], L(170, 330)[1], L(215, 372)[0],
               L(215, 372)[1]], fill=white)

    # --- the open book (leaning forward), drawn on top of the legs' hips ---
    d.polygon([BP(-250, -175), BP(20, -130), BP(20, 175), BP(-250, 130)],
              fill=shadow)  # soft shadow
    # left page
    d.polygon([BP(-260, -195), BP(5, -145), BP(5, 165), BP(-260, 120)],
              fill=white)
    # right page
    d.polygon([BP(5, -145), BP(270, -195), BP(270, 120), BP(5, 165)],
              fill=white)
    # spine
    d.line([BP(5, -145), BP(5, 165)], fill=pageln, width=S(12))
    # page text lines
    for i, dy in enumerate([-95, -35, 25, 85]):
        d.line([BP(-210, dy - 18), BP(-30, dy)], fill=pageln, width=S(13))
        d.line([BP(45, dy), BP(240, dy - 22)], fill=pageln, width=S(13))


def main():
    full = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    draw_background(full)
    draw_content(full, cx=SZ // 2 + 15, cy=SZ // 2 - 30, scale=1.0)
    full.save("assets/icon/icon_full.png")

    fg = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    draw_content(fg, cx=SZ // 2 + 10, cy=SZ // 2 - 18, scale=0.60)
    fg.save("assets/icon/icon_fg.png")
    print("wrote icon_full.png and icon_fg.png")


if __name__ == "__main__":
    main()
