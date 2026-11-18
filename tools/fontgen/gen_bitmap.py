"""Single-page Fira **bitmap atlases** for the mod (D-106, D-108), generated from the TTF with FreeType.

Every size is rasterised from the original font with light hinting: widths and kerning are those
of that size, not rounded from another one. Usage:
  python gen_bitmap.py <ttf_dir> <media_fonts_dir> <Presets.lua> <FontSizes.lua>
Sources (tools/fontgen/src/, OFL 1.1): FiraSansExtraCondensed-Regular.ttf, -SemiBold.ttf.
Outputs:
  fonts/rsk/rsk_<weight><size>.fnt/_0.png        one for every role size at the 5 levels (D-108)
  fonts/[EN/<n>x/]zomboidSmall|Medium|Large.fnt  vanilla font replacements (SemiBold, vanilla sizes)
  RSK/Theme/FontSizes.lua                         list of generated sizes (read by Theme)
A single page because from Lua only AngelCodeFont.new(fnt, png) works.
Requires: pip install freetype-py fonttools pillow
"""
import ctypes, math, os, re, sys
import freetype
from fontTools.ttLib import TTFont
from PIL import Image

FACE = "Fira Sans Extra Condensed"
FILES = {"regular": "FiraSansExtraCondensed-Regular.ttf", "semibold": "FiraSansExtraCondensed-SemiBold.ttf"}
LEVEL_SMALL = (16, 19, 26, 33, 38)       # vanilla Small size per level (D-108)
LEVEL_REF, GROWTH = 16, 0.5              # level 1 = mockup; grows at half the vanilla rate
BOLD_MOD = 0.0128                        # D-97 weight per side, as a fraction of the size (mod texts)
BOLD_VANILLA = 0.22                      # D-97 weight per side in px (replaced vanilla fonts)
SMALL_BOLD = {12: 0.12, 13: 0.1, 14: 0.06}  # extra px per side at small sizes (D-106)
CAP = 0.689                              # cap height / em (vertical centring, as in gen_sdf)
VANILLA = {                              # folder -> (small, medium, large), media/fonts/.Font size reference.txt
    "": (16, 23, 26), "EN/1x": (19, 29, 33), "EN/2x": (26, 33, 40), "EN/3x": (33, 40, 45), "EN/4x": (38, 45, 50),
}
EXCLUDE = {0x200B, 0xFEFF, 0x00AD}


def kern_ok(c):
    """Kerning only for Latin-1 and typographic quotes (file size; English only for now)."""
    return c <= 0xFF or 0x2018 <= c <= 0x201E


def level_factors():
    return [1 + (s / LEVEL_REF - 1) * GROWTH for s in LEVEL_SMALL]


def role_sizes(presets_path):
    """Sizes per family from T.fonts in Presets.lua, multiplied by the 5 levels (rounded like T.px)."""
    txt = open(presets_path, encoding="utf-8").read()
    block = txt[txt.index("T.fonts = {"):]
    block = block[:block.index("\n}")]
    out = {}
    for fam, size in re.findall(r'family\s*=\s*"(\w+)",\s*size\s*=\s*(\d+)', block):
        for f in level_factors():
            out.setdefault(fam, set()).add(int(math.floor(int(size) * f + 0.5)))
    return {k: sorted(v) for k, v in out.items()}


def charset(cmap):
    keep = lambda c: (0x20 <= c < 0x250) or (0x2000 <= c < 0x2070) or c in (0x20AC, 0x2122, 0x2116, 0x2264, 0x2265)
    return sorted(c for c in cmap if keep(c) and c not in EXCLUDE)


def kern_pairs(tt):
    """Kerning pairs (font units) from the GPOS kern feature (PairPos format 1 and 2)."""
    res = {}
    if "GPOS" not in tt:
        return res
    gpos = tt["GPOS"].table
    rev = {}
    for cp, g in tt.getBestCmap().items():
        rev.setdefault(g, []).append(cp)
    idx = set()
    for fr in gpos.FeatureList.FeatureRecord:
        if fr.FeatureTag == "kern":
            idx |= set(fr.Feature.LookupListIndex)
    for li in idx:
        lk = gpos.LookupList.Lookup[li]
        for st in lk.SubTable:
            if lk.LookupType == 9:
                st = st.ExtSubTable
            if not hasattr(st, "Format") or not hasattr(st, "Coverage"):
                continue
            cov = st.Coverage.glyphs
            if st.Format == 1:
                for i, g1 in enumerate(cov):
                    for pvr in st.PairSet[i].PairValueRecord:
                        v = getattr(pvr.Value1, "XAdvance", 0) if pvr.Value1 else 0
                        if v:
                            for a in rev.get(g1, []):
                                for b in rev.get(pvr.SecondGlyph, []):
                                    res.setdefault((a, b), v)
            elif st.Format == 2:
                cd1, cd2 = st.ClassDef1.classDefs, st.ClassDef2.classDefs
                cls2 = {}
                for g, c in cd2.items():
                    cls2.setdefault(c, []).append(g)
                for g1 in cov:
                    row = st.Class1Record[cd1.get(g1, 0)].Class2Record
                    for c2, rec in enumerate(row):
                        v = getattr(rec.Value1, "XAdvance", 0) if rec.Value1 else 0
                        if not v or c2 == 0:
                            continue
                        for g2 in cls2.get(c2, []):
                            for a in rev.get(g1, []):
                                for b in rev.get(g2, []):
                                    res.setdefault((a, b), v)
    return res


