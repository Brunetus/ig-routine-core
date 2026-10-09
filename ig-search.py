#!/usr/bin/python3
"""ig-search.py — the ONLY sanctioned way to SEARCH Instagram with the dormant
throwaway account (Marcus, 2026-09-18). Read-only: keyword search
(fbsearch/top_serp) and hashtag top posts (tags/web_info). Same guards as
ig-fetch.sh: bare "Profile N" only, never a business/Google-signed profile,
must hold an IG session, daily cap counts REQUESTS (fails included),
randomized human pacing, stop after 2 consecutive failures. Never posts,
likes, follows, saves, or DMs.

  ig-search.py kw "<phrase>"        keyword search
  ig-search.py tag <tag> [<tag> ...] hashtag pages, one request per tag, paced
  ig-search.py profile <handle> [...] a creator's profile + recent posts (the
                                    fallback when business_discovery misses)
Tag names are validated BEFORE any request: a name with a space, '#', or
anything outside [A-Za-z0-9_] is refused with exit 2 and costs nothing (no
count, no failure). Added 2026-09-27 after a scan passed ten tags as ONE
argument, sent one malformed request, and burned a search and a failure.
Output: JSON lines to stdout (code, username, likes, comments, plays,
duration, taken_at, caption) — nothing else. State/log in ~/.config/ig-fetch/.
"""
import json, os, sys, time, random, re, datetime, urllib.parse, urllib.request
sys.path.insert(0, os.path.expanduser('~/Library/Python/3.9/lib/python/site-packages'))
import logging; logging.disable(logging.WARNING)
import warnings; warnings.filterwarnings("ignore")
CFG_DIR=os.path.expanduser("~/.config/ig-fetch"); CFG=f"{CFG_DIR}/config.json"
STATE=f"{CFG_DIR}/search-state.json"; LOG=f"{CFG_DIR}/fetch.log"
FORBIDDEN={"Default","Profile 1","Profile 6"}
OWNER_EMAILS=("marc.brunet.r@gmail.com","mbrunet@maximahq.com","heliumdeploy")
def log(s):
    with open(LOG,"a") as f: f.write(f"{datetime.datetime.now():%F %T} SEARCH {s}\n")
def die(s): print(f"ig-search: {s}",file=sys.stderr); log(f"ABORT {s}"); sys.exit(1)
cfg=json.load(open(CFG)); profile=cfg["chrome_profile"]; handle=cfg.get("handle","?")
maxday=int(cfg.get("search_max_per_day",10)); mingap=int(cfg.get("min_gap",60)); maxgap=int(cfg.get("max_gap",90))
if profile in FORBIDDEN or "/" in profile or not re.fullmatch(r"Profile \d+",profile): die(f"REFUSING profile '{profile}'")
prefs=os.path.expanduser(f"~/Library/Application Support/Google/Chrome/{profile}/Preferences")
if not os.path.exists(prefs): die("no such profile")
emails=" ".join(a.get("email","") for a in json.load(open(prefs)).get("account_info",[]))
if any(e in emails for e in OWNER_EMAILS): die("REFUSING: profile holds one of Marcus's Google accounts")
from yt_dlp.cookies import extract_cookies_from_browser
jar=extract_cookies_from_browser("chrome",profile,logger=logging.getLogger("q"))
ck={c.name:c.value for c in jar if "instagram.com" in c.domain}
if "sessionid" not in ck or "csrftoken" not in ck: die("REFUSING: profile has no Instagram session")
# validate BEFORE touching state (a malformed call must cost nothing)
if len(sys.argv)<3: die("usage: ig-search.py kw \"<phrase>\" | tag <tag> [<tag> ...]")
mode=sys.argv[1]
if mode=="tag":
    qs=[t.lstrip("#") for t in sys.argv[2:]]
    bad=[t for t in qs if not re.fullmatch(r"[A-Za-z0-9_]{1,100}",t)]
    if bad:
        print(f"ig-search: REFUSED, not a tag name: {bad!r} (pass each tag as its own argument). Nothing was sent.",file=sys.stderr)
        log(f"REFUSED malformed tag args {bad!r} (no request, no count)"); sys.exit(2)
elif mode=="profile":
    qs=[h.lstrip("@") for h in sys.argv[2:]]
    bad=[h for h in qs if not re.fullmatch(r"[A-Za-z0-9._]{1,30}",h)]
    if bad:
        print(f"ig-search: REFUSED, not a handle: {bad!r}. Nothing was sent.",file=sys.stderr)
        log(f"REFUSED malformed handle args {bad!r} (no request, no count)"); sys.exit(2)
elif mode=="kw":
    qs=[" ".join(sys.argv[2:])]
else: die("mode must be kw|tag")
today=datetime.date.today().isoformat()
def load_state():
    st=json.load(open(STATE)) if os.path.exists(STATE) else {}
    if st.get("date")!=today: st={"date":today,"count":0,"fails":0,"last":0}
    return st
