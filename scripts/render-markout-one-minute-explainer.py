#!/usr/bin/env python3
"""Render the evidence-aligned one-minute MARKOUT project explainer."""

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
DURATION = 60.0

F_KICKER = B.font(B.FONT_MONO, 18)
F_SMALL = B.font(B.FONT_REGULAR, 23)
F_BODY = B.font(B.FONT_REGULAR, 28)
F_BODY_BOLD = B.font(B.FONT_BOLD, 28)
F_H1 = B.font(B.FONT_BOLD, 72)
F_H1_SERIF = B.font(B.FONT_SERIF_ITALIC, 74)
F_H2 = B.font(B.FONT_BOLD, 50)
F_H3 = B.font(B.FONT_BOLD, 36)
F_NUMBER = B.font(B.FONT_BOLD, 58)
F_MONO = B.font(B.FONT_MONO, 17)
F_MONO_SMALL = B.font(B.FONT_MONO, 14)
F_LOGO = B.font(B.FONT_BOLD, 112)


def scene_alpha(t: float, start: float, end: float, fade: float = 0.65) -> float:
    return B.scene_alpha(t, start, end, fade)


def reveal(t: float, start: float, duration: float = 0.9) -> float:
    return B.smooth((t - start) / duration)


def header(draw: ImageDraw.ImageDraw, t: float) -> None:
    alpha = B.smooth(t / 0.9)
    draw.rounded_rectangle(
        (68, 54, 110, 96),
        radius=10,
        fill=B.rgba(B.GREEN_DARK, 175 * alpha),
        outline=B.rgba(B.GREEN, 170 * alpha),
        width=2,
    )
    draw.text((82, 63), "M", font=B.F_MARK, fill=B.rgba(B.GREEN_BRIGHT, 255 * alpha))
    draw.text((130, 61), "MARKOUT", font=B.F_BODY_BOLD, fill=B.rgba(B.TEXT, 245 * alpha))
    draw.text((130, 94), B.tracked("Outcome-priced liquidity"), font=B.F_BOX_LABEL, fill=B.rgba(B.DIM, 225 * alpha))
    draw.text((1848, 63), B.tracked("UHI10 / 60-second explainer"), font=B.F_BOX_LABEL, anchor="ra", fill=B.rgba(B.DIM, 225 * alpha))
    draw.line((68, 126, 1852, 126), fill=B.rgba(B.TEXT, 24 * alpha), width=1)


def footer(draw: ImageDraw.ImageDraw, t: float) -> None:
    alpha = B.smooth(t / 0.8)
    y = 1004
    progress = B.clamp(t / DURATION)
    draw.line((68, y, 1852, y), fill=B.rgba(B.TEXT, 30 * alpha), width=2)
    draw.line((68, y, 68 + 1784 * progress, y), fill=B.rgba(B.GREEN, 190 * alpha), width=3)
    phases = [
        (68, "MARKET PROBLEM"),
        (690, "MARKOUT MECHANISM"),
        (1350, "OUTCOME + PROOF"),
    ]
    for x, label in phases:
        draw.text((x, 1021), label, font=F_MONO_SMALL, fill=B.rgba(B.DIM, 200 * alpha))
    draw.text((1848, 1021), f"{t:04.1f}s", font=F_MONO_SMALL, anchor="ra", fill=B.rgba(B.DIM, 200 * alpha))


def title(draw: ImageDraw.ImageDraw, kicker: str, line_one: str, line_two: str | None, alpha: float, accent: tuple[int, int, int] = B.GREEN) -> None:
    draw.text((104, 185), B.tracked(kicker), font=F_KICKER, fill=B.rgba(accent, 230 * alpha))
    draw.text((104, 246), line_one, font=F_H1, fill=B.rgba(B.TEXT, 255 * alpha))
    if line_two:
        draw.text((104, 330), line_two, font=F_H1, fill=B.rgba(B.TEXT, 255 * alpha))


def fee_pill(draw: ImageDraw.ImageDraw, x: float, y: float, text: str, color: tuple[int, int, int], alpha: float) -> None:
    draw.rounded_rectangle((x, y, x + 170, y + 58), radius=29, fill=B.rgba(color, 34 * alpha), outline=B.rgba(color, 170 * alpha), width=2)
    draw.text((x + 85, y + 29), text, font=F_BODY_BOLD, anchor="mm", fill=B.rgba(color, 255 * alpha))


