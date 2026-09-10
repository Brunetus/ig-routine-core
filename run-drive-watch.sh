#!/bin/zsh
# run-drive-watch.sh — Drive-folder intake for PAID reel clients.
# LaunchAgent: com.marcus.drive-watch (StartInterval 900).
#
# The paid tier reuses the reels.ibuildapp.ca pipeline end to end; the ONLY
# difference is intake (a per-client Google Drive folder instead of the site
# uploader) and that the shipped page file is the clean cut. Per drop of new
# footage this enqueues <cuts> jobs (default 5) via the worker API's enqueue
# route; render, review gate, salvage, and release are untouched.
#
# Per client: reel-app/clients/<handle>/drive.json
#   { folder_id, email, phone, cuts, note }
# State:      reel-app/clients/<handle>/.drive-seen   (processed Drive file ids)
# Clips land: reel-app/clients/<handle>/inbox/<UTC-stamp>/  (the client archive)
# Jobs:       reel-app/jobs/<uuid>/photos/ pre-staged locally; job.json goes to
#             R2 via POST /api/worker/enqueue/<id> (photos NEVER uploaded — the
#             worker skips downloads for files it already has).
#
# Batch settling: a drop is processed only when its newest file is >=20 min
# old, so a multi-clip upload in progress is never cut in half. New files
# arriving later form a NEW drop (that's a feature: more footage = more cuts).

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

APP_DIR="$HOME/Claude Code/reel-app"
CLIENTS_DIR="$APP_DIR/clients"
JOBS_DIR="$APP_DIR/jobs"
LOG="$JOBS_DIR/drive-watch.log"
DRIVE_PY="$HOME/.config/personal-drive/drive.py"
DRIVE_PYTHON="$HOME/.config/personal-drive/venv/bin/python"
NTFY="https://ntfy.sh/imabgold-reels-x7k2mq94"
SETTLE_SECS="${SETTLE_SECS:-1200}"  # override for TEST runs only

