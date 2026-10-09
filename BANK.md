# BANK.md — viral clip bank: law for the DAILY scan (daily since 2026-08-21; was Mon+Thu)
**EXCLUSIVE MODE since 2026-09-17: donor-opener setups only. Read THE GATE before anything else.**

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
4. API modesty: ≤25 recent media queried per watchlist account, ≤12 new
   clip downloads per scan (raised from 6 to 12 by Marcus, 2026-08-29 — the
   watchlist reached 22 accounts and 6 slots no longer covered a day's real
   spikes; this cap governs GRAPH API downloads only, which are signed CDN
   links carrying no account risk, and it does NOT touch ig-fetch.sh's
   cookie budget below, which stays where it is). No paid APIs, no
   scraping, no cookies — the Graph API is the ONLY Instagram surface you
   touch (plus `ig-fetch.sh` and the read-only `read-saved.sh`, below).
   **COOKIE RULE (revised 2026-08-21, Marcus).** Cookie-driven fetching is
   allowed ONLY through `ig-routine-core/ig-fetch.sh`, which uses a DORMANT
   throwaway account in its own Chrome profile and enforces a daily cap,
   randomized human-pace spacing, and a stop-after-2-failures rule. Never
   call `yt-dlp` directly, never use a Chrome profile holding an imabgold /
   bambi / maxima session (the script refuses those by name), and never
   raise the caps to finish a bank faster — a bank that takes three days is
   the point. Use it only for clips whose `media_url` the API withholds, and
   (since 2026-09-17) to resolve a creator handle for step 2b's `[premise]`
   lane, ≤3 resolutions per scan inside the script's configured daily cap
   (`max_per_day` in `~/.config/ig-fetch/config.json` — 8 since Marcus confirmed
   it 2026-09-18; the "5" elsewhere in this guard is the 2026-08-21 value) — a gate-passing
   donor whose media is withheld (step 4) has first call on the budget,
   resolutions take what is left. Everything else comes from the Graph API.
   An exit 3 or 4 on EITHER use ends all ig-fetch use for the day. **If `ig-fetch.sh` exits 3
   (daily cap) or 4 (two failures), that is FINAL for today: log
   `download-miss: <shortcode> media withheld (fetch cap)`, substitute the
   next-ranked reel, never retry, never call yt-dlp yourself.** For a
   withheld clip that matters and cannot be fetched today, leave it for
   tomorrow's scan (its tombstone/miss line is the queue) or ask Marcus to
   save it by hand from the IG app.
   **CARVE-OUT (Marcus, 2026-09-24, for step 1b ONLY — widened the same evening
   to a headless read):** his private Saved collection may be read with HIS
   session in exactly one way: `ig-routine-core/read-saved.sh`, which renders the
   one collection page headlessly from a COPY of his Chrome profile's cookie jar,
   extracts shortcodes and handles from the grid, and exits. One run per day,
   page render only, no downloads on his session (downloads stay on the
   throwaway through ig-fetch.sh), no other URL, no scrolling past the grid, and
   never `yt-dlp` on his cookies. Any other use of an imabgold / bambi / maxima
   session stays banned as above. An interactive session on his request may
   also read the collection through the desktop app's browser pane.
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
   — for a `[premise]` or `[saved]` handle, since 2026-09-27 (Marcus: "can we
   use the throwaway to scan these if the API doesn't work? isn't that the
   rule?") — read through the throwaway instead of skipped:
   `ig-search.py profile <handle>` (same guards and 10/day cap as the tag
   pages; profile reads come out of the SAME budget, so reserve one per miss
   before the tag pages spend it). Log `watchlist-fallback: @handle via
   throwaway (<N> posts)`, then gate its recent reels exactly like a Graph
   read; withheld videos go through ig-fetch.sh as usual. If the throwaway
   also finds no such profile, log `handle-gone: @handle (not found on IG
   either)` and leave the line for Marcus — a renamed creator is his call
   to re-point. Old-lane `dormant` lines never get a fallback. The rest of
   the old rule stands:
   skipped — never fatal, never removed from the watchlist by you.
6. Stay lean: the whole scan should finish well before 9:00 AM when the
   daily routines start. (Launch moved 8:00 → 7:30 on 2026-08-29, with the
   Mac's pmset wake moved 7:50 → 7:20, to fund the 12-download cap; the
   8:50 stop and 9:00 deadline below are unchanged.) If you are somehow still running past 8:50, stop
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
   - **The standing set is FROZEN at daily cadence** (since 2026-08-21;
     10 premise tags since 2026-09-17): re-query the same set every scan and never swap one
     on your own judgment — a swap is a new tag charged for 7 days on a
     window ig-pulse also needs. Swaps are Marcus's call, noted in this
     file. A steering tag (step 2b) that would push `|used| + new` past
     30 is DROPPED and logged `steering-defer: #tag (quota)` — steering
     never outranks the hard stop.

## EXCLUSIVE MODE — the donor-opener format is the only thing you bank
**(Marcus, 2026-09-17. This overrides the lane spread everywhere below.)**

The bank feeds ONE format now: the **donor-opener template** behind every
hit @imabgold has ever had (`sexiest_said` 39k, `one_thing` 532k views /
22,778 shares, `midweek_reset` 43 shares in its first 10 hours). Its law
lives in `imabgold-ig/performance.md`, rules 90-93 plus their four
refinements; the donor half is reproduced as THE GATE below and is the only
part you need.

Why this file changed: **not one of the four donors behind those reels ever
came from this bank.** `@uldouz`, `@abb.davv`, `@thexcelguy` and the
shortcodes `DZsOX8fxFtc` / `DDz6Y0ZyTqe` appear nowhere in `catalog.md` —
Marcus hand-picked every one, while the scan banked 170 FRESH entries of
@pubity animal clips, sports moments and office skits that this format
cannot use. The bank was stocking a shelf nobody shopped from.

**A candidate that fails the gate is not banked, and there is no second
lane to fall back on.** A scan that banks ZERO clips because nothing passed
is a CORRECT scan: log it, write `last-scan.txt`, commit, stop. Do not
relax a test to fill a slot. Do not bank a general/sports/family clip
"while you are here". An empty day is the expected shape of this job until
the `[premise]` watchlist lane fills, and a thin bank of the right shape is
worth more than 170 entries of the wrong one.

What this costs, knowingly: @bambi.map and the CUSTOMER jobs live off the
FRESH entries already banked until those age out under step 6, which logs
`lane-dry:` when a lane empties so Marcus can see the cost accumulating —
never act on it yourself, and never reopen a lane to fix it.

## THE GATE — seven tests (numbered 1-8, test 5 retired 2026-09-27), all of them, on every candidate
**(the donor half of performance.md rules 90-93 and their refinements. Tests
1, 7 and 8 carry Marcus's 2026-09-17 wording, which goes further than the
file: test 1 is new (widened 2026-09-18), test 7 amends rule 93 (2026-09-24: whole-premise copies allowed), test 8
extends the 09-16 read.
Where this section and performance.md differ, this section governs the scan.)**

The donor is the OPENER: it is the reel's first frame, someone sets up a man
in a positive way, and the reel hard-cuts to Marcus's own footage as that man. **You
are hunting for a SETUP, never for a joke.** This inverts what this bank used
to look for, so read the tests before you read a caption.

1. **A girl talks straight to camera and states the premise about men.**
   Marcus's rule, restored 2026-09-18 evening after a one-day widening: the
   09-17 wording was "hot girl to the camera"; on 09-18 it was widened to "any
   speaker who sets up a man positively", the scan banked two man-to-camera
   donors on that (Galloway's "3 things women find attractive", a men's-glowup
   "4 things girls find attractive", 4.77M and 2.1M plays), and Marcus rejected
   both the same evening: "these donors suck, girl donors are proven to work."
   So: a woman speaking to camera, stating a positive premise about men —
   and she has to SAY it, audibly, clearly enough for us to caption (this is
   what the retired test 5 was really protecting). Not a
   man to camera, not a couple, not a text card over b-roll, not a podcast
   guest, not an aggregator's quote card. Both winners are exactly this, and
   her being the one who says it is part of why the tribe forwards it.
   **SHE MUST BE A REAL PERSON (Marcus, 2026-09-24): no AI avatar, no
   generated woman, ever.** `DYLF0zvTx80` (@lilybrooksmind) passed every
   test on the frames — podcast mic, lamp, freckles, hoops — and her bio
   reads "AI avatar sharing what works". A generated donor is disqualified
   before the other seven tests are read; his own Veo 3.1 opener
   (`ai_donor_test`, 09-23) floored at 429 views. Check three things on every
   candidate creator, and log which one caught it: (a) the `biography` and
   `name` from the business_discovery probe (step 2's curl now asks for
   them) for AI / avatar / virtual / generated / synthetic / "not a real
   person"; (b) the feed shape (a daily quote-clip cadence with the same
   framing and lighting every day is the avatar tell); (c) a generator
   watermark in the frames (Veo, Sora, Runway, HeyGen, Kling, Pika). Any
   one hit: `[NOT BANKED] tombstone (test 1: AI avatar)`, and the handle goes
   to the watchlist's Dropped list, not to `[premise]`.
