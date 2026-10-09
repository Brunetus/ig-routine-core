#!/bin/zsh
# release-reel.sh — the ONLY path that ships a rendered reel to the customer.
# Called two ways:
#   release-reel.sh <job-id>   Marcus approves: release NOW (clears HOLD).
#   release-reel.sh --scan     Auto-release pass: ship every pending job whose
#                              review window (20 min) has expired, or that has
#                              an APPROVED marker. Jobs with a HOLD file are
#                              skipped until the HOLD is removed.
# Review-gate contract with run-reel-worker.sh:
#   render success  -> worker writes $JOB/PENDING-RELEASE (epoch inside)
#   salvaged render -> worker writes $JOB/SALVAGED + HOLD (finished but never
#                      QA'd; NO scan touches it — only an explicit
#                      `release-reel.sh <id>` converts it and ships)
#   Marcus pauses   -> touch $JOB/HOLD          (blocks auto-release)
#   Marcus approves -> touch $JOB/APPROVED      (ships on next 2-min scan)
#                      or runs this script with the id (ships immediately)
# Atomic claim: PENDING-RELEASE is mv'd to .RELEASING before any network I/O,
# so notify-scan and worker-backstop can never double-ship the same job.
#
# ECLIP JOBS (2026-09-10). A job whose job.json carries an `eclip` object is a
# daily reel for an eclip app customer, not a web-page delivery. It:
#   - NEVER auto-releases. It is HELD from the moment it is enqueued AND
#     `--scan` skips it outright on the `eclip` key. Marcus's explicit
#     `release-reel.sh <id>` is the only thing that ships one, and only over a
#     QA-passed render (`out/DONE`).
#   - carries `ECLIP-QUEUED` from enqueue until the worker claims it. That
#     marker, NOT the HOLD text, is what tells run-reel-worker.sh that a HOLD
#     on a not-yet-rendered eclip job is not a park. HOLD means exactly what
#     it has always meant everywhere.
#   - skips the landing page and the email entirely. Delivery is the
#     reel-archive bucket the phone restores from: <ig_user_id>/<day>.mp4,
#     .jpg and .json, plus the reel_archive / user_reels rows and the clip
#     rows moving to 'cut'. That body lives in reels-ios/mac/lib/deliver.mjs,
#     the same code `review.mjs approve` uses.
#   - still calls the worker `complete` route, so the server job leaves the
#     queue exactly like every other finished job.
#
#   release-reel.sh <id> [--day yyyy-MM-dd] [--replace] [--dry-run]
#     --day      override the day key recorded at enqueue
#     --replace  overwrite a day this account already has a reel for
#     --dry-run  eclip only: prove the wiring, upload nothing, write nothing

export PATH="$HOME/.nvm/versions/node/v20.20.2/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

APP_DIR="$HOME/Claude Code/reel-app"
JOBS_DIR="$APP_DIR/jobs"
LOG="$JOBS_DIR/worker-$(date +%F).log"
WINDOW_SECS=1200   # 20-minute review window
NTFY="https://ntfy.sh/imabgold-reels-x7k2mq94"

WORKER_SECRET=$(grep "^WORKER_SECRET=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
WORKER_API=$(grep "^WORKER_API=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
RESEND_KEY=$(grep "^RESEND_API_KEY=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
if [[ -z "$WORKER_SECRET" || -z "$WORKER_API" ]]; then
  echo "$(date): release-reel: WORKER_SECRET/WORKER_API missing" >> "$LOG"; exit 1
fi
API="$WORKER_API/api/worker"
AUTH="Authorization: Bearer $WORKER_SECRET"
api() { curl -s --max-time 120 -H "$AUTH" "$@"; }

DELIVER="$HOME/Claude Code/reels-ios/mac/lib/deliver.mjs"
# job_who: whose job this is, at the front of every push title.
source "${0:A:h}/job-who.sh"
NODE="$HOME/.nvm/versions/node/v20.20.2/bin/node"

# --- flags (the manual eclip path only; --scan takes none of them) ---
# `shift 2` on a last-position `--day` is a zsh error, not a shift: the loop
# then spins on the same argument forever. Check the count first.
DAY_OVERRIDE=""; REPLACE=""; DRYRUN=""; NOCOVER=""
SALVAGED_NOTE=""   # set only when THIS run converts a salvaged job (never inherited from the environment)
ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --day)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "--day needs a date: release-reel.sh <job-id> --day yyyy-MM-dd"; exit 2
      fi
      DAY_OVERRIDE="$2"; shift 2 ;;
    --replace) REPLACE="1"; shift ;;
    --dry-run) DRYRUN="1"; shift ;;
    # An eclip reel ships WITH its cover (Marcus, 2026-10-01): releasing it is
    # his approval of both. --no-cover is the deliberate way to ship one alone.
    --no-cover) NOCOVER="1"; shift ;;
    # --scan is a MODE, not a flag: it is how run-reel-notify.sh (every 2 min)
    # and run-reel-worker.sh ship every paying customer's reel. It must reach
    # the dispatch below untouched — an "unknown flag" exit here would silently
    # stop the entire auto-release pass.
    --scan)    ARGS+=("$1"); shift ;;
    --*)       echo "unknown flag '$1' (--day, --replace, --dry-run, --no-cover)"; exit 2 ;;
    *)         ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]}"
