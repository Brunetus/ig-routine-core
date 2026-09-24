#!/bin/zsh
# run-reel-worker.sh — launcher for reels.ibuildapp.ca customer jobs.
# LaunchAgent: com.marcus.reel-worker (StartInterval 600). Session law: JOBS.md.
# The launcher does ALL network I/O (queue/claim/photos/upload via the
# authenticated /api/worker surface — the only R2 credential is the Pages
# binding); the claude session only turns local photos into local reels.
# Job data lives in ~/Claude Code/reel-app/jobs/<id>/ (ephemeral accounts).
# Test: touch "$JOBS_DIR/TEST-MODE" && launchctl kickstart gui/501/com.marcus.reel-worker

export PATH="$HOME/.nvm/versions/node/v20.20.2/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

CORE_DIR="${0:A:h}"
source "${0:A:h}/contact-card.sh"
APP_DIR="$HOME/Claude Code/reel-app"
JOBS_DIR="$APP_DIR/jobs"
NOTIF_TITLE="reel worker"
MAX_JOBS_PER_WAKE=2

mkdir -p "$JOBS_DIR"
LOG="$JOBS_DIR/worker-$(date +%F).log"

# ---- Config: WORKER_SECRET + WORKER_API from reel-app/.env ----
WORKER_SECRET=$(grep "^WORKER_SECRET=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
WORKER_API=$(grep "^WORKER_API=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
RESEND_KEY=$(grep "^RESEND_API_KEY=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
if [[ -z "$WORKER_SECRET" || -z "$WORKER_API" ]]; then
  echo "$(date): WORKER_SECRET/WORKER_API missing in reel-app/.env - not running" >> "$LOG"
  exit 1
fi
API="$WORKER_API/api/worker"
AUTH="Authorization: Bearer $WORKER_SECRET"

api() { curl -s --max-time 120 -H "$AUTH" "$@"; }

# Kill a process and ALL its descendants. ffmpeg/whisper are grandchildren of
# the claude session; `pkill -P` alone leaves them alive and writing into out/
# after the watchdog fires — which could hand the salvage check a file that is
# still mid-encode.
kill_tree() {
  local sig="$1" pid="$2" c
  { [ -n "$pid" ] && [ "$pid" -gt 1 ]; } 2>/dev/null || return
  for c in $(pgrep -P "$pid" 2>/dev/null); do kill_tree "$sig" "$c"; done
  kill "-$sig" "$pid" 2>/dev/null
}

# ---- TEST MODE: launchd -> config -> API auth -> ffmpeg -> claude -> notification ----
if [ -f "$JOBS_DIR/TEST-MODE" ]; then
  echo "===== TEST MODE run $(date) =====" >> "$LOG"
  rm "$JOBS_DIR/TEST-MODE"
  echo "queue probe: $(api "$API/queue" | head -c 200)" >> "$LOG"
  FFBIN=$(ls "$HOME/Library/Python/3.9/lib/python/site-packages/imageio_ffmpeg/binaries/"ffmpeg-* 2>/dev/null | head -1)
  echo "ffmpeg: ${FFBIN:-MISSING}" >> "$LOG"
  echo "claude: $(command -v claude || echo MISSING)" >> "$LOG"
  osascript -e "display notification \"$NOTIF_TITLE TEST-MODE chain OK - check jobs/worker log\" with title \"$NOTIF_TITLE\"" >> "$LOG" 2>&1
  echo "===== TEST MODE exit $? at $(date) =====" >> "$LOG"
  exit 0
fi

# ---- Release-gate backstop: ship any pending job whose review window
# expired, even during the routine quiet window (it's light network I/O,
# no claude/ffmpeg). Primary scan lives in run-reel-notify.sh (every 2 min);
# this catches the case where the notify agent is down. Atomic claim in
# release-reel.sh makes the overlap safe. ----
/bin/zsh "$CORE_DIR/release-reel.sh" --scan 2>> "$LOG"

# ---- Never contend with the daily routines (08:30-10:30 is theirs), and
# never run alongside a daily/scan/second worker instance ----
HM=$(date +%H%M)
if [ "$HM" -ge 0830 ] && [ "$HM" -le 1030 ]; then
  exit 0  # silent: this fires every 10 min, logging it would be noise
fi
if pgrep -f "run-daily-core.sh|run-viral-scan.sh" > /dev/null; then
  echo "$(date): daily/scan running, yielding" >> "$LOG"
  exit 0
fi
LOCK="$JOBS_DIR/.worker-lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  # stale-lock: reclaim ONLY if the holding process is dead (PID check) —
  # a time-only reclaim could run alongside a still-alive hung instance.
  HOLDER=$(cat "$LOCK/pid" 2>/dev/null)
  if [ -n "$HOLDER" ] && kill -0 "$HOLDER" 2>/dev/null; then
    exit 0  # holder is alive
  fi
  if [ -z "$HOLDER" ] && [ -z "$(find "$LOCK" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then
    exit 0  # empty pid on a FRESH lock = another instance mid-acquire, not stale
  fi
  rm -rf "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null || exit 0
  echo "$(date): reclaimed stale lock (holder ${HOLDER:-unknown} dead)" >> "$LOG"
fi
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK" 2>/dev/null' EXIT

DONE_COUNT=0
while [ "$DONE_COUNT" -lt "$MAX_JOBS_PER_WAKE" ]; do
  # Review-gate guard: a rendered job stays in the server queue until
  # release-reel.sh calls complete, so the raw queue re-lists parked jobs
  # (QA'd pending-release, salvaged, or held). Re-dispatching one boots a
  # premium session for zero work and resets its review state. Skip them;
  # pick the first job that actually needs work.
  QIDS=$(api "$API/queue" | /usr/bin/python3 -c "import json,sys
try:
  [print(i) for i in json.load(sys.stdin).get('jobs',[])]
except Exception: pass" 2>/dev/null)
  ID=""
  for Q in ${(f)QIDS}; do
    # Any park marker means a render already exists for this job (QA'd or
    # salvaged) — re-dispatching would boot a premium session for zero work
    # and reset the review state. release-reel.sh owns it from here.
    if [ -f "$JOBS_DIR/$Q/PENDING-RELEASE" ] || [ -f "$JOBS_DIR/$Q/.RELEASING" ] || [ -f "$JOBS_DIR/$Q/RELEASED" ] || [ -f "$JOBS_DIR/$Q/SALVAGED" ] || [ -f "$JOBS_DIR/$Q/REJECTED" ]; then
      continue
    fi
    # HOLD normally means the same thing, and it keeps that meaning here.
    # The ONE exception is an eclip job between enqueue and its first render:
    # nothing eclip auto-ships, so clips-watch.mjs holds it from the moment it
    # is queued, and that HOLD is not a park. `ECLIP-QUEUED` is what says so —
    # a marker file, not a substring of HOLD, so nobody's wording can turn a
    # real park into a dispatch. It is removed on claim, just below.
    if [ -f "$JOBS_DIR/$Q/HOLD" ]; then
      if [ ! -f "$JOBS_DIR/$Q/ECLIP-QUEUED" ] \
         || [ -f "$JOBS_DIR/$Q/out/RENDERED" ] || [ -f "$JOBS_DIR/$Q/out/DONE" ]; then
        continue
      fi
    fi
    ID="$Q"; break
  done
  [ -z "$ID" ] && break

  echo "===== job $ID start $(date) =====" >> "$LOG"
  api -X POST "$API/claim/$ID" >> "$LOG" 2>&1; echo "" >> "$LOG"
  # The dispatch exception is spent the moment we claim: from here the job's
  # HOLD means exactly what a HOLD means on every other job.
  rm -f "$JOBS_DIR/$ID/ECLIP-QUEUED"
  # .session-live (our pid inside): from the claim until the park/fail below is
  # written, nobody may revise or restore this folder (review.mjs refuses
  # while it exists and the pid is alive). Closes the window where a revise
  # could disarm a PENDING-RELEASE about to be written, have its fresh queue
  # marker deleted by the fail POST, or land while the old marcus_note is
  # being downloaded (audit 2026-09-13).
  echo $$ > "$JOBS_DIR/$ID/.session-live"

  JOB="$JOBS_DIR/$ID"
  mkdir -p "$JOB/photos" "$JOB/out"
  # Contact info stays OUT of the job folder (the session's cwd) — the session
  # must never see it. Full record goes only to shell vars; the folder gets a
  # scrubbed copy.
  RAW="$JOBS_DIR/.job-$ID.json"
  api "$API/job/$ID" > "$RAW"
  EMAIL=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW'))['email'])" 2>/dev/null)
  PHONE=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW'))['phone'])" 2>/dev/null)
  PAIDJOB=$(/usr/bin/python3 -c "import json;print('1' if json.load(open('$RAW')).get('paid') else '')" 2>/dev/null)
  STORY=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW')).get('story') or '')" 2>/dev/null)
  HANDLE=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW')).get('handle') or '')" 2>/dev/null)
  CLIENT=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW')).get('client') or '')" 2>/dev/null)
  CREATED=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW')).get('created') or '')" 2>/dev/null)
  MNOTE=$(/usr/bin/python3 -c "import json;print((json.load(open('$RAW')).get('marcus_note') or '').replace(chr(10),' '))" 2>/dev/null)
  /usr/bin/python3 -c "
import json
j = json.load(open('$RAW'))
for k in ('email','phone','env'): j.pop(k, None)
json.dump(j, open('$JOB/job.json','w'), indent=2)
[print(k.split('/')[-1]) for k in j['photos']]
" | while read -r F; do
    # drive-watch paid jobs pre-stage clips locally and never upload them to
    # R2 — fetching would overwrite the real clip with a "not found" body.
    # PAID ONLY: on a free job a leftover local file could be a truncated
    # download from a killed run, and the re-fetch is the fix, not the bug.
    [ -n "$PAIDJOB" ] && [ -s "$JOB/photos/$F" ] && continue
    api -o "$JOB/photos/$F" "$API/photo/$ID/$F"
  done
  rm -f "$RAW"
  N=$(ls "$JOB/photos" | wc -l | tr -d ' ')
  echo "downloaded $N inputs" >> "$LOG"

  # ---- the session: local files only, per JOBS.md. The ONLY kill switch is
  # the 90-min hard ceiling — the budget fuse so a live-but-looping session
  # can't eat the monthly Claude limit (2026-07-21 spend incident; the
  # ceiling STAYS no matter what else changes here). The stall watchdog was
  # REMOVED 2026-08-26 (Marcus's call): file-mtime proof-of-life killed
  # healthy jobs three times — b4f8085c and 075b7ccb mid-QA on 08-19 at 25/35
  # min, then 0d8e7c1f on 08-26 during a 30+ min read-only viral-bank catalog
  # walk it could not see. Cost of removal: a truly hung session now fails at
  # 90 min instead of 25, blocking that wake's slot until then. ----
  # A re-dispatched folder (re-queued FAILED job, lost fail POST) must never
  # satisfy the salvage/success checks on a PREVIOUS run's artifacts.
  rm -f "$JOB/out/DONE" "$JOB/out/RENDERED" "$JOB/out/FAILED"
  # The contact card (written after the session exits, below) must never be
  # present while the session runs — its cwd is this folder and the whole
  # point of the scrub above is that it never sees contact info.
  rm -f "$JOB"/CONTACT-*.txt(N)
  ( cd "$JOB" && claude -p "You are running one customer reel job. Read the file '$CORE_DIR/JOBS.md' and execute it exactly, start to finish. Your working directory is this job folder. Today's date: $(date +%F)." \
      --permission-mode acceptEdits \
      --allowedTools "Bash,Read,Write,Edit,Glob,Grep,Task,Agent" \
      --model opus >> "$LOG" 2>&1 ) &
  SPID=$!
  # The ceiling kill must take the whole tree (claude AND its ffmpeg/whisper
  # grandchildren), not just the wrapper — else the runaway keeps burning opus
  # or keeps writing into out/ after the kill.
  ( CEILING_SECS=5400; WSTART=$(date +%s)
    while kill -0 $SPID 2>/dev/null; do
      /bin/sleep 60
      kill -0 $SPID 2>/dev/null || break
      WNOW=$(date +%s)
      if [ $((WNOW - WSTART)) -ge $CEILING_SECS ]; then
        echo "$(date): session watchdog: HARD CEILING ${CEILING_SECS}s - killing (budget fuse)" >> "$LOG"
        kill_tree TERM $SPID; /bin/sleep 10; kill_tree KILL $SPID; break
      fi
    done ) &
  WPID=$!
  wait $SPID
  kill $WPID 2>/dev/null; wait $WPID 2>/dev/null

  # ---- Contact card: written ONLY now, after the session has exited, so
  # Marcus can open any job folder and see whose it is at a glance. The folder
  # itself stays uuid-named on purpose — see contact-card.sh for why. ----
  write_contact_card "$JOB" "$ID" "$EMAIL" "$PHONE" "$HANDLE" "$CLIENT" "$CREATED" "$STORY" "$WORKER_API/reel?job=$ID" "$MNOTE" \
    || echo "$(date): contact card write FAILED for $ID" >> "$LOG"

  # One deliverable on every tier since 2026-08-26: the clean cut.
  WMREQ="$JOB/out/reel-clean.mp4"
  if [ -f "$JOB/out/DONE" ] && [ -f "$WMREQ" ] && [ -f "$JOB/out/reel-clean.mp4" ]; then
    # ---- REVIEW GATE: nothing ships from here. The render is parked as
    # PENDING-RELEASE and release-reel.sh is the only path to the customer:
    #   auto-releases after a 20-min window (notify scan, every 2 min)
    #   touch $JOB/HOLD      pauses it indefinitely
    #   touch $JOB/APPROVED  ships on the next scan
    #   release-reel.sh <id> ships immediately
    # Marcus edits out/reel-*.mp4 and out/delivery.json in place; whatever the
    # files say at release time is what the customer gets. ----
    date +%s > "$JOB/PENDING-RELEASE"
    # An eclip job has no review window: it is held, and only Marcus ships it.
    # Saying "auto-sends in 20 min" to him would be a lie he might act on.
    if grep -q '"eclip"' "$JOB/job.json" 2>/dev/null; then
      ECLIP_WHO=$(/usr/bin/python3 -c "import json;print((json.load(open('$JOB/job.json')).get('eclip') or {}).get('username') or '?')" 2>/dev/null)
      echo "render done: $ID parked for review (eclip @$ECLIP_WHO, HELD, no auto-release)" >> "$LOG"
      osascript -e "display notification \"eclip cut ready for @$ECLIP_WHO — nothing sends until you approve\" with title \"$NOTIF_TITLE\" sound name \"Glass\"" 2>/dev/null
      curl -s -m 15 -X POST "https://ntfy.sh/imabgold-reels-x7k2mq94" -H "Title: eclip cut ready for review" -H "Priority: high" -H "Tags: eyes" \
        -d "eclip cut for @$ECLIP_WHO is rendered and HELD. Nothing auto-sends. Watch jobs/$ID/out/reel-clean.mp4, then release-reel.sh $ID to deliver it, or review.mjs reject $ID \"why\"." > /dev/null 2>&1
    else
    echo "render done: $ID parked for review (auto-release in 20 min)" >> "$LOG"
    osascript -e "display notification \"REVIEW WINDOW: job ${ID:0:8} auto-sends in 20 min — jobs/$ID/out/\" with title \"$NOTIF_TITLE\" sound name \"Glass\"" 2>/dev/null
    curl -s -m 15 -X POST "https://ntfy.sh/imabgold-reels-x7k2mq94" -H "Title: Reel rendered - review window open" -H "Priority: high" -H "Tags: eyes" \
      -d "Job ${ID:0:8} rendered. Auto-sends in 20 min. Review jobs/$ID/out/ - touch HOLD to pause, APPROVED to send now." > /dev/null 2>&1
    fi
    DONE_COUNT=$((DONE_COUNT + 1))
  elif [ -f "$JOB/out/RENDERED" ] && [ ! -f "$JOB/out/FAILED" ] && [ -f "$WMREQ" ] && [ -f "$JOB/out/reel-clean.mp4" ]; then
    # ---- SALVAGE: the render finished but the session died before QA wrote
    # out/DONE (watchdog, crash). A finished render must not be failed over a
    # missing receipt. An explicit out/FAILED (e.g. two QA FAILs) is NOT a
    # salvage — that verdict wins and takes the fail branch below.
    # Park with SALVAGED + HOLD, never PENDING-RELEASE: no scan consumes
    # SALVAGED, so the job cannot auto-send even if the HOLD is deleted or a
    # crash lands between the two writes. The server job stays as-is (customer
    # keeps the normal "cutting it" page, NOT the snag page). Marcus reviews
    # and ships with `release-reel.sh <id>`, which converts SALVAGED to a
    # pending release at that moment. Either marker stops re-dispatch. ----
    echo "salvaged $(date +%s)" > "$JOB/SALVAGED"
    echo "unverified render: session died before QA ($(date))" > "$JOB/HOLD"
    echo "render SALVAGED: $ID parked - finished render, no QA verdict" >> "$LOG"
    osascript -e "display notification \"UNVERIFIED render: job ${ID:0:8} parked - review then release-reel.sh\" with title \"$NOTIF_TITLE\" sound name \"Basso\"" 2>/dev/null
    curl -s -m 15 -X POST "https://ntfy.sh/imabgold-reels-x7k2mq94" -H "Title: Reel rendered but UNVERIFIED" -H "Priority: high" -H "Tags: eyes,warning" \
      -d "Job ${ID:0:8} finished rendering but the session died before QA. It will NOT auto-send under any path. Review jobs/$ID/out/ then run release-reel.sh $ID to ship." > /dev/null 2>&1
    rm -f "$JOB/.session-live"
    break  # a watchdog kill may be systemic (hung model, full disk) — don't burn another long session this wake
  else
    REASON=$(head -c 300 "$JOB/out/FAILED" 2>/dev/null || echo "session produced no output")
    api -X POST -H "Content-Type: application/json" -d "{\"note\":$(printf '%s' "$REASON" | /usr/bin/python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')}" "$API/fail/$ID" >> "$LOG" 2>&1
    echo "" >> "$LOG"
    echo "job FAILED: $REASON" >> "$LOG"
    osascript -e "display notification \"Customer job FAILED - check jobs/$ID\" with title \"$NOTIF_TITLE\" sound name \"Basso\"" 2>/dev/null
    curl -s -m 15 -X POST "https://ntfy.sh/imabgold-reels-x7k2mq94" -H "Title: Reel job FAILED" -H "Priority: high" -H "Tags: rotating_light" \
      -d "Job ${ID:0:8} failed ($(echo "$REASON" | head -1 | head -c 60)). Review it and reach out to the customer." > /dev/null 2>&1
    rm -f "$JOB/.session-live"
    break  # don't chew the queue on a systematic failure; next wake retries nothing (job left failed for Marcus)
  fi
  rm -f "$JOB/.session-live"
  echo "===== job $ID end $(date) =====" >> "$LOG"
done
exit 0
