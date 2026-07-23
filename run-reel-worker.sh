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
  # release-reel.sh calls complete, so the raw queue re-lists parked jobs.
  # Re-dispatching one boots a premium session for zero work AND resets its
  # review window (re-park overwrites PENDING-RELEASE). Skip anything already
  # rendered; pick the first job that actually needs work.
  QIDS=$(api "$API/queue" | /usr/bin/python3 -c "import json,sys
try:
  [print(i) for i in json.load(sys.stdin).get('jobs',[])]
except Exception: pass" 2>/dev/null)
  ID=""
  for Q in ${(f)QIDS}; do
    if [ -f "$JOBS_DIR/$Q/out/DONE" ] && { [ -f "$JOBS_DIR/$Q/PENDING-RELEASE" ] || [ -f "$JOBS_DIR/$Q/.RELEASING" ] || [ -f "$JOBS_DIR/$Q/RELEASED" ] }; then
      continue  # parked for review; release-reel.sh owns it from here
    fi
    ID="$Q"; break
  done
  [ -z "$ID" ] && break

  echo "===== job $ID start $(date) =====" >> "$LOG"
  api -X POST "$API/claim/$ID" >> "$LOG" 2>&1; echo "" >> "$LOG"

  JOB="$JOBS_DIR/$ID"
  mkdir -p "$JOB/photos" "$JOB/out"
  # Contact info stays OUT of the job folder (the session's cwd) — the session
  # must never see it. Full record goes only to shell vars; the folder gets a
  # scrubbed copy.
  RAW="$JOBS_DIR/.job-$ID.json"
  api "$API/job/$ID" > "$RAW"
  EMAIL=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW'))['email'])" 2>/dev/null)
  PHONE=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW'))['phone'])" 2>/dev/null)
  /usr/bin/python3 -c "
import json
j = json.load(open('$RAW'))
for k in ('email','phone','env'): j.pop(k, None)
json.dump(j, open('$JOB/job.json','w'), indent=2)
[print(k.split('/')[-1]) for k in j['photos']]
" | while read -r F; do
    api -o "$JOB/photos/$F" "$API/photo/$ID/$F"
  done
  rm -f "$RAW"
  N=$(ls "$JOB/photos" | wc -l | tr -d ' ')
  echo "downloaded $N inputs" >> "$LOG"

  # ---- the session: local files only, per JOBS.md. Hard 25-min watchdog —
  # a hung session must not hold the lock and burn opus forever. ----
  ( cd "$JOB" && claude -p "You are running one customer reel job. Read the file '$CORE_DIR/JOBS.md' and execute it exactly, start to finish. Your working directory is this job folder. Today's date: $(date +%F)." \
      --permission-mode acceptEdits \
      --allowedTools "Bash,Read,Write,Edit,Glob,Grep,Task,Agent" \
      --model opus >> "$LOG" 2>&1 ) &
  SPID=$!
  # Watchdog must kill the claude process itself (child of the wrapper
  # subshell), not just the wrapper — else the runaway keeps burning opus.
  ( /bin/sleep 1500; pkill -TERM -P $SPID 2>/dev/null; kill -TERM $SPID 2>/dev/null \
      && echo "$(date): session watchdog fired (25min)" >> "$LOG"; \
    /bin/sleep 10; pkill -KILL -P $SPID 2>/dev/null ) &
  WPID=$!
  wait $SPID
  kill $WPID 2>/dev/null; wait $WPID 2>/dev/null

  if [ -f "$JOB/out/DONE" ] && [ -f "$JOB/out/reel-watermarked.mp4" ] && [ -f "$JOB/out/reel-clean.mp4" ]; then
    # ---- REVIEW GATE: nothing ships from here. The render is parked as
    # PENDING-RELEASE and release-reel.sh is the only path to the customer:
    #   auto-releases after a 20-min window (notify scan, every 2 min)
    #   touch $JOB/HOLD      pauses it indefinitely
    #   touch $JOB/APPROVED  ships on the next scan
    #   release-reel.sh <id> ships immediately
    # Marcus edits out/reel-*.mp4 and out/delivery.json in place; whatever the
    # files say at release time is what the customer gets. ----
    date +%s > "$JOB/PENDING-RELEASE"
    echo "render done: $ID parked for review (auto-release in 20 min)" >> "$LOG"
    osascript -e "display notification \"REVIEW WINDOW: job ${ID:0:8} auto-sends in 20 min — jobs/$ID/out/\" with title \"$NOTIF_TITLE\" sound name \"Glass\"" 2>/dev/null
    curl -s -m 15 -X POST "https://ntfy.sh/imabgold-reels-x7k2mq94" -H "Title: Reel rendered - review window open" -H "Priority: high" -H "Tags: eyes" \
      -d "Job ${ID:0:8} rendered. Auto-sends in 20 min. Review jobs/$ID/out/ - touch HOLD to pause, APPROVED to send now." > /dev/null 2>&1
    DONE_COUNT=$((DONE_COUNT + 1))
  else
    REASON=$(head -c 300 "$JOB/out/FAILED" 2>/dev/null || echo "session produced no output")
    api -X POST -H "Content-Type: application/json" -d "{\"note\":$(printf '%s' "$REASON" | /usr/bin/python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')}" "$API/fail/$ID" >> "$LOG" 2>&1
    echo "" >> "$LOG"
    echo "job FAILED: $REASON" >> "$LOG"
    osascript -e "display notification \"Customer job FAILED - check jobs/$ID\" with title \"$NOTIF_TITLE\" sound name \"Basso\"" 2>/dev/null
    curl -s -m 15 -X POST "https://ntfy.sh/imabgold-reels-x7k2mq94" -H "Title: Reel job FAILED" -H "Priority: high" -H "Tags: rotating_light" \
      -d "Job ${ID:0:8} failed ($(echo "$REASON" | head -1 | head -c 60)). Review it and reach out to the customer." > /dev/null 2>&1
    break  # don't chew the queue on a systematic failure; next wake retries nothing (job left failed for Marcus)
  fi
  echo "===== job $ID end $(date) =====" >> "$LOG"
done
exit 0
