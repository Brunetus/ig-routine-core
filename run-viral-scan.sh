#!/bin/zsh
# run-viral-scan.sh — launcher for the twice-weekly viral clip bank scan.
# LaunchAgent: com.marcus.viral-scan (Mon + Thu 8:00 AM). The scan's law is
# BANK.md in this repo; the bank data lives in ~/Claude Code/viral-bank/.
# This launcher is deliberately NOT an account wrapper (no Photos, no iCloud
# outbox, no ROUTINE file) — do not source run-daily-core.sh here.
# Test: touch "$BANK/TEST-MODE" && launchctl kickstart gui/501/com.marcus.viral-scan

export PATH="$HOME/.nvm/versions/node/v20.20.2/bin:$HOME/.local/bin:$HOME/Library/Python/3.9/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

CORE_DIR="${0:A:h}"
BANK="$HOME/Claude Code/viral-bank"
TOKEN_ENV="$HOME/Claude Code/reel-app/.env"
NOTIF_TITLE="viral scan"

cd "$BANK" || {
  osascript -e "display notification \"viral-bank folder missing - scan did not run\" with title \"$NOTIF_TITLE\" sound name \"Basso\"" 2>/dev/null
  exit 1
}
mkdir -p logs clips
LOG="logs/$(date +%F).log"

# ---- TEST MODE: exercise launchd -> token -> Graph API -> yt-dlp -> ffmpeg
# -> notification without a real scan, then self-disarm ----
if [ -f TEST-MODE ]; then
  echo "===== TEST MODE run $(date) =====" >> "$LOG"
  rm TEST-MODE
  if grep -q "^META_SYSTEM_USER_TOKEN=." "$TOKEN_ENV"; then
    echo "token line: present" >> "$LOG"
    TOK=$(grep "^META_SYSTEM_USER_TOKEN=" "$TOKEN_ENV" | cut -d= -f2-)
    HANDLE=$(grep -m1 "^@" watchlist.md | awk '{print $1}' | tr -d '@')
    echo "business_discovery probe (@$HANDLE):" >> "$LOG"
    curl -sg --max-time 20 "https://graph.facebook.com/v21.0/17841480076308621?fields=business_discovery.username($HANDLE){followers_count}&access_token=$TOK" \
      | sed 's/access_token=[^&"]*//' >> "$LOG" 2>&1
    echo "" >> "$LOG"
  else
    echo "token line: MISSING in $TOKEN_ENV" >> "$LOG"
  fi
  FFBIN=$(ls "$HOME/Library/Python/3.9/lib/python/site-packages/imageio_ffmpeg/binaries/"ffmpeg-* 2>/dev/null | head -1)
  echo "ffmpeg: ${FFBIN:-MISSING}" >> "$LOG"
  osascript -e "display notification \"$NOTIF_TITLE TEST-MODE chain OK - check viral-bank/logs\" with title \"$NOTIF_TITLE\"" >> "$LOG" 2>&1
  echo "===== TEST MODE exit $? at $(date) =====" >> "$LOG"
  exit 0
fi

# ---- Skip if a scan already completed today (launchd re-fires after wake) ----
if grep -q "$(date +%F)" last-scan.txt 2>/dev/null; then
  echo "$(date): already scanned today, skipping" >> "$LOG"
  exit 0
fi

# ---- Pre-flight: wait for the Anthropic API (up to 40 min, 5-min checks;
# shorter than the dailies' 2h — a late scan must not collide with them,
# and a missed scan just means Thursday's/Monday's bank) ----
for i in {1..8}; do
  curl -s --max-time 10 -o /dev/null https://api.anthropic.com/ && break
  [ $i -eq 1 ] && echo "$(date): Anthropic API unreachable, waiting…" >> "$LOG"
  sleep 300
done

echo "===== viral scan start $(date) =====" >> "$LOG"

# ---- Run the session; retry once on an API drop ----
STATUS=1
for ATTEMPT in 1 2; do
  EXTRA=""
  if [ "$ATTEMPT" -gt 1 ]; then
    EXTRA=" NOTE: an earlier attempt today failed partway (API drop). Read today's log in logs/ and check catalog.md + clips/ before each step so you never duplicate a download or a catalog entry. Continue from the first incomplete step."
    echo "===== retry attempt $ATTEMPT $(date) =====" >> "$LOG"
    sleep 60
  fi
  claude -p "You are running the twice-weekly viral clip bank scan. Read the file '$CORE_DIR/BANK.md' and execute it exactly, start to finish. The bank directory (your cwd) is '$BANK'. Today's date: $(date +%F).$EXTRA" \
    --permission-mode acceptEdits \
    --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch" \
    --model opus >> "$LOG" 2>&1
  STATUS=$?
  [ $STATUS -eq 0 ] && break
done

echo "===== scan exit status $STATUS at $(date) =====" >> "$LOG"

if [ $STATUS -eq 0 ]; then
  SUMMARY=$(head -1 last-scan.txt 2>/dev/null)
  osascript -e "display notification \"${SUMMARY:-scan finished (no summary written)}\" with title \"$NOTIF_TITLE\"" 2>/dev/null
else
  osascript -e "display notification \"$NOTIF_TITLE FAILED - check viral-bank/logs\" with title \"$NOTIF_TITLE\" sound name \"Basso\"" 2>/dev/null
fi
exit $STATUS
