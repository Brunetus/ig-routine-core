#!/usr/bin/env python3
"""Build an Instagram reel cover (thumbnail) from the reel's own footage.

Universal across accounts (ig-reel skill §8). Styling defaults match @imabgold's
spec; override per account via flags or a brand.md-documented wrapper.

Why this exists: a reel that opens on a donor creator's face puts THEIR face on
the grid, so the profile reads as a repost page and visitors don't follow.
@imabgold, 2026-09-21: 9 of the top 10 tiles were donor faces; after swapping in
face-of-the-account covers, follows moved (200 -> 210 in a day).

Usage:
  make-cover.py --src CLIP.MOV --start 12.3 --end 17.9 \
      --line1 "WHAT MEN WANT:" --line2 "COFFEE + CLAUDE" --out cover.jpg
  make-cover.py --src CLIP.MOV --start 12.3 --end 17.9 --sheet picks.jpg
      (contact sheet of face candidates; then re-run with --frame N)
  Add --rotate 90|180|270 when the sheet shows the faces sideways or upside
  down (a phone clip whose display matrix is wrong; same fix the cut used).

Styles (2026-10-01). Everything above is ONE style, `bold-caps`: the look that
works on @imabgold's grid. Another account gets the style that works on ITS
grid, as a JSON file passed with --style (found by a cover study of that
account's own best and worst covers, approved by Marcus; see
reels-ios/mac/COVER-STUDY.md). Without --style the output is exactly what it
always was. A style chooses:
  framing  "face"    the tight face-centred crop described below
           "natural" the frame as shot: the largest 9:16 window, centred on the
                     face, optionally punched in (natural_scale 0.4..1.0)
           "letterbox" HORIZONTAL footage: the whole frame, uncropped, centred
                     on black, text in the bar above (text.y_boxed). VERTICAL
                     footage: exactly "natural", text at text.y. One style
                     for an account that shoots both ways.
           "product" NO face needed (2026-10-06, for @replogleglobescanada,
                     whose grid is product photography with no owner in it):
                     the largest 9:16 window centred on the frame, punched in
                     by natural_scale. The product is alone: any face in the
                     tile is a warning, which keeps a donor's face off the
                     grid. --frame picks the frame; without it the sharpest
                     frame of the beat is used. text.position must be "fixed".
  fade / relight     on or off (default: on for "face", off for "natural")
  text.mode "caps-two-line"  the two-line block below (line 1 white, line 2 accent)
            "sentence"       --line1 as ONE sentence, wrapped, one colour with an
                             outline, at text.y (top), like a reel's own card;
                             text.box_color puts each line on a rounded box
                             instead (Instagram's own label look)
            "none"           no text at all
  make-cover.py --check-style FILE validates a style file and exits.

Layout law (do not drift without re-measuring):
  * 1080x1920 output. The profile grid shows the CENTRED 3:4 window = rows
    240..1680. Face and both text lines must sit inside it.
  * Text bottom at y=1540, so a 4:5 crop or a nudged grid preview can't clip it.
  * One fixed font size for every cover in a set. Lines must be <=960px wide.
  * Line 1 white, line 2 the account's accent colour, which carries the payoff
    (what the account is actually about), not just the hook.
  * Relight is BRIGHTNESS ONLY (Y of YCbCr). Lifting RGB greys out skin.
"""
import argparse, glob, hashlib, json, os, re, shutil, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
FACE_BIN = os.path.join(HERE, "face")
FACE_SRC = os.path.join(HERE, "face.swift")
W, H = 1080, 1920
GRID_TOP, GRID_BOTTOM = 240, 1680          # what the profile grid actually shows
TEXT_BOTTOM = 1540
MAX_LINE_PX = 960
HLG_TONEMAP = ("zscale=tin=arib-std-b67:min=bt2020nc:pin=bt2020:t=linear:npl=203,"
               "format=gbrpf32le,zscale=p=bt709,tonemap=hable:desat=0,"
               "zscale=t=bt709:m=bt709:r=pc,format=rgb24")


