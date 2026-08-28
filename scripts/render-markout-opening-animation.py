#!/usr/bin/env python3
"""Render a short cinematic MARKOUT logo opener as a 1080p60 MP4."""

from __future__ import annotations

import argparse
import importlib.util
import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


BASE_SCRIPT = Path(__file__).with_name("render-markout-cinematic-intro.py")
SPEC = importlib.util.spec_from_file_location("markout_cinematic_base", BASE_SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Unable to load {BASE_SCRIPT}")
B = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(B)

WIDTH = B.WIDTH
HEIGHT = B.HEIGHT
RENDER_FPS = 30
OUTPUT_FPS = 60
DURATION = 12.0

F_TAPE = B.font(B.FONT_MONO, 15)
F_LABEL = B.font(B.FONT_MONO, 18)
F_MARK = B.font(B.FONT_MONO, 64)
F_LOGO = B.font(B.FONT_BOLD, 148)
F_TAGLINE = B.font(B.FONT_REGULAR, 34)
F_STACK = B.font(B.FONT_MONO, 17)
F_TEASER = B.font(B.FONT_BOLD, 44)


def reveal(t: float, start: float, duration: float = 0.8) -> float:
    return B.smooth((t - start) / duration)


def fade_between(t: float, start: float, end: float, edge: float = 0.6) -> float:
    return B.smooth((t - start) / edge) * B.smooth((end - t) / edge)


def trail_points(t: float, adverse: bool) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    for index in range(46):
        progress = index / 45
        x = 124 + progress * 1672
        base = 550 + 16 * math.sin(index * 0.55 + t * 1.8)
        divergence = B.smooth((progress - 0.45) / 0.55)
        direction = -1 if adverse else 1
        y = base + direction * divergence * 190
        points.append((x, y))
    return points


def draw_market_tape(draw: ImageDraw.ImageDraw, t: float, alpha: float) -> None:
    price = 2431.12 + 3.2 * math.sin(t * 0.72) + 0.8 * math.sin(t * 2.8)
    draw.text((66, 45), "PYTH ETH/USD", font=F_TAPE, fill=B.rgba(B.GREEN, 220 * alpha))
    draw.text((240, 45), f"${price:,.2f}", font=F_TAPE, fill=B.rgba(B.TEXT, 235 * alpha))
    draw.text((1848, 45), "SIGNED PRICE / LIVE", font=F_TAPE, anchor="ra", fill=B.rgba(B.DIM, 215 * alpha))
    draw.line((66, 82, 1854, 82), fill=B.rgba(B.TEXT, 23 * alpha), width=1)

    tape = "EXECUTION  /  T+0  /  OBSERVATION  /  T+5M  /  REACT  /  ALLOCATE  /  "
    offset = -int((t * 86) % 670)
    for repeat in range(5):
        draw.text((offset + repeat * 670, 1015), tape, font=F_TAPE, fill=B.rgba(B.DIM, 105 * alpha))


def draw_particles(draw: ImageDraw.ImageDraw, t: float, alpha: float) -> None:
    for index in range(58):
        x = (83 * index + int(t * (16 + index % 7))) % WIDTH
        y = (149 * index + int(32 * math.sin(t * 0.44 + index * 1.7))) % HEIGHT
        brightness = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * 1.8 + index))
        radius = 1 if index % 6 else 2
        color = B.GREEN if index % 4 else B.BLUE
        draw.ellipse(
            (x - radius, y - radius, x + radius, y + radius),
            fill=B.rgba(color, 45 * alpha * brightness),
        )


