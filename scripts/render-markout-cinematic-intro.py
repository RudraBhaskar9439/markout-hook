#!/usr/bin/env python3
"""Render the 35-second MARKOUT cinematic prologue as a 1080p60 MP4."""

from __future__ import annotations

import argparse
import math
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


WIDTH = 1920
HEIGHT = 1080
RENDER_FPS = 30
OUTPUT_FPS = 60
DURATION = 35.0

INK = (8, 11, 10)
PANEL = (18, 24, 21)
PANEL_HIGH = (23, 30, 26)
TEXT = (238, 246, 240)
MUTED = (152, 165, 157)
DIM = (102, 115, 107)
GREEN = (138, 255, 173)
GREEN_BRIGHT = (184, 255, 201)
GREEN_DARK = (23, 60, 36)
AMBER = (244, 198, 106)
CORAL = (255, 142, 116)
BLUE = (130, 185, 255)

FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_MONO = "/System/Library/Fonts/SFNSMono.ttf"
FONT_SERIF_ITALIC = "/System/Library/Fonts/Supplemental/Georgia Italic.ttf"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


F_LABEL = font(FONT_MONO, 18)
F_SMALL = font(FONT_REGULAR, 22)
F_BODY = font(FONT_REGULAR, 29)
F_BODY_BOLD = font(FONT_BOLD, 28)
F_BOX_LABEL = font(FONT_MONO, 16)
F_BOX_VALUE = font(FONT_BOLD, 30)
F_H1 = font(FONT_BOLD, 78)
F_H1_SERIF = font(FONT_SERIF_ITALIC, 80)
F_HERO = font(FONT_BOLD, 120)
F_MARK = font(FONT_MONO, 24)


def clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))


def smooth(value: float) -> float:
    value = clamp(value)
    return value * value * (3.0 - 2.0 * value)


def ease_out(value: float) -> float:
    value = clamp(value)
    return 1.0 - (1.0 - value) ** 3


def scene_alpha(t: float, start: float, end: float, fade: float = 0.7) -> float:
    return smooth((t - start) / fade) * smooth((end - t) / fade)


def rgba(color: tuple[int, int, int], alpha: int | float = 255) -> tuple[int, int, int, int]:
    return (*color, int(clamp(float(alpha), 0, 255)))


def measure(draw: ImageDraw.ImageDraw, text: str, used_font: ImageFont.FreeTypeFont) -> float:
    box = draw.textbbox((0, 0), text, font=used_font)
    return float(box[2] - box[0])


def rich_line(
    draw: ImageDraw.ImageDraw,
    x: float,
    y: float,
    parts: list[tuple[str, ImageFont.FreeTypeFont, tuple[int, int, int]]],
    alpha: float,
    center: bool = False,
) -> None:
    widths = [measure(draw, text, used_font) for text, used_font, _ in parts]
    cursor = x - sum(widths) / 2 if center else x
    for width, (text, used_font, color) in zip(widths, parts):
        draw.text((cursor, y), text, font=used_font, fill=rgba(color, 255 * alpha))
        cursor += width


def tracked(text: str) -> str:
    return "  ".join(text.upper())


def rounded_box(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    fill: tuple[int, int, int],
    outline: tuple[int, int, int],
    alpha: float,
    radius: int = 20,
    width: int = 2,
) -> None:
    draw.rounded_rectangle(
        box,
        radius=radius,
        fill=rgba(fill, 220 * alpha),
        outline=rgba(outline, 150 * alpha),
        width=width,
    )


def node(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    radius: float,
    color: tuple[int, int, int],
    alpha: float,
    pulse: float = 0.0,
) -> None:
    cx, cy = center
    if pulse > 0:
        outer = radius + 10 + 10 * pulse
        draw.ellipse(
            (cx - outer, cy - outer, cx + outer, cy + outer),
            outline=rgba(color, (90 - 40 * pulse) * alpha),
            width=2,
        )
    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=rgba((10, 18, 13), 245 * alpha),
        outline=rgba(color, 220 * alpha),
        width=3,
    )
    draw.ellipse(
        (cx - 6, cy - 6, cx + 6, cy + 6),
        fill=rgba(color, 255 * alpha),
    )


