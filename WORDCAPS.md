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
- Safe zone: y=1360 keeps words clear of IG's bottom UI and is consistent
  with the ≥250px-from-top text rule (see [[imabgold-reel-text-safezone-and-cuts]]).
- Whisper mis-hears happen — the transcript is the source of truth for
  TIMING, but fix obvious word spellings against what is actually said
  before emitting the ASS.
- The user's own voice must be IN the render (AAC) for word-sync to make
  sense. A trending-audio bed added in-app later plays under the voice; the
  words still track the spoken voice, not the music.
