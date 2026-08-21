#!/bin/zsh
# ig-fetch.sh — the ONLY sanctioned way to pull a reel that the Graph API
# withholds (licensed audio). Everything else uses the Graph API's media_url.
#
# Context: 2026-08-20 Instagram warned @imabgold for "automated behavior"
# after ~20 cookie-driven yt-dlp downloads in tight bursts. The capability
# is kept (Marcus's call 2026-08-21) but moved off every account that
# matters and wrapped in limits the tool enforces, so pace is never left to
# anyone's judgment.
#
#   ig-fetch.sh <shortcode> <dest.mp4> [<shortcode> <dest.mp4> ...]
#
# Config: ~/.config/ig-fetch/config.json
#   { "chrome_profile": "Profile N",   # the DORMANT account's own profile
#     "handle": "<dormant handle>",    # for the log only
#     "max_per_day": 5, "min_gap": 60, "max_gap": 90 }   # cap counts REQUESTS (fails included)
# State/log: ~/.config/ig-fetch/{state.json,fetch.log}

set -u
CFG_DIR="$HOME/.config/ig-fetch"
CFG="$CFG_DIR/config.json"
STATE="$CFG_DIR/state.json"
LOG="$CFG_DIR/fetch.log"
YT="$HOME/Library/Python/3.9/bin/yt-dlp"
FF=$(ls "$HOME/Library/Python/3.9/lib/python/site-packages/imageio_ffmpeg/binaries/"ffmpeg-* 2>/dev/null | head -1)

# Chrome profiles that hold a BUSINESS session — using their cookies is
# exactly what caused the warning. Hard refusal, not a warning.
FORBIDDEN=("Default" "Profile 1" "Profile 6")

log() { print -r -- "$(date '+%F %T') $*" >> "$LOG"; }
die() { print -r -- "ig-fetch: $*" >&2; log "ABORT $*"; exit 1; }

[ -f "$CFG" ] || die "no config at $CFG (see setup notes in this script's header)"
[ -x "$YT" ] || die "yt-dlp not found at $YT"

PROFILE=$(/usr/bin/python3 -c "import json;print(json.load(open('$CFG'))['chrome_profile'])" 2>/dev/null) \
  || die "config unreadable"
HANDLE=$(/usr/bin/python3 -c "import json;print(json.load(open('$CFG')).get('handle','?'))" 2>/dev/null)
MAXDAY=$(/usr/bin/python3 -c "import json;print(int(json.load(open('$CFG')).get('max_per_day',5)))")
MINGAP=$(/usr/bin/python3 -c "import json;print(int(json.load(open('$CFG')).get('min_gap',60)))")
MAXGAP=$(/usr/bin/python3 -c "import json;print(int(json.load(open('$CFG')).get('max_gap',90)))")

for f in "${FORBIDDEN[@]}"; do
  [ "$PROFILE" = "$f" ] && die "REFUSING: '$PROFILE' holds a business session (imabgold/bambi/maxima). Point chrome_profile at the dormant account's own profile."
