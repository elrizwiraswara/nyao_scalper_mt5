# Nyao Scalper v42.0

**Indicator-Based Signal Strength EA for MetaTrader 5**

> **Disclaimer:** This Expert Advisor is an experimental project for educational purposes. Trading Forex/CFDs involves significant risk. Past performance is not indicative of future results. Use at your own risk.

Nyao Scalper is an automated trading EA designed for scalping on lower timeframes (M1, M5). It uses a **weighted signal scoring system** that aggregates data from multiple technical factors (Trend, Momentum, Volatility, Price Action) into a single confidence score (0.0 - 10.0).

It includes position management, adaptive trailing stops, and lot sizing based on equity performance and signal quality.

## Key Features

### Signal Scoring

The EA calculates a "Signal Score" for every tick based on:

- **Trend**: Fast/Slow EMA crossover and slope alignment.
- **Momentum**: RSI "sweet spots" (trending ranges), breakouts, and candle body momentum.
- **Impulse**: Detects price acceleration and directional continuity (consecutive candles).
- **Volatility**: ATR-based analysis to detect chopping vs. trending markets.
- **Price Action**: Penalizes signals with large opposing wicks (rejection) and rewards breakouts from local peaks.
- **Velocity**: Tracks the _change_ in signal score to detect strengthening or weakening moves.
- **Blended Weighted Average Signal Smoothing**: Combining recent closed candle signals with a configurable dampened current candle contribution for improved responsiveness while maintaining signal stability.
- **Multi-Bar EMA Slope** _(new in v42)_: Trend slope is measured over `SlopeLookback` bars instead of a single bar, reducing M1 whipsaw.
- **Dead-Market Filter** _(new in v42)_: When ATR collapses relative to its average (`ATR/AvgATR < MinVolRatioToTrade`), the signal is zeroed — the EA does not scalp a market too quiet to overcome costs.
- **New-Bar Entry Evaluation** _(new in v42, default on)_: With `EnableNewBarEntryOnly`, entries are evaluated once per closed bar (position management still runs every tick). This removes intrabar signal repaint and makes backtests representative of live behavior.
- **Per-Tick Caching**: Signal scores are computed once per tick and cached, eliminating redundant calculations across position management, trailing, and dashboard systems.

### Risk & Equity Management

- **Equity Protection**:
  - **Min Equity Stop**: Hard stop if equity falls below a specific dollar amount.
  - **Max Drawdown Stop**: Stops trading if drawdown from peak exceeds a set limit.
  - **Daily Target**: Optional target profit to stop trading for the day.
- **Basket Stop** _(new in v42)_: Portfolio-level backstop. Closes **all** positions and pauses when total floating loss exceeds a % of equity (`MaxBasketLossPct`) — protects against compounding drawdown from stacked positions, independent of per-position stops.
- **Max-Spread Filter** _(new in v42)_: Blocks new entries when the spread is too wide (fixed `MaxSpreadPoints`, or auto-derived from ATR via `MaxSpreadATRRatio`). Critical for cost control on M1 gold.
- **Signal Dampening**: Position-aware system that penalizes signal scores when holding losing positions and raises entry thresholds during drawdown periods.
- **News Filter**: Automatically pauses trading before and after high-impact news events.
- **Trading Hours**: Configurable start and end times to avoid low-liquidity sessions.
- **Leverage Guard**: Pauses trading if account leverage changes unexpectedly.

### Position Management

- **Duplicate Signal Filter**: Uses "Zone Points" and minimum distance multipliers to prevent over-stacking positions.
- **Adaptive Trailing**:
  - Standard trailing stop logic.
  - **Signal-Based Adaptation**: Tightens or loosens TP/SL based on real-time changes in the Signal Score.