if [ -n "$DAY_OVERRIDE" ]; then
  case "$DAY_OVERRIDE" in
    [0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]) ;;
    *) echo "--day must be yyyy-MM-dd, got '$DAY_OVERRIDE'"; exit 2 ;;
  esac
fi

# Read one dotted key out of a job.json. Empty string when it is not there.
job_field() {
  /usr/bin/python3 - "$1" "$2" <<'PYFIELD' 2>/dev/null
import json, sys
try:
    cur = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for k in sys.argv[2].split("."):
    if not isinstance(cur, dict):
        sys.exit(0)
    cur = cur.get(k)
print(cur if cur is not None else "")
PYFIELD
}

# One field of the `eclip` block. job.json is the truth once the worker has
# claimed the job; ECLIP.json is what clips-watch.mjs staged before that, so a
# folder that was enqueued but never claimed is still readable.
eclip_field() {
  local V
  V=$(job_field "$1/job.json" "eclip.$2")
  [ -n "$V" ] && { printf '%s\n' "$V"; return; }
  job_field "$1/ECLIP.json" "$2"
}

# Is this job folder an eclip job? The `eclip` object with an ig_user_id in it
# IS the contract — nothing else about the folder is allowed to decide.
is_eclip() {
  [ -n "$(eclip_field "$1" ig_user_id)" ]
}

# ---- eclip delivery: the reel goes to the customer's PHONE. No page, no
# email, no Drive copy. mac/lib/deliver.mjs does the archive uploads and the
# rows; this function only decides what to hand it and what to say afterwards.
release_eclip() {
  local ID="$1" JOB="$JOBS_DIR/$1"
  local IGID ECLIP_USER DAY WHO
  IGID=$(eclip_field "$JOB" ig_user_id)
  # NOT `USERNAME`: that is one of zsh's own special parameters (the login
  # user), so assigning to it silently does nothing and the handle reads as
  # whoever is logged in.
  ECLIP_USER=$(eclip_field "$JOB" username)
  DAY="${DAY_OVERRIDE:-$(eclip_field "$JOB" day)}"
  WHO=$(job_who "$JOB")
  if [ -z "$IGID" ]; then
    echo "eclip release $ID BLOCKED: neither job.json nor ECLIP.json carries eclip.ig_user_id."
    echo "$(date): eclip release $ID ABORTED - neither job.json nor ECLIP.json has eclip.ig_user_id" >> "$LOG"; return 1
  fi
  if [ ! -x "$NODE" ]; then
    echo "eclip release $ID BLOCKED: node is missing at $NODE."
    echo "$(date): eclip release $ID ABORTED - node missing at $NODE" >> "$LOG"; return 1
  fi
  if [ ! -f "$DELIVER" ]; then
    echo "eclip release $ID BLOCKED: deliver.mjs is missing at $DELIVER."
    echo "$(date): eclip release $ID ABORTED - deliver.mjs missing at $DELIVER" >> "$LOG"; return 1
  fi
  # The kit IS the delivery on the phone: caption, why-views and concept are
  # read straight out of it. A reel with no kit is a reel with no post.
  if [ ! -f "$JOB/out/kit.json" ]; then
    echo "eclip release $ID BLOCKED: out/kit.json is missing, so the phone would get a reel with no caption. (JOBS.md 'eclip jobs' is what writes it.)"
    echo "$(date): eclip release $ID ABORTED - out/kit.json missing (JOBS.md 'eclip jobs' writes it)" >> "$LOG"
    curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · eclip release BLOCKED" -H "Priority: high" -H "Tags: rotating_light" \
      -d "Job ${ID:0:8} (@${ECLIP_USER}) has no out/kit.json, so the phone would get a reel with no caption. Parked." > /dev/null 2>&1
    return 1
  fi

  local DARGS=(--ig-user-id "$IGID" --job-id "$ID"
               --video "$JOB/out/reel-clean.mp4" --kit "$JOB/out/kit.json"
               --cut-paths-prefix "reel-app")
  [ -f "$JOB/out/plan.json" ]  && DARGS+=(--plan "$JOB/out/plan.json")
  [ -f "$JOB/out/poster.jpg" ] && DARGS+=(--poster "$JOB/out/poster.jpg")
  # The Instagram cover (JOBS.md "eclip jobs", 2026-10-01). An eclip reel
  # ships WITH its cover: releasing it is Marcus's approval of both, so the
  # paths always go to deliver.mjs with --require-cover and deliver.mjs is
  # the one judge (no cover, a skipped/warned/recipe-less one, the wrong
  # style for this account: it refuses before any upload and says why).
  # --no-cover passes NOTHING: a cover he rejected by eye must not ship just
  # because it passes the machine checks.
  [ -z "$NOCOVER" ] && DARGS+=(--cover "$JOB/out/cover.jpg" --cover-meta "$JOB/out/cover.json" --require-cover)
  [ -n "$DAY" ]     && DARGS+=(--day "$DAY")
  [ -n "$REPLACE" ] && DARGS+=(--replace)
  [ -n "$DRYRUN" ]  && DARGS+=(--dry-run)

  local OUT RC
  OUT=$("$NODE" "$DELIVER" "${DARGS[@]}" 2>&1); RC=$?
  echo "$OUT" >> "$LOG"
  printf '%s\n' "$OUT" | grep -v '^DELIVERED-DAY '""
  # One reel per local day is the phone's rule, not a bug to route around, so
  # spell out the two deliberate ways past it rather than leaving him guessing.
  if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "already has a reel for"; then
    echo ""
    echo "Two ways out, both deliberate:"
    echo "  replace that day :  release-reel.sh $ID --replace"
    echo "  ship it tomorrow :  release-reel.sh $ID --day $(date -v+1d +%F)"
    if [ -n "$(eclip_field "$JOB" revision.round)" ]; then
      echo ""
      echo "This job is a REVISION, and a revision keeps the day key of the cut it revises."
      echo "If that earlier cut already went out, --replace is the answer: it is the same"
      echo "reel for the same day, edited the way you asked."
    fi
  fi
  if [ "$RC" -ne 0 ]; then
    echo "$(date): eclip release $ID FAILED in deliver.mjs" >> "$LOG"
    echo "$OUT" | tail -3
    return 1
  fi
  DAY=$(printf '%s' "$OUT" | sed -n 's/^DELIVERED-DAY //p' | tail -1)

  if [ -n "$DRYRUN" ]; then
    echo "DRY RUN: nothing uploaded, nothing written. Would have delivered @${ECLIP_USER} ${DAY}."
    return 0
  fi

  # Close the server job exactly like every other finished job, so it leaves
  # the queue and the worker never re-dispatches it. The reel file rides along
  # because the complete route requires it; nobody is sent to the page.
  local RES
  RES=$(api -X POST -F "reel=@$JOB/out/reel-clean.mp4;type=video/mp4" "$API/complete/$ID")
  echo "eclip release $ID complete: $RES" >> "$LOG"
  if ! printf '%s' "$RES" | grep -q '"ok":true'; then
    # The customer HAS the reel (the archive write above is the delivery of
    # record). Only the queue marker is stuck, so this is a warning, not a
    # rollback — re-shipping would replace the day for nothing.
    echo "$(date): eclip $ID delivered to the app but the worker complete call failed" >> "$LOG"
    curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · eclip delivered, queue not closed" -H "Tags: warning" \
      -d "Reel for @${ECLIP_USER} ${DAY} IS on their phone, but the worker complete call failed so the job is still in the queue. Check jobs/worker log." > /dev/null 2>&1
  fi

  date +%s > "$JOB/RELEASED"
  rm -f "$JOB/.RELEASING"
  printf '%s | eclip @%s | %s | archive %s/%s.mp4\n' \
    "$(date '+%F %H:%M')" "$ECLIP_USER" "${ID:0:8}" "$IGID" "$DAY" >> "$JOBS_DIR/OUTBOX.md"
  osascript -e "display notification \"eclip delivered to @$ECLIP_USER ($DAY)\" with title \"reel worker\" sound name \"Glass\"" 2>/dev/null
  curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · eclip reel delivered" -H "Tags: white_check_mark" \
    -d "delivered to app: @${ECLIP_USER} ${DAY}" > /dev/null 2>&1
  return 0
}

