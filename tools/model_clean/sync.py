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
# photos a person looked at and found not clean enough — never published
BLOCK = os.path.join(HERE, "blocklist.txt")
# cleaned copies the automatic stroke check was unsure about; a person looked
# at them and approved these names (they are then published like the rest)
ALLOW = os.path.join(HERE, "approved.txt")
REVIEW = os.path.join(HERE, "review")


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
    os.makedirs(REVIEW, exist_ok=True)
    approved = set()
    if os.path.exists(ALLOW):
        approved = {l.strip() for l in open(ALLOW, encoding="utf-8") if l.strip() and not l.startswith("#")}
    blocked = set()
    if os.path.exists(BLOCK):
        blocked = {l.strip() for l in open(BLOCK, encoding="utf-8") if l.strip() and not l.startswith("#")}
    for key, files in m.items():
        good = []
        for f in files or []:
            name = os.path.basename(f)
            if name in blocked:
                continue
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
            # each photo in its own process: a native crash in the image
            # libraries (low-memory PC) only loses that one photo, this run
            tmp_in = os.path.join(REVIEW, "_in.jpg")
            open(tmp_in, "wb").write(data)
            rv = os.path.join(REVIEW, name)
            try:
                code = subprocess.run([sys.executable, os.path.join(HERE, "clean.py"), tmp_in, dst,
                                       "--design", key, "--review", rv],
                                      capture_output=True, text=True, timeout=400).returncode
            except subprocess.TimeoutExpired:
                code = -1
            ok = code == 0
            if code == 4:
                if name in approved:
                    os.replace(rv, dst)
                    ok = True
                else:
                    print("for review:", f)
            elif code not in (0, 2, 4):
                print("crashed/ocr fail, try next run:", f, code)
                continue  # no state → tried again next run
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