2. **The premise is a POSITIVE superlative or desire about men** — "the
   sexiest thing a man can do", "men only want one thing", "what's the
   equivalent of flowers for you", "green flags", "how to know he's a
   keeper". REJECT every negative frame: red flags, the ick, signs he's
   cheating, what men lie about. Under a negative premise the payoff object
   becomes the thing WRONG with him, and the viewer who owns that object is
   the butt of the joke instead of the hero.
   **AUDIENCE FIT (Marcus, 2026-09-18, after the first sweep):** the man
   being set up must be one the viewer IS. The reach is 85% men 18-34 (38%
   are 18-24; per-reel audience tab, performance.md 09-16), global (India,
   Korea, Turkey, Iran), 95% strangers. So the premise has to describe a
   young man's desire, status or habit — what men want, the sexiest thing a
   man can do, green flags, flowers for men, what he's like when he's into
   you. REJECT premises anchored on an age or life stage the viewer has not
   reached: "older men", "grown men", "a real man vs a boy", husbands,
   fathers, providers, "a man over 30". `DdcKZ9fPDin` ("three things learned
   dating older men") passed every other test and was dropped on this one:
   a 22-year-old watching it is the boy she is comparing against.
   **Second-person sub-case (Marcus, 2026-09-24/25):** a girl to camera
   addressing the viewer directly ("bruh", "you") with an aspirational line
   whose hero is the man watching COUNTS, even though she never says "men".
   `Dao0ESOudKj` ("how do you think those fake motherfuckers are gonna feel
   when you pull up in a ___") was tombstoned on caption, reversed by Marcus,
   aired, and called "a donor we should definitely keep going". The slot in
   this family is usually an OBJECT the cut shows rather than a word the
   payoff says. Still reject a line with no blank at all ("let them hate",
   "just start") — motivation without a slot is a mood, not a setup.
3. **The man is the HERO of her sentence, not the problem.** Test 2 applied
   to sentences that only sound positive. `astra`'s donor ("things men say
   when they're 1000% lying") passed a casual read and failed this one: 12
   shares against `midweek_reset`'s 43 the same night.
4. **The premise carries a SLOT** — a claim plus its eliminations ("not
   money. not power.") leaving one blank that a single object fills. A
   premise with no blank has nothing to answer. This is the fastest test to
   run while skimming captions, so run it first.
5. **RETIRED 2026-09-27 (Marcus): "text on screen is not necessary because we
   can add that later, so we shouldn't have a rule that is against that."**
   On-screen text is never a reason to reject a donor, in either direction:
   a donor with no text is fine (we caption every donor ourselves, WORDCAPS
   house style), and a donor whose own card or captions carry the setup is
   fine too. The number is kept so old log lines still read; never cite
   "test 5" in a new rejection. What the old test was really protecting is
   now part of test 1: she has to SAY the premise, audibly and clearly
   enough to caption. A setup that lives only in the post's caption, or
   under music loud enough to bury her, fails test 1, not test 5.
6. **The setup runs 3s MINIMUM, 4-5s ideal, and is the WHOLE setup.**
   Winners 4.03s and 4.60s; floors 2.03s and 2.37s. Measure it off the
   frames in step 5 — never estimate it from the caption. A clip that cuts
   away before the premise finishes is the WRONG COPY of a right donor, which
   is test 7.
7. **The copy carries the WHOLE premise — original preferred, second-hand
   allowed with the chain recorded.** (AMENDED 2026-09-24, Marcus.) This test
   was written because both floor reels used @thexcelguy reposts that jump
   to an Excel screen at 2.0-2.4s, so there was no more of her left to use.
   That is a LENGTH failure in a sourcing costume, and test 6 already catches
   it. Measured 2026-09-24: @programmergrind's `DaWr4F9OH9q` (57.6k likes)
   opens on a borrowed woman clip that runs 0.00-4.03s COMPLETE — the same
   length as this account's two best donors (4.03s, 4.60s). So:
   - A copy that TRUNCATES the premise before it finishes is rejected: log
     `repost-skip: <shortcode> (truncated at <t>s, original wanted)` and treat
     the original creator as a handle lead per step 2b.
   - A second-hand copy that carries the premise WHOLE (test 6 passes on the
     copy itself) MAY be banked. The entry must record the chain: `creator:
     @<original if nameable>` and `copied-from: @<account we took it from>
     <shortcode>`. The reel's credit names where WE took it from (Marcus:
     "as long as we quote where we take it from").
   - The original is still preferred when both exist, because rule 92
     attaches the ORIGINAL account's audio; when only a copy is banked, the
     entry's `her-audio:` line must name which account's sound to attach in-app.
8. **The donor never says Claude, and never names an AI coding tool.**
   (performance.md's 09-16 read says "must NOT mention Claude"; the tool-name
   half is the 09-17 extension.) Claude arrives only in Marcus's line. `other_woman`'s donor says Claude at 1.8s and the
   reel sits in the account's ordinary band.

Two further properties are not pass/fail tests but MUST be recorded in the
entry, because the architect cuts on them: the setup has to address the same
person the payoff recognises (a premise aimed at women about a man — "why he
isn't texting YOU" — orphans both audiences, 975 views), and her audio has
to be her ORIGINAL sound, since rule 92 attaches it in-app rather than baking
it.

All seven pass (test 5 is retired) → bank it. One fails → do not spend the download slot. There
is no "close enough" here: a near-miss donor costs a full build and lands in
the 700-4,000 band, which is exactly what the last four non-hit reels did.

## THROWAWAY BROWSING — finding donors the way Marcus does (Marcus, 2026-09-18)
(The "Profile 1 is a hard stop" line below governs browsing sessions. It does not
cover `read-saved.sh`, which is the guard-4 carve-out and reads Profile 1's cookie
jar by design.)
Every donor behind the account's hits was found by scrolling, not by the API,
and the hashtag API is quota-blocked and popularity-blind. So the dormant
throwaway (@aureliusnuttus, Chrome "Profile 7", the same account ig-fetch.sh
uses) MAY browse Instagram's own search to FIND premise donors. This is a new
surface for that account, and volume is what earns warnings, so the limits
are the rule, not a guideline:
- **Profile check first, every session.** Before any instagram.com
  navigation, confirm the browser is Profile 7 and the signed-in handle is
  @aureliusnuttus (read it off the page). Any other profile — Default,
  Profile 1, Profile 6, anything signed into Marcus's Google accounts or an
  imabgold/bambi/maxima IG session — is a hard stop, same as ig-fetch.sh.
- **Caps per day:** ≤10 searches, ≤25 page loads total (search pages, reel
  pages, profile pages all count), 45-90s between navigations, no more than
  3 reel pages opened in a row without a search or profile page between
  them. Log every navigation as `throwaway-nav: <url path>`; the log is the
  counter, and the day's count is read from it before the first move.
- **Stop signals:** any "suspicious activity", "confirm it's you", challenge,
  captcha, or rate-limit page ends browsing for the day — log
  `throwaway-stop: <what the page said>`, do not retry, do not switch
  profiles. Downloads still go through ig-fetch.sh only (its own cap); a
  reel found by browsing is fetched by shortcode like any other.
- **Call it ONCE with every tag as its own argument:**
  `ig-search.py tag greenflagsinmen whatmenwant attractivemen …` — it paces
  and caps itself. Never build the list into one quoted string or a shell
  variable: on 2026-09-27 that sent ten tags as one name, got a 404, and cost
  the morning. Since that day the script refuses a malformed tag with exit 2
  BEFORE any request (no count, no failure), so exit 2 means fix the call,
  not stop browsing.
- **The tool is `ig-routine-core/ig-search.py`** (built 2026-09-18, same guard
  set as ig-fetch.sh, cap `search_max_per_day` in the ig-fetch config,
  default 10, state in `~/.config/ig-fetch/search-state.json`, log lines
  `SEARCH ...` in fetch.log). Two modes, measured the day it was built:
  `tag <name>` reads IG's own hashtag page (`tags/web_info`) and returns the
  RANKED top posts with plays, likes, handle and duration — this is the
  surface the Graph API never had, and it found both of the day's banked
  donors (4.77M and 2.1M plays) on the first five tags. `kw "<phrase>"`
  (fbsearch/top_serp) returned HTTP 400 and counts as a failure; do not
  spend the fail budget re-trying it until someone fixes the call.
  **Step 2b's Graph hashtag sweep is now SECONDARY:** run the throwaway tag
  pages first (they do not touch the 30-tag Graph window at all), and use
  the Graph sweep only for tags already charged. Tag pages that produced
  on 09-18: greenflags, attractivemen, greenflagsinmen, whatmenwant;
  boyfriendgoals was couple-content noise.
- **What to search:** premise phrases in the audience's words, not tags —
  "the sexiest thing a man can do", "men only want one thing", "green flags
  in a man", "what men want", "the most attractive thing a man can say",
  "flowers for men". Read the ranked reels grid: the shortcode from each
  href (path only) and the creator handle. Screen on the gate from the
  cover and caption; open a reel page only for a candidate that already
  passes tests 1/2/3/4/8 on what the grid shows.
- **Output:** a creator handle → `[premise]` lane (after the same
  business_discovery probe as step 2b; personal accounts are still
  unreadable, but a browsed find carries its handle, so it CAN be fetched
  and banked directly — record `source: @handle (browsed)` in the entry).
- Never like, follow, comment, save or DM from the throwaway. Reading only.

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

**DAILY READ CUT (Marcus, 2026-09-25).** Probe ONLY watchlist lines that start
with `@` (the `[premise]` lane plus the surviving `[saved]` handles, 18 on the
day of the cut). `dormant …` and `dead …` prose lines are never probed, never
counted in "scanned N accounts", never re-added by you. Why: on 09-25 the scan
probed 43 accounts, 40 of which cannot bank, hit the 08:50 guard at 09:10 with
64 rejects, and skipped the tag pages that are the only surface that has found
donors. **Order of the morning is now: step 1 → throwaway tag pages (THROWAWAY
BROWSING, ≤10) → step 2 probes → step 3.** The tag pages run before the probes
so the time box can never starve them again.
**Daily target: 2 gate-passing girl-to-camera donors.** A zero day with rejects
is legal; a day that skipped the tag pages is not.

**AMENDED 2026-09-17 (exclusive mode).** One lane produces donors now:
`[premise]`. Every other lane — tech, general, sports, family — is
**format-capture only**: you may still read those accounts and write a step-5b
playbook entry from what you see, but you may NOT spend a download slot on
them and you may NOT write a catalog entry for them. The paragraph above
still describes how lanes are *meant* to work and is kept for the day Marcus
reopens them; until he does, a customer-segment gap is a log note and nothing
more. The `[premise]` lane starts EMPTY by design — step 2b fills it.
A `[premise]` line marked unprobed (added by an interactive bank) that returns HTTP 400 on its
first probe is moved by the scan to `## [saved] lane` marked `(unreadable)` — the one move the
scan may make on a `[premise]` line, because a line that can never be read is a daily miss.
**`[saved]` (added 2026-09-24, Marcus): read like `[premise]`.** A `[saved]` handle is a creator
Marcus saved on Instagram (step 1b). Its reels run THE GATE like any candidate; a gate-passer
MAY spend a download slot and gets a catalog entry written as `lane: premise` (never
`lane: saved`), and the creator's watchlist line moves to `[premise]` (readable handles
only; an HTTP-400 creator stays `[saved]` marked `(unreadable)`). That is the one
exception to "only `[premise]` produces donors". A `[saved]` reel that fails is a
tombstone, or a step 5b format entry when the format is the asset.

### 1b. Saved inbox — what Marcus saved on Instagram (added 2026-09-24, Marcus)

**2026-09-25 (Marcus, after Instagram flagged "automated behavior" on @imabgold): read-saved.sh STAYS ON, it is read-only (one headless page load of his Saved collection per day, capped by saved-state.json). Everything else that touches Instagram as a logged-in user goes through the THROWAWAY (Profile 7, ig-fetch.sh): every clip download, every reel page read. NEVER use Profile 1 cookies for yt-dlp or any download, and never click, type, like, follow or DM as @imabgold.**
Marcus's rule: **whenever he saves a reel, that creator joins the scan, and the
reel itself is a candidate.** Every donor behind the account's hits was found by
him scrolling, not by the hashtag API (see THROWAWAY BROWSING), and on 2026-09-24
his collection held 12 reels, 12/12 unknown to catalog.md and 11/11 creators
absent from watchlist.md — including @thegroundedmen, whose clip he had shipped
two days earlier. This step runs BEFORE 2b, because it is pre-filtered by taste.

**The scan never reads Saved or any `instagram.com/imabgold/*` page ITSELF;
the one and only read is running `read-saved.sh` in (a) below.** Not with curl,
not "just to check", not with any cookie. The Graph API, `ig-fetch.sh` and
`read-saved.sh` (guard 4) are your only Instagram surfaces.

Source of truth: `saved-inbox.md` in the bank directory. Lines under `## inbox`
are `<shortcode> @<handle> <url>`, one per reel. Who fills it, in this order:
(a) **`ig-routine-core/read-saved.sh`** — run it FIRST in this step, once. It
renders Marcus's collection page headlessly from a COPY of his Chrome cookie jar (Marcus's
allowance, 2026-09-24 evening — guard 4 carve-out ABOVE, in Hard guards), takes only the
shortcodes and handles off the rendered grid, and appends the new ones to
`## inbox`. It never downloads, never scrolls past the grid, never runs twice
a day, and refuses any other URL. Exit 0 = read. Exit 2 = config problem,
3 = Chrome or cookie-jar problem, 4 = nothing rendered, 5 = the page did not
identify his session (logged out or a challenge): log `saved-read: exit N
<reason>`, put the same line in `last-scan.txt` so Marcus sees it, and go on
with whatever is already in the inbox — never improvise a read another way,
and never re-run it the same day. (b) Marcus pastes links. (c) An interactive session on his
request. A line with a bare URL and no handle is still valid: derive the
shortcode from the URL; the handle comes back from `ig-fetch.sh`'s info-json
when the reel is fetched in (3). Empty inbox = log `saved-inbox: empty` and go on.

For each `## inbox` line:
1. **Dedup first.** If the shortcode is already a catalog.md header, or already
   under `## processed`, move the line to `## processed` as `<date> ... — dup`
   and stop. Nothing is respent on it.
2. **Resolve the creator** with ONE business_discovery call (step 2's curl).
   HTTP 400 = personal account: log `saved-unreadable: @<handle>`; the reel can
   still be gated (3), but the handle is listed with `(unreadable)` and must
   never be appended to `[premise]`, only to `[saved]`.
3. **Run THE GATE**, all seven live tests, test 7 as amended. **The candidate may be INSIDE the
   saved reel**: a creator who opens on a borrowed woman-to-camera clip (e.g.
   @programmergrind, whose hits open on a ~4s borrowed opener before his own body) is a
   DONOR SOURCE — gate the borrowed opener itself, and if it passes, bank it as a
   second-hand copy with `copied-from: @<his handle> <shortcode>` and `creator:` when
   nameable (Marcus, 2026-09-24). **The account a COPY came from stays under `[saved]`**
   (a man to camera fails test 1 himself); only a NAMED `creator:` goes to `[premise]`.
   A donor-source account gets at most ONE fetch per scan, on its single best-ranked new reel. Test 6 needs
   frames: saved reels are usually older than the 25 media business_discovery
   returns, so `media_url` is normally absent and the only route is
   `ig-fetch.sh` (guard 4). An inbox reel that passes tests 1-4, 7 and 8 on its
   caption has FIRST call on the day's fetch budget, ahead of step 2b's
   resolutions (it ties with a withheld gate-passing donor from step 4; take the
   inbox one first, Marcus chose it). If ig-fetch exits 3 or 4 before it is
   fetched, leave its line in `## inbox`, log `download-miss: <shortcode> saved
   inbox (fetch cap)`, and it gets first call tomorrow. Step 3's 10-day recency
   and 2x-median filters do NOT apply here: Marcus's save is the spike signal.
4. **Then the watchlist.** A pass: catalog entry per step 5 (`lane: premise`,
   `status: FRESH`), and the creator goes under `[premise]` — readable handles
   only; an HTTP-400 creator whose reel passes stays under `[saved]` marked
   `(unreadable)`, because `[premise]` lines carry a serve rate the probe must
   supply. A fail: `[NOT BANKED]` tombstone naming the failing test, and the
   creator goes under `## [saved] lane` if on no lane yet — one line, the date,
   the shortcode, what they do. A fail whose FORMAT is the asset (e.g. a split-
   screen structure) also gets a step 5b playbook entry.
5. Move the line to `## processed` with the date and the verdict
   (`BANKED` / `tombstone (test N)` / `dup`).

Also read `## re-measure` in saved-inbox.md: each line names a catalog entry
banked by Marcus's ruling without frames. Fetch it (budget permitting), measure
test 6 (setup length) off the frames, and EDIT THE EXISTING BLOCK IN PLACE — never
append a second block with the same header (catalog.md must have one block per
shortcode). Passes: `status: FRESH`. Under 3s or inaudible: `status:
DO-NOT-SPLICE (<date>) — re-measure failed test N`, file pruned per 6b. Then move
the line to `## processed` as `re-measured`.

Log `saved-inbox: N read, N banked, N tombstoned, N dup, N handles added`.

Saving is NOT approving: the gate still runs (the first inbox held NVIDIA and a
Porsche reel). Marcus's sequencing is add-first, cut-later: nothing else in the
scan changes because of this step; after a week compare its leads to 2b's.

### 2. Pull each account's recent reels
For each handle, one `business_discovery` call (the tested read surface):

```
curl -sg "https://graph.facebook.com/v21.0/17841480076308621?fields=business_discovery.username(<HANDLE>){name,biography,followers_count,media.limit(25){id,media_type,media_product_type,permalink,caption,like_count,comments_count,timestamp,media_url}}&access_token=<TOKEN>"
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
2. Fill remaining slots from the STANDING PREMISE SET — same tags every
   scan (guard 8: reuse is free, novelty burns the window):
   **#greenflags, #datingadvice, #relationshipadvice, #datingcoach,
   #streetinterview, #publicinterview, #girltalk, #husbandgoals,
   #boyfriendgoals, #whatmenwant** (10 tags, seeded 2026-09-17, replacing
   the tech/family/meme set that exclusive mode retired).
   Audience-fit note 2026-09-18: #husbandgoals is off-audience (18-34 men,
   mostly unmarried) and #datingcoach skews to over-30 advice; both are
   candidates for a swap to a younger tag (#rizz, #datinginyour20s,
   #situationship) — Marcus's call, not yours.
   These ten are a HYPOTHESIS about where women-to-camera positive-premise
   reels live, not a measured set — nothing verifies a tag without charging
   it for 7 days. Kill rule: a premise tag that yields ZERO gate-passing
   candidates across 7 consecutive scans is reported in the log as
   `tag-barren: #tag (7 scans, 0 gate passes)` and swapped by MARCUS, not by
   you. Two slots of the 12-per-scan ceiling stay free for steering; if more
   than two steering tags arrive, LEAVE OUT premise tags from the bottom of
   the list for that scan so the per-scan count stays ≤12 — that is the
   per-scan cap, and skipping a query there costs nothing.
   **MEASURED 2026-09-18: the computed window is a FLOOR, not the truth.** At a
   computed 18/30 the API accepted #greenflags and #datingadvice and refused
   the third new tag with code 18 / subcode 2207034 ("Hashtag search limit
   exceeded, retry new hashtag in a week"). Instagram counts something the
   logs do not see. So: query the premise list IN ORDER, and on the first code
   18 stop charging new tags for the scan — a refused search is logged
   `quota-correction: #tag REJECTED (code 18) — NOT charged` right under its
   `hashtag-query` line, so the window arithmetic never counts it. Re-try the
   refused tags in order every scan; they enter as the window frees.
   Transition note: the retired set (#instantregret #fail #claudecode
   #vibecoding #techtok #programmerhumor #familytravel #toddlertravel
   #parentsofinstagram #toddlermom #dadlife #memes) stays charged against the
   rolling 30 until 2026-09-24, so the window runs 28/30 until then and 18/30
   after (#claudecode and #vibecoding never expire — ig-pulse holds them
   active). Guard 8's precedence is unchanged: a steering tag that would push
   |used| + new past 30 is DROPPED and logged `steering-defer`. Skipping a
   premise tag never helps THIS cap: once charged, a tag stays charged for 7
   days whether you query it or not. (It does help the ≤12-per-scan ceiling
   above — the two caps are different things.)
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

**A HASHTAG FIND IS A HANDLE LEAD, NOT A DONOR (2026-09-17).** Hashtag media
is privacy-stripped: it carries a permalink but NO username (verified
2026-07-17), and this format cannot use a donor whose creator you cannot
name — rule 92 attaches her original audio in-app and rule 93 sends you to
her ORIGINAL when the copy you found cuts short. So a hashtag find is never
downloaded into `clips/` and never gets a catalog entry. The procedure:
  1. **Screen on the caption and cover frame with gate tests 1, 2, 3, 4
     and 8 only** — and spend a fetch slot ONLY when the caption QUOTES her
     spoken setup or the cover shows a card that is the setup. A hashtag, a
     comment count, or "read the caption" is not a premise: 09-18's four
     caption-screened leads all failed on frames, and the week's fetch budget
     went the same way (1 banked in 7 scans). Tests 6 and 7 need frames and her own account; they
     are run later, on the `business_discovery` read of her profile. (THE
     GATE is defined above "The scan", before this step, so you have read it.)
  2. **Dedup before spending a request.** Skip the lead if its shortcode
     appears in a `premise-handle:` or `premise-unresolved:` line in the last
     10 days of `logs/`, or if you can already tell the creator is on the
     `[premise]` lane. The reel stays in `recent_media` for days; the cookie
     budget must not be re-spent on it.
  3. Resolve the creator with `ig-fetch.sh <shortcode> logs/premise-probe/<shortcode>.mp4`
     (guard 4; ≤3 per scan; the script writes the handle to
     `<dest>.uploader` and a `UPLOADER` line in `~/.config/ig-fetch/fetch.log`).
     The probe is a SCRATCH download, never `clips/`: read the handle, then
     delete the mp4 and its `.uploader`. An exit 3 or 4 ends ALL ig-fetch use
     for the day — log every remaining lead `premise-unresolved: <shortcode>
     (#<tag>, fetch cap)` and move on, never retry.
  4. **Probe the handle with one `business_discovery` call BEFORE writing
     it anywhere.** Most personal accounts return HTTP 400 (watchlist.md
     records cormacbuilds/viralhog/caters_news failing exactly this way). On
     400: log `premise-unreadable: @<handle> (not a business/creator
     account)` and stop — the handle is not appended. On success, count the
     reels serving `media_url` out of 25.
  5. Append the handle to `watchlist.md` under `## [premise] lane` in the
     file's line shape, with today's date, the shortcode that led you there,
     and the serve rate; log `premise-handle: @<handle> (via #<tag>,
     <shortcode>, <N>/25 serving)`.
From the next scan on, that creator is read through `business_discovery`
like any watchlist account: handles, full media, back catalogue, no cookie
budget — and THAT read is where tests 6-7 run and where clips get banked.
**This is the whole point of the hashtag sweep — it builds the `[premise]`
lane, it does not fill `clips/`.** A lead that passes screening but cannot
be resolved today is logged `premise-unresolved: <shortcode> (#<tag>)` and
left for tomorrow.

### 3. Rank for spikes
**`[premise]` LANE EXCEPTION (Marcus, 2026-09-27): no spike bar.** On
`[premise]`-lane accounts, every reel posted in the last 10 days is a
candidate regardless of its ratio, and goes straight to THE GATE on caption +
cover. The best setup on a creator's feed is often not her spike
(@xel.official's "you are gonna succeed" was her #2; the 2x bar skipped
donor-shaped posts on three lane accounts the week of 09-21). Rank lane
candidates by gate fit, then by ratio. This exception covers ONLY the
donor-opener format on the `[premise]` lane; every other account keeps the 2x
bar below, unchanged.

Per account: engagement = like_count + comments_count; compute the account's
median engagement across its fetched reels. A **candidate** is a reel posted
within the last 10 days with engagement ≥ 2× that account's median (a spike
relative to the account's own baseline, so mega-accounts don't drown small
ones). Rank all candidates across all accounts by their ratio
(engagement ÷ account median). Take the top candidates that are NOT already
in `catalog.md` (match by permalink/shortcode), up to the 12-download cap.

Degenerate baselines: if an account has fewer than 5 kept reels or a median
engagement of 0, log `rank-skip: @handle (thin/zero baseline)` and produce
NO candidates from it — a ratio against a thin or zero median is not a
spike signal, and `inf`/`NaN` must never reach the catalog.

Hashtag candidates (step 2b) have no account baseline and — since
2026-09-17 — **never enter the download pool at all.** Rank them among
themselves by raw `like_count` only to decide the ORDER in which step 2b
resolves handle leads (≤3 per scan). No hashtag find gets a clip file or a
catalog entry; the retired `(hashtag recent_media, no account baseline)`
stats line exists only on entries older than 2026-09-18.

**Ad gate first (guard 7, BOTH pools):** before any taste judgment, drop
every candidate whose caption reads promotional — the watchlist pool too,
not just hashtags (the 2026-07-17 morning scan banked watchlist ads;
that's the regression this line closes). The taste gate below selects
only among survivors and can NEVER reinstate an ad, however well it
"fits".

**THE GATE, before spending downloads (2026-09-17 — this replaces the taste
gate, which selected for joke mechanism and is the reason the bank filled
with clips this format cannot use).** Run the ad gate first as above, then
run all seven live tests from THE GATE on every surviving candidate, reading the
caption and the cover frame. Only gate-passers may be downloaded, and the
12-slot cap is a ceiling, never a target — if two candidates pass, you
download two.

**Gate fit outranks the engagement ratio.** The ratio decides order among
gate-passers and nothing else: a 2.1x candidate that passes all seven beats a
9x candidate that fails one, every time. Log the choice as
`gate-pick: <shortcode> (<ratio>x) over <shortcode> (<ratio>x): <which test
the higher-ranked one failed>`. `taste.md` is still read for context and
still written by step 0, but it can no longer promote a candidate the gate
rejected — on this account taste.md's own universal bullet says the
recognition lives in a premise the feed is already arguing about, which IS
the gate.

A candidate that fails on a test you cannot judge from the caption and cover
alone (test 6 usually needs frames) may have a slot spent on it: if it
then fails, catalogue it `status: DO-NOT-SPLICE (<today>)` with the failing
test named, and log `gate-reject: <shortcode> test <N> (<reason>)`. It does
NOT count as banked, and the tombstone stops a later scan re-spending the
slot.

A candidate that clears the ad gate but has NO comedic/splice mechanism —
a sincere talking-head, straight news, a tragedy, anything with no joke to
lend — is not an ad and not a fit. If you've already spent a download slot
frame-sampling it to learn this, catalogue it `status: DO-NOT-SPLICE (<today>)` with a
one-line reason and log `taste-reject: <shortcode> <reason>`, so a later
scan won't re-spend a slot rediscovering it. It does NOT count as banked.

**INVERTED 2026-09-17:** under exclusive mode a sincere talking-head is no
longer an automatic reject — a woman stating a positive premise straight to
camera IS the asset, and she is not telling a joke. What is now rejected is
the thing this paragraph used to protect: a clip whose value is its own joke.
The donor supplies the SETUP; the joke is Marcus's line. If a candidate is
funny on its own and has no premise with a slot, it fails test 4.

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

**SIMPLIFIED 2026-09-17 (exclusive mode): every donor you bank is an OPENER,
so the clean-window test never applies to it.** The whole gate is built
around a donor that opens the reel and whose on-screen setup is doing the
recognition work, and that is the exact case the OPENER branch
above exempts. Her burned captions are not a defect to crop around, they are
the asset. Bank the clip whole, full-bleed, no crop, no upscale, and write
`clean-window: n/a — OPENER donor (her setup card IS the hook)`.

Do NOT run the row-scan, do not spend time on band measurements, and never
reject a gate-passing donor for carrying text. The one measurement that
replaces it is test 6: **time the setup off the frames** and record it in the
new `setup-length:` field. That number is the single best predictor the
account has (4.03s and 4.60s won; 2.03s and 2.37s floored), and it is now the
cheapest measurement in the scan.

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
- source: @handle | <permalink>          <- always a watchlist handle since 2026-09-18 (hashtag finds are handle leads, never entries)
- lane: premise   <- the only lane that produces entries since 2026-09-18
- first-seen: <today> | status: FRESH
- stats-at-capture: <likes> likes / <comments> comments (<ratio>x account median)
- joke-structure: n/a — opener donor   <- since 2026-09-18 a donor carries a SETUP, not a joke (gate test 4). Never invent a mechanism to fill this line; `premise:` and `slot:` carry the entry.
- the-beat: cut at <N.N>s, the frame her premise finishes on   <- the only cut point an opener donor has; it is the `setup-length:` timestamp, not a laugh
- audio-model: <original sound (attach in-app, NEVER bake — rule 92) | trending sound (add in-app) — she rides a licensed track, her voice cannot be attached, flag for the architect>   <- must agree with `her-audio:` below; "diegetic (bakeable)" is never valid on an opener donor
- her-audio: <original sound — attachable in-app | licensed/trending track — rule 92 cannot attach it, note it and let the architect decide>
- pairs-with: <kinds of user moments this sets up, 1-2 concrete examples>
- premise: <her claim, quoted as she says it>   <- gate test 2. Quote it, never paraphrase: the architect matches a payoff object against her exact words.
- slot: <the blank her premise leaves + 1-2 payoff objects that would fill it>   <- gate test 4. e.g. `"not money, not power" -> the one thing men want: a Claude 20x Max plan / tokens resetting midweek`
- setup-length: <seconds, measured off the frames> (<does she finish the premise? yes/cuts at N s>)   <- gate test 6, MANDATORY. Under 3s the entry should not exist; 4-5s is the winning band.
- hero-test: <one line: is the man the hero of her sentence, or the problem?>   <- gate test 3. Say which, and why, in the architect's words.
- addresses: <who her setup talks to> / recognises: <who the payoff would flatter>   <- these must be the same person; if they differ, say so plainly, it is the `texting` failure (975 views).
- original: <yes — creator's own upload | COPY — creator: @<original if nameable>, copied-from: @<account we took it from> <shortcode>>   <- gate test 7 as amended 2026-09-24: a whole-premise copy is bankable; the chain is what the architect credits.
- clean-window: n/a — OPENER donor (her setup card IS the hook)   <- fixed value since 2026-09-18; no row-scan, no band measurement. The older gloss below applies only to pre-09-18 entries: Give the text-free vertical band and the resulting 9:16 upscale, and/or the text-free time range. e.g. `band y0-770 of 1280 -> 432x768 crop, 2.5x upscale` or `caption fades at 0:06, 0:06-0:11 is fully clean, no crop needed`. If the clip carries no burned text at all, write `NONE — full frame clean`.
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
**Since 2026-09-17 the old lanes (tech/general/sports/family) never get a
download, so for them this step runs WITHOUT frames: judge the format from
the caption, the cover frame and the permalink alone, and write the playbook
entry with no clip and no `→ clips/` reference.** The ≤2-per-scan cap and the
`·scan` ownership rules below apply unchanged. For `[premise]` candidates the
step runs as written, while frame-sampling.
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
After demoting, count FRESH entries per lane. A lane at zero that had FRESH
entries yesterday is logged `lane-dry: <lane>, 0 FRESH under 21d` (this is
where EXCLUSIVE MODE's cost line gets written; nowhere else owns it).
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
  `"<title>" — <artist> | shape: <deadpan-hold/escalation/comparison/quiet-confession/momentum> | lane-fit: <tech/general/family/any> | why: <one line> | start: <where> | url: <optional> | confirmed: <date>`
- **`url:` = the IG audio page (Marcus 2026-09-02, so the app's link works).**
  For every track you ADD, spend one extra site-scoped search
  (`"<title>" <artist>` with allowed domain instagram.com) and write
  `url: https://www.instagram.com/reels/audio/<id>/` ONLY when a result's
  URL has that shape AND its title names this exact track (a search for one
  song also returns that artist's other audio pages — the title match is the
  guard). Strip the slug and any `?hl=` from the URL. Original sounds
  rarely index: leave `url:` absent, never guess an id. Re-confirms keep the
  existing `url:` untouched. Time box unchanged; if the budget is gone, add
  the track without a url and let a later scan fill it.
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
entries pruned, A ads skipped, X misses, G gate rejects, R premise handles
added, S saved-inbox lines read / B banked from it`; then append any `saved-read: exit N <reason>`
line from step 1b as line 2, never overwrite it. G and R were added 2026-09-17, S and B on 2026-09-24, and are the real health of this
scan (a literal example: `2026-09-18 — scanned 22 accounts + 10 hashtags, 0
new clips banked, 1 formats captured, 3 entries went stale, 0 entries
pruned, 14 ads skipped, 2 misses, 6 gate rejects, 2 premise handles added`). **Zero banked with a non-zero gate-reject count is a healthy
day, not a failure — say so in the line so the morning notification does not
read as a broken scan.** Log the same line. Commit the
bank repo (`git -C ~/Claude\ Code/viral-bank add -A && git commit`) with
that summary as the message — catalog.md, watchlist.md, taste.md,
playbook.md and audio.md are tracked (audio.md grows every scan now); clips and logs are gitignored.

## Consumption law (for architects / daily routines — not the scan)

- **Entries dated 2026-09-18 onward are OPENER donors and nothing else.** They
  are somebody's setup, not a joke to insert: the reel opens on her, full-bleed
  and uncropped, her original audio attached in-app (never baked), and hard-cuts
  to the account's own footage for the payoff. Read `premise:` and `slot:`
  first — the pick is "which of my payoff objects fills her blank", not "is this
  clip funny". Entries dated before 2026-09-18 are the old mixed bank and follow
  the paragraphs below unchanged.
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
the ONLY cookie path is `ig-fetch.sh` (plus the read-only `read-saved.sh`, guard 4 carve-out) (throwaway account, guard 4).**
Instagram warned Marcus's account for suspected automated behavior on 2026-08-20
after ~20 cookie-based yt-dlp pulls over two days. Media the API withholds goes
through `ig-fetch.sh` up to its daily cap or is recorded as withheld and
substituted; it is never fetched through his session. @imabgold and @bambi.map are the business; a
restriction ends the routines and the outreach engine.
