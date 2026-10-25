# Nyao Scalper v54.0

![Nyao Scalper MT5: a gold trade on a 7.4 trend score, the stop climbing behind the price at each $20 checkpoint until the exit](assets/cover.png)

**Indicator-Based Signal Strength EA for MetaTrader 5**

> **Disclaimer:** This Expert Advisor is an experimental project for educational purposes. Trading Forex/CFDs involves significant risk. Past performance is not indicative of future results. Use at your own risk.

Nyao Scalper is an automated trading EA designed for scalping on lower timeframes (M1, M5). It scores how strongly price has trended over the last several hours (range position, EMA distance, directional efficiency and net move) into a single score from 0.0 to 10.0, and trades in the direction of the daily trend.

It includes position management, adaptive trailing stops, and lot sizing based on equity performance and signal quality.

The repository also contains **Nyao Straddle** (`nyao_straddle.mq5`), a separate and more experimental EA that trades gold only in extreme markets and can run next to Nyao Scalper on the same account. See [Nyao Straddle](#nyao-straddle-companion-ea).

## Key Features

### Signal Scoring

The EA scores buys and sells from 0.0 to 10.0 on every tick (see [Strategy Logic](#strategy-logic)):

- **Trend score**: how strongly price has trended over the last several hours: its position in the recent high-low range, its distance from a slow EMA, how efficiently it moved and its net move. Every part is continuous and directional, so the score changes smoothly and buy + sell always add up to 10.
- **Velocity** _(informational)_: Tracks the _change_ in signal score between bars and shows it on the dashboard. It is not used for any trading decision.
- **Blended Weighted Average Signal Smoothing**: Combining recent closed candle signals with a configurable dampened current candle contribution for improved responsiveness while maintaining signal stability.
- **Dead-Market Filter** _(off in the default profile: `MinVolRatioToTrade = 0`)_: When the last closed candle's ATR collapses relative to its average (`ATR/AvgATR < MinVolRatioToTrade`), new entries, re-entries and pending limits are blocked — the EA does not scalp a market too quiet to overcome costs. (Open positions are still managed normally.)
- **New-Bar Entry Evaluation** _(default on)_: With `EnableNewBarEntryOnly`, entries are evaluated once per closed bar on **closed candles only** (the forming candle is ignored for the entry decision, because on the first tick of a bar it holds just that one tick). Position management still runs every tick. This removes intrabar signal repaint and makes backtests representative of live behavior.
- **Per-Tick Caching**: Signal scores are computed once per tick and cached, eliminating redundant calculations across position management, trailing, and dashboard systems.
- **Range Filter** _(off by default)_: `MinEfficiencyToTrade` blocks entries unless the last `RangeFilterPeriod` closed bars moved efficiently **in the signal's direction** (directional efficiency ratio = net move ÷ path travelled). In a sideways market the score peaks right at the range edges — buying the top, selling the bottom — and this filter refuses those entries. Try `0.30` with a 20-bar lookback.
- **ATR-Based Stops** _(opt-in)_: every distance input type (`SLInputType`, `TPInputType`, `TSInputType`) accepts **ATR Multiple**, so stops and trailing scale with current volatility instead of fixed dollars that become too tight as price and volatility rise. `BreakEvenTriggerATR` and `TrailStartATR` delay the break-even lock and trailing until the trade has moved that many ATRs in its favor (0 = legacy dollar/spread triggers).
- **Higher-Timeframe Trend Filter** (`EnableHTFTrendFilter`, _on in the default profile, D1 EMA50_): only allows buys above a rising higher-timeframe EMA, and sells below a falling one. `HTFMinDistancePct` (0.5 in the default profile, 0 = off) also requires the last closed higher-timeframe bar to close at least that % beyond the EMA, so entries are skipped while price hugs it and the trend is unclear.

### Risk & Equity Management

- **Equity Protection**:
  - **Min Equity Stop**: If equity falls below a specific dollar amount (`MinimumEquity`), closes everything and removes the EA from the chart.
  - **Max Drawdown Pause**: Pauses new entries (with growing pause lengths) when equity drops `100 − MinEquityPercent`% below its peak; `MaxMinEquityTriggers` turns repeated triggers into a full stop.
  - **Target Equity**: Optional absolute equity level (`TargetEquity`) at which the EA closes everything and stops for good (not a daily target).
- **Basket Stop**: Portfolio-level backstop. Closes **all non-chain** positions and pauses when their floating loss exceeds a % of equity (`MaxBasketLossPct`) — protects against compounding drawdown from stacked positions, independent of per-position stops.
- **Total Loss Hard Stop**: `MaxTotalLossPct` closes **everything, including hedge chains**, and pauses when the total floating loss crosses the limit. This is the one cap that bounds every position the EA holds.
- **Max-Spread Filter**: Blocks new entries when the spread is too wide (fixed `MaxSpreadPoints`, or auto-derived from ATR via `MaxSpreadATRRatio`). Critical for cost control on M1 gold.
- **Signal Dampening**: Position-aware system that penalizes signal scores when holding losing positions and raises entry thresholds during drawdown periods. The drawdown is the whole account's by default; `DrawdownScope = This EA's Own Trades` measures only the chart's own trades (for several symbols on one account).
- **Loss-Streak Pause** _(`LossStreakPauseCount`, default 4, 0 = off)_: losing trades cluster — after a loss the next trade wins noticeably less often, i.e. the market is temporarily not suited to the signal. After N losses in a row the EA stops opening real trades and **paper-trades** every signal instead (same entry price, stop and first checkpoint/TP). Real trading resumes on the first paper win, or when a still-open real position closes in profit.
- **News Filter**: Automatically pauses new entries before and after high-impact news events. News, basket-stop and drawdown pauses each run on their own timer, so one can't cancel or shorten another.
- **Market-Close Filter**: Stops opening positions `MinutesBeforeClose` minutes before the symbol's quote session ends (daily break or weekend). Back-to-back sessions (e.g. 24:00 → 00:00) count as one continuous session.
- **Trading Hours**: Configurable start and end times to avoid low-liquidity sessions.
- **Leverage Guard**: Pauses new entries if account leverage changes and resumes when it's restored. `CloseAllOnLeverageChange` (default on) also closes all positions — set it off on brokers with dynamic leverage.
- **Restart-Safe State**: With `EnablePersistState` (default on) the EA saves its per-position and account-level state to `MQL5\Files\NyaoScalper\` and restores it after a terminal/VPS restart, recompile, input change or timeframe switch. Set `ResetSavedState = true` once to start fresh (then set it back to false). Not used in the Strategy Tester.
  - Open positions the saved state doesn't cover (no file, reset, or a crash before the save) are still protected. Each gets a stop if it has none, and its checkpoint exit is re-armed.
  - At terminal start the EA waits for the trade-server connection before reading the account.
  - Deposits and withdrawals shift the peak-equity baseline, so a withdrawal is never treated as a drawdown.

### Position Management

- **Duplicate Signal Filter**: Uses "Zone Points" and minimum distance multipliers to prevent over-stacking positions.
- **Adaptive Trailing** _(off in the default profile, which uses the checkpoint trailing stop instead)_:
  - Standard trailing stop logic.
  - **Signal-Based Adaptation**: Tightens or loosens TP/SL based on real-time changes in the Signal Score.
- **Loss Management** _(off in the default profile)_:
  - **Position Health Revalidation**: Continuously evaluates trade thesis using trend alignment, RSI zone, adverse ATR excursion, and swing structure — weighted health score determines hold/exit decisions.
  - **Scaled Partial Close**: Gradually reduces position volume as signal decays (75% → close 25%, 50% → close 50%, 25% → full exit). Each level is evaluated on its own; a level whose partial volume is below the broker minimum (e.g. 25% of 0.01 lot) is skipped, so the 25% full exit still fires on minimum-lot positions.
  - **Dynamic SL Tightening**: Pulls stop-loss closer proportionally as position health weakens below a threshold.
  - **Break-Even Lock**: Moves SL to entry price once profit exceeds spread cost, protecting gains.
  - **Virtual SL + Re-entry**: Closes positions at the health threshold, then immediately re-enters at the current (better) price if the signal is still valid. A re-entry goes through the same checks as a fresh entry (cooldown, per-candle limit, dampening, spread, HTF filter — only the duplicate-distance filter is skipped), and is skipped when a new position would fail the health check itself (otherwise it would just be closed again after its grace bars).
  - **Profit Offset SL**: Tightens SL of losing positions using accumulated profits from consecutive winning trades.

### Hedge Chain Recovery (Optional, Off in the Default Profile)

> ⚠️ **This is a martingale.** Lot size grows as a losing trade is hedged and re-hedged. It can recover many drawdowns smoothly but carries genuine **ruin risk** in strongly trending or choppy markets — it converts frequent small losses into rarer large ones. It is **opt-in** (`EnableHedgeChain`) and **off in the default profile**. Size `HedgeMaxLot` and the loss caps for an account you can afford to draw down.

> **What to expect:** a hedge is a new bet in the opposite direction, against the trend the original trade followed, so it cannot recover losses for free. A covered chain ends near break-even, a stopped chain loses its cap. With the trend-turn gate and the 1.5× SL cap it was roughly neutral in backtests; with a loose gate and a 5%-of-equity cap it lost noticeably.

When a position moves into loss by `HedgeTriggerATR × ATR` **and the reverse-direction signal confirms** (`HedgeRequireSignal`: the opposite-side score ≥ `HedgeMinSignalScore`, default 6.5: the multi-hour trend has clearly turned against the position), the EA opens a reversed **hedge** and manages the pair as a *rolling chain* — at most two legs open at a time. The signal gate is an **anti-spike filter**: a wick that crosses the ATR trigger intrabar but isn't a real reversal won't have a strong opposite-side score, so no hedge is opened — the chain waits for the move to be confirmed (or the position to recover).

- **Recovery Sizing** (`HedgeAutoLot`): each hedge lot is *computed* so its profit covers `HedgeRecoveryPct%` of the leg it hedges within a `HedgeRecoveryATR × ATR` favorable move — instead of a blind fixed multiplier (which often can't catch up before price reverses). Falls back to `HedgeLotMultiplier` when auto-sizing is off, and is always clamped to `HedgeMaxLot`.
- **Covered**: hedge profit covers the older leg's current loss → close the older leg; the hedge graduates and trails to ride for more. Two safeguards on the graduated hedge:
  - **Recovery-locked SL**: its stop is floored at the price that keeps `HedgeRecoveryPct%` of the (now-closed) older leg's loss locked, so the pair can **never give back into a net loss** below the recovery target — the trail only ever rides the SL *above* that floor.
  - **ATR trailing**: because a graduated hedge carries a **large (martingale) lot**, it trails at **`HedgeTrailATR × ATR`** (lot-independent) rather than the dollar-based `TrailingDistanceValue` — a small dollar distance on a big lot becomes a near-zero price gap that would close the position instantly. Set `HedgeTrailATR = 0` to fall back to the normal trailing settings.
- **Roll**: hedge is losing but the older leg has recovered to break-even → close the older leg (free) and open a larger reverse hedge against the current one. Repeats up to `HedgeCycleLevels` per cycle.
- **Reseed**: at the cycle/lot limit, partial-close the deepest hedge by `HedgeCyclePartialPct%` and start a fresh, smaller cycle (up to `HedgeMaxCycles`) — capping lot growth instead of stacking ever-larger legs.
- **Exhausted → release** (not closed): once the chain can no longer expand (`HedgeMaxCycles` reached, or the `HedgeMaxLot` / `HedgeMaxTotalLots` ceiling hit with reseed off), the legs are **handed back to the adaptive loss management** — trailing, health-revalidation, partial close — and flagged so no new hedge is started on them. The chain is **not** force-closed at this point.
- **Chain loss stop** (`HedgeMaxChainLossSL` / `HedgeMaxChainLossPct` / `HedgeMaxChainLossUSD`; the tightest wins): closes the whole chain when its combined loss crosses the cap. It is checked **before** any roll. By default a chain may lose at most **1.5× the base lot's SL loss** ($30 with the default $20 stop at 0.01 lot) or 5% of equity, so it can never cost much more than the stop it replaced.
- **Entry gates**: anything that adds exposure — starting a chain, rolling to a bigger leg, reseeding a cycle — obeys the same blocks as a fresh entry: news window, pauses, trading hours, market close, leverage change and the spread filter. While blocked, an existing pair is simply held (still bounded by the chain loss stop and the total hard stop). Closing actions (covered, stop, release) always run.
- **Concurrency caps**: `HedgeMaxActiveChains` (default 1) limits how many chains can run at once, so a sharp reversal can't open a hedge for every stacked position on the same tick. `HedgeMaxTotalLots` caps the combined volume of all active chain legs; a roll that would exceed it reseeds or releases instead.

While a chain is active its legs are excluded from the standard trailing/loss-management **and from the portfolio basket stop** (a chain's transient drawdown must not trip it). They are still covered by their own chain loss stop and by the **total loss hard stop** (`MaxTotalLossPct`), which includes every position. Once released (or after a stop), the legs become normal positions again and the basket stop covers them. The first position's stop-loss is cleared on chain start (`HedgeClearRootSL`) — only after its hedge has actually been opened — so the chain logic alone governs the pair.

Chain state is saved to disk (see **Restart-Safe State**), so a restart doesn't turn live legs into "new" losing positions that start fresh chains. If no saved state exists, open positions whose comment starts with `Hedge L` are flagged so they never seed a new chain.

### Lot Sizing

- **Risk-Based Lot** _(`RiskPerTradePct`, default 1.25)_: each entry uses the largest lot whose stop-out loses at most this % of equity, capped at `MaxLotSize` (default 0.05), the broker limits and available margin. The lot is rounded down, so it shrinks as a balance shrinks. With the default $20 stop: 0.01 lot on a $2,000 standard account (about 1% risk), 0.05 lot on a $100 cent account (10,000 cents). Works only with a lot-independent stop (Points, ATR); set 0 to trade a fixed `BaseLotSize` instead.
- **Small-Account Cap** _(`MaxRiskPerTradePct`, default 5)_: when even the broker's minimum lot loses more than `RiskPerTradePct`, the EA still trades the minimum lot as long as its stop-out loses no more than this % of equity, and says so (an orange **Lot** line on the dashboard and a daily `[RISK SIZING]` note in the Experts tab, even with logging off). Above the cap the entry is skipped instead of over-risking. With the default $20 stop a standard account trades 0.01 lot at up to 1.25% risk from about $1,600, at 1.25-5% between about $400 and $1,600, and opens nothing below about $400. Set 0 to skip every entry that would risk more than `RiskPerTradePct`.
- **Base Lot**: With `RiskPerTradePct = 0`, every entry starts at `BaseLotSize`, capped at `MaxLotSize`, the broker limits and available margin.
- **Drawdown Recovery Steps** _(`EnableDynamicLots`)_: Adds `LotStepSize` for every `EquityDropPercent`% the equity is below its peak — but **only** when the entry's signal score is at least `MinSignalStrengthForLot` (default 8.0). The score is a gate for these steps, not a separate lot boost. _Guardrails:_ capped at `MaxEquityDropLotSteps` total steps, and **disabled** while in a post-loss cooldown or while the basket is in floating loss — so size never scales up while actively bleeding.

### Dashboard & Alerts

- **On-Chart Dashboard**: Display of Signal Scores, Equity, Drawdown, hedge-chain usage and Statistics (refreshed once per second; hidden in non-visual backtests). Statistics count one trade per closed position (partial closes summed, entry commission included) and show **average win / average loss, expectancy per trade and profit factor** — the numbers that decide profitability, which a high win rate alone can hide.
  - **Lot**: the lot the next entry would use and what it risks at the stop. It turns orange when the broker's minimum lot risks more than `RiskPerTradePct` but is still traded (within `MaxRiskPerTradePct`), and reads `NONE` with the reason when even the minimum lot is over that cap (the status then reads _No Entries (Account Too Small)_ and the Experts tab gets a `[RISK SIZING]` warning at start-up and hourly, even with logging off).
  - **BUY / SELL SCORE**: the live score (closed bars blended with the forming one). Below it, **Entry** is what the next bar's entry decision actually uses: the closed-bar score after the losing-position penalty against the effective minimum, with each boost listed (consecutive candles, drawdown).
  - **Ready / Blocked**: the first gate that currently stops a new trade that way, e.g. _needs a D1 uptrend_, _score 4.80 below 5.00_, _spread 620 pts > cap 500_, _2 positions open (max 2)_, _loss cooldown_ or _account too small_. Entries are decided once per new bar.
- **Discord Integration**: Sends alerts to Discord via Webhook for:
  - Trade Open/Close
  - Equity Milestones
  - News Events
  - Trading Pauses/Resumes

## Strategy Logic

The EA scores both sides from **0.0 to 10.0** and opens a trade when a side's score reaches `MinBuySignalScore` / `MinSellSignalScore` (default **5.0**), only in the direction the D1 trend filter allows.

### Trend Score

Four readings of the closed bars, each from -1 (strong down) to +1 (strong up), averaged into `s`:

| Part | Measures | Input (default) |
|---|---|---|
| Range | Where the close sits in the high-low range | `TrendRangeBars` (200) |
| EMA | Distance from the EMA, in ATRs (`TrendATRPeriod`, 14) | `TrendEMAPeriod` (200) |
| Efficiency | Net move / total path: a clean trend vs. a whipsaw | `TrendERBars` (100) |
| Momentum | Net move over the lookback, in ATRs | `TrendROCBars` (192) |

- **Buy score = 5 + 5s, sell score = 5 - 5s**, so the two always add up to 10: 5 means no trend, 7.5 a clear uptrend for buys (2.5 for sells).
- A small price change moves the score a little, never in fixed jumps, and nothing adds points for volatility alone.
- With the default minimum of 5.0 the EA buys while the multi-hour trend leans up and the D1 filter allows buys, and the mirror for sells. On M5 the lookbacks cover about 8 to 17 hours; scale them for other timeframes.
- On XAUUSDm M5 (2022-2026) the buy score's median was 4.7-5.9 per year, following gold's direction, and the score spread fairly evenly from 1 to 9: it spends little time near 5.
- The checkpoint hold (`CheckpointHoldMode = Score`) keeps a trade while its side still scores higher, i.e. while the multi-hour trend agrees.
- The dashboard shows the four parts as `Rng`, `EMA`, `Eff` and `Mom`.

> **Why a multi-hour score:** up to v53.0 the EA also offered an older short-term score (EMA 5/12, RSI 8, candle body and wicks, breakouts, volatility points). On XAUUSDm M5 history it barely separated winning entries from losing ones, and it jumped 1 to 3 points on tiny price changes; multi-hour trend readings carried the most information. v54.0 removed it with its inputs. It is still a modest edge: the score measures trend strength, it is not a probability.

### Score Smoothing & Filters

- **Dead-Market Block**: if the last closed candle's `ATR/AvgATR < MinVolRatioToTrade`, entries are blocked (off by default).
- **Velocity Tracking** _(informational)_: tracks the _change_ in signal score between bars and shows it on the dashboard (`Vel`). It does not drive trailing or lot sizing.
- **Signal Smoothing (Blended Weighted Average)**:
  - Combines weighted average of recent closed candles with a dampened current candle contribution.
  - **SignalSmoothingCandles**: Number of closed candles to average (1-10, default 2).
  - **CurrentCandleBlend**: Weight factor for the forming candle (0.0-1.0, where 0.0 = closed candles only, 1.0 = current candle only). It applies to the live dashboard score and to the loss-management and trailing features that compare the score with the entry score. Entries (with `EnableNewBarEntryOnly`, default), the checkpoint hold and the trend-flip exit use **closed candles only**.
  - Results in smooth yet responsive signal scoring that adapts to market conditions.

**Entry Condition**: the side's score >= `MinBuySignalScore` / `MinSellSignalScore` (plus the HTF trend filter and the entry guards)

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
- **`LimitEntryExpiryBars`**: Cancels an unfilled limit after N bars (managed internally, broker-agnostic). When the symbol supports it, the order also gets a broker-side expiry one bar later as a backstop in case the EA isn't running.
- **`LimitEntryCancelOnFlip`**: Cancels the pending if the directional signal drops back below its threshold before filling.
- **Safety**: All pending limits are cancelled whenever new entries are blocked (news, pause, trading hours, market close, leverage change), when an equity stop fires, and when the EA is removed — a resting limit can never fill into a window the EA meant to avoid, or fill unmanaged.
- **Scope**: This affects **fresh entries only**. Virtual-SL re-entries always execute at market — their purpose is to restore exposure immediately, so they must not risk going unfilled.

> **Trade-off:** A pullback limit improves average fill price but **lowers fill rate** — strong momentum/breakout moves (which this EA's scoring favors) often run without retracing, so the best moves may be missed while weaker, stalling signals fill preferentially. Backtest both modes before committing; it is off by default for this reason.

### Checkpoint Exit (On in the Default Profile)

With `EnableCheckpointExit` the take-profit is **not sent to the broker** — it becomes a **checkpoint**. When price reaches it, the EA re-checks the trade instead of closing it:

- **Still valid → keep it.** The SL is moved to lock `CheckpointLockPct`% of the move (default 50%), and the next checkpoint is set one TP-distance further. This repeats as long as the trade keeps qualifying, so winners can run with the trend while profit is progressively locked.
- **No longer valid → close** at the checkpoint.
- **What "valid" means** (`CheckpointHoldMode`): the higher-timeframe trend still agrees (uses the `EnableHTFTrendFilter` settings — turn it on), the signal score still points the same way, or both.
- **Trailing stop** (`CheckpointTrailPct`, `CheckpointTrailStartPct`; 0 = off): both are a **% of the checkpoint distance** (the TP distance), so they follow it automatically if you change it. Once the trade is `CheckpointTrailStartPct`% of that distance in profit, the SL follows the price `CheckpointTrailPct`% of it behind and never moves back. With a start of 0, trailing begins after the first held checkpoint. The checkpoint lock still applies, and whichever stop is tighter wins. The default profile uses 100% / 50%: with its $20 checkpoint, the SL trails $20 behind the price from +$10.
- **Break-even lock** (`CheckpointBreakEvenPct`, default 75 = +$15 of the $20 checkpoint; 0 = off): once the trade is this % of the checkpoint distance in profit, the SL moves to the **smallest possible profit**: one tick beyond the entry plus commission and any negative swap. On a fast market the stop can still fill a little below that level. Tested on Jan-Sep 2026 real ticks (M5, monthly runs): the +$15 lock raised the default from +83.3% to +93.8% with a slightly smaller drawdown (19.2% vs 20.0%); a +$5 lock cut the profit by more than half, because most trades were closed at about $0 before they could run.
- **All checkpoint settings at a glance:**
  - distance: `TPInputType` / `TPValue`
  - what keeps a trade: `CheckpointHoldMode`
  - profit locked per checkpoint: `CheckpointLockPct`
  - trailing distance and start: `CheckpointTrailPct` / `CheckpointTrailStartPct`
  - loss-side skips: `CheckpointMaxSkips`
  - early exit when the trend turns: `TrendFlipExitScore`
  - smallest-profit lock: `CheckpointBreakEvenPct`
- **Loss side** (`CheckpointMaxSkips`, default 0 = off): when the SL is touched while the signal score still agrees, the stop may be pushed one SL-distance further, at most this many times. The broker always holds a **hard stop at the maximum distance** (`(1 + skips) × SL`), so the worst case is fixed even if the EA or terminal is offline; the inner stops are managed by the EA. Risk sizing uses the full worst-case distance.
- **Trend-flip exit** (`TrendFlipExitScore`, default 6.0, 0 = off): a losing trade is closed as soon as the **opposite** side's closed-candle score reaches this value, i.e. the trend it was opened with has turned against it, instead of waiting for the full SL. With the Trend score, 6.0 to 7.0 means the multi-hour trend has clearly reversed. It cut the average loss in backtests without hurting results. Hedge chain legs are left to the chain logic.

### Risk:Reward TP/SL (Optional)

By default the EA places SL and TP from the manual **Trailing TP/SL** inputs (`SLValue` / `TPValue`). Enabling **Independent Risk:Reward** instead derives *both* stops from a single risk leg and a target ratio — so every trade carries the same R:R geometry regardless of the manual TP/SL tuning.

- **`EnableRiskReward`** _(default off)_: When on, the R:R engine **overrides** the manual Stop Loss *and* Take Profit entirely — `EnableStopLoss` / `SLValue` and `EnableTakeProfit` / `TPValue` are ignored for fresh entries.
- **`RRRiskMode`**: How the **risk (SL) leg** is sized —
  - **Auto (ATR-Based)** _(default)_: `SL distance = ATR × RRAtrMultiplier`, computed per entry from the last closed bar's ATR — the stop scales with current volatility.
  - **Manual Distance**: a fixed SL distance from `RRRiskValue`, in the units set by `RRRiskInputType`.
- **`RRRiskInputType`**: Units for the manual risk distance (Dollar Amount / Percent of Equity / Points) — used only when `RRRiskMode = Manual`.
- **`RRRiskValue`** _(default 200)_: Manual SL distance for the risk leg (used only when `RRRiskMode = Manual`).
- **`RRAtrMultiplier`** _(default 1.5)_: ATR multiple for the SL leg (used only when `RRRiskMode = ATR`).
- **`RiskRewardRatio`** _(default 1.5)_: Reward-to-risk ratio — `TP distance = SL distance × RiskRewardRatio`. The default targets 1.5× the risked distance in profit (a 1:1.5 R:R).

Once set at entry, the **TP is fixed at the R:R level** — the adaptive trailing system will *not* recompute or overwrite it, so the intended reward target is preserved for the life of the trade. Trailing and break-even still manage the **SL** as normal. Applies to both market and pullback-limit entries.

> **Scope:** This is a per-entry geometry override, independent of the per-trade and basket equity stops, which still apply. Leave it off to keep the manual/adaptive TP/SL behavior.

## Settings Profile

Three profiles are bundled: `settings/xauusd-default.set`, `settings/xauusd-high-risk.set` (see [High-Risk Profile](#high-risk-profile)) and `settings/usdjpy-default.set`, which runs next to gold on the same account (see [Gold + USDJPY](#gold--usdjpy-on-one-account)). `xauusd-default.set` holds the same values as the EA's built-in input defaults, except `DrawdownScope`: the file uses This EA's Own Trades (see [Using the Profiles Together](#using-the-profiles-together)), which gives the same results when the EA trades the account alone. To load it, attach the EA to a chart, open the **Inputs** tab, click **Load** and pick the file (in the Strategy Tester: right-click the inputs list → **Load**). The file lists every input, so loading it fully defines the EA's behavior.

Profiles are named after their symbol (`xauusd-…`, `usdjpy-…`), and reports after the profile and the tick data they were tested on (`reports/xauusd-default-2026-real-ticks`, `reports/usdjpy-default-2025-generated-ticks`, …). `settings/xauusd-straddle.set` belongs to the separate [Nyao Straddle](#nyao-straddle-companion-ea) EA.

| default | |
|---|---|
| Symbol / timeframe | Gold (written for XAUUSDm, 3-digit quotes; 2-digit brokers are rescaled automatically) on **M5** |
| Entries | Trend score ≥ 5 (the multi-hour trend agrees), only in the D1 trend direction (close at least 0.5% beyond a rising / falling EMA50) |
| Stop | Fixed $20 move (20000 points on 3-digit quotes) |
| Lot size | Largest lot that loses at most 1.25% at the stop (`RiskPerTradePct`), capped at 0.05: 0.01 lot on $2,000, 0.05 lot on a $100 cent account |
| Exit | Checkpoint every $20: held while the score agrees (locking 50%), otherwise closed; $20 trailing stop from +$10; break-even lock at +$15, so a trade that got that far can't end as a loss; a losing trade is closed early once the trend flips against it (opposite score ≥ 6) |
| Loss-streak pause | After 4 losses in a row, paper-trades until a paper win |
| Hedge chain | Off |
| Account | **Standard account: the reports use $2,000** (0.01 lot risks $20, about 1%). Below about $1,600 the 0.01 minimum lot risks more than 1.25%: the EA still trades it down to about $400 (up to 5% per trade, `MaxRiskPerTradePct`, shown in orange on the dashboard) and opens nothing below that. **Cent account: $100 or more** (10,000 cents, 0.05 lot, the same ~1%). See [Account Size, Risk & Account Type](#account-size-risk--account-type) |

### High-Risk Profile

`settings/xauusd-high-risk.set` uses the default rules with twice the risk per trade. Only two inputs differ: `RiskPerTradePct` 2.5 (0.02 lot on $2,000, dropping to 0.01 lot below about $1,600; below about $800 that 0.01 lot risks more than 2.5% and is traded down to about $400, the same 5% cap as the default) and `MaxLotSize` 0.10 (so a $100 cent account can trade 0.10 lot). It was tested on **M5**.

Jan-Sep 2026, real ticks, v54.0 (with the +$15 break-even lock), M5, $2,000 per month: `xauusd-default.set` **+93.8%** (worst month -2.7%, max DD 19.2%), `xauusd-high-risk.set` **+187.6%** (worst month -14.4%, max DD 35.5%).

Every month since 2022 under v54.0 (2022-2025 ticks generated from 1-minute bars, 2026 real ticks), from the [reports in this repository](#automated-backtests-toolsbacktest):

| M5, $2,000 per month | 2022 | 2023 | 2024 | 2025 | Jan-Sep 2026 | 57 months | Months up | Worst month | Max DD |
|---|---|---|---|---|---|---|---|---|---|
| `xauusd-default.set` (1.25%) | -5.3% | -9.0% | +0.9% | +65.3% | +93.8% | +145.8% | 27/57 | -6.5% | 19.2% |
| `xauusd-high-risk.set` (2.5%) | -17.5% | -4.3% | -9.0% | +95.4% | +187.6% | **+252.2%** | 27/57 | **-15.7%** | **35.5%** |

Monthly reports with every run's balance & equity graph, M1 and M5, real ticks Jan-Sep 2026 (v54.0): [`reports/xauusd-default-2026-real-ticks`](reports/xauusd-default-2026-real-ticks/summary.md) (M5 +93.8%, M1 +24.1%) and [`reports/xauusd-high-risk-2026-real-ticks`](reports/xauusd-high-risk-2026-real-ticks/summary.md) (M5 +187.6%, M1 +20.9%). For 2025, M5 with ticks generated from 1-minute bars (v54.0): [`reports/xauusd-default-2025-generated-ticks`](reports/xauusd-default-2025-generated-ticks/summary.md) (+65.3%, 10/12 months up) and [`reports/xauusd-high-risk-2025-generated-ticks`](reports/xauusd-high-risk-2025-generated-ticks/summary.md) (+95.4%, 10/12 months up).

Doubling the risk doubles the size of the edge, not the edge itself: the return per unit of drawdown stays the same, and the profile still loses when gold moves sideways. Higher risk (3.75% and 5%) returned more but with 52-64% drawdowns. A frequent-trading M1 variant (entries during the bar, up to 4 positions $1.50 apart, a faster trend score) was tested and rejected: at 2.5% risk it lost up to 60% in a single month.

### Gold + USDJPY on One Account

The default rules also trend-follow USDJPY, and USDJPY tends to trend when gold moves sideways (their prices move opposite: monthly correlation -0.36 since 2022). `settings/usdjpy-default.set` is the default profile with every distance scaled by USDJPY's daily volatility, nothing tuned: a 786-point (0.786 yen) stop and checkpoint, entries at least 590 points apart (`ZonePoints` 393), a 0.309% D1 trend distance, a 2-pip spread cap, `PointInputDigits` 0, `MaxLotSize` 0.20 (about $100 at the stop, like gold's 0.05 lot) and gold's smallest-profit lock at 75% of the checkpoint (`CheckpointBreakEvenPct` 75).

| M5, $2,000 per month, 1.25% risk each | 2022 | 2023 | 2024 | 2025 | Jan-Sep 2026 | 57 months | Months up | Worst month | Drawdown across months |
|---|---|---|---|---|---|---|---|---|---|
| Gold (`xauusd-default.set`) | -5.3% | -9.0% | +0.9% | +65.3% | +93.8% | +145.8% | 27/57 | -6.5% | 24.0% |
| USDJPY (`usdjpy-default.set`) | +55.8% | +1.3% | +38.9% | -6.8% | -5.2% | +84.0% | 25/57 | -6.9% | 18.8% |
| **Both on one account** | +50.5% | -7.7% | +39.8% | +58.5% | +88.6% | **+229.8%** | 33/57 | -6.9% | **26.7%** |

"Both" is the sum of the two monthly runs (the tester runs one EA at a time), measured with v54.0; 2022-2025 use ticks generated from 1-minute bars, 2026 real ticks. The smallest-profit lock helped USDJPY the way it helped gold: without it, USDJPY made +81.5% with a 23.2% drawdown across months, and both together +227.4% (27.3%). To run it:

One **hedging** account, two M5 charts: XAUUSD with `xauusd-default.set`, USDJPY with `usdjpy-default.set`. Both profiles already carry their own magic number and `DrawdownScope` = This EA's Own Trades; see [Using the Profiles Together](#using-the-profiles-together). Up to 4 positions and about 5% of equity can be at risk at the same time.

USDJPY reports (M5, v54.0): [`reports/usdjpy-default-2026-real-ticks`](reports/usdjpy-default-2026-real-ticks/summary.md) (-5.2%, 2/9 months up) and [`reports/usdjpy-default-2025-generated-ticks`](reports/usdjpy-default-2025-generated-ticks/summary.md) (-6.8%, 5/12 months up). The [Nyao Straddle](#nyao-straddle-companion-ea) can be added as a third chart.

Alone, USDJPY was a weak earner (it lost in 2025 and 2026); it was tested as a partner for gold. Using the opposite movement as a filter instead (gold buys only while USDJPY falls, and back) was tested and rejected: it cut gold to +86-112% and USDJPY to +12-14%, because the two also trend together at times (2024). The same scaled test (57 months) found no other partner: EURUSD -49%, AUDUSD -145%, silver -185%, platinum -518% and GBPUSD +11% (added nothing); US stock indices US500 -70%, USTEC -35%, US30 -46%; crypto BTCUSD -18% and ETHUSD -1% (both raised the combined drawdown), XRPUSD and LTCUSD far worse (their spread is 35-62% of the scaled stop). The edge of these rules is gold's, with USDJPY as the one partner that balances it.

> **Brokers with other quote decimals**: point values are written for a 3-digit gold quote (0.001), and `PointInputDigits` (default 3) rescales them to the symbol's own decimals so every distance keeps the same price meaning. Where gold is quoted with 2 decimals, 20000 points become 2000, still a $20 move, instead of a $200 stop with 10× the risk. This covers `SLValue`, `TPValue`, `TrailingDistanceValue` and `RRRiskValue` when their type is Points, plus `ZonePoints` and `MaxSpreadPoints`. The EA prints a `[POINTS]` line at start-up when it rescales. Set `PointInputDigits = 0` to use point values exactly as typed (for example on forex, where your own values are written for that symbol).

### Account Size, Risk & Account Type

The EA sizes every trade from equity: it uses the largest lot whose stop-out loses at most `RiskPerTradePct` of equity, capped at `MaxLotSize`. When even the broker's minimum lot (0.01) is over that budget, it still trades the minimum lot as long as its stop-out loses no more than `MaxRiskPerTradePct` (5%), and opens nothing above that. With gold's $20 stop, 0.01 lot loses $20. Both profiles need a **hedging** account; leverage changes only the margin a trade needs, not what it risks.

**Standard account** (balance in dollars):

| Equity | `xauusd-default.set` (1.25% per trade) | `xauusd-high-risk.set` (2.5% per trade) |
|---|---|---|
| under $400 | no trades (0.01 lot would lose more than 5%) | no trades |
| $400 | 0.01 lot, 5% per trade | 0.01 lot, 5% |
| $800 | 0.01 lot, 2.5% | 0.01 lot, 2.5% |
| $1,600 | 0.01 lot, 1.25% | 0.02 lot, 2.5% |
| **$2,000** (as in the reports) | **0.01 lot, 1.0%** | **0.02 lot, 2.0%** |
| $4,000 | 0.02 lot, 1.0% | 0.05 lot, 2.5% |
| $8,000 | 0.05 lot (the cap), 1.25% | 0.10 lot (the cap), 2.5% |
| $16,000 | 0.05 lot, 0.6% | 0.10 lot, 1.25% |

- **It trades from $400; the reports use $2,000.** Below $1,600 the default trades the 0.01 minimum lot above its 1.25% budget (up to 5%); the dashboard shows this as an orange **Lot** line and the Experts tab gets a `[RISK SIZING]` note.
- **Above $8,000** the lot cap (0.05 for the default, 0.10 for high-risk) holds each trade below the set percentage. Raise `MaxLotSize` if you want the risk to keep scaling with the account.

**Cent account** (balance in US cents, e.g. 10,000 = $100):

- The EA reads every amount in the account currency, so a cent account is sized like a standard account with 100× the number: on a **$100 cent account** the default trades **0.05 lot (about 1% per trade)** and `xauusd-high-risk.set` 0.10 lot (about 2%). Above about $80 the 0.05 cap keeps the default below 1.25%.
- This assumes the cent gold symbol has the standard lot size with profit counted in cents (the usual setup). The EA calculates from the symbol's own values either way, so check the dashboard's **Lot** line: it shows the lot and the % it risks. A cent symbol has not been backtested.
- Money inputs are also read in cents: `MinimumEquity` 20 means 20 cents, so set it to 2000 for a $20 floor. Cent gold spreads can be wider: above 500 points ($0.50) the spread filter blocks entries.

**Gold + USDJPY:** USDJPY's 0.786-yen stop costs about $5 per 0.01 lot (it moves with the yen rate), so on $2,000 the USDJPY chart trades about 0.04 lot (about 1%) and is blocked only below about $100. The pair needs gold's minimums above; with both charts running (up to 2 positions each), about 4-5% of equity can be at risk at once.

### Using the Profiles Together

Every profile in `settings/` can share one **hedging** account with any of the others, each on its own chart:

| Profile | EA | Chart | `MagicNumber` |
|---|---|---|---|
| `xauusd-default.set` | Nyao Scalper | XAUUSD M5 | 6926268 |
| `xauusd-high-risk.set` | Nyao Scalper | XAUUSD M5 | 6926269 |
| `usdjpy-default.set` | Nyao Scalper | USDJPY M5 | 6926270 |
| `xauusd-straddle.set` | Nyao Straddle | XAUUSD M1 | 25102501 |

- **Separate trades.** Each chart manages only the positions and orders with its own magic number on its own symbol, so two profiles on gold never touch each other's trades. Nyao Scalper's saved state (`EnablePersistState`) is also kept per symbol and magic number.
- **Separate drawdown.** The Nyao Scalper profiles use `DrawdownScope` = This EA's Own Trades: another chart's losses don't raise this chart's entry score. When one EA trades the account alone, this gives the same results as measuring the whole account.
- **Shared account checks.** The per-trade, basket and total-loss stops count only the chart's own trades. The account-wide checks (`MinEquityPercent` drawdown pause, `MinimumEquity`, `TargetEquity`, leverage pause) watch the whole account, and each EA then closes only its own positions.
- **The risk adds up.** Every chart sizes its lots from the whole account's equity. Gold + USDJPY can hold up to 4 positions with about 5% of equity at risk at once; the straddle adds one more position, about $1 at 0.01 lot.
- **What was tested together** (sums of separate monthly tester runs, since the tester runs one EA at a time): gold + USDJPY over 57 months ([above](#gold--usdjpy-on-one-account)) and gold + the straddle in 2026 ([below](#next-to-nyao-scalper)). `xauusd-default` and `xauusd-high-risk` on the same account take the same trades twice, which amounts to a higher risk setting, not a second strategy.
- **Load the files.** The magic numbers and the drawdown setting come from the profile files. An EA attached without loading a profile uses its built-in magic number (6926268 for Nyao Scalper) and measures drawdown on the whole account.

## Nyao Straddle (Companion EA)

[`nyao_straddle.mq5`](nyao_straddle.mq5) is a second, separate EA for **gold on M1**, built on a different idea from Nyao Scalper. Nyao Scalper trades with the daily trend and makes its money in steady trends. Nyao Straddle stays out of the market almost all the time and trades only when gold becomes extremely volatile, the kind of market where a $1 move tends to keep going. It can run on the same account as the Nyao Scalper profiles (see [Using the Profiles Together](#using-the-profiles-together)).

> **More experimental than Nyao Scalper.** It has been backtested on one year of real ticks (2026), and most of its profit comes from a single event, the gold crash of late January 2026. Trading CFDs involves significant risk; past results are not indicative of future results.

Profile: [`settings/xauusd-straddle.set`](settings/xauusd-straddle.set) (= the EA's built-in input defaults). Report: [`reports/xauusd-straddle-2026-real-ticks`](reports/xauusd-straddle-2026-real-ticks/summary.md).

### How It Works

1. **Extreme markets only.** Gold's H1 ATR(14), measured on closed bars, must be at least **$34**. That was gold's most extreme 10% of the time in 2026. In January, March and April 2026 it held for hours or days; in May and July-October it never happened.
2. **The market must be speeding up.** The ATR of the last 7 one-minute bars must be at least **2×** its average over the last 288 bars.
3. **Straddle.** While both hold, the EA keeps a **buy stop $1 above** and a **sell stop $1 below** the price. The first one to fill cancels the other.
4. **Exit.** The position has a **$1 stop** that trails **$1 behind the price** from the moment it fills. There is no take profit: the trailing stop ends every trade.
5. **Again.** As soon as the position closes, a new pair goes out, as long as the market is still extreme. In a crash this means many trades an hour.
6. **Pause.** After **10 losing trades in a row** it places nothing for **30 minutes**.
7. **Lot.** Fixed **0.01**: about $1 at the stop, plus slippage.

Untriggered orders are deleted when the market calms down. The chart shows the current ATR values next to the levels they need, so you can see why it is or isn't trading.

| `xauusd-straddle.set` | |
|---|---|
| Symbol / timeframe | Gold (XAUUSD) on **M1** |
| Extreme-market filter | H1 ATR(14) ≥ $34 (`RegimeMinATR`) |
| Speed-up filter | M1 ATR(7) ≥ 2× its 288-bar average (`VolATRPeriod`, `VolMinRatio`) |
| Entry | Buy stop and sell stop $1 from the price; the first fill cancels the other |
| Exit | $1 stop, trailing $1 behind the price from the fill; no take profit |
| Pause | 10 losing trades in a row → 30 minutes without new orders |
| Lot size | 0.01 (`Lots`; `RiskPercent` > 0 sizes from equity, never below `Lots`). On a **cent account** (balance in cents) 0.01 lot loses 1 cent at the stop; 0.05 lot, or `RiskPercent` 0.05, on a $100 cent account is the same ~0.05% per trade as 0.01 lot on $2,000. Cent gold spreads can be wider, and the straddle pays the spread on every trade; a cent symbol has not been backtested |
| Account | **Hedging** account (it can share gold with Nyao Scalper). At 0.01 lot a trade risks about $1 plus slippage |

### Straddle Results

Real ticks, Jan-Sep 2026, $2,000 per month (each month a fresh run), 0.01 lot, sums of monthly returns ([full report](reports/xauusd-straddle-2026-real-ticks/summary.md)):

| Month | M1 (the timeframe it was tuned on) | M5 |
|---|---|---|
| January | +120.0% | +109.7% |
| February | +75.5% | +27.7% |
| March | +33.0% | +45.5% |
| April | +10.7% | +1.5% |
| June | -0.2% | no trades |
| May, July-September | no trades | no trades |
| **Total** | **+239.0%** | **+184.5%** |
| Profit factor / max drawdown | 2.02 / 2.7% | 1.74 / 4.0% |
| Trades / win rate | 9,985 / 45% | 10,486 / 43% |
| Avg win / loss | $2.12 / -$0.85 | $1.93 / -$0.84 |

October 2026 (to the 23rd) had no trades either.

- **82% of the profit is one event:** January 29 - February 9, 2026, the crash and its aftermath. Outside it the edge is a few cents per trade (about $0.09 per 0.01-lot trade in the tests below).
- **It sits idle most of the time.** It traded in 5 of 10 months in 2026.
- **The tester fills orders instantly.** It models slippage from real ticks (fills averaged about $0.10 worse than the order price) but not execution delay. In a crash the EA can trade every few seconds; a real broker may fill later, requote, or limit that.
- **2025 can't be tested properly.** Real ticks only go back to 2026 at the test broker. With ticks generated from 1-minute bars, only October 2025 reached the $34 level (gold was cheaper then, so $34 was a bigger move): +37.6% with an 83% win rate and a profit factor of 41.8. Generated price paths are far smoother than real ones, which makes a $1 trailing stop look almost perfect, so that number is not usable ([2025 report](reports/xauusd-straddle-2025-generated-ticks/summary.md)). 2022-2024 on generated ticks: no trades: gold, at about $1,600-2,800 then, never reached a $34 hourly ATR ([report](reports/xauusd-straddle-2022-2024-generated-ticks/summary.md)).
- **The defaults were chosen on 2026 data.** There is no untouched period left to confirm them on.

### Straddle Coin Flip Test

A control test: the EA trades at exactly the same moments, with the same filters and exits, but a coin flip picks the direction (`EntryMode` input, three random seeds each). If random directions did about as well, the profit would come from the market and the exits, not from the straddle.

| Jan-Sep 2026, M1, $2,000 per month | Total | Profit factor | Max drawdown | Trades |
|---|---|---|---|---|
| **Straddle** | **+239.0%** | **2.02** | 2.7% | 9,985 |
| Coin flip, market order now (3 seeds) | +16.9% / +33.3% / +51.5% | 1.08-1.20 | 13-17% | 6,400-8,600 |
| Coin flip, one stop order $1 away (3 seeds) | +13.7% / +23.7% / +27.0% | 1.53-2.09 | 1-1.5% | about 1,030 |

The straddle beats all six. The comparison also shows where the edge is: **entering only after price has already moved $1**. A single random stop order earns about the same per trade as the straddle (it also waits for a $1 move), while random market orders barely make money and lost 13-16% in March. The straddle catches every breakout in either direction, so it gets about 10 times as many of those trades.

### Gold Only

The straddle needs price to run well past its entry *after* paying the spread. On gold in 2026 a typical minute moved about 8 times the spread ($2.17 vs $0.26); on USDJPY only 1.8 times (1.8 pips vs 1 pip).

| USDJPY, Jan-Sep 2026, M1, $2,000 per month, about $1 per stop | Total | Months up | Profit factor |
|---|---|---|---|
| $1 scaled by 1-minute volatility (0.83-pip stop, inside the 1-pip spread) | -165.2% | 0/10 | 0.06 |
| $1 scaled by daily volatility, like `usdjpy-default.set` (3.9-pip stop) | -16.3% | 0/10 | 0.68 |

Both used USDJPY's own most extreme 10% (H1 ATR ≥ 0.303 yen) as the extreme-market level. Nyao Scalper works on USDJPY because its distances are wide (78.6 pips); a $1-style straddle needs gold's large moves next to its cost.

### Next to Nyao Scalper

The two earn at different times: Nyao Scalper in steady trends (January, March, June 2026), the straddle in the crash (late January - early February).

| Jan-Sep 2026, $2,000 per month | Nyao Scalper (M5, `xauusd-default.set`) | Straddle (M1, `xauusd-straddle.set`) | Both on one account |
|---|---|---|---|
| Total | +93.8% | +239.0% | **+332.8%** |
| Months up | 5/9 | 4/9 | 6/9 |
| Worst point within a month | -14.7% (March) | -0.8% | -14.8% (March) |

"Both" adds up the two monthly test runs (the tester runs one EA at a time). The straddle added its profit without deepening Nyao Scalper's worst dip. The earlier 1.5× version of the straddle did deepen it: it lost in early March at the same time as Nyao Scalper (worst point -$610 together vs -$293 alone), which the 2× filter avoided. October 2026 (Nyao Scalper -6.5%, straddle no trades) is not in the table. How to run them together: [Using the Profiles Together](#using-the-profiles-together).

### What a Demo Test Should Check

- **Fills during fast markets.** Compare the fills with the order prices. Fills much worse than about $0.10, especially in fast moves, shrink the straddle's edge (about $0.48 per 0.01-lot trade in 2026) quickly.
- **Broker limits.** In a crash it opens a new trade every few seconds to minutes.
- **Spread.** The test broker's gold spread was $0.16 in January 2026 and $0.24-0.36 later. The straddle pays it on every trade.
- **Latency.** The straddle reacts to every tick, so the delay between the terminal and the broker matters more for it than for Nyao Scalper.
- **Idle time.** Weeks without a trade are normal. The chart status shows the H1 ATR next to the $34 it needs.
- **Gold's price level.** $34 and $1 are dollar distances set at a gold price of about $4,500. If gold moves far from that, the same distances describe a different market.

### How the Straddle's Defaults Were Found

Each change below was tested in the Strategy Tester on 2026 real ticks and kept only when it held up (usually with a pass rule written down before the run). The numbers come from the version current at the time, so rows aren't always comparable with each other.

**The idea and the first versions**

| Version / test | Result |
|---|---|
| v1.0: straddle whenever the M1 or M5 ATR was 1.5× its recent average, stops in ATR multiples, 0.50 lot | M5: 8 of 9 months lost the whole $2,000 (only April +$4,691). M1 with a 0.5-ATR stop: profit factor 0.83-0.95 |
| Fixed $1 / $2 / $3 stops instead of ATR (M1, 0.50 lot) | Still 8 of 9 months drained. February made +$123k / +$71k / +$35k, all of it in the week after the crash |
| Why February? Hourly profit vs the H1 ATR at that hour | Below $30 every level lost (-$40k); from $30 up it won (+$156k). The crash also had the year's lowest spread ($0.16) |
| What separated winning hours from losing ones (H1 ATR ≥ $30)? | Crash hours won 79% of the time, other periods 12-37%: the crash had bigger moves next to the $1 distances and the year's lowest spread. One-way vs back-and-forth movement made no difference (directional efficiency 0.103 vs 0.101), and more ticks or bigger bars helped in the crash but hurt from April on |
| v1.1: H1 ATR ≥ $30 filter | Profitable in the crash; outside it about 3 cents per trade, with a March drawdown that a $2,000 account at 0.50 lot couldn't survive |

**Filters**

| Test | Result | Decision |
|---|---|---|
| Which volatility window? M1, M15, H1, D1 ATR, each allowed its most extreme 5/10/20% of 2026 | Minute windows lost outside the crash; D1 was too slow (caught a third of the crash); hour-scale windows worked. **H1 ATR(14), top 10% (≥ $33.77)** was the only one positive in all three non-crash periods | **H1 ATR(14) ≥ $34** |
| $34 vs $30 (0.05 lot, one account) | $53,069 vs $50,896, profit factor 1.63 vs 1.47, drawdown 3.6% vs 7.0%; outside the crash +$1,216 vs +$699 per 0.01 lot | $34 |
| Speed-up level 1× / 1.5× / 2× | +674.9% / +400.1% / +207.2%, drawdown 20.2% / 7.3% / 1.9%. 1×'s extra profit all came from the crash | **2×** |
| ATR period of the speed-up filter: 5 / 7 / 14 / 21 / 30 / 60 minutes (at 1.5×) | +417% / +414% / +400% / +365% / +349% / +296%: shorter is slightly better; drawdowns jumped around (one March path decides them) | **7** |
| 7 minutes at 2× | +239.0%, profit factor 2.02, drawdown 2.7%, no month below -0.8% | **default (v1.5)** |
| London + New York hours only | $7,972 vs $12,214 for all hours (0.01 lot, one account); Asia hours carried much of the crash, and the quiet hours after New York were profitable | rejected (`EnableSessions`, off) |
| Spread cap | Within each period, low-spread trades did not do consistently better (spreads widen exactly when the market spikes) | rejected |

**Stops, trailing and locks** (0.01 lot, one account from $2,000, Jan-Oct 2026)

| Test | Net | Profit factor | Drawdown | Decision |
|---|---|---|---|---|
| **$1 stop, $1 trail from the fill** | **+$10,214** | **1.63** | **-3.1%** | **kept** |
| $1 + lock at entry +$0.20 once +$0.50 | +$10,332 | 1.66 | -4.5% | rejected: the gain was all crash, worse elsewhere |
| $2 stop and trail | +$7,101 | 1.49 | -2.4% | rejected |
| $2 + lock once +$1 | +$7,425 | 1.54 | -2.8% | rejected |
| $5 stop + lock once +$0.50 (trail from +$1.20) | +$6,878 | 1.52 | -2.9% | rejected (82% winners, but about 2,500 full -$5.30 stops) |
| $5 stop + lock once +$1.00 / no lock | +$6,267 / +$5,818 | 1.45 / 1.40 | -4.1% | rejected |

In fast markets a tight stop that is hit often but costs little beat a wide one. The break-even lock inputs (`BreakEvenTrigger`, `BreakEvenLock`) stay in the EA, off.

**Trade frequency and risk**

| Test | Result | Decision |
|---|---|---|
| One trade per candle | Same edge per trade (about $0.31), 93% fewer trades, profit /14 | removed |
| **Pause after 10 losses in a row for 30 minutes** (also 10/120, 15/30) | Net -22%, drawdown halved (-$171 vs -$344), profit factor 1.63 → 1.81. All three settings beat no pause | **adopted (v1.4)** |
| Daily loss limit (stop for the day after -$5 to -$40) | No change to the worst drawdown (it builds over several days) | rejected |
| Lot size on a fresh $2,000 month | 0.50 lot: most months lost the account. 0.05: March fell to $405 (-80%) before recovering. 0.01: worst month -16% before the pause, -0.8% with it | **0.01** default |

**Research options left in the EA (off by default):** `EntryMode` (coin flip control tests: a market order or one stop order in a random direction, `CoinFlipSeed`), `EnableSessions` (Asia / London / New York hours in UTC, `SessionUTCOffset` for the server clock), `BreakEvenTrigger` / `BreakEvenLock`, `DistanceUnit` = ATR multiples, `VolMinATR`, `PendingExpiryBars`, `TakeProfit` and `RiskPercent`.

### Straddle Inputs

| Group | Input | Default | Meaning |
|---|---|---|---|
| Volatility Filter | `VolTimeframe` / `VolATRPeriod` / `VolBaseBars` | chart (M1) / 7 / 288 | Current ATR and its normal level (average over the last N bars) |
| | `VolMinRatio` | 2.0 | Trade only when the current ATR is at least this many times the normal level (0 = always) |
| | `VolMinATR` | 0 | Also require this ATR as a price distance (0 = off) |
| | `CancelWhenCalm` | true | Delete untriggered orders when the market calms down |
| Extreme Market Filter | `RegimeTimeframe` / `RegimeATRPeriod` / `RegimeMinATR` | H1 / 14 / 34 | Trade only while this ATR is at least $34 (0 = off) |
| Trading Sessions | `EnableSessions` and the session hours | off | Asia 0-9, London 7-16, New York 12-21 (UTC) |
| Orders | `Lots` / `RiskPercent` | 0.01 / 0 | Lot size; `RiskPercent` > 0 sizes from equity at the stop, never below `Lots` |
| | `DistanceUnit` | Price | Distances below in price ($ for gold) or ATR multiples |
| | `EntryDistance` / `StopLoss` / `TakeProfit` | 1.0 / 1.0 / 0 | Pending order distance, initial stop, take profit (0 = none) |
| | `MaxSpread` / `PendingExpiryBars` | 0 / 0 | Spread cap; re-place an untriggered pair after N bars (0 = off) |
| Trailing Stop | `TrailStart` / `TrailDistance` / `TrailStep` | 0 / 1.0 / 0.1 | Start trailing at this profit (0 = from the fill), distance, minimum move |
| | `BreakEvenTrigger` / `BreakEvenLock` | 0 / 0.2 | Lock the stop at entry + `BreakEvenLock` once profit reaches the trigger (0 = off) |
| Losing Streak Pause | `LossStreakPause` / `LossStreakPauseMinutes` | 10 / 30 | Pause after this many losing trades in a row (0 = off) |
| Other | `EntryMode` / `CoinFlipSeed` | Straddle / 1 | Research control test |
| | `MagicNumber` | 25102501 | Different from every Nyao Scalper profile |
| | `TesterEquityLog` | true | Strategy Tester only: balance & equity log for the report graphs |

The [backtest tool](#automated-backtests-toolsbacktest) runs it with `--ea nyao_straddle.mq5`. Use real ticks only: with ticks generated from 1-minute bars the $1 trailing stop looks far better than it is.

## Installation

1.  **Copy File**:
    Place `nyao_scalper.mq5` into your MetaTrader 5 `Experts` folder.
    - File -> Open Data Folder -> MQL5 -> Experts

2.  **Dependencies**:
    Ensure the `Controls` and `Generic` standard libraries are available (standard in MT5). No DLLs are used.

3.  **Allow WebRequest** (For Discord Alerts):
    - Go to `Tools` -> `Options` -> `Expert Advisors`.
    - Check "Allow WebRequest for listed URL".
    - Add your Discord Webhook URL (if using alerts).

4.  **Compile**:
    Open the file in MetaEditor and press `F7` or click "Compile".
    - **Nyao Straddle** (optional): copy `nyao_straddle.mq5` to the same `Experts` folder and compile it the same way, then attach it to an XAUUSD **M1** chart. It needs no extra libraries.

5.  **Run**:
    Drag the EA onto an **M5** chart. Its built-in defaults are the `xauusd-default.set` profile.
    - The built-in defaults (= `xauusd-default.set`) are made for **XAUUSDm on M5** with 3-digit quotes and a **$2,000+ standard** or **$100+ cent** account (see the Account row above).
    - 2-digit gold quotes are rescaled automatically (`PointInputDigits`); for other symbols set your own distances (see [Settings Profile](#settings-profile)).
    - Requires a **hedging** account (the EA refuses to start on netting accounts).
    - When an equity stop fires (Min Equity, Target Equity or Max Times Trigger), the EA closes all its positions and pending orders and then **removes itself from the chart**. Other EAs in the terminal keep running.

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

The EA uses no DLLs, so it runs on local agents and on the MQL5 Cloud Network. State persistence is disabled in the tester (every test starts clean).

Results in the Strategy Tester only mean something if the test mirrors live conditions. For this EA specifically:

1.  **Use "Every tick based on real ticks"** (Strategy Tester → Modeling). Entries are decided on bar close, but almost everything after the entry — trailing, health exit, partial close, SL tightening, hedge chain start/roll and virtual-SL re-entries — is evaluated **every tick**. `1 minute OHLC` can be used for a fast first sweep, but only real-tick results mean anything for this EA (especially with the hedge chain on). Set `ReentryRespectsNewBarGate = true` if you want re-entries to also wait for bar close.
2.  **Include realistic costs.** Set your broker's **commission** in the tester and test on a **realistic spread** (ideally the symbol's actual spread, not 0). On M1 XAUUSD, spread + commission is the dominant cost — a backtest without them is meaningless.
3.  **Know what the tester can't see.** `CalendarValueHistory` (the high-impact **news filter**) generally returns nothing inside the Strategy Tester, so backtests run **without** news protection that live trading has. Treat tester drawdowns around news as optimistic.
4.  **Validate out-of-sample.** With this many tunable inputs, in-sample optimization overfits easily. Tune on one period, then confirm on a separate untouched period (or use walk-forward) before trusting a profile.
5.  **Sanity-check guards** via the journal (`EnableLogging = true`): confirm entries fire only on bar close, that trades are skipped when spread is wide or ATR has collapsed, that no entries or hedge starts happen in the `MinutesBeforeClose` window, and that the **Basket Stop** / **Total Loss Hard Stop** close positions once floating loss crosses their limits.
6.  **Judge expectancy, not win rate.** Tight trailing locks in small wins while the hard stop is much wider, so a high win rate is built into the design and says little on its own. Look at average win vs. average loss, expectancy per trade and profit factor (shown on the dashboard and in reports), plus the worst drawdown.

> Capture your own report with the tool below (real ticks + your broker's costs, out-of-sample) before running the EA on a funded account.

### Coin Flip Test

Does the EA's direction choice beat chance? A research copy of v54.0 opened its trades at exactly the same moments but let a coin flip pick buy or sell (three random seeds). The trend-flip exit was off in all runs, because it would otherwise close every random trade placed against the score within a minute. Fixed 0.01 lot, one account from $2,000, M5, Jan-Oct 2026 real ticks:

| | Result | Profit factor | Max drawdown | Trades |
|---|---|---|---|---|
| **Nyao Scalper (its own direction)** | **+78.7%** | **1.18** | **13.2%** | 1,152 |
| Coin flip, seeds 1 / 2 / 3 | -30.0% / -15.2% / +14.3% | 0.95 / 0.97 / 1.02 | 42.1% / 50.0% / 39.3% | 1,451-1,532 |

The direction is the edge. With random directions wins and losses cancel out (profit factor about 1.0) and the drawdown triples. The profit comes from the trend months: per 0.01 lot, January +$928, June +$543, March +$399. The Nyao Straddle passed the same kind of test ([Straddle Coin Flip Test](#straddle-coin-flip-test)).

### Automated Backtests (`tools/backtest`)

[`tools/backtest/nyao_backtest.py`](tools/backtest/nyao_backtest.py) runs Strategy Tester passes from the command line and writes a report to `reports/<name>/`.

**Requirements:**
- Windows
- MetaTrader 5, logged in to your broker at least once; the tester uses that account and its tick history
- Python 3.8+ (standard library only)

```bash
# Default profile on M1 and M5, one real-tick run per month (each month starts from a fresh $2,000)
python tools/backtest/nyao_backtest.py run --name xauusd-default-2026-real-ticks --periods M1,M5 --from 2026-01 --to 2026-09

# USDJPY profile on M5
python tools/backtest/nyao_backtest.py run --name usdjpy-default-2026-real-ticks --set settings/usdjpy-default.set --symbol USDJPYm --periods M5 --from 2026-01 --to 2026-09

# Nyao Straddle (the --ea option picks the EA source)
python tools/backtest/nyao_backtest.py run --name xauusd-straddle-2026-real-ticks --ea nyao_straddle.mq5 --set settings/xauusd-straddle.set --periods M1,M5 --from 2026-01 --to 2026-09

# Your own settings file, one timeframe, quick 1-minute-OHLC sweep
python tools/backtest/nyao_backtest.py run --name my-settings-m5 --set settings/my-settings.set --periods M5 --from 2026-03 --to 2026-06 --model ohlc

# Rebuild reports/<name>/ from the tester reports already in the terminal folder
python tools/backtest/nyao_backtest.py report --name xauusd-default-2026-real-ticks
```

**What `run` does:**
1. Compiles the EA (`--ea`, default `nyao_scalper.mq5`) from this repo into `MQL5\Experts\NyaoBacktest\`. Your own compiled EA is not touched.
2. Installs the `.set` file as a tester profile.
3. **Closes MetaTrader 5**, the way clicking X does. It never force-closes, so save your work first. The tester can't start while the terminal is open.
4. Runs one test per timeframe × month at below-normal priority on half the CPU cores. The tester window opens on its **Graph** tab.
5. Reopens MetaTrader 5.
6. Writes the report:
   - `summary.md`: tables and the balance & equity graph of every run (renders on GitHub)
   - `index.html`: the same, for the browser
   - `results.csv`, `graphs/`, `equity/` (each run's balance, equity and lowest equity per hour) and `plan.json`

The balance & equity graphs come from the EA's **TesterEquityLog** input (on by default). In the Strategy Tester only, it saves the balance, the equity and the lowest equity of every 5-minute bar; on a live or demo chart it does nothing. Runs made with it off fall back to the tester's own balance-only graph.

| Option | Default | Meaning |
|---|---|---|
| `--name` | (required) | Report folder `reports/<name>/` |
| `--set` / `--ea` | `settings/xauusd-default.set` / `nyao_scalper.mq5` | Settings file and EA source in this repo |
| `--periods` | `M1` | Comma-separated timeframes, e.g. `M1,M5` |
| `--from` / `--to` | (required) | First and last month, `YYYY-MM` |
| `--split` | `monthly` | `monthly` (fresh deposit each month) or `whole` (one run over the range) |
| `--model` | `real` | `real` (real ticks), `every` (generated ticks), `ohlc` (1-minute OHLC), `open` |
| `--symbol` / `--deposit` / `--leverage` | `XAUUSDm` / `2000` / `500` | Test account |
| `--terminal` / `--data-dir` | auto-detected | Path to `terminal64.exe` and its data folder |
| `--cpu-mask` | every other CPU | Affinity for the tester, e.g. `0x555`; `0` = all CPUs |
| `--keep-raw` | off | Also copy the raw MT5 reports to `reports/<name>/raw/` (git-ignored, large) |
| `--no-reopen` / `--timeout-min` | off / `30` | Leave the terminal closed afterwards; abort a single run after N minutes |

The **Tick data** column in the summary shows whether each run really used real ticks ("100% real ticks"). Brokers only keep real ticks for a limited period; before that, the tester generates ticks from M1 bars.

**Reports in this repository** (`reports/<symbol>-<profile>-<period>-<tick data>`). 2022-2025 use ticks generated from 1-minute bars; 2026 real ticks:

| Report | EA / timeframes | Result (sum of monthly returns) |
|---|---|---|
| [`xauusd-default-2022-2024-generated-ticks`](reports/xauusd-default-2022-2024-generated-ticks/summary.md) | Nyao Scalper, M5 | -13.4% (2022 -5.3%, 2023 -9.0%, 2024 +0.9%) |
| [`xauusd-default-2025-generated-ticks`](reports/xauusd-default-2025-generated-ticks/summary.md) | Nyao Scalper, M5 | +65.3%, 10/12 months up |
| [`xauusd-default-2026-real-ticks`](reports/xauusd-default-2026-real-ticks/summary.md) | Nyao Scalper, M1 + M5, Jan-Sep | M5 +93.8%, M1 +24.1% |
| [`xauusd-high-risk-2022-2024-generated-ticks`](reports/xauusd-high-risk-2022-2024-generated-ticks/summary.md) | Nyao Scalper, M5 | -30.8% (2022 -17.5%, 2023 -4.3%, 2024 -9.0%) |
| [`xauusd-high-risk-2025-generated-ticks`](reports/xauusd-high-risk-2025-generated-ticks/summary.md) | Nyao Scalper, M5 | +95.4%, 10/12 months up |
| [`xauusd-high-risk-2026-real-ticks`](reports/xauusd-high-risk-2026-real-ticks/summary.md) | Nyao Scalper, M1 + M5, Jan-Sep | M5 +187.6%, M1 +20.9% |
| [`usdjpy-default-2022-2024-generated-ticks`](reports/usdjpy-default-2022-2024-generated-ticks/summary.md) | Nyao Scalper, M5 | +96.0% (2022 +55.8%, 2023 +1.3%, 2024 +38.9%) |
| [`usdjpy-default-2025-generated-ticks`](reports/usdjpy-default-2025-generated-ticks/summary.md) | Nyao Scalper, M5 | -6.8%, 5/12 months up |
| [`usdjpy-default-2026-real-ticks`](reports/usdjpy-default-2026-real-ticks/summary.md) | Nyao Scalper, M5, Jan-Sep | -5.2%, 2/9 months up |
| [`xauusd-straddle-2022-2024-generated-ticks`](reports/xauusd-straddle-2022-2024-generated-ticks/summary.md) | Nyao Straddle, M1 + M5 | no trades: gold, at about $1,600-2,800 then, never reached a $34 hourly ATR |
| [`xauusd-straddle-2025-generated-ticks`](reports/xauusd-straddle-2025-generated-ticks/summary.md) | Nyao Straddle, M1 + M5 | M1 +37.6%, M5 +42.1%: only October traded, and generated ticks overstate a $1 trailing stop (83% winners, profit factor 41.8) |
| [`xauusd-straddle-2026-real-ticks`](reports/xauusd-straddle-2026-real-ticks/summary.md) | Nyao Straddle, M1 + M5, Jan-Sep | M1 +239.0%, M5 +184.5% |

## Research Log

Nyao Scalper went through more than 50 versions. Everything below was tested on gold (XAUUSD) in the Strategy Tester; most tests compare against the default of their day, so numbers from different rows aren't always comparable. 2026 uses real ticks; 2022-2025 use ticks generated from 1-minute bars. "Per 0.01 lot" results come from one continuous run with a fixed 0.01 lot; "profit/DD" is that profit divided by the largest drawdown (the current default scores about 5.0 in 2026). AUC measures how well a signal separates winning from losing trades: 0.50 is a coin flip. Ideas that failed stayed out of the EA; they are listed here so they don't get retried blindly. Most tests had a pass rule written down before the run, usually "more profit and no deeper drawdown than the default".

### Early Versions (v3.1 - v44.0)

The EA started in a private repository on 2026-01-15; its history (v3.1 - v35.0) is merged into this repository's history, without compiled files, third-party files or private data. The public repository started at v32.0 on 2026-02-10.

| Versions | Dates | Strategy and main changes |
|---|---|---|
| v3.1 - v9.0 | Jan 15 - 20, 2026 | **EMA + Stochastic** scalping. Equity & risk management and Discord alerts (v3.5), trading hours (v5.0), RSI instead of the EMA/Stochastic signal (v8.0), news filter fixes and better management of losing positions (v9.0) |
| v10.0 - v14.0 | Jan 22 - 27 | **RSI with reversal & hedge**: hedge pairs (v10.0), managing winning positions, pyramiding and a daily report (v12.0 - v13.0) |
| v15.0 - v23.0 | Jan 28 - Feb 4 | **Candle prediction** (a signal for every candle). Fast-market and market-close filters (v16.0); hedge, reversal and pyramiding replaced by a multi-entry system with loss management (v17.0); algo-trading status and reports (v19.0) |
| v25.0 - v35.0 | Feb 5 - 21 | **Indicator-based signal strength**, the base of today's EA: position management and pyramiding reworked (v26.0), a dashboard (v27.0), the signal rewritten (v28.0 - v31.0). v32.0 became the public initial commit; v34.0 - v35.0 (private) tried the v13.0 signal method again |
| v36.0 - v41.0 | Feb 25 - Mar 12 | Loss management: partial close, SL tightening, break-even lock and re-entry (v36.0); pyramiding removed; position-aware signal dampening; lot sizing reduced to equity-drop recovery; max trades per candle (v37.0); consecutive-candle escalation and profit-offset SL tightening (v38.0); signal smoothing and health checks (v39.0); a filling-mode fix for gold (v40.0); signal scoring tuned for M1 (v41.0); license changed to BSD-3-Clause |
| v42.0 - v43.0 | May 31 - Jun 11 | Risk safety and signal quality fixes; the rolling hedge chain recovery (v42.0); independent risk:reward TP/SL (v43.0) |
| v44.0 | Oct 12 | Safety fixes, the checkpoint exit and the D1-trend default profile; from here on every change was backtested on real ticks, see below |

### How the Default Profile Was Built

| Version | Change | Evidence |
|---|---|---|
| v45.0 | "Clear trend" D1 filter: close at least 0.5% beyond the EMA50 (`HTFMinDistancePct`) | 0.3 / 0.5 / 0.8% all beat no distance in 2025 and 2026; 0.5% had the best 2025 profit factor (1.37). It helps in a few choppy months |
| v45.0 | M5 instead of M1 | Jan 2025 - Jun 2026: M5 +123.5% (worst month -7.2%, drawdown 19%) vs M1 +110.3% (worst month -17.1%, drawdown 30%); M15 +40.4% |
| v46.0 | Trend score (range position, EMA distance, efficiency, net move over several hours) replaces the old 0-10 score; minimum 5 | The old score's AUC was 0.51-0.52: a coin flip. With the trend score M5 2026 made +82.6% vs +51.4% |
| v46.0 | Trend-flip exit: close a losing trade once the opposite score reaches 6 (`TrendFlipExitScore`) | 2026 +83.3%, 2025 +66.0% (+57.4% without), worst month -3.1% / -2.2%. A score of 4 or less closed too much |
| v47.0 | `PointInputDigits`: point inputs rescaled to the symbol's decimals | On a 2-decimal gold quote the same point inputs meant a $200 stop. "Better results" there were 10× the risk in a trending month |
| v48.0 | Lot from equity: 1.25% at the $20 stop, capped at 0.05 | Trade for trade the old fixed 0.01 lot on $2,000. 1.0% was rejected: after one loss the lot rounds down to zero and the EA stops |
| v50.0 | `MaxRiskPerTradePct` 5: keep trading the 0.01 minimum lot from $400 up | v48 opened nothing below about $1,600 (a $528 demo never traded). M5 unchanged; M1 2026 +8.9% → +19.5% |
| v50.0 | High-risk profile (2.5%) | See [High-Risk Profile](#high-risk-profile) |
| v51.0 | USDJPY profile and `DrawdownScope` | See [Gold + USDJPY](#gold--usdjpy-on-one-account) |
| v52.0 | Smallest-profit lock at +$15 (`CheckpointBreakEvenPct` 75) | One account, per 0.01 lot, 2026: +$1,920 with the lowest drawdown, vs +$1,527 without. A +$5 lock made +$588 (57% of trades closed near zero); +$10 made +$2,141 with a deeper drawdown |
| v53.0 | Balance & equity log for the backtest reports (`TesterEquityLog`) | The balance-only tester graph hid floating losses (a flat balance while equity fell 93%) |
| v54.0 | Old score model and its 26 inputs removed | 18 real-tick runs traded identically, deal for deal |

### Entries

| Idea | Result |
|---|---|
| The old 0-10 score | AUC 0.51-0.52. Its chop and volatility parts don't know direction; the wick part pointed slightly the wrong way |
| The trend score as a confidence level (bigger lots on higher scores) | Among taken trades the score is almost always above 7 and doesn't rank them (AUC 0.49 in 2026). Score-weighted lots: profit/DD 4.7 vs 5.0 |
| 16 more entry features (H4 and H1 trend, volume, candle size, recent push, previous day, D1 range, spread, closes in a row, $10 levels, volatility regime) | None separated winners in both periods (test AUC 0.47-0.52). All of them in one model: 0.60 on the design years, 0.53 on the test year |
| 10 entry attributes (position number, previous trade, losses in a row, hour, weekday, US data times, week open/close, D1 trend age and distance, time since the last exit) | No loser pattern held in both sideways (2022-24) and trend (2025-26) years. The win rate was 15-25% in every bucket in 2022-24 and 40-45% in 2025-26: the market regime decides, not the entry |
| A faster trend score (shorter lookbacks) | More whipsaw entries. In a walk-forward test the current lookbacks were best in both halves (×0.5, ×0.75 and ×2 all worse) |
| One combined score (M5 trend + D1 trend in one number), no other filters | Profit/DD 0.8 vs 5.0. Turning the loss filters off alone: 1.1 |
| Machine learning (gradient boosting, trained walk-forward) | AUC 0.47-0.58 by year, mean 0.51: it learned sideways-year patterns that reversed in trend years |
| An external AI decision model (with no examples, then with 500 labelled examples) | AUC 0.49. The trades it approved earned less per trade than all trades (+$1.85 vs +$2.16) |
| Supply/demand zones and fair value gaps (24 variants) | All lost in 2021-24; the chosen one made +0.07R per trade in 2025-26 vs -0.01R for random entries in the trend direction: no better than random |
| RSI 30/70 and 20/80 zones | -$203 per 0.01 lot without the trend filter, profit/DD 0.2-0.7 with it; also failed as a second strategy |
| Reversing the signals | January 2026 -$459 vs +$952 per 0.01 lot |
| Waiting for a breakout to confirm the entry | +25% vs +83% (2026): it buys near short-term highs |
| Not buying near the 24-hour high (selling near the low) | +30% on paper over 57 months; in the real EA +78% to +124% vs +130%, because blocked trades came back later, closer to the high |
| Stricter D1 filter (distance 1-2%, EMA slope) | Best +147% vs +130% over 57 months, but an isolated spike: its neighbours matched the default. Sideways years lose steadily while the D1 trend still looks intact |
| A gold/USDJPY cross-market filter | Gold +130% → +86-112%, USDJPY +82% → +12-14%: the two also trend together at times |
| Trading only the London / New York overlap (M1) | -70.0% vs +22.0% (2026). The MT5 "profit by hour" chart counts the hour a trade closed; the trades behind it opened earlier |
| A mid-month window (week 2 Friday to week 4 Tuesday, M1) | +56.5% vs +22.0% in 2026, but picked on the same months; not adopted without an out-of-sample test |

### Exits

| Idea | Result |
|---|---|
| Stops sized by ATR (4× ATR(8) or ATR(50)) | 2026 +106.9% / +90.0% vs +83.4%, but 2025 +60.5% / +23.5% vs +66.2%, 13/21 months up vs 16/21, worst month -25% / -12% vs -3%. The EA enters during fast moves, so 4 ATR became $27-52 in 2026 |
| Tighter checkpoint stops (lock 80% or trail 80%) | 2026 +17.6% / +16.8% vs +51.4% (v45): they cut the trend runners |
| Closing early losers after 3-12 bars | +16% to +71% vs +83% (2026): many trend trades dip first |
| A $40 stop with a $25 checkpoint (modelled on a commercial gold EA that risks about 13% per trade) | Profit/DD 3.1 vs 5.0; with a trail from +$16: 70% winners but 2.6× the drawdown. Its smooth curve came from compounding and an 80% win rate at very high risk |
| No stop loss, trailing only after break-even | 84-95% winners but 2.7× the drawdown; with the emergency stop also off, two buys were held 244 days and the account lost 93% |
| Cutting losers that haven't recovered after 4 hours | Saved money in one setup and lost it in another: too fragile. Trades that recover and trades that don't look identical at entry; they only differ in how fast they fall in the first hours |
| Hedge chain (opposite trades to recover a loser) | 2026 +71% / 2025 +27% vs +83% / +57% without. The best gated version only broke even: the first hedge bets against the D1 trend. It stays in the EA, off |

### Positions, Frequency and Scalping

| Idea | Result |
|---|---|
| Pending-order grids, candle-following, tiny targets (separate test EAs) | Grids lost 160-530% over Jan-Jun 2026. The next M1 candle follows the previous one only 49.3% of the time. +$0.10 locks gave 80-85% winners averaging $0.60 against $4-5 losses |
| An M1 scalping study: session-open breakouts and Asian-session mean reversion (10,240 variants, pre-registered) | None beat random entries minus the ~$0.30 cost per trade |
| A frequent M1 profile (4 positions $1.50 apart, entries during the bar) | +133% vs +150% for M5 over 21 months, 8/21 months up; at 2.5% risk it lost up to 60% in a month |
| Adding to winners (up to 4 positions, only while in profit) | Profit/DD 3.8 vs 5.0; with a basket break-even or basket target 0.7-2.3 |
| A second gold strategy on M1 or H1 next to M5 | Profit/DD 2.6 / 3.3 vs 5.0: the streams move together (daily correlation 0.81 / 0.59) |
| Fewer open positions | Trades opened next to a running position were the best ones (+$2.38 vs +$1.40 per 0.01 lot in 2026), so the limit stays at 2 |
| An M15 measured breakout (separate EA: D1 + H1 trend, 10-bar breakout, stop beyond the 5-bar swing, 3R target) | +80% over 18 months with an 18% drawdown, vs the default's +110% and 30% at the time. Kept as an idea |
| A short-timeframe indicator EA (separate research EA: RSI, MACD, stochastic, EMAs, candle parts, self-learning weights) | Every part alone lost (profit factor 0.57-0.93), mean reversion lost in all forms, learning didn't help. With a D1 / H1 trend gate it met its targets (+35.9%, 88% winners): the daily trend again. The only short-term idea positive in both halves of 2026 was fading volume climaxes (profit factor 1.10 / 1.39), and only weakly |
| An EMA-pullback M5 EA with 2R targets | Profit factor 0.89-0.98 with a 30-33% win rate (2R needs 33% to break even) |

### Risk and Drawdown

| Idea | Result |
|---|---|
| Risk per trade 1.25 / 2.5 / 3.75 / 5% (M5, 21 months) | +150% / +274% / +400% / +521%, drawdown 20 / 36 / 52 / 64%. Return per drawdown stays the same: 2.5% became the high-risk profile |
| Dynamic lots (bigger lots after a drawdown) | 2026 +105% vs +83%, but worst month -15% vs -3% and drawdown 38% vs 20% |
| A set tuned on one month (6 positions $0.50 apart, dynamic lots, looser filters) | 2026 +116%, but one month lost 70% and the drawdown reached 87% |
| A settings search (460+ optimizer runs on 2025-26) | The best candidate beat the default in only 28 of 57 months: a coin flip. Single continuous-run comparisons are path noise |
| Daily loss cap (no entries after 1-3 losing exits in a day) | Trades after a same-day loss did better than average (+$2.40-2.83 vs +$1.77), so the cap cost profit |
| Pausing after 2 or 3 losses in a row instead of 4 | Deeper drawdown (563 / 472 vs 400 per 0.01 lot): the pause skips the trades that recover |
| An equity-curve pause; doubling the lot after a win | Lower profit/DD |
| Pausing 1-3 days after a big daily candle | 2026 $1,586-1,891 vs $1,920 per 0.01 lot, same drawdown: it cut January's trend gains |
| An adaptive minimum score (raised after losses, lowered after wins) | 26-46% less profit with the +$15 lock; without a time decay it locked the EA out (19 trades) |
| Half the risk after a losing 3 months (one account, 2022-2026) | Drawdown 43.5% vs 45.1%: the worst drop came right after the best month |
| Lots scaled down in volatile markets | 82% of the profit with 82% of the drawdown: the same as a lower risk setting |
| A $100 standard account at 1:2000 leverage | -80%: 0.01 lot is the smallest lot and still risks about 20% at the $20 stop; leverage only changes the margin |

### Other Markets

Beyond USDJPY and the scaled 57-month test in [Gold + USDJPY](#gold--usdjpy-on-one-account): crude oil and BTC with a grid of stop sizes (2025-26) had no profitable setting; wider stops only shrank the spread cost toward zero.

### October 2026 Checks

| Test | Result |
|---|---|
| 2025, ticks generated from 1-minute bars (v54.0, M5) | +65.3%, 10 of 12 months up, worst month -1.5%, drawdown 11.5%, profit factor 1.37 ([report](reports/xauusd-default-2025-generated-ticks/summary.md)); the older v51.0 rules made +66.2% |
| October 2026 (real ticks, to the 23rd) | -6.5%, 46 trades, 28% winners: the weakest month of 2026, as gold fell with weak trends |
| An H1 ATR(14) ≥ $34 volatility gate (the straddle's filter) **instead of** the D1 trend filter | +4.5% vs +93.8% (Jan-Sep 2026), worst month -16%, drawdown 28.4%: without the daily direction the edge is gone |
| The same gate **next to** the D1 filter, trading only extreme hours | +15.9%: Nyao Scalper earns in normal trending hours, not in extreme ones |
| The D1 filter plus skipping extreme hours (H1 ATR < $34) | +75.4%, drawdown 14.8% vs 19.2%: less profit for less drawdown, the same trade-off as a lower risk setting |
| A $1 stop with a $1 checkpoint | January -$117 (1,268 trades, 35% winners) vs +$952, February -$103 vs +$117: stopped. Tight stops turn it into a high-frequency trader that loses |
| Looser entry limits: up to 10 positions, no spacing, no cooldown, loss-streak pause, spread cap or equity pause | Jan-Sep 2026 M5 months summed +1,238% vs +93.9%, but one month lost 80% and the drawdown reached 88% (one account: +1,971% with a 66% drawdown); M1 -257.6%. Positions opened minutes apart hit the $20 stop together |
| 3 positions and a $10 gap, loss limits kept | +99.2% vs +93.9% with 15% more trades, but the worst month -13.3% vs -2.7% and the drawdown 24.6% vs 19.2%. 4 positions $7.50 apart: +69.1%, drawdown 32.6%. In the tests, adding USDJPY or a higher risk setting added return with less extra drawdown |
| Smaller locked profit: +$1 instead of +$15 | M5 +97.1% vs +93.9%, but M1 +7.7% vs +24.1% and the drawdown 24.5% vs 19.2%. The +$15 lock's exits often close at about $0 after slippage and count as losses for the cooldown and loss-streak pause; that is useful, because a trade that reached +$15 and fell all the way back marks a choppy market |
| Closing at +$100, or at +$50 with a +$5 lock, with the trail tightening to $10 | +72% to +94% vs +93.9%. Taking profit earlier raised the win rate (44% → 53%) and lowered the profit factor (1.23 → 1.14): the edge is the few trend trades that run far |
| Taking half the profit at the first checkpoint ($4,000 account, so the lot can be split) | +131.0% vs +156.3% over 57 months, lower in every year |
| Closing everything 30 minutes before the weekend | +126.5% vs +146.0% over 57 months (2026 M5 +76.4% vs +93.9%): trades held over the weekend tended to continue the trend |
| Trading costs | Every $0.05 less spread per 0.01-lot trade adds about 2.85 percentage points over Jan-Sep 2026 (M5) |
| v54.0: the old legacy score model and its 26 inputs removed | 18 real-tick runs (M1 and M5, Jan-Sep 2026) traded identically, deal for deal |
| Where does the trend score sit? (M5 bars, 2022-2026) | Median about 5.4 for buys (sells = 10 - buys), but spread almost evenly from 1 to 9, not bunched around 5: only 20% of bars score 4-6. Where the D1 filter allows a side, that side scores 5 or more on 54-59% of bars |

### Testing Lessons

- **Many monthly runs beat one long run.** A settings search that won on continuous runs was a coin flip across 57 separate months: any change reshuffles every later trade.
- **Paper estimates mislead.** Dropping trades on paper ignored that the EA re-enters later (24-hour filter, big-candle pause), and bar-based simulations overstated trailing exits. Only real EA runs count.
- **Real ticks for small distances.** Ticks generated from 1-minute bars are acceptable for Nyao Scalper's $20 distances but make $1 trailing stops look far too good.
- **Reruns drift by cents.** The tester applies today's swap rates, so the same EA rerun later differs by a few cents per month; compare against a same-day rerun of the old version.
- **Check the quote's decimals.** The same point inputs mean 10× the distance on a 2-decimal gold quote (`PointInputDigits` handles it now).
- **Write the pass rule first.** "More profit and no deeper drawdown than the default", decided before the run, kept lucky backtests from changing the defaults.

## Credits

**Author**: Elriz Wiraswara<br/>
**License**: BSD-3-Clause (Open Source)<br/>
**Repository**: [https://github.com/elrizwiraswara/nyao_scalper_mt5](https://github.com/elrizwiraswara/nyao_scalper_mt5)

> **Disclaimer:** I do not sell or commercialize this EA under my name. If you encounter anyone selling it claiming to represent me, please treat it as a scam and report it.
