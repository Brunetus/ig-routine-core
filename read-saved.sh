#!/bin/zsh
# read-saved.sh — the ONLY sanctioned read of Marcus's private Instagram Saved
# collection (BANK.md step 1b; guard 4 carve-out, Marcus 2026-09-24).
#
# Renders ONE collection page headlessly from a COPY of his Chrome profile's
# cookie jar, takes shortcodes + handles off the rendered grid, appends the
# new ones to viral-bank/saved-inbox.md under "## inbox". Nothing else:
#   - no downloads, no yt-dlp, no scrolling, no second URL, no writes to Chrome
#   - once per calendar day (state file), any second run exits 0 with "already ran"
#   - refuses the throwaway profile and any URL that is not the configured collection
#
# Config: ~/.config/ig-fetch/saved.json
#   { "chrome_profile": "Profile 1",          # the profile holding HIS session (Chrome shows it as "Marc")
#     "collection_url": "https://www.instagram.com/imabgold/saved/viral-stuff/901996575663900/",
#     "inbox": "/Users/marcusaurelius/Claude Code/viral-bank/saved-inbox.md",
#     "catalog": "/Users/marcusaurelius/Claude Code/viral-bank/catalog.md",
#     "render_seconds": 40 }
# State/log: ~/.config/ig-fetch/saved-state.json, ~/.config/ig-fetch/saved.log
# Exit: 0 ok / 2 config / 3 chrome or cookie-jar problem / 4 nothing rendered / 5 session not identified or 0 items (logged out / challenge)

set -u
CFG="$HOME/.config/ig-fetch/saved.json"; STATE="$HOME/.config/ig-fetch/saved-state.json"; LOG="$HOME/.config/ig-fetch/saved.log"
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
say() { echo "read-saved: $*"; echo "$(date '+%F %T') $*" >> "$LOG"; }
[ -f "$CFG" ] || { say "no config at $CFG"; exit 2; }
PROFILE=$(python3 -c "import json;print(json.load(open('$CFG'))['chrome_profile'])")
URL=$(python3 -c "import json;print(json.load(open('$CFG'))['collection_url'])")
INBOX=$(python3 -c "import json;print(json.load(open('$CFG'))['inbox'])")
CATALOG=$(python3 -c "import json;print(json.load(open('$CFG'))['catalog'])")
SECS=$(python3 -c "import json;print(json.load(open('$CFG')).get('render_seconds',40))")
[ "${1:-}" = "" ] || [ "$1" = "$URL" ] || { say "REFUSING: only the configured collection URL may be read"; exit 2; }
[ "$PROFILE" = "Profile 1" ] || { say "REFUSING: chrome_profile must be 'Profile 1' (his own session), got '$PROFILE'"; exit 2; }
case "$URL" in https://www.instagram.com/imabgold/saved/*) ;; *) say "REFUSING: collection_url must be under instagram.com/imabgold/saved/"; exit 2;; esac
case "$URL" in *..*|*\?*|*\#*) say "REFUSING: collection_url may not contain .., ? or #"; exit 2;; esac
[ -x "$CH" ] || { say "Chrome not found"; exit 3; }
TODAY=$(date +%F)
if [ -f "$STATE" ] && [ "$(python3 -c "import json;print(json.load(open('$STATE')).get('date',''))")" = "$TODAY" ]; then say "already ran today"; exit 0; fi
SRC="$HOME/Library/Application Support/Google/Chrome"; UDD=$(mktemp -d /tmp/read-saved.XXXXXX); mkdir -p "$UDD/Default"
PID=""; trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$UDD"' EXIT
trap '[ -n "$PID" ] && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; rm -rf "$UDD"; exit 130' INT TERM
# once-per-day counts ATTEMPTS, not successes: a failed or suspicious render must not be retried on his session
echo "{\"date\":\"$TODAY\",\"result\":\"attempted\"}" > "$STATE"
cp "$SRC/Local State" "$UDD/Local State" 2>/dev/null || { say "no Local State"; exit 3; }
cp "$SRC/$PROFILE/Cookies" "$UDD/Default/Cookies" 2>/dev/null || sqlite3 "$SRC/$PROFILE/Cookies" ".backup '$UDD/Default/Cookies'" 2>/dev/null || { say "cannot copy cookie jar"; rm -rf "$UDD"; exit 3; }
DOM="$UDD/dom.html"
# UA follows the INSTALLED Chrome so his session never shows up from an older browser than the one he uses
CHV=$("$CH" --version 2>/dev/null | grep -o '[0-9][0-9.]*' | head -1); [ -n "$CHV" ] || CHV="128.0.0.0"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$CHV Safari/537.36"
( exec "$CH" --headless=new --user-agent="$UA" --user-data-dir="$UDD" --profile-directory=Default --no-first-run --no-default-browser-check --disable-gpu --window-size=1280,2400 --virtual-time-budget=20000 --dump-dom "$URL" > "$DOM" 2>/dev/null ) & PID=$!
for i in $(seq 1 "$SECS"); do kill -0 $PID 2>/dev/null || break; sleep 1; done; kill -0 $PID 2>/dev/null && { kill $PID 2>/dev/null; wait $PID 2>/dev/null; }; PID=""
[ -s "$DOM" ] || { say "nothing rendered"; exit 4; }
grep -q '"username":"imabgold"' "$DOM" || { say "session not identified (logged out or a challenge page) — check Chrome Profile 1"; exit 5; }
RES=$(python3 - "$DOM" "$INBOX" "$CATALOG" "$TODAY" <<'PY'
import re,sys
dom,inbox,catalog,today=sys.argv[1:5]
h=open(dom,encoding='utf-8',errors='ignore').read()
cut=min([m.start() for m in re.finditer(r'More posts from|Show more posts|Accounts you might like|Suggested for you|Reels you might like',h)] or [len(h)])
found=[]; seen=set()
for m in re.finditer(r'href="/([A-Za-z0-9_.]+)/(reel|p)/([A-Za-z0-9_-]{8,14})/"',h[:cut]):
    handle,kind,code=m.groups()
    if code in seen or handle in ('reel','p','explore'): continue
    seen.add(code); found.append((code,handle,kind))
known=set(re.findall(r'^## ([A-Za-z0-9_-]{8,14}) ',open(catalog).read(),re.M))
ib=open(inbox).read()
assert "## inbox\n" in ib, "saved-inbox.md has no '## inbox' header"
known|=set(re.findall(r'/(?:reel|reels|p)/([A-Za-z0-9_-]{8,14})',ib))   # every inbox/processed line carries a URL; handles trailing '-' codes and bare-URL lines
new=[(c,h,k) for c,h,k in found if c not in known]
if new:
    lines="".join(f"{c} @{h} https://www.instagram.com/{k}/{c}/\n" for c,h,k in new)
    ib=ib.replace("## inbox\n","## inbox\n"+lines,1); open(inbox,'w').write(ib)
if not found: print("0 on grid"); sys.exit(5)
print(f"{len(found)} on grid, {len(new)} new appended")
PY
)
RC=$?; [ $RC -eq 5 ] && { say "0 on grid — treat as session/challenge problem"; exit 5; }
[ $RC -ne 0 ] && { say "parse failed rc=$RC"; exit 4; }
echo "{\"date\":\"$TODAY\",\"result\":\"$RES\"}" > "$STATE"
say "$RES"
