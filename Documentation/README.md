# MR Sniper Mean-Reversion EA

**Version:** 1.00  
**Author:** Manus AI  
**Platform:** MetaTrader 5 / MQL5 Expert Advisor  
**Status:** Source package ready for user-side compilation and controlled validation

> **Risk notice.** This software is an execution-capable research tool, not investment advice or a promise of profitability. Leveraged trading can lose more rapidly than expected and historical results do not guarantee future performance. Compile, test, and forward-test on a demo account before considering any live deployment.

## 1. Package contents

| Path | Purpose |
| --- | --- |
| `Experts/MR_Sniper_MeanReversion.mq5` | Complete MT5 Expert Advisor source. It contains the signal engine, risk engine, order execution, trade management, logging, dashboard, and custom tester objective. |
| `Presets/MR_Sniper_Conservative.set` | Low-risk research preset with stricter filters and `InpEnableTrading=false`. |
| `Presets/MR_Sniper_Balanced.set` | Default research preset corresponding to the supplied brief. |
| `Presets/MR_Sniper_Aggressive.set` | Higher-frequency research preset that retains hard loss, drawdown, and execution controls. |
| `Tools/monte_carlo.py` | Reproducible bootstrap-resampling utility for exported **closed position** P/L records. |
| `Documentation/README.md` | Installation, strategy, risk, testing, optimization, walk-forward, Monte Carlo, and troubleshooting guide. |

## 2. Strategy design

The EA is intentionally selective. It processes entry decisions only when a **new closed execution-timeframe bar** appears, using the default M5 setting. This prevents current-bar look-ahead and avoids repeatedly placing entry orders on individual ticks. Tick processing remains active for spread monitoring and position management.

| Component | Implementation | Entry role |
| --- | --- | --- |
| Session VWAP | Intraday typical-price VWAP weighted by real volume where available, otherwise tick volume. Only completed bars from the broker trading day are included. | Primary equilibrium and take-profit reference. |
| Bollinger Bands | Configurable period and standard deviation; default 20 / 2.0. | Statistical extension and re-entry confirmation. |
| Z-score | Rolling close-price z-score, default 50 bars. | Quantifies unusual deviation. |
| RSI | Configurable RSI, default 14. | Secondary extreme and turn confirmation. |
| ATR | Configurable ATR, default 14. | Dynamic stop, volatility filter, and optional trailing stop. |
| ADX and EMAs | ADX plus higher-timeframe EMA 20 / 50 / 200 geometry. | Blocks mean reversion in unsuitable trend conditions. |

A long candidate earns points for a negative VWAP deviation, lower-band touch, negative z-score, oversold RSI, bullish reversal evidence, return inside the band, range regime, and acceptable spread. The short score mirrors this logic. The default score threshold is **75/100**. A score alone cannot trade: all session, news, spread, volatility, regime, risk, margin, duplicate-order, stop-distance, and target-R:R gates must pass.

## 3. Risk and execution controls

The EA uses MQL5's `CTrade` class for live market orders and stop modifications. The code explicitly sets the filling mode based on the symbol, uses synchronous requests, and checks trade-server return codes after every entry, close, and protected modification; a `true` result from `Buy` or `PositionModify` alone is not treated as an execution confirmation. MQL5’s own documentation makes this distinction explicit.[1] [2] [3]