- **Loss Management**:
  - **Position Health Revalidation**: Continuously evaluates trade thesis using trend alignment, RSI zone, adverse ATR excursion, and swing structure — weighted health score determines hold/exit decisions.
  - **Scaled Partial Close**: Gradually reduces position volume as signal decays (75% → close 25%, 50% → close 50%, 25% → full exit).
  - **Dynamic SL Tightening**: Pulls stop-loss closer proportionally as position health weakens below a threshold.
  - **Break-Even Lock**: Moves SL to entry price once profit exceeds spread cost, protecting gains.
  - **Virtual SL + Re-entry**: Closes losing positions at the health threshold, then immediately re-enters at the current (better) price if the signal is still valid.
  - **Profit Offset SL**: Tightens SL of losing positions using accumulated profits from consecutive winning trades.

### Hedge Chain Recovery (Optional)

> ⚠️ **This is a martingale.** Lot size grows as a losing trade is hedged and re-hedged. It can recover many drawdowns smoothly but carries genuine **ruin risk** in strongly trending or choppy markets — it converts frequent small losses into rarer large ones. It is **opt-in per profile** (`EnableHedgeChain`) and **off in the `safe` profile by design**. Size `HedgeMaxLot` and the loss caps for an account you can afford to draw down.

When a position moves into loss by `HedgeTriggerATR × ATR` **and the reverse-direction signal confirms** (`HedgeRequireSignal`: the opposite-side score ≥ `HedgeMinSignalScore`), the EA opens a reversed **hedge** and manages the pair as a *rolling chain* — at most two legs open at a time. The signal gate is an **anti-spike filter**: a wick that crosses the ATR trigger intrabar but isn't a real reversal won't have a strong opposite-side score, so no hedge is opened — the chain waits for the move to be confirmed (or the position to recover).