def ensure_face_bin():
    """Apple Vision face detector; compiled on first use."""
    # Rebuilt when the source is newer: the detector learned --all on 2026-10-01
    # and a stale binary would silently report one face per frame.
    if os.path.exists(FACE_BIN) and (not os.path.exists(FACE_SRC)
                                     or os.path.getmtime(FACE_BIN) >= os.path.getmtime(FACE_SRC)):
        return FACE_BIN
    if not os.path.exists(FACE_SRC):
        sys.exit(f"missing {FACE_SRC}")
    subprocess.run(["swiftc", "-O", FACE_SRC, "-o", FACE_BIN], check=True)
    return FACE_BIN


HEX6 = re.compile(r"[0-9a-fA-F]{6}")
DEFAULT_FONT = "/System/Library/Fonts/Avenir Next Condensed.ttc"
# What the generator reads from a style, and the notes that ride along for
# people and sessions (never read here).
STYLE_KEYS = {"name", "framing", "natural_scale", "fade", "relight", "text"}
NOTE_KEYS = {"frame", "copy", "why", "approved_by", "approved_at"}
TEXT_KEYS = {"mode", "font", "font_index", "size", "color", "accent", "stroke", "stroke_color",
             "y", "position", "max_width", "max_lines", "line_spacing",
             "box_color", "box_pad", "box_radius", "y_boxed"}
DASHES = re.compile("[\u2012-\u2015\u2212]")
STAMP = "eclip-cover-style:"


def style_id(st):
    """Fingerprint of what the generator reads from a style. Stamped into every
    styled cover, so the releaser can prove which look a file is really in
    without trusting anyone's say-so."""
    def norm(v):
        # 1.0 and 1 are the same setting: a style re-saved by another JSON
        # writer (cover-study.mjs approve) must keep its fingerprint.
        if isinstance(v, dict):
            return {k: norm(x) for k, x in v.items()}
        if isinstance(v, list):
            return [norm(x) for x in v]
        if isinstance(v, float) and v.is_integer():
            return int(v)
        return v
    core = norm({k: st[k] for k in sorted(STYLE_KEYS) if k in st})
    return hashlib.sha1(json.dumps(core, sort_keys=True, separators=(",", ":")).encode()).hexdigest()[:12]



