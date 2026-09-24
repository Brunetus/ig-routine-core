# WORDCAPS.md — word-synced ("karaoke") captions for narration-led reels

**WHEN:** a reel is narration-led — the user's/customer's OWN spoken voice
carries the content (a tutorial, teaching point, pitch, talking-to-camera)
AND the voice is clean enough to transcribe. One word appears on screen at
a time, popping in exactly as it is spoken. Do NOT use on montage /
trending-audio reels (those keep line-level overlays or none).

**STATUS:** tested + shipped. Proven on reel-app job `07734fe2` (Pilates
educator) as the "word-synced captions" variant — Marcus: "worked really
well." This file records that exact process so it is repeatable.

## Recipe

1. **Word timestamps** (per source clip used in a narration beat). Extract
   audio and transcribe with word-level timestamps:
   - `ffmpeg -i <clip> -vn -ar 16000 -ac 1 audio.wav`
   - `mlx_whisper.transcribe("audio.wav", path_or_hf_repo="mlx-community/whisper-base-mlx", word_timestamps=True)`
   - Save each clip as `NN.words.json`: array of `{ "w": word, "s": start, "e": end }` in the SOURCE clip's own time.

2. **Build the base reel first.** Assemble the narration-led cut as normal
   (per-beat segments → `concat.txt` → concat → `base.mp4`), the voice kept
   in the render (AAC). Word captions are a second pass ON TOP of base.mp4.

3. **Map words to the reel timeline.** For each beat (source clip + its
   [in,out] + its cumulative offset in the finished reel), take each word
   whose source time falls inside [in,out] and set
   `reel_time = beat_offset + (word.s − beat.in)`. One caption per word;
   each word's END = the next word's START (one word visible at a time).
   Skip words outside a beat, and beats with no narration.

4. **Emit `captions.ass`** (the tested style — keep these values):
   - `[Script Info]`: PlayResX 1080, PlayResY 1920, WrapStyle 2, ScaledBorderAndShadow yes
   - Style `Word`: Arial, 72, PrimaryColour `&H00FFFFFF` (white), OutlineColour `&HCC000000`, BackColour `&H80000000`, Bold -1, Outline 4, Shadow 2, Alignment 5 (centered), MarginV 0
   - one `Dialogue` per word, Start→End = the word's reel time, Text:
     `{\pos(540,1360)\fscx55\fscy55\t(0,90,\fscx100\fscy100)}WORD`
     → centered at x=540 (frame center), y=1360 (~71% down, inside the text
     safe zone); pops in 55%→100% scale over 90 ms.

5. **Burn in.**
   - `ffmpeg -i base.mp4 -vf "ass=captions.ass" -c:a copy reel-wordcaps-clean.mp4`
   - that clean file IS the deliverable. No watermark pass (Marcus,
     2026-08-26: nothing ships with a watermark).

6. **QA the caption pass.** Frame-sample at several word-boundary times +
   a contact sheet; verify each word appears on time, spelled correctly,
   one at a time, inside the safe zone. (The base reel already passed
   normal QA; this pass only checks the captions.)

## Delivery
Word-synced captions can be the reel's MAIN render OR a separate VARIANT of
the base reel (job `07734fe2` shipped it as variant `word-synced captions`,
`variant_of` the base job). The architect decides per job/account.

## Notes
- **Cut-boundary rules (added 2026-09-11 after QA on imabgold `0910_tworole`):** a caption must END ONE FRAME
  BEFORE any cut, never on it (libass draws the outgoing line on the cut tick, so a word bleeds one frame onto
  the next shot); and a minimum-duration clamp must never push an end past the NEXT word's start (it drew two
  words on one frame). A word whose whisper start falls just before a cut may be snapped TO the cut; a word
  whisper places before a spoken pause must be moved to the audio onset (`Do` was 0.54 s early).
- **Generator assertions (added 2026-09-11, same QA):** after emitting the ASS, assert (a) the number of Dialogue
  events equals the intended word count, (b) every event is >= 0.10 s long (a start moved onto the next word's
  start silently became a zero-duration card that rendered on NO frame), (c) no two events overlap, (d) no event
  ends on or after a cut it started before. Whisper can emit a degenerate word (start == end) at a spoken pause;
  time those by hand from the RMS envelope.