- **Recovery Sizing** (`HedgeAutoLot`): each hedge lot is *computed* so its profit covers `HedgeRecoveryPct%` of the leg it hedges within a `HedgeRecoveryATR × ATR` favorable move — instead of a blind fixed multiplier (which often can't catch up before price reverses). Falls back to `HedgeLotMultiplier` when auto-sizing is off, and is always clamped to `HedgeMaxLot`.
- **Covered**: hedge profit covers the older leg's current loss → close the older leg; the hedge graduates and trails to ride for more. Because a graduated hedge carries a **large (martingale) lot**, it trails at **`HedgeTrailATR × ATR`** (lot-independent) rather than the dollar-based `TrailingDistanceValue` — a small dollar distance on a big lot becomes a near-zero price gap that would close the position instantly. Set `HedgeTrailATR = 0` to fall back to the normal trailing settings.
- **Roll**: hedge is losing but the older leg has recovered to break-even → close the older leg (free) and open a larger reverse hedge against the current one. Repeats up to `HedgeCycleLevels` per cycle.
- **Reseed**: at the cycle/lot limit, partial-close the deepest hedge by `HedgeCyclePartialPct%` and start a fresh, smaller cycle (up to `HedgeMaxCycles`) — capping lot growth instead of stacking ever-larger legs.
- **Exhausted → release** (not closed): once the chain can no longer expand (`HedgeMaxCycles` reached, or the `HedgeMaxLot` ceiling hit with reseed off), the legs are **handed back to the adaptive loss management** — trailing, health-revalidation, partial close — and flagged so no new hedge is started on them. The chain is **not** force-closed at this point.
- **Optional hard stop** (`HedgeMaxChainLossPct` / `HedgeMaxChainLossUSD`, **default 0 = off**): if set, closes the whole chain when its combined loss crosses the cap. Off by default so the chain is bounded by cycles + lot and then released.

While a chain is active its legs are excluded from the standard trailing/loss-management **and from the portfolio basket stop** (a chain's transient drawdown must not trip it) — the chain is governed solely by its own cycle/lot limits. Once released (or after the optional hard stop), the legs become normal positions again and the basket stop covers them. The first position's stop-loss is cleared on chain start so the chain logic alone governs the pair.

### Lot Sizing

- **Recovery Mode**: Increases lot size incrementally after equity drops for faster recovery. _Guardrails (new in v42):_ capped at `MaxEquityDropLotSteps` total steps, and **disabled** while in a post-loss cooldown or while the basket is in floating loss — so size never scales up while actively bleeding.
- **Confidence Mode**: Increases lot size for high-confidence signals (e.g., Score > 8.0).
- **Velocity Boost**: Slightly increases position size if signal velocity (momentum) is accelerating.

### Dashboard & Alerts

- **On-Chart Dashboard**: Real-time display of Signal Scores, Equity, Drawdown, and Statistics.
- **Discord Integration**: Sends alerts to Discord via Webhook for:
  - Trade Open/Close
  - Equity Milestones
  - News Events
  - Trading Pauses/Resumes

## Strategy Logic

The strategy uses a **weighted scoring system** (0.0 - 10.0 scale). A trade is taken only if the _Total Score_ exceeds the `MinSignalScore` threshold (Default: 4.5).

> **v42 calibration note:** The Chop and Volatility components no longer add "free" points in a dead/quiet market (their low tiers default to `0.0`), so the score now discriminates regime instead of always rewarding it. Thresholds were lowered accordingly (~1.0) across all profiles. Additionally, when `ATR/AvgATR` falls below `MinVolRatioToTrade` the score is forced to `0` (no trade).

**Note:** All scoring weights (Trend, Momentum, Volatility, etc.) are **fully adjustable** in the EA settings, allowing you to customize the strategy's sensitivity to different market conditions.

The score is calculated by summing up weights from specialized components:

1.  **Trend Score (Max 3.0)**:
    - **Alignment (+1.5)**: Fast EMA > Slow EMA (Buy) or Fast EMA < Slow EMA (Sell).
    - **Slope (+1.5)**: Fast EMA is rising (Buy) or falling (Sell).

2.  **Momentum Score (Max 3.0)**:
    - **RSI Sweet Spot (+1.0)**: RSI between 50-80 (Buy) or 20-50 (Sell).
    - **RSI Breakout (+0.5)**: RSI crossing key levels (60 for Buy, 40 for Sell).
    - **Body Momentum (+1.5)**: Current candle body is larger than the recent average.
    - **Impulse Boost**: Momentum score is multiplied by `(1 + ImpulseStrength)` where impulse combines:
      - Body acceleration (current vs. average body size)
      - Range expansion (current vs. average candle range)
      - Directional continuity (consecutive same-direction candles)

3.  **Volatility & Structure (Max 4.0)**:
    - **Chop Filter (Max 2.0)**: ATR ratio classifies trend strength vs. chop risk. In a low-volatility (chop) regime the low tier contributes `0.0` by default — no free points.
    - **Volatility (Max 1.0)**: Expanding volatility (ATR ratio > 1.2) adds to the score; a quiet market adds `0.0` by default.
    - **Dead-Market Block**: If `ATR/AvgATR < MinVolRatioToTrade`, the entire signal is zeroed (the market is too quiet to scalp).
    - **Peak Breakout (+1.0)**: Price breaking above/below local extremes (recent 5-bar high/low).

4.  **Penalties (Deductions)**:
    - **Wick Rejection**: Long opposing wicks (e.g., long upper wick on a Buy signal) reduce the final score by the wick-to-body ratio.

5.  **Velocity Tracking**:
    - Tracks the _change_ in signal score between bars to detect strengthening or weakening moves.
    - Used for adaptive trailing stop adjustments and dynamic lot sizing.

6.  **Signal Smoothing (Blended Weighted Average)**:
    - Combines weighted average of recent closed candles with a dampened current candle contribution.
    - **SignalSmoothingCandles**: Number of closed candles to average (1-10, default per profile).
    - **CurrentCandleBlend**: Weight factor for the forming candle (0.0-1.0, where 0.0 = closed candles only, 1.0 = current candle only).
    - Results in smooth yet responsive signal scoring that adapts to market conditions.

**Entry Condition**: `Total Score` >= `MinSignalScore`

### Entry Execution (Market vs. Limit)

By default, a qualifying signal opens **at market** (current Ask/Bid). Optionally, fresh entries can be placed as a **pending pullback limit** instead:

- **`EnableLimitEntry`** _(default off)_: When on, a fresh signal places a Buy Limit below the Ask (or Sell Limit above the Bid), aiming for a better fill on a small retracement rather than chasing the move at market.
- **`LimitEntryAnchor`**: Where the limit is placed —
  - **Fixed ATR** _(default)_: a flat depth of `LimitEntryATRFraction × ATR` below/above price. Simplest; easiest to reason about.
  - **EMA**: at the fast EMA (a natural M1 retracement target).
  - **Swing**: at the recent swing low/high (`HealthSwingLookback` bars) — pure structure.
  - **Smart**: the *nearer-to-price* of the swing level and the fast EMA, so the limit lands at a price that means something.
  - For EMA/Swing/Smart, `LimitEntryATRFraction` acts as a **cap** — the limit is never placed deeper than that ATR fraction (so you never wait absurdly far), and it always respects the broker stop level. If no valid level sits on the pullback side, it falls back to the fixed depth.
- **`LimitEntryATRFraction`**: Fixed pullback depth (Fixed-ATR mode) / maximum pullback cap (EMA/Swing/Smart modes), as a fraction of ATR.
- **`LimitEntryExpiryBars`**: Cancels an unfilled limit after N bars (managed internally, broker-agnostic).
- **`LimitEntryCancelOnFlip`**: Cancels the pending if the directional signal drops back below its threshold before filling.
- **Scope**: This affects **fresh entries only**. Virtual-SL re-entries always execute at market — their purpose is to restore exposure immediately, so they must not risk going unfilled.

> **Trade-off:** A pullback limit improves average fill price but **lowers fill rate** — strong momentum/breakout moves (which this EA's scoring favors) often run without retracing, so the best moves may be missed while weaker, stalling signals fill preferentially. Backtest both modes before committing; it is off by default for this reason.

## Settings Profiles

Pre-configured settings files are available in the `settings/` folder. Load them via MetaTrader 5: **Charts → Templates** or manually copy values.

| Profile | Signal Threshold | Frequency | Risk | Best For |
|---------|:---:|:---:|:---:|---|
| **aggressive** | 3.5 | Very High | High | Maximum profit capture, larger lots, widest stops. High risk — use only with capital you can afford to lose. |
| **safe-aggressive** | 4.0 | High | Medium-Low | Fast entries with safe lot sizing, strong dampening, fast break-even locks. Best for small accounts ($200+). |
| **default** | 4.5 | Medium-High | Medium | M1 scalping-optimized baseline. Balanced signal response and risk management. |
| **balanced** | 5.0 | Medium | Medium | Quality entries with moderate exposure. Suitable for everyday trading. |
| **safe** | 6.0 | Low | Low | Highest conviction trades only, minimal exposure, tightest risk controls. Highest win rate. |

> Thresholds were lowered by ~1.0 vs. v41 because the scoring no longer adds "free" chop/volatility points (see the v42 calibration note above) — relative selectivity between profiles is unchanged.

### Profile Comparison

| Setting | Aggressive | Safe-Aggressive | Default | Balanced | Safe |
|---------|:---:|:---:|:---:|:---:|:---:|
| Base Lot | 0.03 | 0.01 | 0.01 | 0.01 | 0.01 |
| Max Lot | 0.10 | 0.03 | 0.05 | 0.05 | 0.01 |
| Max Open Orders | 12 | 8 | 8 | 6 | 3 |
| **Per-Trade SL (% equity)** | 1.5% | 0.8% | 1.0% | 0.8% | 0.5% |
| **Basket Stop (% equity)** | 12% | 7% | 8% | 6% | 3% |
| **Max Spread (ATR ratio)** | 0.35 | 0.28 | 0.25 | 0.22 | 0.20 |
| **Min Vol Ratio to Trade** | 0.50 | 0.55 | 0.60 | 0.65 | 0.70 |
| **Max DD Lot Steps** | 3 | 2 | 2 | 2 | 0 |
| Slope Lookback | 2 | 2 | 3 | 3 | 4 |
| Smoothing Candles | 1 | 2 | 2 | 2 | 3 |
| Current Candle Blend | 0.60 | 0.45 | 0.40 | 0.35 | 0.25 |
| Max Holding Loss Pos | 4 | 2 | 2 | 2 | 1 |
| Dampening Penalty | 1.0 | 1.8 | 1.5 | 1.5 | 2.0 |
| Break-Even Lock | 2.0x | 1.2x | 1.5x | 1.5x | 1.0x |
| Virtual SL Re-entry | On (50%) | On (65%) | On (75%) | On (75%) | Off |
| Dynamic Lots | On | On (capped) | On | On | Off |
| News Filter | 15/15 min | 25/25 min | 30/30 min | 30/30 min | 45/45 min |
| **Hedge Chain** | On | On | On | On | **Off** |
| Hedge Max Lot | 0.30 | 0.04 | 0.10 | 0.06 | 0.02 |
| Hedge Cycles × Levels | 4 × 3 | 2 × 2 | 3 × 2 | 3 × 2 | 1 × 2 |
| Hedge Hard Loss Cap | Off | Off | Off | Off | Off |

> The hedge chain is bounded by **cycles × levels** and **max lot**; when exhausted it is **released to the adaptive loss management** rather than force-closed. The optional hard loss cap (`HedgeMaxChainLossPct`/`USD`) ships **off** in every profile — set it if you want a fixed catastrophic-loss close.

> **Stop Loss units are now consistent** across all profiles — every profile uses `SLInputType = Percent of Equity`, so per-trade risk is comparable and scales with account size. (In v41 the SL unit type varied by profile, which made the magnitudes contradict each profile's stated philosophy.) Per-trade SL × Max Open Orders is kept roughly in line with each profile's Basket Stop.

### Recommended Profile by Account Size

| Account Size | Recommended | Notes |
|---|---|---|
| $100-200 | **safe-aggressive** | Fast entries but strict risk controls, capped lot sizing |
| $200-500 | **safe-aggressive** or **default** | Safe-aggressive for growth, default for stability |
| $500-1000 | **default** or **balanced** | Room for moderate exposure |
| $1000+ | Any profile | Account can absorb drawdowns from aggressive profiles |

## Installation

1.  **Copy File**:
    Place `nyao_scalper.mq5` into your MetaTrader 5 `Experts` folder.
    - File -> Open Data Folder -> MQL5 -> Experts

2.  **Dependencies**:
    Ensure `WinAPI` and `Controls` libraries are available (standard in MT5).

3.  **Allow WebRequest** (For Discord Alerts):
    - Go to `Tools` -> `Options` -> `Expert Advisors`.
    - Check "Allow WebRequest for listed URL".
    - Add your Discord Webhook URL (if using alerts).

4.  **Compile**:
    Open the file in MetaEditor and press `F7` or click "Compile".

5.  **Run**:
    Drag the EA onto a chart (Recommended: XAUUSD, EURUSD on M1/M5).

## Alternative Compilation (VS Code)

If you prefer coding in Visual Studio Code, you can compile `.mq5` files directly using the **MQL5/MQL4** extension (also known as Buraq).

1.  **Install Extension**:
    - Open VS Code Extensions (`Ctrl+Shift+X`).
    - Search for `Buraq MQL5` or `sarfrazfrompk`.
    - Install **[MQL5/MQL4](https://marketplace.visualstudio.com/items?itemName=sarfrazfrompk.buraq-mql5-mql4)** by `sarfrazfrompk`.

2.  **Configure Path**:
    - Go to Extension Settings (`Ctrl+,`).
    - Search for `MQL5`.
    - Set `Mql5: Metaeditor Path` to your `metaeditor64.exe` location.
    - _Example:_ `C:\Program Files\MetaTrader 5\metaeditor64.exe`

3.  **Compile**:
    - Open `nyao_scalper.mq5` in VS Code.
    - Right-click anywhere in the code.
    - Select **MQL5: Compile**.
    - Check the Output terminal for success or errors.

## Backtesting Honestly

Results in the Strategy Tester only mean something if the test mirrors live conditions. For this EA specifically:

1.  **Use "Every tick based on real ticks"** (Strategy Tester → Modeling). Lower-fidelity modes can misrepresent intrabar behavior. With `EnableNewBarEntryOnly = true` (default) entries are decided on bar close, so `1 minute OHLC` is also reasonable for a faster sweep — but validate the final candidate on real ticks. **Note:** Virtual-SL re-entries fire intrabar by default (immediately at the better price); set `ReentryRespectsNewBarGate = true` if you want re-entries to also wait for bar close so an `OHLC`/`Open prices` backtest has no intrabar entries at all.
2.  **Include realistic costs.** Set your broker's **commission** in the tester and test on a **realistic spread** (ideally the symbol's actual spread, not 0). On M1 XAUUSD, spread + commission is the dominant cost — a backtest without them is meaningless.
3.  **Know what the tester can't see.** `CalendarValueHistory` (the high-impact **news filter**) generally returns nothing inside the Strategy Tester, so backtests run **without** news protection that live trading has. Treat tester drawdowns around news as optimistic.
4.  **Validate out-of-sample.** With this many tunable inputs, in-sample optimization overfits easily. Tune on one period, then confirm on a separate untouched period (or use walk-forward) before trusting a profile.
5.  **Sanity-check the new v42 guards** via the journal: confirm entries fire only on bar close, that trades are skipped when spread is wide or ATR has collapsed, and that the **Basket Stop** closes everything once floating loss crosses `MaxBasketLossPct`.

> No equity curve is bundled with this repo. Capture your own tester report (real ticks + commission, out-of-sample) before running any profile on a funded account.

## What's New in v42

- **Max-spread entry filter** and **portfolio basket stop** (close-all on aggregate floating loss).
- **Drawdown lot-scaling guardrails**: capped steps; never scales up during cooldown or while the basket is in loss.
- **New-bar entry evaluation** (stable signals, honest backtests) and **dead-market filter** (skip collapsed-ATR regimes).
- **Multi-bar EMA slope**; chop/volatility no longer add free points (thresholds recalibrated).
- **Consistent Stop-Loss units** across all profiles (percent of equity), re-tuned so each profile matches its stated aim.
- **Hedge Chain recovery (optional, martingale)**: rolling reverse-hedge with computed recovery-lot sizing and cycle reseeding (partial-close instead of unbounded lot growth). Bounded by **cycles + max lot**; when exhausted the legs are **released to the adaptive loss management** rather than force-closed, and active chains are **exempt from the basket stop** so their transient drawdown doesn't trip it. Optional hard loss cap ships off. Opt-in per profile; **off in `safe`**. ⚠️ High risk — see the [Hedge Chain Recovery](#hedge-chain-recovery-optional) section.
- Code cleanup (unified entry-condition logic) and repo hygiene (`.ex5` no longer tracked).

## Credits

**Author**: Elriz Wiraswara<br/>
**License**: BSD-3-Clause (Open Source)<br/>
**Repository**: [https://github.com/elrizwiraswara/nyao_scalper_mt5](https://github.com/elrizwiraswara/nyao_scalper_mt5)

> **Disclaimer:** I do not sell or commercialize this EA under my name. If you encounter anyone selling it claiming to represent me, please treat it as a scam and report it.
