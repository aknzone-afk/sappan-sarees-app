"""Samppan: erase the B.B Synthetics logo (monogram, wordmark, ™, ©, tagline)
and the design number printed under it from a modelling photo.

1. Tesseract finds the word "Synthetics" (large bold black type — reliable).
2. The logo area is laid out around that word (measured on the real logo):
   monogram above, "B.B" to the left, © to the right, tagline + number below.
3. Inside that area only the black SHAPES that sit fully inside it are erased
   (letters, monogram, number). A dark shape that runs out of the area — hair,
   a shoulder, an inset photo's frame — is never touched.
4. The erased strokes are filled from the backdrop around them.
The Instagram QR is left as it is (owner 6-Nov: "QR is fine").

Usage: python clean.py IN.jpg OUT.jpg [debug.jpg]   → 0 cleaned, 2 = logo not found
"""
import re
import sys

import cv2
import numpy as np
import pytesseract

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"


class OcrFailed(Exception):
    pass


def _ocr_word(g, cfg="--psm 11"):
    d = None
    for _ in range(2):
        try:
            d = pytesseract.image_to_data(g, config=cfg, output_type=pytesseract.Output.DICT)
            break
        except (pytesseract.TesseractError, RuntimeError, OSError):
            d = None
    if d is None:
        raise OcrFailed(cfg)
    best = None
    for i, t in enumerate(d["text"]):
        if re.search(r"ynthe|nthetic", t or "", re.I):
            b = (d["left"][i], d["top"][i], d["width"][i], d["height"][i])
            if best is None or b[2] > best[2]:
                best = b
    return best


def logo_colour(img):
    """(white?, word box): read "Synthetics" on a black-ink-only and a
    white-ink-only picture of the top of the photo — whichever reads it is the
    logo's colour. None when neither does."""
    h = img.shape[0]
    top = img[: int(h * 0.6)]
    s = 2.0
    found = []
    for white, pol in ((False, top), (True, 255 - top)):
        m = ink(pol)
        g = np.where(m > 0, 0, 255).astype(np.uint8)
        g = cv2.resize(g, None, fx=s, fy=s, interpolation=cv2.INTER_NEAREST)
        b = _ocr_word(g)
        if b:
            box = tuple(int(v / s) for v in b)
            x, y, w, hh = box
            frac = float(m[y:y + hh, x:x + w].mean()) if w and hh else 1.0
            found.append((abs(frac - 0.28), white, box))
    if not found:
        return None
    # on a dark backdrop the black picture shows the letters as gaps and reads
    # too — real letters fill about a quarter of their box, the backdrop most
    _, white, box = min(found)
    return white, box


def find_word(img):
    """Box (x, y, w, h) of the word "Synthetics" in the top 60 % of the photo."""
    h, w = img.shape[:2]
    top = img[: int(h * 0.6)]
    s = 2.0  # small type reads better enlarged
    gray = cv2.cvtColor(top, cv2.COLOR_BGR2GRAY)
    inkonly = np.where(ink(top) > 0, 0, 255).astype(np.uint8)  # dark backdrops: just the black type
    tries = [(cv2.resize(gray, None, fx=s, fy=s, interpolation=cv2.INTER_CUBIC), c) for c in ("--psm 11", "--psm 3")]
    tries.append((cv2.resize(inkonly, None, fx=s, fy=s, interpolation=cv2.INTER_NEAREST), "--psm 11"))
    for g, cfg in tries:
        d = None
        for _ in range(2):  # Tesseract can fail on a low-memory PC — retry once
            try:
                d = pytesseract.image_to_data(g, config=cfg, output_type=pytesseract.Output.DICT)
                break
            except (pytesseract.TesseractError, RuntimeError, OSError):
                d = None
        if d is None:
            raise OcrFailed(cfg)
        best = None
        for i, t in enumerate(d["text"]):
            if re.search(r"ynthe|nthetic", t or "", re.I):
                b = (d["left"][i] / s, d["top"][i] / s, d["width"][i] / s, d["height"][i] / s)
                if best is None or b[2] > best[2]:
                    best = b
        if best:
            return tuple(int(v) for v in best)
    return None