def make_background() -> Image.Image:
    yy, xx = np.mgrid[0:HEIGHT, 0:WIDTH]
    base = np.zeros((HEIGHT, WIDTH, 3), dtype=np.float32)
    base[:, :, :] = np.array(INK, dtype=np.float32)

    glow_one = np.exp(-(((xx - 1530) / 520) ** 2 + ((yy - 90) / 460) ** 2))
    glow_two = np.exp(-(((xx - 120) / 620) ** 2 + ((yy - 760) / 580) ** 2))
    base += glow_one[:, :, None] * np.array([8, 32, 15], dtype=np.float32)
    base += glow_two[:, :, None] * np.array([2, 10, 7], dtype=np.float32)

    rng = np.random.default_rng(20260828)
    noise = rng.normal(0, 1.5, (HEIGHT, WIDTH, 1)).astype(np.float32)
    base += noise
    base = np.clip(base, 0, 255).astype(np.uint8)
    image = Image.fromarray(base, mode="RGB").convert("RGBA")

    grid = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid)
    for x in range(0, WIDTH, 48):
        grid_draw.line((x, 0, x, HEIGHT), fill=(221, 255, 231, 9), width=1)
    for y in range(0, HEIGHT, 48):
        grid_draw.line((0, y, WIDTH, y), fill=(221, 255, 231, 9), width=1)
    return Image.alpha_composite(image, grid)


BASE = make_background()


def header(draw: ImageDraw.ImageDraw, t: float) -> None:
    alpha = smooth(t / 1.2)
    draw.rounded_rectangle(
        (68, 54, 110, 96),
        radius=10,
        fill=rgba(GREEN_DARK, 175 * alpha),
        outline=rgba(GREEN, 170 * alpha),
        width=2,
    )
    draw.text((82, 63), "M", font=F_MARK, fill=rgba(GREEN_BRIGHT, 255 * alpha))
    draw.text((130, 61), "MARKOUT", font=F_BODY_BOLD, fill=rgba(TEXT, 245 * alpha))
    draw.text((130, 94), tracked("Outcome-priced liquidity"), font=F_BOX_LABEL, fill=rgba(DIM, 225 * alpha))
    draw.text((1848, 63), tracked("UHI10 / PROLOGUE"), font=F_BOX_LABEL, anchor="ra", fill=rgba(DIM, 225 * alpha))
    draw.line((68, 126, 1852, 126), fill=rgba(TEXT, 24 * alpha), width=1)


def footer(draw: ImageDraw.ImageDraw, t: float) -> None:
    alpha = smooth(t / 1.0)
    progress = clamp(t / DURATION)
    y = 1004
    draw.line((68, y, 1852, y), fill=rgba(TEXT, 30 * alpha), width=2)
    draw.line((68, y, 68 + 1784 * progress, y), fill=rgba(GREEN, 180 * alpha), width=3)
    draw.text((68, 1021), "A PROTOCOL STORY IN SIX MOMENTS", font=F_BOX_LABEL, fill=rgba(DIM, 190 * alpha))
    draw.text((1740, 1021), f"{t:04.1f}s", font=F_BOX_LABEL, fill=rgba(DIM, 190 * alpha))