WORKER_SECRET=$(grep "^WORKER_SECRET=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
WORKER_API=$(grep "^WORKER_API=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
if [[ -z "$WORKER_SECRET" || -z "$WORKER_API" || ! -x "$DRIVE_PYTHON" ]]; then
  echo "$(date): drive-watch: missing config (secret/api/drive venv)" >> "$LOG"
  exit 1
fi

# One instance at a time (downloads can outlive a 15-min interval).
LOCK="$JOBS_DIR/.drive-watch-lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  HOLDER=$(cat "$LOCK/pid" 2>/dev/null)
  if [ -n "$HOLDER" ] && kill -0 "$HOLDER" 2>/dev/null; then exit 0; fi
  if [ -z "$HOLDER" ] && [ -z "$(find "$LOCK" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then exit 0; fi
  rm -rf "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null || exit 0
fi
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK" 2>/dev/null' EXIT

export APP_DIR CLIENTS_DIR JOBS_DIR LOG DRIVE_PY DRIVE_PYTHON NTFY SETTLE_SECS WORKER_SECRET WORKER_API

# NOT exec: exec would replace this shell and the EXIT trap above would never
# fire, leaking the lock dir forever (audit finding, 2026-08-19).
/usr/bin/python3 - <<'PYEOF'
import json, os, re, subprocess, sys, time, uuid, glob, shutil, urllib.request
from datetime import datetime, timezone

E = os.environ
LOG = E["LOG"]

def log(msg):
    with open(LOG, "a") as f:
        f.write(f"{datetime.now():%F %T} drive-watch: {msg}\n")

def drive(*args):
    out = subprocess.run([E["DRIVE_PYTHON"], E["DRIVE_PY"], *args],
                         capture_output=True, text=True, timeout=3600)
    if out.returncode != 0:
        raise RuntimeError(f"drive.py {args[0]} failed: {out.stderr.strip()[-300:]}")
    return json.loads(out.stdout)

def api(method, path, body=None):
    req = urllib.request.Request(
        f"{E['WORKER_API']}/api/worker/{path}", method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {E['WORKER_SECRET']}",
                 # CF WAF 403s urllib's default Python-urllib/3.x agent
                 "User-Agent": "drive-watch/1.0 (Marcus reel worker)",
                 **({"Content-Type": "application/json"} if body is not None else {})})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())

def ntfy(title, msg):
    try:
        req = urllib.request.Request(E["NTFY"], data=msg.encode(), method="POST",
                                     headers={"Title": title, "Tags": "inbox_tray"})
        urllib.request.urlopen(req, timeout=15)
    except Exception:
        pass

VIDEO_EXT = re.compile(r"\.(mp4|mov|m4v|webm|mkv|avi|3gp|mts|m2ts)$", re.I)

# Each cut of a drop gets a distinct creative bias so five cuts from the same
# clips land five different concepts. The architect still owns the format
# decision within the bias; craft law is unchanged.
ANGLES = [
    "your own first-choice concept, no added constraint",
    "a save-magnet structure: checklist, numbered tips, or do-this-now steps",
    "a first-person identity or confession hook in the subject's own voice",
    "a process or transformation arc: before, during, after",
    "an expectation-inversion hook: open where this content category never opens",
]

now = time.time()
for cfg_path in sorted(glob.glob(os.path.join(E["CLIENTS_DIR"], "*", "drive.json"))):
    cdir = os.path.dirname(cfg_path)
    handle = os.path.basename(cdir)
    try:
        cfg = json.load(open(cfg_path))
        seen_path = os.path.join(cdir, ".drive-seen")
        seen = set(open(seen_path).read().split()) if os.path.exists(seen_path) else set()

        files = drive("ls", cfg["folder_id"])
        vids = [f for f in files
                if f.get("mimeType") != "application/vnd.google-apps.folder"
                and VIDEO_EXT.search(f.get("name", ""))]
        # A file we can't use must not vanish silently: tell Marcus ONCE
        # (folders can't be pulled; odd extensions won't render).
        oddballs = [f for f in files if f not in vids and f["id"] not in seen]
        if oddballs:
            names = ", ".join(f.get("name", "?") for f in oddballs[:5])
            log(f"{handle}: ignoring non-video item(s): {names}")
            ntfy(f"Drive watch: unusable upload from {handle}",
                 f"Ignored (not a video file the pipeline takes): {names}. "
                 f"If it's real footage, ask them to re-send as mp4/mov.")
            with open(seen_path, "a") as f:
                for o in oddballs:
                    f.write(o["id"] + "\n")
            seen.update(o["id"] for o in oddballs)
        new = [f for f in vids if f["id"] not in seen]
        if not new:
            continue

        # Settle: the folder as a WHOLE must be quiet, not just the unseen
        # files — otherwise a drop uploaded over an hour is chopped into
        # several drops and each one burns a full set of cuts.
        def mtime(f):
            return datetime.fromisoformat(
                f["modifiedTime"].replace("Z", "+00:00")).timestamp()
        newest = max(mtime(f) for f in vids)
        if now - newest < int(E["SETTLE_SECS"]):
            log(f"{handle}: {len(new)} new file(s) still settling, waiting")
            continue

        # Daily render ceiling per client — the backstop against a bulk
        # upload (or a bug) queueing unbounded Opus renders. Unprocessed
        # footage just waits for tomorrow's quota.
        cuts = int(cfg.get("cuts", 5))
        cap = int(cfg.get("max_cuts_per_day", 10))
        quota_path = os.path.join(cdir, ".drive-quota")
        today = datetime.now().strftime("%F")
        used = 0
        if os.path.exists(quota_path):
            d, _, n = open(quota_path).read().partition(" ")
            used = int(n) if d == today and n.strip().isdigit() else 0
        if used + cuts > cap:
            log(f"{handle}: daily cap {cap} would be exceeded ({used} used), holding drop")
            ntfy(f"Drive watch: {handle} at daily cap",
                 f"New footage is waiting but {used}/{cap} cuts already ran today. "
                 f"It processes tomorrow, or raise max_cuts_per_day in drive.json.")
            continue

        # Library-dump guard (Sahil uploaded his whole camera roll, 121
        # items, 2026-08-20): a drop bigger than the per-drop clip cap is
        # cut from its NEWEST clips only; the rest are marked seen and stay
        # in Drive (which IS the customer's library — no need to mirror a
        # camera roll onto a 460GB Mac that lives chronically full).
        drop_cap = int(cfg.get("max_clips_per_drop", 15))
        skipped = 0
        if len(new) > drop_cap:
            new_sorted = sorted(new, key=mtime)
            overflow, new = new_sorted[:-drop_cap], new_sorted[-drop_cap:]
            skipped = len(overflow)
            with open(seen_path, "a") as f:
                for o in overflow:
                    f.write(o["id"] + "\n")
            log(f"{handle}: {skipped + drop_cap} new clips - cutting from the "
                f"newest {drop_cap}, {skipped} left in Drive (marked seen)")
            ntfy(f"Drive watch: big drop from {handle}",
                 f"{skipped + drop_cap} new clips landed. Cutting from the "
                 f"newest {drop_cap}; the other {skipped} stay in Drive "
                 f"untouched (raise max_clips_per_drop in drive.json to use "
                 f"more).")

        # Disk guard: never start a download that could squeeze the Mac.
        st = os.statvfs(E["JOBS_DIR"])
        free_gb = st.f_bavail * st.f_frsize / 1e9
        drop_gb = sum(int(f.get("size", 0)) for f in new) / 1e9
        if free_gb - drop_gb < 15:
            log(f"{handle}: HOLDING drop - {drop_gb:.1f}GB download vs "
                f"{free_gb:.1f}GB free would leave <15GB")
            ntfy(f"Drive watch: {handle} drop held (disk)",
                 f"The drop needs {drop_gb:.1f}GB but the Mac has only "
                 f"{free_gb:.1f}GB free. Clear space; the watcher retries "
                 f"every 15 min.")
            continue

        # Download the drop once into the client archive.
        stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M")
        drop_dir = os.path.join(cdir, "inbox", stamp)
        os.makedirs(drop_dir, exist_ok=True)
        clips = []
        for f in sorted(new, key=mtime):
            ext = VIDEO_EXT.search(f["name"]).group(1).lower()
            dest = os.path.join(drop_dir, f"{len(clips)+1:02d}.{ext}")
            log(f"{handle}: downloading {f['name']} ({f.get('size','?')} bytes)")
            drive("get", f["id"], dest)
            if os.path.getsize(dest) > 0:
                clips.append(dest)
        if not clips:
            log(f"{handle}: drop had no downloadable clips, skipping")
            continue

        # Marcus's call 2026-08-19: the delivered reels are this client's
        # PATTERN BANK — cuts born from the viral playbook, treated as the
        # proven style. The architect of every new cut studies them and cuts
        # in the same vein (inspiration, not a do-not-repeat blacklist).
        hist = ""
        bank = os.path.expanduser(f"~/Claude Code/viral-bank/{handle}")
        if os.path.isdir(bank):
            hist += (f" This client's PROVEN-VIRAL bank is at '{bank}' - "
                     f"JOBS.md Phase A step 0 binds you: study index.md and "
                     f"the top-ranked clips there before deciding, and cut in "
                     f"their vein.")
        dpath = os.path.join(cdir, "delivered.md")
        if os.path.exists(dpath):
            lines = [l for l in open(dpath).read().splitlines() if l.startswith("- ")]
            if lines:
                hist += (" PROVEN REELS for this client - these shipped cuts are "
                        "the house style, built from the viral playbook. Study "
                        "them before deciding and cut in the same vein: same "
                        "series feel, same energy, similar mechanisms. Fresh "
                        "wording (never reuse an exact hook line), but "
                        "similarity to these is the goal, not a fault: "
                        + " | ".join(lines[-15:]))

        # Enqueue <cuts> jobs. Each job gets up to 5 clips; with a bigger drop
        # the selection rotates so cuts see different subsets.
        queued = []
        for n in range(cuts):
            jid = str(uuid.uuid4())
            jdir = os.path.join(E["JOBS_DIR"], jid, "photos")
            os.makedirs(jdir, exist_ok=True)
            take = clips if len(clips) <= 5 else [
                clips[(n + i) % len(clips)] for i in range(5)]
            photos = []
            for i, src in enumerate(take, 1):
                name = f"{i:02d}{os.path.splitext(src)[1]}"
                # hardlink, not copy: a 500MB clip would otherwise exist once
                # in inbox/ plus once per cut. Same volume, and job-folder
                # cleanup can't touch the inbox archive through a hardlink.
                dst = os.path.join(jdir, name)
                try:
                    os.link(src, dst)
                    # 444 guards the shared inode — a render session writing
                    # into photos/ must not corrupt the client's archive copy.
                    os.chmod(dst, 0o444)
                except OSError as le:
                    log(f"{handle}: hardlink failed ({le}), copying {name}")
                    shutil.copy2(src, dst)
                photos.append(f"jobs/{jid}/photos/{name}")
            note = (f"Paid founding-subscriber job: cut {n+1} of {cuts}, all cut "
                    f"from the same footage drop (the other cuts run as separate "
                    f"jobs). Each of the {cuts} cuts must land a clearly different "
                    f"concept, so for THIS cut bias toward: {ANGLES[n % len(ANGLES)]}. "
                    f"The bias guides your format choice; all craft law still "
                    f"applies. Client brief: {cfg.get('note', '')}{hist}")
            job = {"id": jid, "photos": photos, "email": cfg["email"],
                   "phone": cfg.get("phone", ""), "paid": True,
                   "client": handle, "marcus_note": note}
            res = api("POST", f"enqueue/{jid}", job)
            if not res.get("ok"):
                raise RuntimeError(f"enqueue {jid} failed: {res}")
            queued.append(jid)
            log(f"{handle}: queued cut {n+1}/{cuts} as {jid[:8]} ({len(photos)} clips)")

        # Only after every enqueue succeeded does the drop count as processed.
        with open(seen_path, "a") as f:
            for fobj in new:
                f.write(fobj["id"] + "\n")
        with open(quota_path, "w") as f:
            f.write(f"{today} {used + len(queued)}")
        ntfy(f"Footage drop: {handle}",
             f"{len(clips)} clip(s) from {handle}'s Drive folder -> {len(queued)} "
             f"cuts queued. Renders start on the next worker wake.")
        log(f"{handle}: drop {stamp} done, {len(queued)} jobs queued")
    except Exception as e:
        log(f"{handle}: ERROR {e}")
        # Throttle the push: a broken drop retries every 15 min and would
        # otherwise storm ntfy. The log gets every occurrence regardless.
        mark = os.path.join(cdir, ".drive-err-ntfy")
        last = os.path.getmtime(mark) if os.path.exists(mark) else 0
        if now - last > 3600:
            open(mark, "w").write(str(e)[:300])
            ntfy(f"Drive watch ERROR: {handle}", str(e)[:300])
PYEOF