def ink(img, strict=False):
    """Logo ink: clearly darker than the backdrop around it and colourless.
    (Compared with the local backdrop so the soft grey letter edges count too.)
    strict: dark backdrop (runway, night) — only true black counts."""
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    if strict:
        return (hsv[..., 2] < 32).astype(np.uint8)
    v = hsv[..., 2].astype(np.int16)
    back = cv2.medianBlur(hsv[..., 2], 31).astype(np.int16)
    core = (v < 45) | ((v < 80) & (hsv[..., 1] < 120))  # near-black: colour reading is noise
    soft = (back - v > 35) & (hsv[..., 1] < 120)
    return (core | soft).astype(np.uint8)


def _runs(prof, gap=3):
    """Longest run of busy rows/columns (blank gaps of >= gap end a run)."""
    best, start, blank = (0, 0), None, 0
    for i, v in enumerate(list(prof) + [0] * (gap + 1)):
        if v:
            if start is None:
                start = i
            blank = 0
            end = i
        elif start is not None:
            blank += 1
            if blank >= gap:
                if end - start > best[1] - best[0]:
                    best = (start, end)
                start, blank = None, 0
    return best


def _tight(dark, x, y):
    """Shrink a QR candidate to its solid block of modules — a design number
    printed just above the QR is not part of it."""
    r0, r1 = _runs(dark.mean(1) > 0.06)
    c0, c1 = _runs(dark[r0:r1 + 1].mean(0) > 0.06)
    return (x + c0, y + r0, c1 - c0 + 1, r1 - r0 + 1)