release_one() {
  local ID="$1" JOB="$JOBS_DIR/$1"
  local WHO
  WHO=$(job_who "$JOB")
  if [ -n "$DRYRUN" ]; then
    # A dry run proves the wiring and must leave the folder exactly as it is:
    # no claim, no marker moved, no state to hand back if it fails.
    echo "DRY RUN: $ID (no claim, no upload, no marker written)"
  else
    # Atomic claim — mv fails if another scan claimed it first.
    mv "$JOB/PENDING-RELEASE" "$JOB/.RELEASING" 2>/dev/null || return 1
    # HOLD re-check AFTER the claim: closes the race where Marcus touches HOLD
    # between the scan's check and the claim. The manual path clears HOLD
    # before calling us, so an explicit release still overrides.
    if [ -f "$JOB/HOLD" ]; then
      mv "$JOB/.RELEASING" "$JOB/PENDING-RELEASE" 2>/dev/null
      return 1
    fi
    rm -f "$JOB/APPROVED"
  fi

  # One deliverable on every tier since 2026-08-26 (no watermarked file).
  local CHECK_FILES=("$JOB/out/reel-clean.mp4")
  if [ ! -f "$JOB/out/reel-clean.mp4" ]; then
    echo "$(date): release $ID ABORTED - output files missing" >> "$LOG"
    [ -z "$DRYRUN" ] && mv "$JOB/.RELEASING" "$JOB/PENDING-RELEASE" 2>/dev/null
    return 1
  fi

  # Sanity: the deliverable must decode with a sane duration before it can
  # ship. A watchdog kill mid-encode leaves a truncated mp4 (no moov atom)
  # that still passes the existence check above — ffmpeg then reports no
  # Duration at all, which this catches. Spec range is 7-20s; accept 6-21.
  local FFBIN F DUR
  FFBIN=$(ls "$HOME/Library/Python/3.9/lib/python/site-packages/imageio_ffmpeg/binaries/"ffmpeg-* 2>/dev/null | head -1)
  if [ -n "$FFBIN" ]; then
    for F in "${CHECK_FILES[@]}"; do
      DUR=$("$FFBIN" -hide_banner -i "$F" 2>&1 | sed -n 's/.*Duration: \([0-9:.]*\),.*/\1/p')
      case "$DUR" in
        00:00:0[6-9].*|00:00:1[0-9].*|00:00:2[01].*) ;;
        *)
          echo "$(date): release $ID BLOCKED - ${F:t} unreadable or bad duration '${DUR:-none}'" >> "$LOG"
          [ -z "$DRYRUN" ] && mv "$JOB/.RELEASING" "$JOB/PENDING-RELEASE" 2>/dev/null
          # HOLD alongside the re-arm: a truncated file never heals, so without
          # this the 2-min scan re-attempts forever and storms ntfy. The HOLD
          # parks it (4h nag loop covers it); a deliberate release-reel.sh <id>
          # still clears the HOLD and forces one attempt per command.
          [ -z "$DRYRUN" ] && echo "blocked by decode/duration check ($(date))" > "$JOB/HOLD"
          curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · Reel release BLOCKED" -H "Priority: high" -H "Tags: rotating_light" \
            -d "Job ${ID:0:8}: ${F:t} failed the decode/duration check (got '${DUR:-unreadable}'). Likely a truncated render. Parked on HOLD - inspect jobs/$ID/out/." > /dev/null 2>&1
          return 1 ;;
      esac
    done
  else
    echo "$(date): release $ID - ffmpeg binary missing, skipping decode check" >> "$LOG"
  fi

  # ---- THE FORK. An eclip job goes to a phone, not to a page: no landing
  # page, no email, no SMS line, no Drive copy. Everything below this block is
  # the web-customer path and must not run for one. ----
  if is_eclip "$JOB"; then
    if release_eclip "$ID"; then
      return 0
    fi
    [ -z "$DRYRUN" ] && mv "$JOB/.RELEASING" "$JOB/PENDING-RELEASE" 2>/dev/null
    # Re-assert the HOLD: an eclip job that failed to deliver must not be
    # sitting armed for anything, and the 4h park nag will surface it.
    [ -z "$DRYRUN" ] && echo "eclip delivery failed $(date)" > "$JOB/HOLD"
    # A salvaged render (never QA'd) that did not ship is STILL unverified:
    # the explicit command consumed its flag, and a blocked release (no
    # cover, most often) must give it back, or review.mjs calls it "pending".
    [ -z "$DRYRUN" ] && [ -n "$SALVAGED_NOTE" ] && printf '%s\n' "$SALVAGED_NOTE" > "$JOB/SALVAGED"
    return 1
  fi

  # Contact stays out of the job folder; fetch it at send time.
  local RAW="$JOBS_DIR/.release-$ID.json"
  api "$API/job/$ID" > "$RAW"
  # The tier decision and the recipient both come from this fetch. If it
  # failed (CF 403/5xx, timeout, non-JSON), releasing anyway would skip a
  # paid client's Drive copy and email while still stamping RELEASED.
  # Abort and re-arm instead.
  if ! /usr/bin/python3 -c "import json;json.load(open('$RAW'))" 2>/dev/null; then
    rm -f "$RAW"
    echo "$(date): release $ID ABORTED - job fetch unreadable, re-armed" >> "$LOG"
    mv "$JOB/.RELEASING" "$JOB/PENDING-RELEASE" 2>/dev/null
    return 1
  fi
  local EMAIL PHONE PAID
  EMAIL=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW')).get('email',''))" 2>/dev/null)
  PHONE=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW')).get('phone',''))" 2>/dev/null)
  PAID=$(/usr/bin/python3 -c "import json;print('1' if json.load(open('$RAW')).get('paid') else '')" 2>/dev/null)
  CLIENT=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW')).get('client',''))" 2>/dev/null)
  rm -f "$RAW"
  WHO=$(job_who "$JOB" "$EMAIL")

  local META_ARGS=()
  [ -f "$JOB/out/delivery.json" ] && META_ARGS=(-F "meta=@$JOB/out/delivery.json;type=application/json")
  # Preview = the same clean cut with a music bed, and the page plays the
  # preview over the main file whenever it exists. Free tier only: a paid
  # client's page plays their clean cut with its own audio.
  [ -f "$JOB/out/reel-preview.mp4" ] && [ -z "$PAID" ] && META_ARGS+=(-F "preview=@$JOB/out/reel-preview.mp4;type=video/mp4")
  local RES
  # ONE deliverable on every tier (Marcus, 2026-08-26): nothing ships with a
  # watermark, so the page/save file is the clean cut for free and paid alike.
  local PAGE_FILE="$JOB/out/reel-clean.mp4"
  # TWO versions reach the customer and both are sent above/below:
  #   preview.mp4 -> plays inline on the delivery page, carries the music bed
  #   reel.mp4    -> what the Save button downloads, SILENT by design so they
  #                  post it with the trending audio named in delivery.json
  #                  instead of picking their own.
  # The API's third field, `clean`, is NOT sent (2026-08-27). Before the
  # no-watermark change `reel` was the watermarked page copy and `clean` was
  # the unwatermarked download — two genuinely different files. Since
  # 2026-08-26 PAGE_FILE *is* reel-clean.mp4, so `clean` was uploading a
  # byte-identical second copy of the download file, and NOTHING serves it:
  # functions/api/reel/[id].js only ever reads preview.mp4 (inline) and
  # reel.mp4 (?dl=1 + fallback). The API treats `clean` as optional, so
  # dropping it is safe.
  # This was not cosmetic. Job 8a0fc66a died on "413 Payload Too Large" from
  # Cloudflare because the body was clean+clean+preview = 115.8 MB against a
  # 100 MB ceiling. Without the duplicate the same job is 77.3 MB and fits at
  # full quality. It also halves R2 storage per job.
  RES=$(api -X POST -F "reel=@$PAGE_FILE;type=video/mp4" \
                   "${META_ARGS[@]}" \
                   "$API/complete/$ID")
  echo "release $ID complete: $RES" >> "$LOG"
  if ! printf '%s' "$RES" | grep -q '"ok":true'; then
    # Failed upload: put the job back in pending so the next scan retries.
    mv "$JOB/.RELEASING" "$JOB/PENDING-RELEASE" 2>/dev/null
    curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · Reel release FAILED" -H "Priority: high" -H "Tags: rotating_light" \
      -d "Release of job ${ID:0:8} failed at the complete call. It stays pending; check jobs/worker log." > /dev/null 2>&1
    return 1
  fi
  date +%s > "$JOB/RELEASED"
  rm -f "$JOB/.RELEASING"

  # Paid clients also get the clean cut + caption dropped into their Drive
  # "Cut reel" folder (delivery_folder_id in clients/<handle>/drive.json).
  # Best-effort: the email + page above are the delivery of record, so a
  # Drive hiccup logs and pings but never fails the release.
  if [ -n "$PAID" ] && [ -n "$CLIENT" ]; then
    # Record what shipped so the NEXT cut's architect sees it (do-not-repeat
    # context, fed in by the drive watcher). Independent of the Drive copy.
    /usr/bin/python3 - "$JOB/out/delivery.json" "$HOME/Claude Code/reel-app/clients/$CLIENT/delivered.md" "${ID:0:8}" <<'PYDIG'