| Control | Default | Behavior |
| --- | ---:| --- |
| Risk per trade | 0.50% of equity | Floors volume to the broker’s volume step, rather than rounding upward, then checks tick value, tick size, volume constraints, and margin. |
| Initial stop | 1.2 × ATR | Enforces broker stop distance and normalizes to tick size. |
| Target | Hybrid | Uses a valid mean target from VWAP / middle band; entry is rejected if projected R:R is below the configured minimum. |
| Minimum R:R | 1.2R | Rejects targets too close to entry. |
| Daily loss lock | 2% of daily-start equity | Stops entries; can close EA-owned positions if enabled. Resets on the next broker-server day. |
| Daily profit target | Disabled, 3% configured | Stops new entries only when enabled. |
| Drawdown lock | 10% of equity high-water mark | Persists via terminal global variables and requires manual reset through `InpManualResetRiskLock=true`. |
| Trade count cap | 5 closed positions/day | Blocks new entries after the cap. |
| Consecutive loss circuit breaker | 3 losses / 60 minutes | Pauses entries and then forces a reassessment rather than revenge-trading. |
| Post-trade cooldown | 10 minutes | Limits repeated entries from indicator noise. |
| Portfolio risk guard | 1.5% | Adds open EA-position risk and projected new-trade risk before allowing entry. |
| Correlation guard | 1.0% | For currency symbols, limits risk where existing EA positions share a base or quote currency. |
| Spread / execution filter | 1.5 pips default | Supports pips, points, or ATR-percent caps; also rejects stale or missing quotes. |
| News blackout | 15 minutes before / 30 minutes after | Uses the terminal economic calendar for identifiable FX currencies. With fail-closed mode, an unavailable calendar blocks new entries. |

The terminal calendar uses **trade-server time**, not local desktop time. Session windows and the calendar filter are therefore evaluated using server time to avoid an implicit local-time shift.[4]

## 4. Installation and compilation

Copy the `Experts/MR_Sniper_MeanReversion.mq5` file to the terminal data folder at:

```text
MQL5/Experts/MR_Sniper_MeanReversion.mq5
```

Open the file in **MetaEditor**, select **Compile**, and resolve any terminal/build-specific warnings before testing. This environment does not include MetaEditor or an MQL5 compiler, so **a terminal-side compilation is still required**; the package has received structural and API-oriented static review but must not be described as compiled until that step is complete.

After a successful compilation, restart the terminal or refresh the Navigator pane, locate **MR_Sniper_MeanReversion**, and attach it to an M5 chart. In the EA properties, load one of the supplied `.set` files from `Presets/`. Every preset intentionally sets `InpEnableTrading=false`. Leave this value disabled through initial backtests and demo validation. Before any demo activation, set a unique `InpMagicNumber` and validate the broker symbol’s digits, stop level, volume step, and execution model.

The EA contains no broker password, account password, credential storage, concealment routine, or mechanism to bypass a broker restriction. It only manages positions whose magic number equals `InpMagicNumber`.

## 5. Configuration and multi-symbol operation

The supplied presets are **research baselines**, not universal production settings. Use the chart’s broker symbol name exactly, including suffixes, and set an instrument-specific spread limit. XAUUSD and indices commonly need different point, tick-value, session, and spread settings from major FX pairs.

| Preset | Risk/trade | Entry threshold | Filters | Intended use |
| --- | ---:| ---:| --- | --- |
| Conservative | 0.25% | 85 | Strict trend / spread / session / R:R constraints | First baseline and fragile-market evaluation. |
| Balanced | 0.50% | 75 | Moderate trend control and default risk controls | Main research baseline. |
| Aggressive | 0.75% | 70 | Moderate filter, shorter cooldown, wider spread cap | Controlled sensitivity research only. |

For multi-symbol operation, attach one instance to each intended symbol while using the **same magic number** across the coordinated instances. The code’s portfolio and shared-currency exposure checks aggregate open positions under that magic number. This is a safe per-symbol deployment model rather than a single chart process attempting to subscribe to and execute every symbol asynchronously. It does not calculate statistical correlations; its FX correlation control is a conservative shared-currency proxy. Do not use the proxy as a substitute for a tested portfolio-correlation model.

## 6. Dashboard and logs

The lightweight chart label reports status, market regime, action, key indicators, long/short scores, current risk locks, daily P/L, drawdown, trade count, and **broker-server time**. The dashboard does not perform trade operations.

