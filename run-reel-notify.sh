#!/bin/zsh
# run-reel-notify.sh — fast "someone submitted a reel" alert for Marcus,
# plus the review-gate auto-release scan.
# LaunchAgent: com.marcus.reel-notify (StartInterval 120). Complements the
# instant email/ntfy push sent by /api/render-request: this one is the
# Mac-native banner, and it kickstarts the worker so the customer's reel
# starts cutting within ~2 min instead of waiting out the 10-min poll.
# Read-only against the QUEUE (never claims render jobs); the release scan
# ships rendered jobs whose 20-min review window expired via release-reel.sh.

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

CORE_DIR="${0:A:h}"
APP_DIR="$HOME/Claude Code/reel-app"
JOBS_DIR="$APP_DIR/jobs"
SEEN="$JOBS_DIR/.notify-seen"
touch "$SEEN"

# ---- Review-gate scan first (every 2 min): auto-release expired windows,
# ship APPROVED jobs, skip HOLDs. Runs before the queue-empty early exit. ----
/bin/zsh "$CORE_DIR/release-reel.sh" --scan 2>/dev/null

WORKER_SECRET=$(grep "^WORKER_SECRET=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
WORKER_API=$(grep "^WORKER_API=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
[[ -z "$WORKER_SECRET" || -z "$WORKER_API" ]] && exit 0
API="$WORKER_API/api/worker"
AUTH="Authorization: Bearer $WORKER_SECRET"

IDS=$(curl -s -m 20 -H "$AUTH" "$API/queue" | /usr/bin/python3 -c "import json,sys
try: [print(i) for i in json.load(sys.stdin).get('jobs',[])]
except Exception: pass")
[ -z "$IDS" ] && exit 0

NTFY="https://ntfy.sh/imabgold-reels-x7k2mq94"

NEW=0
echo "$IDS" | while read -r ID; do
  grep -q "^$ID$" "$SEEN" && continue
  echo "$ID" >> "$SEEN"
  PHONE=$(curl -s -m 20 -H "$AUTH" "$API/job/$ID" | /usr/bin/python3 -c "import json,sys
try: print(json.load(sys.stdin).get('phone',''))
except Exception: print('')")
  osascript -e "display notification \"Text them now: ${PHONE:-see email} — reel is queued (${ID:0:8})\" with title \"🎬 New reel submitted\" sound name \"Glass\"" 2>/dev/null
  # iPhone push. ntfy.sh drops publishes from Cloudflare's shared egress IPs,
  # so the phone push goes out from here instead of the Pages function.
  curl -s -m 15 -X POST "$NTFY" -H "Title: New reel submitted" -H "Priority: high" -H "Tags: clapper" \
    -d "Job ${ID:0:8} is queued. Contact info is in your email, text them now." > /dev/null 2>&1
done

# Wake the worker right away (it has its own lock + quiet-window guards, so
# an extra kickstart is always safe).
if [ "$(echo "$IDS" | head -1)" != "" ]; then
  launchctl kickstart gui/501/com.marcus.reel-worker 2>/dev/null
fi
exit 0
