#!/bin/zsh
# backfill-contact-cards.sh — drop a CONTACT-<email>.txt card into every
# historical job folder in ~/Claude Code/reel-app/jobs/, so Marcus can open any
# folder and immediately see whose it is. Going forward run-reel-worker.sh
# writes the card itself after each render; this is the one-time catch-up for
# the folders that already exist.
#
# Contact data comes from the worker API (GET /api/worker/job/<id> reads
# jobs/<id>/job.json straight out of R2, no queue dependency), falling back to
# the local scrubbed job.json when R2 no longer has the record.
#
# Usage:  zsh backfill-contact-cards.sh [--go]
#         no flag = DRY RUN, prints what it would write and touches nothing.

set -u
APP_DIR="$HOME/Claude Code/reel-app"
JOBS_DIR="$APP_DIR/jobs"
source "${0:A:h}/contact-card.sh"

GO=""
[[ "${1:-}" == "--go" ]] && GO=1

WORKER_SECRET=$(grep "^WORKER_SECRET=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
WORKER_API=$(grep "^WORKER_API=" "$APP_DIR/.env" 2>/dev/null | cut -d= -f2-)
if [[ -z "$WORKER_SECRET" || -z "$WORKER_API" ]]; then
  echo "WORKER_SECRET/WORKER_API missing in reel-app/.env — cannot fetch contact records."
  exit 1
fi

# A render session's cwd is its job folder, and it must never see contact info.
# ACQUIRE the worker's lock rather than testing it: a 33-folder run can take
# minutes, the worker is a LaunchAgent on StartInterval 600, and a check-then-go
# leaves a window where a job is claimed one second after we looked. Holding the
# lock makes us mutually exclusive with the worker by construction.
# The pid file matters — run-reel-worker.sh reclaims a pid-less lock after 5 min.
if ! mkdir "$JOBS_DIR/.worker-lock" 2>/dev/null; then
  echo "The reel worker holds its lock (a render may be in flight)."
  echo "Re-run this once it's idle — writing a card into a live session's cwd"
  echo "would defeat the contact scrub in run-reel-worker.sh."
  exit 1
fi
echo $$ > "$JOBS_DIR/.worker-lock/pid"
# A combined `trap ... EXIT INT TERM` is WRONG here: in zsh an INT/TERM handler
# runs and then RESUMES the script, so Ctrl-C would release the lock and keep
# writing cards unlocked, then the EXIT trap would delete the WORKER's lock and
# let a second worker instance start on a live job folder. Separate traps that
# actually exit, plus a pid-ownership check so we can only ever remove our own.
cleanup() {
  [[ "$(cat "$JOBS_DIR/.worker-lock/pid" 2>/dev/null)" == "$$" ]] && rm -rf "$JOBS_DIR/.worker-lock" 2>/dev/null
  return 0
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# A failed `source` above would leave every card silently unwritten while the
# run still reports success.
whence -f write_contact_card >/dev/null || { echo "contact-card.sh did not load — aborting."; exit 1; }

typeset -i WROTE=0 SKIPPED=0 NOREC=0
for D in "$JOBS_DIR"/*(/N); do
  ID="${D:t}"
  # Only real job folders: uuid-named, nothing else in jobs/ qualifies.
  [[ "$ID" =~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' ]] || continue

  # A folder mid-render has no terminal marker and is being written right now.
  if [ ! -f "$D/RELEASED" ] && [ ! -f "$D/PENDING-RELEASE" ] && [ ! -f "$D/SALVAGED" ] \
     && [ ! -f "$D/HOLD" ] && [ ! -f "$D/out/FAILED" ] && [ ! -f "$D/out/DONE" ]; then
    # Test what a RENDER session writes (log.txt, out/, work/), not the folder
    # itself — writing the card bumps the folder mtime and would otherwise make
    # this guard trip on its own previous run.
    if [ -n "$(find "$D/log.txt" "$D/out" "$D/work" "$D/photos" -newermt '-2 hours' 2>/dev/null | head -1)" ]; then
      echo "SKIP  $ID  (no terminal marker and touched in the last 2h — may be live)"
      (( SKIPPED++ )); continue
    fi
  fi

  # Two partial sources, so MERGE rather than pick. R2 often holds only a stub
  # for older jobs ({status, photos:[]}) while the local scrubbed copy still has
  # marcus_note / client / created; the API is the only place email/phone/story
  # live. Non-empty API values win, local fills every gap.
  API_RAW=$(curl -s --max-time 30 -H "Authorization: Bearer $WORKER_SECRET" "$WORKER_API/api/worker/job/$ID" 2>/dev/null)
  LOCAL_RAW=""
  [ -f "$D/job.json" ] && LOCAL_RAW=$(cat "$D/job.json")

  FIELDS=$(API_RAW="$API_RAW" LOCAL_RAW="$LOCAL_RAW" /usr/bin/python3 -c '
import json, os, shlex
def load(v):
    try:
        d = json.loads(v)
        return d if isinstance(d, dict) else {}
    except Exception:
        return {}
def usable(d):
    # An {"error": ...} body parses fine as a dict. Treating it as a record is
    # how a bad WORKER_SECRET yields 33 confident CONTACT-unknown.txt cards.
    return d and "error" not in d
merged = load(os.environ.get("LOCAL_RAW", ""))
if not usable(merged):
    merged = {}
api = load(os.environ.get("API_RAW", ""))
for k, v in (api if usable(api) else {}).items():
    if v not in (None, "", [], {}):
        merged[k] = v
if not merged:
    raise SystemExit(1)
for k in ("email", "phone", "handle", "client", "created", "story", "marcus_note"):
    name = "MNOTE" if k == "marcus_note" else k.upper()
    print("%s=%s" % (name, shlex.quote(str(merged.get(k) or "").replace("\n", " "))))
') || {
    echo "NOREC $ID  (no usable record in R2 or locally)"
    (( NOREC++ )); continue
  }
  eval "$FIELDS"

  LABEL="${EMAIL:-${CLIENT:-}}"; [ -n "$LABEL" ] || LABEL="${MNOTE:+internal}"; [ -n "$LABEL" ] || LABEL="unknown"
  if [ -z "$GO" ]; then
    echo "WOULD  $ID -> CONTACT-$LABEL.txt${STORY:+  (story: ${STORY[1,60]}...)}"
  else
    if write_contact_card "$D" "$ID" "$EMAIL" "$PHONE" "$HANDLE" "$CLIENT" "$CREATED" "$STORY" "$WORKER_API/reel?job=$ID" "$MNOTE"; then
      echo "WROTE  $ID -> CONTACT-$LABEL.txt"
    else
      echo "CARDFAIL $ID  (write_contact_card returned non-zero)"
    fi
  fi
  (( WROTE++ ))
done

echo ""
if [ -z "$GO" ]; then
  echo "DRY RUN: $WROTE card(s) would be written, $SKIPPED skipped, $NOREC without a record."
  echo "Re-run with --go to write them."
else
  echo "Done: $WROTE card(s) written, $SKIPPED skipped, $NOREC without a record."
fi
