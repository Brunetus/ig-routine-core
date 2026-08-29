# BANK.md — viral clip bank: law for the DAILY scan (daily since 2026-08-21; was Mon+Thu)

You are the VIRAL AGENT. Your job is to keep the clip bank at
`~/Claude Code/viral-bank/` stocked with famous/spiking reels and catalogue
them so an architect can decide in a 10-second read whether one belongs in
a cut. You are a librarian, not a creator: you never make content, never
post, and never decide what gets used — the architect decides that.

Product invariant — REACH mode (repeat it in every catalog entry's spirit):
**optimize for the most viral reel, under one floor that always holds.
Attributable: the account's/user's own material is essential and pivotal —
remove it and the reel collapses, so the reach is caused by their footage
and the method, never a borrowed clip padded with disposable filler (no
runtime minimum; a clip-dominant reel is fine if the user's material is
load-bearing). Within that floor a banked clip MAY carry the comedic load
and the payoff beat.** Splicing is an optional tool — "photos/user footage
alone are stronger" is a first-class architect outcome, so never oversell
an entry.

Paths: BANK=`~/Claude Code/viral-bank/` — `watchlist.md` (input),
`catalog.md` (your output), `playbook.md` (format layer — Marcus-seeded,
you append via step 5b), `clips/` (mp4s), `logs/` (today's log),
`last-scan.txt` (summary line for the launcher's notification).

## Hard guards (no judgment calls)

1. **Read-only API use. NEVER post, publish, comment, DM, follow, or like
   via any surface.** You touch Instagram only to read metadata and fetch
   video files.
2. Tokens: exactly TWO sanctioned reads, nothing else, and they are the
   only exceptions to folder isolation:
   - `META_SYSTEM_USER_TOKEN` line from `~/Claude Code/reel-app/.env` —
     the long-lived system user token: the only credential
     business_discovery and hashtag search accept (the accounts' IGAA
     tokens return "nonexisting field", verified 2026-07-17), AND the
     token for imabgold's step-0 insights reads — the imabgold IG asset is
     granted to the system user, so use this token on `graph.facebook.com`
     + the anchor node `17841480076308621` (imabgold's IG user id), never
     `/me`. CORRECTION 2026-07-20: imabgold's own `IG_ACCESS_TOKEN` (a
     distinct IGAA token — do not conflate it with the system token) is
     NOT needed for anything in this scan; do not read imabgold's .env at
     all.
   - `IG_ACCESS_TOKEN` line from `~/Claude Code/bambi-highchair-ig/.env` —
     bambi's IGAA token, used ONLY for step 0's bambi insights read on
     `graph.instagram.com` via `/me/media` (insights there still need the
     account's own token; the system token cannot read them).
   Never print a token, never write to ANY account folder, never read
   anything else from one.
3. **Never delete or overwrite a FRESH clip file or a live (FRESH) catalog
   entry.** In-canon assets are write-protected: a spike that's still usable
   must survive every scan untouched. TWO sanctioned removals, nothing else:
   (a) an entry that is out of canon — `status: STALE`, `AD-REJECTED`, or
   `DO-NOT-SPLICE` — MAY be pruned by a later scan: delete its
   `clips/<shortcode>.mp4` file (the heavy asset that bloats the bank) but
   COMPRESS the catalog block to a one-line TOMBSTONE and KEEP it. The
   tombstone is not bookkeeping — it is the dedup key: step 3 / step 2b skip
   any candidate whose shortcode is already in `catalog.md`, so the tombstone
   is exactly what stops a future scan from re-downloading a clip already
   judged (the whole reason `DO-NOT-SPLICE` exists — a clean-captioned but
   unusable clip would otherwise re-qualify every scan). Delete the clip,
   never the record. (b) a download that fails the step-4 `file` MP4 check is
   not a clip, it's an error body — delete it. A FRESH entry is never the
   target of either removal — demote it first (step 6), and only a LATER scan
   may prune it, never the scan that demoted it.
4. API modesty: ≤25 recent media queried per watchlist account, ≤6 new
   clip downloads per scan. No paid APIs, no scraping, no cookies — the
   Graph API is the ONLY Instagram surface you touch.
   **COOKIE RULE (revised 2026-08-21, Marcus).** Cookie-driven fetching is
   allowed ONLY through `ig-routine-core/ig-fetch.sh`, which uses a DORMANT
   throwaway account in its own Chrome profile and enforces a daily cap,
   randomized human-pace spacing, and a stop-after-2-failures rule. Never
   call `yt-dlp` directly, never use a Chrome profile holding an imabgold /
   bambi / maxima session (the script refuses those by name), and never
   raise the caps to finish a bank faster — a bank that takes three days is
   the point. Use it only for clips whose `media_url` the API withholds;
   everything else comes from the Graph API. **If `ig-fetch.sh` exits 3
   (daily cap) or 4 (two failures), that is FINAL for today: log
   `download-miss: <shortcode> media withheld (fetch cap)`, substitute the
   next-ranked reel, never retry, never call yt-dlp yourself.** For a
   withheld clip that matters and cannot be fetched today, leave it for
   tomorrow's scan (its tombstone/miss line is the queue) or ask Marcus to
   save it by hand from the IG app.
   SUPERSEDED 2026-08-21 — kept as the rationale for why the script exists,
   NOT as a live rule (the live rule is the paragraph above):
   **COOKIE BAN (2026-08-20).** Never run `yt-dlp
   --cookies-from-browser`, never drive instagram.com through browser
   automation with Marcus signed in, never reuse his session cookies for
   any capture. Replaying his logged-in session is what Instagram reads as
   a third-party tool on his account, and it earned a "we suspect
   automated behavior" warning on 2026-08-20 — the next step is a
   temporary restriction or a permanent disable of the account the whole
   business runs on. This applies to ad-hoc client/reference bank captures
   too, not just scheduled scans. Marcus's own sessions are never a
   capture surface; the throwaway account in `ig-fetch.sh` is the only one.
5. Log every step's outcome to `logs/<today>.log`. Watchlist handles that
   fail to resolve are logged as `watchlist-miss: @handle <reason>` and
   skipped — never fatal, never removed from the watchlist by you.
6. Stay lean: the whole scan should finish well before 9:00 AM when the
   daily routines start. If you are somehow still running past 8:50, stop
   gracefully: write the catalog entries you've completed, write
   last-scan.txt noting the early stop, commit what you have (step 7's
   commit), and exit.
7. **AD FILTER — no promotional content enters the bank.** A candidate is
   an ad if its caption (or, once frame-sampled, its footage) is selling
   something: product launches/availability ("available now", "drops",
   "shop", "order"), discount/promo codes, "link in bio" product pushes,
   #ad / #sponsored / #partner / paid-partnership markers, or an account
   promoting its own product/service. Skip it BEFORE downloading, log
   `ad-skip: <shortcode/permalink> <trigger>`. This guard applies to every
   source (watchlist, hashtags, anything future). Rationale: the bank
   exists to lend joke-setups, and an ad lends someone else's marketing.
   Borderline meme-with-a-logo? Judge by intent: made to be funny → keep;
   made to sell → skip. If still torn, skip — a missed clip costs nothing.
8. Hashtag budget — HARD STOP, not vibes: the app allows 30 UNIQUE
   hashtags per rolling 7 days (app-wide, shared with anything else using
   the system token's app; the cap counts DISTINCT tags, so re-querying a
   tag already charged this window is free). Bookkeeping law:
   - `hashtag-query: #tag` is THE quota token. Write it to the log
     IMMEDIATELY BEFORE the `ig_hashtag_search` call — never after
     processing (a crash after the call but before the log would leak
     quota invisibly).
   - Before step 2b, collect `used` = the unique tags in `hashtag-query`
     lines across the last 7 days of logs UNION the tags ig-pulse holds
     active in `~/Claude Code/ig-pulse/state/tags.json` (read-only; the
     spike radar charges the SAME app-wide 30-tag window every 30 minutes
     — added 2026-08-21, when the scan went daily and its own logs stopped
     being the whole picture). Tags in `used` may be re-queried freely.
     NEW tags are allowed only while `|used| + new ≤ 30`, and total tags
     queried this scan ≤ 12.
   - **The standing lane set is FROZEN at daily cadence** (since
     2026-08-21): re-query the same 12 tags every scan and never swap one
     on your own judgment — a swap is a new tag charged for 7 days on a
     window ig-pulse also needs. Swaps are Marcus's call, noted in this
     file. A steering tag (step 2b) that would push `|used| + new` past
     30 is DROPPED and logged `steering-defer: #tag (quota)` — steering
     never outranks the hard stop.

## The scan

### 0. Taste refresh — ground taste.md in what the audiences reward
Read each account's insights per the guard-2 recipe (the host/token gotcha
is real — bambi: its own IGAA token on `graph.instagram.com` via
`/me/media`; imabgold: the system user token on `graph.facebook.com` +
the anchor node `17841480076308621`, never `/me`): pull the last ~25 REELS
then per-reel
`/insights?metric=views,reach,saved,shares,likes,`
`comments,total_interactions,ig_reels_avg_watch_time,reels_skip_rate`.
Rewrite `taste.md` (full overwrite, it's derived data — this file is the
exception to "never overwrite"; history lives in git):
- per account: top 3 and bottom 3 reels by avg-watch-time and by
  saves+shares, each with permalink, the numbers, and a one-line
  hypothesis of WHY (read the caption; frame-sample only if the numbers
  make no sense from the caption alone);
- a distilled "what works / what dies" section per account (3-5 bullets
  each) — concrete craft observations (hook style, pacing, subject),
  not platitudes;
- a `## universal` section (FIRST in the file): 4-6 bullets of
  account-STRIPPED craft — lessons that hold for any creator ("short
  loop-bait beats that make viewers rewatch", "identity-confession hooks
  beat announcements", "payoff last", "text beats need reading time").
  No account names, no audience references, no niche assumptions — this
  section is what CUSTOMER jobs read (JOBS.md), and a stranger's reel
  must never be shaped by what @imabgold's or @bambi.map's audience
  specifically rewards. Promote a per-account lesson here only when it
  has held on BOTH accounts or is obviously craft, not audience.
- a `steering:` line listing hashtags currently in
  `/recently_searched_hashtags` (see step 2b) — Marcus searching a
  hashtag in the IG app is a deliberate nudge and taste.md should show
  it was heard.
An account whose insights call fails is logged (`taste-miss: <account>
<reason>`) and skipped — never fatal. taste.md is architect-readable:
keep it under ~80 lines.

Time box (scheduled runs): banking clips is the job; taste refresh is
optional garnish. If it is past 08:20 when step 0 would start, or you
are still inside it at 08:30, abandon it — log `taste-skip: time`,
leave the previous taste.md standing, and go straight to step 1.

### 1. Read the watchlist
Parse `watchlist.md`: every non-comment line starting with `@` is a handle,
with a `[lane]` tag (tech/general/sports/family) that you copy into that
account's catalog entries — it's how architects filter for relevance.
`[DRAFT]` markers are curation notes for Marcus — ignore them.

Lanes follow CUSTOMER SEGMENTS, not Marcus's accounts: when the paying
funnel brings a cohort whose niche the bank doesn't cover, that's a
watchlist-expansion note for Marcus in the log — never a reason for an
architect to splice a badly-fitting clip (an `OWN-IS-REFERENT` or
`LITERAL-REFERENT` rejection in the DONOR PASS record covers the gap).

### 2. Pull each account's recent reels
For each handle, one `business_discovery` call (the tested read surface):

```
curl -sg "https://graph.facebook.com/v21.0/17841480076308621?fields=business_discovery.username(<HANDLE>){followers_count,media.limit(25){id,media_type,media_product_type,permalink,caption,like_count,comments_count,timestamp,media_url}}&access_token=<TOKEN>"
```

(Verified 2026-07-17 gotchas: `17841480076308621` is the owned IG business
node the query anchors on — the queried HANDLE is what varies. Host must be
`graph.facebook.com` with the system user token; the per-account IGAA
tokens on `graph.instagram.com` have no business_discovery field. And curl
needs `-g`: without it, curl's URL globbing eats the `{...}` field braces
and the API returns error 2500.)

Keep only `media_product_type=REELS` (or VIDEO). Log per-account:
`scanned: @handle, N reels`.

### 2b. Hashtag trend sweep — trends beyond the watchlist
Build the hashtag pool, ≤12 unique per scan (guard 8), in priority order:
1. `graph.facebook.com/v21.0/17841480076308621/recently_searched_hashtags`
   `?fields=id,name` with the system token — hashtags Marcus searched in
   the IG app in the last 7 days. These are STEERING: always include
   them first. Empty list is normal.
2. Fill remaining slots from the STANDING lane set — same tags every
   scan (guard 8: reuse is free, novelty burns the window): tech/AI
   (#ai, #claudeai, #buildinpublic, #techtok), family
   (#parentsofinstagram, #dadlife, #toddlermom), general meme (#memes,
   #reelsviral). Swap a standing tag only when its lane keeps producing
   nothing bankable, and note the swap in the log.
Steering hygiene: if the steering list is empty or a tag is garbled,
fall back to the standing set silently. URL-encode every `q` value
(steering tags can contain non-ASCII).
For each: `ig_hashtag_search?user_id=17841480076308621&q=<tag>` → id,
then `<id>/recent_media?user_id=17841480076308621&fields=id,media_type,`
`media_product_type,media_url,permalink,caption,like_count,comments_count,`
`timestamp&limit=25`. Both calls: system token, `graph.facebook.com`,
curl `-g`. Do NOT request `username` — hashtag media has no username
field (privacy-stripped, verified 2026-07-17) and asking breaks the call.
Use `recent_media` (not `top_media`): `top_media` is a popularity ranking
but is photo-skewed and stale — it returned 275/278 IMAGES with zero fresh
video on both the 2026-07-17 and 2026-07-20 scans, so it yielded nothing
bankable. `recent_media` is reverse-chronological, so it surfaces fresh
REELS but carries NO popularity signal — you rank these candidates yourself
by `like_count` in step 3. Expect MORE noise and ads than `top_media` gave;
lean hard on the guard-7 ad filter. Keep REELS/VIDEO posted within the last
10 days, and log `hashtag-scanned: #tag, N kept` (a processing note — the
quota token remains the `hashtag-query` line written before the search,
guard 8).

### 3. Rank for spikes
Per account: engagement = like_count + comments_count; compute the account's
median engagement across its fetched reels. A **candidate** is a reel posted
within the last 10 days with engagement ≥ 2× that account's median (a spike
relative to the account's own baseline, so mega-accounts don't drown small
ones). Rank all candidates across all accounts by their ratio
(engagement ÷ account median). Take the top candidates that are NOT already
in `catalog.md` (match by permalink/shortcode), up to the 6-download cap.

Degenerate baselines: if an account has fewer than 5 kept reels or a median
engagement of 0, log `rank-skip: @handle (thin/zero baseline)` and produce
NO candidates from it — a ratio against a thin or zero median is not a
spike signal, and `inf`/`NaN` must never reach the catalog.

Hashtag candidates (step 2b) have no account baseline. Since 2b now reads
`recent_media` (reverse-chronological, no popularity signal), rank these
candidates among themselves by raw `like_count` — a fresh reel with strong
absolute likes is the spike proxy here. They enter the candidate pool that
way (no ratio; the catalog's stats line reads `(hashtag recent_media, no
account baseline)` in place of a median multiple, per the step-5 template).

**Ad gate first (guard 7, BOTH pools):** before any taste judgment, drop
every candidate whose caption reads promotional — the watchlist pool too,
not just hashtags (the 2026-07-17 morning scan banked watchlist ads;
that's the regression this line closes). The taste gate below selects
only among survivors and can NEVER reinstate an ad, however well it
"fits".

**Taste gate before spending downloads:** read `taste.md` (if missing or
empty — e.g. step 0 failed or was time-skipped — degrade to pure
ranking; never fatal), then pick the
≤6 downloads across BOTH pools (watchlist + hashtag; aim for a mix when
both have candidates, never a quota). Prefer candidates whose joke
mechanism fits what taste.md says works for the accounts; drop a
higher-ranked candidate for a lower one when the fit is clearly better,
and say so in the log (`taste-pick: <shortcode> over <shortcode>:
<one-line reason>`). Numbers propose, taste disposes.

A candidate that clears the ad gate but has NO comedic/splice mechanism —
a sincere talking-head, straight news, a tragedy, anything with no joke to
lend — is not an ad and not a fit. If you've already spent a download slot
frame-sampling it to learn this, catalogue it `status: DO-NOT-SPLICE (<today>)` with a
one-line reason and log `taste-reject: <shortcode> <reason>`, so a later
scan won't re-spend a slot rediscovering it. It does NOT count as banked.

### 4. Download
Each candidate's `media_url` from the step-2 response is a signed CDN link
to the actual mp4 (verified 2026-07-17 — no yt-dlp, no cookies, no
scraping). The links are short-lived: download in the SAME run as the
query, never store a media_url for later.
`curl -s --max-time 120 -o "clips/<shortcode>.mp4" "<media_url>"`
then confirm with `file` that it's really an MP4 (an expired link returns
an error body, not video) — if the check fails, DELETE the junk file (the
guard-3 exception). A reel whose media_url is absent or fails is logged
(`download-miss: <shortcode> <reason>`) and skipped — never retried more
than once, never fatal. A reel with NO `media_url` (licensed audio) may be
fetched ONLY through `ig-fetch.sh` per guard 4, ≤ its daily cap, highest-
ranked first; anything past the cap is a `download-miss ... media withheld
(fetch cap)` and waits for a later scan.

### 4b. THE CLEAN-WINDOW GATE — a donor must have footage without text on it
**(Marcus, 2026-08-28. Applies to every clip banked as a DONOR.)**

*"The viral bank should be clips that do not have text in them. Or at least
there should be a part of the clips that have no text in them."*

A clip only earns a slot in `clips/` if a splice can actually be cut from it.
Nearly every reel on the feed carries the creator's own burned-in caption, and
a caption that sits across the middle of the frame makes the clip unusable as a
donor no matter how good the joke is — the 9:16 crop that clears the text either
destroys the action or upscales it into mush. **Check this BEFORE spending a
download slot, not at catalogue time.**

**⚠ THE GATE IS CONDITIONAL ON THE DONOR'S ROLE (Marcus, 2026-08-28, amending his own rule
the same day).** *"It's fine if the captions are inside the reel if the splice leads the joke."*
The no-text requirement was too broad. Which test applies depends on where the donor sits:

- **DONOR AS PAYOFF** (own footage sets up, the reel cuts INTO the borrowed clip to land the turn)
  → **the clean-window test below is REQUIRED.** The donor's caption would collide with our own
  card and read as a second, competing caption at the exact moment ours is supposed to land. This
  is the case that killed four candidates on 2026-08-28.
- **DONOR AS OPENER** (the borrowed clip is the FIRST frame and its caption IS the setup, then the
  reel cuts to the channel's own footage for the payoff) → **the clean-window test does NOT apply.**
  The caption is part of the borrowed asset and is doing the recognition work. Bank the clip whole,
  full-bleed, no crop, no upscale. Record `clean-window: n/a — OPENER-ONLY donor (caption is the
  setup)` and say so, so no architect later tries to cut it into a payoff beat.

A clip that fails the clean-window test may therefore still be banked **as an opener-only donor**.
Mark it as such rather than skipping it. A clip that passes is usable in both roles.

For a donor being banked for the PAYOFF role, it passes if it has EITHER:
- **a clean BAND** — a horizontal strip carrying no burned text, tall enough
  that a full-bleed 9:16 crop out of it reaches 1080x1920 at **≤2.6x upscale**; or
- **a clean STRETCH** — a run of at least ~1.5s of real action with no burned
  text on screen at all (captions that fade out, or appear late).

Fail both AND have no value as an opener, and the clip is **not downloaded**. Log
`download-skip: <shortcode> no clean window, no opener value (<measurement>)` and take the next
candidate. If it fails but the caption is a strong setup, bank it as OPENER-ONLY and log
`opener-only: <shortcode> (<what its caption sets up>)`. This is not a taste judgment and it is not negotiable by argument —
it is a measurement, and it is the cheapest measurement in the whole scan.

**This does NOT touch step 5b.** A reel whose FORMAT is the asset is still
captured as a `FORMAT ONLY, footage unusable` playbook entry with no clip file;
that path exists precisely for clips that cannot be donors.

*Why this rule exists.* On 2026-08-28 four separate donor candidates were killed
mid-build and not one of them died on taste: a burned caption straddled the
payoff (`DcPUWj1vU78`), a permanent broadcast scorebug covered every frame
(`DcVBZDiNrHF`, `DcTuLiwRLAT`), a subject was a dot at 576x720 under two caption
bands (`DcQ7__eRvNv`), and one clip turned out to have no motion in it at all
(`DcejaQYskRm`). The catalog recorded `pairs-with`, `the-beat` and
`joke-structure` for all of them and **nothing about whether they could be cut**,
so the architect rediscovered each failure by hand, one at a time, mid-build.

**⚠ MEASURE IT, AND THEN LOOK.** A row-scan for bright rows is the fast test and
it has two known false-negative classes, both found on 2026-08-28: **emoji are
graphics, not text rows** (a crop measured to clear a caption's text left the
emoji tops visible in frame), and **a caption that fades out defeats a
whole-clip test**. ARCHITECT-CORE §6.2 governs and applies verbatim: *"the
row-scan has false negatives and you must assume it does. The visual check on
the cropped beat is mandatory, never optional."*

`~/Claude Code/imabgold-ig/scratchpad/0828/donor_probe.py` is a working
implementation of the measurement (bright-AND-frozen pixels across sampled
frames, two-window to catch fades, plus a motion score). Its motion column is
reliable; its caption band is triage only. Treat it as a shortlister.

### 5. Catalogue — the architect-facing entry
You must actually look at each clip before writing its entry: frame-sample
with the imageio ffmpeg binary (e.g. 1 frame/sec to `frames/<shortcode>/`)
and read the frames. An entry written from the caption alone is a guess —
the architect will make a splice decision on your words, so they must
describe the actual footage. Then append to `catalog.md` (newest first,
below the header comment):

```
## <shortcode> — <one line: what literally happens in the clip>
- source: @handle | <permalink>          <- hashtag finds: `#hashtag | <permalink>` (no username on hashtag media)
- lane: <the watchlist lane tag of the source account>   <- hashtag finds: the lane the hashtag was queried under
- first-seen: <today> | status: FRESH
- stats-at-capture: <likes> likes / <comments> comments (<ratio>x account median)   <- hashtag finds: `(hashtag recent_media, no account baseline)` instead of a ratio
- joke-structure: <the mechanism, e.g. "hype setup, anticlimax payoff">   <- this line IS the entry's borrowable SHAPE — write it as the recognition trigger (what a scroller clocks in <1s), not a plot summary
- the-beat: <where the laugh lands + where to cut, e.g. "setup 0:00-0:03, cut on the turn at 0:03">   <- this line IS the entry's PAYOFF — name the turn plainly so an architect can cut on it, borrow it as an element, or replicate it (§6.1)
- audio-model: <diegetic (bakeable) | trending sound (add in-app) | flexible>
- pairs-with: <kinds of user moments this sets up, 1-2 concrete examples>
- clean-window: <where this clip has NO burned text, and what it costs to cut>   <- step 4b, MANDATORY on every donor entry. Give the text-free vertical band and the resulting 9:16 upscale, and/or the text-free time range. e.g. `band y0-770 of 1280 -> 432x768 crop, 2.5x upscale` or `caption fades at 0:06, 0:06-0:11 is fully clean, no crop needed`. If the clip carries no burned text at all, write `NONE — full frame clean`.
- file: clips/<shortcode>.mp4 (<duration>s)
```

`audio-model` (best-effort call from the footage/format): **diegetic
(bakeable)** = the clip carries its own sound that IS the beat (a voice, a
crowd, a sting, natural action) — fine to keep in the spliced MP4.
**trending sound (add in-app)** = the clip rides a licensed IG-library
track (lip-syncs, dances, trend edits) — NEVER bake that audio into the
delivered MP4: a business/creator account gets the upload muted or
reach-throttled for non-original copyrighted audio, AND selecting the
library sound is what earns the trending-audio distribution push. That
track must be picked by the human natively in the Instagram app / editor
when posting (the dailies deliver the MP4 to the phone for exactly this).
**flexible** = works either way. Rule of thumb the architect follows: one
audio bed per reel — either a trending library sound added in-app (duck or
mute any spliced clip's own audio under it) OR the splice's diegetic audio
is the point and no track is added. Rarely both.

Delete the `frames/<shortcode>/` directory after writing the entry (frames
are working files; clips and catalog are the durable assets).

### 5b. Format capture — when the FORMAT is the asset, not the footage
While frame-sampling in step 5, ask one extra question per candidate: **is
the viral asset the footage, or the format?** Format signals: a reusable
on-screen TEXT TEMPLATE ("Dear Instagram, please connect me with [X]"), a
trending-audio meme where the track + structure carry the joke, or a
structural gag (wipe-reveal, sound-impression gap) any account could
rebuild with its own footage. Three outcomes:
- **Footage is the asset** → catalog entry only (step 5, unchanged).
- **Format is the asset, footage is disposable/unusable** (ad-adjacent,
  identifiable stranger, etc.) → playbook entry ONLY, no clip banked; log
  `format-capture: <shortcode> (no clip banked)`. The download slot is
  already spent — capture the format value instead of discarding the find.
- **Both are strong** → catalog entry AND a playbook entry that
  cross-references the clip (`→ clips/ <shortcode>`).

A scan-written playbook entry matches the file's existing hand-seeded shape
(one voice, appended to the matching lane section, numbering continues from
the highest existing entry):

```
**N. <format name>** · audio: <diegetic (bakeable) | trending sound (add in-app) | flexible> · 🔥 LIVE (<today>) ·scan [· → clips/ <shortcode>]
<2 lines: the mechanism — what the text/audio/structure does, where the joke lives>
Splice: <how to rebuild it with the USER'S OWN footage as hero> (source: <permalink or @handle>)
```

The trailing **`·scan` token is the ownership marker** — it is what makes an
entry yours. A bare `🔥 LIVE (<date>)` WITHOUT `·scan` is a hand-seeded
entry that happens to carry a date (entry #13 does): NOT yours.

Rules:
- If the format is ALREADY in the playbook (same mechanism spiking again),
  refresh that entry's `🔥 LIVE` date instead of duplicating it — but only
  on an entry carrying `·scan`; a hand-seeded entry (no `·scan`, dated or
  not) is re-sighted in the log (`format-resight: <entry name>`) and left
  untouched.
- ≤2 NEW playbook entries per scan. The playbook must stay a tight read;
  when more than 2 candidates qualify, keep the strongest and log the rest.
- **Hand-seeded entries are Marcus's.** Anything without the `·scan` token
  is NEVER aged, edited, renumbered, or deleted by you — a dated stamp
  alone proves nothing. You own only what you wrote.
- Honest scope: this captures format value from candidates the scan already
  surfaced — the API cannot search by format/audio, so genuinely new
  formats still enter via Marcus's hand-seeding; 5b just stops the scan
  from throwing away format value it already paid a download for.
- Time box like steps 0/6c: past 08:20 → `format-skip: time`.

### 6. Freshness sweep
Any entry with `first-seen` older than 21 days and `status: FRESH` → edit
its status to `STALE (<today>)` — the date is what step 6b's 3-day delay
is measured from (every demotion status carries its date for that reason). Touch nothing else about it.

Retro ad sweep (same pass): any entry still `status: FRESH` whose own
catalog text fails the guard-7 ad filter gets `status: AD-REJECTED (<today>)`
(the status line IS the record of why it left the canon — record the demotion
now; a LATER scan prunes it, per 6b). Judge from the catalog text you already
have — no re-fetching captions, no extra API calls; re-frame-sample the
local clip only if genuinely ambiguous, and if the clip file is gone and
it's ambiguous, leave the status untouched. STALE and AD-REJECTED entries
are skipped (already out of the canon). Log `ad-reject-retro: <shortcode>`.

Playbook aging (same pass, entries carrying the `·scan` token ONLY — never
a hand-seeded one, even if dated, per step 5b): an entry whose
`🔥 LIVE (<date>) ·scan` is >30 days old with no re-sighting since →
downgrade the stamp to `~ FADING (<original date>) ·scan`. A
FADING entry >45 days past its original date → DELETE the entry outright
(playbook.md is git-tracked, history survives; formats need no tombstone —
there is no download slot to protect, nothing is ever re-downloaded for a
format). Renumber nothing — gaps in numbering are fine and cheaper than
renumbering entries architects may have referenced in staged notes. Log
`format-fade: <entry name>` / `format-prune: <entry name>`.

### 6b. Prune sweep — reclaim clip files, keep the dedup record (guard 3)
Keep the bank lean without ever risking a live spike OR re-downloading a
clip you already judged. Prune ONLY entries whose `status: STALE |
AD-REJECTED | DO-NOT-SPLICE (<date>)` carries a demotion date **≥ 3 days
old** — never a demotion you made this run. (Was "written by a PRIOR scan";
at daily cadence that became a 24h window, too short for a staged reel that
references the clip to air. An out-of-canon status with no date gets today's
date stamped on it this run and is considered next time.) The delay is
deliberate: a demoted entry stays fully visible, with its file, for at
least three days and several commits before collection.

For each such entry:
- DELETE its `clips/<shortcode>.mp4` file — the heavy asset that bloats the
  bank. If the file is already gone, fine.
- COMPRESS the catalog block to a one-line TOMBSTONE and KEEP it in
  `catalog.md`:
  `## <shortcode> — [PRUNED <status>] <one line: what it was> · <permalink> · first-seen <date>`
  Drop joke-structure / the-beat / pairs-with / audio-model / file — those
  only guided splicing a clip that no longer exists.
- Log `prune: <shortcode> <old-status>`.

The tombstone is the dedup key (guard 3): it is what stops a future scan
from re-spending a download slot on a clip already rejected — critical for
`DO-NOT-SPLICE`, where a clean-captioned but unusable clip (an awareness
piece, a tragedy) would otherwise re-qualify as a top candidate every scan
inside its 10-day window. Do NOT delete a tombstone while its post could
still re-qualify. A tombstone whose `first-seen` is >30 days old MAY be
removed outright (git keeps the history, and by then step 3's "posted within
the last 10 days" filter is a second net against re-download). NEVER prune a
`FRESH` entry. Count pruned entries in the close-out line.

### 6c. Trending-audio pool — the accumulating audio source (rewritten 2026-08-21)
Customer reel jobs (JOBS.md) and the account dailies have NO trend research
of their own; their audio pick comes from `audio.md`, which this step grows.
**`audio.md` is a POOL that ACCUMULATES, never a shortlist that resets.**
Until 2026-08-21 it was a full overwrite capped at 20, which meant the pool
could never be larger than one morning's search and every refresh threw
away tracks that were still live (the 08-20 refresh dropped 12 of 20 just
because that day's four roundups didn't list them). At 3-4 posts/day with
the dailies' last-5 variety rule, that pool ran dry in about three days.
Rules now:
- **ADD, don't replace.** WebSearch current IG trending audio (several
  targeted searches are fine — this step is where extra calls are spent)
  and append every REAL track you find that is not already in the file.
  Re-sighting an existing track updates its `confirmed:` date only.
- **No cap.** The target is >= 5x the weekly post count across the accounts
  that draw on it (Marcus, 2026-08-21: 3-4 posts/day on one account alone,
  so think 100+, not 20). Each scan should net at least +5 new tracks while
  the pool is under target; log `audio-added: N, audio-pool: M`.
- **Drop only on evidence.** A track leaves the file when its `confirmed:`
  date is >21 days old AND today's search still does not mention it, or
  when Marcus vetoes it (the veto list in the header is permanent — never
  re-add a vetoed track). Log `audio-dropped: "<title>" <reason>`. Never
  drop a track because a single list omitted it today.
- Entry format, one line each:
  `"<title>" — <artist> | shape: <deadpan-hold/escalation/comparison/quiet-confession/momentum> | lane-fit: <tech/general/family/any> | why: <one line> | start: <where> | confirmed: <date>`
  `shape:` is how the architect actually selects (the shape of the cut the
  track plays straight under); group the file by shape so a thin shape is
  visible at a glance.
- Inherited from the dailies' audio law (ROUTINE-CORE step 4): every entry
  is a REAL, currently-trending track found in the search — never invented,
  never unsourced; a pick is a title AND an artist. Account-agnostic:
  lane-fit and shape describe the track, not an account. No rights flags
  (Marcus's ruling 2026-08-15).
- Time box (scheduled runs): do not START 6c past 08:35 (`audio-skip:
  time`); at most 3 searches; and if you are still inside 6c at 08:45,
  write what you have and go to step 7 — the 09:00 daily reads audio.md
  and must never catch it mid-write.
- One-time migration (first daily scan after 2026-08-21): any entry lacking
  `confirmed:` is stamped with the file's last refresh date and given a
  best-fit `shape:`; the header comment is rewritten to describe the pool
  law (add-only, drop-on-evidence), replacing any "full overwrite" wording.
- Dedup on normalized title + artist (case/punctuation/"(feat. …)"
  stripped). Within each shape group order by `confirmed:` descending, so a
  consumer reading the top of a group gets the freshest.

### 7. Close out
Write `last-scan.txt`: first line `<today> — scanned N accounts + H
hashtags, M new clips banked, F formats captured, K entries went stale, P
entries pruned, A ads skipped, X misses`. Log the same line. Commit the
bank repo (`git -C ~/Claude\ Code/viral-bank add -A && git commit`) with
that summary as the message — catalog.md, watchlist.md, taste.md,
playbook.md and audio.md are tracked (audio.md grows every scan now); clips and logs are gitignored.

## Consumption law (for architects / daily routines — not the scan)

- `catalog.md` is read-only for you. Reading it is part of the trends step;
  whether to use a clip is decided ON THE RECORD: ARCHITECT-CORE §1's
  DONOR PASS walks the FRESH entries every run and names the top 3 with a
  rejection each. No-splice is legal only on top of that record (since
  2026-08-22; "no justification needed" is retired).
- If you splice (REACH mode): optimize for the most viral cut. The
  account's/user's own material must stay essential and load-bearing (pull
  it and the reel collapses — the reach is attributable to their footage,
  never a borrowed clip padded with disposable filler; no runtime minimum).
  Within that floor the banked clip MAY carry the comedic load
  and the payoff beat. State in your staged notes which clip you used
  (shortcode) so QA can verify provenance of every frame.
- FRESH entries are preferred; using a STALE entry requires one written
  line of justification in the staged notes. An `AD-REJECTED` entry is
  never used, no exceptions — it's promotional material. A `DO-NOT-SPLICE`
  entry is never used either: it's real (non-ad) footage with no comedic or
  splice mechanism, banked only as a record so a later scan won't re-spend a
  download slot rediscovering it.
- `taste.md` is architect-readable context (what each account's audience
  rewards, distilled from real insights) — read it alongside catalog.md
  in the trends step. Account routines read the whole file; CUSTOMER jobs
  read ONLY the `## universal` section (and `audio.md` for their audio
  pick) — account-audience knowledge never shapes a stranger's reel.
- QA brief addition when a splice is present (REACH mode): verify the
  account's/user's own material is essential and load-bearing (a reel where
  the borrowed clip is the whole thing and the user footage is disposable
  filler is a FAIL), and the clip came from `viral-bank/clips/` (not scraped
  ad hoc mid-run). The banked clip MAY carry the payoff beat — that is no
  longer a failure.

---

## OPEN GAPS FOR THE SCAN (recorded 2026-08-21, from @imabgold's first splice day)

Marcus's stated goal: **more audio and more banked clips, accepting more API
calls to get them.** These five findings are why, in priority order.
**ACTIONED 2026-08-21 (Marcus's call: keep it simple):** the scan now runs
DAILY instead of Mon+Thu, and step 6c makes `audio.md` an accumulating pool
with no cap. Findings 2-5 were NOT actioned as new sorting rules — more
cadence is the fix; revisit only if the daily bank still misses them.

### 1. AUDIO IS THE BINDING CONSTRAINT, and it is arithmetic, not taste

Marcus wants to move to **3-4 posts per day**. The variety rule blocks any track
in the last 5 ledger rows, and `audio.md` holds roughly 10-15 usable tracks once
the register rule removes female-pop. **At 4 posts/day the pool is exhausted in
about three days**, after which every pick is a repeat or a rule break.

This is already binding, twice over:
- 2026-08-21 needed **six distinct tracks in one session** and had to promote
  unspent BACKUPS to fill the slots.
- 2026-08-05 recorded it explicitly: *"audio.md is thin for QUIET DEADPAN shapes
  — 5 of its 10 entries were blocked by the last-5 rule and 3 by
  creator-account/commercial restrictions, leaving one real candidate."*

**The audio pool must scale with posting rate, not with scan cadence.** A pool
that supports 2 posts/week does not support 4 posts/day, and the ledger cannot
be relaxed to paper over it — the variety rule is what stops the account sounding
identical. Target the pool at >= 5x the weekly post count, and bank tracks BY
SHAPE (deadpan-hold, escalation, comparison, quiet-confession, momentum) since
that is how the architect actually selects.

### 2. THE BANK IS A COMEDY MONOCULTURE, and the org now has customers

All 34 FRESH entries are comedy: dogs, toddlers, robots, monkeys, sports fails.
That serves @imabgold and **failed completely for a paying customer**: for
@sahilchawla.md (physician, "credibility IS the product, never a comedy format
that makes him or a patient the butt of the joke") **not one usable donor exists
in the entire bank**. The only survivor was playbook #28, headlines-as-receipts,
which adds authority instead of spending it.

**The scan is banking for one account and serving at least three.** It needs
lanes for AUTHORITY/CREDIBILITY formats, not only comedy: receipts-and-headlines,
before/after with a verifiable claim, consumer-protection warnings, "here is what
this actually costs", process-transparency. Those are the shapes customer
channels can legally and reputationally use.

### 3. NAMED CLIP GAP: nothing pictures a CHAIN REACTION

No FRESH entry depicts *a small input causing a disproportionate cascade* —
one thing pulled and everything collapsing. A reel needing it was killed on
2026-08-21 for exactly this. It is @imabgold's single most repeatable true story
("I changed one thing and it moved everything") and the bank cannot picture it.
Nearest candidates were checked and rejected on inspection: `Dbi8hsFxMD9` (fall
obscured behind a stair rail), `DbTsR5LR5W3` (news-pegged, banned by brand.md).

### 4. THE SCAN MISSED THE HIGHEST-COMMENT FORMATS IN THE ORG

@rghoss1's engine — one held line, one continuous shot, text phrased as a demand
the viewer must answer — was found in a **hand-built client folder**, not by the
scan, despite reels at 16.1M and 8.2M views and **70,800 comments on one post
(1 per 4 likes)**. The scan watches 16 accounts + 12 hashtags and surfaced none
of it. Worth auditing what those 16 accounts actually are, and whether
comment-rate (not like-count) should be a ranking axis. Comments are now
@imabgold's graded criterion and the bank has almost no comment-engine formats.

### 5. PER-CUSTOMER TREND COVERAGE IS UNEVEN (Marcus, 2026-08-21)

- **@sahilchawla.md** builds his own library from his own **post scan**, so his
  account-level clip bank is self-feeding. **He has NO ig-pulse setup** — the
  pulse spike-radar is wired to the iPhone-app customer instead — so he has no
  account-specific trend monitoring at all.
- Any expansion has to account for per-customer scans running alongside the org
  scan, so the same clip is not fetched twice and the API budget is shared, not
  duplicated.

### CONSTRAINT ON ALL OF THE ABOVE

**More API calls is the sanctioned direction. Scale through the Graph API;
the ONLY cookie path is `ig-fetch.sh` (throwaway account, guard 4).**
Instagram warned Marcus's account for suspected automated behavior on 2026-08-20
after ~20 cookie-based yt-dlp pulls over two days. Media the API withholds goes
through `ig-fetch.sh` up to its daily cap or is recorded as withheld and
substituted; it is never fetched through his session. @imabgold and @bambi.map are the business; a
restriction ends the routines and the outreach engine.