def style_problems(st):
    """Everything wrong with a style file, as a list of plain sentences."""
    if not isinstance(st, dict):
        return ["a style is a JSON object"]
    out = []
    unknown = sorted(set(st) - STYLE_KEYS - NOTE_KEYS)
    if unknown:
        out.append(f"unknown key(s): {', '.join(unknown)} (a typo would be silently ignored)")
    if not re.fullmatch(r"[a-z0-9-]{1,40}", str(st.get("name", ""))):
        out.append("name must be lowercase letters, digits and dashes")
    if st.get("name") == "bold-caps":
        out.append("'bold-caps' is the generator's own look and takes no style file; pick another name")
    if st.get("framing") not in ("face", "natural", "letterbox", "product"):
        out.append("framing must be 'face', 'natural', 'letterbox' or 'product'")
    if st.get("framing") == "product":
        t = st.get("text")
        if isinstance(t, dict) and t.get("mode") == "sentence" and t.get("position", "auto") != "fixed":
            out.append("product framing has no face to dodge: text.position must be 'fixed'")
        for key in ("fade", "relight"):
            if st.get(key):
                out.append(f"product framing has no face to light or hide under: {key} must be false")
    scale = st.get("natural_scale", 1.0)
    if isinstance(scale, bool) or not isinstance(scale, (int, float)) or not 0.4 <= scale <= 1.0:
        out.append("natural_scale must be between 0.4 and 1.0")
    for key in ("fade", "relight"):
        if key in st and not isinstance(st[key], bool):
            out.append(f"{key} must be true or false")
    t = st.get("text")
    if not isinstance(t, dict) or t.get("mode") not in ("none", "caps-two-line", "sentence"):
        out.append("text.mode must be 'none', 'caps-two-line' or 'sentence'")
        return out
    unknown = sorted(set(t) - TEXT_KEYS)
    if unknown:
        out.append(f"unknown text key(s): {', '.join(unknown)}")
    if t["mode"] == "none":
        return out
    whole = lambda v: type(v) is int                     # True/False are not sizes
    if not os.path.exists(str(t.get("font", DEFAULT_FONT))):
        out.append(f"font file missing: {t.get('font')}")
    if not whole(t.get("font_index", 0)) or not 0 <= t.get("font_index", 0) <= 40:
        out.append("text.font_index must be a whole number from 0 to 40")
    if not whole(t.get("size", 112)) or not 24 <= t.get("size", 112) <= 200:
        out.append("text.size must be a whole number from 24 to 200")
    for key in ("box_pad", "box_radius"):
        if key in t and (not whole(t[key]) or not 0 <= t[key] <= 60):
            out.append(f"text.{key} must be a whole number from 0 to 60")
    for key in ("color", "accent", "stroke_color", "box_color"):
        if key in t and not HEX6.fullmatch(str(t[key])):
            out.append(f"text.{key} must be six hex digits")
    if not whole(t.get("stroke", 0)) or not 0 <= t.get("stroke", 0) <= 12:
        out.append("text.stroke must be a whole number from 0 to 12")
    spacing = t.get("line_spacing", 1.18)
    if isinstance(spacing, bool) or not isinstance(spacing, (int, float)) or not 0.9 <= spacing <= 2.0:
        out.append("text.line_spacing must be between 0.9 and 2.0")
    if t["mode"] == "sentence":
        for key in ("y", "y_boxed"):
            y = t.get(key, 300)
            if type(y) is not int or not GRID_TOP <= y <= GRID_BOTTOM - 200:
                out.append(f"text.{key} must be a whole number from {GRID_TOP} to {GRID_BOTTOM - 200} (inside the grid window)")
        if t.get("position", "auto") not in ("auto", "fixed"):
            out.append("text.position must be 'auto' (move under the face when text.y would cover it) or 'fixed'")
        mw = t.get("max_width", 860)
        if type(mw) is not int or not 300 <= mw <= MAX_LINE_PX:
            out.append(f"text.max_width must be a whole number from 300 to {MAX_LINE_PX}")
        ml = t.get("max_lines", 3)
        if type(ml) is not int or not 1 <= ml <= 4:
            out.append("text.max_lines must be 1 to 4")
    return out


def load_style(path):
    try:
        with open(path) as f:
            st = json.load(f)
    except Exception as e:
        sys.exit(f"style file unreadable: {e}")
    problems = style_problems(st)
    if problems:
        sys.exit("bad style: " + "; ".join(problems))
    return st


def rgb(hex6):
    return tuple(int(hex6[i:i + 2], 16) for i in (0, 2, 4))


def wrap_sentence(draw, text, font, max_width):
    lines, cur = [], ""
    for word in text.split():
        cand = (cur + " " + word).strip()
        if cur and draw.textlength(cand, font=font) > max_width:
            lines.append(cur)
            cur = word
        else:
            cur = cand
    if cur:
        lines.append(cur)
    return lines


OTHER_FACES = {}        # frame path -> every face after the widest, as [x, y, w, h]


def detect_faces(paths):
    """Widest face per frame (the crop centres on it); the rest land in OTHER_FACES."""
    out = {}
    for line in subprocess.run([ensure_face_bin(), "--all"] + paths, capture_output=True,
                               text=True).stdout.splitlines():
        p, *rest = line.split()
        if len(rest) >= 5 and rest[0].isdigit() and len(rest) == 1 + 4 * int(rest[0]):
            nums = list(map(int, rest[1:]))
            boxes = [nums[i:i + 4] for i in range(0, len(nums), 4)]
            out[p] = boxes[0]
            OTHER_FACES[p] = boxes[1:]
    return out


def frame_sharpness(path):
    """Sharpness of the whole frame (product framing has no face box to judge)."""
    g = np.asarray(Image.open(path).convert("L").resize((256, 256)), dtype=np.float32)
    return float(np.abs(4 * g[1:-1, 1:-1] - g[:-2, 1:-1] - g[2:, 1:-1]
                        - g[1:-1, :-2] - g[1:-1, 2:]).var())


