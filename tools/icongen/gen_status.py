"""Status icons for inventory rows (D-26, D-141): filled badges.

Writes white masks (tinted by the theme at draw time) for every size in SIZES:
  42/media/ui/RSK/status/disc_<n>.png   filled circle (danger / muted / ok)
  42/media/ui/RSK/status/bang_<n>.png   exclamation mark (ink)
  42/media/ui/RSK/status/eye_<n>.png    solid eye with pupil (ink)
  42/media/ui/RSK/status/check_<n>.png  check mark (ink)
Each size is drawn on its own (supersampled), not scaled down from one big image, so small
icons stay sharp. The mod picks the size closest to the row's status size.
Usage: python tools/icongen/gen_status.py   (requires Pillow)
"""
import math
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "42" / "media" / "ui" / "RSK" / "status"
SIZES = [12, 13, 14, 15, 16, 17, 18, 20, 22, 24, 26, 28, 32]
SS = 16  # supersampling factor
WHITE, CLEAR = (255, 255, 255, 255), (0, 0, 0, 0)


class Pen:
    """Draws in a 24-unit square at size * SS, then downsamples to size."""

    def __init__(self, size):
        self.size, self.k = size, size * SS / 24.0
        self.im = Image.new("RGBA", (size * SS, size * SS), CLEAR)
        self.d = ImageDraw.Draw(self.im)

    def p(self, x, y):
        return (x * self.k, y * self.k)

    def disc(self, cx, cy, r, c=WHITE):
        self.d.ellipse([self.p(cx - r, cy - r), self.p(cx + r, cy + r)], fill=c)

    def line(self, pts, w, c=WHITE):
        self.d.line([self.p(*q) for q in pts], fill=c, width=max(1, round(w * self.k)), joint="curve")
        for q in pts:
            self.disc(q[0], q[1], w / 2, c)  # round caps

    def poly(self, pts, c=WHITE):
        self.d.polygon([self.p(*q) for q in pts], fill=c)

    def save(self, path):
        self.im.resize((self.size, self.size), Image.LANCZOS).save(path)


def almond(rx, ry, n=48):
    up = [(12 - rx * math.cos(t), 12 - ry * math.sin(t)) for t in (math.pi * i / n for i in range(n + 1))]
    lo = [(12 + rx * math.cos(t), 12 + ry * math.sin(t)) for t in (math.pi * i / n for i in range(n + 1))]
    return up + lo


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for n in SIZES:
        p = Pen(n); p.disc(12, 12, 11); p.save(OUT / f"disc_{n}.png")
        p = Pen(n); p.line([(12, 6.2), (12, 13.2)], 3.0); p.disc(12, 17.6, 1.75); p.save(OUT / f"bang_{n}.png")
        p = Pen(n); p.poly(almond(8.2, 5.2)); p.disc(12, 12, 3.0, CLEAR); p.disc(12, 12, 1.5); p.save(OUT / f"eye_{n}.png")
        p = Pen(n); p.line([(7.2, 12.4), (10.6, 15.8), (16.8, 8.6)], 3.2); p.save(OUT / f"check_{n}.png")
    print(f"{len(SIZES) * 4} icons in {OUT}")


if __name__ == "__main__":
    main()