def qr_boxes(img):
    """QR codes on the photo (to leave untouched): OpenCV's detector first,
    else a small pure-white square with dark modules inside."""
    H, W = img.shape[:2]
    out = []
    try:
        ok, pts = cv2.QRCodeDetector().detectMulti(img)
        if ok and pts is not None:
            for p in pts:
                p = p.reshape(-1, 2)
                x, y = int(p[:, 0].min()), int(p[:, 1].min())
                out.append((x, y, int(p[:, 0].max()) - x, int(p[:, 1].max()) - y))
    except cv2.error:
        pass
    if out:
        return out
    g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    _, th = cv2.threshold(g, 245, 255, cv2.THRESH_BINARY)
    th = cv2.morphologyEx(th, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
    cnts, _ = cv2.findContours(th, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in cnts:
        x, y, w, h = cv2.boundingRect(c)
        if 40 < w < W * 0.3 and 0.8 < w / max(h, 1) < 1.25:
            box = g[y:y + h, x:x + w]
            dark = (box < 90).mean()
            # a QR is many small separate dots/modules (a monogram is 1-3 shapes)
            n_dots = cv2.connectedComponents((box < 90).astype(np.uint8))[0] - 1
            # and printed QRs are pure black on pure white — few in-between tones
            white_px = (box > 225).mean()
            mid = 1.0 - white_px - dark
            if 0.08 < dark < 0.65 and n_dots >= 25 and white_px > 0.35 and mid < 0.3:
                tx, ty, tw, th_ = _tight(box < 90, x, y)
                q = g[ty:ty + th_, tx:tx + tw] < 90
                k = max(5, min(tw, th_) // 7)
                # three alike finder squares (TL, TR, BL) and a lighter 4th corner
                f = [float(c.mean()) if c.size else 0.0 for c in (q[:k, :k], q[:k, -k:], q[-k:, :k])]
                br = float(q[-k:, -k:].mean()) if q.size else 1.0
                if min(f) > 0.3 and max(f) < 0.75 and max(f) - min(f) < 0.15 and br < min(f):
                    out.append((tx, ty, tw, th_))
    return out


def area_of(word, h, w):
    """The logo's area laid out around the word "Synthetics"."""
    sx, sy, sw, sh = word
    sh = max(sh, int(sw * 0.16))
    x0 = max(0, int(sx - 0.95 * sw)); x1 = min(w, int(sx + sw + 0.21 * sw))  # © is the right-most mark
    y0 = max(0, int(sy - 7.5 * sh)); y1 = min(h, int(sy + sh + 5.4 * sh))
    return x0, y0, x1, y1


def strokes(pol, area, qrs, white, full_shape):
    """Logo-like shapes inside [area] of [pol] (the photo, or the inverted
    photo for a white logo) as a full-size mask (not dilated)."""
    x0, y0, x1, y1 = area
    H, W = full_shape
    region = pol[y0:y1, x0:x1]
    hsv_r = cv2.cvtColor(region, cv2.COLOR_BGR2HSV)
    rh, rw = region.shape[:2]
    qr_cut = [(max(0, qx - 3 - x0), max(0, qy - 3 - y0), qx + qw + 3 - x0, qy + qh + 3 - y0) for qx, qy, qw, qh in qrs]
    # an area side that is the photo's own edge does not cut anything
    cut_l, cut_t, cut_r, cut_b = x0 > 0, y0 > 0, x1 < W, y1 < H
    keep = np.zeros((rh, rw), np.uint8)
    # pass 1: normal ink; pass 2: pure black only (letters over a dark backdrop
    # merge with it in pass 1 and get skipped there)
    for strict in (False, True):
        m = ink(region, strict=strict)
        for a0, b0, a1, b1 in qr_cut:
            if a1 > 0 and b1 > 0:
                m[b0:max(0, b1), a0:max(0, a1)] = 0
        n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
        for i in range(1, n):
            x, y, ww, hh, area_px = st[i]
            touches = (cut_l and x <= 1) or (cut_t and y <= 1) or (cut_r and x + ww >= rw - 1) or (cut_b and y + hh >= rh - 1)
            if touches or area_px < 4:
                continue
            if ww > rw * 0.6 or hh > rh * 0.5:  # far too big for a letter or the monogram
                continue
            # black/grey ink only — a coloured shape (dark fabric, hair dye,
            # skin shadow) is part of the photo
            px = hsv_r[lab == i]
            lit = px[px[:, 2] >= 50]
            # a white logo's soft edges take the backdrop's colour → looser test
            if len(lit) >= 6 and np.median(lit[:, 1]) > (140 if white else 70):
                continue
            keep[lab == i] = 255
    mask = np.zeros(full_shape, np.uint8)
    mask[y0:y1, x0:x1] = keep
    return mask


def word_cover(mask, word):
    sx, sy, sw, sh = word
    return int((mask[sy:sy + sh, sx:sx + sw] > 0).sum())


def branded(img):
    """Can "Synthetics" still be read — black type, or white type (inverted)?"""
    return find_word(img) is not None or find_word(255 - img) is not None


def clean_img(img):
    """The logo is black on light photos and WHITE on dark ones. Both are
    looked for; the one whose strokes form the word "Synthetics" is erased.
    Returns (None, reason) when it could not be cleaned for sure."""
    h, w = img.shape[:2]
    qrs = qr_boxes(img[: int(h * 0.7)])
    inv = 255 - img
    lc = logo_colour(img)
    if lc is None:
        return None, "logo not found"
    white, word = lc
    area = area_of(word, h, w)
    black_m = strokes(img, area, qrs, False, (h, w))
    white_m = strokes(inv, area, qrs, True, (h, w))
    bc, wc = word_cover(black_m, word), word_cover(white_m, word)
    mask = white_m if white else black_m
    if max(bc, wc) < 30:
        return None, "word strokes not found"
    big = cv2.dilate(mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)), iterations=2)
    out = cv2.inpaint(img, big, 6, cv2.INPAINT_TELEA)
    blur = cv2.GaussianBlur(out, (0, 0), 2.0)
    soft = cv2.GaussianBlur(big, (0, 0), 2).astype(np.float32)[..., None] / 255.0
    out = (out.astype(np.float32) * (1 - soft) + blur.astype(np.float32) * soft).astype(np.uint8)
    # proof: the logo's strokes are really gone (both colours) in its area
    before = int((mask > 0).sum())
    after = strokes(255 - out, area, qrs, True, (h, w)) if white else strokes(out, area, qrs, False, (h, w))
    left = int(((after > 0) & (big > 0)).sum()) / max(before, 1)  # only where the logo was
    if left > 0.08:
        return None, f"logo strokes left {left:.0%}"
    return out, (*area, word)


def main(src, dst, dbg=None):
    img = cv2.imread(src)
    if img is None:
        return 3
    out, info = clean_img(img)
    if out is None:
        print(info)
        return 2
    print("area", info)
    cv2.imwrite(dst, out, [cv2.IMWRITE_JPEG_QUALITY, 90])
    if dbg:
        d = img.copy()
        x0, y0, x1, y1, (sx, sy, sw, sh) = info
        cv2.rectangle(d, (x0, y0), (x1, y1), (0, 0, 255), 2)
        cv2.rectangle(d, (sx, sy), (sx + sw, sy + sh), (0, 200, 0), 2)
        cv2.imwrite(dbg, d)
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