import json, sys, datetime
d = json.load(open(sys.argv[1]))
hook = d.get("caption", "").split("\n")[0]
audio = (d.get("audio") or {}).get("title", "?")
mech = (d.get("why_views") or "").split(". ")[0][:160]
line = '- %s %s: "%s" · audio: %s · works because: %s\n' % (
    datetime.date.today().isoformat(), sys.argv[3], hook, audio, mech)
open(sys.argv[2], "a").write(line)
PYDIG
    DFID=$(/usr/bin/python3 -c "import json;print(json.load(open('$HOME/Claude Code/reel-app/clients/$CLIENT/drive.json')).get('delivery_folder_id',''))" 2>/dev/null)
    DRIVE_PYTHON="$HOME/.config/personal-drive/venv/bin/python"
    DRIVE_PY="$HOME/.config/personal-drive/drive.py"
    if [ -n "$DFID" ] && [ -x "$DRIVE_PYTHON" ]; then
      CAPTXT="$JOB/out/.caption-$ID.txt"
      DRIVE_OK=1
      /usr/bin/python3 - "$JOB/out/delivery.json" > "$CAPTXT" <<'PYCAP' || DRIVE_OK=0
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get("caption", ""))
a = d.get("audio") or {}
if a.get("title"):
    print()
    print('Audio to add in the app: "%s" - %s' % (a["title"], a.get("artist", "")))
    if a.get("start"):
        print("Start it %s." % a["start"])