- **Fast function words (added 2026-09-12):** whisper often stamps two words within 20-80 ms of each other ("you know",
  "for sure"); a card that short cannot pop. Auto-merge any word spoken <0.10 s before the next into ONE card with the
  next word ("you know") rather than dropping it or hand-timing it. Two-word cards are legal for this reason.
- Safe zone: y=1360 keeps words clear of IG's bottom UI and is consistent
  with the ≥250px-from-top text rule (see [[imabgold-reel-text-safezone-and-cuts]]).
- Whisper mis-hears happen — fix obvious word spellings against what is
  actually said before emitting the ASS.
- **WHISPER IS THE SOURCE OF TRUTH FOR WORDS, NEVER FOR TIMING** (0911 Emil
  reel, 2026-09-11; the same law as reelbuild.py's OUT-POINT LAW, and what the
  cut-boundary rules above are all instances of). Every card/chunk onset comes
  from a measured 5 ms RMS envelope of the source.
- **AND THE WORD MUST BE INSIDE THE CUT.** Before trusting an out-point, check
  which side of it the last word falls on: the quiet gap right before a word
  reads exactly like that word's decay. On the 0911 reel a beat ended at 16.65
  while "point" was spoken 16.67-16.88, so the last caption sat on room tone.
- **VERIFY BY TRANSCRIBING THE RENDER, NOT THE PLAN.** Run two models
  (`whisper-large-v3` + `distil-large-v3`) over the FINISHED file — whole, and
  each beat window in isolation — and compare against the chunk list. Every
  caption defect on that reel was caught this way and none by eye: a chunk over
  an "um", a chunk 0.25 s early, a name clipped by an out-point ("with Abel"
  became "with it"). Isolated windows also disambiguate unstressed words; where
  the models split (he/you), tally across passes and flag it for a human ear.
- The user's own voice must be IN the render (AAC) for word-sync to make
  sense. A trending-audio bed added in-app later plays under the voice; the
  words still track the spoken voice, not the music.

## Caption truth-gate (2026-09-14, learned by getting it wrong twice on one reel)

1. **The speaker outranks the decoder.** The gate exists to stop the agent burning a word it cannot verify. It is not a
   licence to overrule the person in the footage about their own speech. When the owner rules on a word, that is the
   answer. And the ruling must then be carried INTO the QA brief: an auditor only verifies the brief it is handed, so a
   ruling left out of it comes back as a blocking finding against a correct file. (09-14: five decodes returned "hot",
   none returned "Claude", and the auditor demanded a re-burn of a word Marcus had personally ruled on. The brief was
   the defect, not the file. Note also that the decoder supported neither candidate, so the "safe" old word was only
   defensible, never correct.)

2. **To call a word prompt-following, prime for the OTHER candidate.** Counting unprimed passes is NOT the test. Run the
   symmetric pair: prime for A, then prime for B. A word that survives a prompt pushing the other way is recognition; a
   word that appears only when its own phrase is fed in is prompt-following. (09-14: the unprimed count said "walk in"
   3 of 4, so I nearly put the question to Marcus. The walk-primed pass returned "lock" at p0.95 and settled it the
   other way. Separately, a "will beats we'll 7 of 8" claim collapsed to 4/4 once prompts containing NEITHER candidate
   were tried.)

3. **Decode the DELIVERED audio, and only once the cut is final.** A renderer bug truncating 30-50 ms off each cue was
   making the decoder mishear: "lock in" came back as "lock here", "we'll" as "will". Repairing the audio repaired the
   transcript with no caption edit at all. A caption argued from a broken cut is an argument about the bug.
- **Centisecond rounding overlap (2026-09-23, `0923_opus55` QA):** rounding a card's START down and its END up to
  centiseconds makes every hand-off card overlap the next by 10 ms, and libass draws BOTH words on any frame inside that
  window (three stacked-word frames on a 68-card reel). When a card ends exactly where the next starts, write the end
  with the SAME rounding as the start (floor both). Keep ceil only for ends that are not a hand-off (cut minus one
  frame, last card). Assert zero overlaps on the parsed ASS, not on the pre-rounding floats.
