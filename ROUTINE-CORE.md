# ROUTINE-CORE.md — structural law for EVERY IG daily routine

You are an autonomous headless session running a daily Instagram content
routine. Marcus is NOT watching — there are no questions, only rules. This
file is the STRUCTURE shared by all accounts. The account's own ROUTINE file
(the one that sent you here) supplies the CONTENT rules — mission, success
criteria, privacy/face rules, formats, budgets, material lanes — and names
its Photos album, iCloud folder, and ledgers. The shared architect + craft
law lives in `ARCHITECT-CORE.md` (this folder) — steps 4-5 send you there;
it binds this run. Read all of them before acting. Where they conflict, the
ACCOUNT file wins.

## Universal hard guards (every account, no judgment calls)

1. **NEVER publish via API.** No --publish, no --go, no media_publish. Output
   is a STAGED draft; Marcus posts manually in-app (that's also how the post
   gets trending audio).
2. Mandatory fresh-eyes QA agent review — no PASS, no staging. A reviewer is
   a NEW independent agent with zero context on how the piece was cut. If QA
   fails twice, stop and leave a note in the log + notification; a missed day
   is better than a bad post.
   **The QA brief must state the provenance gate: "this reel was cut today
   from raw material — verify that."** Hand the reviewer the source-cut table
   and tell it to FAIL a reel that looks pre-made (baked-in captions it can't
   trace to today's cuts, a single unbroken clip, an edit style that isn't the
   account's). A reviewer only checks what it's handed: on 2026-07-16 an
   independent Opus reviewer returned SHIP on a video the run hadn't cut at
   all, because the brief only asked "is this a good reel?" — it was. Never
   let a PASS on craft launder a failure of provenance.
   **The brief must also state the cohesion gate: FAIL a reel with a beat whose
   source clip breaks visual/tonal continuity with the rest (a foreign
   location, lighting, or time-of-day dropped into an otherwise-continuous
   montage), even when that beat is individually clean, provenance-clean, and
   privacy-safe.** (2026-07-21: costa-eatout passed a privacy/provenance-only
   brief with a night-dinner beat spliced into a daytime pool montage; the
   reviewer had no cohesion criterion, so an out-of-place beat shipped.)
   A reel MAY legitimately contain a banked viral clip (step 4 /
   ARCHITECT-CORE §1): when a splice is DECLARED in the staged notes, QA applies the
   splice addendum (clip really from `viral-bank/clips/`, the account's own
   material is essential/load-bearing — not disposable filler; the clip
   MAY carry the payoff) — and still FAILs if that doesn't hold. An UNDECLARED foreign clip remains a
   provenance failure; a splice claim never launders a pre-made reel.
   **The brief must ALSO state, unconditionally (splice or not): "verify the
   notes carry a DONOR PASS record — 3 `catalog.md` shortcodes that resolve
   to FRESH entries, each with a quoted `pairs-with` line, a beat, and a
   named rejection; missing = FIX-FIRST" (ARCHITECT-CORE §1, 2026-08-22).**
   This line is what makes `Splice: NONE` checkable; the DECLARED-splice
   addendum above adds nothing when the answer is NONE, which is exactly the
   case the donor pass exists for.
   **The brief must also hand the reviewer the ACCOUNT file's content hard
   guards (its ROUTINE.md / brand.md) and FAIL any violation** — a reviewer
   only checks what it's handed, so a guard that lives only in the account
   file never fires unless it's in the brief (2026-07-22: imabgold added a
   flash-reveal guard to its ROUTINE.md; documenting it there does nothing
   until the QA brief carries it).
   **And when the reel reproduces a viral-bank playbook format, the brief
   must hand the reviewer the verbatim playbook entry and FAIL if the
   on-screen joke deviates from that format's mechanism** — a "clever" or
   meta rewrite that concedes or inverts the format's premise is a FAIL, not
   a pass (2026-07-22: imabgold's nightpool_aislop took playbook #12, the
   "made by a REAL human" flex, and shipped "an AI cut this one too" as the
   middle beat; the reviewer had only a concept paraphrase, not the entry,
   so the broken joke passed). Fidelity is authored at the architect step
   (ARCHITECT-CORE §1 playbook fidelity); QA is the backstop.
3. Do not delete anything from the Photos library. Never repost old content.
4. Never touch another account's folder. Structural fixes belong in
   `~/Claude Code/ig-routine-core/` — note them in the log for Marcus; do not
   edit core files mid-run.