def face_sharpness(path, box):
    x, y, w, h = box
    g = np.asarray(Image.open(path).convert("L").crop((x, y, x + w, y + h))
                   .resize((128, 128)), dtype=np.float32)
    return float(np.abs(4 * g[1:-1, 1:-1] - g[:-2, 1:-1] - g[2:, 1:-1]
                        - g[1:-1, :-2] - g[1:-1, 2:]).mean())


# Extra clockwise rotation, applied AFTER ffmpeg's autorotate. Phone clips
# shot face-up or mid-turn carry a display matrix that leaves them 90 or 180
# degrees wrong; the cut corrects that per clip, and the cover must use the
# same correction or the face lands sideways or upside down (eclip, 2026-10-01:
# Vision still finds the face, so nothing errors, the cover is just wrong).
ROTATE_VF = {0: "", 90: "transpose=1,", 180: "transpose=1,transpose=1,", 270: "transpose=2,"}


def extract(src, start, end, workdir, fps, hlg, rotate=0):
    """Frames from the beat. HLG iPhone footage is tone-mapped, or faces go muddy."""
    if os.path.splitext(src)[1].lower() in (".jpg", ".jpeg", ".png"):
        dst = os.path.join(workdir, "f_001.jpg")
        im = Image.open(src).convert("RGB")
        if rotate:
            im = im.rotate(-rotate, expand=True)
        im.save(dst, quality=95)
        return [dst]
    vf = ROTATE_VF[rotate] + (f"{HLG_TONEMAP},fps={fps}" if hlg else f"fps={fps}")
    cmd = ["ffmpeg", "-nostdin", "-v", "error", "-y"]
    if start is not None:
        cmd += ["-ss", str(start)]
    if start is not None and end is not None:
        cmd += ["-t", str(round(end - start, 3))]
    cmd += ["-i", src, "-vf", vf, "-q:v", "2", os.path.join(workdir, "f_%03d.jpg")]
    subprocess.run(cmd, check=True)
    return sorted(glob.glob(os.path.join(workdir, "f_*.jpg")))


def is_hlg(src):
    if os.path.splitext(src)[1].lower() in (".jpg", ".jpeg", ".png"):
        return False
    info = subprocess.run(["ffmpeg", "-i", src], capture_output=True, text=True).stderr
    return "arib-std-b67" in info


