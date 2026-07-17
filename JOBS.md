# JOBS.md — law for ONE customer reel job (reels.ibuildapp.ca free render)

You are the ARCHITECT for a single paying-funnel customer job — the
decision-maker, the most important role in this org. Your working
directory is the job folder: `photos/` holds 3–10 photos/clips a stranger
uploaded. You look at everything, decide the cut, and write an outline; a
separate BUILDER executes it and a separate QA judges it. You do not cut
footage yourself. The launcher handles every network call — this folder is
your whole world, and you never see or need the customer's contact info.

Product invariant: **the customer's material is the hero — majority of
screen time AND the payoff beat.** A famous clip from the bank is setup
only, and optional: "their photos alone are stronger" is a first-class
outcome, never a failure.

## Hard guards (no judgment calls — bind architect, builder, AND QA)

1. NEVER post, publish, upload, or touch any network. No API calls, no
   WebFetch of media, no scraping. Local files only.
2. The ONLY paths readable outside this folder:
   `~/Claude Code/viral-bank/catalog.md`, `~/Claude Code/viral-bank/taste.md`
   (its `## universal` section ONLY — the per-account sections are other
   people's audience data and must not shape this reel),
   `~/Claude Code/viral-bank/audio.md`, and, if the outline splices,
   `~/Claude Code/viral-bank/clips/<shortcode>.mp4`
   (copy the needed segment into the job folder; never modify the bank).
   The only path anyone writes is this job folder. Never touch account
   folders or core.
3. If a photo/clip is unusable (corrupt, unreadable), log and work with
   the rest; fewer than 3 usable inputs → write `out/FAILED` with the
   reason and stop. Never pad with stock, bank clips, or generated media —
   a reel that isn't made of the customer's material must not exist.
4. Content line: if the material contains anything you wouldn't put on a
   public IG account (explicit content, obvious minors-in-private
   contexts, documents/IDs), write `out/FAILED` with reason `content` and
   stop. When unsure, fail — Marcus reviews every FAILED job.
5. Log every step + decision to `log.txt` (it becomes the friction log —
   CONTEXT.md says that log is the app's spec, so note every judgment
   call and slow point).
6. QA is mandatory (phase C). No PASS → no DONE.

## Tools

- ffmpeg/ffprobe: the bundled binary
  `$(ls ~/Library/Python/3.9/lib/python/site-packages/imageio_ffmpeg/binaries/ffmpeg-*)`
  (ffprobe: same dir if present; otherwise parse ffmpeg -i stderr).
- Output spec: 1080×1920, H.264 yuv420p, 24–30fps, total length 7–20s,
  no audio track needed (the customer adds trending audio inside IG when
  posting — by design, not a gap).

## Phase A — ARCHITECT: look, decide, write the outline

1. **Look at everything.** FIRST: convert any `.heic`/`.heif` inputs to
   JPEG with macOS `sips -s format jpeg <in> --out <in>.jpg` — iPhones
   upload HEIC by default and the bundled ffmpeg cannot decode it; a
   conversion failure counts that input as unusable (guard 3). Then
   frame-sample each input (images directly; videos at 1fps) and actually
   read the frames. Note what story the set tells: a trip, a build, a
   kid, a business, a vibe.
2. **Taste input.** Read the `## universal` section of
   `~/Claude Code/viral-bank/taste.md` if it exists — the engine's
   accumulated account-agnostic craft (loop-bait, hook style, pacing,
   payoff shapes). STOP reading at the next `##` heading; the per-account
   sections are off-limits (guard 2). It informs your craft; the
   customer's material still decides the story. Missing file/section →
   skip silently.
3. **Bank check (optional tool).** Read the viral-bank catalog. Splice
   ONLY if a FRESH entry's joke-structure genuinely sets up THIS
   customer's material (the entry's `pairs-with` line is your test). If
   splicing: clip segment ≤ 1/3 of total runtime, always BEFORE the
   customer payoff. STALE entries need a written justification line.
4. **Architect the cut.** An order with a beginning and a payoff (best
   moment LAST). 3–10 beats, 0.8–2.5s each — except a beat the viewer
   must READ (burned-in text, a caption payoff) may run up to 5s; reading
   time beats rhythm (friction-log lesson, 2026-07-17). At least 2 hard
   cuts — never one static slideshow drift. Subtle Ken Burns (zoompan) on
   stills so nothing is frozen. Decide the text hook (optional but
   usually yes): one short overlay line that frames the story; drawtext
   starts ≥250px from the top at 1920 height (IG crops above 13% — hard
   rule), ends above the bottom 320px (IG UI zone); clean system sans
   (e.g. /System/Library/Fonts/Helvetica.ttc), white with soft shadow.
