"""Samppan modelling photos: B.B's published model photos → logo-free copies.

Reads B.B's list (akn-zone-data app/model.json, read only), downloads each new
or changed photo, erases the logo + design number (clean.py), then re-reads the
result: only a photo where "Synthetics" can no longer be found is published.
A photo that could not be cleaned is left out — never shown with the logo.

Output (GitHub Pages of this repo): docs/model/<file>.jpg + docs/model.json
State: tools/model_clean/state.json (source size+etag per file → no re-work).

Usage: python sync.py [--push]
"""
import json
import os
import subprocess
import sys
import urllib.request

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import clean  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = "https://aknzone-afk.github.io/akn-zone-data/app/"
OUT_DIR = os.path.join(REPO, "docs", "model")
OUT_JSON = os.path.join(REPO, "docs", "model.json")
STATE = os.path.join(HERE, "state.json")


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "samppan-model-sync"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read(), r.headers.get("ETag", "")


def still_branded(img):
    try:
        return clean.branded(img)
    except clean.OcrFailed:
        return True  # could not check → never publish


def main(push=False):
    os.makedirs(OUT_DIR, exist_ok=True)
    state = json.load(open(STATE, encoding="utf-8")) if os.path.exists(STATE) else {}
    raw, _ = fetch(SRC + "model.json")
    src = json.loads(raw.decode("utf-8"))
    m = src.get("m") or {}
    out = {}
    done = skipped = failed = 0
    for key, files in m.items():
        good = []
        for f in files or []:
            name = os.path.basename(f)
            dst = os.path.join(OUT_DIR, name)
            st = state.get(f)
            try:
                data, etag = fetch(SRC + f)
            except Exception as e:  # network blip: keep what we had
                print("fetch fail", f, e)
                if st and st.get("ok") and os.path.exists(dst):
                    good.append("model/" + name)
                continue
            sig = f"{len(data)}:{etag}"
            if st is None and os.path.exists(dst):
                # written by an earlier run that stopped before saving state —
                # files are only ever written after passing the logo check
                st = state[f] = {"sig": sig, "ok": True}
            if st and st.get("sig") == sig:
                if st.get("ok") and os.path.exists(dst):
                    good.append("model/" + name)
                skipped += 1
                continue
            img = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
            ok = False
            res = None
            if img is not None:
                try:
                    res, _ = clean.clean_img(img)
                except clean.OcrFailed:
                    print("OCR failed, try next run:", f)
                    continue  # no state → retried next run
                if res is not None and not still_branded(res):
                    cv2.imwrite(dst, res, [cv2.IMWRITE_JPEG_QUALITY, 88])
                    ok = True
            if not ok:
                failed += 1
                print("left out (could not clean):", f)
                if os.path.exists(dst):
                    os.remove(dst)
            else:
                done += 1
                good.append("model/" + name)
            state[f] = {"sig": sig, "ok": ok}
            if (done + failed) % 10 == 0:
                json.dump(state, open(STATE, "w", encoding="utf-8"), indent=0)
        if good:
            out[key] = good
    # photos B.B removed → remove ours too
    keep = {os.path.basename(x) for v in out.values() for x in v}
    for n in os.listdir(OUT_DIR):
        if n not in keep:
            os.remove(os.path.join(OUT_DIR, n))
    json.dump({"m": out}, open(OUT_JSON, "w", encoding="utf-8"), separators=(",", ":"))
    json.dump(state, open(STATE, "w", encoding="utf-8"), indent=0)
    print(f"cleaned {done}, unchanged {skipped}, left out {failed}, published designs {len(out)}")
    if push:
        g = lambda *a: subprocess.run(["git", "-C", REPO, *a], check=False)
        g("add", "docs/model", "docs/model.json", "tools/model_clean/state.json")
        if subprocess.run(["git", "-C", REPO, "diff", "--cached", "--quiet"]).returncode != 0:
            g("commit", "-q", "-m", "Modelling photos sync (logo-free)")
            g("push", "-q")


if __name__ == "__main__":
    main("--push" in sys.argv)
