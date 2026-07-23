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
#   Marcus pauses   -> touch $JOB/HOLD          (blocks auto-release)
#   Marcus approves -> touch $JOB/APPROVED      (ships on next 2-min scan)
#                      or runs this script with the id (ships immediately)
# Atomic claim: PENDING-RELEASE is mv'd to .RELEASING before any network I/O,
# so notify-scan and worker-backstop can never double-ship the same job.

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

release_one() {
  local ID="$1" JOB="$JOBS_DIR/$1"
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

  if [ ! -f "$JOB/out/reel-watermarked.mp4" ] || [ ! -f "$JOB/out/reel-clean.mp4" ]; then
    echo "$(date): release $ID ABORTED - output files missing" >> "$LOG"
    mv "$JOB/.RELEASING" "$JOB/PENDING-RELEASE" 2>/dev/null
    return 1
  fi

  # Contact stays out of the job folder; fetch it at send time.
  local RAW="$JOBS_DIR/.release-$ID.json"
  api "$API/job/$ID" > "$RAW"
  local EMAIL PHONE
  EMAIL=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW')).get('email',''))" 2>/dev/null)
  PHONE=$(/usr/bin/python3 -c "import json;print(json.load(open('$RAW')).get('phone',''))" 2>/dev/null)
  rm -f "$RAW"

  local META_ARGS=()
  [ -f "$JOB/out/delivery.json" ] && META_ARGS=(-F "meta=@$JOB/out/delivery.json;type=application/json")
  [ -f "$JOB/out/reel-preview.mp4" ] && META_ARGS+=(-F "preview=@$JOB/out/reel-preview.mp4;type=video/mp4")
  local RES
  RES=$(api -X POST -F "reel=@$JOB/out/reel-watermarked.mp4;type=video/mp4" \
                   -F "clean=@$JOB/out/reel-clean.mp4;type=video/mp4" \
                   "${META_ARGS[@]}" \
                   "$API/complete/$ID")
  echo "release $ID complete: $RES" >> "$LOG"
  if ! printf '%s' "$RES" | grep -q '"ok":true'; then
    # Failed upload: put the job back in pending so the next scan retries.
    mv "$JOB/.RELEASING" "$JOB/PENDING-RELEASE" 2>/dev/null
    curl -s -m 15 -X POST "$NTFY" -H "Title: Reel release FAILED" -H "Priority: high" -H "Tags: rotating_light" \
      -d "Release of job ${ID:0:8} failed at the complete call. It stays pending; check jobs/worker log." > /dev/null 2>&1
    return 1
  fi
  date +%s > "$JOB/RELEASED"
  rm -f "$JOB/.RELEASING"

  local URL="$WORKER_API/reel?job=$ID"
  printf '%s | %s | %s | %s\n  SMS> Your reel is ready 🎬 %s\n' \
    "$(date '+%F %H:%M')" "$PHONE" "$EMAIL" "$URL" "$URL" >> "$JOBS_DIR/OUTBOX.md"
  if [ -n "$RESEND_KEY" ] && [ -n "$EMAIL" ]; then
    curl -s --max-time 30 -X POST "https://api.resend.com/emails" \
      -H "Authorization: Bearer $RESEND_KEY" -H "Content-Type: application/json" \
      -d "{\"from\":\"Marc <marcus@ibuildapp.ca>\",\"to\":[\"$EMAIL\"],\"subject\":\"Your reel is ready 🎬\",\"text\":\"It's done. Cut from your own videos by the IMABGOLD Reels engine.\n\nWatch it here: $URL\n\nThe page also has your caption and the audio to use when you post. Love it? Founding creators get the clean version and up to 100 reels a month, it's on the same page.\n\n- Marc\"}" >> "$LOG" 2>&1
    echo "" >> "$LOG"
  fi
  osascript -e "display notification \"Reel RELEASED — text $PHONE (see jobs/OUTBOX.md)\" with title \"reel worker\" sound name \"Glass\"" 2>/dev/null
  curl -s -m 15 -X POST "$NTFY" -H "Title: Reel released" -H "Tags: white_check_mark" \
    -d "Reel for $PHONE is live and emailed. The text to send them is in jobs/OUTBOX.md." > /dev/null 2>&1
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
    echo "$(date): recovered orphaned release claim for $ID (re-armed)" >> "$LOG"
    curl -s -m 15 -X POST "$NTFY" -H "Title: Reel release recovered" -H "Tags: warning" \
      -d "Job ${ID:0:8} had an interrupted release (crash or reboot). Re-armed for auto-release." > /dev/null 2>&1
  done
  for P in "$JOBS_DIR"/*/PENDING-RELEASE(N); do
    JOB_DIR="${P:h}"; ID="${JOB_DIR:t}"
    [ -f "$JOB_DIR/HOLD" ] && continue
    if [ -f "$JOB_DIR/APPROVED" ]; then release_one "$ID"; continue; fi
    TS=$(cat "$P" 2>/dev/null)
    [ -n "$TS" ] && [ $((NOW - TS)) -ge $WINDOW_SECS ] && release_one "$ID"
  done
  exit 0
fi

ID="$1"
if [ -z "$ID" ] || [ ! -d "$JOBS_DIR/$ID" ]; then
  echo "usage: release-reel.sh <job-id> | --scan"; exit 1
fi
if [ ! -f "$JOBS_DIR/$ID/PENDING-RELEASE" ]; then
  echo "job $ID is not pending release (already shipped, failed, or not rendered yet)"; exit 1
fi
rm -f "$JOBS_DIR/$ID/HOLD"   # explicit release overrides a HOLD
release_one "$ID" && echo "released $ID" || echo "release of $ID FAILED - see $LOG"
