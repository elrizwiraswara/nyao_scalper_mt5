# Nyao Scalper v32.0

**Advanced Indicator-Based Signal Strength EA for MetaTrader 5**

> **Disclaimer:** This Expert Advisor is an experimental project for educational purposes. Trading Forex/CFDs involves significant risk. Past performance is not indicative of future results. Use at your own risk.

Nyao Scalper is a sophisticated automated trading system designed for scalping on lower timeframes (M1, M5). Unlike simple indicator-crossing bots, it uses a **Composite Signal Strength Engine** that aggregates data from multiple technical factors (Trend, Momentum, Volatility, Price Action) into a single confidence score (0.0 - 10.0).

It features advanced position management, including smart pyramiding, adaptive trailing stops, and dynamic lot sizing based on equity performance and signal quality.

## Key Features

### Composite Signal Engine

The EA calculates a "Signal Score" for every tick based on:

- **Trend**: Fast/Slow EMA crossover and slope alignment.
- **Momentum**: RSI "sweet spots" (trending ranges), breakouts, and candle body momentum.
- **Impulse**: Detects price acceleration and directional continuity (consecutive candles).
- **Volatility**: ATR-based analysis to detect chopping vs. trending markets.
- **Price Action**: Penalizes signals with large opposing wicks (rejection) and rewards breakouts from local peaks.
- **Velocity**: Tracks the _change_ in signal score to detect strengthening or weakening moves.

### Risk & Equity Management

- **Equity Protection**:
  - **Min Equity Stop**: Hard stop if equity falls below a specific dollar amount.
  - **Max Drawdown Stop**: Stops trading if drawdown from peak exceeds a set limit.
  - **Daily Target**: Optional target profit to stop trading for the day.
- **News Filter**: Automatically pauses trading before and after high-impact news events.
- **Trading Hours**: Configurable start and end times to avoid low-liquidity sessions.
- **Leverage Guard**: Pauses trading if account leverage changes unexpectedly.

### Dynamic Position Management

- **Smart Pyramiding**: Adds positions to winning trades or recovery trades, restricted by "Max Positions Per Candle" and "Zone Points" to prevent over-stacking.
- **Adaptive Trailing**:
  - Standard trailing stop logic.
  - **Signal-Based Adaptation**: Tightens or loosens TP/SL based on real-time changes in the Signal Score.
- **Loss Management**: Automatically closes losing positions if the current Signal Score drops significantly below the entry score (Signal Decay).

### Dynamic Lot Sizing

- **Recovery Mode**: Increases lot size incrementally after equity drops to facilitate faster recovery.
- **Confidence Mode**: Increases lot size for high-confidence signals (e.g., Score > 9.0).
- **Velocity Boost**: Slightly increases position size if signal velocity (momentum) is accelerating.

### Dashboard & Alerts

- **On-Chart Dashboard**: Real-time display of Signal Scores, Equity, Drawdown, and Statistics.
- **Discord Integration**: Sends rich alerts to Discord via Webhook for:
  - Trade Open/Close
  - Equity Milestones
  - News Events
  - Trading Pauses/Resumes

## Strategy Logic

The core strategy uses an **Additive Weighted Scoring System** (0.0 - 10.0 scale). A trade is taken only if the _Total Score_ exceeds the `MinSignalScore` threshold (Default: 6.0).

**Note:** All scoring weights (Trend, Momentum, Volatility, etc.) are **fully adjustable** in the EA settings, allowing you to customize the strategy's sensitivity to different market conditions.

The score is calculated by summing up weights from specialized components:

1.  **Trend Score (Max 3.0)**:
    - **Alignment (+1.5)**: Fast EMA > Slow EMA (Buy).
    - **Slope (+1.5)**: Fast EMA is rising (Buy).

2.  **Momentum Score (Max 3.0)**:
    - **RSI Sweet Spot (+1.0)**: RSI between 50-80 (Buy) or 20-50 (Sell).
    - **RSI Breakout (+0.5)**: RSI crosses key levels (60 for Buy, 40 for Sell).
    - **Body Momentum (+1.5)**: Current candle body is larger than recent average.
    - **Impulse Boost**: Momentum score is amplified if multiple consecutive candles move in the same direction.

3.  **Volatility & Structure (Max 4.0)**:
    - **Chop Filter (+2.0)**: High ATR ratio indicates potential trend vs. chop.
    - **Volatility (+1.0)**: Expanding volatility adds to the score.
    - **Breakout (+1.0)**: Price breaking above local interactions (recent highs/lows).

4.  **Penalties (Deductions)**:
    - **Wick Rejection**: Long opposing wicks reduce the final score (e.g., long upper wick on a Buy signal).

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
**License**: MIT (Open Source)<br/>
**Repository**: [https://github.com/elrizwiraswara/nyao_scalper_mt5](https://github.com/elrizwiraswara/nyao_scalper_mt5)

> **Disclaimer:** I do not sell or commercialize this EA under my name. If you encounter anyone selling it claiming to represent me, please treat it as a scam and report it.