def draw_signal_scene(draw: ImageDraw.ImageDraw, t: float) -> None:
    alpha = fade_between(t, 0.1, 6.8, 0.75)
    if alpha <= 0:
        return

    path_reveal = B.ease_out((t - 0.5) / 3.0)
    good = trail_points(t, False)
    adverse = trail_points(t, True)
    count = max(2, int(len(good) * path_reveal))

    draw.line(good[:count], fill=B.rgba(B.GREEN, 210 * alpha), width=4, joint="curve")
    draw.line(adverse[:count], fill=B.rgba(B.CORAL, 200 * alpha), width=4, joint="curve")

    for path, color in ((good, B.GREEN), (adverse, B.CORAL)):
        px, py = path[count - 1]
        pulse = 8 + 4 * (0.5 + 0.5 * math.sin(t * 5.0))
        draw.ellipse((px - pulse, py - pulse, px + pulse, py + pulse), outline=B.rgba(color, 100 * alpha), width=2)
        draw.ellipse((px - 4, py - 4, px + 4, py + 4), fill=B.rgba(color, 255 * alpha))

    swap_x = 124 + 0.45 * 1672
    draw.line((swap_x, 310, swap_x, 790), fill=B.rgba(B.AMBER, 90 * alpha), width=2)
    draw.text((swap_x + 18, 332), "SWAP / T+0", font=F_LABEL, fill=B.rgba(B.AMBER, 225 * alpha))
    draw.text((1796, 338), "ADVERSE FLOW", font=F_LABEL, anchor="ra", fill=B.rgba(B.CORAL, 235 * alpha * reveal(t, 2.2)))
    draw.text((1796, 756), "GOOD FLOW", font=F_LABEL, anchor="ra", fill=B.rgba(B.GREEN, 235 * alpha * reveal(t, 2.4)))

    title_alpha = alpha * reveal(t, 1.4, 0.9)
    draw.text((960, 206), "THE TRADE HAPPENS NOW.", font=F_TEASER, anchor="mm", fill=B.rgba(B.TEXT, 250 * title_alpha))
    draw.text((960, 868), "THE OUTCOME ARRIVES LATER.", font=F_TEASER, anchor="mm", fill=B.rgba(B.TEXT, 250 * title_alpha))
    draw.text((960, 925), B.tracked("One execution / two possible outcomes"), font=F_STACK, anchor="mm", fill=B.rgba(B.DIM, 220 * title_alpha))


def draw_convergence(draw: ImageDraw.ImageDraw, t: float) -> None:
    alpha = fade_between(t, 5.2, 8.0, 0.45)
    if alpha <= 0:
        return
    progress = B.smooth((t - 5.2) / 2.1)
    center = (960, 526)
    origins = [
        (180, 340, B.GREEN),
        (180, 710, B.CORAL),
        (1740, 340, B.BLUE),
        (1740, 710, B.AMBER),
    ]
    for index, (ox, oy, color) in enumerate(origins):
        delay = index * 0.05
        local = B.smooth((progress - delay) / (1 - delay))
        x = ox + (center[0] - ox) * local
        y = oy + (center[1] - oy) * local
        draw.line((ox, oy, x, y), fill=B.rgba(color, 130 * alpha * (1 - local * 0.4)), width=3)
        draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill=B.rgba(color, 245 * alpha))

    ring = 180 * (1 - progress) + 54
    draw.ellipse(
        (center[0] - ring, center[1] - ring, center[0] + ring, center[1] + ring),
        outline=B.rgba(B.GREEN, 150 * alpha * progress),
        width=3,
    )


