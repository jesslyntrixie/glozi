#!/usr/bin/env python3
"""
Compose the demo recording into a landscape frame with the headline beside it.

    python3 tools/make_demo_video.py demo.mov
    python3 tools/make_demo_video.py demo.mov --square

Writes glozi-demo-wide.mp4 (1920x1080) or glozi-demo-square.mp4 (1080x1080)
next to the input. Audio is dropped: LinkedIn autoplays muted and the demo
has no narration.

Needs ffmpeg and ffprobe, which are already on this machine.
"""

import argparse
import json
import os
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

PAPER = (251, 248, 241)
INK = (26, 22, 16)
MUTED = (122, 114, 98)
FILL = (255, 233, 138)
STROKE = (245, 197, 24)


def font(spec, size):
    """Ask fontconfig for the closest match, so this works on any machine."""
    path = subprocess.run(["fc-match", "-f", "%{file}", spec],
                          capture_output=True, text=True).stdout.strip()
    if not path or not os.path.exists(path):
        sys.exit(f"No font found for {spec!r}")
    return ImageFont.truetype(path, size)


def video_size(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "json", path],
        capture_output=True, text=True, check=True).stdout
    stream = json.loads(out)["streams"][0]
    return stream["width"], stream["height"]


def wrap(draw, text, fnt, width):
    """Greedy wrap, because Pillow has no text box."""
    words, lines, line = text.split(), [], ""
    for word in words:
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=fnt) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def fit(draw, text, spec, start_size, width, scale, floor=20):
    """Largest size at which `text` still fits on one line."""
    size = start_size
    while size > floor:
        fnt = font(spec, int(size * scale))
        if draw.textlength(text, font=fnt) <= width:
            return fnt
        size -= 2
    return font(spec, int(floor * scale))


def build_plate(canvas, slot, scale):
    """The still background. `slot` is where the video will sit."""
    W, H = canvas
    vx, vy, vw, vh = slot

    image = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(image, "RGBA")

    pad = int(76 * scale)
    text_width = vx - pad * 2

    serif = lambda s: font("DejaVu Serif", int(s * scale))
    serif_b = lambda s: font("DejaVu Serif:bold", int(s * scale))

    y = pad

    # Mark and wordmark.
    box = int(96 * scale)
    d.rounded_rectangle([pad, y, pad + box, y + box], radius=int(11 * scale),
                        fill=FILL, outline=STROKE, width=max(2, int(4 * scale)))
    cjk = font("Noto Serif CJK SC:bold", int(58 * scale))
    l, t, r, b = d.textbbox((0, 0), "字", font=cjk)
    d.text((pad + (box - (r - l)) / 2 - l, y + (box - (b - t)) / 2 - t), "字", font=cjk, fill=INK)
    d.text((pad + box + int(22 * scale), y + int(14 * scale)), "Glozi",
           font=serif_b(58), fill=INK)

    y += box + int(72 * scale)

    # Heading. Short enough to go very large, so let it.
    head = fit(d, "Press. Tap. Read.", "DejaVu Serif:bold", 132, text_width, scale)
    d.text((pad, y), "Press. Tap. Read.", font=head, fill=INK)
    y += int(head.size * 1.22)

    y += int(18 * scale)

    # Subheading.
    sub = serif(40)
    for line in wrap(d, "Any Chinese on your screen. Manga, games, menus, anything.",
                     sub, text_width):
        d.text((pad, y), line, font=sub, fill=INK)
        y += int(sub.size * 1.34)

    y += int(46 * scale)

    # The app's own highlight, around the one line that is the product.
    lead_text = "Press the Action Button. Tap the word you're stuck on."
    ph, pv = int(18 * scale), int(12 * scale)
    lead = fit(d, lead_text, "DejaVu Serif:bold", 46, text_width - ph * 2, scale)
    tw = d.textlength(lead_text, font=lead)
    d.rounded_rectangle([pad, y, pad + tw + ph * 2, y + lead.size + pv * 2],
                        radius=int(7 * scale), fill=FILL, outline=STROKE,
                        width=max(2, int(3 * scale)))
    d.text((pad + ph, y + pv - int(2 * scale)), lead_text, font=lead, fill=INK)

    # Footer, pinned to the bottom.
    foot = serif(30)
    d.text((pad, H - pad - foot.size),
           "Never translates the whole page. On purpose.", font=foot, fill=MUTED)

    # A hairline where the video will land, so the phone has an edge.
    d.rectangle([vx - 2, vy - 2, vx + vw + 1, vy + vh + 1],
                outline=(226, 220, 206), width=2)

    return image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("video")
    parser.add_argument("--square", action="store_true",
                        help="1080x1080 instead of 1920x1080")
    args = parser.parse_args()

    if not os.path.exists(args.video):
        sys.exit(f"No such file: {args.video}")

    src_w, src_h = video_size(args.video)

    if args.square:
        W, H, scale = 1080, 1080, 0.62
        margin = 46
    else:
        W, H, scale = 1920, 1080, 1.0
        margin = 46

    # Fit the phone to the height, leaving a margin top and bottom.
    vh = H - margin * 2
    vw = round(src_w * vh / src_h)
    vw -= vw % 2                      # h264 needs even dimensions
    vh -= vh % 2
    vx, vy = W - margin - vw, (H - vh) // 2

    if vx < W * 0.45:
        print(f"warning: the video is {src_w}x{src_h}, wide enough that little "
              f"room is left for the text. A vertical recording works best.")

    plate_path = "demo-plate.png"
    build_plate((W, H), (vx, vy, vw, vh), scale).save(plate_path)

    out = "glozi-demo-square.mp4" if args.square else "glozi-demo-wide.mp4"
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-loop", "1", "-i", plate_path,
        "-i", args.video,
        "-filter_complex",
        f"[1:v]scale={vw}:{vh}[v];[0:v][v]overlay={vx}:{vy}:shortest=1[out]",
        "-map", "[out]", "-an",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20",
        "-movflags", "+faststart",
        out,
    ], check=True)

    os.remove(plate_path)
    print(f"wrote {out}  ({W}x{H}, phone at {vw}x{vh})")


if __name__ == "__main__":
    main()