The EA writes a CSV log under the active terminal data folder’s `MQL5/Files/` directory, using the format:

```text
MR_Sniper_<symbol>_<magic>_<broker-server-date>.csv
```

It records executed entries, exits observed through trade transactions, signal rejections, risk rejections, portfolio rejections, execution failures, and indicator/data rejections. A failed file write does not block risk logic; the failure is printed to the Experts log.

## 7. Backtesting protocol

Use the MT5 Strategy Tester with the EA compiled from this package. Select the correct broker symbol and set the chart period to `M5` unless evaluating a different permitted execution timeframe. Use the most granular available tick modelling and a data span that contains multiple market regimes; a minimum of one, three, and five years should be examined where reliable broker-quality history exists.

| Test control | Required practice | Reason |
| --- | --- | --- |
| Data basis | Use the same broker-symbol specification, commissions, swaps, and execution settings expected for forward testing. | FX / metals / index contract settings and costs are not interchangeable. |
| Costs | Stress spread, slippage, and commission assumptions. | Scalping results can be dominated by execution costs. |
| Periods | Segment range, trend, high-volatility, low-volatility, news, rollover, and wide-spread conditions. | A mean-reversion rule should be evaluated outside its preferred range regime. |
| Report | Record net and gross P/L, profit factor, expectancy, drawdown, recovery factor, trade count, win/loss size, losing streak, and trade duration. | A high-profit period alone does not establish robustness. |
| Safety checks | Deliberately test disabled trading permissions, invalid stops, insufficient margin, stale quotes, rejected orders, calendar errors, daily loss lock, drawdown lock, and duplicate ticks. | Confirms the no-trade / fail-safe paths. |

The code provides `OnTester()` as a **custom optimization criterion** that favors a combination of profit factor, recovery factor, limited drawdown, and a trade-count penalty. It is not a profitability claim and should never be optimized alone.

## 8. Optimization and walk-forward protocol

Restrict optimization to a small, interpretable parameter set. Recommended candidates are `InpMinimumSignalScore`, `InpVWAPDeviationATR`, `InpZScoreThreshold`, `InpADXTrendThreshold`, `InpATRStopMultiplier`, `InpMinimumRR`, session windows, and the instrument-specific spread cap. Keep structural risk protections, magic isolation, broker stop protections, and trading-disabled initialization out of broad optimization sweeps.

A practical walk-forward sequence uses six months of in-sample development followed by three months of untouched out-of-sample testing, rolling forward through the full sample. Select **stable plateaus**, not isolated best points. Compare in-sample and out-of-sample profit factor, drawdown, expectancy, trade count, and parameter drift. If performance depends on a narrow parameter combination or collapses after realistic costs are worsened, reject the configuration.

> **Do not use a settings file that was selected on the full data history as the evidence for the same full history.** That is an in-sample result, not independent validation.

## 9. Monte Carlo robustness testing

Export a clean table with **one fully closed position per row** and realised net P/L in account currency. Consolidate partial exits first. Then run the supplied tool from any system with Python 3:

```bash
python3 monte_carlo.py \
  --input closed_positions.csv \
  --profit-column Profit \
  --runs 10000 \
  --starting-equity 10000 \
  --cost-shock 10 \
  --entry-noise 5 \
  --ruin-drawdown-pct 30 \
  --output monte_carlo_summary.json
```

The utility bootstrap-resamples trade outcomes, applies an optional adverse cost shock and execution noise, and reports percentile distributions for terminal P/L, maximum drawdown, and maximum losing streak. Its “ruin” metric is only a configurable drawdown-threshold proxy; it is **not** an actuarial probability of ruin. The script cannot model a structural regime break, a broker outage, liquidity disappearance, or an unobserved correlation change unless those effects are represented in the input sample.

## 10. Acceptance checklist