PYCAP
      # Descriptive Drive names (Marcus, 2026-08-21): "YYYY-MM-DD · Reel NN · <hook>"
      # where NN = highest existing "Reel NN" in the folder + 1 and <hook> = the
      # caption's first line, cleaned for a filename. Any failure in the naming
      # step falls back to the old reel-<id8> names so a Drive hiccup never
      # blocks a delivery.
      DNAME=$(/usr/bin/python3 - "$JOB/out/delivery.json" "$DFID" "$DRIVE_PYTHON" "$DRIVE_PY" <<'PYNAME' 2>/dev/null
import json, sys, re, subprocess, datetime
cap = (json.load(open(sys.argv[1])).get("caption") or "").strip().splitlines()
hook = cap[0].strip() if cap else ""
hook = re.split(r"[.?!]", hook)[0]          # first sentence only
hook = re.sub(r'[\\/:*?"<>|#]', "", hook).replace("—", "-")
hook = re.sub(r"\s+", " ", hook)[:70].strip(" .,")
if not hook: sys.exit(1)
ls = subprocess.run([sys.argv[3], sys.argv[4], "ls", sys.argv[2]], capture_output=True, text=True).stdout
try: names = [f.get("name", "") for f in json.loads(ls)]
except Exception: names = []
nums = [int(m) for nm in names for m in re.findall(r"\u00b7 Reel (\d+) \u00b7", nm)]
n = (max(nums) if nums else 0) + 1
print("%s · Reel %02d · %s" % (datetime.date.today().isoformat(), n, hook))
PYNAME
)
      if [ -n "$DNAME" ]; then
        VNAME="$DNAME.mp4"; CNAME="$DNAME · caption.txt"
      else
        VNAME="reel-${ID:0:8}.mp4"; CNAME="reel-${ID:0:8}-caption.txt"
        echo "$(date): release $ID - descriptive Drive name failed, using reel-${ID:0:8}" >> "$LOG"
      fi
      "$DRIVE_PYTHON" "$DRIVE_PY" upload "$JOB/out/reel-clean.mp4" --parent "$DFID" --name "$VNAME" >> "$LOG" 2>&1 || DRIVE_OK=0
      "$DRIVE_PYTHON" "$DRIVE_PY" upload "$CAPTXT" --parent "$DFID" --name "$CNAME" >> "$LOG" 2>&1 || DRIVE_OK=0
      rm -f "$CAPTXT"
      if [ "$DRIVE_OK" = "1" ]; then
        echo "$(date): release $ID - clean cut + caption copied to $CLIENT's Drive delivery folder" >> "$LOG"
      else
        curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · Drive delivery copy FAILED" -H "Tags: warning"           -d "Reel ${ID:0:8} released fine (email+page), but the copy into $CLIENT's Cut reel folder failed - check jobs/worker log." > /dev/null 2>&1
      fi
    fi
  fi

  local URL="$WORKER_API/reel?job=$ID"
  if [ -n "$PAID" ]; then
    # Paid client: email is the delivery channel, no SMS forward needed.
    printf '%s | %s | %s | %s (PAID - emailed, no SMS needed)\n' \
      "$(date '+%F %H:%M')" "$PHONE" "$EMAIL" "$URL" >> "$JOBS_DIR/OUTBOX.md"
  else
    printf '%s | %s | %s | %s\n  SMS> Your reel is ready 🎬 %s\n' \
      "$(date '+%F %H:%M')" "$PHONE" "$EMAIL" "$URL" "$URL" >> "$JOBS_DIR/OUTBOX.md"
  fi
  if [ -n "$RESEND_KEY" ] && [ -n "$EMAIL" ]; then
    local BODY
    if [ -n "$PAID" ]; then
      BODY="It's done. Cut from your footage by the IMABGOLD Reels engine.\n\nWatch and download it here: $URL\n\nThat file is the clean version, no watermark. It's also waiting in the Cut reel folder of your Drive, next to a text file with your caption and the audio to add when you post.\n\nAnything you want changed, just reply.\n\n- Marc"
    else
      BODY="It's done. Cut from your own videos by the IMABGOLD Reels engine.\n\nWatch it here: $URL\n\nIt's yours to post, no watermark. The page also has your caption and the audio to use when you post. Love it? Founding creators get up to 100 reels a month, it's on the same page.\n\n- Marc"
    fi
    curl -s --max-time 30 -X POST "https://api.resend.com/emails" \
      -H "Authorization: Bearer $RESEND_KEY" -H "Content-Type: application/json" \
      -d "{\"from\":\"Marc <marcus@ibuildapp.ca>\",\"to\":[\"$EMAIL\"],\"subject\":\"Your reel is ready 🎬\",\"text\":\"$BODY\"}" >> "$LOG" 2>&1
    echo "" >> "$LOG"
  fi
  if [ -n "$PAID" ]; then
    osascript -e "display notification \"Paid reel released and emailed (${ID:0:8})\" with title \"reel worker\"" 2>/dev/null
    curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · Paid reel released" -H "Tags: white_check_mark" \
      -d "Paid cut ${ID:0:8} is live and emailed. Nothing to do." > /dev/null 2>&1
  else
    osascript -e "display notification \"Reel RELEASED — text $PHONE (see jobs/OUTBOX.md)\" with title \"reel worker\" sound name \"Glass\"" 2>/dev/null
    curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · Reel released" -H "Tags: white_check_mark" \
      -d "Reel for $PHONE is live and emailed. The text to send them is in jobs/OUTBOX.md." > /dev/null 2>&1
  fi
  return 0
}