def price_chart(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], toxic: bool, alpha: float) -> None:
    x1, y1, x2, y2 = box
    draw.rounded_rectangle(box, radius=18, fill=B.rgba(B.PANEL, 220 * alpha), outline=B.rgba(B.TEXT, 28 * alpha), width=2)
    for row in range(1, 4):
        y = y1 + (y2 - y1) * row / 4
        draw.line((x1 + 24, y, x2 - 24, y), fill=B.rgba(B.TEXT, 18 * alpha), width=1)
    points = []
    samples = 18
    for index in range(samples):
        p = index / (samples - 1)
        x = x1 + 30 + p * (x2 - x1 - 60)
        if toxic:
            move = 0.05 * math.sin(index * 0.9) + (0.48 * max(0, p - 0.52) / 0.48)
            y = y1 + 122 - move * 150
        else:
            y = y1 + 92 + 10 * math.sin(index * 0.85)
        points.append((x, y))
    color = B.CORAL if toxic else B.GREEN
    draw.line(points, fill=B.rgba(color, 235 * alpha), width=4, joint="curve")
    marker_x = x1 + 30 + 0.52 * (x2 - x1 - 60)
    draw.line((marker_x, y1 + 28, marker_x, y2 - 28), fill=B.rgba(B.AMBER, 85 * alpha), width=2)
    draw.text((marker_x + 10, y2 - 48), "SWAP", font=F_MONO_SMALL, fill=B.rgba(B.AMBER, 210 * alpha))


