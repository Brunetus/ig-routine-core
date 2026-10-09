#!/bin/zsh
# job-who.sh — the one answer to "whose job is this?" for every ntfy push.
# Sourced by run-reel-worker.sh, release-reel.sh and run-reel-notify.sh.
# Marcus reads the pushes on his iPhone, and a bare uuid means looking it up,
# so every push title starts with this name (Marcus, 2026-10-07). The same
# rule lives inline in clips-watch.mjs and in run-drive-watch.sh's Python.
#
# Rule, first hit wins: eclip.username (as @name), handle (as @name), client,
# the email's local part, else "job <id8>". job.json first; ECLIP.json covers
# a folder clips-watch staged that the worker has not claimed yet. The worker
# scrubs email out of job.json, so the email comes from the caller when it
# has one, else from the folder's CONTACT card.

# job_who <job_dir> [email]     a job folder
# job_who --json <job json>     the server's job record (no folder yet)
job_who() {
  local W
  W=$(/usr/bin/python3 - "$@" <<'PYWHO' 2>/dev/null
import glob, json, os, re, sys
args = sys.argv[1:] + ["", ""]
def obj(v):
    return v if isinstance(v, dict) else {}
def load(path):
    try:
        return obj(json.load(open(path)))
    except Exception:
        return {}
# A name goes into an HTTP header: no control characters, ever.
def clean(v):
    return re.sub(r"[\x00-\x1f\x7f]+", " ", str(v or "")).strip()[:60]
card = ""
if args[0] == "--json":
    try:
        job = obj(json.loads(args[1]))
    except Exception:
        job = {}
    staged, jid, email = {}, str(job.get("id") or ""), ""
else:
    d = args[0].rstrip("/")
    job = load(os.path.join(d, "job.json"))
    staged, jid, email = load(os.path.join(d, "ECLIP.json")), os.path.basename(d), args[1]
    for p in sorted(glob.glob(os.path.join(d, "CONTACT-*.txt"))):
        try:
            for line in open(p):
                if line.startswith("email:") and "@" in line:
                    card = line.split(":", 1)[1]
        except Exception:
            pass
user = clean(obj(job.get("eclip")).get("username") or staged.get("username")).lstrip("@")
handle = clean(job.get("handle")).lstrip("@")
client = clean(job.get("client"))
local = clean(job.get("email") or email or card).split("@")[0]
print("@" + user if user else "@" + handle if handle else client or local or "job " + (jid[:8] or "?"))
PYWHO
)
  [ -n "$W" ] || W="job ${${1:t}[1,8]}"
  printf '%s\n' "$W"
}
