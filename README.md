# Nyao Scalper v40.0

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
- **blended weighted average signal smoothing**: Combining recent closed candle signals with a configurable dampened current candle contribution for improved responsiveness while maintaining signal stability.

### Risk & Equity Management

- **Equity Protection**:
  - **Min Equity Stop**: Hard stop if equity falls below a specific dollar amount.
  - **Max Drawdown Stop**: Stops trading if drawdown from peak exceeds a set limit.
  - **Daily Target**: Optional target profit to stop trading for the day.
- **News Filter**: Automatically pauses trading before and after high-impact news events.
- **Trading Hours**: Configurable start and end times to avoid low-liquidity sessions.
- **Leverage Guard**: Pauses trading if account leverage changes unexpectedly.

### Position Management

- **Duplicate Signal Filter**: Uses "Zone Points" and minimum distance multipliers to prevent over-stacking positions.
- **Adaptive Trailing**:
  - Standard trailing stop logic.
  - **Signal-Based Adaptation**: Tightens or loosens TP/SL based on real-time changes in the Signal Score.
- **Loss Management**:
  - **Scaled Partial Close**: Gradually reduces position volume as signal decays (75% → close 25%, 50% → close 50%, 25% → full exit).
  - **Dynamic SL Tightening**: Pulls stop-loss closer proportionally as position health weakens below a threshold.
  - **Break-Even Lock**: Moves SL to entry price once profit exceeds spread cost, protecting gains.
  - **Virtual SL + Re-entry**: Closes losing positions at the health threshold, then immediately re-enters at the current (better) price if the signal is still valid.

### Lot Sizing

- **Recovery Mode**: Increases lot size incrementally after equity drops for faster recovery.
- **Confidence Mode**: Increases lot size for high-confidence signals (e.g., Score > 9.0).
- **Velocity Boost**: Slightly increases position size if signal velocity (momentum) is accelerating.

### Dashboard & Alerts

- **On-Chart Dashboard**: Real-time display of Signal Scores, Equity, Drawdown, and Statistics.
- **Discord Integration**: Sends alerts to Discord via Webhook for:
  - Trade Open/Close
  - Equity Milestones
  - News Events
  - Trading Pauses/Resumes

## Strategy Logic

The strategy uses a **weighted scoring system** (0.0 - 10.0 scale). A trade is taken only if the _Total Score_ exceeds the `MinSignalScore` threshold (Default: 6.0).

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
    - **Chop Filter (Max 2.0)**: ATR ratio classifies trend strength vs. chop risk.
    - **Volatility (Max 1.0)**: Expanding volatility (ATR ratio > 1.2) adds to the score.
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

## Credits

**Author**: Elriz Wiraswara<br/>
**License**: BSD-3-Clause (Open Source)<br/>
**Repository**: [https://github.com/elrizwiraswara/nyao_scalper_mt5](https://github.com/elrizwiraswara/nyao_scalper_mt5)

> **Disclaimer:** I do not sell or commercialize this EA under my name. If you encounter anyone selling it claiming to represent me, please treat it as a scam and report it.