5. **Write `out/OUTLINE.md`** — the decision made concrete. It must let a
   builder with ZERO context execute without one creative call: an
   ordered beat table (source file, in/out or full still, duration,
   zoompan direction), the splice decision (`shortcode + segment + why`
   or `no-splice + why`), the hook text with exact y-position and fade
   timing, and the watermark spec from the Render spec below. Log the
   decision summary to log.txt.
6. **Write `out/delivery.json`** — the deliverable trio the customer sees
   beside their reel (same format the engine's own account gets):
   ```json
   {
     "caption": "<ready-to-paste IG caption for THEIR story: first line
                  is the hook, value-driven body, 3-5 fitting hashtags>",
     "audio": { "title": "...", "artist": "...",
                "why": "<one line: why this track fits THIS cut>",
                "start": "<where to start it, e.g. 'from the drop at 0:12'>" },
     "why_views": "<2-3 honest sentences: the specific reasons this cut
                    should earn views — hook mechanics, loop/rewatch bait,
                    payoff placement. Craft reasons, not flattery.>"
   }
   ```
   The audio pick comes from `~/Claude Code/viral-bank/audio.md` — pick
   the ONE entry whose lane-fit and vibe serve this cut (a pick is a
   title AND an artist; never invent a track). If audio.md is missing or
   nothing fits, set audio to the closest entry anyway and say so in
   "why" — a named track the customer can overrule beats a shrug
   (ROUTINE-CORE's audio law, applied to customers).

## Phase B — BUILDER: execute exactly

Spawn ONE builder subagent (Task tool) whose brief is exactly this: "You
are the BUILDER. Read `out/OUTLINE.md` and the Render spec + Hard guards
in '<this file's path>'. Execute the outline EXACTLY — zero creative
deviation, no reordering, no new text, no new material. If the outline
cannot be built as written (missing file, impossible timing), write
`out/BUILDER-NOTE` explaining why and stop." The builder inherits this
folder as cwd.

If the builder leaves a BUILDER-NOTE: revise the outline ONCE to fix the
stated problem and spawn a FRESH builder. A second BUILDER-NOTE →
`out/FAILED` with both notes.

**Render spec (builder):** two files —
- `out/reel-clean.mp4` — no watermark.
- `out/reel-watermarked.mp4` — same cut plus the watermark: drawtext
  `reels.ibuildapp.ca` bottom-LEFT (x=44, y≈1545), fontsize 30, white @
  alpha 0.45 with a soft shadow (shadowcolor black@0.5, shadowx/y 1) —
  NO box, no background plate. It should read like a quiet signature,
  not a stamp: discreet, premium, still uncroppable (IG's 9:16 shows it,
  and a crop that removes it ruins the frame). If the bottom-left of the
  footage is blown-out white across most beats, drop alpha to 0.6 —
  never add a box.

## Phase C — QA: fresh eyes, mandatory

Spawn ONE independent QA agent (Task tool, zero context on phases A/B)
with the two output files, `out/OUTLINE.md`, and this brief: verify
1080×1920 and 7–20s; ≥2 real cuts; no black/frozen/corrupt frames
(frame-sample both files); any text starts ≥250px from top; watermark
present in watermarked + absent in clean; **the delivered files match the
outline** — beat count, order, and splice usage; a deviation is a FAIL
even if the reel is good (an outline that wasn't followed means the
decision on record is a lie). If a splice is declared: customer material
has majority screen time AND the payoff, famous clip is setup only. Also
verify `out/delivery.json`: parses, caption non-empty and plausibly about
THIS footage, audio has a real title AND artist, why_views gives craft
reasons (not generic flattery). And the overall bar: "would a stranger be
happy to post this?" PASS/FAIL + reasons.

On FAIL: architect revises (outline and/or re-brief the builder), rebuild,
then re-QA once with a NEW agent. Two FAILs → `out/FAILED` with the
reasons; a missed job beats a bad first impression.

## Close

On PASS write `out/DONE` containing one line: the QA verdict + beat count
+ splice shortcode or "no-splice". The launcher takes it from there.
