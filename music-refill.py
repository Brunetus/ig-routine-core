#!/usr/bin/env python3
"""Refill the shared CC0 music shelf (viral-bank/music/) from Openverse.

BANK.md step 6d runs this. The shelf feeds reels that are POSTED VIA API
(@bambi.map auto-post, 2026-10-14), where IG's licensed audio cannot be
attached, so a bed is baked into the file. That makes licensing a hard gate:
only CC0 is ever written, and every file gets a LICENSES.tsv row. No row, no file.

Usage:
  music-refill.py                 top up to TARGET (default 30), max +3 per run
  music-refill.py --add 30        one-time bootstrap: add up to 30 regardless
  music-refill.py --dry-run       search + filter, print picks, download nothing

Filters (each candidate must pass all):
  - license == cc0 (re-checked on the result, not just the query param)
  - 20s <= duration <= 240s (a bed, not a sound effect)
  - mp3, file <= 8MB, decodes with ffmpeg
  - title/tags carry no sfx words (whoosh, jingle, stinger, riser, ...)
  - title/tags carry no derivative words (cover, remix, remake, tribute, ...)
  - title does not contain any named track from viral-bank/audio.md
    (a CC0 tag cannot launder a remake of a copyrighted song)
  - no vocals/speech tags (a lyric fights the on-screen text)
"""
import argparse, json, os, re, subprocess, sys, time, urllib.parse, urllib.request
from datetime import date
from pathlib import Path

BANK = Path.home() / "Claude Code" / "viral-bank"
SHELF = BANK / "music"
LEDGER = SHELF / "LICENSES.tsv"
AUDIO_MD = BANK / "audio.md"
FFMPEG = next((Path.home() / "Library/Python/3.9/lib/python/site-packages/imageio_ffmpeg/binaries").glob("ffmpeg-*"), None)
API = "https://api.openverse.org/v1/audio/"
HEADER = "file\tvibe\ttitle\tlicense\tsource_url\tadded\tadded_by\topenverse_id\tcreator\tduration_s\n"

# vibe -> search terms. Bambi leans warm/chill; the rest keep other accounts covered.
QUERIES = {
    "warm": ["ukulele music", "acoustic guitar happy", "folk acoustic loop", "warm acoustic"],
    "chill": ["lofi loop", "chill music", "lofi piano", "jazz loop"],
    "upbeat": ["happy upbeat music", "positive music loop", "whistle happy", "cheerful music"],
    "cinematic": ["gentle piano", "cinematic calm", "ambient music"],
    "hype": ["funk groove", "hip hop beat", "electro beat"],
}
SFX = r"whoosh|jingle|sting|riser|impact|hit\b|swoosh|sfx|effect|notification|alert|ringtone|bell|ding|click|glitch|transition|intro\b|outro\b|logo|one.?shot|drum ?roll|fx\b|advert|commercial|wah|meme|funny|comedy|cartoon|horn|kazoo|game ?over|8.?bit"
DERIV = r"cover|remix|remake|tribute|rendition|in the style|karaoke|parody|version of|mashup|bootleg|edit of|inspired by|happy birthday"
VOCAL = r"vocal|voice|speech|singing|sung|lyrics|rap\b|choir|spoken"

def known_titles():
    """Named tracks in the trending pool: a CC0 file titled like one is a remake."""
    if not AUDIO_MD.exists():
        return set()
    titles = re.findall(r'"([^"]{3,60})"', AUDIO_MD.read_text())
    return {t.lower().strip() for t in titles if len(t.strip()) >= 4}

def read_ledger():
    if not LEDGER.exists():
        return []
    lines = LEDGER.read_text().splitlines()[1:]
    return [dict(zip(HEADER.strip().split("\t"), l.split("\t"))) for l in lines if l.strip()]

def slug(s):
    s = re.sub(r"\.(wav|mp3|flac|ogg|aif+)$", "", s, flags=re.I)
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:40] or "track"