class Source:
    def __init__(self, path):
        self.face = freetype.Face(path)
        self.tt = TTFont(path)
        self.upm = self.tt["head"].unitsPerEm
        self.cps = charset(self.tt.getBestCmap())
        self.kern = kern_pairs(self.tt)


def render(face, cp, bold_px):
    """Glyph with light hinting and bold_px weight per side: (L image or None, left, top, advance)."""
    face.load_char(chr(cp), freetype.FT_LOAD_NO_BITMAP | freetype.FT_LOAD_TARGET_LIGHT)
    g = face.glyph
    if bold_px > 0 and g.format == freetype.FT_GLYPH_FORMAT_OUTLINE:
        freetype.raw.FT_Outline_Embolden(ctypes.byref(g.outline._FT_Outline), int(round(bold_px * 2 * 64)))
    adv = int(round(g.advance.x / 64.0))
    g.render(freetype.FT_RENDER_MODE_LIGHT)
    bm = g.bitmap
    if bm.width == 0 or bm.rows == 0:
        return None, 0, 0, adv
    img = Image.frombytes("L", (bm.width, bm.rows), bytes(bm.buffer), "raw", "L", bm.pitch)
    return img, g.bitmap_left, g.bitmap_top, adv


def pack(glyphs, width):
    x = y = shelf = 0
    pos = {}
    for key, img in sorted(glyphs.items(), key=lambda kv: -kv[1].size[1]):
        w, h = img.size
        if x + w + 1 > width:
            x, y, shelf = 0, y + shelf + 1, 0
        pos[key] = (x + 1, y + 1)
        x += w + 1
        shelf = max(shelf, h)
    return pos, (y + shelf + 2 + 3) // 4 * 4


def build(src, size, bold_px, line_height, base, out_dir, out_name):
    face = src.face
    face.set_char_size(size * 64)
    glyphs, meta = {}, {}
    for cp in src.cps:
        img, left, top, adv = render(face, cp, bold_px)
        meta[cp] = (left, base - top, adv)
        if img is not None:
            glyphs[cp] = img
    width = 512 if size <= 40 else 1024
    pos, height = pack(glyphs, width)
    page = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    for cp, img in glyphs.items():
        tile = Image.new("RGBA", img.size, (255, 255, 255, 0))
        tile.putalpha(img)
        page.paste(tile, pos[cp])
    cps = set(src.cps)
    kl = [(a, b, int(round(v * size / src.upm))) for (a, b), v in src.kern.items()
          if a in cps and b in cps and kern_ok(a) and kern_ok(b)]
    kl = sorted(k for k in kl if k[2] != 0)
    bold_flag = 1 if "SemiBold" in face.style_name.decode() or "Bold" in face.style_name.decode() else 0
    lines = [
        f'info face="{FACE}" size={size} bold={bold_flag} italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1',
        f"common lineHeight={line_height} base={base} scaleW={width} scaleH={height} pages=1 packed=0",
        f'page id=0 file="{out_name}_0.png"',
        f"chars count={len(meta)}",
    ]
    for cp in sorted(meta):
        xo, yo, adv = meta[cp]
        x, y = pos.get(cp, (0, 0))
        w, h = glyphs[cp].size if cp in glyphs else (0, 0)
        lines.append(f"char id={cp:<6} x={x:<4} y={y:<5} width={w:<4} height={h:<4} xoffset={xo:<4} "
                     f"yoffset={yo:<4} xadvance={adv:<4} page=0    chnl=0 ")
    lines.append(f"kernings count={len(kl)}")
    lines += [f"kerning first={a} second={b} amount={v}" for a, b, v in kl]
    os.makedirs(out_dir, exist_ok=True)
    page.save(os.path.join(out_dir, out_name + "_0.png"), optimize=True)
    with open(os.path.join(out_dir, out_name + ".fnt"), "w", encoding="ascii", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    ttf_dir, fonts, presets, sizes_lua = sys.argv[1:5]
    srcs = {fam: Source(os.path.join(ttf_dir, f)) for fam, f in FILES.items()}
    rsk = os.path.join(fonts, "rsk")
    os.makedirs(rsk, exist_ok=True)
    for f in os.listdir(rsk):
        if f.startswith("rsk_"):
            os.remove(os.path.join(rsk, f))
    sizes = role_sizes(presets)
    for fam, lst in sizes.items():
        for s in lst:
            lh = round(s * 1.25)
            build(srcs[fam], s, s * BOLD_MOD + SMALL_BOLD.get(s, 0), lh, round(lh / 2 + s * CAP / 2), rsk, f"rsk_{fam}{s}")
        print(fam, lst)
    for folder, trio in VANILLA.items():
        for s, name in zip(trio, ("zomboidSmall", "zomboidMedium", "zomboidLarge")):
            build(srcs["semibold"], s, BOLD_VANILLA, s, round(s * 0.75), os.path.join(fonts, folder), name)
    with open(sizes_lua, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("-- Generated by tools/fontgen/gen_bitmap.py: sizes of the Fira atlases in media/fonts/rsk/ (D-108).\n")
        fh.write("RSK = RSK or {}\nRSK.Theme = RSK.Theme or {}\nRSK.Theme.FONT_SIZES = {\n")
        for fam, lst in sorted(sizes.items()):
            fh.write(f"    {fam} = {{ {', '.join(str(s) for s in lst)} }},\n")
        fh.write("}\n")
    print("ok")
