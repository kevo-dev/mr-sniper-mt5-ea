#!/usr/bin/env python3
"""Monte Carlo robustness analysis for exported MT5 closed-trade results.

The script resamples a sequence of realised trade P/L values with replacement,
optionally applies adverse cost shocks, and reports percentile distributions for
ending P/L, maximum drawdown, losing streaks, and a simple ruin proxy.

Example:
    python3 monte_carlo.py --input closed_trades.csv --profit-column Profit \
        --runs 10000 --cost-shock 0.10 --starting-equity 10000 \
        --ruin-drawdown-pct 30 --output monte_carlo_summary.json

The source CSV must contain one row per fully closed position. A numeric P/L
column in account currency is required. Partial closes should be consolidated
before use, otherwise the sequence will not represent position-level outcomes.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
from pathlib import Path
from statistics import mean


def percentile(values: list[float], q: float) -> float:
    if not values:
        return float("nan")
    ordered = sorted(values)
    index = (len(ordered) - 1) * q
    low = math.floor(index)
    high = math.ceil(index)
    if low == high:
        return ordered[low]
    return ordered[low] * (high - index) + ordered[high] * (index - low)


def longest_loss_streak(sequence: list[float]) -> int:
    current = 0
    longest = 0
    for value in sequence:
        if value < 0:
            current += 1
            longest = max(longest, current)
        else:
            current = 0
    return longest


def run_path(
    outcomes: list[float],
    starting_equity: float,
    cost_shock_pct: float,
    entry_noise_pct: float,
) -> tuple[float, float, int]:
    """Return terminal P/L, max drawdown percent, and max losing streak."""
    equity = starting_equity
    high_water = starting_equity
    max_dd_pct = 0.0
    simulated: list[float] = []
    for original in outcomes:
        # An adverse cost shock affects every trade. Entry noise is symmetric and
        # scaled to absolute trade outcome to test modest fill variability.
        adverse_cost = abs(original) * cost_shock_pct / 100.0
        entry_noise = random.uniform(-entry_noise_pct, entry_noise_pct) * abs(original) / 100.0
        value = original - adverse_cost + entry_noise
        simulated.append(value)
        equity += value
        high_water = max(high_water, equity)
        if high_water > 0:
            max_dd_pct = max(max_dd_pct, 100.0 * (high_water - equity) / high_water)
    return equity - starting_equity, max_dd_pct, longest_loss_streak(simulated)


def load_outcomes(path: Path, column: str) -> list[float]:
    outcomes: list[float] = []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or column not in reader.fieldnames:
            available = ", ".join(reader.fieldnames or [])
            raise ValueError(f"Column '{column}' not found. Available columns: {available}")
        for row_number, row in enumerate(reader, start=2):
            raw = (row.get(column) or "").strip().replace(",", "")
            if not raw:
                continue
            try:
                outcomes.append(float(raw))
            except ValueError as exc:
                raise ValueError(f"Invalid number in row {row_number}: {raw!r}") from exc
    if len(outcomes) < 30:
        raise ValueError("At least 30 fully closed trades are required for a meaningful preliminary analysis.")
    return outcomes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="CSV with one fully closed position per row")
    parser.add_argument("--profit-column", default="Profit", help="Name of numeric realised P/L column")
    parser.add_argument("--runs", type=int, default=10000, help="Number of resampled paths (default: 10000)")
    parser.add_argument("--starting-equity", type=float, required=True, help="Starting account equity in account currency")
    parser.add_argument("--cost-shock", type=float, default=0.0, help="Adverse cost shock as %% of abs(trade P/L)")
    parser.add_argument("--entry-noise", type=float, default=0.0, help="Symmetric execution noise as %% of abs(trade P/L)")
    parser.add_argument("--ruin-drawdown-pct", type=float, default=30.0, help="Drawdown threshold used only as a ruin proxy")
    parser.add_argument("--seed", type=int, default=26081201, help="Random seed for reproducibility")
    parser.add_argument("--output", type=Path, default=Path("monte_carlo_summary.json"), help="JSON output file")
    args = parser.parse_args()

    if args.runs < 100:
        raise ValueError("Use at least 100 runs; 10,000 is the recommended default.")
    if args.starting_equity <= 0:
        raise ValueError("Starting equity must be positive.")
    if args.cost_shock < 0 or args.entry_noise < 0:
        raise ValueError("Cost shock and entry noise must be non-negative.")

    random.seed(args.seed)
    outcomes = load_outcomes(args.input, args.profit_column)
    path_length = len(outcomes)
    terminal_pnl: list[float] = []
    max_drawdown: list[float] = []
    loss_streaks: list[int] = []

    for _ in range(args.runs):
        resample = random.choices(outcomes, k=path_length)
        pnl, dd_pct, streak = run_path(
            resample,
            args.starting_equity,
            args.cost_shock,
            args.entry_noise,
        )
        terminal_pnl.append(pnl)
        max_drawdown.append(dd_pct)
        loss_streaks.append(streak)

    summary = {
        "method": "bootstrap resampling with replacement",
        "source_file": str(args.input),
        "profit_column": args.profit_column,
        "runs": args.runs,
        "trades_per_path": path_length,
        "starting_equity": args.starting_equity,
        "cost_shock_pct_of_absolute_trade_pnl": args.cost_shock,
        "entry_noise_pct_of_absolute_trade_pnl": args.entry_noise,
        "ruin_proxy_drawdown_pct": args.ruin_drawdown_pct,
        "terminal_pnl": {
            "p05": percentile(terminal_pnl, 0.05),
            "p25": percentile(terminal_pnl, 0.25),
            "median": percentile(terminal_pnl, 0.50),
            "p75": percentile(terminal_pnl, 0.75),
            "p95": percentile(terminal_pnl, 0.95),
            "mean": mean(terminal_pnl),
            "probability_negative": sum(x < 0 for x in terminal_pnl) / args.runs,
        },
        "maximum_drawdown_pct": {
            "p05": percentile(max_drawdown, 0.05),
            "p50": percentile(max_drawdown, 0.50),
            "p95": percentile(max_drawdown, 0.95),
            "worst": max(max_drawdown),
            "probability_above_ruin_proxy": sum(x >= args.ruin_drawdown_pct for x in max_drawdown) / args.runs,
        },
        "maximum_losing_streak": {
            "p05": percentile([float(x) for x in loss_streaks], 0.05),
            "p50": percentile([float(x) for x in loss_streaks], 0.50),
            "p95": percentile([float(x) for x in loss_streaks], 0.95),
            "worst": max(loss_streaks),
        },
        "limitations": [
            "This is a bootstrap stress test, not a forecast of live performance.",
            "It assumes the exported trade set represents a stable process and cannot prove that assumption.",
            "It does not model regime changes, liquidity collapse, broker outages, or correlated market shocks unless those are represented in the source outcomes.",
        ],
    }
    args.output.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    print(f"\nSaved: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