def fetch(q):
    st=load_state()
    if st["count"]>=maxday: print(f"ig-search: daily cap {maxday} reached, {q!r} and the rest wait",file=sys.stderr); log("CAP hit"); sys.exit(3)
    if st["fails"]>=2: print("ig-search: two consecutive failures today, stopped",file=sys.stderr); sys.exit(4)
    gap=random.randint(mingap,maxgap); since=time.time()-st["last"]
    if st["last"] and since<gap: time.sleep(gap-since)
    if mode=="kw": url="https://www.instagram.com/api/v1/fbsearch/top_serp/?enable_metadata=true&query="+urllib.parse.quote(q)
    elif mode=="profile": url="https://www.instagram.com/api/v1/users/web_profile_info/?username="+urllib.parse.quote(q)
    else: url="https://www.instagram.com/api/v1/tags/web_info/?tag_name="+urllib.parse.quote(q)
    req=urllib.request.Request(url,headers={
     "user-agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36",
     "x-ig-app-id":"936619743392459","x-csrftoken":ck["csrftoken"],"x-requested-with":"XMLHttpRequest",
     "referer":"https://www.instagram.com/explore/","accept":"*/*",
     "cookie":"; ".join(f"{k}={v}" for k,v in ck.items())})
    st["count"]+=1; st["last"]=time.time()
    try:
        data=json.loads(urllib.request.urlopen(req,timeout=30).read().decode("utf-8","replace"))
        st["fails"]=0; json.dump(st,open(STATE,"w")); return data,st
    except urllib.error.HTTPError as e:
        if mode=="profile" and e.code==404:
            # a missing profile is an ANSWER, not a bot signal: counted, not a failure
            st["fails"]=0; json.dump(st,open(STATE,"w")); log(f"OK profile {q!r} -> NOT FOUND (404) as @{handle} ({st['count']}/{maxday})")
            print(json.dumps({"profile":q,"found":False}),flush=True)
            print(f"ig-search: profile {q!r} -> not found on Instagram ({st['count']}/{maxday} today)",file=sys.stderr)
            return None,st
        if e.code==429:
            # Instagram's rate limit is a STOP signal (BANK.md): end browsing for the day, no retry
            st["fails"]=2; json.dump(st,open(STATE,"w")); log(f"STOP 429 rate-limited on {mode} {q!r} — browsing ends for today")
            print(f"ig-search: HTTP 429 (rate limited) on {q!r}. Browsing is over for today; do not retry.",file=sys.stderr); sys.exit(4)
        st["fails"]+=1; json.dump(st,open(STATE,"w")); log(f"FAIL {mode} {q!r} HTTPError {e.code}")
        print(f"ig-search: request failed on {q!r}: HTTP {e.code}",file=sys.stderr)
        if st["fails"]>=2: sys.exit(4)
        return None,st
    except Exception as e:
        st["fails"]+=1; json.dump(st,open(STATE,"w")); log(f"FAIL {mode} {q!r} {type(e).__name__} {str(e)[:80]}")
        print(f"ig-search: request failed on {q!r}: {e}",file=sys.stderr)
        if st["fails"]>=2: sys.exit(4)
        return None,st
def walk(o):
    if isinstance(o,dict):
        if "code" in o and "user" in o and ("like_count" in o or "play_count" in o): yield o
        for v in o.values(): yield from walk(v)
    elif isinstance(o,list):
        for v in o: yield from walk(v)
import urllib.error
for q in qs:
    data,st=fetch(q)
    if data is None: continue
    if mode=="profile":
        u=(data.get("data") or {}).get("user") or {}
        if not u:
            print(json.dumps({"profile":q,"found":False}),flush=True)
            log(f"OK profile {q!r} -> NOT FOUND (empty user) as @{handle} ({st['count']}/{maxday})")
            print(f"ig-search: profile {q!r} -> not found ({st['count']}/{maxday} today)",file=sys.stderr); continue
        print(json.dumps({"profile":q,"found":True,"username":u.get("username"),"full_name":u.get("full_name"),
            "is_business":u.get("is_business_account"),"is_professional":u.get("is_professional_account"),"is_private":u.get("is_private"),
            "followers":(u.get("edge_followed_by") or {}).get("count"),"posts":(u.get("edge_owner_to_timeline_media") or {}).get("count")}),flush=True)
        for ed in (u.get("edge_owner_to_timeline_media") or {}).get("edges",[]):
            n=ed.get("node",{}); capn=((n.get("edge_media_to_caption") or {}).get("edges") or [{}])
            cap=(capn[0].get("node",{}).get("text","") if capn else "")
            print(json.dumps({"code":n.get("shortcode"),"username":u.get("username"),"likes":(n.get("edge_liked_by") or n.get("edge_media_preview_like") or {}).get("count"),
                "comments":(n.get("edge_media_to_comment") or {}).get("count"),"plays":n.get("video_view_count"),"video":bool(n.get("is_video")),
                "duration":n.get("video_duration"),"taken_at":datetime.datetime.fromtimestamp(n["taken_at_timestamp"]).strftime("%Y-%m-%d") if n.get("taken_at_timestamp") else None,
                "caption":cap[:200].replace("\n"," ")}),flush=True)
        log(f"OK profile {q!r} -> found as @{handle} ({st['count']}/{maxday})")
        print(f"ig-search: profile {q!r} -> found ({st['count']}/{maxday} today)",file=sys.stderr)
        continue
    seen=set(); n=0
    for m in walk(data):
        if m["code"] in seen: continue
        seen.add(m["code"]); n+=1
        cap=(m.get("caption") or {}).get("text","") if isinstance(m.get("caption"),dict) else ""
        print(json.dumps({"tag":q if mode=="tag" else None,"code":m["code"],"username":(m.get("user") or {}).get("username"),"likes":m.get("like_count"),
            "comments":m.get("comment_count"),"plays":m.get("play_count") or m.get("ig_play_count"),
            "video":bool(m.get("video_versions") or m.get("media_type")==2),"duration":m.get("video_duration"),
            "taken_at":datetime.datetime.fromtimestamp(m["taken_at"]).strftime("%Y-%m-%d") if m.get("taken_at") else None,
            "caption":cap[:200].replace("\n"," ")}),flush=True)
    log(f"OK {mode} {q!r} -> {n} media as @{handle} ({st['count']}/{maxday})")
    print(f"ig-search: {mode} {q!r} -> {n} media ({st['count']}/{maxday} today)",file=sys.stderr)