def scene_one(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 0.2, 6.3
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    p = reveal(t, start, 1.0)
    offset = 24 * (1 - p)
    draw.text((960, 242 + offset), B.tracked("Markout in sixty seconds"), font=F_KICKER, anchor="mm", fill=B.rgba(B.GREEN, 235 * alpha))
    draw.text((960, 375 + offset), "Why should every trader", font=F_H1, anchor="mm", fill=B.rgba(B.TEXT, 255 * alpha))
    B.rich_line(draw, 960, 454 + offset, [
        ("pay the ", F_H1, B.TEXT),
        ("same fee?", F_H1_SERIF, B.GREEN),
    ], alpha, center=True)
    draw.text((960, 586), "Trade impact is only visible after execution.", font=F_BODY, anchor="mm", fill=B.rgba(B.MUTED, 230 * alpha))
    reveal_pills = reveal(t, 1.5, 1.2)
    fee_pill(draw, 590, 718, "30 bps", B.GREEN, alpha * reveal_pills)
    draw.text((790, 747), "for benign flow", font=F_BODY, fill=B.rgba(B.MUTED, 220 * alpha * reveal_pills))
    fee_pill(draw, 1120, 718, "30 bps", B.CORAL, alpha * reveal_pills)
    draw.text((1320, 747), "for informed flow", font=F_BODY, fill=B.rgba(B.MUTED, 220 * alpha * reveal_pills))


def scene_two(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 5.7, 13.6
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    title(draw, "The current market", "AMMs decide the full fee", "before the outcome is known.", alpha, B.AMBER)
    draw.text((108, 438), "A fixed fee sees the swap, but not what happens to the price afterward.", font=F_BODY, fill=B.rgba(B.MUTED, 225 * alpha))
    reveal_cards = reveal(t, 6.7, 1.6)
    cards = [
        (104, "BENIGN TRADER", "Pays the fixed fee", "Price stays near execution", B.GREEN),
        (960, "INFORMED TRADER", "Pays the same fixed fee", "Price moves against the LP", B.CORAL),
    ]
    for index, (x, label, value, detail, color) in enumerate(cards):
        card_alpha = alpha * B.smooth((reveal_cards - index * 0.18) / 0.65)
        B.rounded_box(draw, (x, 586, x + 756, 842), B.PANEL, color, card_alpha, radius=24)
        draw.text((x + 38, 624), B.tracked(label), font=F_KICKER, fill=B.rgba(color, 235 * card_alpha))
        draw.text((x + 38, 684), value, font=F_H3, fill=B.rgba(B.TEXT, 250 * card_alpha))
        draw.text((x + 38, 752), detail, font=F_BODY, fill=B.rgba(B.MUTED, 225 * card_alpha))
        fee_pill(draw, x + 540, 684, "30 bps", color, card_alpha)
    draw.text((960, 910), "Same fee. Different economic impact.", font=F_BODY_BOLD, anchor="mm", fill=B.rgba(B.AMBER, 235 * alpha))


def scene_three(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 13.0, 21.6
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    title(draw, "Why this is inefficient", "Good flow is overcharged.", "Adverse selection is underpriced.", alpha, B.CORAL)
    chart_alpha = alpha * reveal(t, 14.0, 1.2)
    price_chart(draw, (104, 548, 864, 812), False, chart_alpha)
    price_chart(draw, (1056, 548, 1816, 812), True, chart_alpha)
    draw.text((484, 854), "BENIGN FLOW", font=F_KICKER, anchor="mm", fill=B.rgba(B.GREEN, 230 * chart_alpha))
    draw.text((1436, 854), "ADVERSE FLOW", font=F_KICKER, anchor="mm", fill=B.rgba(B.CORAL, 230 * chart_alpha))
    draw.text((484, 900), "Trader paid more than needed", font=F_SMALL, anchor="mm", fill=B.rgba(B.MUTED, 220 * chart_alpha))
    draw.text((1436, 900), "LP absorbed directional loss", font=F_SMALL, anchor="mm", fill=B.rgba(B.MUTED, 220 * chart_alpha))


def scene_four(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 21.0, 30.6
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    title(draw, "The MARKOUT solution", "Split the fee into a base", "and a refundable escrow.", alpha, B.GREEN)
    draw.text((108, 438), "The trader deposits protection now. The protocol decides the final amount after evidence.", font=F_BODY, fill=B.rgba(B.MUTED, 225 * alpha))
    bar_alpha = alpha * reveal(t, 22.2, 1.4)
    x1, y1, x2, y2 = 104, 616, 1816, 746
    draw.rounded_rectangle((x1, y1, x2, y2), radius=26, fill=B.rgba(B.PANEL, 230 * bar_alpha), outline=B.rgba(B.TEXT, 32 * bar_alpha), width=2)
    base_width = 540
    draw.rounded_rectangle((x1, y1, x1 + base_width, y2), radius=26, fill=B.rgba(B.GREEN, 38 * bar_alpha), outline=B.rgba(B.GREEN, 185 * bar_alpha), width=2)
    draw.text((x1 + 36, y1 + 28), B.tracked("Permanent base"), font=F_KICKER, fill=B.rgba(B.GREEN, 235 * bar_alpha))
    draw.text((x1 + 36, y1 + 72), "18 bps", font=F_NUMBER, fill=B.rgba(B.TEXT, 255 * bar_alpha))
    draw.rounded_rectangle((x1 + base_width + 16, y1, x2, y2), radius=26, fill=B.rgba(B.AMBER, 28 * bar_alpha), outline=B.rgba(B.AMBER, 170 * bar_alpha), width=2)
    draw.text((x1 + base_width + 52, y1 + 28), B.tracked("Provisional escrow"), font=F_KICKER, fill=B.rgba(B.AMBER, 235 * bar_alpha))
    draw.text((x1 + base_width + 52, y1 + 72), "50 bps", font=F_NUMBER, fill=B.rgba(B.TEXT, 255 * bar_alpha))
    draw.text((x1 + base_width + 360, y1 + 86), "Not final", font=F_BODY_BOLD, fill=B.rgba(B.AMBER, 240 * bar_alpha))
    draw.text((960, 842), "The escrow can be returned to the trader or retained for LP protection.", font=F_BODY, anchor="mm", fill=B.rgba(B.MUTED, 230 * bar_alpha))
    draw.text((960, 900), "INITIAL CHARGE: 18 BPS BASE + 50 BPS PROVISIONAL", font=F_MONO, anchor="mm", fill=B.rgba(B.GREEN, 220 * bar_alpha))


def scene_five(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 30.0, 41.5
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    title(draw, "How it works", "One swap. Five verifiable steps.", None, alpha, B.BLUE)
    draw.text((108, 356), "No operator gets to choose the winner. Contracts apply one deterministic rule.", font=F_BODY, fill=B.rgba(B.MUTED, 225 * alpha))
    nodes = [
        (180, "1", "SWAP", "Unichain v4", B.GREEN),
        (570, "2", "WAIT", "5-minute window", B.AMBER),
        (960, "3", "PROVE", "Pyth evidence", B.BLUE),
        (1350, "4", "REACT", "11s callback live", B.GREEN_BRIGHT),
        (1740, "5", "ALLOCATE", "MARKOUT hook", B.AMBER),
    ]
    y = 664
    path_progress = B.smooth((t - 31.1) / 6.0)
    draw.line((180, y, 1740, y), fill=B.rgba(B.TEXT, 38 * alpha), width=3)
    draw.line((180, y, 180 + 1560 * path_progress, y), fill=B.rgba(B.GREEN, 190 * alpha), width=4)
    for index, (x, number, action, detail, color) in enumerate(nodes):
        threshold = index / 4
        node_alpha = alpha * B.smooth((path_progress - threshold + 0.1) / 0.18)
        radius = 48 if action != "REACT" else 60
        B.node(draw, (x, y), radius, color, node_alpha, 0.5 + 0.5 * math.sin(t * 3 + index))
        draw.text((x, y), number, font=F_BODY_BOLD, anchor="mm", fill=B.rgba(B.TEXT, 255 * node_alpha))
        draw.text((x, y + 100), action, font=F_BODY_BOLD, anchor="mm", fill=B.rgba(B.TEXT, 245 * node_alpha))
        draw.text((x, y + 142), detail, font=F_MONO_SMALL, anchor="mm", fill=B.rgba(color, 230 * node_alpha))
    draw.text((960, 874), "PYTH: SIGNED DELAYED EVIDENCE", font=F_MONO_SMALL, anchor="mm", fill=B.rgba(B.BLUE, 225 * alpha))
    draw.text((960, 908), "REACTIVE NETWORK: LIVE EVENT-TO-ACTION TRANSPORT", font=F_MONO_SMALL, anchor="mm", fill=B.rgba(B.GREEN, 235 * alpha))
    draw.text((960, 942), "INDEPENDENT FALLBACK: 4 PUBLIC ECONOMIC LIFECYCLES", font=F_MONO_SMALL, anchor="mm", fill=B.rgba(B.AMBER, 225 * alpha))


def scene_six(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 40.5, 48.6
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    title(draw, "The outcome sets the fee", "Direction matters.", "Volatility alone is not enough.", alpha, B.GREEN)
    draw.text((108, 438), "MARKOUT compares the execution price with the delayed reference price.", font=F_BODY, fill=B.rgba(B.MUTED, 225 * alpha))
    cards = [
        (104, "NEGATIVE / IMPROVING MARKOUT", "Return escrow", "40% below the fixed 30 bps fee", "Trader rewarded", B.GREEN),
        (960, "POSITIVE / ADVERSE MARKOUT", "Retain protection", "Up to 100% of escrow retained", "LP reserve protected", B.AMBER),
    ]
    cards_reveal = reveal(t, 42.0, 1.5)
    for index, (x, label, action, detail, footer_text, color) in enumerate(cards):
        card_alpha = alpha * B.smooth((cards_reveal - index * 0.18) / 0.65)
        B.rounded_box(draw, (x, 574, x + 756, 862), B.PANEL, color, card_alpha, radius=24)
        draw.text((x + 38, 612), B.tracked(label), font=F_MONO_SMALL, fill=B.rgba(color, 235 * card_alpha))
        draw.text((x + 38, 664), action, font=F_H2, fill=B.rgba(B.TEXT, 255 * card_alpha))
        draw.text((x + 38, 746), detail, font=F_BODY, fill=B.rgba(B.MUTED, 230 * card_alpha))
        draw.text((x + 38, 808), footer_text, font=F_BODY_BOLD, fill=B.rgba(color, 240 * card_alpha))
    draw.text((960, 920), "The provisional 50 bps is allocated proportionally, not automatically charged in full.", font=F_SMALL, anchor="mm", fill=B.rgba(B.MUTED, 225 * alpha))


def scene_seven(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 47.9, 56.1
    alpha = scene_alpha(t, start, end)
    if alpha <= 0:
        return
    title(draw, "Research that can fail", "Controlled result.", "Real-data challenge.", alpha, B.GREEN)
    draw.text(
        (108, 438),
        "The same five-minute outcome logic is tested under two explicitly different evidence boundaries.",
        font=F_BODY,
        fill=B.rgba(B.MUTED, 225 * alpha),
    )

    controlled_alpha = alpha * reveal(t, 48.7, 1.0)
    historical_alpha = alpha * reveal(t, 49.3, 1.0)
    left = (104, 536, 930, 910)
    right = (990, 536, 1816, 910)
    B.rounded_box(draw, left, B.PANEL, B.BLUE, controlled_alpha, radius=24)
    B.rounded_box(draw, right, B.PANEL, B.GREEN, historical_alpha, radius=24)

    draw.text((142, 570), B.tracked("CONTROLLED MECHANISM STUDY"), font=F_MONO_SMALL, fill=B.rgba(B.BLUE, 235 * controlled_alpha))
    draw.text((142, 612), "768 trades  /  $1.999M", font=F_H3, fill=B.rgba(B.TEXT, 255 * controlled_alpha))
    draw.text((142, 662), "Frozen seeded experiment", font=F_SMALL, fill=B.rgba(B.MUTED, 225 * controlled_alpha))
    controlled_metrics = [
        (142, "-8.58%", "benign fee"),
        (410, "-40%", "improving fee"),
        (676, "+21.87%", "modeled LP net"),
    ]
    for x, value, label in controlled_metrics:
        metric_color = B.BLUE if value.startswith("+") else B.GREEN
        draw.text((x, 732), value, font=F_H3, fill=B.rgba(metric_color, 250 * controlled_alpha))
        draw.text((x, 782), label, font=F_MONO_SMALL, fill=B.rgba(B.TEXT, 225 * controlled_alpha))
    draw.line((142, 826, 892, 826), fill=B.rgba(B.TEXT, 30 * controlled_alpha), width=2)
    draw.text((142, 852), "MODELED VS FIXED 30 BPS", font=F_MONO_SMALL, fill=B.rgba(B.DIM, 225 * controlled_alpha))
    draw.text((142, 880), "Result depends on declared synthetic assumptions", font=F_MONO_SMALL, fill=B.rgba(B.MUTED, 215 * controlled_alpha))

    draw.text((1028, 570), B.tracked("HISTORICAL ROBUSTNESS REPLAY"), font=F_MONO_SMALL, fill=B.rgba(B.GREEN, 235 * historical_alpha))
    draw.text((1028, 612), "251 real swaps  /  $3.188M", font=F_H3, fill=B.rgba(B.TEXT, 255 * historical_alpha))
    draw.text((1028, 670), "18.00  <  29.02  <  39.14 bps", font=F_H3, fill=B.rgba(B.GREEN, 250 * historical_alpha))
    draw.text((1028, 720), "FAVORABLE     NEAR-ZERO     ADVERSE", font=F_MONO_SMALL, fill=B.rgba(B.MUTED, 225 * historical_alpha))
    draw.line((1028, 758, 1778, 758), fill=B.rgba(B.TEXT, 30 * historical_alpha), width=2)
    draw.text((1028, 784), "DIRECTIONAL ORDERING SURVIVED", font=F_BODY_BOLD, fill=B.rgba(B.GREEN, 245 * historical_alpha))
    draw.text((1028, 830), "-0.39%", font=F_H3, fill=B.rgba(B.AMBER, 250 * historical_alpha))
    draw.text((1170, 837), "aggregate LP net vs fixed", font=F_SMALL, fill=B.rgba(B.TEXT, 230 * historical_alpha))
    draw.text((1028, 880), "Aggregate synthetic gain did not generalize", font=F_MONO_SMALL, fill=B.rgba(B.AMBER, 220 * historical_alpha))
    draw.text(
        (960, 950),
        "SYNTHETIC RESULT AND HISTORICAL NEGATIVE RESULT ARE REPORTED SIDE BY SIDE",
        font=F_MONO_SMALL,
        anchor="mm",
        fill=B.rgba(B.DIM, 225 * alpha),
    )


def scene_eight(draw: ImageDraw.ImageDraw, t: float) -> None:
    start, end = 55.4, 60.0
    alpha = scene_alpha(t, start, end, fade=0.55)
    if alpha <= 0:
        return
    p = B.ease_out((t - start) / 0.8)
    offset = 18 * (1 - p)
    draw.rounded_rectangle((918, 158 - offset, 1002, 242 - offset), radius=20, fill=B.rgba(B.GREEN_DARK, 210 * alpha), outline=B.rgba(B.GREEN, 190 * alpha), width=3)
    draw.text((960, 200 - offset), "M", font=F_NUMBER, anchor="mm", fill=B.rgba(B.GREEN_BRIGHT, 255 * alpha))
    draw.text((960, 334 - offset), "MARKOUT", font=F_LOGO, anchor="mm", fill=B.rgba(B.TEXT, 255 * alpha))
    draw.text((960, 454 - offset), "Observe first.", font=F_H1, anchor="mm", fill=B.rgba(B.TEXT, 255 * alpha))
    B.rich_line(draw, 960, 576 - offset, [
        ("Allocate after ", F_H1, B.TEXT),
        ("evidence.", F_H1_SERIF, B.GREEN),
    ], alpha, center=True)
    proof_alpha = alpha * reveal(t, 56.2, 0.8)
    proof_cards = [
        (230, "4", "ECONOMIC LIFECYCLES", B.AMBER),
        (730, "11s", "REACTIVE CALLBACK", B.GREEN),
        (1230, "202 + 12", "TESTS + INVARIANTS", B.BLUE),
    ]
    for x, value, label, color in proof_cards:
        B.rounded_box(draw, (x, 666, x + 460, 770), B.PANEL, color, proof_alpha, radius=18)
        draw.text((x + 28, 688), value, font=F_H3, fill=B.rgba(color, 250 * proof_alpha))
        draw.text((x + 28, 738), label, font=F_MONO_SMALL, fill=B.rgba(B.TEXT, 225 * proof_alpha))
    draw.text((960, 824), B.tracked("Uniswap v4  x  Pyth  x  Reactive Network  x  Circle"), font=F_KICKER, anchor="mm", fill=B.rgba(B.MUTED, 225 * alpha))
    draw.text((960, 884), "ZERO MEDIUM / HIGH SLITHER FINDINGS", font=F_MONO_SMALL, anchor="mm", fill=B.rgba(B.BLUE, 225 * alpha))
    draw.text((960, 938), "FEES SHOULD FOLLOW OUTCOMES. NOT FEAR.", font=F_MONO, anchor="mm", fill=B.rgba(B.GREEN, 235 * alpha))


def frame_at(t: float) -> Image.Image:
    frame = B.BASE.copy()
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    scan_y = int((t * 38) % HEIGHT)
    draw.rectangle((0, scan_y, WIDTH, scan_y + 2), fill=(138, 255, 173, 7))
    for index in range(20):
        x = (127 * index + int(t * (5 + index % 5))) % WIDTH
        y = (83 * index + int(28 * math.sin(t * 0.35 + index))) % HEIGHT
        draw.ellipse((x - 1, y - 1, x + 1, y + 1), fill=(184, 255, 201, 26))
    header(draw, t)
    footer(draw, t)
    scene_one(draw, t)
    scene_two(draw, t)
    scene_three(draw, t)
    scene_four(draw, t)
    scene_five(draw, t)
    scene_six(draw, t)
    scene_seven(draw, t)
    scene_eight(draw, t)
    return Image.alpha_composite(frame, overlay).convert("RGB")


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
        "-af", "afade=t=in:st=0:d=0.7,afade=t=out:st=57.2:d=2.8,loudnorm=I=-14:TP=-1.5:LRA=11",
        "-c:v", "libx264", "-preset", "medium", "-crf", "16", "-profile:v", "high", "-level", "4.2", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "320k", "-ar", "48000", "-movflags", "+faststart",
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
