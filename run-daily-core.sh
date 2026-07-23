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

# This file's own directory — we get sourced from an account folder, so $0 and
# $PWD both point at the ACCOUNT, not here. ${(%):-%x} is the sourced script's
# path in zsh. Needed to call sibling helpers (dump-labels.py).
CORE_DIR="${${(%):-%x}:A:h}"

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
  dump_archive
}

# ---- Archive manifest (the fallback lane when the fresh window is empty) ----
# The session has no FDA, so it cannot go dig through the catalogue itself —
# without this dump, "look further back" is impossible and the run has no
# honest option but to declare exhaustion (or, as on 2026-07-16, improvise).
# So: dump EVERY video in the library, oldest included, with the moment's place
# name — filename + duration + date + place is enough to pick candidates, and
# AppleScript export (authorized) + ffmpeg frame-sampling does the rest.
# TSV only, no previews: 4k+ derivative copies would cost more than it's worth.
# ZSAVEDASSETTYPE<>12 is load-bearing: type-12 assets (59 videos here) are in
# Photos.sqlite but CANNOT be addressed by AppleScript at all -- `media item id`
# throws "Can't get media item id". They're unexportable, so they're uncuttable,
# so listing them only sends the session chasing candidates it can never use.
# Exportable rows are type 6/3/4 (verified 2026-07-16).
# NEVER commit this file (real localities + the whole family catalogue): it is
# gitignored in every account repo. Keep it that way.
dump_archive() {
  local LIB="$HOME/Pictures/Photos Library.photoslibrary"
  sqlite3 -readonly -separator $'\t' \
    "file:$LIB/database/Photos.sqlite?immutable=1" \
    "SELECT a.ZUUID, aa.ZORIGINALFILENAME, ROUND(a.ZDURATION,1), datetime(a.ZDATECREATED+978307200,'unixepoch','localtime'), COALESCE(m.ZTITLE,'') FROM ZASSET a LEFT JOIN ZADDITIONALASSETATTRIBUTES aa ON aa.ZASSET=a.Z_PK LEFT JOIN ZMOMENT m ON a.ZMOMENT=m.Z_PK WHERE a.ZKIND=1 AND a.ZTRASHEDSTATE=0 AND a.ZSAVEDASSETTYPE <> 12 ORDER BY a.ZDATECREATED DESC;" \
    > routine/photos-archive.tsv 2>> "$LOG"
  echo "archive: $(wc -l < routine/photos-archive.tsv | tr -d ' ') videos catalogued (fallback lane)" >> "$LOG"
  # Photos' OWN scene labels ("High Chair", "Restaurant", "Baby", "Meal"...) so
  # the session can search the archive by CONTENT, not by guessing at
  # IMG_9128.MOV. Non-fatal: a missing labels file just costs search quality.
  python3 "$CORE_DIR/dump-labels.py" >> "$LOG" 2>&1 || \
    echo "labels: dump failed (non-fatal; archive search falls back to date/place)" >> "$LOG"
}

# ---- Photos export-lane health probe ----
# Photos has a THIRD state between authorized and TCC-blocked: app-level
# queries (albums, counts) answer but media-item queries hang until the
# AppleEvent timeout (-1712). Seen 2026-07-17 and 2026-07-19, both in the 9am
# run right after wake (post-wake iCloud sync / library churn); the same query
# answered in ~1s mid-afternoon. The 07-19 run burned ~12 min discovering this
# mid-step; this 25s probe turns it into a decision the session reads BEFORE
# planning any export lane. Probes the newest ARCHIVE row (type-12 assets are
# already filtered out there; the manifest is not filtered and a type-12 head
# row would false-report STALLED).
probe_photos_export() {
  local UUID=$(head -1 routine/photos-archive.tsv 2>/dev/null | cut -f1)
  if [ -z "$UUID" ]; then
    echo "UNKNOWN $(date +%H:%M:%S) no catalogued video to probe" > routine/photos-export-health.txt
  elif osascript -e 'on run argv' \
       -e 'with timeout of 25 seconds' \
       -e 'tell application "Photos" to get filename of media item id (item 1 of argv)' \
       -e 'end timeout' -e 'end run' "$UUID/L0/001" > /dev/null 2>&1; then
    echo "OK $(date +%H:%M:%S) media-item queries answering" > routine/photos-export-health.txt
  else
    echo "STALLED $(date +%H:%M:%S) media-item query timed out; do NOT plan an export lane this run - use on-disk footage or the generation lane, and note unexported candidates in the inventory for the next run" > routine/photos-export-health.txt
  fi
  echo "photos-export-health: $(cat routine/photos-export-health.txt)" >> "$LOG"
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
  probe_photos_export
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
probe_photos_export

# ---- Run the session; retry once on an API drop OR an incomplete run,
# resuming from state. Exit code 0 is NOT proof of completion: on 2026-07-18
# a session backgrounded a slow Photos export, ended its turn, and exited 0
# with no reel — so completion is verified by the last-run.txt stamp, which
# ROUTINE-CORE.md step 6 requires on EVERY deliberate end (staging, no-reel
# day, early stops). No today-stamp = the run died partway. ----
run_complete() { grep -q "$(date +%F)" routine/last-run.txt 2>/dev/null; }
[ -z "$RESUME_NOTE" ] && RESUME_NOTE="the ledgers, logs, and output files each step writes"
STATUS=1
for ATTEMPT in 1 2; do
  EXTRA=""
  if [ "$ATTEMPT" -gt 1 ]; then
    EXTRA=" NOTE: an earlier attempt today ended partway (API drop, or the session ended its turn with work still pending — background tasks die when the turn ends). Read today's log in routine/logs/ and check completed state before each step so you never duplicate work: $RESUME_NOTE. Continue from the first incomplete step, and this time keep every long task in the foreground until it finishes."
    echo "===== retry attempt $ATTEMPT $(date) =====" >> "$LOG"
    sleep 60
  fi
  CLAUDE_ARGS=(-p "You are running the $ROUTINE_DESC. Read the file '$DIR/$ROUTINE_FILE' and execute it exactly, start to finish. Today's date: $(date +%F).$EXTRA"
    # Pin plain Opus, NOT the account default. The default is opus[1m] (1M-context
    # beta) which bills a long-context premium the reel routine never needs — it
    # hit the monthly spend cap mid-run on 2026-07-20. Reel judgment stays on Opus;
    # we just drop the 1M window. Applies to every account routing through this core.
    --model opus
    --permission-mode acceptEdits
    --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Task,Agent,Skill,ToolSearch")
  if (( ${#DISALLOWED_TOOLS[@]} )); then
    CLAUDE_ARGS+=(--disallowedTools "${DISALLOWED_TOOLS[@]}")
  fi
  claude "${CLAUDE_ARGS[@]}" >> "$LOG" 2>&1
  STATUS=$?
  if [ $STATUS -eq 0 ] && ! run_complete; then
    echo "$(date): exit 0 but last-run.txt not stamped today — run died partway, treating as failed" >> "$LOG"
    STATUS=1
  fi
  [ $STATUS -eq 0 ] && break
done

echo "===== routine exit status $STATUS at $(date) =====" >> "$LOG"

move_outbox

if [ $STATUS -ne 0 ]; then
  osascript -e "display notification \"$NOTIF_TITLE routine FAILED - check routine/logs\" with title \"$NOTIF_TITLE\" sound name \"Basso\"" 2>/dev/null
fi
exit $STATUS