if [ "$1" = "--scan" ]; then
  NOW=$(date +%s)
  # ---- Orphan recovery: a crash/reboot between the .RELEASING claim and the
  # success cleanup leaves a job no glob below would ever see again. ctime
  # updates on the claim rename, so an old-ctime .RELEASING with no RELEASED
  # sibling means the release died mid-flight: re-arm it. Safe to retry — the
  # complete endpoint is idempotent and the email only fires on an attempt
  # that actually saw ok:true, which a crashed attempt never did. ----
  ORPHAN_SECS="${RELEASE_ORPHAN_SECS:-300}"
  for R in "$JOBS_DIR"/*/.RELEASING(N); do
    JOB_DIR="${R:h}"; ID="${JOB_DIR:t}"
    CLAIMED=$(stat -f %c "$R" 2>/dev/null || echo "$NOW")
    [ $((NOW - CLAIMED)) -lt "$ORPHAN_SECS" ] && continue  # release in flight
    if [ -f "$JOB_DIR/RELEASED" ]; then rm -f "$R"; continue; fi
    mv "$R" "$JOB_DIR/PENDING-RELEASE" 2>/dev/null
    WHO=$(job_who "$JOB_DIR")
    # HOLD guard (2026-08-27). Recovery was the ONE path with no HOLD check.
    # It still hands the claim back to PENDING-RELEASE — a held job must stay
    # visible to `release-reel.sh <id>`, which exits 1 when PENDING-RELEASE is
    # missing, so a bare `continue` here would strand a held job where neither
    # the scan nor Marcus could ship it without renaming files by hand. What
    # changes is that a held job is never announced as "re-armed for
    # auto-release", because it is not: the pending loop below skips it while
    # HOLD exists.
    if [ -f "$JOB_DIR/HOLD" ] || is_eclip "$JOB_DIR"; then
      echo "$(date): recovered orphaned release claim for $ID - HELD, parked (no auto-release while HOLD exists)" >> "$LOG"
      curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · Held reel recovered" -H "Tags: warning" \
        -d "Job ${ID:0:8} had an interrupted release and is on HOLD. Parked, NOT re-armed. release-reel.sh ${ID} ships it when you're ready." > /dev/null 2>&1
      continue
    fi
    echo "$(date): recovered orphaned release claim for $ID (re-armed)" >> "$LOG"
    curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · Reel release recovered" -H "Tags: warning" \
      -d "Job ${ID:0:8} had an interrupted release (crash or reboot). Re-armed for auto-release." > /dev/null 2>&1
  done
  for P in "$JOBS_DIR"/*/PENDING-RELEASE(N); do
    JOB_DIR="${P:h}"; ID="${JOB_DIR:t}"
    # eclip jobs NEVER auto-release. The HOLD written at enqueue already stops
    # them; this is the second lock, on the `eclip` key itself, so a deleted
    # or missing HOLD cannot put a reel on a customer's phone unreviewed.
    is_eclip "$JOB_DIR" && continue
    [ -f "$JOB_DIR/HOLD" ] && continue
    if [ -f "$JOB_DIR/APPROVED" ]; then release_one "$ID"; continue; fi
    TS=$(cat "$P" 2>/dev/null)
    [ -n "$TS" ] && [ $((NOW - TS)) -ge $WINDOW_SECS ] && release_one "$ID"
  done
  # ---- Stale-park reminder: a HOLD or SALVAGED job never auto-releases and
  # its one alert fired at park time — without this, one missed notification
  # means a customer sits on the "about 45 minutes" page forever. Re-nag every
  # 4h once a park is older than 2h. ----
  for H in "$JOBS_DIR"/*/HOLD(N) "$JOBS_DIR"/*/SALVAGED(N); do
    JOB_DIR="${H:h}"; ID="${JOB_DIR:t}"
    [ -f "$JOB_DIR/RELEASED" ] && continue
    # Settled or deliberately silent jobs never nag (2026-09-14: the old
    # one-uuid-per-round chains and rejected cuts kept HOLD and nagged
    # Marcus every 4 h for days). NO-NAG = "I know it is parked, leave it".
    [ -f "$JOB_DIR/REJECTED" ] && continue
    [ -f "$JOB_DIR/SUPERSEDED-BY" ] && continue
    [ -f "$JOB_DIR/NO-NAG" ] && continue
    HAGE=$((NOW - $(stat -f %m "$H" 2>/dev/null || echo "$NOW")))
    [ "$HAGE" -lt 7200 ] && continue
    LASTNAG=$(cat "$JOB_DIR/.park-nag" 2>/dev/null || echo 0)
    [ $((NOW - LASTNAG)) -lt 14400 ] && continue
    echo "$NOW" > "$JOB_DIR/.park-nag"
    WHO=$(job_who "$JOB_DIR")
    curl -s -m 15 -X POST "$NTFY" -H "Title: $WHO · Reel still parked" -H "Priority: high" -H "Tags: hourglass_flowing_sand" \
      -d "Job ${ID:0:8} has been parked (${H:t}) for $((HAGE / 3600))h and the customer is still on the waiting page. release-reel.sh $ID ships it. If you fail it instead, delete the HOLD/SALVAGED markers to stop this reminder." > /dev/null 2>&1
  done
  exit 0