5. Never print or commit secrets (.env, tokens). A performance file produced
   by a generator script is never hand-edited — but whether the account uses
   a generator or a hand-maintained table is defined in the ACCOUNT file's
   config; follow its stated method.
6. Log every step's outcome to today's file in `routine/logs/`.
7. **You are a one-shot headless process: when your final message ends, the
   process exits and anything still running in the background dies with it.**
   Never launch a long task (Photos export, iCloud original download, render,
   upload) in the background and end the turn expecting to be notified when it
   completes — no notification can ever arrive (2026-07-18: a bambi run
   backgrounded a 4-clip Photos export that was waiting on iCloud downloads,
   ended its turn with "the task will notify", and exited 0 with no reel, no
   retry, no alert). Long waits run in the FOREGROUND: poll in a Bash loop
   (`for i in {1..N}; do <check> && break; sleep 30; done`), splitting across
   successive foreground calls if one would exceed a tool timeout. Your final
   message comes only after every step is done, or after a declared stop
   (guard 2 QA double-fail, step 3/3.5 stop, no-reel day) has been logged AND
   `routine/last-run.txt` stamped per step 6.

## Resume discipline (retried runs)

If your prompt says an earlier attempt failed partway: before EACH step,
check its completed state (today's log + the files that step writes) and skip
what's already done. Never duplicate a followers.log row, a Photos export, a
paid render, or a staged import. Paid generation gets a mechanical gate, not
a vibe check: before ANY paid render on a retried run, list the drafts/frames
folders and the render ledger for today's slug — frames already on disk are
paid for and get reused, and re-rendering them is spending the budget twice.

## Daily sequence (mechanics; the account file fills in the content)

### 1. Gather material
**Do NOT read the Photos library directly — this session has no Full Disk
Access.** The launcher already dumped `routine/photos-manifest.tsv` (videos
added since the last run: UUID, filename, duration, created) and previews at
`routine/previews/<UUID>.jpeg`.
- **Before planning ANY export, read `routine/photos-export-health.txt`**
  (written by the launcher's 25s probe). `OK` = the export lane is open.
  `STALLED` = Photos is in its third state (app-level queries answer,
  media-item queries hang until the -1712 timeout — typical right after wake
  while iCloud sync/library churn settles): do NOT attempt exports this run,
  don't burn the timebox re-verifying; go straight to on-disk footage or the
  generation lane, and mark wanted-but-unexported candidates in the inventory
  ("NOT exported (Photos stalled <date>)") so the next open run grabs them.
  Missing file = launcher predates the probe; behave as before.
- **Timebox ~10 min.** Judge from preview images; AppleScript-export (that IS
  authorized, when health is OK) only the 2-3 clips that actually fit today's
  direction, into `footage/`. Never bulk-export or frame-strip every new video.
  Run exports under a kill-guard; if the guard fires (export AppleEvent hung),
  run `killall Photos` afterward and log it — a killed AppleEvent otherwise
  leaves Photos wedged for every later AppleEvent and the next account's run
  (see the staging rule in step 6), then fall back down the material ladder.
- Ignore staged imports (`reel_*.mp4`, screen recordings already used) and
  clips that belong to another account's lanes. EXCEPTION (Marcus,
  2026-07-27): a NEW, unused screen recording is real material for an
  account whose brand.md explicitly allows staged readable screens — treat
  it like any fresh clip, subject to that account's sweep.
- An empty manifest is not a blocker; use the account's other material lanes.
- Respect the account's used-material ledger: never re-cut a used segment,
  never touch ranges marked BURNED.

**The material ladder — climb it in order; "exhausted" is only true at the
bottom** (Marcus, 2026-07-16: "if there is no footage the fallback is to go
back further in my photos catalogue to find something or generate it on nano
banana"). Empty fresh manifest is rung 1 of 3, not a verdict:
1. **Fresh manifest** (`routine/photos-manifest.tsv` + previews) — timeboxed
   scout above.
2. **The archive** — `routine/photos-archive.tsv` lists EVERY video in the
   catalogue (uuid, filename, duration, created, place), dumped by the
   launcher because this session has no FDA to go digging itself.
   **`routine/photos-labels.tsv` is how you SEARCH it** (`<uuid>\t<labels>`):
   Photos' own scene tags — "High Chair", "Restaurant", "Baby", "Meal",
   "Brunch", "Stroller" — the same index the Photos app searches. Grep it for
   the concept, join to the archive on uuid for date/place/duration. This is
   the difference between a searchable catalogue and 4k rows of IMG_9128.MOV:
   on 2026-07-16 the run declared exhaustion while the library held 47 videos
   Photos had already tagged "High Chair". Labels are a strong hint, not
   truth — they get you to ~20 candidates; frames decide.
   Then AppleScript-export the 2-3 best (export is authorized) and
   frame-sample with ffmpeg to judge — there are no previews for archive rows,
   so judging means actually looking at frames, never a filename or a label.
   Old footage is not stale: it has never been cut, and the ledger only burns
   SEGMENTS, not clips. Check the ledger before cutting, as always.
   **`routine/photos-albums.tsv` is Marcus's OWN filing** (`<album>\t<uuid>\t
   <filename>\t<dur>\t<created>`) — album names like "Pool tings" and
   "Grinding with a family" are deliberate human curation and outrank any ML
   label as a hint. Grep it BEFORE declaring that material for a format "does
   not exist": on 2026-07-28 the run passed on two proven night-desk formats
   for lack of footage while an album of exactly that sat in the library,
   invisible because only labels were searchable (added 2026-07-28, Marcus's
   call).
3. **Generation** — the account's generation lane (e.g. nano banana), inside
   its stated budget cap. Nothing in the catalogue fits, or what fits fails
   the privacy rules, is exactly what this rung is for.

Only after all three rungs come up empty is "material exhausted" a true
statement, and only then may you declare the no-reel day (step 5). Reporting
exhaustion at rung 1 is a false report.

### 2. Verify the leaderboard
- Pull Graph API insights (per the account file's method), refresh its
  performance file.
- Append today's follower count to `routine/followers.log` (`date,count`) —
  skip if today's row already exists.
- Score the most recent post against the ACCOUNT's success criteria:
  PASS/MISS per metric + one written line WHY it likely missed (hook? format?
  caption? audio?). That line feeds today's concept choice.
- If the account's scorecards hold 8+ SPLICE and 8+ NON-SPLICE rows at 24h+
  reads, run the ARCHITECT-CORE §6 UNPROVEN #1 comparison (comments + shares
  per reel, last 8 per side) and record the verdict in the performance file.
  Below that count, write nothing — the claim stays UNPROVEN.
- If new data contradicts a "what works" rule, update it per the account
  file's convention.

### 3. Un-posted draft check
If the most recent staged draft (Photos favorite "…, post this one") was
never posted, do NOT stack a second draft. Send the reminder notification,
stamp `routine/last-run.txt` (step 6 rule), and stop after step 2.

**"Posted" is a CONCEPT match, not a file match.** Marcus posts through the
IG app (often finalizing in the Edits app), which re-encodes and re-exports
the clip — the staged file itself will NEVER appear in the Graph API media
list, and his re-export may land in Photos under a new name. The draft counts
as POSTED if any post since staging carries the draft's hook / on-screen text
/ caption, even with trims or small edits (this exact miss stopped the
imabgold 07-14 run: the posted reel had the staged draft's text verbatim and
was still ruled "unposted"). When it matches: mark it posted — un-favorite
and rename the Photos favorite to "<concept> POSTED <date>" — and continue to
step 4. Stop only when NO recent post resembles the draft's concept; if it's
genuinely ambiguous, say so in the notification and continue (a duplicate
draft Marcus can ignore beats a silently skipped day).

**Abandonment timeout (Marcus, 2026-07-27).** Before stopping, count the
consecutive prior runs that ended in THIS step-3 stop on the SAME draft
(read the recent `routine/logs/` files — every stop is logged per guard 6).
If this run would be the THIRD consecutive stop-day on that draft, do not
stop: declare the draft ABANDONED instead. Append a dated line to the
account's topic ledger — abandoned after N stop-days, never posted, NOT
spent as a posted concept, do not re-stage this cut — say it LOUDLY in the
notification ("<slug> abandoned unposted after N days; cutting fresh
today"), un-favorite/rename any Photos favorite for it (best-effort, normal
staging rules), and proceed to steps 4-6 as a normal creating day. An
abandoned draft is never graded as a post. The counter resets whenever a
stop-day's draft differs from the previous stop-day's, and a draft Marcus
kills or posts mid-week clears it entirely. (Born of 07-24→07-27: four
runs correctly refused to stack while fresh material sat uncut and the
leaderboard re-measured a decayed post for six days.)

### 3.5 Skip-creation flag (one-shot)
If `routine/skip-creation.txt` exists, Marcus has already handled the next
post himself (e.g. scheduled a staged draft in-app) and today needs NO new
draft. Run steps 1-3 as normal first — measurement never skips — then STOP:
no trends, no creation, no staging. Delete the flag file (it applies to
exactly one run), say what was skipped and why (quote the file's note) in
the log and the notification, and stamp `routine/last-run.txt` (step 6 rule).

### 4. Load the trend intelligence (the viral agent already did the scouting)

You do NOT research trends in this run. Finding this week's viral formats,
clips, and audio is the **viral agent's** job, on its own scan cadence. Your
job is to READ what it banked and decide with it.

**The bank-reading law, the REACH-mode consumption law, and the splice rules
now live in `~/Claude Code/ig-routine-core/ARCHITECT-CORE.md` §1 — read that
file NOW (it is shared architect law for every channel; craft lessons land
there once instead of drifting across three copies).** Routine-specific
notes on top of it: full REACH text is in `BANK.md`; filling a bank gap is
the viral agent's job next scan, never this run's.

**Narration-led exception (voice-first content).** If today's material is
talking-to-camera / voice-first where the account's OWN spoken words carry
the content (not montage-over-music), treat it as narration-led: transcribe
with mlx_whisper, keep the voice in the render, order beats to the spoken
arc, and produce WORD-SYNCED captions per `WORDCAPS.md` (this repo) — the
tested one-word-at-a-time treatment. Default account reels stay montage +
trending-audio + line captions; use this only for genuine voice-first
footage (none generated yet for these accounts, but expected).

**Audio pick — prefer the bank, one narrow search allowed.** Pick from
`viral-bank/audio.md` first. Because audio trends decay fast and must be
accurate at post time, you MAY run a SINGLE targeted WebSearch to confirm a
candidate is still trending this week or to fill a gap the bank misses. This is
the only search left in the daily run and it is AUDIO-ONLY, never format or
concept research. **A pick is a title and an artist.** "Pick an up-arrow-flagged
warm acoustic track from the Trending tab" is NOT a pick — it is the job handed
back to Marcus at the exact moment he is trying to post (his correction,
2026-07-14). The staged doc must carry a single named track, one line on why it
fits THIS cut, and where to start it. Rules:
- It must be a real, currently-trending track — never invent a title, and never
  name a track you cannot source.
- **Variety rule: it must NOT appear in the last 5 rows of
  `routine/audio-used.md`** (create the ledger if missing).
- Append the named pick to that ledger when you stage — the ledger is what
  makes the variety rule enforceable, so an unnamed pick corrupts it.
- The up-arrow flag is a bonus to mention, not a substitute for choosing. If
  nothing usable surfaces, say so explicitly in the notification and name the
  closest fit anyway — Marcus can overrule a named track in two seconds; he
  cannot overrule a shrug.

### 5. Decide the concept (the Architect step), then create

**The weighing method (three inputs: current meta / material + proven lanes
/ standing brief) is ARCHITECT-CORE.md §2 — apply it here.** For a routine
run the three inputs are: step 4's bank read; today's fresh footage (step 1)
+ performance.md proven lanes; and `routine/next-concept.md` if it exists.
performance.md's rules (rule-10 fatigue, the hard guards, the caption/saves
law) are the rear-view CONSTRAINTS §2 warns about — check the finished
concept against them, never build from them alone.

**`routine/next-concept.md` mechanics (routine-specific):** Marcus's
requested subject is an INPUT with real weight — NOT an override by default.
If the current meta or fresh footage makes a clearly stronger reel, take
that and state in the notes why you set the brief aside. **HARD override
opt-in:** if the brief's FIRST line begins with `HARD:` (case-sensitive),
Marcus means it as binding — build that subject and skip the weighing;
every craft/QA/privacy rule still applies. Either way, after successful
staging move it to `routine/used-concepts/<date>-<slug>.md` so it is
consumed exactly once.

**You must CUT a new reel. Every single day. There is no other output.**
Staging a video you did not cut today is not a deliverable — it is a NULL
result wearing a deliverable's clothes (Marcus, 2026-07-16, after a run
renamed his own unposted Edits-app export "travel-tips v1, post this one"
and called the day complete). Specifically banned, no exceptions:
- Staging any pre-made/finished video as-is — an Edits-app export, a clip
  Marcus cut himself, an old draft, anything already carrying baked-in
  captions. Marcus's own footage is RAW MATERIAL to cut from, never a
  finished reel to hand back to him.
- Re-staging, re-titling, or lightly re-encoding a previously staged draft.
- Any output where the day's work was choosing and renaming rather than
  cutting.
A reel is new when today's run selected the beats, made the cuts, and
rendered the caption system. If you can't honestly write "why this concept"
and an exact source-cut table for beats YOU cut, you have no reel.

**When material is exhausted, DECLARE IT — never improvise a substitute.**
Exhausted means you climbed all three rungs of the step-1 ladder (fresh
manifest -> archive -> generation) and came up empty — not that the fresh
window was thin. If it IS truly empty, the correct output is a clean no-reel day: log it,
notification says exhausted + names the ONE recording that unblocks tomorrow,
stamp `routine/last-run.txt` (step 6 rule), stop. Do NOT go looking for something reel-shaped to stage instead. A missed
day is a known cost Marcus accepts (see guard 2); a recycled reel is worse
than nothing because it burns a ledger row, spends an audio pick, and lies to
the leaderboard — the next run then "learns" from a post that never happened.
The pull to produce something is exactly the pressure this rule exists to
overrule.

- **Check `routine/next-concept.md` FIRST.** If it exists, that is Marcus's
  requested subject for today — build it (it overrides free concept choice;
  every craft/QA/privacy rule still applies). After successful staging, move
  it to `routine/used-concepts/<date>-<slug>.md` so it runs exactly once.
- Otherwise: concept from the account's performance file (proven lanes +
  yesterday's MISS line + the trend check), deduped against the account's
  topic ledger.
- Then the full `/ig-reel <account>` pipeline: fact-check, cut, privacy gate,
  fresh-eyes QA. Claims must match the pixels they sit on (an overlay saying
  "mapped" over an empty-state UI is a FAIL — Marcus, 2026-07-12).
- **FORMAT-FIRST IS THE DEFAULT (Marcus, 2026-08-21 — "the viral bank always
  should be the first"). The reel is BUILT ON a 🔥 LIVE `playbook.md` entry or
  a banked `catalog.md` clip.** An original concept is the EXCEPTION, not a
  co-equal option. To ship one, the notes must name **every** live entry that
  fits today's footage and state why the original beats each; QA treats an
  unjustified pass as **FIX-FIRST**. If genuinely nothing live fits the
  material, that is a **stop-and-say to Marcus**, not a licence to invent.

  *Why this rule exists:* the old wording here read "whether it was USED or
  consciously PASSED (and why)", which made PASSED a legal outcome. @imabgold
  then shipped **nine consecutive aired reels with no format at all**
  (2026-08-10 to 08-20) while its engagement fell to zero — 0 comments and 0
  shares across three straight posts, followed by a reach collapse from ~1,700
  to ~200 that four separate distribution hypotheses failed to explain. The two
  reels immediately before that streak, both built on playbook #26, still hold
  every engagement record that account has. See imabgold `performance.md`
  rule 72.

- **Deliverables:** FINAL.mp4 + caption + audio pick + notes file. The notes
  "why this concept" MUST name: which LIVE playbook format / banked clip the
  reel is BUILT ON, or the full pass justification above; the **DONOR PASS**
  record (ARCHITECT-CORE §1: top 3 `catalog.md` shortcodes, each with its
  `pairs-with` line quoted and the beat it was matched to, each unused one
  rejected by one of the four §1 names — `Splice: NONE` without it is
  FIX-FIRST); and how the account's own footage carries the reel — alongside
  the exact source cuts and the success-criteria bet. This makes the decision auditable and lets the next
  scorecard grade FORMAT FIT, not just theme fatigue. **The scorecard's first
  row is FORMAT** — the entry used, or PASSED plus the justification — so a
  format-free reel is visible in the grade instead of buried in a run record.
  **The second row is SPLICE** — the donor shortcode used, or NONE — so the
  rolling splice ledger (ARCHITECT-CORE §6 UNPROVEN #1) fills itself from
  the scorecard. Account files that list scorecard rows carry this row in
  second position.

### 6. Stage + notify + close the loop
- **Never copy anything to iCloud Drive yourself** — this session has no
  iCloud TCC permission; the attempt hangs on a prompt nobody can click
  (killed the imabgold 07-13 run). Instead write into `routine/icloud-outbox/`
  (create it) and let the launcher move it to iCloud Drive's account folder
  after you exit — it moves EVERY file in that folder, running as Marcus, who
  has the access this session lacks. Put TWO things there:
  1. The finished reel MP4 — copy it into the outbox, **date-stamped** as
     `<YYYY-MM-DD> <concept>_FINAL.mp4` (same date prefix as the doc below). The
     date matters: the phone imports the NEWEST `.mp4`, so on a day that
     produces no new reel (footage exhausted, QA double-fail, crash before this
     step) an undated name could leave yesterday's already-posted clip as the
     "newest" one and trigger a re-post — the date makes staleness detectable.
     iCloud is the DEFAULT delivery path: it syncs to the phone, where a
     Shortcuts automation drops the newest MP4 into Photos for posting (Marcus,
     2026-07-17). An account file MAY opt out of MP4-in-iCloud (precedence rule
     up top) — then skip this and rely on Photos staging only.
  2. ONE combined document named `<YYYY-MM-DD> <Concept> - caption + audio.txt`:
     the full caption, then an AUDIO section naming ONE track — "<title>" —
     <artist> — plus why it fits this cut and where to start it (step 4: a pick
     is a title and an artist, never a description of how to go find one).
- Photos staging (Mac album) is now **best-effort only and must NEVER block** —
  iCloud→phone (above) is the real delivery. **Before sending ANY staging
  AppleEvent, run the attended-session check:**
  `ioreg -n Root -d1 -a | plutil -extract IOConsoleLocked raw -`
  — if it prints `true` (screen locked = nobody can answer a TCC prompt) or
  errors, SKIP staging entirely: log
  `photos-staging skipped: console locked, no AppleEvent sent` and move on.
  Do NOT use an attempt-with-kill-guard as the permission probe: a Photos
  AppleEvent killed mid-TCC-prompt leaves Photos WEDGED and unresponsive for
  the NEXT account's run (2026-07-22: imabgold's killed 09:29 staging attempt
  wedged Photos; bambi's 09:30 health probe then STALLED and lost its whole
  export lane). If the check prints `false` (someone is at the Mac to answer
  a prompt), stage as before: import the FINAL into the account's album,
  favorite it, name it "<concept> vN, post this one", un-favorite + rename
  the previous one (use variables theNew/theOld, never `it`), still under a
  kill-guard — and if that guard ever fires anyway, run `killall Photos`
  afterward and log it, so a wedged Photos is reset rather than left broken
  for the next account's run.
- Append to the account's ledgers (used material/topics, audio-used).
- If the account folder is a git repo: commit the ledgers/captions/learning
  files the account file lists (never drafts/media/secrets) and push;
  on rejection `git pull --rebase` then push.
- Write `routine/last-run.txt` — LOCAL-time ISO timestamp
  (`date +%Y-%m-%dT%H:%M:%S`, NEVER `date -u`; the launcher parses it as
  local time for the manifest window and the ran-today skip).
  Format contract: OVERWRITE the file (`>`, never `>>`) with exactly ONE
  bare timestamp line — no notes, no reason text; the launcher parses line 1
  as a timestamp and anything else silently breaks the manifest window.
  Ordering contract: this stamp is the LAST write of the entire run, after
  every deliverable and ledger — it is the launcher's proof of completion,
  so stamping early (then continuing to work) turns a later crash back into
  the silent no-op this rule exists to catch.
  **This stamp is mandatory on EVERY deliberate end of run**, not just full
  staging: a declared no-reel day, the step-3 un-posted-draft stop, the 3.5
  skip-creation stop, and a guard-2 QA double-fail all stamp it before the
  final message. It means "today's run reached its intended end". The
  launcher treats exit-without-today's-stamp as a crashed run — it retries
  the session and, if still unstamped, fires the FAILED notification — so a
  missing stamp on a legitimate stop causes a false alarm and a duplicate
  attempt.
- macOS notification (osascript `display notification`): one line = concept +
  audio pick, e.g. "Staged: <hook>. Audio: <track>. Photos → <album>."
