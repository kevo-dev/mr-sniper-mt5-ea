# MR Sniper — MT5 Mean-Reversion EA

[![Status: Research Only](https://img.shields.io/badge/status-research%20only-orange?style=flat-square)](Documentation/README.md)
[![Platform: MetaTrader 5](https://img.shields.io/badge/platform-MetaTrader%205-1f6feb?style=flat-square)](https://www.metatrader5.com/)
[![Language: MQL5](https://img.shields.io/badge/language-MQL5-4c1?style=flat-square)](https://www.mql5.com/)
[![Risk Controls](https://img.shields.io/badge/risk-controls%20included-2ea44f?style=flat-square)](Documentation/README.md#3-risk-and-execution-controls)
[![Backtesting](https://img.shields.io/badge/backtesting-required-critical?style=flat-square)](#backtesting-and-results-guide)

> **Research software, not investment advice.** MR Sniper is an execution-capable MetaTrader 5 Expert Advisor intended for disciplined strategy research. It does not promise profitability, and historical or simulated results do not establish future performance. Use a demo account and independently validate every configuration before considering any live deployment.

MR Sniper is a selective intraday **mean-reversion** EA for MetaTrader 5. It evaluates only completed execution-timeframe bars for new signals and combines session VWAP, Bollinger Bands, z-score, RSI, ATR, ADX, EMA structure, reversal confirmation, market regime, spread, session, economic-calendar, and risk filters. The default research configuration is M5 execution with M15 context.

## Contents

| Section | Purpose |
| --- | --- |
| [What is included](#what-is-included) | Repository contents and deployment model. |
| [Core design](#core-design) | Signal, regime, execution, and risk logic. |
| [Quick start](#quick-start) | Safe compile, install, and first-test procedure. |
| [Inputs and presets](#inputs-and-presets) | Conservative, balanced, and aggressive research baselines. |
| [Backtesting and results guide](#backtesting-and-results-guide) | Reproducible test configuration, reporting templates, and interpretation. |
| [Robustness testing](#robustness-testing) | Walk-forward and Monte Carlo workflow. |
| [Logs and troubleshooting](#logs-and-troubleshooting) | Evidence collection and common failure modes. |

## What is included

| Path | Description |
| --- | --- |
| [`Experts/MR_Sniper_MeanReversion.mq5`](Experts/MR_Sniper_MeanReversion.mq5) | Full MQL5 EA source, including signal evaluation, sizing, execution, trade management, chart dashboard, logging, and custom tester objective. |
| [`Presets/MR_Sniper_Conservative.set`](Presets/MR_Sniper_Conservative.set) | Lowest-risk research baseline; tighter signal and risk gates. |
| [`Presets/MR_Sniper_Balanced.set`](Presets/MR_Sniper_Balanced.set) | Main research baseline and closest match to the design defaults. |
| [`Presets/MR_Sniper_Aggressive.set`](Presets/MR_Sniper_Aggressive.set) | Higher-frequency sensitivity-research baseline that retains hard safety controls. |
| [`Tools/monte_carlo.py`](Tools/monte_carlo.py) | Python 3 bootstrap-resampling analysis for exported, consolidated closed-position P/L. |
| [`Documentation/README.md`](Documentation/README.md) | Detailed operating manual, risk controls, technical implementation notes, and troubleshooting guide. |

The EA is designed as a **per-symbol chart instance**. For a coordinated portfolio test, attach one instance to each intended symbol and use the same `InpMagicNumber`; portfolio-risk and shared-currency exposure checks then aggregate positions under that magic number. This shared-currency check is a conservative proxy, not a covariance or correlation-matrix model.

## Core design

The strategy looks for statistically stretched prices with corroborating evidence that a reversion is plausible, then rejects signals that fail market, execution, or risk conditions. It is deliberately selective: a high signal score is necessary but never sufficient for entry.

| Layer | Default mechanism | Purpose |
| --- | --- | --- |
| Equilibrium | Session VWAP using typical price and real volume where available, otherwise tick volume | Identifies intraday fair-value reference. |
| Statistical stretch | Bollinger Bands (20, 2.0) and rolling z-score (50 bars; threshold 2.0) | Identifies uncommon deviation from the recent distribution. |
| Momentum extreme | RSI (14; 30/70 default) | Adds oversold/overbought confirmation. |
| Reversal evidence | Engulfing, wick, strong-close, and return-inside-band checks | Avoids acting on extension alone. |
| Regime filter | ADX and higher-timeframe EMA geometry | Blocks or tightens entries during unsuitable directional conditions. |
| Volatility filter | ATR, normal-ATR comparison, abnormal candle, and band-width checks | Avoids weak or disorderly market states. |
| Execution filters | Spread, stale quote, broker stop/freeze distance, session, rollover, calendar, margin, and duplicate-order gates | Rejects entries that cannot satisfy preconditions. |
| Risk management | Equity-risk sizing, ATR stop, target/R:R check, break-even, optional trail, time stop, daily loss, drawdown, cooldown, and portfolio-risk locks | Limits exposure; it does not eliminate trading loss. |

The EA uses MQL5's `CTrade` interface for market execution and protected modifications. The implementation verifies trade-server return codes after entry, close, and modification requests; a method returning `true` alone is not treated as proof that the broker executed a deal.[1] [2] [3]

## Quick start

### 1. Install and compile

Copy [`MR_Sniper_MeanReversion.mq5`](Experts/MR_Sniper_MeanReversion.mq5) into your terminal data directory:

```text
MQL5/Experts/MR_Sniper_MeanReversion.mq5
```

Open the file in **MetaEditor** and compile it. Refresh the Navigator panel or restart the terminal if the EA does not appear. This repository intentionally ships source rather than a precompiled `.ex5`; compilation must be completed on your own MT5 installation and terminal build.

### 2. Attach and load a research preset

Attach the EA to an M5 chart for the desired broker symbol. In **Inputs**, load a preset from [`Presets/`](Presets/). Each supplied `.set` file sets `InpEnableTrading=false` deliberately. Keep it disabled while conducting historical tests and initial demo validation.

| First-test task | Required action |
| --- | --- |
| Symbol contract | Confirm tick size, tick value, volume minimum/step, stop level, freeze level, session hours, and quote digits at your broker. |
| Unique identity | Set an intentional `InpMagicNumber`; use the same one only for EA instances intended to share the portfolio guard. |
| Execution assumptions | Set `InpMaxSpreadValue` and `InpMaxSlippagePoints` for the exact instrument, not for a generic FX pair. |
| Calendar behavior | Keep `InpFailClosedOnNewsError=true` while validating. A missing calendar then blocks new entries rather than assuming safety. |
| Live permission | Do not enable it merely because compilation succeeded. First complete the backtesting and forward-demo process below. |

### 3. Choose a starting baseline

| Preset | Risk per trade | Minimum score | Maximum daily loss | Intended use |
| --- | ---:| ---:| ---:| --- |
| Conservative | 0.25% | 85 | 1.0% | First robustness baseline and fragile-market study. |
| Balanced | 0.50% | 75 | 2.0% | Primary controlled research baseline. |
| Aggressive | 0.75% | 70 | 2.5% | Sensitivity research only; not a recommendation to trade more aggressively. |

## Inputs and presets

The full input surface is grouped in MT5 as **General**, **Mean-Reversion Model**, **Market Regime**, **Spread, Session and News Filters**, **Risk and Position Sizing**, **Stops, Targets and Trade Management**, and **Logging and Dashboard**. Do not perform a broad optimization of every setting. That maximizes the risk of fitting parameters to the tested history rather than evaluating a durable hypothesis.

| Input | Balanced default | Practical role |
| --- | ---:| --- |
| `InpExecutionTF` / `InpHigherTF` | M5 / M15 | Execution and contextual analysis timeframe. |
| `InpMinimumSignalScore` | 75 | Minimum weighted confluence score before other gates are considered. |
| `InpVWAPDeviationATR` | 0.70 | Required VWAP extension expressed in ATR units. |
| `InpZScoreThreshold` | 2.00 | Required close-price statistical stretch. |
| `InpADXTrendThreshold` | 25 | Regime threshold used with the selected trend-filter mode. |
| `InpMaxSpreadValue` | 1.50 pips | Maximum permitted spread in the selected spread mode. |
| `InpRiskPerTradePercent` | 0.50% | Equity fraction used for risk-based volume sizing. |
| `InpATRStopMultiplier` | 1.20 | ATR multiple used in initial protective-stop construction. |
| `InpMinimumRR` | 1.20R | Minimum projected reward-to-risk permitted at entry. |
| `InpMaxTradesPerDay` | 5 | Closed-position cap for the broker-server day. |
| `InpMaxAccountDrawdownPercent` | 10% | Persisted equity high-water drawdown lock threshold. |

> **Parameter-selection rule:** prefer a broad region of similar out-of-sample behavior over an isolated best result. An exact “best” combination found only in a single historical interval is evidence of fragility, not proof of edge.

## Backtesting and results guide

### Backtest policy

A result is only useful if another reviewer can reproduce its assumptions. Every report should specify the **exact Git commit**, EA inputs, broker-symbol specification, data dates, tester model, account currency, leverage, commission, spread treatment, slippage assumption, and any disabled safety filter. MT5’s Strategy Tester provides model, trading, and optimization configuration that materially affect reported outcomes; maintain those settings with the report rather than reporting headline P/L alone.[4]

Use the same broker-symbol specification that you expect to forward-test. FX pairs, XAUUSD, indices, and suffix-bearing broker symbols are not interchangeable: volume, tick economics, session behavior, spread, swap, and stop requirements can differ materially. In particular, do not move an FX preset unchanged to a CFD and treat the outcome as comparable.

### Minimum test matrix

Run the same baseline across more than one market condition before making a claim about behavior.

| Test dimension | Minimum record | Interpretation standard |
| --- | --- | --- |
| Instrument | Exact broker symbol, e.g., `EURUSD.a` | Never collapse differently specified symbols into one result. |
| Data window | Start/end date, timezone basis, and number of market sessions | Cover both favorable and adverse regimes where quality history is available. |
| Test model | Use the most granular available tick modelling; record the terminal build and data source | Do not compare different modelling assumptions as if they are equal. |
| Costs | Commission, spread method, swap, and explicit slippage stress | Scalping results must survive costs beyond a best-case quote assumption. |
| Market regime | Range, trend, high-volatility, low-volatility, rollover, and news-adjacent samples | A mean-reversion process must be examined outside preferred ranges. |
| Parameter status | Baseline, in-sample candidate, locked out-of-sample, or walk-forward selection | Prevents presenting optimized in-sample results as independent evidence. |
| Failure-path tests | Missing indicator, stale quote, calendar failure, margin failure, invalid stops, trade rejection, and risk-lock behavior | Confirms the intended no-trade / fail-safe response. |

### Strategy Tester procedure

1. Open **View → Strategy Tester**, select `MR_Sniper_MeanReversion`, select the exact broker symbol, and use the EA's execution timeframe (M5 by default).
2. Load `MR_Sniper_Balanced.set` as the initial baseline. Confirm that the test inputs, including the magic number, are saved with your report. Keep automated live trading disabled; tester execution is sufficient for research.
3. Use the finest reliable tick model available in your terminal and record the selected model, data span, and terminal build. Do not describe lower-fidelity results as tick-accurate.
4. Set the account currency, initial deposit, leverage, commission, swap, and spread assumptions to values that are conservative and reproducible. Repeat the test with worse spread/slippage assumptions.
5. Run the baseline without optimization. Review the EA CSV, Experts log, and detailed trade list for rejected entries, closes, and risk-lock events—not only the equity curve.
6. Divide the data into development, validation, and untouched out-of-sample periods. Optimize only on the development period, lock a small, rational parameter set, and test it exactly once on the untouched period.
7. Export the report, settings, trade list, and a short methodology note. Store the file names and SHA-256 values when auditability is important.

### Results reporting template

The repository intentionally contains **no fabricated performance results**. Replace the placeholders below only with reports produced from a documented test. Preserve an unfavourable result; it is as informative as a favourable one.

#### Test identity

| Field | Value to record |
| --- | --- |
| Repository commit | `git rev-parse HEAD` |
| EA file / build | `MR_Sniper_MeanReversion.mq5` / MetaEditor build number |
| Symbol and broker | Exact symbol plus broker-server name |
| Test dates | YYYY-MM-DD to YYYY-MM-DD |
| Execution / higher timeframe | e.g., M5 / M15 |
| Deposit, currency, leverage | Initial balance and account assumptions |
| Tester model and data source | Exact Strategy Tester model and data quality note |
| Preset and changes | Preset filename plus every modified input |
| Costs | Commission, spread method/value, swap, and slippage treatment |
| Parameter status | Baseline / in-sample / locked out-of-sample / walk-forward |
| Tester report files | Relative paths or artifact links |

#### Performance summary

| Metric | Value | Required context |
| --- | ---:| --- |
| Net profit | _Not yet reported_ | Report account currency and period. |
| Gross profit / gross loss | _Not yet reported_ | Supports independent profit-factor calculation. |
| Profit factor | _Not yet reported_ | Treat values with low trade counts cautiously. |
| Expected payoff | _Not yet reported_ | Report account currency per closed position. |
| Total closed positions | _Not yet reported_ | Do not substitute individual partial fills unless that is the declared unit. |
| Win rate | _Not yet reported_ | Report average win and average loss alongside it. |
| Average win / average loss | _Not yet reported_ | Shows payoff asymmetry hidden by win rate. |
| Maximum equity drawdown | _Not yet reported_ | Report both currency and percent; identify tester statistic used. |
| Relative / maximal drawdown | _Not yet reported_ | Preserve the tester’s label to avoid ambiguity. |
| Recovery factor | _Not yet reported_ | Interpret only together with drawdown and trade count. |
| Largest losing streak | _Not yet reported_ | Compare with Monte Carlo stress percentiles. |
| Average trade duration | _Not yet reported_ | Helpful for verifying time-stop and session behavior. |
| Cost stress outcome | _Not yet reported_ | State the exact spread/slippage deterioration. |
| Out-of-sample outcome | _Not yet reported_ | Must not reuse the optimization window. |

#### Interpretation guardrails

| Observation | Appropriate interpretation | Inappropriate interpretation |
| --- | --- | --- |
| High profit factor over few trades | A hypothesis for more testing; sampling error remains large. | Evidence that the strategy is proven. |
| High win rate with rare large losses | Inspect average loss, tail events, stop behavior, and worst drawdown. | “Safe” because most trades won. |
| Positive in-sample but weak OOS result | Suggests parameter dependence or regime sensitivity. | Ignore OOS because the in-sample chart looks better. |
| Positive result only under zero/low costs | Likely execution-sensitive. | Assume a broker will match best-case fills. |
| Flat results across a broad parameter area | Potentially more robust than a narrow optimum; still requires OOS and demo verification. | A guarantee of future stability. |
| Risk lock triggers frequently | The configuration may be mismatched to the instrument or risk budget. | Remove the lock to improve a performance statistic. |

### Results folder convention

When you start producing reports, keep raw artifacts separate from summary claims. A recommended local layout is below; add only files you are comfortable retaining in version control and remove account-sensitive exports before publishing.

```text
Results/
  2026-08_EURUSD_M5_baseline/
    methodology.md
    inputs.set
    strategy_tester_report.html
    closed_positions.csv
    experts_log_excerpt.txt
    monte_carlo_summary.json
    sha256sums.txt
```

A concise `methodology.md` should state the objective, test identity fields, cost assumptions, exclusions, pass/fail criteria, known data limitations, and whether the result is in-sample or out-of-sample. Do not store account identifiers, credentials, or personally identifying broker exports in a public repository.

## Robustness testing

### Walk-forward procedure

Use rolling chronological windows, such as six months in-sample and three months untouched out-of-sample, where the available data supports that interval. Within each development window, adjust only a limited, economically interpretable parameter set—such as score threshold, VWAP extension, z-score threshold, ADX threshold, ATR stop multiplier, session window, or spread cap. Freeze the chosen values before running the next out-of-sample segment.

| Walk-forward field | Record |
| --- | --- |
| Window number | Sequential identifier. |
| In-sample dates | Parameter-selection period. |
| Out-of-sample dates | Untouched evaluation period. |
| Selected parameters | Values selected before OOS run. |
| IS / OOS trade counts | Sufficient to contextualize metrics. |
| IS / OOS P/L, profit factor, drawdown, expectancy | Same definitions in both windows. |
| Cost assumptions | Identical or explicitly changed. |
| Decision | Retain, investigate, or reject, with rationale. |

A configuration should be rejected or redesigned if it performs only in one narrow parameter point, if reasonable execution stress eliminates its behavior, if out-of-sample degradation is extreme, or if risk controls are repeatedly hit under ordinary test conditions. These are research decisions, not automated trading decisions.

### Monte Carlo tool

After exporting a **clean, consolidated closed-position** P/L series, run the included utility with Python 3. Partial closes must be consolidated at the position level first; otherwise the input sequence does not represent comparable position outcomes.

```bash
cd Tools
python3 monte_carlo.py \
  --input ../Results/2026-08_EURUSD_M5_baseline/closed_positions.csv \
  --profit-column Profit \
  --runs 10000 \
  --starting-equity 10000 \
  --cost-shock 10 \
  --entry-noise 5 \
  --ruin-drawdown-pct 30 \
  --output ../Results/2026-08_EURUSD_M5_baseline/monte_carlo_summary.json
```

The tool uses bootstrap resampling with replacement and can add an adverse cost shock plus symmetric execution noise. It reports terminal P/L, maximum-drawdown, and losing-streak percentiles. Its drawdown threshold is only a **ruin proxy**, not a probability forecast. It does not model a structural regime break, liquidity disappearance, a broker outage, or changing correlations unless those effects are present in the supplied historical outcome series.

## Risk controls and operating model

MR Sniper includes many controls intended to prefer **no trade** over an uncertain entry: broker stop/freeze checks, tick/volume normalization, margin pre-check, duplicate-pending-order block, stale-quote filter, session and rollover blackout, news blackout, abnormal-volatility filter, daily loss/profit rules, drawdown lock, maximum trades/day, post-trade cooldown, consecutive-loss pause, portfolio risk, shared-currency exposure, break-even, optional trailing stop, and time stop.

| Control | Balanced default | Important behavior |
| --- | ---:| --- |
| Per-trade risk | 0.50% of equity | Volume is floored to the broker step instead of rounded up. |
| Daily loss lock | 2.00% | Blocks entries; configured to close EA-owned positions when the limit is reached. |
| Account drawdown lock | 10.00% | Persists through a terminal global variable and requires an intentional manual reset input. |
| Daily trade cap | 5 | Stops new entries after the cap. |
| Consecutive-loss pause | 3 losses / 60 minutes | Blocks new entries through a reassessment interval. |
| Portfolio-risk cap | 1.50% | Adds open EA-position risk to proposed risk. |
| Calendar blackout | 15 min before / 30 min after | Evaluates broker-server time; unknown calendar state can fail closed.[5] |

These settings limit exposure but cannot prevent loss, slippage, gaps, delays, rejected orders, data errors, or changing market structure. Do not lower or disable them merely to improve a historical statistic.

## Logs and troubleshooting

When file logging is enabled, the EA writes CSV records under the terminal data directory’s `MQL5/Files/` path. The filename contains the symbol, magic number, and broker-server date. The chart dashboard reports status, regime, action, key indicators, signal scores, lock state, daily P/L, drawdown, trade count, and server time.

| Symptom | Most likely first check |
| --- | --- |
| No trades | Verify the preset’s `InpEnableTrading`, then inspect session, score, regime, news, and spread rejection entries in the log. |
| Position size invalid | Confirm symbol tick values, minimum volume/step, ATR stop distance, free margin, and risk percentage. Never force the size upward. |
| SL/TP rejected | Inspect the trade-server return code; verify stop/freeze distance and price normalization. |
| Calendar unavailable | Keep fail-closed for serious testing. If disabling it for a specific research experiment, record that decision prominently. |
| Risk lock persists | Investigate the event first; it is designed to persist. Use `InpManualResetRiskLock=true` for a deliberate, auditable reset, then set it back to false. |
| Different result from prior run | Compare commit hash, tester model, data range, contract details, inputs, costs, timezone/server state, and terminal build before drawing a conclusion. |

## Development and contribution notes

Use focused commits that preserve reproducibility. An EA logic change should include a description of the hypothesis, the changed inputs or code path, the intended test matrix, and separated in-sample/out-of-sample evidence. Do not commit `.ex5` binaries, account logs, credentials, personal broker exports, or unreviewed live-trading settings. The repository `.gitignore` excludes common generated artifacts.

There is no performance claim or published verified backtest in this repository at the time of writing. A future result should be added only alongside its method, inputs, costs, raw or auditable trade evidence, and limitations.

## References

[1]: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade "MQL5 Reference — CTrade"
[2]: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuy "MQL5 Reference — CTrade::Buy"
[3]: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionmodify "MQL5 Reference — CTrade::PositionModify"
[4]: https://www.metatrader5.com/en/terminal/help/algotrading/testing "MetaTrader 5 Help — Strategy Testing"
[5]: https://www.mql5.com/en/docs/calendar/calendarvaluehistory "MQL5 Reference — CalendarValueHistory"