fi

ID="$1"
if [ -z "$ID" ] || [ ! -d "$JOBS_DIR/$ID" ]; then
  echo "usage: release-reel.sh <job-id> [--day yyyy-MM-dd] [--replace] [--dry-run]"
  echo "       release-reel.sh --scan"
  exit 1
fi

# ---- FIRST, before anything is read, claimed or moved: the eclip-only flags.
# A dry run on a WEB job would skip the claim, the HOLD check and the
# PENDING-RELEASE gate and then run the real delivery — email, Drive copy,
# complete — while leaving PENDING-RELEASE unconsumed for --scan to ship a
# second time. There is no dry path through the web branch, so refuse. ----
if ! is_eclip "$JOBS_DIR/$ID"; then
  BAD=""
  [ -n "$DRYRUN" ]       && BAD="--dry-run"
  [ -n "$REPLACE" ]      && BAD="${BAD:+$BAD }--replace"
  [ -n "$DAY_OVERRIDE" ] && BAD="${BAD:+$BAD }--day"
  if [ -n "$BAD" ]; then
    echo "$BAD is eclip-only, and $ID is not an eclip job."
    echo "A web job has no dry path: releasing it emails the customer and copies to Drive."
    echo "Run it with no flags when you mean it."
    exit 2
  fi