def draw_logo_scene(draw: ImageDraw.ImageDraw, t: float) -> None:
    alpha = B.smooth((t - 6.25) / 0.8) * B.smooth((12.0 - t) / 0.5)
    if alpha <= 0:
        return

    rise = 24 * (1 - B.ease_out((t - 6.25) / 1.1))
    glow = 0.55 + 0.45 * math.sin(t * 2.1)
    mark_alpha = alpha * reveal(t, 6.35, 0.65)
    box = (908, 258 + rise, 1012, 362 + rise)
    draw.rounded_rectangle(
        box,
        radius=23,
        fill=B.rgba(B.GREEN_DARK, 215 * mark_alpha),
        outline=B.rgba(B.GREEN, (165 + 45 * glow) * mark_alpha),
        width=3,
    )
    draw.text((960, 310 + rise), "M", font=F_MARK, anchor="mm", fill=B.rgba(B.GREEN_BRIGHT, 255 * mark_alpha))

    word = "MARKOUT"
    letter_widths = [B.measure(draw, letter, F_LOGO) for letter in word]
    tracking = 19
    full_width = sum(letter_widths) + tracking * (len(word) - 1)
    cursor = 960 - full_width / 2
    for index, (letter, width) in enumerate(zip(word, letter_widths)):
        letter_alpha = alpha * reveal(t, 6.75 + index * 0.105, 0.48)
        letter_y = 430 + rise + (1 - B.ease_out((t - 6.75 - index * 0.105) / 0.55)) * 24
        draw.text((cursor, letter_y), letter, font=F_LOGO, fill=B.rgba(B.TEXT, 255 * letter_alpha))
        cursor += width + tracking

    divider_alpha = alpha * reveal(t, 7.7, 0.65)
    divider_width = 660 * B.ease_out((t - 7.7) / 0.9)
    draw.line((960 - divider_width / 2, 650, 960 + divider_width / 2, 650), fill=B.rgba(B.GREEN, 155 * divider_alpha), width=2)
    draw.text(
        (960, 704),
        "Outcome-priced liquidity",
        font=F_TAGLINE,
        anchor="mm",
        fill=B.rgba(B.TEXT, 240 * alpha * reveal(t, 8.0, 0.7)),
    )
    draw.text(
        (960, 777),
        B.tracked("Observe first / allocate after evidence"),
        font=F_STACK,
        anchor="mm",
        fill=B.rgba(B.GREEN, 230 * alpha * reveal(t, 8.45, 0.7)),
    )

    stack_alpha = alpha * reveal(t, 9.2, 0.75)
    draw.rounded_rectangle(
        (593, 858, 1327, 920),
        radius=31,
        fill=B.rgba(B.PANEL, 205 * stack_alpha),
        outline=B.rgba(B.TEXT, 35 * stack_alpha),
        width=2,
    )
    draw.text(
        (960, 889),
        B.tracked("Uniswap v4 / Pyth / Reactive Network"),
        font=F_STACK,
        anchor="mm",
        fill=B.rgba(B.MUTED, 235 * stack_alpha),
    )


def frame_at(t: float) -> Image.Image:
    frame = B.BASE.copy()
    darkener = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 88))
    frame = Image.alpha_composite(frame, darkener)
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    scan_y = int((t * 68) % HEIGHT)
    draw.rectangle((0, scan_y, WIDTH, scan_y + 2), fill=(138, 255, 173, 7))
    draw_particles(draw, t, 1.0)
    draw_market_tape(draw, t, B.smooth(t / 0.7))
    draw_signal_scene(draw, t)
    draw_convergence(draw, t)
    draw_logo_scene(draw, t)

    vignette = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    vignette_draw = ImageDraw.Draw(vignette)
    for inset in range(0, 180, 12):
        strength = int(4 + inset * 0.11)
        vignette_draw.rectangle((inset, inset, WIDTH - inset, HEIGHT - inset), outline=(0, 0, 0, strength), width=18)
    return Image.alpha_composite(Image.alpha_composite(frame, overlay), vignette).convert("RGB")


def render(audio: Path, output: Path) -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg is required")
    output.parent.mkdir(parents=True, exist_ok=True)
    command = [
        ffmpeg, "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{WIDTH}x{HEIGHT}", "-r", str(RENDER_FPS), "-i", "pipe:0",
        "-i", str(audio),
        "-map", "0:v:0", "-map", "1:a:0",
        "-t", str(DURATION), "-vf", f"fps={OUTPUT_FPS}",
        "-af", "afade=t=in:st=0:d=0.35,afade=t=out:st=10.9:d=1.1,loudnorm=I=-15:TP=-1.5:LRA=10",
        "-c:v", "libx264", "-preset", "medium", "-crf", "15", "-profile:v", "high", "-level", "4.2", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "320k", "-ar", "48000", "-movflags", "+faststart",
        str(output),
    ]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    assert process.stdin is not None
    total_frames = int(DURATION * RENDER_FPS)
    try:
        for index in range(total_frames):
            process.stdin.write(frame_at(index / RENDER_FPS).tobytes())
            if index % (RENDER_FPS * 3) == 0:
                print(f"Rendered {index / RENDER_FPS:4.0f}s / {DURATION:.0f}s", flush=True)
    finally:
        process.stdin.close()
    code = process.wait()
    if code != 0:
        raise RuntimeError(f"ffmpeg exited with status {code}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if not args.audio.is_file():
        raise FileNotFoundError(args.audio)
    render(args.audio.resolve(), args.output.resolve())
    print(f"Created {args.output.resolve()}")


if __name__ == "__main__":
    main()
