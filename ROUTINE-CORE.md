# ROUTINE-CORE.md — structural law for EVERY IG daily routine

You are an autonomous headless session running a daily Instagram content
routine. Marcus is NOT watching — there are no questions, only rules. This
file is the STRUCTURE shared by all accounts. The account's own ROUTINE file
(the one that sent you here) supplies the CONTENT rules — mission, success
criteria, privacy/face rules, formats, budgets, material lanes — and names
its Photos album, iCloud folder, and ledgers. Read both before acting. Where
they conflict, the ACCOUNT file wins.

## Universal hard guards (every account, no judgment calls)

1. **NEVER publish via API.** No --publish, no --go, no media_publish. Output
   is a STAGED draft; Marcus posts manually in-app (that's also how the post
   gets trending audio).
2. Mandatory fresh-eyes QA agent review — no PASS, no staging. A reviewer is
   a NEW independent agent with zero context on how the piece was cut. If QA
   fails twice, stop and leave a note in the log + notification; a missed day
   is better than a bad post.
3. Do not delete anything from the Photos library. Never repost old content.
4. Never touch another account's folder. Structural fixes belong in
   `~/Claude Code/ig-routine-core/` — note them in the log for Marcus; do not
   edit core files mid-run.
5. Never print or commit secrets (.env, tokens). A performance file produced
   by a generator script is never hand-edited — but whether the account uses
   a generator or a hand-maintained table is defined in the ACCOUNT file's
   config; follow its stated method.
6. Log every step's outcome to today's file in `routine/logs/`.

## Resume discipline (retried runs)

If your prompt says an earlier attempt failed partway: before EACH step,
check its completed state (today's log + the files that step writes) and skip
what's already done. Never duplicate a followers.log row, a Photos export, a
paid render, or a staged import.

## Daily sequence (mechanics; the account file fills in the content)

### 1. Gather material
**Do NOT read the Photos library directly — this session has no Full Disk
Access.** The launcher already dumped `routine/photos-manifest.tsv` (videos
added since the last run: UUID, filename, duration, created) and previews at
`routine/previews/<UUID>.jpeg`.
- **Timebox ~10 min.** Judge from preview images; AppleScript-export (that IS
  authorized) only the 2-3 clips that actually fit today's direction, into
  `footage/`. Never bulk-export or frame-strip every new video.
- Ignore staged imports (`reel_*.mp4`, screen recordings already used) and
  clips that belong to another account's lanes.
- An empty manifest is not a blocker; use the account's other material lanes.
- Respect the account's used-material ledger: never re-cut a used segment,
  never touch ranges marked BURNED.

### 2. Verify the leaderboard
- Pull Graph API insights (per the account file's method), refresh its
  performance file.
- Append today's follower count to `routine/followers.log` (`date,count`) —
  skip if today's row already exists.
- Score the most recent post against the ACCOUNT's success criteria:
  PASS/MISS per metric + one written line WHY it likely missed (hook? format?
  caption? audio?). That line feeds today's concept choice.
- If new data contradicts a "what works" rule, update it per the account
  file's convention.

### 3. Un-posted draft check
If the most recent staged draft (Photos favorite "…, post this one") was
never posted, do NOT stack a second draft. Send the reminder notification and
stop after step 2.

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

### 3.5 Skip-creation flag (one-shot)
If `routine/skip-creation.txt` exists, Marcus has already handled the next
post himself (e.g. scheduled a staged draft in-app) and today needs NO new
draft. Run steps 1-3 as normal first — measurement never skips — then STOP:
no trends, no creation, no staging. Delete the flag file (it applies to
exactly one run), and say what was skipped and why (quote the file's note) in
the log and the notification.

### 4. Trends + trending audio
WebSearch current IG reel trends + this week's trending audio for the
account's niche. Note 1-2 usable trend formats.

**Name ONE track. A pick is a title and an artist.** "Pick an up-arrow-flagged
warm acoustic track from the Trending tab" is NOT a pick — it is the job handed
back to Marcus at the exact moment he is trying to post (his correction,
2026-07-14). The staged doc must carry a single named track, one line on why it
fits THIS cut, and where to start it. Rules:
- It must be a real, currently-trending track you found in the search — never
  invent a title, and never name a track you cannot source.
- **Variety rule: it must NOT appear in the last 5 rows of
  `routine/audio-used.md`** (create the ledger if missing).
- Append the named pick to that ledger when you stage — the ledger is what
  makes the variety rule enforceable, so an unnamed pick corrupts it.
- The up-arrow flag is a bonus to mention, not a substitute for choosing. If
  the search genuinely surfaces nothing usable, say so explicitly in the
  notification and name the closest fit anyway — Marcus can overrule a named
  track in two seconds; he cannot overrule a shrug.

### 5. Create
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
- Deliverables: FINAL.mp4 + caption + audio pick + notes file ("why this
  concept", exact source cuts, the success-criteria bet).

### 6. Stage + notify + close the loop
- **Never copy anything to iCloud Drive yourself** — this session has no
  iCloud TCC permission; the attempt hangs on a prompt nobody can click
  (killed the imabgold 07-13 run). Instead write ONE combined document into
  `routine/icloud-outbox/` (create it), named
  `<YYYY-MM-DD> <Concept> - caption + audio.txt`: the full caption, then an
  AUDIO section naming ONE track — "<title>" — <artist> — plus why it fits this
  cut and where to start it (step 4: a pick is a title and an artist, never a
  description of how to go find one). **No
  MP4 in iCloud — the reel lives in Photos only** (Marcus, 2026-07-13). The
  launcher moves the doc to iCloud Drive's account folder after you exit.
- Photos staging (AppleScript is authorized): import the FINAL into the
  account's album, favorite it, name it "<concept> vN, post this one";
  un-favorite + rename the previous one. Use variables (theNew/theOld),
  never `it`.
- Append to the account's ledgers (used material/topics, audio-used).
- If the account folder is a git repo: commit the ledgers/captions/learning
  files the account file lists (never drafts/media/secrets) and push;
  on rejection `git pull --rebase` then push.
- Write `routine/last-run.txt` — LOCAL-time ISO timestamp
  (`date +%Y-%m-%dT%H:%M:%S`, NEVER `date -u`; the launcher parses it as
  local time for the manifest window and the ran-today skip).
- macOS notification (osascript `display notification`): one line = concept +
  audio pick, e.g. "Staged: <hook>. Audio: <track>. Photos → <album>."
