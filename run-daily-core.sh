#!/bin/zsh
# run-daily-core.sh — ALL launcher logic for every IG daily routine.
# Sourced by each account's routine/run-daily.sh wrapper, which must set:
#   ACCOUNT        short name, e.g. "bambi"            (log messages)
#   NOTIF_TITLE    e.g. "bambi daily"                  (macOS notifications)
#   DIR            absolute path of the account folder
#   ROUTINE_FILE   playbook filename in $DIR, e.g. "ROUTINE-REELS.md"
#   ROUTINE_DESC   e.g. "bambi.map daily 9:30am reels routine"
#   ICLOUD_DIR     folder name under iCloud Drive for outbox delivery
# Optional:
#   WAIT_FOR           pgrep -f pattern of another routine to wait for (max 2h)
#   DISALLOWED_TOOLS   zsh array of --disallowedTools entries
#   RESUME_NOTE        account state files a retry must check before each step
#
# Edit THIS file to change structure for ALL accounts. Test via TEST-MODE
# through launchd (see CLAUDE.md). Never edit a copy in an account folder.

export PATH="$HOME/.nvm/versions/node/v20.20.2/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# ---- Wrapper contract: refuse to run with missing parameters (an unset DIR
# would silently cd to $HOME and "run" against nothing) ----
for v in ACCOUNT NOTIF_TITLE DIR ROUTINE_FILE ROUTINE_DESC ICLOUD_DIR; do
  if [[ -z "${(P)v}" ]]; then
    osascript -e "display notification \"run-daily wrapper missing $v - routine did not run\" with title \"IG routine\" sound name \"Basso\"" 2>/dev/null
    exit 1
  fi
done
if [[ ! -d "$DIR" ]]; then
  osascript -e "display notification \"$NOTIF_TITLE: DIR not found - routine did not run\" with title \"$NOTIF_TITLE\" sound name \"Basso\"" 2>/dev/null
  exit 1
fi

cd "$DIR" || exit 1
mkdir -p routine/logs
LOG="routine/logs/$(date +%F).log"