done
# The name denylist alone is not enough (audit 2026-08-21): a path-style
# profile, a new "Profile 8", or Marcus signing into a business account in
# the dormant profile would all slip past it. Positive checks:
#  - chrome_profile must be a bare "Profile N" directory name, no slashes;
#  - that profile's Chrome Preferences must not carry one of Marcus's own
#    Google accounts (the business profiles all do; the dormant one does not);
#  - the profile must hold an instagram.com session at all (else yt-dlp
#    would fall back to an anonymous fetch that looks exactly like a bot).
case "$PROFILE" in */*|.*|"") die "REFUSING: chrome_profile must be a bare 'Profile N' name, got '$PROFILE'";; esac
PREFS="$HOME/Library/Application Support/Google/Chrome/$PROFILE/Preferences"
[ -f "$PREFS" ] || die "REFUSING: no Chrome profile dir for '$PROFILE'"
OWNER_EMAILS='marc.brunet.r@gmail.com mbrunet@maximahq.com heliumdeploy'
PROFILE_EMAIL=$(/usr/bin/python3 -c "import json,sys;print(' '.join(a.get('email','') for a in json.load(open(sys.argv[1])).get('account_info',[])))" "$PREFS" 2>/dev/null)
for e in ${=OWNER_EMAILS}; do
  case "$PROFILE_EMAIL" in *"$e"*) die "REFUSING: '$PROFILE' is signed into Marcus's own account ($e) — not a dormant profile";; esac
done
COOKIES="$HOME/Library/Application Support/Google/Chrome/$PROFILE/Cookies"
HAS_IG=$(/usr/bin/sqlite3 -readonly "file:$COOKIES?immutable=1" "select count(*) from cookies where host_key like '%instagram.com' and name='sessionid'" 2>/dev/null || echo 0)
[ "${HAS_IG:-0}" -ge 1 ] || die "REFUSING: '$PROFILE' holds no instagram.com session — sign the dormant account in first"

# ---- daily budget (calendar day, local) ----
TODAY=$(date +%F)
USED=0; LAST=0
if [ -f "$STATE" ]; then
  USED=$(/usr/bin/python3 -c "
import json;d=json.load(open('$STATE'));print(d['count'] if d.get('date')=='$TODAY' else 0)" 2>/dev/null || echo 0)
  LAST=$(/usr/bin/python3 -c "import json;print(int(json.load(open('$STATE')).get('last',0)))" 2>/dev/null || echo 0)
fi

save_state() {
  /usr/bin/python3 -c "
import json;json.dump({'date':'$TODAY','count':$USED,'last':$1}, open('$STATE','w'))"
}

FAILS=0
while [ $# -ge 2 ]; do
  CODE="$1"; DEST="$2"; shift 2
  # day rollover mid-run must not hand out a fresh budget (audit 2026-08-21)
  if [ "$(date +%F)" != "$TODAY" ]; then
    print -r -- "ig-fetch: day rolled over mid-run; stopping, the rest wait for a new invocation."; log "STOP day rollover"; exit 3
  fi

  [ "$USED" -ge "$MAXDAY" ] && { print -r -- "ig-fetch: daily cap $MAXDAY reached. $CODE and the rest wait for tomorrow."; log "CAP hit, deferred $CODE"; exit 3; }
  [ "$FAILS" -ge 2 ] && { print -r -- "ig-fetch: two consecutive failures. Stopping (repeated retries are the bot signal)."; log "STOP after 2 consecutive failures"; exit 4; }
  [ -f "$DEST" ] && { print -r -- "ig-fetch: $DEST exists, skipping"; continue; }

  # human-ish spacing since the previous fetch, randomized
  NOW=$(date +%s)
  GAP=$(( MINGAP + (RANDOM % (MAXGAP - MINGAP + 1)) ))
  SINCE=$(( NOW - LAST ))
  if [ "$LAST" -gt 0 ] && [ "$SINCE" -lt "$GAP" ]; then
    WAIT=$(( GAP - SINCE ))
    print -r -- "ig-fetch: pacing, ${WAIT}s before $CODE"
    /bin/sleep "$WAIT"
  fi

  print -r -- "ig-fetch: $CODE -> $DEST (as @$HANDLE, ${USED}/${MAXDAY} today)"
  if "$YT" -q --no-warnings --cookies-from-browser "chrome:$PROFILE" \
       -f "bv*+ba/b" --merge-output-format mp4 -o "$DEST" \
       "https://www.instagram.com/reel/$CODE/" 2>>"$LOG"; then
    USED=$(( USED + 1 )); FAILS=0; LAST=$(date +%s); save_state "$LAST"
    # yt-dlp often yields VP9, which QuickTime can't play — normalise
    if [ -n "$FF" ] && "$FF" -i "$DEST" 2>&1 | grep -q "Video: vp9"; then
      "$FF" -y -i "$DEST" -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
        -c:a copy "$DEST.h264.mp4" -loglevel error && mv "$DEST.h264.mp4" "$DEST"
      print -r -- "  transcoded vp9 -> h264"
    fi
    log "OK $CODE ($(stat -f %z "$DEST" 2>/dev/null) bytes) as @$HANDLE"
  else
    # a failed request is still a request Instagram saw — it counts against the cap
    FAILS=$(( FAILS + 1 )); USED=$(( USED + 1 )); LAST=$(date +%s); save_state "$LAST"
    rm -f "$DEST"
    print -r -- "ig-fetch: FAILED $CODE (failure $FAILS of 2 allowed)"
    log "FAIL $CODE"
  fi
done
print -r -- "ig-fetch: done. ${USED}/${MAXDAY} used today."
