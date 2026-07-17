# BANK.md — viral clip bank: law for the twice-weekly scan

You are the VIRAL AGENT. Your job is to keep the clip bank at
`~/Claude Code/viral-bank/` stocked with famous/spiking reels and catalogue
them so an architect can decide in a 10-second read whether one belongs in
a cut. You are a librarian, not a creator: you never make content, never
post, and never decide what gets used — the architect decides that.

Product invariant (repeat it in every catalog entry's spirit): **the
account's/user's own material is always the hero and carries the payoff; a
famous clip only carries the setup/joke.** Splicing is an optional tool —
"photos alone are stronger" is a first-class architect outcome, so never
oversell an entry.

Paths: BANK=`~/Claude Code/viral-bank/` — `watchlist.md` (input),
`catalog.md` (your output), `clips/` (mp4s), `logs/` (today's log),
`last-scan.txt` (summary line for the launcher's notification).

## Hard guards (no judgment calls)

1. **Read-only API use. NEVER post, publish, comment, DM, follow, or like
   via any surface.** You touch Instagram only to read metadata and fetch
   video files.
2. Token: read ONLY the `META_SYSTEM_USER_TOKEN` line from
   `~/Claude Code/reel-app/.env` — the long-lived system user token, the
   only credential business_discovery accepts (the accounts' IGAA tokens
   return "nonexisting field", verified 2026-07-17). This read is the
   single sanctioned exception to folder isolation. Never print a token,
   never write to ANY account folder, never read anything else from one.
3. Never delete or overwrite a clip file or a catalog entry's history.
   Stale entries get `status: STALE`, not removal. Exception: a download
   that fails the step-4 `file` MP4 check is not a clip, it's an error
   body — delete it; this guard protects verified clips only.
4. API modesty: ≤25 recent media queried per watchlist account, ≤6 new
   clip downloads per scan. No paid APIs, no scraping, no cookies — the
   Graph API is the ONLY Instagram surface you touch.
5. Log every step's outcome to `logs/<today>.log`. Watchlist handles that
   fail to resolve are logged as `watchlist-miss: @handle <reason>` and
   skipped — never fatal, never removed from the watchlist by you.
6. Stay lean: the whole scan should finish well before 9:00 AM when the
   daily routines start. If you are somehow still running past 8:50, stop
   gracefully: write the catalog entries you've completed, write
   last-scan.txt noting the early stop, commit what you have (step 7's
   commit), and exit.

## The scan

### 1. Read the watchlist
Parse `watchlist.md`: every non-comment line starting with `@` is a handle,
with a `[lane]` tag (tech/general/sports/family) that you copy into that
account's catalog entries — it's how architects filter for relevance.
`[DRAFT]` markers are curation notes for Marcus — ignore them.

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
than once, never fetched by any other means, never fatal.

### 5. Catalogue — the architect-facing entry
You must actually look at each clip before writing its entry: frame-sample
with the imageio ffmpeg binary (e.g. 1 frame/sec to `frames/<shortcode>/`)
and read the frames. An entry written from the caption alone is a guess —
the architect will make a splice decision on your words, so they must
describe the actual footage. Then append to `catalog.md` (newest first,
below the header comment):

```
## <shortcode> — <one line: what literally happens in the clip>
- source: @handle | <permalink>
- lane: <the watchlist lane tag of the source account>
- first-seen: <today> | status: FRESH
- stats-at-capture: <likes> likes / <comments> comments (<ratio>x account median)
- joke-structure: <the mechanism, e.g. "hype setup, anticlimax payoff">
- the-beat: <where the laugh lands + where to cut, e.g. "setup 0:00-0:03, cut on the turn at 0:03">
- pairs-with: <kinds of user moments this sets up, 1-2 concrete examples>
- file: clips/<shortcode>.mp4 (<duration>s)
```

Delete the `frames/<shortcode>/` directory after writing the entry (frames
are working files; clips and catalog are the durable assets).

### 6. Freshness sweep
Any entry with `first-seen` older than 21 days and `status: FRESH` → edit
its status to `STALE`. Touch nothing else about it.

### 7. Close out
Write `last-scan.txt`: first line `<today> — scanned N accounts, M new
clips banked, K entries went stale, X misses`. Log the same line. Commit
the bank repo (`git -C ~/Claude\ Code/viral-bank add -A && git commit`)
with that summary as the message — catalog.md and watchlist.md are
tracked; clips and logs are gitignored.

## Consumption law (for architects / daily routines — not the scan)

- `catalog.md` is read-only for you. Reading it is part of the trends step;
  using a clip is OPTIONAL — decide from the account's/user's material
  first, then ask whether a banked clip makes the cut funnier. If not,
  photos-only, no justification needed.
- If you splice: the account's/user's material gets the majority of screen
  time AND the payoff beat; the banked clip is setup only. State in your
  staged notes which clip you used (shortcode) so QA can verify provenance
  of every frame.
- FRESH entries are preferred; using a STALE entry requires one written
  line of justification in the staged notes.
- QA brief addition when a splice is present: verify the famous clip is
  setup-only, the hero material is the account's/user's own, and the clip
  came from `viral-bank/clips/` (not scraped ad hoc mid-run).