| Area | Package implementation | User-side validation still required |
| --- | --- | --- |
| Real trading API | `CTrade.Buy`, `CTrade.Sell`, `PositionModify`, and ticket-level `PositionClose` are used. | Compile in MetaEditor; demo-test actual broker return codes and filling modes. |
| Sizing and price normalization | Uses equity risk, tick size/value, floored volume step, broker stop level, tick normalization, and margin pre-check. | Test exact contract settings for each broker symbol. |
| Duplicate / manual trade isolation | Blocks existing positions on the symbol, blocks EA-owned pending orders, uses magic-number filtering for management. | Validate on both netting and hedging demo accounts if relevant. |
| Risk locks | Daily loss, daily target, drawdown, trade count, loss cooldown, post-trade cooldown, portfolio and shared-currency checks are implemented. | Test persistence across terminal restart and broker-server day change. |
| Market filters | Session, rollover, spread, stale-tick, volatility, ADX/EMA regime, and economic calendar gates are implemented. | Validate your broker’s server time and calendar availability. |
| Research tooling | Presets, custom tester objective, detailed logs, a backtest protocol, walk-forward process, and Monte Carlo tool are provided. | Produce independent in-sample, out-of-sample, and forward-demo reports. |

## 11. Troubleshooting

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| EA will not compile | Terminal build mismatch, edited source, or a local MetaEditor error. | Compile in MetaEditor and correct the first listed error before evaluating secondary errors. Keep the official MT5 standard library available. |
| No trades in Strategy Tester | Filters are designed to be restrictive; trading may also be disabled by the preset. | Read the CSV / Experts log for the rejection reason, then verify `InpEnableTrading`, session times, score threshold, range regime, news state, and spread cap. |
| “News calendar unavailable; fail-closed enabled” | The broker terminal cannot provide applicable calendar data or symbol currencies were not recognized. | Keep fail-closed during production-quality testing. If you deliberately disable it for research, document the changed risk assumption. |
| “Position size invalid” | The risk-sized volume is below broker minimum, tick properties are unavailable, or margin is insufficient. | Check contract specification, risk percentage, stop distance, free margin, and volume step. Do not force the volume upward. |
| Rejected SL / TP or modification | Broker stop/freeze distance or price normalization constraint. | Confirm symbol stop/freeze levels and test with wider ATR multiplier/buffer; check the trade-server retcode in Experts log. |
| Drawdown risk lock persists | This is intentional protection using terminal global variables. | First investigate why it occurred. For a deliberate, auditable reset, set `InpManualResetRiskLock=true` for one initialization, then return it to false. |
| Multiple positions / unexpected netting behavior | Netting and hedging accounts behave differently. | Use one instance per symbol; the EA blocks any existing position on its chart symbol before entry. Test the intended account mode on demo. |
| XAUUSD or an index is perpetually rejected | FX default caps may be unsuitable for a non-FX contract. | Derive per-symbol session, spread, ATR, and stop settings from the broker’s actual contract specification and test separately. |

## 12. Important limitations

The EA is a **per-symbol chart instance** architecture. Shared portfolio risk is coordinated through the same magic number, but it does not provide a single-process multi-symbol event bus or full covariance matrix. It contains a calendar-based filter for FX symbols with identifiable base/quote codes; opaque broker names and many non-FX CFDs may fail closed by design. A failed or unavailable indicator, quote, calendar request, execution precondition, or uncertainty condition leads to **no new trade**.

No source code can establish a statistical edge by itself. The appropriate progression is: compile → historical test with realistic costs → out-of-sample validation → walk-forward study → Monte Carlo stress test → extended demo forward test → only then make an independent decision about any constrained live use.

## References

[1] [MQL5 Reference — CTrade](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade)  
[2] [MQL5 Reference — CTrade::Buy](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuy)  
[3] [MQL5 Reference — CTrade::PositionModify](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionmodify)  
[4] [MQL5 Reference — CalendarValueHistory](https://www.mql5.com/en/docs/calendar/calendarvaluehistory)
