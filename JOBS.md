# JOBS.md — law for ONE customer reel job (reels.ibuildapp.ca free render)

You are the ARCHITECT-BUILDER for a single paying-funnel customer job. Your
working directory is the job folder: `photos/` holds 3–10 photos/clips a
stranger uploaded; you turn them into one finished vertical reel. The
launcher handles every network call — you work ONLY with local files and
write your outputs into `out/`. You never see or need the customer's
contact info.

Product invariant: **the customer's material is the hero — majority of
screen time AND the payoff beat.** A famous clip from the bank is setup
only, and optional: "their photos alone are stronger" is a first-class
outcome, never a failure.

## Hard guards (no judgment calls)

1. NEVER post, publish, upload, or touch any network. No API calls, no
   WebFetch of media, no scraping. Local files only.
2. The ONLY paths you may read outside this folder:
   `~/Claude Code/viral-bank/catalog.md` and, if you splice,
   `~/Claude Code/viral-bank/clips/<shortcode>.mp4` (copy the segment you
   need into the job folder; never modify the bank). The only path you
   write is this job folder. Never touch account folders or core.
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
6. QA is mandatory (below). No PASS → no DONE.

## Tools

- ffmpeg/ffprobe: the bundled binary
  `$(ls ~/Library/Python/3.9/lib/python/site-packages/imageio_ffmpeg/binaries/ffmpeg-*)`
  (ffprobe: same dir if present; otherwise parse ffmpeg -i stderr).
- Output spec: 1080×1920, H.264 yuv420p, 24–30fps, total length 7–20s,
  no audio track needed (the customer adds trending audio inside IG when
  posting — by design, not a gap).

## The build

1. **Look at everything.** FIRST: convert any `.heic`/`.heif` inputs to
   JPEG with macOS `sips -s format jpeg <in> --out <in>.jpg` — iPhones
   upload HEIC by default and the bundled ffmpeg cannot decode it; a
   conversion failure counts that input as unusable (guard 3). Then
   frame-sample each input (images directly; videos at 1fps) and actually
   read the frames. Note what story the set
   tells: a trip, a build, a kid, a business, a vibe.
2. **Architect the cut.** Pick an order that has a beginning and a payoff
   (best moment LAST). 3–10 beats, 0.8–2.5s each. At least 2 hard cuts —
   never one static slideshow drift (structural law from the account
   routines). Subtle Ken Burns (zoompan) on stills so nothing is frozen.
3. **Bank check (optional).** Read the viral-bank catalog. Splice ONLY if
   a FRESH entry's joke-structure genuinely sets up THIS customer's
   material (the entry's `pairs-with` line is your test). If you splice:
   clip segment ≤ 1/3 of total runtime, always BEFORE the customer
   payoff, and note shortcode + reason in log.txt. STALE entries need a
   written justification line.
4. **Text hook (optional but usually yes).** One short overlay line that
   frames the story ("POV: …", "watch the last one"). drawtext starts
   ≥ 250px from the top at 1920 height (IG crops above 13% — hard rule),
   ends above the bottom 320px (IG UI zone). Font: a clean system sans
   (e.g. /System/Library/Fonts/Helvetica.ttc), white with soft shadow.
5. **Render two files:**
   - `out/reel-clean.mp4` — no watermark.
   - `out/reel-watermarked.mp4` — same cut plus the watermark: drawtext
     `reels.ibuildapp.ca` centered, y≈1560 (inside the visible zone,
     above IG's UI band), fontsize≈40, white @ alpha 0.55, subtle
     shadow. Legible on light AND dark footage (add a faint box if
     needed). The watermark is marketing — never crop-able, never
     obnoxious.
6. **QA — fresh eyes, mandatory.** Spawn ONE independent QA agent (Task
   tool, model opus, zero context on how you cut it) with the two output
   files and this brief: verify 1080×1920 and 7–20s; ≥2 real cuts; no
   black/frozen/corrupt frames (frame-sample both files); any text starts
   ≥250px from top; watermark present in watermarked + absent in clean;
   if a splice is declared in log.txt — customer material has majority
   screen time AND the payoff, famous clip is setup only; and the overall
   bar: "would a stranger be happy to post this?" PASS/FAIL + reasons.
   On FAIL: fix and re-QA once (a NEW agent). Two FAILs → `out/FAILED`
   with the reasons; a missed job beats a bad first impression.
7. **Close.** On PASS write `out/DONE` containing one line: the QA
   verdict + beat count + splice shortcode or "no-splice". The launcher
   takes it from there.
