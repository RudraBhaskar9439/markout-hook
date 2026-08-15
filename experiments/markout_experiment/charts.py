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
}


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