def scene_one(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 0.3, 6.0
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    p = ease_out((t - start) / 1.2)
    y_offset = 28 * (1 - p)
    draw.text((104, 218 + y_offset), tracked("One ordinary swap"), font=F_LABEL, fill=rgba(GREEN, 230 * alpha))
    rich_line(draw, 104, 278 + y_offset, [
        ("A trader pays", F_H1, TEXT),
        (" before", F_H1_SERIF, GREEN),
    ], alpha)
    draw.text((104, 370 + y_offset), "the pool knows the outcome.", font=F_H1, fill=rgba(TEXT, 255 * alpha))
    draw.text((108, 492 + y_offset), "Execution is instant. Trade quality is not.", font=F_BODY, fill=rgba(MUTED, 230 * alpha))

    line_y = 714
    draw.line((260, line_y, 1660, line_y), fill=rgba(TEXT, 44 * alpha), width=2)
    progress = smooth((t - 1.5) / 2.8)
    draw.line((260, line_y, 260 + 980 * progress, line_y), fill=rgba(GREEN, 190 * alpha), width=3)
    node(draw, (340, line_y), 20, GREEN, alpha, 0.5 + 0.5 * math.sin(t * 4))
    draw.text((292, line_y + 42), "SWAP MINED", font=F_BOX_LABEL, fill=rgba(GREEN, 220 * alpha))
    if progress > 0.58:
        unknown_alpha = alpha * smooth((progress - 0.58) / 0.3)
        node(draw, (1240, line_y), 20, AMBER, unknown_alpha, 0.5 + 0.5 * math.sin(t * 3))
        draw.text((1132, line_y + 42), "OUTCOME UNKNOWN", font=F_BOX_LABEL, fill=rgba(AMBER, 220 * unknown_alpha))
    draw.text((260, 844), "T+0", font=F_BOX_LABEL, fill=rgba(DIM, 190 * alpha))
    draw.text((1544, 844), "T+5 MIN", font=F_BOX_LABEL, fill=rgba(DIM, 190 * alpha))


def scene_two(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 5.4, 11.6
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    p = ease_out((t - start) / 1.0)
    y_offset = 24 * (1 - p)
    draw.text((104, 206 + y_offset), tracked("The blind spot"), font=F_LABEL, fill=rgba(AMBER, 230 * alpha))
    draw.text((104, 268 + y_offset), "The fee is final.", font=F_H1, fill=rgba(TEXT, 255 * alpha))
    rich_line(draw, 104, 362 + y_offset, [
        ("The outcome ", F_H1, TEXT),
        ("isn't.", F_H1_SERIF, GREEN),
    ], alpha)

    cards = [
        (104, "EXECUTION", "Swap confirmed", GREEN),
        (632, "FEE", "Charged now", AMBER),
        (1160, "MARKOUT", "Arrives later", BLUE),
    ]
    reveal = smooth((t - 6.3) / 1.6)
    for index, (x, label, value, color) in enumerate(cards):
        card_alpha = alpha * smooth((reveal - index * 0.18) / 0.45)
        rounded_box(draw, (x, 596, x + 420, 790), PANEL, color, card_alpha)
        draw.text((x + 32, 626), tracked(label), font=F_BOX_LABEL, fill=rgba(DIM, 230 * card_alpha))
        draw.text((x + 32, 688), value, font=F_BOX_VALUE, fill=rgba(color, 255 * card_alpha))
        draw.text((x + 32, 746), ["T+0", "T+0", "T+5m"][index], font=F_BOX_LABEL, fill=rgba(MUTED, 210 * card_alpha))

    draw.text((104, 862), "One decision is made before the information needed to price it exists.", font=F_SMALL, fill=rgba(MUTED, 215 * alpha))


def scene_three(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 11.0, 17.7
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    draw.text((104, 196), tracked("Same swap. Different information."), font=F_LABEL, fill=rgba(BLUE, 230 * alpha))
    rich_line(draw, 960, 265, [
        ("Good flow or ", F_H1, TEXT),
        ("adverse selection?", F_H1_SERIF, GREEN),
    ], alpha, center=True)

    reveal = smooth((t - 11.8) / 1.6)
    left_alpha = alpha * smooth(reveal / 0.62)
    right_alpha = alpha * smooth((reveal - 0.24) / 0.62)
    connector_alpha = alpha * smooth((reveal - 0.45) / 0.4)
    draw.line((580, 668, 1340, 668), fill=rgba(TEXT, 42 * connector_alpha), width=2)
    node(draw, (580, 668), 64, GREEN, left_alpha, 0.5 + 0.5 * math.sin(t * 3))
    node(draw, (1340, 668), 64, CORAL, right_alpha, 0.5 + 0.5 * math.sin(t * 2.7))
    draw.text((470, 772), tracked("Benign flow"), font=F_LABEL, fill=rgba(GREEN, 230 * left_alpha))
    draw.text((1202, 772), tracked("Informed flow"), font=F_LABEL, fill=rgba(CORAL, 230 * right_alpha))
    draw.rounded_rectangle((920, 628, 1000, 708), radius=18, fill=rgba(PANEL_HIGH, 235 * connector_alpha), outline=rgba(AMBER, 170 * connector_alpha), width=2)
    draw.text((946, 638), "?", font=F_H1_SERIF, fill=rgba(AMBER, 255 * connector_alpha))
    draw.text((960, 884), "A static fee treats both alike.", font=F_BODY, anchor="mm", fill=rgba(MUTED, 230 * alpha))


def scene_four(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 17.0, 24.7
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    draw.text((104, 184), tracked("Five minutes later"), font=F_LABEL, fill=rgba(GREEN, 230 * alpha))
    rich_line(draw, 104, 246, [
        ("Evidence becomes ", F_H1, TEXT),
        ("actionable.", F_H1_SERIF, GREEN),
    ], alpha)
    draw.text((108, 358), "Signed evidence moves through one authenticated, replay-safe lifecycle.", font=F_BODY, fill=rgba(MUTED, 225 * alpha))

    nodes = [
        (220, "UNISWAP V4", "SWAP", GREEN),
        (700, "PYTH", "PROVE", BLUE),
        (1180, "REACTIVE", "ACT", GREEN_BRIGHT),
        (1660, "MARKOUT", "ALLOCATE", AMBER),
    ]
    y = 662
    path_progress = smooth((t - 18.1) / 4.4)
    draw.line((220, y, 1660, y), fill=rgba(TEXT, 36 * alpha), width=3)
    draw.line((220, y, 220 + 1440 * path_progress, y), fill=rgba(GREEN, 190 * alpha), width=4)
    for index, (x, label, action, color) in enumerate(nodes):
        threshold = index / 3
        reveal = smooth((path_progress - threshold + 0.09) / 0.18)
        node_alpha = alpha * reveal
        radius = 40 if index != 2 else 54
        node(draw, (x, y), radius, color, node_alpha, 0.5 + 0.5 * math.sin(t * 3 + index))
        draw.text((x, y + 92), label, font=F_BODY_BOLD, anchor="mm", fill=rgba(TEXT, 245 * node_alpha))
        draw.text((x, y + 132), tracked(action), font=F_BOX_LABEL, anchor="mm", fill=rgba(color, 230 * node_alpha))
    draw.text((960, 914), "PYTH PROVES THE EVENT. REACTIVE NETWORK TURNS IT INTO ACTION.", font=F_LABEL, anchor="mm", fill=rgba(GREEN, 225 * alpha))


def scene_five(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 24.0, 30.8
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    draw.text((104, 184), tracked("Outcome-priced liquidity"), font=F_LABEL, fill=rgba(GREEN, 230 * alpha))
    draw.text((104, 246), "Return what was not earned.", font=F_H1, fill=rgba(TEXT, 255 * alpha))
    rich_line(draw, 104, 340, [
        ("Retain what ", F_H1, TEXT),
        ("protects LPs.", F_H1_SERIF, GREEN),
    ], alpha)

    reveal = smooth((t - 24.9) / 1.6)
    left_alpha = alpha * smooth(reveal / 0.75)
    right_alpha = alpha * smooth((reveal - 0.22) / 0.68)
    rounded_box(draw, (104, 590, 900, 846), PANEL, GREEN, left_alpha, radius=24)
    draw.text((144, 624), tracked("Good flow"), font=F_LABEL, fill=rgba(GREEN, 240 * left_alpha))
    draw.text((144, 684), "18 bps final fee", font=F_BOX_VALUE, fill=rgba(TEXT, 255 * left_alpha))
    draw.text((144, 748), "Provisional surcharge returned", font=F_BODY, fill=rgba(MUTED, 230 * left_alpha))

    rounded_box(draw, (1020, 590, 1816, 846), PANEL, AMBER, right_alpha, radius=24)
    draw.text((1060, 624), tracked("Adverse selection"), font=F_LABEL, fill=rgba(AMBER, 240 * right_alpha))
    draw.text((1060, 684), "Up to 68 bps", font=F_BOX_VALUE, fill=rgba(TEXT, 255 * right_alpha))
    draw.text((1060, 748), "Protection retained for LPs", font=F_BODY, fill=rgba(MUTED, 230 * right_alpha))


def scene_six(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 30.1, 35.0
    alpha = scene_alpha(t, start, end, fade=0.8)
    if alpha <= 0:
        return
    p = ease_out((t - start) / 1.1)
    scale_offset = 18 * (1 - p)
    draw.rounded_rectangle((910, 214 - scale_offset, 1010, 314 - scale_offset), radius=24, fill=rgba(GREEN_DARK, 210 * alpha), outline=rgba(GREEN, 190 * alpha), width=3)
    draw.text((960, 264 - scale_offset), "M", font=F_H1, anchor="mm", fill=rgba(GREEN_BRIGHT, 255 * alpha))
    draw.text((960, 430 - scale_offset), "MARKOUT", font=F_HERO, anchor="mm", fill=rgba(TEXT, 255 * alpha))
    rich_line(draw, 960, 520 - scale_offset, [
        ("Fees should follow ", F_H1, TEXT),
        ("outcomes.", F_H1_SERIF, GREEN),
    ], alpha, center=True)
    draw.text((960, 710 - scale_offset), "Not fear.", font=F_H1, anchor="mm", fill=rgba(TEXT, 255 * alpha))
    draw.text((960, 822), tracked("Uniswap v4  x  Pyth  x  Reactive Network"), font=F_LABEL, anchor="mm", fill=rgba(MUTED, 225 * alpha))
    draw.text((960, 886), "THE ARCHITECTURE STARTS HERE", font=F_BOX_LABEL, anchor="mm", fill=rgba(GREEN, 220 * alpha))


def frame_at(t: float) -> Image.Image:
    frame = BASE.copy()
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    scan_y = int((t * 44) % HEIGHT)
    draw.rectangle((0, scan_y, WIDTH, scan_y + 2), fill=(138, 255, 173, 7))
    for index in range(18):
        x = (113 * index + int(t * (8 + index % 4))) % WIDTH
        y = (79 * index + int(30 * math.sin(t * 0.4 + index))) % HEIGHT
        draw.ellipse((x - 1, y - 1, x + 1, y + 1), fill=(184, 255, 201, 28))

    header(draw, t)
    footer(draw, t)
    scene_one(draw, t)
    scene_two(draw, t)
    scene_three(draw, t)
    scene_four(draw, t)
    scene_five(draw, t)
    scene_six(draw, t)
    return Image.alpha_composite(frame, overlay).convert("RGB")


def render(audio: Path, output: Path) -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg is required to render the video")
    output.parent.mkdir(parents=True, exist_ok=True)

    command = [
        ffmpeg,
        "-y",
        "-f", "rawvideo",
        "-pix_fmt", "rgb24",
        "-s", f"{WIDTH}x{HEIGHT}",
        "-r", str(RENDER_FPS),
        "-i", "pipe:0",
        "-i", str(audio),
        "-map", "0:v:0",
        "-map", "1:a:0",
        "-t", str(DURATION),
        "-vf", f"fps={OUTPUT_FPS}",
        "-af", "afade=t=in:st=0:d=0.7,afade=t=out:st=32.5:d=2.5,loudnorm=I=-14:TP=-1.5:LRA=11",
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "16",
        "-profile:v", "high",
        "-level", "4.2",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "320k",
        "-ar", "48000",
        "-movflags", "+faststart",
        str(output),
    ]

    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    assert process.stdin is not None
    total_frames = int(DURATION * RENDER_FPS)
    try:
        for index in range(total_frames):
            process.stdin.write(frame_at(index / RENDER_FPS).tobytes())
            if index % (RENDER_FPS * 5) == 0:
                print(f"Rendered {index / RENDER_FPS:4.0f}s / {DURATION:.0f}s", flush=True)
    finally:
        process.stdin.close()
    return_code = process.wait()
    if return_code != 0:
        raise RuntimeError(f"ffmpeg exited with status {return_code}")


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
    try:
        main()
    except BrokenPipeError:
        print("ffmpeg closed the video pipe unexpectedly", file=sys.stderr)
        raise
