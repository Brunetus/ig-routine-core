#!/usr/bin/env python3
"""Dump Photos' own scene labels for every video -> routine/photos-labels.tsv

Why this exists: on 2026-07-16 the bambi run reported "all material lanes
exhausted" and recycled an old reel. The catalogue held 47 videos that Photos
had already tagged "High Chair". Nothing was exhausted — the routine just had
no way to SEE the archive, so filenames like IMG_9128.MOV told it nothing.

Photos' search index (psi.sqlite) has the labels the Photos app searches on
("High Chair", "Restaurant", "Baby", "Meal"...). The launcher has Full Disk
Access; the claude session does not — so the launcher dumps this, and the
session greps it.

Output: <uuid>\t<label,label,...>  (videos only, one row per tagged video)

Gotchas paid for once, do not re-learn:
- content_string carries a trailing NUL byte: 'High Chair\\x00'. Exact match in
  SQL silently returns nothing, and SQLite's char(0) is '' so replace() is a
  no-op. Strip it in Python (text_factory below).
- assets.uuid_0/uuid_1 are the UUID's 16 bytes as two little-endian int64s.
- Read immutable=1 and NEVER write: this is Apple's live index.
"""
import sqlite3, uuid, struct, sys, os, collections

LIB = os.path.expanduser("~/Pictures/Photos Library.photoslibrary")
PSI = f"{LIB}/database/search/psi.sqlite"
OUT = "routine/photos-labels.tsv"
LABEL_CATEGORIES = (1500, 1501)  # singular + plural scene-label vocabulary


def main():
    if not os.path.exists(PSI):
        print("no psi.sqlite; skipping labels", file=sys.stderr)
        return 1
    db = sqlite3.connect(f"file:{PSI}?immutable=1", uri=True)
    db.text_factory = lambda b: b.decode("utf8", "replace").rstrip("\x00")

    gid_label = {}
    for rid, cs in db.execute(
        f"SELECT rowid, content_string FROM groups WHERE category IN {LABEL_CATEGORIES}"
    ):
        if cs:
            gid_label[rid] = cs

    asset_uuid = {}
    for rid, u0, u1 in db.execute("SELECT rowid, uuid_0, uuid_1 FROM assets"):
        try:
            asset_uuid[rid] = str(
                uuid.UUID(bytes=struct.pack("<q", u0) + struct.pack("<q", u1))
            ).upper()
        except Exception:
            pass

    # only label rows for videos we actually catalogued
    videos = set()
    try:
        with open("routine/photos-archive.tsv") as f:
            for line in f:
                p = line.split("\t")
                if p and p[0]:
                    videos.add(p[0])
    except FileNotFoundError:
        print("no photos-archive.tsv; run dump_archive first", file=sys.stderr)
        return 1

    labels = collections.defaultdict(set)
    for gid, label in gid_label.items():
        for (aid,) in db.execute("SELECT assetid FROM ga WHERE groupid=?", (gid,)):
            u = asset_uuid.get(aid)
            if u in videos:
                labels[u].add(label)

    with open(OUT, "w") as f:
        for u, ls in labels.items():
            f.write(f"{u}\t{','.join(sorted(ls))}\n")
    print(f"labels: {len(labels)} videos tagged")
    return 0


if __name__ == "__main__":
    sys.exit(main())