# ---- Photo manifest pre-dump (launcher has FDA; the claude session doesn't) ----
# Videos added since the last run (default 7 days) + derivative previews, so
# the session can scout without touching the Photos library directly.
dump_manifest() {
  local LIB="$HOME/Pictures/Photos Library.photoslibrary"
  local SINCE_EPOCH
  if [ -f routine/last-run.txt ]; then
    SINCE_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(cat routine/last-run.txt | head -1)" +%s 2>/dev/null || date -v-7d +%s)
  else
    SINCE_EPOCH=$(date -v-7d +%s)
  fi
  local SINCE_APPLE=$((SINCE_EPOCH - 978307200))
  sqlite3 -readonly -separator $'\t' \
    "file:$LIB/database/Photos.sqlite?immutable=1" \
    "SELECT ZUUID, ZORIGINALFILENAME, ROUND(ZDURATION,1), datetime(ZDATECREATED+978307200,'unixepoch','localtime') FROM ZASSET LEFT JOIN ZADDITIONALASSETATTRIBUTES ON ZADDITIONALASSETATTRIBUTES.ZASSET = ZASSET.Z_PK WHERE ZKIND=1 AND ZADDEDDATE > $SINCE_APPLE AND ZTRASHEDSTATE=0 ORDER BY ZDATECREATED DESC;" \
    > routine/photos-manifest.tsv 2>> "$LOG"
  mkdir -p routine/previews && rm -f routine/previews/*.jpeg(N) 2>/dev/null
  while IFS=$'\t' read -r uuid rest; do
    [ -z "$uuid" ] && continue
    local first=${uuid:0:1}
    cp "$LIB/resources/derivatives/$first/${uuid}_1_105_c.jpeg" "routine/previews/${uuid}.jpeg" 2>/dev/null \
      || cp "$LIB/resources/derivatives/masters/$first/${uuid}_4_5005_c.jpeg" "routine/previews/${uuid}.jpeg" 2>/dev/null
  done < routine/photos-manifest.tsv
  echo "manifest: $(wc -l < routine/photos-manifest.tsv | tr -d ' ') new videos, $(ls routine/previews 2>/dev/null | wc -l | tr -d ' ') previews" >> "$LOG"
}

# ---- iCloud outbox mover (claude has no iCloud TCC permission; we do) ----
move_outbox() {
  if [ -d routine/icloud-outbox ] && [ -n "$(ls -A routine/icloud-outbox 2>/dev/null)" ]; then
    mkdir -p "$HOME/Library/Mobile Documents/com~apple~CloudDocs/$ICLOUD_DIR"
    local f
    for f in routine/icloud-outbox/*; do
      mv "$f" "$HOME/Library/Mobile Documents/com~apple~CloudDocs/$ICLOUD_DIR/" \
        && echo "icloud-staged: $(basename "$f")" >> "$LOG" \
        || echo "icloud-stage FAILED: $(basename "$f")" >> "$LOG"
    done
  fi
}

# ---- TEST MODE: exercise launchd -> sqlite -> previews -> Photos TCC ->
# outbox -> notification without a real content run, then self-disarm ----
if [ -f routine/TEST-MODE ]; then
  echo "===== TEST MODE run $(date) =====" >> "$LOG"
  rm routine/TEST-MODE
  dump_manifest
  echo "manifest head:" >> "$LOG"
  head -5 routine/photos-manifest.tsv >> "$LOG" 2>&1
  echo "Photos AppleScript (TCC) check:" >> "$LOG"
  osascript -e 'tell application "Photos" to get count of albums' >> "$LOG" 2>&1
  mkdir -p routine/icloud-outbox && echo "outbox test $(date)" > "routine/icloud-outbox/TEST-outbox.txt"
  move_outbox
  rm -f "$HOME/Library/Mobile Documents/com~apple~CloudDocs/$ICLOUD_DIR/TEST-outbox.txt"  # don't pollute the real delivery folder
  osascript -e "display notification \"$NOTIF_TITLE TEST-MODE chain OK - check routine/logs\" with title \"$NOTIF_TITLE\"" >> "$LOG" 2>&1
  echo "===== TEST MODE exit $? at $(date) =====" >> "$LOG"
  exit 0
fi

# ---- Skip if a run already completed today (launchd re-fires after wake) ----
if grep -q "$(date +%F)" routine/last-run.txt 2>/dev/null; then
  echo "$(date): already ran today, skipping" >> "$LOG"
  exit 0
fi

# ---- Never run two routines concurrently (Photos AppleScript + ffmpeg) ----
if [ -n "$WAIT_FOR" ]; then
  for i in {1..120}; do
    pgrep -f "$WAIT_FOR" > /dev/null || break
    [ $i -eq 1 ] && echo "$(date): $WAIT_FOR still running, waiting…" >> "$LOG"
    sleep 60
  done
fi

# ---- Pre-flight: wait for the Anthropic API (up to 2h, 5-min checks).
# The 2026-07-13 outage burned both claude attempts; start late, not dead. ----
for i in {1..24}; do
  curl -s --max-time 10 -o /dev/null https://api.anthropic.com/ && break
  [ $i -eq 1 ] && echo "$(date): Anthropic API unreachable, waiting…" >> "$LOG"
  sleep 300
done

echo "===== $ACCOUNT daily routine start $(date) =====" >> "$LOG"
dump_manifest

# ---- Run the session; retry once on an API drop, resuming from state ----
[ -z "$RESUME_NOTE" ] && RESUME_NOTE="the ledgers, logs, and output files each step writes"
STATUS=1
for ATTEMPT in 1 2; do
  EXTRA=""
  if [ "$ATTEMPT" -gt 1 ]; then
    EXTRA=" NOTE: an earlier attempt today failed partway (API drop). Read today's log in routine/logs/ and check completed state before each step so you never duplicate work: $RESUME_NOTE. Continue from the first incomplete step."
    echo "===== retry attempt $ATTEMPT $(date) =====" >> "$LOG"
    sleep 60
  fi
  CLAUDE_ARGS=(-p "You are running the $ROUTINE_DESC. Read the file '$DIR/$ROUTINE_FILE' and execute it exactly, start to finish. Today's date: $(date +%F).$EXTRA"
    --permission-mode acceptEdits
    --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Task,Agent,Skill,ToolSearch")
  if (( ${#DISALLOWED_TOOLS[@]} )); then
    CLAUDE_ARGS+=(--disallowedTools "${DISALLOWED_TOOLS[@]}")
  fi
  claude "${CLAUDE_ARGS[@]}" >> "$LOG" 2>&1
  STATUS=$?
  [ $STATUS -eq 0 ] && break
done

echo "===== routine exit status $STATUS at $(date) =====" >> "$LOG"

move_outbox

if [ $STATUS -ne 0 ]; then
  osascript -e "display notification \"$NOTIF_TITLE routine FAILED - check routine/logs\" with title \"$NOTIF_TITLE\" sound name \"Basso\"" 2>/dev/null
fi
exit $STATUS
