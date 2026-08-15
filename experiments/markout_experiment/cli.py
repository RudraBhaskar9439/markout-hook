"""Command-line entrypoint for generating one complete experiment artifact set."""

from __future__ import annotations

import argparse
from pathlib import Path

from . import __version__
from .reporting import write_artifacts
from .simulation import evaluate_trade_tape, generate_trade_tape, load_config


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate deterministic MARKOUT Phase 6 artifacts")
    parser.add_argument("--config", type=Path, required=True, help="experiment configuration JSON")
    parser.add_argument("--output-root", type=Path, required=True, help="directory receiving results/ and charts/")
    arguments = parser.parse_args()

    config_path = arguments.config.resolve()
    output_root = arguments.output_root.resolve()
    config = load_config(config_path)
    if config["generatorVersion"] != __version__:
        raise ValueError(
            f"configuration expects generator {config['generatorVersion']}, running {__version__}"
        )
    trades = generate_trade_tape(config)
    outcomes = evaluate_trade_tape(trades, config)
    write_artifacts(
        trades=trades,
        outcomes=outcomes,
        config=config,
        config_path=config_path,
        output_root=output_root,
        source_root=Path(__file__).resolve().parent,
    )
    print(
        f"Generated {len(trades)} trades and {len(outcomes)} policy outcomes "
        f"for {len(config['scenarios'])} scenarios."
    )


if __name__ == "__main__":
    main()