def sheet(frames, faces, out):
    """Contact sheet of face close-ups, so a human picks the expression."""
    T, cols = 200, 8
    rows = (len(frames) + cols - 1) // cols
    s = Image.new("RGB", (cols * T, rows * T), "black")
    d = ImageDraw.Draw(s)
    for i, p in enumerate(frames):
        im = Image.open(p).convert("RGB")
        if p in faces:
            x, y, w, h = faces[p]
            m = w * 0.9
            im = im.crop((int(x - m), int(y - m), int(x + w + m), int(y + w + m * 1.6)))
        s.paste(im.resize((T, T)), ((i % cols) * T, (i // cols) * T))
        d.text(((i % cols) * T + 4, (i // cols) * T + 4), os.path.basename(p)[2:5],
               fill="yellow")
    s.save(out, quality=88)


def relight(im, face, radius=2.2, black_point=0.0, warm=(-3, 4), sat=1.12,
            target=0.56, floor=0.42):
    """Backlit whiteboard/laptop shots leave the face dark. Lift Y only."""
    ycc = np.asarray(im.convert("YCbCr")).astype(np.float32)
    Y = ycc[..., 0] / 255
    Y = Y ** 0.85
    x, y, w, h = face
    cx, cy, r = x + w / 2, y + h * 0.8, w * radius
    yy, xx = np.mgrid[0:Y.shape[0], 0:Y.shape[1]]
    mask = np.clip(1 - np.sqrt(((xx - cx) / r) ** 2 + ((yy - cy) / (r * 1.25)) ** 2), 0, 1) ** 1.5
    fl = float(Y[max(y, 0):y + h, max(x, 0):x + w].mean())
    g = np.clip(np.log(target) / np.log(max(fl, 0.05)), floor, 1.0)
    Y = Y * (1 - mask) + (Y ** g) * mask
    if black_point:
        Y = np.clip((Y - black_point) / (1 - black_point), 0, 1)
    ycc[..., 0] = np.clip((Y - 0.5) * 1.06 + 0.5, 0, 1) * 255
    ycc[..., 1] += warm[0]
    ycc[..., 2] += warm[1]
    ycc = np.clip(ycc, 0, 255).astype(np.uint8)
    im = Image.merge("YCbCr", [Image.fromarray(ycc[..., i]) for i in range(3)]).convert("RGB")
    im = ImageEnhance.Color(im).enhance(sat)
    return im.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))


def build(a):
    style = load_style(a.style) if a.style else None
    natural = bool(style) and style["framing"] in ("natural", "letterbox", "product")
    letterbox = bool(style) and style["framing"] == "letterbox"
    product = bool(style) and style["framing"] == "product"
    text_mode = style["text"]["mode"] if style else "caps-two-line"
    work = tempfile.mkdtemp(prefix="cover-")
    try:
        frames = extract(a.src, a.start, a.end, work, a.fps,
                         a.hlg if a.hlg is not None else is_hlg(a.src), a.rotate)
        if not frames:
            sys.exit("no frames extracted")
        faces = detect_faces(frames)
        if a.sheet:
            sheet(frames, faces, a.sheet)
            print(f"contact sheet: {a.sheet} ({len(frames)} frames, {len(faces)} with a face)")
            print("pick one, then re-run with --frame N")
            return
        if product:
            # The product is the subject: no face is needed, and the whole
            # frame (not a face box) is what gets judged for sharpness.
            if a.frame:
                pick = os.path.join(work, f"f_{a.frame:03d}.jpg")
                if pick not in frames:
                    sys.exit(f"frame {a.frame} is not in the beat ({len(frames)} frames)")
            else:
                pick = max(frames, key=lambda p: frame_sharpness(p))
            src = Image.open(pick).convert("RGB")
            sw, sh = src.size
            # A stand-in "face": the centre of the frame, so the shared code
            # below (window, luma, warnings) has a box to work with.
            fw, fh = int(sw * 0.3), int(sh * 0.3)
            x, y = (sw - fw) // 2, (sh - fh) // 2
        else:
            if not faces:
                sys.exit("no face found in the beat; widen --start/--end or pass a still to --src")
            if a.frame:
                pick = os.path.join(work, f"f_{a.frame:03d}.jpg")
                if pick not in faces:
                    sys.exit(f"frame {a.frame} has no detected face")
            else:
                pick = max(faces, key=lambda p: face_sharpness(p, faces[p]))
            x, y, fw, fh = faces[pick]
            src = Image.open(pick).convert("RGB")
            sw, sh = src.size

        # Horizontal footage gets the bars; vertical footage is shown as shot
        # (Marcus, 2026-10-01, for @josuesantos.ads: "option A if it's
        # vertical, and option B if it's horizontal"). One style, both cases.
        boxed = letterbox and sw > sh
        if boxed:
            # The whole frame, uncropped, on black. Nothing is cut away, so the
            # crop rectangle is the frame itself.
            x0, y0, cw, ch = 0, 0, sw, sh
        elif natural:
            # The frame as shot: the largest 9:16 window, centred on the face,
            # punched in by natural_scale. The setting stays in the picture.
            scale = style.get("natural_scale", 1.0)
            cw = min(sw, sh * 9 / 16) * scale
            ch = cw * 16 / 9
            cx, cy = x + fw / 2, y + fh / 2
            x0 = min(max(cx - cw / 2, 0), sw - cw)
            # Product: the window sits on the frame's centre; a face sits 40% down.
            y0 = min(max(cy - ch * (0.50 if product else 0.40), 0), sh - ch)
        else:
            # Crop face-centred: face about a third down, so it lands high in the 3:4 window.
            cw = max(fw * a.zoom, 560 if sw < 2000 else 700)
            cw = min(cw, sw, sh * 9 / 16)
            ch = cw * 16 / 9
            cx, cy = x + fw / 2, y + fh / 2
            x0 = min(max(cx - cw / 2, 0), sw - cw)
            y0 = min(max(cy - ch * 0.34, 0), sh - ch)
        k = W / cw
        off = 0                                  # top of the picture band when letterboxed
        if boxed:
            ph = int(round(sh * k))
            off = (H - ph) // 2
            face = (int(x * k), off + int(y * k), int(fw * k), int(fh * k))
            im = Image.new("RGB", (W, H))
            im.paste(src.resize((W, ph), Image.LANCZOS), (0, off))
        else:
            face = (int((x - x0) * k), int((y - y0) * k), int(fw * k), int(fh * k))
            im = src.crop((int(x0), int(y0), int(x0 + cw), int(y0 + ch))).resize((W, H), Image.LANCZOS)
        if style is None or style.get("relight", not natural):
            im = relight(im, face, radius=a.relight_radius, black_point=a.black_point,
                         warm=(a.warm_cb, a.warm_cr), sat=a.saturation)

        if style is None or style.get("fade", not natural):
            # Dark fade from the bottom: hides laptop lids and desk edges under the text.
            grad = np.clip((np.arange(H) - a.fade_start) / 420, 0, 1) ** 1.2 * 235
            im.paste(Image.new("RGB", (W, H)),
                     (0, 0), Image.fromarray(np.repeat(grad[:, None], W, 1).astype(np.uint8)))

        d = ImageDraw.Draw(im)
        text_box = None                      # (top, bottom) of the text block, when there is one
        if text_mode == "caps-two-line":
            t = style["text"] if style else {}
            size = t.get("size", a.size)
            lines = [l for l in (a.line1, a.line2) if l]
            font = ImageFont.truetype(t.get("font", a.font), size, index=t.get("font_index", a.font_index))
            for l in lines:
                width = d.textlength(l, font=font)
                if width > MAX_LINE_PX:
                    sys.exit(f'line too wide ({int(width)}px > {MAX_LINE_PX}): "{l}" — shorten it; '
                             "do NOT shrink the font, the set must share one size")
            lh = int(size * 0.98)
            top = TEXT_BOTTOM - lh * len(lines)
            accent_hex = a.accent if a.accent_given or "accent" not in t else t["accent"]
            accent = tuple(int(accent_hex[i:i + 2], 16) for i in (0, 2, 4))
            for i, l in enumerate(lines):
                d.text(((W - d.textlength(l, font=font)) / 2, top + i * lh), l, font=font,
                       fill=accent if i == 1 else (255, 255, 255))
            text_box = (top, TEXT_BOTTOM)
        elif text_mode == "sentence":
            # One sentence, the way a reel's own card reads: one colour, an
            # outline, wrapped, near the top of the grid window.
            t = style["text"]
            size = t.get("size", 56)
            font = ImageFont.truetype(t.get("font", DEFAULT_FONT), size, index=t.get("font_index", 0))
            sentence = " ".join(l for l in (a.line1, a.line2) if l).strip()
            if not sentence:
                sys.exit("this style carries one sentence: pass it in --line1")
            max_width = t.get("max_width", 860)
            lines = wrap_sentence(d, sentence, font, max_width)
            for l in lines:
                if d.textlength(l, font=font) > max_width:
                    sys.exit(f'a word is wider than the text block ({max_width}px): "{l}" — reword it')
            if len(lines) > t.get("max_lines", 3):
                sys.exit(f'text too long: {len(lines)} lines, this style allows {t.get("max_lines", 3)} — '
                         f'shorten "{sentence}"; do NOT shrink the font')
            # Balance the lines: the narrowest block that keeps the same line
            # count, so the last line is never one stranded word.
            width = max_width
            while width - 20 >= 300:
                tighter = wrap_sentence(d, sentence, font, width - 20)
                if len(tighter) != len(lines) or any(d.textlength(l, font=font) > width - 20 for l in tighter):
                    break
                lines, width = tighter, width - 20
            lh = int(size * t.get("line_spacing", 1.18))
            block = lh * len(lines)
            top = t.get("y_boxed", t.get("y", 300)) if boxed else t.get("y", 300)
            # Selfie footage puts the face high in the frame: when the block
            # at text.y would sit on the face, it goes under it instead (the
            # chest, where there is room), still inside the grid window. If
            # neither place is clear the warning below says so.
            face_top, face_bottom = face[1], face[1] + face[3]
            box_rise = int(t.get("box_pad", 18) * 0.45) if "box_color" in t else 0
            if boxed:
                # Letterboxed: the label lives in the bar ABOVE the picture,
                # never on it. Its bottom is held clear of the picture, so a
                # 4:3 clip (a shorter bar than 16:9) pushes it up instead of
                # letting it slide onto the frame.
                top = min(top, off - 28 - block)
            elif t.get("position", "auto") == "auto" and not (top + block <= face_top or top >= face_bottom):
                below = face_bottom + int(face[3] * 0.30)
                if below + block <= GRID_BOTTOM - 60:
                    top = below
            stroke = t.get("stroke", 0)
            if "box_color" in t:
                # Instagram's label look: each line sits on its own rounded box.
                pad, radius = t.get("box_pad", 18), t.get("box_radius", 16)
                asc, desc = font.getmetrics()
                for i, l in enumerate(lines):
                    lw = d.textlength(l, font=font)
                    x1, y1 = (W - lw) / 2 - pad, top + i * lh - pad * 0.45
                    d.rounded_rectangle((x1, y1, x1 + lw + 2 * pad, y1 + asc + desc + pad * 0.9),
                                        radius=radius, fill=rgb(t["box_color"]))
            for i, l in enumerate(lines):
                d.text(((W - d.textlength(l, font=font)) / 2, top + i * lh), l, font=font,
                       fill=rgb(t.get("color", "FFFFFF")), stroke_width=stroke,
                       stroke_fill=rgb(t.get("stroke_color", "000000")))
            text_box = (top - box_rise, top + lh * len(lines))

        if style is None:
            im.save(a.out, quality=95)
        else:
            # A styled cover says which style it is in, inside the file itself.
            im.save(a.out, quality=95, comment=f"{STAMP}{style['name']}:{style_id(style)}".encode())
        fl = np.asarray(im.convert("L").crop((face[0], face[1], face[0] + face[2],
                                              face[1] + face[3]))).mean()
        warn = ""
        # Anyone else in the tile: another detected face whose box reaches into
        # the crop. The cover is the account owner alone (ig-reel 8.5: never a
        # donor; eclip: never a client), in every style. Specks under 2.5% of
        # the tile's width are noise, not people.
        others = 0
        # In a product cover EVERY face counts, the main one included: the
        # product is alone, and this is what keeps a donor's face off the grid.
        all_faces = ([faces[pick]] if product and pick in faces else []) + OTHER_FACES.get(pick, [])
        for ox, oy, ow, oh in all_faces:
            inside = ox + ow > x0 and ox < x0 + cw and oy + oh > y0 and oy < y0 + ch
            if inside and ow >= cw * 0.025:
                others += 1
        if others:
            warn += (f"  WARNING: {others} face(s) in the cover; the product is alone in it\n" if product
                     else f"  WARNING: {others} other face(s) in the cover; the owner must be alone in it\n")
        if product:
            if text_box and (text_box[0] < GRID_TOP or text_box[1] > GRID_BOTTOM):
                warn += "  WARNING: text outside the grid window\n"
            if fl < 60:
                warn += f"  WARNING: picture dark (centre luma {fl:.0f}); try another frame\n"
        elif style is None:
            if face[1] < GRID_TOP or face[1] + face[3] > top:
                warn += "  WARNING: face outside the grid window or behind the text\n"
        else:
            face_top, face_bottom = face[1], face[1] + face[3]
            if face_top < GRID_TOP or face_bottom > GRID_BOTTOM:
                warn += "  WARNING: face outside the grid window\n"
            if text_box and not (text_box[1] <= face_top or text_box[0] >= face_bottom):
                warn += "  WARNING: text over the face\n"
            if text_box and (text_box[0] < GRID_TOP or text_box[1] > GRID_BOTTOM):
                warn += "  WARNING: text outside the grid window\n"
            if boxed and text_box and text_box[1] > off:
                warn += "  WARNING: the label does not fit in the bar above the picture\n"
            if face[2] < 90:
                warn += f"  WARNING: face too small to read in the grid tile ({face[2]}px wide); pick a closer frame\n"
        if fl < 80 and not product:
            warn += f"  WARNING: face still dark (luma {fl:.0f}); try another frame\n"
        if k > 2.0:
            warn += f"  WARNING: upscaled {k:.1f}x; it will look soft\n"
        print(f"{a.out}: frame {os.path.basename(pick)}, upscale {k:.2f}x, face luma {fl:.0f}")
        sys.stdout.write(warn)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    p = argparse.ArgumentParser(description="Build a reel cover from the reel's own footage.",
                                allow_abbrev=False)
    p.add_argument("--src", help="source clip (or a still image)")
    p.add_argument("--style", help="style JSON for this account (default: the bold-caps look)")
    p.add_argument("--check-style", help="validate a style JSON and exit")
    p.add_argument("--style-id", help="print NAME:FINGERPRINT for a style JSON and exit")
    p.add_argument("--start", type=float, help="beat start, seconds")
    p.add_argument("--end", type=float, help="beat end, seconds")
    p.add_argument("--frame", type=int, help="frame number from --sheet; default is the sharpest face")
    p.add_argument("--sheet", help="write a contact sheet of face candidates and exit")
    p.add_argument("--line1", default="", help="white line (the hook)")
    p.add_argument("--line2", default="", help="accent line (the payoff: what the account is about)")
    p.add_argument("--out", default="cover.jpg")
    p.add_argument("--fps", type=float, default=4)
    p.add_argument("--hlg", type=lambda s: s.lower() == "true", default=None,
                   help="force HLG tone-mapping on/off (default: autodetect)")
    p.add_argument("--rotate", type=int, choices=[0, 90, 180, 270], default=0,
                   help="extra clockwise rotation after autorotate; use the same correction "
                        "the cut applied to this clip (check --sheet: faces must be upright)")
    p.add_argument("--zoom", type=float, default=4.6, help="crop width in face widths")
    p.add_argument("--font", default="/System/Library/Fonts/Avenir Next Condensed.ttc")
    p.add_argument("--font-index", type=int, default=8, help="8 = Heavy in Avenir Next Condensed")
    p.add_argument("--size", type=int, default=112, help="one size for the whole set")
    p.add_argument("--accent", default="E8B840", help="line 2 colour, hex")
    p.add_argument("--fade-start", type=int, default=1000)
    p.add_argument("--relight-radius", type=float, default=2.2)
    p.add_argument("--black-point", type=float, default=0.0, help="raise on hazy sources")
    p.add_argument("--warm-cb", type=float, default=-3)
    p.add_argument("--warm-cr", type=float, default=4)
    p.add_argument("--saturation", type=float, default=1.12)
    a = p.parse_args()
    if a.check_style:
        st = load_style(a.check_style)
        print(f"style ok: {st['name']} ({st['framing']} framing, text {st['text']['mode']})")
        return
    if a.style_id:
        st = load_style(a.style_id)
        print(f"{st['name']}:{style_id(st)}")
        return
    for line in (a.line1, a.line2):
        if DASHES.search(line or ""):
            p.error(f'no dashes on a cover: "{line}"')
    if not a.src:
        p.error("--src is required")
    # An explicit --accent beats the style's; the default must not.
    a.accent_given = any(arg == "--accent" or arg.startswith("--accent=") for arg in sys.argv[1:])
    needs_text = True
    if a.style:
        needs_text = load_style(a.style)["text"]["mode"] != "none"
    if not a.sheet and needs_text and not (a.line1 or a.line2):
        p.error("--line1/--line2 required unless --sheet (or a style with no text)")
    build(a)


if __name__ == "__main__":
    main()