fi

# A rejected eclip job is closed. Re-shipping it would put on a customer's
# phone the exact cut Marcus refused, and its clips are already back in the
# queue for a fresh one.
if [ -f "$JOBS_DIR/$ID/REJECTED" ]; then
  echo "job $ID was REJECTED - $(head -2 "$JOBS_DIR/$ID/REJECTED" | tail -1)"
  echo "Its clips went back in the queue; the watcher cuts a new reel. Nothing to release."
  exit 1
fi
# Already delivered. The real path is stopped by the missing PENDING-RELEASE,
# but a dry run skips that gate (nothing is ever written for it to consume), so
# say it here where both paths see it.
if [ -f "$JOBS_DIR/$ID/RELEASED" ] && [ ! -f "$JOBS_DIR/$ID/PENDING-RELEASE" ]; then
  echo "job $ID was already released ($(date -r "$JOBS_DIR/$ID/RELEASED" '+%F %H:%M' 2>/dev/null))."
  echo "Re-sending the same day would replace it: release-reel.sh $ID --replace, or --day for another day."
  exit 1
fi
# A release already in flight owns this job; a second command would race its
# atomic claim. --scan recovers a genuinely crashed one after 5 minutes.
if [ -f "$JOBS_DIR/$ID/.RELEASING" ]; then
  echo "job $ID already has a release in flight (.RELEASING). Wait for it; a crashed one is re-armed by the next --scan."
  exit 1
fi
# An eclip job has no review window to expire, so it never carries a live
# PENDING-RELEASE of its own accord and Marcus's command here IS the approval.
# But only over a QA-PASSED render: `out/DONE` is the one marker that says QA
# ruled on these exact pixels. A finished render with NO verdict is parked
# SALVAGED and keeps the explicit-only path every customer job has, one block
# below — this must not swallow it, and must never arm on the mp4 alone.
if is_eclip "$JOBS_DIR/$ID" && [ ! -f "$JOBS_DIR/$ID/PENDING-RELEASE" ] \
   && [ ! -f "$JOBS_DIR/$ID/RELEASED" ] && [ ! -f "$JOBS_DIR/$ID/SALVAGED" ]; then
  if [ ! -f "$JOBS_DIR/$ID/out/DONE" ]; then
    echo "job $ID has no out/DONE: QA has not passed this cut, so there is nothing to release."
    echo "Still rendering? Wait. Session died mid-render? It is parked SALVAGED and this same command converts it."
    exit 1
  fi
  if [ -z "$DRYRUN" ]; then
    date +%s > "$JOBS_DIR/$ID/PENDING-RELEASE"
    echo "$(date): eclip job $ID armed by explicit command (out/DONE present)" >> "$LOG"
  fi
fi
if [ -f "$JOBS_DIR/$ID/SALVAGED" ]; then
  # Salvaged render (finished but never QA'd — see run-reel-worker.sh). No
  # scan can consume SALVAGED; Marcus's explicit command here IS the approval,
  # so convert it to a normal pending release at this moment.
  if [ -z "$DRYRUN" ]; then
    SALVAGED_NOTE=$(cat "$JOBS_DIR/$ID/SALVAGED" 2>/dev/null)
    [ -n "$SALVAGED_NOTE" ] || SALVAGED_NOTE="unverified: salvaged render, release attempted $(date)"
    date +%s > "$JOBS_DIR/$ID/PENDING-RELEASE"
    rm -f "$JOBS_DIR/$ID/SALVAGED"
    echo "$(date): salvaged job $ID converted to pending release by explicit command" >> "$LOG"
  fi
fi
if [ ! -f "$JOBS_DIR/$ID/PENDING-RELEASE" ] && [ -z "$DRYRUN" ]; then
  echo "job $ID is not pending release (already shipped, failed, or not rendered yet)"; exit 1
fi
[ -z "$DRYRUN" ] && rm -f "$JOBS_DIR/$ID/HOLD"   # explicit release overrides a HOLD
if release_one "$ID"; then
  if [ -n "$DRYRUN" ]; then echo "dry run finished for $ID - nothing was shipped"; else echo "released $ID"; fi
else
  echo "release of $ID FAILED - see $LOG"; exit 1
fi
