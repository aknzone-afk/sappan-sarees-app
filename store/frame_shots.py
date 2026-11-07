"""Samppan store screenshots: frame raw app screenshots on the house ivory with
a serif headline and a gold subline (App Store 6.7" 1290x2796; Play uses the
same files).  Usage: python frame_shots.py RAW_DIR OUT_DIR"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "app", "assets", "fonts")
IVORY, WINE, GOLD = (255, 252, 247), (94, 11, 31), (176, 138, 69)
W, H = 1290, 2796

CAPTIONS = {
    "01_home": ("The Finest Weaves of India", "NEW DESIGNS EVERY DAY"),
    "02_collections": ("Curated Collections", "ZARI · BANARASI · BANDHEJ & MORE"),
    "03_new_in": ("A Price on Every Design", "ORDER FROM JUST ONE SAREE"),
    "04_choose_colour": ("Choose Your Colour", "TAP THE SAREE YOU LOVE"),
    "05_on_model": ("See It Worn", "VIEW THE SAREE ON A MODEL"),
    "06_bag": ("Your Shopping Bag", "SEE YOUR TOTAL AS YOU GO"),
    "07_order": ("Delivered Across India", "PLACE YOUR ORDER IN SECONDS"),
}


def frame(raw, out, title, sub):
    shot = Image.open(raw).convert("RGB")
    c = Image.new("RGB", (W, H), IVORY)
    d = ImageDraw.Draw(c)
    tf = ImageFont.truetype(os.path.join(FONTS, "Cormorant-700.ttf"), 96)
    sf = ImageFont.truetype(os.path.join(FONTS, "Jost-600.ttf"), 34)
    tw = d.textlength(title, font=tf)
    d.text(((W - tw) / 2, 120), title, font=tf, fill=WINE)
    sp = 6  # letter-spaced subline
    sw = sum(d.textlength(ch, font=sf) + sp for ch in sub) - sp
    x = (W - sw) / 2
    for ch in sub:
        d.text((x, 262), ch, font=sf, fill=GOLD)
        x += d.textlength(ch, font=sf) + sp
    # the screen, framed by a fine gold line
    top, side = 360, 90
    bw = W - 2 * side
    bh = int(shot.height * bw / shot.width)
    if top + bh > H - 60:
        bh = H - 60 - top
        bw = int(shot.width * bh / shot.height)
        side = (W - bw) // 2
    s = shot.resize((bw, bh), Image.LANCZOS)
    c.paste(s, (side, top))
    d.rectangle([side - 3, top - 3, side + bw + 2, top + bh + 2], outline=GOLD, width=3)
    c.save(out, "PNG")


def main(raw_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for name, (t, s) in CAPTIONS.items():
        p = os.path.join(raw_dir, name + ".png")
        if os.path.exists(p):
            frame(p, os.path.join(out_dir, name + ".png"), t, s)
            print("framed", name)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