def search(q, page):
    qs = urllib.parse.urlencode({"q": q, "license": "cc0", "page_size": 20, "page": page})
    req = urllib.request.Request(f"{API}?{qs}", headers={"User-Agent": "marcus-ig-routine/1.0"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r).get("results", [])

def passes(r, banned):
    title = (r.get("title") or "").lower()
    tags = " ".join(t.get("name", "") for t in r.get("tags") or []).lower()
    text = f"{title} {tags}"
    dur = (r.get("duration") or 0) / 1000
    if r.get("license") != "cc0": return "license"
    if not 20 <= dur <= 240: return f"duration {dur:.0f}s"
    if (r.get("filetype") or "").lower() != "mp3": return "filetype"
    if re.search(SFX, text): return "sfx"
    if re.search(DERIV, text): return "derivative"
    if re.search(VOCAL, text): return "vocals"
    if any(b in title for b in banned): return "matches a named commercial track"
    return None

def download(r, dest):
    req = urllib.request.Request(r["url"], headers={"User-Agent": "marcus-ig-routine/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = resp.read(8 * 1024 * 1024 + 1)
    if len(data) > 8 * 1024 * 1024:
        raise ValueError("over 8MB")
    tmp = dest.with_suffix(".part")
    tmp.write_bytes(data)
    # must decode end to end, and be audio-only (mp3 extension proves nothing)
    p = subprocess.run([str(FFMPEG), "-v", "error", "-i", str(tmp), "-f", "null", "-"], capture_output=True, text=True)
    if p.returncode != 0 or p.stderr.strip():
        tmp.unlink(missing_ok=True)
        raise ValueError("ffmpeg decode failed")
    tmp.rename(dest)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", type=int, default=30)
    ap.add_argument("--add", type=int, help="add up to N regardless of target (bootstrap)")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    if not FFMPEG:
        sys.exit("ffmpeg (imageio_ffmpeg) not found")
    SHELF.mkdir(parents=True, exist_ok=True)
    if not LEDGER.exists():
        LEDGER.write_text(HEADER)
    rows = read_ledger()
    on_shelf = [r for r in rows if (SHELF / r["file"]).exists()]
    want = a.add if a.add else min(3, max(0, a.target - len(on_shelf)))
    print(f"shelf: {len(on_shelf)} tracks, adding up to {want}")
    if want == 0:
        return
    have_ids = {r.get("openverse_id") for r in rows}
    have_urls = {r.get("source_url") for r in rows}
    banned = known_titles()
    # balance vibes: fill the thinnest vibe first, round-robin
    counts = {v: sum(1 for r in on_shelf if r["vibe"] == v) for v in QUERIES}
    added, rejects = [], {}
    pools = {v: [] for v in QUERIES}
    # bootstrap searches everything; a +3 top-up runs one query per vibe (fits the scan's time box)
    plan = {v: (qs if a.add else qs[:1]) for v, qs in QUERIES.items()}
    for v, qs in plan.items():
        for q in qs:
            for page in ((1, 2) if a.add else (1,)):
                try:
                    pools[v] += search(q, page)
                except Exception as e:
                    print(f"  search failed ({q} p{page}): {e}")
                time.sleep(0.5)
    while len(added) < want and any(pools.values()):
        v = min((v for v in pools if pools[v]), key=lambda v: counts[v])
        r = pools[v].pop(0)
        if r["id"] in have_ids or r["url"] in have_urls:
            continue
        why = passes(r, banned)
        if why:
            rejects[why] = rejects.get(why, 0) + 1
            have_ids.add(r["id"])
            continue
        fname = f"{v}-{slug(r['title'])}.mp3"
        if (SHELF / fname).exists():
            fname = f"{v}-{slug(r['title'])}-{r['id'][:6]}.mp3"
        have_ids.add(r["id"]); have_urls.add(r["url"])
        if a.dry_run:
            print(f"  would add {fname}  ({r['duration']/1000:.0f}s, {r.get('creator')})")
            added.append(fname); counts[v] += 1
            continue
        try:
            download(r, SHELF / fname)
        except Exception as e:
            rejects[f"download: {e}"] = rejects.get(f"download: {e}", 0) + 1
            continue
        with LEDGER.open("a") as f:
            f.write("\t".join([fname, v, (r.get("title") or "").replace("\t", " "), "CC0", r["url"],
                               date.today().isoformat(), "music-refill.py (Openverse cc0)", r["id"],
                               (r.get("creator") or "").replace("\t", " "), f"{r['duration']/1000:.0f}"]) + "\n")
        added.append(fname); counts[v] += 1
        print(f"  added {fname}")
    print(f"added {len(added)}; shelf by vibe: {counts}; rejected: {rejects}")

if __name__ == "__main__":
    main()
