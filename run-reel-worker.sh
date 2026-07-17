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
  ID=$(api "$API/queue" | /usr/bin/python3 -c "import json,sys; j=json.load(sys.stdin); print(j['jobs'][0] if j.get('jobs') else '')" 2>/dev/null)
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
    META_ARGS=()
    [ -f "$JOB/out/delivery.json" ] && META_ARGS=(-F "meta=@$JOB/out/delivery.json;type=application/json")
    RES=$(api -X POST -F "reel=@$JOB/out/reel-watermarked.mp4;type=video/mp4" \
                     -F "clean=@$JOB/out/reel-clean.mp4;type=video/mp4" \
                     "${META_ARGS[@]}" \
                     "$API/complete/$ID")
    echo "complete: $RES" >> "$LOG"
    URL="$WORKER_API/reel?job=$ID"
    # Handoff for Marcus: one row per delivery, ready to copy into a text.
    printf '%s | %s | %s | %s\n  SMS> Your reel is ready 🎬 %s\n' \
      "$(date '+%F %H:%M')" "$PHONE" "$EMAIL" "$URL" "$URL" >> "$JOBS_DIR/OUTBOX.md"
    # Email automation (only when a Resend key exists; otherwise manual per OUTBOX)
    if [ -n "$RESEND_KEY" ]; then
      curl -s --max-time 30 -X POST "https://api.resend.com/emails" \
        -H "Authorization: Bearer $RESEND_KEY" -H "Content-Type: application/json" \
        -d "{\"from\":\"Marc <marcus@ibuildapp.ca>\",\"to\":[\"$EMAIL\"],\"subject\":\"Your reel is ready 🎬\",\"text\":\"It's done — cut from your own photos by the IMABGOLD Reels engine.\n\nWatch it here: $URL\n\nLove it? Founding creators get the clean version and 4 reels a month: it's on the same page.\n\n— Marc\"}" >> "$LOG" 2>&1
      echo "" >> "$LOG"
    fi
    osascript -e "display notification \"Reel ready — text $PHONE (see jobs/OUTBOX.md)\" with title \"$NOTIF_TITLE\" sound name \"Glass\"" 2>/dev/null
    DONE_COUNT=$((DONE_COUNT + 1))
  else
    REASON=$(head -c 300 "$JOB/out/FAILED" 2>/dev/null || echo "session produced no output")
    api -X POST -H "Content-Type: application/json" -d "{\"note\":$(printf '%s' "$REASON" | /usr/bin/python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')}" "$API/fail/$ID" >> "$LOG" 2>&1
    echo "" >> "$LOG"
    echo "job FAILED: $REASON" >> "$LOG"
    osascript -e "display notification \"Customer job FAILED - check jobs/$ID\" with title \"$NOTIF_TITLE\" sound name \"Basso\"" 2>/dev/null
    break  # don't chew the queue on a systematic failure; next wake retries nothing (job left failed for Marcus)
  fi
  echo "===== job $ID end $(date) =====" >> "$LOG"
done
exit 0
