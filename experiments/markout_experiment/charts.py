"""Dependency-free deterministic SVG charts for committed research artifacts."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from html import escape
from pathlib import Path

POLICY_COLORS = {
    "fixed": "#64748b",
    "volatility": "#f59e0b",
    "markout": "#6366f1",
    "rebate": "#22c55e",
    "protection": "#ec4899",
    "needed_vs_fixed": "#ff8e74",
    "saved_vs_volatility": "#82b9ff",
}


def fair_flow_frontier_chart(destination: Path, sweep: Mapping[str, object]) -> None:
    """Render the two declared Fair-Flow constraints without mixing their units."""

    candidates = sweep["candidates"]
    constraints = sweep["constraints"]
    if not isinstance(candidates, list) or not candidates:
        raise ValueError("fair-flow sweep requires candidates")
    if not isinstance(constraints, Mapping):
        raise ValueError("fair-flow sweep requires constraints")

    width, height = 1080, 720
    left, right = 95, 42
    panel_width = width - left - right
    panel_height = 205
    top_a, top_b = 122, 420
    base_fees = [int(row["base_fee_bps"]) for row in candidates]
    benign = [float(row["benign_effective_fee_bps"]) for row in candidates]
    lp_improvement = [float(row["lp_net_improvement_vs_fixed_percent"]) for row in candidates]
    selected_index = next(index for index, row in enumerate(candidates) if row["selected"])
    x_step = panel_width / (len(candidates) - 1)

    def x_position(index: int) -> float:
        return left + x_step * index

    def panel_y(value: float, minimum: float, maximum: float, top: int) -> float:
        return top + (maximum - value) * panel_height / (maximum - minimum)

    def points(values: Sequence[float], minimum: float, maximum: float, top: int) -> str:
        return " ".join(
            f"{x_position(index):.2f},{panel_y(value, minimum, maximum, top):.2f}"
            for index, value in enumerate(values)
        )

    top_maximum = max(42.0, max(benign) + 2)
    bottom_minimum = min(-25.0, min(lp_improvement) - 4)
    bottom_maximum = max(90.0, max(lp_improvement) + 4)
    benign_cap = float(constraints["maximum_benign_effective_fee_bps"])
    lp_floor = float(constraints["minimum_lp_net_improvement_vs_fixed_percent"])
    selected_x = x_position(selected_index)
    elements = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#0f172a"/>',
        '<text x="95" y="44" fill="#f8fafc" font-family="Inter,Arial,sans-serif" font-size="25" font-weight="700">Fair-Flow base-fee frontier</text>',
        '<text x="95" y="72" fill="#94a3b8" font-family="Inter,Arial,sans-serif" font-size="14">Lowest base satisfying both declared constraints is selected; same 768-trade tape</text>',
        f'<rect x="{selected_x - 15:.2f}" y="100" width="30" height="540" rx="8" fill="#22c55e" opacity="0.10"/>',
    ]

    panels = [
        (top_a, "Benign effective fee", "Basis points", benign, 0.0, top_maximum, benign_cap, "30 bps cap"),
        (
            top_b,
            "LP net improvement versus fixed 30 bps",
            "Percent",
            lp_improvement,
            bottom_minimum,
            bottom_maximum,
            lp_floor,
            "20% floor",
        ),
    ]
    for top, title, unit, values, minimum, maximum, threshold, threshold_label in panels:
        elements.extend(
            [
                f'<text x="{left}" y="{top - 24}" fill="#e2e8f0" font-family="Inter,Arial,sans-serif" font-size="16" font-weight="600">{escape(title)}</text>',
                f'<text x="{width - right}" y="{top - 24}" text-anchor="end" fill="#64748b" font-family="Inter,Arial,sans-serif" font-size="12">{escape(unit)}</text>',
                f'<rect x="{left}" y="{top}" width="{panel_width}" height="{panel_height}" fill="#111c2d" stroke="#334155"/>',
            ]
        )
        for tick in range(5):
            value = minimum + (maximum - minimum) * tick / 4
            y = panel_y(value, minimum, maximum, top)
            elements.extend(
                [
                    f'<line x1="{left}" x2="{width - right}" y1="{y:.2f}" y2="{y:.2f}" stroke="#27364b"/>',
                    f'<text x="{left - 12}" y="{y + 4:.2f}" text-anchor="end" fill="#94a3b8" font-family="Inter,Arial,sans-serif" font-size="11">{value:.1f}</text>',
                ]
            )
        threshold_y = panel_y(threshold, minimum, maximum, top)
        elements.extend(
            [
                f'<line x1="{left}" x2="{width - right}" y1="{threshold_y:.2f}" y2="{threshold_y:.2f}" stroke="#f59e0b" stroke-width="2" stroke-dasharray="7 6"/>',
                f'<text x="{width - right - 8}" y="{threshold_y - 7:.2f}" text-anchor="end" fill="#fbbf24" font-family="Inter,Arial,sans-serif" font-size="11">{escape(threshold_label)}</text>',
                f'<polyline points="{points(values, minimum, maximum, top)}" fill="none" stroke="#82b9ff" stroke-width="3" stroke-linejoin="round"/>',
            ]
        )
        for index, value in enumerate(values):
            selected = index == selected_index
            elements.append(
                f'<circle cx="{x_position(index):.2f}" cy="{panel_y(value, minimum, maximum, top):.2f}" r="{6 if selected else 3.5}" fill="{"#22c55e" if selected else "#82b9ff"}"/>'
            )

    for index, base_fee in enumerate(base_fees):
        if base_fee % 2 == 0 or index == selected_index:
            elements.append(
                f'<text x="{x_position(index):.2f}" y="662" text-anchor="middle" fill="{"#86efac" if index == selected_index else "#94a3b8"}" font-family="Inter,Arial,sans-serif" font-size="11" font-weight="{"700" if index == selected_index else "400"}">{base_fee}</text>'
            )
    elements.extend(
        [
            '<text x="536" y="692" text-anchor="middle" fill="#94a3b8" font-family="Inter,Arial,sans-serif" font-size="12">Base LP fee (bps)</text>',
            f'<text x="{selected_x + 12:.2f}" y="105" fill="#86efac" font-family="Inter,Arial,sans-serif" font-size="12" font-weight="700">SELECTED 18 BPS</text>',
            '</svg>',
        ]
    )
    destination.write_text("\n".join(elements) + "\n", encoding="utf-8")


def grouped_bar_chart(
    destination: Path,
    *,
    title: str,
    subtitle: str,
    groups: Sequence[str],
    series: Mapping[str, Sequence[float]],
    y_axis_label: str,
) -> None:
    if not groups or not series or any(len(values) != len(groups) for values in series.values()):
        raise ValueError("chart groups and series must be non-empty and aligned")

    width, height = 1080, 620
    left, right, top, bottom = 100, 40, 105, 150
    plot_width = width - left - right
    plot_height = height - top - bottom
    all_values = [value for values in series.values() for value in values]
    minimum = min(0.0, min(all_values))
    maximum = max(0.0, max(all_values))
    if maximum == minimum:
        maximum = minimum + 1.0
    padding = (maximum - minimum) * 0.08
    minimum -= padding if minimum < 0 else 0
    maximum += padding

    def y_position(value: float) -> float:
        return top + (maximum - value) * plot_height / (maximum - minimum)

    zero_y = y_position(0.0)
    group_width = plot_width / len(groups)
    bar_gap = 5
    series_names = list(series)
    bar_width = min(
        34.0,
        (group_width * 0.78 - bar_gap * (len(series_names) - 1)) / len(series_names),
    )
    elements = [
        (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}">'
        ),
        '<rect width="100%" height="100%" fill="#0f172a"/>',
        (
            f'<text x="{left}" y="42" fill="#f8fafc" font-family="Inter,Arial,sans-serif" '
            f'font-size="25" font-weight="700">{escape(title)}</text>'
        ),
        (
            f'<text x="{left}" y="70" fill="#94a3b8" font-family="Inter,Arial,sans-serif" '
            f'font-size="14">{escape(subtitle)}</text>'
        ),
    ]

    for tick_index in range(6):
        tick_value = minimum + (maximum - minimum) * tick_index / 5
        tick_y = y_position(tick_value)
        elements.extend(
            [
                (
                    f'<line x1="{left}" x2="{width - right}" y1="{tick_y:.2f}" '
                    f'y2="{tick_y:.2f}" stroke="#334155" stroke-width="1"/>'
                ),
                (
                    f'<text x="{left - 12}" y="{tick_y + 5:.2f}" text-anchor="end" '
                    f'fill="#94a3b8" font-family="Inter,Arial,sans-serif" font-size="12">'
                    f'{tick_value:.2f}</text>'
                ),
            ]
        )
    elements.append(
        (
            f'<line x1="{left}" x2="{width - right}" y1="{zero_y:.2f}" '
            f'y2="{zero_y:.2f}" stroke="#e2e8f0" stroke-width="1.5"/>'
        )
    )

    for group_index, group in enumerate(groups):
        center_x = left + group_width * (group_index + 0.5)
        total_width = len(series_names) * bar_width + (len(series_names) - 1) * bar_gap
        start_x = center_x - total_width / 2
        for series_index, name in enumerate(series_names):
            value = series[name][group_index]
            value_y = y_position(value)
            rectangle_y = min(value_y, zero_y)
            rectangle_height = max(abs(zero_y - value_y), 1.0)
            x = start_x + series_index * (bar_width + bar_gap)
            color = POLICY_COLORS.get(name, "#38bdf8")
            elements.append(
                (
                    f'<rect x="{x:.2f}" y="{rectangle_y:.2f}" width="{bar_width:.2f}" '
                    f'height="{rectangle_height:.2f}" rx="3" fill="{color}"/>'
                )
            )
        wrapped = _wrap_label(group, 21)
        for line_index, line in enumerate(wrapped):
            elements.append(
                (
                    f'<text x="{center_x:.2f}" y="{height - bottom + 28 + line_index * 17}" '
                    f'text-anchor="middle" fill="#cbd5e1" font-family="Inter,Arial,sans-serif" '
                    f'font-size="12">{escape(line)}</text>'
                )
            )

    legend_x = left
    legend_y = height - 35
    for name in series_names:
        color = POLICY_COLORS.get(name, "#38bdf8")
        label = name.replace("_", " ").title()
        elements.extend(
            [
                (
                    f'<rect x="{legend_x}" y="{legend_y - 11}" width="14" height="14" '
                    f'rx="2" fill="{color}"/>'
                ),
                (
                    f'<text x="{legend_x + 21}" y="{legend_y + 1}" fill="#cbd5e1" '
                    f'font-family="Inter,Arial,sans-serif" font-size="13">{escape(label)}</text>'
                ),
            ]
        )
        legend_x += 155
    elements.append(
        (
            f'<text transform="translate(22 {top + plot_height / 2:.2f}) rotate(-90)" '
            f'text-anchor="middle" fill="#94a3b8" font-family="Inter,Arial,sans-serif" '
            f'font-size="12">{escape(y_axis_label)}</text>'
        )
    )
    elements.append("</svg>")
    destination.write_text("\n".join(elements) + "\n", encoding="utf-8")


def _wrap_label(label: str, maximum: int) -> list[str]:
    words = label.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if current and len(candidate) > maximum:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines[:3]
