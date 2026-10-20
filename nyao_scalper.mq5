// +------------------------------------------------------------------+
// | Nyao Scalper v51.0                                               |
// | Indicator-Based Signal Strength EA with Comprehensive Features   |
// | © Copyright Nyao Scalper by Elriz Wiraswara                      |
// +------------------------------------------------------------------+
#property copyright "© Copyright Nyao Scalper by Elriz Wiraswara"
#property version "51.0"
#property description "Auto Trading EA Robot with Comprehensive Features"
#property description ""
#property description "This is an open-source project for educational and experimental purposes only"
#property description "Source: https://github.com/elrizwiraswara/nyao_scalper_mt5 [BSD-3-Clause]"
#property description ""
#property description "No guarantee of profitability. Use at your own risk. Past performance ≠ future results"
#property description "Built with significant effort, please use and share respectfully"
#property description "I do not sell this EA myself. If sold under my name, treat it as a scam and report it"
#property description "Named after my cat MaoMao, he says 'Nyao!' when spotting good trades"
#property strict

// Display name used in logs, alerts and the dashboard (keep in sync with #property version)
#define EA_TITLE "Nyao Scalper v51.0"

// Per-position persistent state file format (bump when ManagedPosition changes)
#define STATE_FILE_VERSION 4

#include <Generic\HashMap.mqh>

// Dialog Controls for Password Input
#include <Controls\Dialog.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>

// Print wrapper with logging control (quietLog mutes it while the dashboard re-runs the entry checks)
#define LogPrint if(EnableLogging && !quietLog) Print

enum ENUM_INPUT_TYPE
{
    INPUT_DOLLAR,                                         // Dollar Amount
    INPUT_PERCENT,                                        // Percent of Equity
    INPUT_POINTS,                                         // Points
    INPUT_ATR                                             // ATR Multiple (last closed bar)
};

enum ENUM_RR_RISK_MODE
{
    RR_RISK_MANUAL,                                      // Manual Distance
    RR_RISK_ATR                                          // Auto (ATR-Based)
};

enum ENUM_LIMIT_ANCHOR
{
    LIMIT_ANCHOR_FIXED_ATR,                              // Fixed ATR Fraction (flat depth)
    LIMIT_ANCHOR_EMA,                                    // Fast EMA
    LIMIT_ANCHOR_SWING,                                  // Swing Level (structure)
    LIMIT_ANCHOR_SMART                                   // Nearer of Swing/EMA (ATR-capped)
};

enum ENUM_CHECKPOINT_HOLD
{
    CP_HOLD_TREND,                                       // Higher-Timeframe Trend (uses HTF filter settings)
    CP_HOLD_SCORE,                                       // Signal Score Direction
    CP_HOLD_BOTH                                         // Trend AND Score
};

enum ENUM_REGIME_MODE
{
    REGIME_ATR_EXPANSION,                                // ATR Expansion (legacy)
    REGIME_EFFICIENCY_RATIO                              // Directional Efficiency Ratio
};
enum ENUM_SCORE_MODEL
{
    SCORE_LEGACY,                                        // Short-Term Confluence (legacy)
    SCORE_TREND                                          // Multi-Hour Trend Strength
};

enum ENUM_DRAWDOWN_SCOPE
{
    DD_SCOPE_ACCOUNT,                                    // Whole Account Equity
    DD_SCOPE_OWN                                         // This EA's Own Trades (several symbols on one account)
};

input group "+-----------------------------------------+"
input group " Nyao Scalper v51.0"
input group " © Copyright Nyao Scalper by Elriz Wiraswara"
input group "+-----------------------------------------+"

// +------------------------------------------------------------------+
// | Input Parameters                                                 |
// +------------------------------------------------------------------+
input group "📊 Indicator Settings"
input int DirectionalBodyLookback = 10;                   // Lookback for directional body analysis
input int EMAFastPeriod = 5;                              // EMA Fast Period
input int EMASlowPeriod = 12;                             // EMA Slow Period
input int SlopeLookback = 3;                              // EMA Slope Lookback Bars (noise reduction)
input int RSIPeriod = 8;                                  // RSI Period
input int ATRPeriod = 8;                                  // ATR Period
input int ATRAvgLookback = 10;                            // ATR Average Lookback
input double MinVolRatioToTrade = 0.0;                    // Min ATR/AvgATR Ratio to Trade (0 = Disabled, blocks dead market)
input int ImpulseLookback = 3;                            // Impulse Lookback
input double ImpulseBoostWeight = 1.0;                    // Impulse Boost Weight
input int SignalSmoothingCandles = 2;                     // Closed Candles for Weighted Average (1-10)
input double CurrentCandleBlend = 0.40;                   // Current Candle Blend Factor (0.0-1.0)
input double VelocityWindow = 2.0;                        // Velocity Window (Score Delta)
input int RSIOverbought = 80;                             // RSI Overbought Level (Max Buy)
input int RSIOversold = 20;                               // RSI Oversold Level (Min Sell)
input int RSIMomentumBuy = 60;                            // RSI Momentum Buy Trigger
input int RSIMomentumSell = 40;                           // RSI Momentum Sell Trigger
input bool EnableHTFTrendFilter = true;                   // Only Enter With Higher-Timeframe Trend (HTF EMA)
input ENUM_TIMEFRAMES HTFTimeframe = PERIOD_D1;           // Higher Timeframe for Trend Filter
input int HTFEMAPeriod = 50;                              // Higher Timeframe EMA Period
input double HTFMinDistancePct = 0.5;                     // HTF Filter: Close Must Be >= this % Beyond the EMA (0 = Off)
input double HTFMinSlopePct = 0.0;                        // HTF Filter: EMA Must Move >= this % Over HTFSlopeBars (0 = Off)
input int HTFSlopeBars = 5;                               // HTF Filter: Bars Used for the EMA Slope Check

input group "⚖️ Score Weight Settings"
input ENUM_SCORE_MODEL ScoreModel = SCORE_TREND;          // Score Model (Trend: range, EMA, efficiency and momentum over hours)
input int TrendRangeBars = 200;                           // Trend Score: Range Position Lookback (bars)
input int TrendEMAPeriod = 200;                           // Trend Score: EMA Period
input int TrendERBars = 100;                              // Trend Score: Efficiency Ratio Lookback (bars)
input int TrendROCBars = 192;                             // Trend Score: Momentum Lookback (bars)
input int TrendATRPeriod = 14;                            // Trend Score: ATR Period (distance unit)
input double TrendWeight = 1.5;                           // Trend Alignment Initial Weight
input double SlopeWeight = 1.5;                           // Trend Slope Confirmation Weight
input double MomentumBaseWeight = 1.0;                    // Momentum Base Weight (RSI Sweet Spot)
input double MomentumTriggerWeight = 0.5;                 // Momentum Trigger Weight (RSI Breakout)
input double BodyMomentumWeight = 1.5;                    // Body Momentum Weight
input bool DirectionalBodyMomentum = true;                // Body / Impulse Momentum Only Counts Candles Moving the Trade's Way
input ENUM_REGIME_MODE RegimeScoreMode = REGIME_ATR_EXPANSION; // Regime (Chop) Score Mode
input int ERPeriod = 10;                                  // Efficiency Ratio Period (Regime Mode = ER)
input double ERHighThreshold = 0.50;                      // ER >= this -> Chop Score High (Regime Mode = ER)
input double ERMedThreshold = 0.30;                       // ER >= this -> Chop Score Med (Regime Mode = ER)
input double ChopScoreHigh = 2.0;                         // Chop Score High (Strong Trend)
input double ChopScoreMed = 1.0;                          // Chop Score Med (Weak Trend)
input double ChopScoreLow = 0.0;                          // Chop Score Low (Chop Risk - no free points)
input double VolatilityScoreHigh = 1.0;                   // Volatility Score High
input double VolatilityScoreLow = 0.0;                    // Volatility Score Low (no free points)
input double PeakScoreWeight = 1.0;                       // Peak Breakout Score Weight
input double WickRejectionWeight = 1.0;                   // Wick Rejection Penalty Weight
input double MinBodyRatio = 1.5;                          // Min Body Ratio for Wick Calculation

input group "📝 Order & Position Settings"
input int PointInputDigits = 3;                           // Point Inputs Are Written for N-Decimal Quotes, Rescaled to This Symbol (0 = As-Is)
input bool EnableBuyOrders = true;                        // Enable Buy Orders
input bool EnableSellOrders = true;                       // Enable Sell Orders
input bool EnableNewBarEntryOnly = true;                  // Evaluate/Open Entries Only on New Bar (stable signals)
input double MinEfficiencyToTrade = 0.0;                  // Range Filter: Min Directional Efficiency Ratio to Enter (0 = Off)
input int RangeFilterPeriod = 20;                         // Range Filter: Efficiency Ratio Lookback (closed bars)
input bool EnableMaxSpreadFilter = true;                  // Block New Entries When Spread Too Wide
input double MaxSpreadPoints = 500;                       // Max Spread in Points (0 = Auto: ATR-based)
input double MaxSpreadATRRatio = 0.25;                    // Auto Spread Cap as Fraction of ATR (when MaxSpreadPoints = 0)
input double BaseLotSize = 0.01;                          // Base Lot Size
input int MaxOpenOrders = 2;                              // Max Consecutive Open Orders
input int MaxTradesPerCandle = 1;                         // Max Trades Per Candle (0 = Unlimited)
input double ConsecutiveCandleThresholdBoost = 1.0;       // Signal Threshold Boost Per Consecutive Trading Candle
input int MaxConsecutiveCandleBoosts = 3;                 // Max Consecutive Candle Boosts (0 = Unlimited)
input double ZonePoints = 10000;                          // Zone Points to Avoid Duplicate Signals
input double BuyDuplicateMultiplier  = 1.5;               // Min Distance Multiplier to Avoid Duplicate Buy Signals
input double SellDuplicateMultiplier = 1.5;               // Min Distance Multiplier to Avoid Duplicate Sell Signals
input double MinBreakEvenProfit = 0.5;                    // Min Profit to Trigger Break-Even ($ | 0 = Disabled)
input double ProfitThresholdMultiplier = 1.5;             // Threshold Multiplier for Min Break-Even Profit
input double LossThresholdMultiplier = 2.0;               // Threshold Multiplier for Max Break-Even Loss
input double MinBuySignalScore = 5.0;                     // Min Signal Strength Score to Buy (0.0 - 10.0)
input double MinSellSignalScore = 5.0;                    // Min Signal Strength Score to Sell (0.0 - 10.0)

input group "🎯 Limit Entry Settings"
input bool EnableLimitEntry = false;                      // Fresh Entries Use Pending Limit (pullback) Instead of Market
input ENUM_LIMIT_ANCHOR LimitEntryAnchor = LIMIT_ANCHOR_FIXED_ATR; // Pullback Anchor (Smart = nearer of Swing/EMA)
input double LimitEntryATRFraction = 0.25;                // Pullback Depth / ATR Cap as Fraction of ATR (below Ask / above Bid)
input int LimitEntryExpiryBars = 1;                       // Cancel Unfilled Limit After N Bars (0 = no expiry)
input bool LimitEntryCancelOnFlip = true;                 // Cancel Pending When Directional Signal Drops Below Threshold

input group "🛡️ Signal Dampening Settings"
input bool EnableSignalDampening = true;                  // Enable Position-Aware Signal Dampening
input int MaxLosingPositionsSameDir = 2;                  // Max Losing Positions in Same Direction Before Block
input double LosingPosScorePenalty = 1.5;                 // Score Penalty Per Losing Same-Direction Position
input double DrawdownThresholdPct = 3.0;                  // Equity Drawdown % to Raise Signal Threshold
input double DrawdownScoreBoost = 2.0;                    // Extra Score Required During Drawdown
input ENUM_DRAWDOWN_SCOPE DrawdownScope = DD_SCOPE_ACCOUNT; // Drawdown Measured On (This EA = another symbol's losses don't count)
input int ConsecutiveLossesBeforeCooldown = 3;            // Consecutive Losses Before Cooldown Activates
input int ConsecutiveLossCooldownBars = 3;                // Cooldown Duration (Bars) After Threshold Reached
input int LossStreakPauseCount = 4;                       // Pause After N Losses in a Row, Paper-Trade Until a Paper Win (0 = Off)

input group "🩺 Loss Management Settings"
input bool EnableLossManagement = false;                  // Enable Adaptive Loss Management
input int MaxHoldingLossPositions = 2;                    // Max Losing Positions to Hold
input double MinHealthScore = 0.40;                       // Min Health Score to Hold Position (0.0 - 1.0)
input double MaxAdverseATR = 1.5;                         // Max Adverse Movement in ATR Multiples
input double HealthTrendWeight = 0.40;                    // Health Weight: Trend Alignment
input double HealthRSIWeight = 0.25;                      // Health Weight: RSI Zone
input double HealthATRWeight = 0.25;                      // Health Weight: Adverse Excursion
input double HealthSwingWeight = 0.10;                    // Health Weight: Swing Level
input double HealthRSIBuyMin = 40.0;                      // Health RSI Min for Buy Position
input double HealthRSISellMax = 60.0;                     // Health RSI Max for Sell Position
input int HealthSwingLookback = 20;                       // Swing Level Lookback Bars
input int HealthGraceBars = 2;                            // Grace Period (Bars Before Health Check)
input bool EnablePartialClose = true;                     // Enable Scaled Partial Close on Signal Decay
input double PartialClose75Pct = 0.25;                    // Close % When Signal Drops to 75% of Initial
input double PartialClose50Pct = 0.50;                    // Close % When Signal Drops to 50% of Initial
input double PartialClose25Pct = 1.00;                    // Close % When Signal Drops to 25% of Initial (Remaining)
input bool EnableHealthSLTightening = true;               // Tighten SL as Health Weakens
input double SLTightenATRMultiplier = 2.0;                // ATR Multiplier for Tightened SL
input double SLTightenMinHealthPct = 0.50;                // Start Tightening Below This Health %
input bool EnableBreakEvenOnSpread = false;               // Lock SL to Entry After Profit > Spread Cost
input double BreakEvenSpreadMultiplier = 1.5;             // Spread Multiplier for Break-Even Lock Trigger
input double BreakEvenTriggerATR = 0.0;                   // Break-Even Lock Trigger: Favorable Move in ATR (0 = use Spread Multiplier)
input bool EnableVirtualSLReentry = true;                 // Close at Threshold Then Re-evaluate & Re-enter
input bool ReentryRespectsNewBarGate = false;             // Re-entry Obeys New-Bar Entry Gate (no intrabar re-entry)
input double ReentryMinSignalPct = 0.75;                  // Min % of Entry Signal Required to Re-enter
input bool EnableProfitOffsetSL = true;                   // Tighten SL of Losing Pos by Consecutive Closed Profits
input int ConsecutiveWinsRequired = 3;                    // Min Consecutive Wins Before Offset Applies
input double MinOffsetProfit = 1.0;                       // Min Accumulated Profit ($) to Trigger SL Offset

input group "🔀 Hedge Chain (Rolling Martingale Recovery) Settings"
input bool EnableHedgeChain = false;                      // Enable Hedge Chain (MARTINGALE - high risk)
input double HedgeTriggerATR = 1.5;                       // Adverse Move (ATR) to Start the Chain
input bool HedgeRequireSignal = true;                     // Only Hedge if Reverse Signal Confirms (anti-spike)
input double HedgeMinSignalScore = 6.5;                   // Min Reverse-Direction Score to Open Hedge (Trend score: the trend has turned)
input bool HedgeAutoLot = true;                           // Auto-size Hedge Lot to Recover (else Multiplier)
input double HedgeRecoveryATR = 1.0;                      // Favorable Move (ATR) to Recover Within
input double HedgeLotMultiplier = 2.0;                    // Fixed Hedge Lot Multiplier (Auto-size OFF)
input double HedgeMaxLot = 0.10;                          // Hard Lot Ceiling Per Hedge Leg
input double HedgeMaxTotalLots = 0.20;                    // Max Total Lots Across All Active Chain Legs (0 = Unlimited)
input int HedgeMaxActiveChains = 1;                       // Max Concurrent Hedge Chains (0 = Unlimited)
input double HedgeRecoveryPct = 100.0;                    // Close Older Leg When Hedge Covers This % Loss
input double HedgeRollMinProfit = 0.0;                    // Min Older-Leg Profit ($) to Roll
input int HedgeCycleLevels = 2;                           // Max Hedge Levels Per Cycle Before Reseed
input bool EnableHedgeCycleReset = true;                  // Reseed New Cycle at Limit (else Release Chain)
input double HedgeCyclePartialPct = 50.0;                 // % of Deepest Hedge to Close at Reseed
input int HedgeMaxCycles = 3;                             // Max Cycles Before Releasing Chain (0 = Unlimited)
input double HedgeMaxChainLossUSD = 0.0;                  // Close Chain if Loss >= this $ (0 = Off)
input double HedgeMaxChainLossPct = 5.0;                  // Close Chain if Loss >= this % Equity (0 = Off)
input double HedgeMaxChainLossSL = 1.5;                   // Close Chain if Loss >= this x the Base Lot's SL Loss (0 = Off)
input bool HedgeClearRootSL = true;                       // Clear First Position SL on Chain Start
input double HedgeTrailATR = 1.0;                         // Graduated Hedge Trail Distance (ATR; 0 = normal trailing)

input group "🧮 Dynamic Lot Sizing Settings"
input double RiskPerTradePct = 1.25;                      // Risk-Based Lot: % Equity Lost at SL (ATR/Points SL only; 0 = Off, Use BaseLotSize)
input double MaxRiskPerTradePct = 5.0;                    // Risk-Based Lot: Still Trade Min Lot up to this % at SL (0 = Skip Instead)
input bool EnableDynamicLots = false;                     // Enable Dynamic Lot Sizing
input double EquityDropPercent = 5.0;                     // Equity Drop % per Lot Step
input int MaxEquityDropLotSteps = 2;                      // Max Drawdown-Based Lot Steps (0 = Unlimited)
input double MinSignalStrengthForLot = 8.0;               // Min Signal Score for Lot Increase
input double LotStepSize = 0.01;                          // Lot Increase Step Size
input double MaxLotSize = 0.05;                           // Max Lot Size

input group "🏦 Equity Settings"
input bool EnableBasketStop = true;                       // Close All When Total Floating Loss Exceeds Limit
input double MaxBasketLossPct = 8.0;                      // Max Total Floating Loss as % of Equity (0 = Disabled)
input double MaxTotalLossPct = 12.0;                      // Hard Stop: Floating Loss incl. Hedge Chains, % of Equity (0 = Disabled)
input double MinEquityPercent = 70.0;                     // Min Equity % from Peak - Pause Trading when Reached
input double MaxDrawdownFromPeak = 0;                     // Max Equity $ Drawdown - Pause Trading when Reached (0 = Disabled)
input int PauseMinutes = 5;                               // Pause Duration (Minutes)
input double PauseMinutesMultiplier = 1.5;                // Multiply Pause Duration on Each Trigger
input int MaxPauseMinutes = 120;                          // Max Pause Duration Minutes (0 = Max 24,855 days)
input int MaxMinEquityTriggers = 0;                       // Max Times Trigger - Stop Trading when Reached (0 = Unlimited)
input bool ResetOnNewPeak = true;                         // Reset Min Equity Triggers on New Peak Equity
input double TargetEquity = 0;                            // Target Equity - Stop Trading when Reached (0 = Disabled)
input double MinimumEquity = 20;                          // Min Equity - Stop Trading when Reached (0 = Disabled)

input group "📈 Take Profit Settings"
input bool EnableTakeProfit = true;                       // Enable Take Profit
input ENUM_INPUT_TYPE TPInputType = INPUT_POINTS;         // TP Input Type
input double TPValue = 20000.0;                           // TP Value

input group "📉 Stop Loss Settings"
input bool EnableStopLoss = true;                         // Enable Stop Loss
input ENUM_INPUT_TYPE SLInputType = INPUT_POINTS;         // SL Input Type
input double SLValue = 20000.0;                           // SL Value

input group "⚖️ Risk:Reward Settings"
input bool EnableRiskReward = false;                      // Enable Independent R:R SL/TP (overrides manual SL & TP)
input ENUM_RR_RISK_MODE RRRiskMode = RR_RISK_ATR;         // Risk (SL) Sizing: Manual or Auto ATR
input ENUM_INPUT_TYPE RRRiskInputType = INPUT_POINTS;     // Manual Risk Input Type (when Mode = Manual)
input double RRRiskValue = 200.0;                         // Manual Risk Distance (SL leg, when Mode = Manual)
input double RRAtrMultiplier = 1.5;                       // Auto Risk: SL = ATR × this (when Mode = ATR)
input double RiskRewardRatio = 1.5;                       // Reward : Risk (TP distance = SL distance × this)

input group "🏁 Checkpoint Exit Settings"
input bool EnableCheckpointExit = true;                   // TP Becomes a Checkpoint: Re-check, Keep & Lock Instead of Closing
input ENUM_CHECKPOINT_HOLD CheckpointHoldMode = CP_HOLD_SCORE; // Keep the Trade at a Checkpoint If...
input double CheckpointLockPct = 50.0;                    // % of the Move to the Checkpoint Locked Into the SL
input int CheckpointMaxSkips = 0;                         // Loss Side: Times the SL May Be Pushed One SL-Distance Further While Score Agrees (0 = Never)
input double TrendFlipExitScore = 6.0;                    // Loss Side: Close a Losing Trade When the Opposite Score Reaches This (0 = Off)
input double CheckpointTrailPct = 100.0;                  // Trailing Stop Distance Behind the Price, % of the Checkpoint Distance (0 = Off)
input double CheckpointTrailStartPct = 50.0;              // Start Trailing at This Profit, % of the Checkpoint Distance (0 = After the 1st Held Checkpoint)
input double CheckpointBreakEvenPct = 75.0;               // Lock the Smallest Profit Once Profit Reaches This % of the Checkpoint Distance (0 = Off)

input group "💸 Trailing TP/SL Settings"
input bool EnableTrailing = false;                        // Enable Trailing TP/SL
input bool TrailingEnableBreakEvenLock = true;            // Enable Trailing Break-Even Lock
input bool TrailingSLOnProfitableOnly = true;             // Trailing SL on Profitable Position Only
input bool EnableAdaptiveTP = true;                       // Enable Adaptive TP
input bool EnableAdaptiveSL = true;                       // Enable Adaptive SL
input ENUM_INPUT_TYPE TSInputType = INPUT_DOLLAR;         // Trailing Distance Input Type
input double TrailingDistanceValue = 0.2;                 // Trailing Distance Value
input double TrailingValueMultiplier = 0.2;               // Trailing Value Multiplier
input double TrailStartATR = 0.0;                         // Start Trailing Only After Favorable Move >= this x ATR (0 = $ threshold)

input group "🤖 Robot Settings"
input int MagicNumber = 6926268;                          // Magic Number
input bool EnableDiscordAlerts = false;                   // Enable Discord Alerts
input string DiscordWebhookURL = "";                      // Discord Webhook URL
input bool EnableTradingHours = false;                    // Enable Trading Hours
input string TradingStartTime = "00:00";                  // Trading Start Time (HH:MM)
input string TradingEndTime = "23:59";                    // Trading End Time (HH:MM)
input bool EnableReports = true;                          // Enable Trading Reports
input int SendReportEveryHour = 1;                        // Send Report Every (n) Hours 
input bool EnableMarketCloseFilter = true;                // Stop Opening New Positions Near Market Close Hour
input int MinutesBeforeClose = 30;                        // Stop Opening Minutes Before Market Close
input bool EnableNewsFilter = true;                       // Enable News Filter (Pause Trading During News)
input int NewsMinutesBefore = 30;                         // Minutes Before News Event
input int NewsMinutesAfter = 30;                          // Minutes After News Event
input bool EnableLeveragePause = true;                    // Pause Trading When Leverage Changed
input bool CloseAllOnLeverageChange = true;               // Also Close All Positions When Leverage Changes
input bool EnablePersistState = true;                     // Save/Restore Position & Chain State Across Restarts
input bool ResetSavedState = false;                       // Discard Saved State on Next Start (set back to false after)
input bool EnableLogging = false;                         // Enable EA Logging (May cause lag)

// +------------------------------------------------------------------+
// | Global Variables                                                 |
// +------------------------------------------------------------------+
bool quietLog = false;                                    // true while the dashboard evaluates entry gates
// EMBEDDED PASSWORD - Change this to your desired password (leave empty to disable)
const string EA_PASSWORD = "";

// Password Dialog Controls
CDialog passwordDialog;
CEdit passwordEdit;
CButton passwordSubmitBtn;
bool passwordVerified = false;
bool passwordDialogActive = false;

double initialBalance = 0;                                // Initial Account Balance     
double peakEquity = 0;                                    // Peak Equity Recorded
double ownClosedPL = 0;                                   // DrawdownScope = This EA: P/L of this EA's closed deals
double ownPeakPL = 0;                                     // ... and its best closed + floating P/L so far
double lastPeakEquity = 0;                                // Last recorded peak equity for drawdown calculations
bool targetEquityReached = false;                         // Flags for target/minimum equity reached
bool minimumEquityReached = false;                        // Flags for target/minimum equity reached
bool minEquityTriggersExceeded = false;                   // Flag when max triggers exceeded
int minEquityTriggerCount = 0;                            // Counter for MinEquityPercent triggers
// Pause state - one timer per reason so pauses can't cancel or overwrite each other
datetime equityPauseUntil = 0;                            // Min-equity drawdown pause end (server time)
datetime basketPauseUntil = 0;                            // Basket / hard-stop cool-off end (server time)
datetime newsPauseUntil = 0;                              // High-impact news window end (server time)
bool wasPaused = false;                                   // Previous-tick pause state (for resume alert)
string lastPauseReason = "";                              // Reason(s) of the most recent pause
bool isOutsideTradingHours = false;                       // Flag when outside trading hours
bool isLeverageDiffFromInitial = false;                   // Flag for leverage changed
bool isNearMarketClose = false;                           // Flag for near market close time
ulong lastProcessedNewsEventID = 0;                       // Last processed news event ID
string symbolBaseCurrency = "";                           // Base currency of the symbol
string symbolQuoteCurrency = "";                          // Quote currency of the symbol
long initialLeverage = 0;                                 // Initial Account Leverage
long stateLogin = 0;                                      // Account the state file belongs to (captured at init)
bool initDeferred = false;                                // InitializeEA waits for the terminal to connect
ulong restoredTickets[];                                  // Positions whose saved state was restored at init
ulong lastBalanceDeal = 0;                                // Newest deposit / withdrawal already applied to the baselines
double lastSeenBalance = 0;                               // Balance on the previous tick
datetime balanceChangedAt = 0;                            // When the balance last changed (peaks wait a moment)
ulong adoptPending[];                                     // Unrestored positions still waiting for a stop / checkpoint
bool isOrderSendLocked = false;                           // Flag for locking OrderSend execution
bool marketCloseAlertSent = false;                        // Flag for near market close time
bool algoTradingStatus = false;                           // Flag for algo trading status
bool stopRemoveRequested = false;                         // ExpertRemove() already requested after an equity stop
bool eaInitialized = false;                               // InitializeEA() completed (guards state saving)

// Loss-streak pause (LossStreakPauseCount): real entries stop after N losses in a row; the
// signals keep being "paper traded" and real trading resumes on the first paper (or real) win
int streakLosses = 0;                                     // consecutive losing trades (real closes + paper results)
bool streakPaused = false;                                // real entries blocked, paper trading active
int paperDir = 0;                                         // open paper trade: +1 buy, -1 sell, 0 none
double paperEntry = 0, paperTarget = 0, paperStop = 0;    // its entry, win level (first checkpoint / TP) and stop
datetime lastNewsCheckTime = 0;                           // Throttle for the calendar lookup
int htfEmaHandle = INVALID_HANDLE;                        // Handle for Higher-Timeframe EMA (trend filter)

// Normalized Health Weights
double normHealthTrendWeight = 0;
double normHealthRSIWeight = 0;
double normHealthATRWeight = 0;
double normHealthSwingWeight = 0;

// Duplicate Signal Filter Variables
datetime startTime = 0;                                   // EA Start Time
datetime lastDailyReportTime = 0;                         // Last time daily report was sent
double lastReportEquity = 0;                              // Equity at last report

// Pause Tracking
int totalPauseCount = 0;                                  // Total number of times trading was paused
double totalPauseDurationMinutes = 0;                     // Total duration of pauses in minutes


int emaFastHandle = INVALID_HANDLE;                       // Handle for Fast EMA
int emaSlowHandle = INVALID_HANDLE;                       // Handle for Slow EMA
int rsiHandle = INVALID_HANDLE;                           // Handle for RSI
int atrSignalHandle = INVALID_HANDLE;                     // Handle for Signal ATR
int trendEmaHandle = INVALID_HANDLE;                      // Handle for the Trend Score EMA
int trendAtrHandle = INVALID_HANDLE;                      // Handle for the Trend Score ATR

// Signal Strength Structure - Indicator-Based Scoring System
// Weights are adjustable via Score Weight Settings inputs
struct SignalStrength
{
    double avgBody;                                       // Average body size of matching candles
    double bodySignal;                                    // Body size of signal candle
    double ratio;                                         // Ratio of bodySignal / avgBody
    double upperWick;                                     // Upper wick size
    double lowerWick;                                     // Lower wick size
    double rejection;                                     // Wick to body ratio
    double penaltyBody;                                   // Penalty from body ratio
    double penaltyWick;                                   // Penalty from wick rejection
    double finalScore;                                    // 0.00-10.00 Score
    double trendScore;                                    // Trend Component (0-3)
    double momentumScore;                                 // Momentum Component (0-3)
    double chopScore;                                     // Chop Component (0-2)
    double peakScore;                                     // Peak Component (0-1)
    double volatilityScore;                               // Volatility Component (0-1)
    double impulseStrength;                               // 0.0-1.0 Impulse Strength
    double velocity;                                      // Current Score - Previous Score (informational)
    double normalizedVelocity;                            // 0.0-1.0 Normalized Velocity (informational)
    bool deadMarket;                                      // Last closed candle failed MinVolRatioToTrade
    double trendRange;                                    // Trend model: position in the range (-1..+1, + = bullish)
    double trendEma;                                      // Trend model: distance from the EMA (-1..+1)
    double trendEfficiency;                               // Trend model: directional efficiency (-1..+1)
    double trendMomentum;                                 // Trend model: move over the lookback (-1..+1)
    string reasoning;                                     // Detailed explanation
};

// Position Health Structure - Measurement-Based Revalidation
// Evaluates whether a position's trade thesis is still valid
struct PositionHealth
{
    double healthScore;                                   // 0.0 (dead) to 1.0 (fully healthy)
    bool trendValid;                                      // EMA still aligned with position direction?
    bool momentumValid;                                   // RSI still in favorable zone?
    double adverseATR;                                    // How many ATRs moved against position
    bool swingValid;                                      // Price hasn't broken swing level?
    bool inGracePeriod;                                   // Position too new for health check?
    string reason;                                        // Human-readable invalidation reason
};

// Managed Position Structure - For Position Tracking 
// Stores position info to avoid repeated MQL function calls
struct ManagedPosition
{
    ulong ticket;                                         // Position ticket ID
    ENUM_POSITION_TYPE type;                              // Buy or Sell
    double signalScore;                                   // Initial signal score
    double entryPrice;                                    // Entry price for adverse excursion calc
    int partialCloseLevel;                                // 0=none, 1=75% triggered, 2=50% triggered, 3=fully closed
    bool breakEvenLocked;                                 // Whether SL has been moved to break-even by loss mgmt
    int profitOffsetConsecWins;                           // Consecutive winning trades closed since this position opened
    double profitOffsetAccumulated;                       // Accumulated profit from consecutive wins (USD)
    double profitOffsetOriginalSL;                        // Original SL price when position was opened
    ulong chainId;                                        // Rolling-hedge chain id (current cycle's root ticket); 0 = standalone
    int hedgeLevel;                                       // Level within the cycle: 0 = root, 1+ = each successive hedge
    double chainAnchorLoss;                               // Cycle start loss ($, positive) carried on every leg of the cycle
    int cycleNum;                                         // Which cycle this leg belongs to (0 = first; +1 on each reseed)
    bool noRehedge;                                       // true = exhausted chain released to loss mgmt; never start a new chain on it
    bool hedgeGraduated;                                  // true = former chain leg; trail with HedgeTrailATR (lot-independent) not the $ distance
    double hedgeLockProfit;                               // min profit ($) to keep locked on a graduated hedge (recovery floor); 0 = none
    double cpPrice;                                       // Checkpoint exit: next checkpoint price (0 = not in checkpoint mode)
    double cpStep;                                        // Checkpoint exit: price distance between checkpoints (= initial TP distance)
    double virtSL;                                        // Checkpoint exit: EA-managed inner stop for the loss-side skip rule (0 = none)
    double virtStep;                                      // Checkpoint exit: distance each skip pushes the inner stop (= initial SL distance)
    int cpSkipsLeft;                                      // Checkpoint exit: loss-side skips remaining
    int cpCount;                                          // Checkpoint exit: checkpoints passed so far
    double chainBooked;                                   // Hedge chain: loss already booked by reseed partial closes ($, <= 0), on every leg
    double cpLock;                                        // Checkpoint exit: SL price owed by the last checkpoint passed (0 = none)
};

// Managed positions array
ManagedPosition managedPositions[];
int managedPositionCount = 0;

// Candle-based Position Counters
datetime currentBarTime = 0;
int buysOnCurrentBar = 0;
int sellsOnCurrentBar = 0;

// New-Bar Entry Gate (only evaluate entries once per closed bar when enabled)
datetime lastEntryBarTime = 0;
bool lastOrderRetryable = false;                          // The last entry order was rejected for a price move
int entryRetries = 0;                                     // Entry retries used on entryRetryBar
datetime entryRetryBar = 0;

// Consecutive Trading Candle Tracker (for threshold escalation)
int consecutiveBuyCandles = 0;                            // How many consecutive candles opened buy positions
int consecutiveSellCandles = 0;                           // How many consecutive candles opened sell positions
bool prevBarHadBuys = false;                              // Whether the previous bar opened buy positions
bool prevBarHadSells = false;                             // Whether the previous bar opened sell positions

// Signal Dampening Globals
int consecutiveLossCount = 0;                             // Track consecutive closing losses
datetime cooldownUntilBarTime = 0;                        // Bar time after which cooldown expires

// Last Position Tracking
datetime lastBuyTime = 0;
double lastBuyPrice = 0;
datetime lastSellTime = 0;
double lastSellPrice = 0;

// Last signal tracking per candle (velocity baseline)
double lastBuySignalScore = 0;
double lastBuySignalScorePrev = 0;
double lastSellSignalScore = 0;
double lastSellSignalScorePrev = 0;

// Per-tick signal cache (invalidated each tick)
// Slots: 0 = buy, 1 = sell, 2 = buy (entry, closed candles only), 3 = sell (entry, closed candles only)
bool _strengthValid[4];
SignalStrength _strengthCache[4];

// Dashboard / statistics throttling
ulong lastDashboardMs = 0;                                // Last dashboard redraw (GetTickCount64)
bool tradeStatsDirty = true;                              // A deal was added since the last stats pass
datetime lastStatsCalcTime = 0;                           // Last stats pass (server time)

// Persistent state bookkeeping
ManagedPosition lastSavedPositions[];                     // Snapshot written by the last SaveState()
int lastSavedCount = -1;                                  // -1 = nothing saved yet this session

// Trade Statistics Structure
struct TradeStats
{
    int count;
    int won;
    int lost;
    double profit;                                        // Total net profit
    double loss;                                          // Total net loss (sum of negative profits)
    double avgProfit;                                     // Average of winning trades
    double maxProfit;                                     // Largest single profit
    double minProfit;                                     // Smallest single profit
    double avgLoss;                                       // Average of losing trades
    double maxLoss;                                       // Largest single loss (most negative)
    double minLoss;                                       // Smallest single loss (closest to 0)
};

// +------------------------------------------------------------------+
// | Create Password Dialog                                           |
// +------------------------------------------------------------------+
bool CreatePasswordDialog()
{
    if(!passwordDialog.Create(0, "PasswordDialog", 0, 10, 10, 324, 120))
        return false;
    
    passwordDialog.Caption("Enter Password to Use Nyao Scalper EA");
    
    if(!passwordEdit.Create(0, "PasswordEdit", 0, 5, 10, 300, 35))
        return false;

    passwordEdit.Text("");

    if(!passwordDialog.Add(passwordEdit))
        return false;
    
    if(!passwordSubmitBtn.Create(0, "PasswordSubmit", 0, 5, 45, 100, 75))
        return false;

    passwordSubmitBtn.Text("Submit");

    if(!passwordDialog.Add(passwordSubmitBtn))
        return false;
    
    return true;
}

// +------------------------------------------------------------------+
// | Expert Initialization Function                                   |
// +------------------------------------------------------------------+
int OnInit()
{   
    // Password protection - show dialog if password is set
    if(EA_PASSWORD != "")
    {
        passwordVerified = false;
        passwordDialogActive = true;
        
        if(!CreatePasswordDialog())
        {
            Alert("ERROR: Failed to create password dialog!");
            return(INIT_FAILED);
        }
        
        Print("🔐 Password required. Please enter password in the dialog on chart.");
        return(INIT_SUCCEEDED);
    }
    else
    {
        passwordVerified = true;
        passwordDialogActive = false;
    }
    
    // At terminal / VPS start the account may not be synced yet (login, leverage, margin mode and
    // positions read as 0): wait for the connection instead of initialising on empty data
    if(!MQLInfoInteger(MQL_TESTER) && !AccountReady())
    {
        initDeferred = true;
        EventSetTimer(1);
        Print(EA_TITLE, ": waiting for the trade server connection before initialising...");
        return(INIT_SUCCEEDED);
    }

    // Continue with normal initialization
    return(InitializeEA());
}

// Account data is synced with the trade server (safe to read margin mode, leverage, positions)
bool AccountReady()
{
    return TerminalInfoInteger(TERMINAL_CONNECTED) && AccountInfoInteger(ACCOUNT_LOGIN) > 0
        && AccountInfoInteger(ACCOUNT_LEVERAGE) > 0 && SymbolInfoDouble(_Symbol, SYMBOL_BID) > 0;
}

// Finish an initialisation that OnInit deferred until the terminal was connected
void TryDeferredInit()
{
    if(!initDeferred || !AccountReady()) return;
    initDeferred = false;
    EventKillTimer();
    if(InitializeEA() != INIT_SUCCEEDED)
    {
        Alert(EA_TITLE, ": initialization failed - removing the EA");
        ExpertRemove();
    }
}

void OnTimer()
{
    TryDeferredInit();
}

// +------------------------------------------------------------------+
// | Full EA Initialization                                           |
// +------------------------------------------------------------------+
int InitializeEA()
{
    eaInitialized = false;

    // The multi-position design (stacking, reverse hedge legs) only works on a hedging
    // account. On a netting account a reverse "hedge" would close/flip the position.
    if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
    {
        Alert("ERROR: ", EA_TITLE, " requires a HEDGING account (netting/exchange accounts are not supported)");
        return(INIT_FAILED);
    }

    if(BaseLotSize <= 0)
    {
        Alert("ERROR: BaseLotSize must be greater than 0");
        return(INIT_PARAMETERS_INCORRECT);
    }

    if(MaxLotSize < BaseLotSize)
    {
        Alert("ERROR: MaxLotSize must be >= BaseLotSize");
        return(INIT_PARAMETERS_INCORRECT);
    }

    if(FloorToVolumeStep(BaseLotSize) < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        Alert("ERROR: BaseLotSize ", BaseLotSize, " is below the broker minimum ",
              SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), " for ", _Symbol);
        return(INIT_PARAMETERS_INCORRECT);
    }

    if(!EnableBuyOrders && !EnableSellOrders)
    {
        Alert("ERROR: Both Buy and Sell orders are disabled! EA will not trade!");
        return(INIT_PARAMETERS_INCORRECT);
    }

    // Inputs used as divisors or loop lengths
    if(EMAFastPeriod < 1 || EMASlowPeriod < 1 || RSIPeriod < 1 || ATRPeriod < 1 || ATRAvgLookback < 1 ||
       SlopeLookback < 1 || DirectionalBodyLookback < 1 || ImpulseLookback < 1 || SignalSmoothingCandles < 1 ||
       VelocityWindow <= 0)
    {
        Alert("ERROR: indicator periods / lookbacks must be >= 1 and VelocityWindow > 0");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if(ScoreModel == SCORE_TREND && (TrendRangeBars < 2 || TrendEMAPeriod < 1 || TrendERBars < 2 || TrendROCBars < 1 || TrendATRPeriod < 1))
    {
        Alert("ERROR: Trend Score lookbacks must be >= 2 (range, efficiency) and >= 1 (EMA, momentum, ATR)");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if(PointInputDigits < 0 || PointInputDigits > 8)
    {
        Alert("ERROR: PointInputDigits must be 0 (use points as-is) or 1-8 (the quote decimals the point inputs are written for)");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if(PointScale() != 1.0)
        Print("[POINTS] Point inputs are written for ", PointInputDigits, "-decimal quotes and ", _Symbol, " has ", _Digits,
              " decimals: point values x", DoubleToString(PointScale(), 4), " (same price distances, e.g. SL ",
              DoubleToString(GetSLPoints(BaseLotSize), 0), " pts = ", DoubleToString(GetSLPoints(BaseLotSize) * _Point, _Digits), ")");
    if(HedgeMaxChainLossSL < 0 || TrendFlipExitScore < 0 || TrendFlipExitScore > 10 || CheckpointBreakEvenPct < 0 ||
       MaxRiskPerTradePct < 0)
    {
        Alert("ERROR: HedgeMaxChainLossSL, CheckpointBreakEvenPct and MaxRiskPerTradePct must be >= 0, TrendFlipExitScore 0-10");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if(EnableLossManagement && MaxAdverseATR <= 0)
    {
        Alert("ERROR: MaxAdverseATR must be > 0 when EnableLossManagement is on");
        return(INIT_PARAMETERS_INCORRECT);
    }
    if(EnableCheckpointExit && (CheckpointLockPct < 0 || CheckpointLockPct >= 100))
    {
        Alert("ERROR: CheckpointLockPct must be between 0 and 99 (100% would put the SL on the price itself)");
        return(INIT_PARAMETERS_INCORRECT);
    }

    string tradingHoursTestParts[];

    if(StringSplit(TradingStartTime, ':', tradingHoursTestParts) != 2)
    {
        Alert("ERROR: Invalid TradingStartTime format. Use HH:MM");
        return(INIT_PARAMETERS_INCORRECT);
    }

    if(StringSplit(TradingEndTime, ':', tradingHoursTestParts) != 2)
    {
        Alert("ERROR: Invalid TradingEndTime format. Use HH:MM");
        return(INIT_PARAMETERS_INCORRECT);
    }

    // Normalize health weights to sum to 1.0
    double healthWeightSum = HealthTrendWeight + HealthRSIWeight + HealthATRWeight + HealthSwingWeight;
    if(healthWeightSum > 0)
    {
        normHealthTrendWeight = HealthTrendWeight / healthWeightSum;
        normHealthRSIWeight   = HealthRSIWeight   / healthWeightSum;
        normHealthATRWeight   = HealthATRWeight   / healthWeightSum;
        normHealthSwingWeight = HealthSwingWeight  / healthWeightSum;
        
        if(MathAbs(healthWeightSum - 1.0) > 0.001)
        {
            Print("⚠️ Health weights sum to ", DoubleToString(healthWeightSum, 3), ", normalized to 1.0");
        }
    }
    else
    {
        // Fallback: equal weights
        normHealthTrendWeight = 0.25;
        normHealthRSIWeight   = 0.25;
        normHealthATRWeight   = 0.25;
        normHealthSwingWeight = 0.25;
        Print("⚠️ All health weights are 0, defaulting to equal weights (0.25 each)");
    }

    // Initialize Signal Indicators
    emaFastHandle = iMA(_Symbol, _Period, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(emaFastHandle == INVALID_HANDLE)
    {
        Print("Error creating Fast EMA handle!");
        return(INIT_FAILED);
    }
    
    emaSlowHandle = iMA(_Symbol, _Period, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(emaSlowHandle == INVALID_HANDLE)
    {
        Print("Error creating Slow EMA handle!");
        return(INIT_FAILED);
    }
    
    rsiHandle = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE)
    {
        Print("Error creating RSI handle!");
        return(INIT_FAILED);
    }
    
    atrSignalHandle = iATR(_Symbol, _Period, ATRPeriod);
    if(atrSignalHandle == INVALID_HANDLE)
    {
        Print("Error creating Signal ATR handle!");
        return(INIT_FAILED);
    }

    if(ScoreModel == SCORE_TREND)
    {
        trendEmaHandle = iMA(_Symbol, _Period, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
        trendAtrHandle = iATR(_Symbol, _Period, TrendATRPeriod);
        if(trendEmaHandle == INVALID_HANDLE || trendAtrHandle == INVALID_HANDLE)
        {
            Print("Error creating Trend Score indicator handles!");
            return(INIT_FAILED);
        }
    }

    if(EnableHTFTrendFilter)
    {
        htfEmaHandle = iMA(_Symbol, HTFTimeframe, HTFEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
        if(htfEmaHandle == INVALID_HANDLE)
        {
            Print("Error creating HTF EMA handle!");
            return(INIT_FAILED);
        }
    }

    if(EnableCheckpointExit)
    {
        if(!EnableTakeProfit && !EnableRiskReward)
            Print("⚠️ Checkpoint exit is on but no TP distance is set (EnableTakeProfit / EnableRiskReward) - it has nothing to work with");
        if(CheckpointHoldMode != CP_HOLD_SCORE && !EnableHTFTrendFilter)
            Print("⚠️ Checkpoint hold mode uses the HTF trend but EnableHTFTrendFilter is off - the trend check always passes");
    }
    else if(CheckpointTrailPct > 0)
        Print("⚠️ CheckpointTrailPct only works with EnableCheckpointExit - it is ignored");

    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    lastPeakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(DrawdownScope == DD_SCOPE_OWN) InitOwnPL();
    targetEquityReached = false;
    minimumEquityReached = false;
    minEquityTriggersExceeded = false;
    minEquityTriggerCount = 0;
    equityPauseUntil = 0;
    basketPauseUntil = 0;
    newsPauseUntil = 0;
    wasPaused = false;
    stopRemoveRequested = false;
    streakLosses = 0;
    streakPaused = false;
    paperDir = 0;
    lastNewsCheckTime = 0;
    lastProcessedNewsEventID = 0;
    startTime = TimeCurrent();
    lastDailyReportTime = 0;
    lastReportEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    totalPauseCount = 0;
    totalPauseDurationMinutes = 0;
    symbolBaseCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
    symbolQuoteCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
    initialLeverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    stateLogin = AccountInfoInteger(ACCOUNT_LOGIN);
    lastBalanceDeal = LatestBalanceDeal();                 // older deposits are already in the baselines
    lastSeenBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    balanceChangedAt = 0;
    // Block flags survive a re-init; each check sets them again on its next pass
    isOutsideTradingHours = false;
    isLeverageDiffFromInitial = false;
    isNearMarketClose = false;
    isOrderSendLocked = false;
    algoTradingStatus = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
    
    // Initialize managed positions array
    ArrayResize(managedPositions, 0);
    managedPositionCount = 0;

    // Reset bar / last-entry bookkeeping (globals survive a parameter or timeframe re-init,
    // so the rebuild below would otherwise double count)
    currentBarTime = 0;
    buysOnCurrentBar = 0;
    sellsOnCurrentBar = 0;
    lastBuyTime = 0;
    lastBuyPrice = 0;
    lastSellTime = 0;
    lastSellPrice = 0;
    for(int c = 0; c < 4; c++) _strengthValid[c] = false;
    lastDashboardMs = 0;
    tradeStatsDirty = true;

    // Scan and register existing positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double posEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        
        // For existing positions, try to calculate current signal strength as baseline
        // If calculation fails or returns 0, use a default safe value (MinBuySignalScore)
        double initialScore = 0;
        
        // We can't easily get the signal at open time, so we use current as baseline
        // This effectively "resets" the signal tracking for this position
        SignalStrength strength;
        if(type == POSITION_TYPE_BUY) strength = GetSignalStrength(ORDER_TYPE_BUY);
        else strength = GetSignalStrength(ORDER_TYPE_SELL);
        
        initialScore = strength.finalScore;
        if(initialScore <= 0) initialScore = (type == POSITION_TYPE_BUY) ? MinBuySignalScore : MinSellSignalScore;

        RegisterManagedPosition(ticket, type, initialScore, posEntryPrice);

        // Safety net when no saved state exists for this ticket: a former hedge leg (large,
        // naked martingale lot) must never seed a brand-new chain. RestoreState() below
        // overwrites these flags with the exact saved values when they are available.
        if(StringFind(PositionGetString(POSITION_COMMENT), "Hedge L") == 0)
        {
            int hIdx = GetManagedPositionIndex(ticket);
            if(hIdx != -1)
            {
                managedPositions[hIdx].noRehedge = true;
                managedPositions[hIdx].hedgeGraduated = true;
            }
        }

        // Update global last position tracking
        datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
        double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        
        // Reconstruct Candle Counters for existing positions
        datetime posBarTime = (posTime / PeriodSeconds(_Period)) * PeriodSeconds(_Period);
        datetime curBarTime = iTime(_Symbol, _Period, 0);
        
        // Initialize current bar time if needed
        if(currentBarTime == 0) currentBarTime = curBarTime;
        
        if(posBarTime == currentBarTime)
        {
            if(type == POSITION_TYPE_BUY) buysOnCurrentBar++;
            else sellsOnCurrentBar++;
        }
        
        if(type == POSITION_TYPE_BUY)
        {
            if(posTime > lastBuyTime)
            {
                lastBuyTime = posTime;
                lastBuyPrice = posPrice;
            }
        }
        else if(type == POSITION_TYPE_SELL)
        {
            if(posTime > lastSellTime)
            {
                lastSellTime = posTime;
                lastSellPrice = posPrice;
            }
        }
    }
    
    // Restore per-position (chain, partial-close, break-even...) and account-level state
    // saved before the last restart / re-init
    RestoreState();
    AdoptUnrestoredPositions();
    if(!EnableHedgeChain) ReleaseOrphanChainLegs();
    eaInitialized = true;
    SaveState(true);

    Print("+-----------------------------------------+");
    Print(EA_TITLE, " Initialized Successfully");
    Print("+-----------------------------------------+");

    // An account too small for RiskPerTradePct trades the minimum lot at a higher risk, or (above
    // MaxRiskPerTradePct) can't open anything with a fixed-distance stop: say so now
    if(RiskSizingApplies())
    {
        double slPts = GetSLPoints(BaseLotSize);
        double lossAtMinLot, riskMoney;
        double sized = (slPts > 0) ? RiskSizedLot(slPts * (1 + CheckpointSkipsFor(slPts)), lossAtMinLot, riskMoney) : -1;
        if(sized == 0)
            WarnRiskBlocksEntries(lossAtMinLot, riskMoney);
        else if(sized > 0 && lossAtMinLot > riskMoney)
            NoteRiskAboveBudget(lossAtMinLot, riskMoney);
    }

    if(EnableDiscordAlerts) CheckDiscordAlert();
    
    return(INIT_SUCCEEDED);
}

// +------------------------------------------------------------------+
// | Expert Deinitialization Function                                 |
// +------------------------------------------------------------------+
void OnDeinit(const int reason)
{   
    // Cleanup password dialog if active
    if(passwordDialogActive)
    {
        passwordDialog.Destroy();
        passwordDialogActive = false;
    }
    
    // Only an EA that finished InitializeEA() owns state worth saving: a failed init (bad
    // inputs, netting account) must never overwrite the saved chain state with an empty one
    if(passwordVerified && eaInitialized)
    {
        // Pending limits are GTC/broker-expiry orders that only this EA manages: never leave
        // them resting at the broker once the EA is gone (they would fill unmanaged)
        DeleteAllPendingOrders();

        // Persist the latest state so a restart / re-init picks up exactly where we left off
        SaveState(true);
    }

    // Send what is still queued (e.g. the equity-stop alert before ExpertRemove)
    for(int a = 0; a < 3 && ArraySize(alertTitles) > 0; a++)
    {
        alertRetryAfter = 0;
        FlushDiscordAlerts();
    }
    eaInitialized = false;
    if(initDeferred) EventKillTimer();
    initDeferred = false;

    // Cleanup Dashboard Objects
    ObjectsDeleteAll(0, "NyaoDash_");
    Comment("");

    // Release indicator handles
    IndicatorRelease(emaFastHandle);
    IndicatorRelease(emaSlowHandle);
    IndicatorRelease(rsiHandle);
    IndicatorRelease(atrSignalHandle);
    if(htfEmaHandle != INVALID_HANDLE) IndicatorRelease(htfEmaHandle);
    htfEmaHandle = INVALID_HANDLE;
    if(trendEmaHandle != INVALID_HANDLE) IndicatorRelease(trendEmaHandle);
    if(trendAtrHandle != INVALID_HANDLE) IndicatorRelease(trendAtrHandle);
    trendEmaHandle = INVALID_HANDLE;
    trendAtrHandle = INVALID_HANDLE;

    Print(EA_TITLE, " Deinitialized");
}

// +------------------------------------------------------------------+
// | Expert Tick Function                                             |
// +------------------------------------------------------------------+
void OnTick()
{
    if(initDeferred) TryDeferredInit();

    // Block trading until password is verified (and initialization actually succeeded)
    if(!passwordVerified || !eaInitialized) return;

    ProcessTick();

    // Persist state whenever it changed this tick (no-op otherwise)
    SaveState();

    // Alerts go out last, one per tick, so a slow webhook never delays trading
    FlushDiscordAlerts();
}

// +------------------------------------------------------------------+
// | Per-Tick Processing                                              |
// +------------------------------------------------------------------+
void ProcessTick()
{
    // Invalidate per-tick signal cache
    for(int c = 0; c < 4; c++) _strengthValid[c] = false;

    // A balance change may be a deposit / withdrawal: apply it before peaks and drawdown look at
    // equity (the transaction event can arrive after this tick)
    double balanceNow = AccountInfoDouble(ACCOUNT_BALANCE);
    if(balanceNow != lastSeenBalance)
    {
        lastSeenBalance = balanceNow;
        balanceChangedAt = TimeCurrent();
        CatchUpBalanceOperations(TimeCurrent() - 7 * 86400);
    }

    // Unrestored positions whose stop / checkpoint could not be set at init (e.g. ATR not ready)
    if(ArraySize(adoptPending) > 0) RetryAdoption();

    // Check Algo Trading status
    CheckAlgoTradingStatus();

    // Check and update peak equity
    CheckPeakEquity();
    
    // Check if target equity reached
    CheckTargetEquity();
    
    // Check if minimum equity reached
    CheckMinTradeableEquity();

    // Check equity drawdawn
    CheckEquityDrawdawn();

    // Aggregate (basket) floating-loss protection
    CheckBasketStop();

    if(targetEquityReached || minimumEquityReached || minEquityTriggersExceeded)
    {
        // Close all positions + pending orders, then remove this EA from the chart.
        // ExpertRemove() stops only this EA (other EAs in the terminal keep running) and
        // needs no DLL. It is requested only once nothing is left open, so a failed close
        // (e.g. market closed) is retried on the next tick instead of being orphaned.
        CloseAllPositions();
        DeleteAllPendingOrders();

        if(!stopRemoveRequested && CountOpenOrders() == 0 && CountPendingOrders() == 0)
        {
            // Everything is flat: drop the saved state so re-attaching the EA starts fresh
            if(IsPersistenceActive() && FileIsExist(StateFileName())) FileDelete(StateFileName());
            stopRemoveRequested = true;
            Print("[STOPPED] Equity stop reached - all positions closed. Removing ", EA_TITLE, " from the chart.");
            ExpertRemove();
        }

        UpdateDashboard();
        return;
    }

    // Check if current time is within allowed trading hours
    CheckTradingHours();

    // Check for leverage changes
    CheckLeverageChange();

    // Check for market close time
    CheckMarketClose();

    // Update Signal Globals on New Bar (for Velocity Tracking)
    datetime currBarTime = iTime(_Symbol, _Period, 0);
    if(currentBarTime != currBarTime)
    {
        // Update History Scores
        // Recalculate Score(1) which is the just-closed candle
        // We can't trust the live variable, so we re-calc
        lastBuySignalScorePrev = lastBuySignalScore;
        lastSellSignalScorePrev = lastSellSignalScore;

        // Update Buy Stats
        SignalStrength buyStr = GetSignalStrength(ORDER_TYPE_BUY);
        lastBuySignalScore = buyStr.finalScore;
        
        // Update Sell Stats
        SignalStrength sellStr = GetSignalStrength(ORDER_TYPE_SELL);
        lastSellSignalScore = sellStr.finalScore;
        
        // Track consecutive trading candles for threshold escalation
        // If the just-closed bar had trades, increment consecutive counter
        // Otherwise reset it (the streak is broken)
        if(buysOnCurrentBar > 0)
        {
            consecutiveBuyCandles++;
            prevBarHadBuys = true;
        }
        else
        {
            consecutiveBuyCandles = 0;
            prevBarHadBuys = false;
        }
        
        if(sellsOnCurrentBar > 0)
        {
            consecutiveSellCandles++;
            prevBarHadSells = true;
        }
        else
        {
            consecutiveSellCandles = 0;
            prevBarHadSells = false;
        }
        
        // Update Bar Time
        currentBarTime = currBarTime;
        buysOnCurrentBar = 0;
        sellsOnCurrentBar = 0;
    }

    // Check for high-impact news events (tracked continuously so the news window is
    // known even while another block - hours, leverage, market close - is active)
    CheckHighImpactNews();

    if (isOutsideTradingHours || isLeverageDiffFromInitial || isNearMarketClose)
    {
        // A failed close-all after a leverage change is retried until flat
        if(isLeverageDiffFromInitial && CloseAllOnLeverageChange && CountOpenOrders() > 0)
        {
            static datetime lastLeverageCloseTry = 0;
            if(TimeCurrent() - lastLeverageCloseTry >= 5)
            {
                lastLeverageCloseTry = TimeCurrent();
                CloseAllPositions();
            }
        }

        // Don't open new positions, but continue managing existing ones
        ManagePositions();
        MarkEntryBarSeen();
        CheckTradeReport();
        UpdateDashboard();
        return;
    }

    // Pause handling (news / basket stop / equity drawdown each run on their own timer)
    if (IsPaused())
    {
        wasPaused = true;
        lastPauseReason = GetPauseReasons();

        // Don't open new positions, but continue managing existing ones
        ManagePositions();
        MarkEntryBarSeen();
        CheckTradeReport();
        UpdateDashboard();
        return;  // EXIT - prevent all new orders while paused
    }

    if (wasPaused)
    {
        // Every pause timer has ended - resume trading
        wasPaused = false;

        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

        LogPrint("+-----------------------------------------+");
        LogPrint("PAUSE PERIOD ENDED (", lastPauseReason, ")");
        LogPrint("Trading RESUMED");
        LogPrint("Current Equity: $", currentEquity);
        LogPrint("+-----------------------------------------+");

        // Send Discord alert for trading resumed
        if(EnableDiscordAlerts)
        {
            string alertMsg = "**Instrument:** " + _Symbol + "\n";
            alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
            alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
            alertMsg += "**Pause Reason:** " + lastPauseReason + "\n";
            alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Action:** Trading Resumed";

            SendDiscordAlert("▶️ TRADING RESUMED!", alertMsg, 3066993); // Blue color
        }
    }
    
    // Manage existing positions
    ManagePositions();

    // Check for trading signals
    CheckForTradingSignal();

    // Check for Trade Report
    CheckTradeReport();
    
    // Update On-Chart Dashboard
    UpdateDashboard();
}

// While entries are blocked, still use up each new bar: when the block lifts mid-bar, the next
// entry decision waits for a fresh bar open instead of firing on a half-formed one
void MarkEntryBarSeen()
{
    if(EnableNewBarEntryOnly) lastEntryBarTime = iTime(_Symbol, _Period, 0);
}

// +------------------------------------------------------------------+
// | Chart Event Handler - Password Dialog                            |
// +------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(passwordDialogActive)
    {
        passwordDialog.OnEvent(id, lparam, dparam, sparam);
        
        // Check for submit button click
        if(id == CHARTEVENT_OBJECT_CLICK && sparam == "PasswordSubmit")
        {
            string enteredPassword = passwordEdit.Text();
            
            if(enteredPassword == EA_PASSWORD)
            {
                // Password correct - close dialog and initialize EA
                passwordDialog.Destroy();
                passwordDialogActive = false;
                passwordVerified = true;
                
                Print("Password verified! EA is now active.");
                
                // Complete initialization (after the trade server connection, like OnInit)
                if(!MQLInfoInteger(MQL_TESTER) && !AccountReady())
                {
                    initDeferred = true;
                    EventSetTimer(1);
                }
                else if(InitializeEA() != INIT_SUCCEEDED)
                {
                    Alert("EA initialization failed!");
                }
            }
            else
            {
                Alert("Invalid password! Please try again.");
                passwordEdit.Text("");
            }
        }
    }
}

// +------------------------------------------------------------------+
// | Trade Transaction Handler - Primary Close Detection              |
// | Fires when a deal is added to history. We account for a fully-   |
// | closed managed position here (event-driven) instead of relying   |
// | solely on per-tick polling, which can miss closes that bunch up  |
// | on a single tick. SyncManagedPositions stays as a reconciliation |
// | fallback; ProcessClosedPosition is idempotent so there is no     |
// | double counting between the two paths.                           |
// +------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    // Only react to a deal being added to history
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

    ulong dealTicket = trans.deal;
    if(dealTicket == 0) return;
    if(!HistoryDealSelect(dealTicket)) return;

    // Deposits / withdrawals move the equity baselines (not a drawdown, not a new peak)
    long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
    if(dealType == DEAL_TYPE_BALANCE || dealType == DEAL_TYPE_CREDIT)
    {
        ApplyBalanceOperation(dealTicket, HistoryDealGetDouble(dealTicket, DEAL_PROFIT));
        return;
    }

    // Only our symbol, and deals of our magic - or any deal that closes a position we manage
    // (a manual or close-by close carries no magic but still ends our trade)
    if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;

    long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
    ulong posID = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
    if(posID == 0) return;
    bool closingDeal = (dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY || dealEntry == DEAL_ENTRY_INOUT);
    if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber && !(closingDeal && GetManagedPositionIndex(posID) != -1))
        return;

    // Statistics are cached; recompute on the next dashboard / report pass
    tradeStatsDirty = true;
    ownClosedPL += DealNetPL(dealTicket);

    // NEW POSITION OPENED
    // Registers fills here so pending-limit entries get tracked. Market entries are
    // already registered inline in OpenPosition, so the index guard below skips them.
    if(dealEntry == DEAL_ENTRY_IN)
    {
        if(GetManagedPositionIndex(posID) != -1) return; // already tracked (market path)

        ENUM_POSITION_TYPE ptype;
        double entryPrice;
        string posComment = "";

        if(PositionSelectByTicket(posID))
        {
            ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            posComment = PositionGetString(POSITION_COMMENT);
        }
        else
        {
            // Fallback to deal data if the position can't be selected
            ptype = (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            entryPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
        }

        // Recover the entry-thesis score from the limit-order comment; fall back to the
        // direction's min threshold if absent (e.g. EA restarted before the fill).
        double score = ParseLimitEntryScore(posComment);
        if(score <= 0) score = (ptype == POSITION_TYPE_BUY) ? MinBuySignalScore : MinSellSignalScore;

        RegisterManagedPosition(posID, ptype, score, entryPrice);

        // A hedge leg whose order reported failure but filled later: a big naked lot outside any
        // chain - flag it so ProtectGraduatedHedges gives it a stop, and never chain it again
        bool lateHedgeLeg = (StringFind(posComment, "Hedge L") == 0);
        if(lateHedgeLeg)
        {
            int hi = GetManagedPositionIndex(posID);
            if(hi != -1) { managedPositions[hi].noRehedge = true; managedPositions[hi].hedgeGraduated = true; }
        }

        // Arm checkpoint mode for the filled limit (same distances it was placed with)
        if(EnableCheckpointExit && !lateHedgeLeg)
        {
            double fillVol = PositionSelectByTicket(posID) ? PositionGetDouble(POSITION_VOLUME)
                                                           : HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
            double fSl = GetSLPoints(fillVol);
            InitCheckpoint(posID, ptype, entryPrice, GetTPPoints(fillVol), fSl, CheckpointSkipsFor(fSl));
        }

        // Mirror OpenPosition's candle-counter + last-position bookkeeping for the fill bar
        datetime currBarTime = iTime(_Symbol, _Period, 0);
        if(currentBarTime != currBarTime)
        {
            currentBarTime = currBarTime;
            buysOnCurrentBar = 0;
            sellsOnCurrentBar = 0;
        }
        if(ptype == POSITION_TYPE_BUY)
        {
            buysOnCurrentBar++;
            lastBuyTime = TimeCurrent();
            lastBuyPrice = entryPrice;
        }
        else
        {
            sellsOnCurrentBar++;
            lastSellTime = TimeCurrent();
            lastSellPrice = entryPrice;
        }

        LogPrint("[LIMIT FILL] Position ", posID, " registered. Type: ",
                 ptype == POSITION_TYPE_BUY ? "BUY" : "SELL",
                 " | Entry: ", entryPrice, " | Score: ", DoubleToString(score, 1));
        SaveState();
        return;
    }

    // POSITION CLOSED (full close accounting)
    if(!closingDeal) return;

    // Partial close — the position is still open (reduced volume); no full-close accounting
    if(PositionSelectByTicket(posID)) return;

    // Only act on positions we manage (also guards against double accounting)
    if(GetManagedPositionIndex(posID) == -1) return;

    double closedProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                        + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                        + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

    ProcessClosedPosition(posID, closedProfit);
    SaveState();
}

// +------------------------------------------------------------------+
// | Position Loss State - Aggregate loss metrics for a direction     |
// +------------------------------------------------------------------+
struct PositionLossState
{
    int   losingCount;                                    // Number of losing positions in this direction
    int   totalCount;                                     // Total positions in this direction
    double totalUnrealizedLoss;                           // Sum of unrealized losses (negative = loss)
    double worstLossPct;                                  // Worst single position loss as % of entry
};

// +------------------------------------------------------------------+
// | Get Open Position Loss State for a Direction                     |
// | Scans all open managed positions and returns aggregate loss info |
// +------------------------------------------------------------------+
PositionLossState GetOpenPositionLossState(ENUM_POSITION_TYPE direction)
{
    PositionLossState state;
    state.losingCount = 0;
    state.totalCount = 0;
    state.totalUnrealizedLoss = 0;
    state.worstLossPct = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        if(posType != direction) continue;
        
        state.totalCount++;
        double profit = PositionGetDouble(POSITION_PROFIT);
        
        if(profit < 0)
        {
            state.losingCount++;
            state.totalUnrealizedLoss += profit; // Accumulate negative value
            
            // Calculate loss as % of entry for worst-case tracking
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            if(entryPrice > 0 && volume > 0 && contractSize > 0)
            {
                double lossPct = MathAbs(profit) / (entryPrice * volume * contractSize) * 100.0;
                if(lossPct > state.worstLossPct)
                    state.worstLossPct = lossPct;
            }
        }
    }
    
    return state;
}

// +------------------------------------------------------------------+
// | Get Total Floating P/L for our positions on this symbol          |
// +------------------------------------------------------------------+
double GetTotalFloatingPL()
{
    double total = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
    }
    return total;
}

// +------------------------------------------------------------------+
// | Floating P/L of NON hedge-chain positions only                   |
// | A hedge chain intentionally carries a transient drawdown while it |
// | recovers; including its legs here would let the basket stop close |
// | the chain prematurely. Active chain legs are bounded by their own |
// | HedgeMaxChainLossPct/USD instead. Falls back to the full total    |
// | when the hedge feature is disabled.                               |
// +------------------------------------------------------------------+
double GetBasketFloatingPL()
{
    if(!EnableHedgeChain) return GetTotalFloatingPL();

    double total = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        int idx = GetManagedPositionIndex(ticket);
        if(idx != -1 && managedPositions[idx].chainId != 0) continue; // skip active chain legs

        total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
    }
    return total;
}

// Net money a deal added to the account: profit, swap, commission and fee
double DealNetPL(ulong deal)
{
    return HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP)
         + HistoryDealGetDouble(deal, DEAL_COMMISSION) + HistoryDealGetDouble(deal, DEAL_FEE);
}

// DrawdownScope = This EA: rebuild this EA's closed P/L and its best level from the deal history,
// so a restart keeps a running drawdown (floating peaks before the restart are not known)
void InitOwnPL()
{
    ownClosedPL = 0; ownPeakPL = 0;
    if(!HistorySelect(0, TimeCurrent())) return;
    int n = HistoryDealsTotal();
    for(int i = 0; i < n; i++)
    {
        ulong deal = HistoryDealGetTicket(i);
        if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
        if(HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber) continue;
        ownClosedPL += DealNetPL(deal);
        ownPeakPL = MathMax(ownPeakPL, ownClosedPL);
    }
}

// Drawdown of this EA's own trades in % - the same formula as (peak - equity) / peak, which it equals
// when this EA trades the account alone; other symbols' profits and losses don't count
double OwnDrawdownPct()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dd = ownPeakPL - (ownClosedPL + GetTotalFloatingPL());
    if(dd <= 0 || equity <= 0) return 0;
    return dd / (equity + dd) * 100.0;
}

// +------------------------------------------------------------------+
// | Basket Stop - Close all when aggregate floating loss exceeds cap |
// | Per-position management protects single trades; this is a hard   |
// | portfolio-level backstop against compounding stacked drawdown.   |
// +------------------------------------------------------------------+
void CheckBasketStop()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(equity <= 0) return;

    // HARD STOP (includes active hedge-chain legs): the basket stop below deliberately
    // ignores chains, so this is the one aggregate cap that bounds everything the EA holds.
    if(MaxTotalLossPct > 0)
    {
        double totalPL = GetTotalFloatingPL();
        if(totalPL < 0)
        {
            double totalLossPct = (-totalPL / equity) * 100.0;
            if(totalLossPct >= MaxTotalLossPct)
            {
                LogPrint("+-----------------------------------------+");
                LogPrint("TOTAL LOSS HARD STOP TRIGGERED!");
                LogPrint("Floating Loss (incl. hedge chains): $", DoubleToString(totalPL, 2),
                         " (", DoubleToString(totalLossPct, 2), "% of equity >= ", DoubleToString(MaxTotalLossPct, 2), "%)");
                LogPrint("Closing ALL positions (including hedge chains) and pausing.");
                LogPrint("+-----------------------------------------+");

                CloseAllPositions();
                int hardStopMinutes = StartBasketPause();

                if(EnableDiscordAlerts)
                {
                    string alertMsg = "**Instrument:** " + _Symbol + "\n";
                    alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
                    alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                    alertMsg += "**Floating Loss:** $" + DoubleToString(totalPL, 2) + " (" + DoubleToString(totalLossPct, 2) + "%)\n";
                    alertMsg += "**Limit:** " + DoubleToString(MaxTotalLossPct, 2) + "% of equity (incl. hedge chains)\n";
                    alertMsg += "**Pause Duration:** " + IntegerToString(hardStopMinutes) + " minutes\n";
                    alertMsg += "**Action:** All Positions Closed (incl. Hedge Chains), Trading Paused";

                    SendDiscordAlert("🛑 TOTAL LOSS HARD STOP", alertMsg, 15158332); // Red color
                }
                return;
            }
        }
    }

    if(!EnableBasketStop || MaxBasketLossPct <= 0) return;

    // Exclude active hedge-chain legs: they are bounded by HedgeMaxChainLossPct/USD,
    // not by the basket stop (a chain's transient drawdown must not trip the basket).
    double floatingPL = GetBasketFloatingPL();
    if(floatingPL >= 0) return; // only acts on net floating loss

    double lossPct = (-floatingPL / equity) * 100.0;
    if(lossPct < MaxBasketLossPct) return;

    LogPrint("+-----------------------------------------+");
    LogPrint("BASKET STOP TRIGGERED!");
    LogPrint("Floating Loss (excl. hedge chains): $", DoubleToString(floatingPL, 2),
             " (", DoubleToString(lossPct, 2), "% of equity >= ", DoubleToString(MaxBasketLossPct, 2), "%)");
    LogPrint("Closing all non-chain positions and pausing.");
    LogPrint("+-----------------------------------------+");

    CloseAllPositions(false, true);  // skip active hedge-chain legs

    int basketMinutes = StartBasketPause();

    if(EnableDiscordAlerts)
    {
        string alertMsg = "**Instrument:** " + _Symbol + "\n";
        alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
        alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
        alertMsg += "**Floating Loss:** $" + DoubleToString(floatingPL, 2) + " (" + DoubleToString(lossPct, 2) + "%)\n";
        alertMsg += "**Limit:** " + DoubleToString(MaxBasketLossPct, 2) + "% of equity\n";
        alertMsg += "**Pause Duration:** " + IntegerToString(basketMinutes) + " minutes\n";
        alertMsg += "**Action:** All Positions Closed, Trading Paused";

        SendDiscordAlert("🧺 BASKET STOP TRIGGERED", alertMsg, 15158332); // Red color
    }
}

// +------------------------------------------------------------------+
// | Check For Trading Signals                                        |
// +------------------------------------------------------------------+
void CheckForTradingSignal()
{
    // NEW-BAR ENTRY GATE
    // When enabled, evaluate/open entries only once per newly closed bar.
    // Position management still runs every tick (ManagePositions in OnTick).
    // This stabilizes signals (no intrabar repaint) and makes "Open prices"/
    // "1-minute OHLC" backtests representative of live behavior.
    if(EnableNewBarEntryOnly)
    {
        datetime currBarTime = iTime(_Symbol, _Period, 0);
        if(lastEntryBarTime == currBarTime) return;
        if(IsSpreadTooWide()) return;                     // wait for a normal spread within this bar
        lastEntryBarTime = currBarTime;
        if(entryRetryBar != currBarTime) { entryRetryBar = currBarTime; entryRetries = 0; }
    }
    lastOrderRetryable = false;

    // Check Signals (a disabled direction scores 0, so it can't hide a valid signal the other way)
    double buySignal  = EnableBuyOrders  ? BuySignal()  : 0;
    double sellSignal = EnableSellOrders ? SellSignal() : 0;

    // Loss-streak pause: the signal is still evaluated exactly as for a real entry, but it opens
    // a paper trade instead (one at a time) - its result decides when real trading resumes.
    // The paper trade stands for that real entry, so it must pass the same position / spread limits.
    if (streakPaused)
    {
        if (buySignal <= 0 && sellSignal <= 0) return;
        if (!IsAllowedToOpenPosition(true)) return;
        if (buySignal > sellSignal) OpenPaperTrade(1, buySignal);
        else if (sellSignal > buySignal) OpenPaperTrade(-1, sellSignal);
        return;
    }

    // Process signals
    // Fresh entries use a pending pullback limit when EnableLimitEntry is on, otherwise
    // a market order. (Virtual-SL re-entries always stay market — they exist to restore
    // exposure immediately and must not risk going unfilled. See TryVirtualSLReentry.)
    if (buySignal > sellSignal)
    {
        if (EnableLimitEntry)
            PlaceLimitEntry(ORDER_TYPE_BUY, buySignal);
        else
            OpenPosition(ORDER_TYPE_BUY, buySignal);
    }
    else if (buySignal < sellSignal)
    {
        if (EnableLimitEntry)
            PlaceLimitEntry(ORDER_TYPE_SELL, sellSignal);
        else
            OpenPosition(ORDER_TYPE_SELL, sellSignal);
    }

    // Requote / price change: nothing was opened - re-evaluate on the next ticks of this bar
    if (lastOrderRetryable && EnableNewBarEntryOnly && entryRetries < 3)
    {
        entryRetries++;
        lastEntryBarTime = 0;
    }
}

// +------------------------------------------------------------------+
// | Entry score vs. threshold - what a fresh entry is decided on     |
// | Score: closed-candle signal strength minus LosingPosScorePenalty |
// | per losing same-direction position. Threshold: the min score plus |
// | the consecutive-candle and drawdown boosts. Shared by the entry  |
// | signals and the dashboard so both show the same numbers.         |
// +------------------------------------------------------------------+
struct EntryScore
{
    SignalStrength strength;                              // closed-candle (entry mode) strength
    double score;                                         // after the losing-position penalty
    double threshold;                                     // min score + boosts
    double penalty;
    double candleBoost;
    double ddBoost;
    double ddPct;
    int candles;
    int losing;
};

void ComputeEntryScore(bool isBuy, EntryScore &e)
{
    e.strength = GetSignalStrength(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, true);
    e.score = e.strength.finalScore;
    e.threshold = isBuy ? MinBuySignalScore : MinSellSignalScore;
    e.penalty = 0; e.candleBoost = 0; e.ddBoost = 0; e.ddPct = 0; e.candles = 0; e.losing = 0;

    // CONSECUTIVE CANDLE THRESHOLD ESCALATION: when the previous candles opened positions this
    // way, raise the threshold to prevent chasing moves and opening at the peak
    int consecutive = isBuy ? consecutiveBuyCandles : consecutiveSellCandles;
    if(consecutive > 0 && ConsecutiveCandleThresholdBoost > 0)
    {
        e.candles = (MaxConsecutiveCandleBoosts > 0 && consecutive > MaxConsecutiveCandleBoosts) ? MaxConsecutiveCandleBoosts : consecutive;
        e.candleBoost = e.candles * ConsecutiveCandleThresholdBoost;
        e.threshold += e.candleBoost;
    }

    // SIGNAL DAMPENING: score penalty per losing same-direction position, higher threshold in drawdown
    if(EnableSignalDampening)
    {
        PositionLossState lossState = GetOpenPositionLossState(isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
        if(lossState.losingCount > 0)
        {
            e.losing = lossState.losingCount;
            e.penalty = lossState.losingCount * LosingPosScorePenalty;
            e.score -= e.penalty;
        }
        if(DrawdownScope == DD_SCOPE_OWN || peakEquity > 0)
        {
            e.ddPct = (DrawdownScope == DD_SCOPE_OWN) ? OwnDrawdownPct()
                                                       : ((peakEquity - AccountInfoDouble(ACCOUNT_EQUITY)) / peakEquity) * 100.0;
            if(e.ddPct >= DrawdownThresholdPct)
            {
                e.ddBoost = DrawdownScoreBoost;
                e.threshold += e.ddBoost;
            }
        }
    }
}

// Entry signal for one direction: the adjusted score when it passes the entry conditions and the
// threshold, else 0
double DirectionSignal(bool isBuy)
{
    double currentPrice = SymbolInfoDouble(_Symbol, isBuy ? SYMBOL_ASK : SYMBOL_BID);
    string dirName = isBuy ? "Buy" : "Sell";

    // Check strict conditions (limits & distance) first
    if(!CheckEntryConditions(isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, currentPrice)) return 0;

    // Smoothed signal strength (entry mode: closed candles only in new-bar mode) and its adjustments
    EntryScore e;
    ComputeEntryScore(isBuy, e);

    // DEAD-MARKET BLOCK: last closed candle's ATR collapsed below MinVolRatioToTrade
    if(e.strength.deadMarket) return 0;

    if(e.candleBoost > 0)
        LogPrint("[CANDLE ESCALATION] ", dirName, " threshold boosted by ", DoubleToString(e.candleBoost, 1),
                 " (", e.candles, " consecutive trading candles). Threshold: ", DoubleToString(e.threshold, 1));
    if(e.penalty > 0)
        LogPrint("[DAMPENED] ", dirName, " score reduced by ", DoubleToString(e.penalty, 1),
                 " (", e.losing, " losing ", (isBuy ? "buys" : "sells"), "). Raw: ",
                 DoubleToString(e.strength.finalScore, 1), " -> Adjusted: ", DoubleToString(e.score, 1));
    if(e.ddBoost > 0)
        LogPrint("[DRAWDOWN GATE] Equity drawdown ", DoubleToString(e.ddPct, 1), "% >= ",
                 DoubleToString(DrawdownThresholdPct, 1), "%. ", dirName, " threshold raised to ", DoubleToString(e.threshold, 1));

    if(e.score >= e.threshold)
    {
        LogPrint((isBuy ? "BUY" : "SELL"), " SIGNAL RECEIVED (Score: ", DoubleToString(e.strength.finalScore, 1),
                 " | Adjusted: ", DoubleToString(e.score, 1), " / Threshold: ", DoubleToString(e.threshold, 1), ")");
        LogPrint("Details: Body=", DoubleToString(e.strength.bodySignal, _Digits),
                 ", AvgBody=", DoubleToString(e.strength.avgBody, _Digits),
                 ", Ratio=", DoubleToString(e.strength.ratio, 2),
                 ", PenBody=", DoubleToString(e.strength.penaltyBody, 1),
                 ", PenWick=", DoubleToString(e.strength.penaltyWick, 1));
        LogPrint("Reasoning: ", e.strength.reasoning);
        LogPrint("Price: ", currentPrice);
        return e.score;
    }
    return 0;
}

double BuySignal()  { return DirectionSignal(true); }
double SellSignal() { return DirectionSignal(false); }

// +------------------------------------------------------------------+
// | Unified Entry Conditions (limits, dampening, cooldown, duplicate)|
// | Direction-driven: replaces the former CheckBuy/SellConditions    |
// | checkDuplicate = false skips only the duplicate-distance filter  |
// | (virtual-SL re-entries intentionally re-enter near the old price)|
// +------------------------------------------------------------------+
bool CheckEntryConditions(ENUM_POSITION_TYPE dir, double price, bool checkDuplicate = true)
{
    return EntryConditionsBlock(dir, price, checkDuplicate) == "";
}

// The same checks, returning "" when the direction may enter or else the reason it can't
// (shown on the dashboard, so a high score with no trade explains itself)
string EntryConditionsBlock(ENUM_POSITION_TYPE dir, double price, bool checkDuplicate = true)
{
    datetime currBarTime = iTime(_Symbol, _Period, 0);
    bool isBuy = (dir == POSITION_TYPE_BUY);
    string dirName = isBuy ? "Buy" : "Sell";

    int sameOnBar = isBuy ? buysOnCurrentBar : sellsOnCurrentBar;
    int oppOnBar  = isBuy ? sellsOnCurrentBar : buysOnCurrentBar;

    // Per-candle trade limit
    if(MaxTradesPerCandle > 0)
    {
        int onCandle = (currentBarTime == currBarTime) ? sameOnBar : 0;
        if(onCandle >= MaxTradesPerCandle)
            return StringFormat("already %d %s on this bar (max %d)", onCandle, isBuy ? "buy" : "sell", MaxTradesPerCandle);
    }

    // Prevent opposite direction trades on the same candle
    if(oppOnBar > 0)
        return "opposite trade on this bar";

    // SIGNAL DAMPENING: Hard block when too many losing same-dir positions are open
    if(EnableSignalDampening)
    {
        PositionLossState lossState = GetOpenPositionLossState(dir);
        if(lossState.losingCount >= MaxLosingPositionsSameDir)
        {
            LogPrint("[DAMPENED] ", dirName, " BLOCKED: ", lossState.losingCount,
                     " losing ", dirName, "s >= max ", MaxLosingPositionsSameDir);
            return StringFormat("%d losing %ss open (max %d)", lossState.losingCount, isBuy ? "buy" : "sell", MaxLosingPositionsSameDir);
        }
    }

    // SIGNAL DAMPENING: Cooldown after consecutive losses
    if(EnableSignalDampening && cooldownUntilBarTime > 0)
    {
        if(currBarTime < cooldownUntilBarTime)
        {
            LogPrint("[COOLDOWN] ", dirName, " BLOCKED: cooldown active until ",
                     TimeToString(cooldownUntilBarTime));
            return "loss cooldown until " + TimeToString(cooldownUntilBarTime, TIME_MINUTES);
        }
        else
        {
            cooldownUntilBarTime = 0; // Cooldown expired
        }
    }

    // Range filter (opt-in): in a sideways market the momentum score peaks exactly at the range
    // edges, so entries land at the top/bottom right before the reversal. Require the recent
    // closes to have actually travelled efficiently IN the signal direction.
    if(MinEfficiencyToTrade > 0)
    {
        double er = DirectionalEfficiency(isBuy, RangeFilterPeriod);
        if(er < MinEfficiencyToTrade)
        {
            LogPrint("[RANGE FILTER] ", dirName, " BLOCKED: efficiency ", DoubleToString(er, 2),
                     " < ", DoubleToString(MinEfficiencyToTrade, 2), " over ", RangeFilterPeriod, " bars");
            return StringFormat("range filter: efficiency %.2f < %.2f", er, MinEfficiencyToTrade);
        }
    }

    // Higher-timeframe trend filter (opt-in)
    if(!HTFTrendAllows(isBuy))
    {
        LogPrint("[HTF FILTER] ", dirName, " BLOCKED: against ", EnumToString(HTFTimeframe), " EMA", HTFEMAPeriod, " trend");
        return StringFormat("needs a %s %s (%.1f%% %s a %s EMA%d)", StringSubstr(EnumToString(HTFTimeframe), 7),
                            isBuy ? "uptrend" : "downtrend", HTFMinDistancePct, isBuy ? "above" : "below",
                            isBuy ? "rising" : "falling", HTFEMAPeriod);
    }

    // Minimum distance from every open same-direction position (duplicate signal filter)
    if(checkDuplicate)
    {
        double dupMult = isBuy ? BuyDuplicateMultiplier : SellDuplicateMultiplier;
        double minDistance = ZonePoints * PointScale() * _Point * dupMult;
        if(minDistance > 0 && NearestOpenEntryDistance(dir, price) < minDistance)
            return StringFormat("within %s of an open %s", DoubleToString(minDistance, _Digits), isBuy ? "buy" : "sell");
    }

    return "";
}

// +------------------------------------------------------------------+
// | Directional Efficiency Ratio over the last `period` CLOSED bars   |
// | net move in the given direction / total path travelled (0..1).    |
// | ~0 = sideways chop or moving the other way, ~1 = clean trend.     |
// +------------------------------------------------------------------+
double DirectionalEfficiency(bool isBuy, int period)
{
    int n = MathMax(2, period);
    double closes[];
    ArraySetAsSeries(closes, true);
    if(CopyClose(_Symbol, _Period, 1, n + 1, closes) < n + 1) return 1.0;   // no data -> don't block

    double path = 0;
    for(int k = 0; k < n; k++) path += MathAbs(closes[k] - closes[k + 1]);
    if(path <= 0) return 0;

    double net = isBuy ? (closes[0] - closes[n]) : (closes[n] - closes[0]);
    return MathMax(0.0, net) / path;
}

// +------------------------------------------------------------------+
// | Higher-Timeframe Trend Filter                                    |
// | Buy only above a rising HTF EMA, sell only below a falling one   |
// | (last CLOSED HTF bar - no repaint). Fails closed when HTF data   |
// | isn't ready so an unknown trend never lets an entry through.     |
// +------------------------------------------------------------------+
bool HTFTrendAllows(bool isBuy)
{
    if(!EnableHTFTrendFilter || htfEmaHandle == INVALID_HANDLE) return true;

    // [0] = last closed HTF bar, [slopeBars] = slopeBars closed bars before it
    int slopeBars = MathMax(1, HTFSlopeBars);
    double ema[];
    ArraySetAsSeries(ema, true);
    if(CopyBuffer(htfEmaHandle, 0, 1, slopeBars + 1, ema) < slopeBars + 1) return false;

    double htfClose = iClose(_Symbol, HTFTimeframe, 1);
    if(htfClose <= 0 || ema[0] <= 0 || ema[slopeBars] <= 0) return false;

    double dir = isBuy ? 1.0 : -1.0;

    // Basic direction: close on the trend side of a rising (buy) / falling (sell) EMA
    if(dir * (htfClose - ema[0]) <= 0 || dir * (ema[0] - ema[1]) <= 0) return false;

    // "Clear trend" options (percent of price, independent of volatility measures):
    // skip the choppy transitions where price hugs a flat EMA and the trend keeps flipping
    if(HTFMinDistancePct > 0 && dir * (htfClose - ema[0]) / ema[0] * 100.0 < HTFMinDistancePct) return false;
    if(HTFMinSlopePct > 0 && dir * (ema[0] - ema[slopeBars]) / ema[slopeBars] * 100.0 < HTFMinSlopePct) return false;

    return true;
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Manage Positions                                                 |
// +------------------------------------------------------------------+
void ManagePositions()
{   
    // Sync managed positions with broker (remove closed ones)
    SyncManagedPositions();

    // Hedge chain recovery: manage existing chains (resolve / stop / extend) and start
    // new chains for losing positions. Runs before trailing/loss management so chain
    // legs are correctly frozen/skipped by those routines.
    ManageHedgeChains();

    // Legs that left a chain (graduated / released) carry large martingale lots and were opened
    // without SL/TP: guarantee them a stop, independent of the trailing / loss-management toggles
    ProtectGraduatedHedges();

    // Checkpoint exits: virtual TP checkpoints (keep & lock, or close) and the capped loss-side skips
    ManageCheckpoints();

    // Trend-flip exit: a losing trade whose trend has turned against it is closed before its SL
    ManageTrendFlipExits();

    // Loss-streak pause: resolve the open paper trade
    ManagePaperTrade();

    // Manage trailing stops for all positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        // Manage Trailing TP & SL for all positions
        ManageTrailingTPSL(ticket);
    }

    // Manage losing positions
    ManageLosingPositions();

    // Expire / cancel stale pending limit entries (no-op when EnableLimitEntry is off)
    ManagePendingOrders();
}

// +------------------------------------------------------------------+
// | Compute Raw Score - Internal Helper                              |
// | Computes the raw signal score for a given candle index           |
// | signalIndex: 0 = current forming candle, 1+ = closed candles     |
// +------------------------------------------------------------------+
double ComputeRawScore(ENUM_ORDER_TYPE orderType, int signalIndex)
{
    SignalStrength dummy;
    return ComputeRawScore(orderType, signalIndex, dummy, false);
}

double ComputeRawScore(ENUM_ORDER_TYPE orderType, int signalIndex, SignalStrength &components, bool fillComponents)
{
    if(ScoreModel == SCORE_TREND) return ComputeTrendScore(orderType, signalIndex, components, fillComponents);

    bool isBuy = (orderType == ORDER_TYPE_BUY);
    bool isSell = (orderType == ORDER_TYPE_SELL);

    double bufEMA_Fast[], bufEMA_Slow[], bufRSI[], bufATR[];
    ArraySetAsSeries(bufEMA_Fast, true);
    ArraySetAsSeries(bufEMA_Slow, true);
    ArraySetAsSeries(bufRSI, true);
    ArraySetAsSeries(bufATR, true);

    // Copy minimal buffers
    int needed = MathMax(ImpulseLookback, MathMax(DirectionalBodyLookback, ATRAvgLookback)) + 5;
    int erBars = MathMax(2, ERPeriod);
    if(RegimeScoreMode == REGIME_EFFICIENCY_RATIO) needed = MathMax(needed, erBars + 2);

    // Fast EMA needs enough history for a multi-bar slope (SlopeLookback bars back)
    int slopeBars = (SlopeLookback < 1) ? 1 : SlopeLookback;
    int emaFastCopy = MathMax(3, slopeBars + 1);

    if(CopyBuffer(emaFastHandle, 0, signalIndex, emaFastCopy, bufEMA_Fast) < emaFastCopy) return 0;
    if(CopyBuffer(emaSlowHandle, 0, signalIndex, 3, bufEMA_Slow) < 3) return 0;
    if(CopyBuffer(rsiHandle, 0, signalIndex, 3, bufRSI) < 3) return 0;
    if(CopyBuffer(atrSignalHandle, 0, signalIndex, needed, bufATR) < needed) return 0;

    // Fetch Price Data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, _Period, signalIndex, needed, rates) < needed) return 0;

    // 1. TREND SCORE (Max 3)
    double emaFast = bufEMA_Fast[0];
    double emaSlow = bufEMA_Slow[0];
    // Multi-bar slope: compare current Fast EMA against its value SlopeLookback bars ago
    // (less whipsaw than a single-bar slope on noisy M1 data)
    double emaFastPrev = bufEMA_Fast[slopeBars];
    double trendScore = 0;

    bool trendAligned = false;
    if (isBuy) trendAligned = (emaFast > emaSlow);
    else trendAligned = (emaFast < emaSlow);
    if (trendAligned) trendScore += TrendWeight;

    bool slopeAligned = false;
    if (isBuy) slopeAligned = (emaFast > emaFastPrev);
    else slopeAligned = (emaFast < emaFastPrev);
    if (slopeAligned) trendScore += SlopeWeight;
    if(trendScore > 3.0) trendScore = 3.0;

    // 2. MOMENTUM SCORE (Max 3) + IMPULSE
    double currentBody = MathAbs(rates[0].close - rates[0].open);
    double sumBody = 0;
    int validCandles = 0;
    for(int i=1; i<=DirectionalBodyLookback && i<needed; i++)
    {
        sumBody += MathAbs(rates[i].close - rates[i].open);
        validCandles++;
    }
    double avgRecentBody = (validCandles > 0) ? sumBody / validCandles : currentBody;

    double rsi = bufRSI[0];
    double baseMomentum = 0;

    // A big candle is momentum for the side it moved: with DirectionalBodyMomentum a large bearish
    // candle no longer adds body / impulse points to the BUY score (and vice versa)
    bool candleWithTrade = isBuy ? (rates[0].close > rates[0].open) : (rates[0].close < rates[0].open);
    bool bodyCounts = (!DirectionalBodyMomentum || candleWithTrade);

    if (isBuy)
    {
        if (rsi > 50 && rsi < RSIOverbought) baseMomentum += MomentumBaseWeight;
        if (rsi > RSIMomentumBuy) baseMomentum += MomentumTriggerWeight;
        if (currentBody > avgRecentBody && bodyCounts) baseMomentum += BodyMomentumWeight;
    }
    else
    {
        if (rsi < 50 && rsi > RSIOversold) baseMomentum += MomentumBaseWeight;
        if (rsi < RSIMomentumSell) baseMomentum += MomentumTriggerWeight;
        if (currentBody > avgRecentBody && bodyCounts) baseMomentum += BodyMomentumWeight;
    }

    double momentumScore = baseMomentum;

    // IMPULSE DETECTION
    double bodyAccel = 0;
    if (avgRecentBody > 0) bodyAccel = currentBody / avgRecentBody;
    if (bodyAccel > 3.0) bodyAccel = 3.0;

    double currentRange = rates[0].high - rates[0].low;
    double sumRange = 0;
    for(int i=1; i<=DirectionalBodyLookback && i<needed; i++)
    {
        sumRange += (rates[i].high - rates[i].low);
    }
    double avgRecentRange = (validCandles > 0) ? sumRange / validCandles : currentRange;

    double rangeAccel = 0;
    if (avgRecentRange > 0) rangeAccel = currentRange / avgRecentRange;
    if (rangeAccel > 3.0) rangeAccel = 3.0;
    if (!bodyCounts) { bodyAccel = 0; rangeAccel = 0; }    // a counter-move candle is no impulse for this side

    int sameDirCount = 0;
    for(int i=0; i<ImpulseLookback && i<needed; i++)
    {
        bool candleBullish = (rates[i].close > rates[i].open);
        bool candleBearish = (rates[i].close < rates[i].open);

        if (isBuy && candleBullish) sameDirCount++;
        else if (isSell && candleBearish) sameDirCount++;
        else break;
    }
    double continuityScore = (double)sameDirCount / ImpulseLookback;
    if(continuityScore > 1.0) continuityScore = 1.0;

    double rawImpulse = (0.5 * bodyAccel + 0.3 * rangeAccel + 0.2 * continuityScore) / 2.0;
    if (rawImpulse > 1.0) rawImpulse = 1.0;
    if (rawImpulse < 0.0) rawImpulse = 0.0;

    momentumScore = momentumScore * (1.0 + ImpulseBoostWeight * rawImpulse);
    if (momentumScore > 3.0) momentumScore = 3.0;

    // 3. CHOP SCORE (Max 2)
    double currentATR = bufATR[0];
    double avgATR = 0;
    if (needed >= ATRAvgLookback) {
         double sumATR = 0;
         for(int i=0; i<ATRAvgLookback && i<needed; i++) sumATR += bufATR[i];
         avgATR = sumATR / ATRAvgLookback;
    } else {
         avgATR = currentATR;
    }

    double volRatio = 0;
    if(avgATR > 0) volRatio = currentATR / avgATR;

    // DEAD-MARKET FILTER: when ATR has collapsed relative to its average the
    // market is too quiet to scalp profitably (costs dominate). Block the signal.
    // Guard volRatio > 0 so we don't block when ATR data is unavailable.
    // GetSignalStrength zeroes the WHOLE signal when the last closed candle trips this.
    if(MinVolRatioToTrade > 0 && volRatio > 0 && volRatio < MinVolRatioToTrade)
    {
        if(fillComponents) components.deadMarket = true;
        return 0;
    }

    double chopScore = 0;
    if(RegimeScoreMode == REGIME_EFFICIENCY_RATIO)
    {
        // Directional Kaufman Efficiency Ratio: net move IN the signal direction divided by
        // the total path travelled. Unlike ATR expansion it separates a clean trend (ER near 1)
        // from a volatile whipsaw (ER near 0), and it is independent of the momentum inputs.
        double path = 0;
        for(int k = 0; k < erBars && k + 1 < needed; k++)
            path += MathAbs(rates[k].close - rates[k + 1].close);
        double net = isBuy ? (rates[0].close - rates[erBars].close)
                           : (rates[erBars].close - rates[0].close);
        double er = (path > 0) ? MathMax(0.0, net) / path : 0;

        if (er >= ERHighThreshold) chopScore = ChopScoreHigh;
        else if (er >= ERMedThreshold) chopScore = ChopScoreMed;
        else chopScore = ChopScoreLow;
    }
    else
    {
        // Legacy: ATR expansion vs its average (measures volatility, not direction)
        if (volRatio > 1.0) chopScore = ChopScoreHigh;
        else if (volRatio > 0.8) chopScore = ChopScoreMed;
        else chopScore = ChopScoreLow;
    }
    if (chopScore > 2.0) chopScore = 2.0;

    // 4. PEAK & VOLATILITY SCORES (Max 1 each)
    double volatilityScore = (volRatio > 1.2) ? VolatilityScoreHigh : VolatilityScoreLow;

    bool breakout = false;
    double localExtreme = isBuy ? rates[1].high : rates[1].low;
    for(int i=2; i<=5; i++)
    {
         if(isBuy) localExtreme = MathMax(localExtreme, rates[i].high);
         else localExtreme = MathMin(localExtreme, rates[i].low);
    }

    double peakScore = 0;
    if(isBuy && rates[0].close > localExtreme) breakout = true;
    if(isSell && rates[0].close < localExtreme) breakout = true;
    if(breakout) peakScore = PeakScoreWeight;

    // 5. WICK / REJECTION PENALTY
    double maxOpenClose = MathMax(rates[0].open, rates[0].close);
    double minOpenClose = MathMin(rates[0].open, rates[0].close);
    double upperWick = rates[0].high - maxOpenClose;
    double lowerWick = minOpenClose - rates[0].low;

    double safeBody = MathMax(currentBody, avgRecentBody * MinBodyRatio);
    double penaltyWick = 0;
    double rejection = 0;

    if (safeBody > 0)
    {
        if (isBuy) rejection = upperWick / safeBody;
        else rejection = lowerWick / safeBody;
        penaltyWick = rejection * WickRejectionWeight;
    }

    // FINAL SCORE AGGREGATION
    double rawScore = trendScore + momentumScore + chopScore + peakScore + volatilityScore;
    rawScore -= penaltyWick;

    if (rawScore < 0) rawScore = 0;
    if (rawScore > 10.0) rawScore = 10.0;

    // Fill component details for dashboard reporting
    if(fillComponents)
    {
        components.trendScore = trendScore;
        components.momentumScore = momentumScore;
        components.chopScore = chopScore;
        components.peakScore = peakScore;
        components.volatilityScore = volatilityScore;
        components.impulseStrength = rawImpulse;
        components.avgBody = avgRecentBody;
        components.bodySignal = currentBody;
        components.upperWick = upperWick;
        components.lowerWick = lowerWick;
        components.rejection = rejection;
        components.penaltyWick = penaltyWick;
    }

    return rawScore;
}

// +------------------------------------------------------------------+
// | Trend Score Model - Multi-Hour Trend Strength                    |
// | Four continuous readings of the same bar, each -1 (strong down)  |
// | to +1 (strong up), averaged into s:                             |
// |  - Range: close's position in the TrendRangeBars high-low range  |
// |  - EMA: distance from the TrendEMAPeriod EMA, in ATRs            |
// |  - Efficiency: net move / path over TrendERBars                  |
// |  - Momentum: net move over TrendROCBars, in ATRs                 |
// | Buy score = 5 + 5s, Sell score = 5 - 5s (they always sum to 10). |
// | Small price changes move it a little, never in fixed steps, and  |
// | every part is directional (no points for volatility alone).      |
// +------------------------------------------------------------------+
struct TrendReading
{
    datetime bar;
    double s;
    double range;
    double ema;
    double efficiency;
    double momentum;
    bool dead;
};
TrendReading trendCache[16];                              // closed bars never change: keep their readings
int trendCacheNext = 0;

bool ReadTrend(int signalIndex, TrendReading &r)
{
    datetime bar = iTime(_Symbol, _Period, signalIndex);
    if(bar == 0) return false;
    if(signalIndex > 0)
        for(int k = 0; k < ArraySize(trendCache); k++)
            if(trendCache[k].bar == bar) { r = trendCache[k]; return true; }

    int rangeBars = MathMax(2, TrendRangeBars);
    int erBars = MathMax(2, TrendERBars);
    int rocBars = MathMax(1, TrendROCBars);
    int closeBars = MathMax(erBars, rocBars) + 1;

    double close[], high[], low[], ema[], atr[];
    ArraySetAsSeries(close, true);
    if(CopyClose(_Symbol, _Period, signalIndex, closeBars, close) < closeBars) return false;
    if(CopyHigh(_Symbol, _Period, signalIndex, rangeBars, high) < rangeBars) return false;
    if(CopyLow(_Symbol, _Period, signalIndex, rangeBars, low) < rangeBars) return false;
    if(CopyBuffer(trendEmaHandle, 0, signalIndex, 1, ema) < 1) return false;
    if(CopyBuffer(trendAtrHandle, 0, signalIndex, 1, atr) < 1 || atr[0] <= 0) return false;

    double c = close[0];
    double hi = high[ArrayMaximum(high)];
    double lo = low[ArrayMinimum(low)];
    double path = 0;
    for(int k = 0; k < erBars; k++) path += MathAbs(close[k] - close[k + 1]);

    // Scales put a typical strong trend near +-0.8 (calibrated on XAUUSDm M5, 2024-2025)
    r.bar = bar;
    r.range = (hi > lo) ? (c - (hi + lo) / 2.0) / ((hi - lo) / 2.0) : 0;
    r.ema = MathTanh((c - ema[0]) / (4.0 * atr[0]));
    r.efficiency = (path > 0) ? MathTanh((c - close[erBars]) / path / 0.25) : 0;
    r.momentum = MathTanh((c - close[rocBars]) / (12.0 * atr[0]));
    r.s = (r.range + r.ema + r.efficiency + r.momentum) / 4.0;

    // Same dead-market gate as the legacy model (ATR collapsed vs its average)
    r.dead = false;
    if(MinVolRatioToTrade > 0)
    {
        int n = MathMax(1, ATRAvgLookback);
        double a[];
        ArraySetAsSeries(a, true);
        if(CopyBuffer(atrSignalHandle, 0, signalIndex, n, a) == n)
        {
            double sum = 0;
            for(int k = 0; k < n; k++) sum += a[k];
            double ratio = (sum > 0) ? a[0] / (sum / n) : 0;
            r.dead = (ratio > 0 && ratio < MinVolRatioToTrade);
        }
    }

    if(signalIndex > 0)
    {
        trendCache[trendCacheNext] = r;
        trendCacheNext = (trendCacheNext + 1) % ArraySize(trendCache);
    }
    return true;
}

double ComputeTrendScore(ENUM_ORDER_TYPE orderType, int signalIndex, SignalStrength &components, bool fillComponents)
{
    TrendReading r;
    if(!ReadTrend(signalIndex, r)) return 0;
    if(fillComponents)
    {
        components.trendRange = r.range;
        components.trendEma = r.ema;
        components.trendEfficiency = r.efficiency;
        components.trendMomentum = r.momentum;
        components.deadMarket = r.dead;
    }
    if(r.dead) return 0;
    double side = (orderType == ORDER_TYPE_BUY) ? 1.0 : -1.0;
    return MathMax(0.0, MathMin(10.0, 5.0 + 5.0 * side * r.s));
}

// +------------------------------------------------------------------+
// | Signal Strength Analysis - Blended Weighted Average              |
// | Combines weighted avg of N closed candles + dampened current     |
// | candle for smooth yet responsive signal scoring                  |
// | entryMode: in new-bar mode, entry decisions run on the first     |
// | tick of a bar where the forming candle is still ~empty (no body, |
// | range or breakout yet). Blending it in would only drag the score |
// | down, so entry mode scores CLOSED candles only (blend = 0).      |
// +------------------------------------------------------------------+
SignalStrength GetSignalStrength(ENUM_ORDER_TYPE orderType, bool entryMode = false, bool forceClosedOnly = false)
{
    bool closedOnly = (entryMode && EnableNewBarEntryOnly) || forceClosedOnly;
    int slot = ((orderType == ORDER_TYPE_BUY) ? 0 : 1) + (closedOnly ? 2 : 0);

    // Return cached result if already computed this tick
    if(_strengthValid[slot])
        return _strengthCache[slot];

    SignalStrength strength;
    strength.finalScore = 0;
    strength.trendScore = 0;
    strength.momentumScore = 0;
    strength.chopScore = 0;
    strength.peakScore = 0;
    strength.volatilityScore = 0;
    strength.impulseStrength = 0;
    strength.velocity = 0;
    strength.normalizedVelocity = 0;
    strength.avgBody = 0;
    strength.bodySignal = 0;
    strength.ratio = 0;
    strength.upperWick = 0;
    strength.lowerWick = 0;
    strength.rejection = 0;
    strength.penaltyBody = 0;
    strength.penaltyWick = 0;
    strength.deadMarket = false;
    strength.trendRange = 0;
    strength.trendEma = 0;
    strength.trendEfficiency = 0;
    strength.trendMomentum = 0;
    strength.reasoning = "";

    bool isBuy = (orderType == ORDER_TYPE_BUY);

    // Clamp smoothing parameters to safe ranges
    int N = SignalSmoothingCandles;
    if(N < 1) N = 1;
    if(N > 10) N = 10;
    double blend = closedOnly ? 0.0 : CurrentCandleBlend;
    if(blend < 0.0) blend = 0.0;
    if(blend > 1.0) blend = 1.0;
    
    // Step 1: Weighted average of last N closed candles (the "base")
    // Weights: candle[1] = N, candle[2] = N-1, ..., candle[N] = 1
    double weightedSum = 0;
    double weightTotal = 0;
    
    for(int i = 1; i <= N; i++)
    {
        // Fill component details on candle[1] for dashboard reporting
        double score_i = (i == 1)
            ? ComputeRawScore(orderType, i, strength, true)
            : ComputeRawScore(orderType, i);
        double weight = (double)(N - i + 1); // Linear decay
        weightedSum += score_i * weight;
        weightTotal += weight;
    }

    double baseScore = (weightTotal > 0) ? weightedSum / weightTotal : 0;

    // Step 2: Compute current candle score (dampened contribution; skipped when blend = 0)
    double currentScore = (blend > 0) ? ComputeRawScore(orderType, 0) : 0;

    // Step 3: Blend
    double finalScore = baseScore * (1.0 - blend) + currentScore * blend;

    // Note: strength.deadMarket (last closed candle too quiet) is an ENTRY gate - fresh
    // entries, re-entries and pending limits treat the signal as zero. It is deliberately not
    // folded into finalScore, which position management compares against the entry score
    // (a quiet market must not read as "signal decayed to 0%" and force exits).

    // Clamp
    if(finalScore < 0) finalScore = 0;
    if(finalScore > 10.0) finalScore = 10.0;

    strength.finalScore = finalScore;

    // VELOCITY TRACKING (informational - shown on the dashboard, not used for decisions)
    // Use smoothed scores for velocity (inherently smoother)
    double prevScore = 0;
    if (isBuy)
    {
        prevScore = lastBuySignalScorePrev;
    }
    else
    {
        prevScore = lastSellSignalScorePrev;
    }
    
    double velocity = strength.finalScore - prevScore;
    strength.velocity = velocity;
    
    // Normalized Velocity
    strength.normalizedVelocity = (velocity + VelocityWindow) / (2.0 * VelocityWindow);
    if(strength.normalizedVelocity < 0) strength.normalizedVelocity = 0;
    if(strength.normalizedVelocity > 1.0) strength.normalizedVelocity = 1.0;

    // Debug Construction
    if(ScoreModel == SCORE_TREND)
        strength.reasoning = StringFormat("Rng:%+.2f EMA:%+.2f Eff:%+.2f Mom:%+.2f | Vel:%.2f [Smooth:%d Blend:%.0f%%]%s",
            strength.trendRange, strength.trendEma, strength.trendEfficiency, strength.trendMomentum,
            strength.normalizedVelocity, N, blend * 100, strength.deadMarket ? " DEAD" : "");
    else
        strength.reasoning = StringFormat("T:%.1f M:%.1f(Imp:%.2f) C:%.1f P:%.1f V:%.1f | Vel:%.2f [Smooth:%d Blend:%.0f%%]%s",
            strength.trendScore, strength.momentumScore, strength.impulseStrength,
            strength.chopScore, strength.peakScore, strength.volatilityScore, strength.normalizedVelocity,
            N, blend * 100, strength.deadMarket ? " DEAD" : "");

    // Cache result for this tick
    _strengthCache[slot] = strength;
    _strengthValid[slot] = true;

    return strength;
}

// +------------------------------------------------------------------+
// | Evaluate Position Health - Measurement-Based Revalidation        |
// | Checks if the trade thesis is still valid                        |
// | Uses smoothed inputs + graduated trend with slope awareness      |
// +------------------------------------------------------------------+
PositionHealth EvaluatePositionHealth(
    ENUM_POSITION_TYPE posType, 
    double entryPrice,
    datetime posOpenTime,
    double emaFast, 
    double emaSlow, 
    double emaFastPrev,
    double rsi, 
    double currentATR,
    const MqlRates &rates[],
    int ratesCount)
{
    PositionHealth health;
    health.healthScore = 0;
    health.trendValid = false;
    health.momentumValid = false;
    health.adverseATR = 0;
    health.swingValid = true;
    health.inGracePeriod = false;
    health.reason = "";
    
    bool isBuy = (posType == POSITION_TYPE_BUY);
    
    // GRACE PERIOD CHECK
    // Skip health evaluation for newly opened positions
    if(HealthGraceBars > 0 && posOpenTime > 0)
    {
        int barsElapsed = iBarShift(_Symbol, _Period, posOpenTime, false);
        if(barsElapsed < HealthGraceBars)
        {
            health.healthScore = 1.0;
            health.trendValid = true;
            health.momentumValid = true;
            health.swingValid = true;
            health.inGracePeriod = true;
            health.reason = StringFormat("Grace period (%d/%d bars). ", barsElapsed, HealthGraceBars);
            return health;
        }
    }
    
    // 1. TREND ALIGNMENT (Graduated: separation + slope awareness)
    // Factors:
    //   a. EMA crossed correctly (base requirement)
    //   b. EMA separation relative to ATR (how strongly crossed)
    //   c. EMA slope direction (is fast EMA still moving favorably?)
    double trendScore = 0;
    if(isBuy)
        health.trendValid = (emaFast > emaSlow);
    else
        health.trendValid = (emaFast < emaSlow);
    
    if(health.trendValid)
    {
        // a. EMA separation: how far apart the EMAs are relative to ATR
        //    Full score at 0.5 ATR separation, scales linearly below that
        double emaSeparation = MathAbs(emaFast - emaSlow);
        double separationScore = 1.0;
        if(currentATR > 0)
        {
            separationScore = MathMin(1.0, emaSeparation / (currentATR * 0.5));
        }
        
        // b. EMA slope: is the fast EMA still moving in the favorable direction?
        //    Full score if slope is favorable, 0.7 penalty if slope is flattening/reversing
        double slopeFactor = 1.0;
        if(isBuy)
        {
            if(emaFast <= emaFastPrev) slopeFactor = 0.7; // Slope flattening or reversing
        }
        else
        {
            if(emaFast >= emaFastPrev) slopeFactor = 0.7; // Slope flattening or reversing
        }
        
        trendScore = separationScore * slopeFactor;
        
        if(slopeFactor < 1.0)
            health.reason += StringFormat("EMA slope weakening (sep=%.1f%% ATR). ", 
                currentATR > 0 ? emaSeparation / currentATR * 100 : 0);
    }
    else
    {
        trendScore = 0;
        health.reason += "Trend crossed against position. ";
    }
    
    // 2. RSI ZONE (Graduated: linear ramp from 0 to 1)
    // Uses configurable thresholds instead of hardcoded 45/55
    double rsiScore = 0;
    if(isBuy)
    {
        // Buy: RSI should be above HealthRSIBuyMin
        // Score ramps from 0 at HealthRSIBuyMin-15 to 1.0 at HealthRSIBuyMin
        double rsiFloor = HealthRSIBuyMin - 15.0;
        if(rsi >= HealthRSIBuyMin)
        {
            rsiScore = 1.0;
            health.momentumValid = true;
        }
        else if(rsi > rsiFloor)
        {
            rsiScore = (rsi - rsiFloor) / (HealthRSIBuyMin - rsiFloor);
            health.momentumValid = false;
            health.reason += StringFormat("RSI weakening (RSI=%.1f, min=%.1f). ", rsi, HealthRSIBuyMin);
        }
        else
        {
            rsiScore = 0;
            health.momentumValid = false;
            health.reason += StringFormat("RSI regime shift (RSI=%.1f, min=%.1f). ", rsi, HealthRSIBuyMin);
        }
    }
    else
    {
        // Sell: RSI should be below HealthRSISellMax
        // Score ramps from 0 at HealthRSISellMax+15 to 1.0 at HealthRSISellMax
        double rsiCeiling = HealthRSISellMax + 15.0;
        if(rsi <= HealthRSISellMax)
        {
            rsiScore = 1.0;
            health.momentumValid = true;
        }
        else if(rsi < rsiCeiling)
        {
            rsiScore = (rsiCeiling - rsi) / (rsiCeiling - HealthRSISellMax);
            health.momentumValid = false;
            health.reason += StringFormat("RSI weakening (RSI=%.1f, max=%.1f). ", rsi, HealthRSISellMax);
        }
        else
        {
            rsiScore = 0;
            health.momentumValid = false;
            health.reason += StringFormat("RSI regime shift (RSI=%.1f, max=%.1f). ", rsi, HealthRSISellMax);
        }
    }
    
    // 3. ADVERSE EXCURSION / ATR (Graduated: smooth falloff based on distance)
    double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double adverseMove = 0;
    
    if(isBuy)
        adverseMove = entryPrice - currentPrice;  // Positive = losing
    else
        adverseMove = currentPrice - entryPrice;  // Positive = losing
    
    double atrScore = 1.0;  // Default: fully healthy (not adverse)
    if(currentATR > 0 && adverseMove > 0)
    {
        health.adverseATR = adverseMove / currentATR;
        // Graduated: score drops linearly from 1.0 at 0 ATR to 0.0 at MaxAdverseATR
        atrScore = MathMax(0.0, 1.0 - (health.adverseATR / MaxAdverseATR));
        
        if(health.adverseATR > MaxAdverseATR)
            health.reason += StringFormat("Adverse excursion %.1f ATR > Max %.1f ATR. ", health.adverseATR, MaxAdverseATR);
        else if(atrScore < 0.5)
            health.reason += StringFormat("Adverse excursion %.1f ATR (score=%.2f). ", health.adverseATR, atrScore);
    }
    
    // 4. SWING LEVEL (Graduated: binary — structure IS or ISN'T broken)
    // Uses configurable lookback, excludes 2 most recent bars to avoid noise
    double swingScore = 1.0;
    int swingLookback = MathMax(5, HealthSwingLookback);  // Minimum 5 bars
    
    if(ratesCount >= swingLookback)
    {
        // Start from bar index 2 (skip 2 most recent to avoid noise)
        int startBar = MathMin(2, ratesCount - 1);
        
        if(isBuy)
        {
            // Find recent swing low — if price broke below it, structure is broken
            double swingLow = rates[startBar].low;
            for(int j = startBar + 1; j < swingLookback && j < ratesCount; j++)
                swingLow = MathMin(swingLow, rates[j].low);
            
            if(currentPrice < swingLow)
            {
                swingScore = 0;
                health.swingValid = false;
                health.reason += StringFormat("Price %.5f broke swing low %.5f (%d bars). ", currentPrice, swingLow, swingLookback);
            }
        }
        else
        {
            // Find recent swing high — if price broke above it, structure is broken
            double swingHigh = rates[startBar].high;
            for(int j = startBar + 1; j < swingLookback && j < ratesCount; j++)
                swingHigh = MathMax(swingHigh, rates[j].high);
            
            if(currentPrice > swingHigh)
            {
                swingScore = 0;
                health.swingValid = false;
                health.reason += StringFormat("Price %.5f broke swing high %.5f (%d bars). ", currentPrice, swingHigh, swingLookback);
            }
        }
    }
    
    // AGGREGATE HEALTH SCORE (Graduated, using normalized weights)
    health.healthScore = (trendScore  * normHealthTrendWeight)
                       + (rsiScore    * normHealthRSIWeight)
                       + (atrScore    * normHealthATRWeight)
                       + (swingScore  * normHealthSwingWeight);
    
    if(health.reason == "")  health.reason = "All health checks passed.";
    
    return health;
}

// +------------------------------------------------------------------+
// | Manage Losing Positions                                          |
// | Scaled Partial Close, Dynamic SL Tightening, Break-Even Lock,    |
// | Virtual SL + Re-entry                                            |
// +------------------------------------------------------------------+
void ManageLosingPositions()
{   
    if(!EnableLossManagement) return;
    
    // Cache indicator data once before the position loop
    double bufEMA_Fast[], bufEMA_Slow[], bufRSI[], bufATR[];
    ArraySetAsSeries(bufEMA_Fast, true);
    ArraySetAsSeries(bufEMA_Slow, true);
    ArraySetAsSeries(bufRSI, true);
    ArraySetAsSeries(bufATR, true);
    
    // Fetch 3 values: [0]=current, [1]=closed, [2]=prev closed (for slope)
    if(CopyBuffer(emaFastHandle, 0, 0, 3, bufEMA_Fast) < 3) return;
    if(CopyBuffer(emaSlowHandle, 0, 0, 3, bufEMA_Slow) < 3) return;
    if(CopyBuffer(rsiHandle, 0, 0, 3, bufRSI) < 3) return;
    if(CopyBuffer(atrSignalHandle, 0, 0, 3, bufATR) < 3) return;
    
    // Blend closed candle + current candle indicators (consistent with signal smoothing)
    // ATR stays on closed candle for stable volatility baseline
    double blend = CurrentCandleBlend;
    if(blend < 0.0) blend = 0.0;
    if(blend > 1.0) blend = 1.0;
    
    double emaFast = bufEMA_Fast[1] * (1.0 - blend) + bufEMA_Fast[0] * blend;
    double emaSlow = bufEMA_Slow[1] * (1.0 - blend) + bufEMA_Slow[0] * blend;
    double emaFastPrev = bufEMA_Fast[2]; // Previous closed candle (for slope detection)
    double rsi = bufRSI[1] * (1.0 - blend) + bufRSI[0] * blend;
    double currentATR = bufATR[1]; // ATR on closed candle (stable baseline)
    
    // Cache rates for swing level check
    int swingBars = MathMax(5, HealthSwingLookback);
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int ratesCopied = CopyRates(_Symbol, _Period, 1, swingBars, rates);
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        datetime posOpenTime = (datetime)PositionGetInteger(POSITION_TIME);
        double volume = PositionGetDouble(POSITION_VOLUME);
        double profit = PositionGetDouble(POSITION_PROFIT);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        
        // Get managed position data
        int posIndex = GetManagedPositionIndex(ticket);
        if(posIndex == -1)
        {
            double posEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            RegisterManagedPosition(ticket, posType, 0, posEntryPrice);
            continue;
        }

        // HEDGE CHAIN: chain logic exclusively manages legs of an active chain.
        // Skip the standard loss management (health close, partial, SL tighten, re-entry).
        if(EnableHedgeChain && managedPositions[posIndex].chainId != 0)
            continue;

        double entryPrice = managedPositions[posIndex].entryPrice;
        double initialScore = managedPositions[posIndex].signalScore;
        
        // Evaluate position health
        PositionHealth health = EvaluatePositionHealth(posType, entryPrice, posOpenTime, 
                                                       emaFast, emaSlow, emaFastPrev, rsi, currentATR, 
                                                       rates, ratesCopied);
        
        // Skip all management during grace period
        if(health.inGracePeriod) continue;
        
        // 1. BREAK-EVEN LOCK (when profit exceeds spread cost)
        if(EnableBreakEvenOnSpread && !managedPositions[posIndex].breakEvenLocked)
        {
            double spreadPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
            double spreadCost = spreadPoints * volume * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            double breakEvenTrigger = spreadCost * BreakEvenSpreadMultiplier;

            // ATR mode: lock only after a favorable move that is meaningful relative to current
            // volatility (a spread-multiple trigger fires on ordinary noise and chokes the trade)
            bool beTriggered = (profit > breakEvenTrigger);
            if(BreakEvenTriggerATR > 0 && currentATR > 0)
            {
                double favorable = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) - entryPrice
                                                                  : entryPrice - SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                beTriggered = (favorable >= BreakEvenTriggerATR * currentATR);
            }

            if(beTriggered)
            {
                // Calculate break-even SL at entry price
                double newBESL = NormalizeDouble(entryPrice, _Digits);
                
                // Validate: SL must be on the correct side
                long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                double minDist = stopLevel * _Point;
                bool canLockBE = false;
                
                if(posType == POSITION_TYPE_BUY)
                {
                    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    canLockBE = (newBESL < bid - minDist) && (currentSL == 0 || newBESL > currentSL);
                }
                else
                {
                    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    canLockBE = (newBESL > ask + minDist) && (currentSL == 0 || newBESL < currentSL);
                }
                
                if(canLockBE)
                {
                    if(ModifyPosition(ticket, newBESL, currentTP))
                    {
                        managedPositions[posIndex].breakEvenLocked = true;
                        
                        LogPrint("+-----------------------------------------+");
                        LogPrint("[BREAK-EVEN LOCKED] Ticket: ", ticket);
                        LogPrint("Profit: $", DoubleToString(profit, 2), " > Trigger: $", DoubleToString(breakEvenTrigger, 2));
                        LogPrint("SL moved to entry: ", newBESL);
                        LogPrint("+-----------------------------------------+");
                    }
                }
            }
        }
        
        // 2. SCALED PARTIAL CLOSE (signal decay based)
        if(EnablePartialClose && initialScore > 0 && managedPositions[posIndex].partialCloseLevel < 3)
        {
            // Get current signal strength for position's direction
            ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            SignalStrength currentStrength = GetSignalStrength(orderType);
            double currentScore = currentStrength.finalScore;
            double signalRatio = currentScore / initialScore;
            
            // Re-read position volume (may have changed from previous partial close)
            if(!PositionSelectByTicket(ticket)) continue;
            volume = PositionGetDouble(POSITION_VOLUME);
            
            double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            int pcLevel = managedPositions[posIndex].partialCloseLevel;

            // Levels are evaluated deepest-first and independently, so the final exit is never
            // stuck behind an earlier level. A level whose partial volume can't be executed
            // (e.g. 25% of a 0.01 lot) is marked as passed instead of blocking the levels after it.

            // Level 3: Signal drops to 25% -> close PartialClose25Pct of what is left
            // (>= 100%, or a remainder too small to keep, means a full exit)
            if(pcLevel < 3 && signalRatio <= 0.25)
            {
                double closeVol = FloorToVolumeStep(volume * PartialClose25Pct);
                bool fullExit = (PartialClose25Pct >= 0.999 || closeVol < minVol || volume - closeVol < minVol);

                LogPrint("+-----------------------------------------+");
                LogPrint("[PARTIAL CLOSE L3", fullExit ? " - FULL EXIT" : "", "] Ticket: ", ticket);
                LogPrint("Signal: ", DoubleToString(currentScore, 1), " / ",
                         DoubleToString(initialScore, 1), " (", DoubleToString(signalRatio * 100, 0), "%)");
                LogPrint("+-----------------------------------------+");

                if(fullExit)
                {
                    managedPositions[posIndex].partialCloseLevel = 3;
                    if(ClosePositionAndAccount(ticket) && EnableVirtualSLReentry)
                    {
                        // Virtual SL Re-entry after L3 full close
                        TryVirtualSLReentry(posType, initialScore,
                                            ReentryThesisHolds(posType, emaFast, emaSlow, emaFastPrev, rsi, currentATR, rates, ratesCopied));
                    }
                    continue; // Position is fully closed (do not touch posIndex again)
                }

                if(PartialClosePosition(ticket, closeVol))
                    managedPositions[posIndex].partialCloseLevel = 3;
            }
            // Level 2: Signal drops to 50% -> Close 50%
            else if(pcLevel < 2 && signalRatio <= 0.50)
            {
                double closeVol = FloorToVolumeStep(volume * PartialClose50Pct);
                double remaining = volume - closeVol;

                if(closeVol >= minVol && remaining >= minVol)
                {
                    if(PartialClosePosition(ticket, closeVol))
                    {
                        managedPositions[posIndex].partialCloseLevel = 2;
                        LogPrint("+-----------------------------------------+");
                        LogPrint("[PARTIAL CLOSE L2] Ticket: ", ticket);
                        LogPrint("Signal: ", DoubleToString(currentScore, 1), " / ",
                                 DoubleToString(initialScore, 1), " (", DoubleToString(signalRatio * 100, 0), "%)");
                        LogPrint("Closed: ", closeVol, " lots | Remaining: ", remaining, " lots");
                        LogPrint("+-----------------------------------------+");
                    }
                }
                else
                {
                    managedPositions[posIndex].partialCloseLevel = 2;
                    LogPrint("[PARTIAL CLOSE L2] Ticket ", ticket, ": volume ", volume, " too small to split - level passed");
                }
            }
            // Level 1: Signal drops to 75% -> Close 25%
            else if(pcLevel < 1 && signalRatio <= 0.75)
            {
                double closeVol = FloorToVolumeStep(volume * PartialClose75Pct);
                double remaining = volume - closeVol;

                if(closeVol >= minVol && remaining >= minVol)
                {
                    if(PartialClosePosition(ticket, closeVol))
                    {
                        managedPositions[posIndex].partialCloseLevel = 1;
                        LogPrint("+-----------------------------------------+");
                        LogPrint("[PARTIAL CLOSE L1] Ticket: ", ticket);
                        LogPrint("Signal: ", DoubleToString(currentScore, 1), " / ", DoubleToString(initialScore, 1), " (", DoubleToString(signalRatio * 100, 0), "%)");
                        LogPrint("Closed: ", closeVol, " lots | Remaining: ", remaining, " lots");
                        LogPrint("+-----------------------------------------+");
                    }
                }
                else
                {
                    managedPositions[posIndex].partialCloseLevel = 1;
                    LogPrint("[PARTIAL CLOSE L1] Ticket ", ticket, ": volume ", volume, " too small to split - level passed");
                }
            }
        }
        
        // 3. DYNAMIC SL TIGHTENING (health-based)
        if(EnableHealthSLTightening && health.healthScore < SLTightenMinHealthPct && currentATR > 0)
        {
            // Calculate tightened SL: distance shrinks proportionally with health
            // healthRatio = health / startThreshold (1.0 at threshold, 0.0 at dead)
            double healthRatio = health.healthScore / SLTightenMinHealthPct;
            if(healthRatio < 0.1) healthRatio = 0.1; // Prevent SL at entry (would be break-even)
            
            double slDistance = currentATR * SLTightenATRMultiplier * healthRatio;
            double newTightenedSL = 0;
            bool tighten = true;                          // false = no SL change; the exit checks below still run
            
            // Re-read position to ensure consistency
            if(!PositionSelectByTicket(ticket)) continue;
            currentSL = PositionGetDouble(POSITION_SL);
            currentTP = PositionGetDouble(POSITION_TP);
            
            long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDist = stopLevel * _Point;
            
            if(posType == POSITION_TYPE_BUY)
            {
                double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                newTightenedSL = NormalizeDouble(bid - slDistance, _Digits);
                
                // Respect break-even lock
                if(managedPositions[posIndex].breakEvenLocked && newTightenedSL < entryPrice)
                    newTightenedSL = NormalizeDouble(entryPrice, _Digits);
                
                // Only move SL UP (more protective)
                if(currentSL > 0 && newTightenedSL <= currentSL) tighten = false;

                // Respect minimum stop distance
                if(newTightenedSL >= bid - minDist) tighten = false;
            }
            else
            {
                double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                newTightenedSL = NormalizeDouble(ask + slDistance, _Digits);
                
                // Respect break-even lock
                if(managedPositions[posIndex].breakEvenLocked && newTightenedSL > entryPrice)
                    newTightenedSL = NormalizeDouble(entryPrice, _Digits);
                
                // Only move SL DOWN (more protective)
                if(currentSL > 0 && newTightenedSL >= currentSL) tighten = false;

                // Respect minimum stop distance
                if(newTightenedSL <= ask + minDist) tighten = false;
            }
            
            if(tighten && IsSLValid(posType, newTightenedSL))
            {
                if(ModifyPosition(ticket, newTightenedSL, currentTP))
                {
                    LogPrint("+-----------------------------------------+");
                    LogPrint("[SL TIGHTENED] Ticket: ", ticket);
                    LogPrint("Health: ", DoubleToString(health.healthScore, 2),
                             " (ratio: ", DoubleToString(healthRatio, 2), ")");
                    LogPrint("SL: ", currentSL, " -> ", newTightenedSL, 
                             " (ATR dist: ", DoubleToString(slDistance / _Point, 0), " pts)");
                    LogPrint("+-----------------------------------------+");
                }
            }
        }
        
        // 5. PROFIT OFFSET SL TIGHTENING (consecutive wins offset)
        // When consecutive winning trades close while this losing position is open,
        // reduce the max loss exposure by tightening SL proportionally
        if(EnableProfitOffsetSL && profit < 0 
           && managedPositions[posIndex].profitOffsetConsecWins >= ConsecutiveWinsRequired
           && managedPositions[posIndex].profitOffsetAccumulated >= MinOffsetProfit)
        {
            // Calculate original risk from SL
            double origSL = managedPositions[posIndex].profitOffsetOriginalSL;
            
            // Need valid original SL to calculate offset
            if(origSL > 0 && entryPrice > 0)
            {
                // Calculate value per point for this position's lot size
                double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                
                if(tickValue > 0 && tickSize > 0 && point > 0 && volume > 0)
                {
                    double normalizedTickValue = tickValue * volume;
                    double pointsPerTick = tickSize / point;
                    double valuePerPoint = normalizedTickValue / pointsPerTick;
                    
                    // Calculate original SL distance in USD
                    double origSLDistPoints = MathAbs(entryPrice - origSL) / _Point;
                    double origRiskUSD = origSLDistPoints * valuePerPoint;
                    
                    // Calculate new target risk after offset
                    double accumulatedProfit = managedPositions[posIndex].profitOffsetAccumulated;
                    double newTargetRiskUSD = origRiskUSD - accumulatedProfit;
                    
                    // Only proceed if there's meaningful reduction
                    if(newTargetRiskUSD < origRiskUSD && newTargetRiskUSD > 0)
                    {
                        // Convert new target risk back to points
                        double newSLDistPoints = newTargetRiskUSD / valuePerPoint;
                        double newSLDistPrice = newSLDistPoints * _Point;
                        
                        double newOffsetSL = 0;
                        
                        // Re-read position to ensure consistency
                        if(!PositionSelectByTicket(ticket)) continue;
                        currentSL = PositionGetDouble(POSITION_SL);
                        currentTP = PositionGetDouble(POSITION_TP);
                        
                        long offsetStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                        double offsetMinDist = offsetStopLevel * _Point;
                        
                        if(posType == POSITION_TYPE_BUY)
                        {
                            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                            newOffsetSL = NormalizeDouble(entryPrice - newSLDistPrice, _Digits);
                            
                            // Respect break-even lock
                            if(managedPositions[posIndex].breakEvenLocked && newOffsetSL < entryPrice)
                                newOffsetSL = NormalizeDouble(entryPrice, _Digits);
                            
                            // Only tighten (move SL UP), never widen
                            if(currentSL > 0 && newOffsetSL <= currentSL) 
                            {
                                // SL already tighter, skip
                            }
                            else if(newOffsetSL >= bid - offsetMinDist)
                            {
                                // Too close to price, skip
                            }
                            else if(IsSLValid(posType, newOffsetSL))
                            {
                                if(ModifyPosition(ticket, newOffsetSL, currentTP))
                                {
                                    LogPrint("+-----------------------------------------+");
                                    LogPrint("[PROFIT OFFSET SL] Ticket: ", ticket);
                                    LogPrint("Consecutive Wins: ", managedPositions[posIndex].profitOffsetConsecWins,
                                             " | Accumulated: $", DoubleToString(accumulatedProfit, 2));
                                    LogPrint("Original Risk: $", DoubleToString(origRiskUSD, 2),
                                             " -> New Max Risk: $", DoubleToString(newTargetRiskUSD, 2));
                                    LogPrint("SL: ", currentSL, " -> ", newOffsetSL);
                                    LogPrint("+-----------------------------------------+");
                                }
                            }
                        }
                        else // SELL
                        {
                            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                            newOffsetSL = NormalizeDouble(entryPrice + newSLDistPrice, _Digits);
                            
                            // Respect break-even lock
                            if(managedPositions[posIndex].breakEvenLocked && newOffsetSL > entryPrice)
                                newOffsetSL = NormalizeDouble(entryPrice, _Digits);
                            
                            // Only tighten (move SL DOWN), never widen
                            if(currentSL > 0 && newOffsetSL >= currentSL)
                            {
                                // SL already tighter, skip
                            }
                            else if(newOffsetSL <= ask + offsetMinDist)
                            {
                                // Too close to price, skip
                            }
                            else if(IsSLValid(posType, newOffsetSL))
                            {
                                if(ModifyPosition(ticket, newOffsetSL, currentTP))
                                {
                                    LogPrint("+-----------------------------------------+");
                                    LogPrint("[PROFIT OFFSET SL] Ticket: ", ticket);
                                    LogPrint("Consecutive Wins: ", managedPositions[posIndex].profitOffsetConsecWins,
                                             " | Accumulated: $", DoubleToString(accumulatedProfit, 2));
                                    LogPrint("Original Risk: $", DoubleToString(origRiskUSD, 2),
                                             " -> New Max Risk: $", DoubleToString(newTargetRiskUSD, 2));
                                    LogPrint("SL: ", currentSL, " -> ", newOffsetSL);
                                    LogPrint("+-----------------------------------------+");
                                }
                            }
                        }
                    }
                    // If newTargetRiskUSD <= 0, the accumulated profit exceeds original risk
                    // In this case, try to move SL to break-even (entry price)
                    else if(newTargetRiskUSD <= 0)
                    {
                        if(!PositionSelectByTicket(ticket)) continue;
                        currentSL = PositionGetDouble(POSITION_SL);
                        currentTP = PositionGetDouble(POSITION_TP);
                        
                        double beSL = NormalizeDouble(entryPrice, _Digits);
                        long beStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                        double beMinDist = beStopLevel * _Point;
                        bool canApplyBE = false;
                        
                        if(posType == POSITION_TYPE_BUY)
                        {
                            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                            canApplyBE = (beSL < bid - beMinDist) && (currentSL == 0 || beSL > currentSL);
                        }
                        else
                        {
                            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                            canApplyBE = (beSL > ask + beMinDist) && (currentSL == 0 || beSL < currentSL);
                        }
                        
                        if(canApplyBE && IsSLValid(posType, beSL))
                        {
                            if(ModifyPosition(ticket, beSL, currentTP))
                            {
                                managedPositions[posIndex].breakEvenLocked = true;
                                
                                LogPrint("+-----------------------------------------+");
                                LogPrint("[PROFIT OFFSET SL -> BE] Ticket: ", ticket);
                                LogPrint("Accumulated profit ($", DoubleToString(accumulatedProfit, 2), 
                                         ") >= Original risk ($", DoubleToString(origRiskUSD, 2), ")");
                                LogPrint("SL moved to break-even: ", beSL);
                                LogPrint("+-----------------------------------------+");
                            }
                        }
                    }
                }
            }
        }
        
        // 4. FULL CLOSE + VIRTUAL SL RE-ENTRY (at health threshold)
        if(health.healthScore < MinHealthScore)
        {
            LogPrint("+-----------------------------------------+");
            LogPrint("POSITION EXIT TRIGGERED (Health Decay)");
            LogPrint("Ticket: ", ticket, " | Profit: $", DoubleToString(PositionGetDouble(POSITION_PROFIT), 2));
            LogPrint("Health: ", DoubleToString(health.healthScore, 2), " / ", DoubleToString(MinHealthScore, 2));
            LogPrint("Trend: ", health.trendValid ? "OK" : "FAIL",
                     " | RSI: ", health.momentumValid ? "OK" : "FAIL",
                     " | ATR: ", DoubleToString(health.adverseATR, 1), "x",
                     " | Swing: ", health.swingValid ? "OK" : "FAIL");
            LogPrint("Reason: ", health.reason);
            LogPrint("+-----------------------------------------+");

            // Close and account for it immediately so the loss streak / cooldown already
            // includes this exit when the re-entry below is evaluated
            if(ClosePositionAndAccount(ticket) && EnableVirtualSLReentry)
            {
                // Virtual SL + Re-entry: try to re-enter at better price if signal supports it
                TryVirtualSLReentry(posType, initialScore,
                                    ReentryThesisHolds(posType, emaFast, emaSlow, emaFastPrev, rsi, currentATR, rates, ratesCopied));
            }
        }
    }
}

// +------------------------------------------------------------------+
// | Would a fresh position in this direction pass the health check?  |
// | Evaluated at the re-entry price with no grace period. Prevents    |
// | the close -> re-enter -> close churn where the signal score says  |
// | "re-enter" while the health check that just closed the position  |
// | would immediately close the re-entry again after its grace bars.  |
// +------------------------------------------------------------------+
bool ReentryThesisHolds(ENUM_POSITION_TYPE posType, double emaFast, double emaSlow, double emaFastPrev,
                        double rsi, double currentATR, const MqlRates &rates[], int ratesCount)
{
    double reentryPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    PositionHealth h = EvaluatePositionHealth(posType, reentryPrice, 0, emaFast, emaSlow, emaFastPrev,
                                              rsi, currentATR, rates, ratesCount);
    if(h.healthScore < MinHealthScore)
    {
        LogPrint("[VIRTUAL SL] Re-entry thesis fails health check (", DoubleToString(h.healthScore, 2),
                 " < ", DoubleToString(MinHealthScore, 2), "): ", h.reason);
        return false;
    }
    return true;
}

// +------------------------------------------------------------------+
// | Partial Close Position - Close a portion of position volume      |
// +------------------------------------------------------------------+
bool PartialClosePosition(ulong ticket, double closeVolume)
{
    if(!PositionSelectByTicket(ticket))
    {
        LogPrint("PartialClose: Position ", ticket, " not found");
        return false;
    }
    
    LockOrderSend(true);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.volume = NormalizeVolume(closeVolume);
    request.deviation = 10;
    request.magic = PositionGetInteger(POSITION_MAGIC);
    request.type_filling = GetFillingMode();
    request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(!OrderSend(request, result))
    {
        LogPrint("PartialClose failed for ", ticket, " Error: ", GetLastError());
        LockOrderSend(false);
        return false;
    }
    
    LogPrint("Partial close ", ticket, " | Vol: ", closeVolume, " | Retcode: ", result.retcode);
    LockOrderSend(false);
    return (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL);
}

// +------------------------------------------------------------------+
// | Virtual SL Re-entry - Re-evaluate and re-enter after exit        |
// +------------------------------------------------------------------+
void TryVirtualSLReentry(ENUM_POSITION_TYPE posType, double initialScore, bool thesisHolds)
{
    if(initialScore <= 0) return;
    if(!thesisHolds) return;  // a re-entry here would fail the health check right after its grace period

    // NEW-BAR ENTRY GATE (optional for re-entries)
    // By default re-entries fire intrabar (immediately at the better price). When
    // ReentryRespectsNewBarGate is enabled alongside EnableNewBarEntryOnly, a re-entry
    // is only allowed once per closed bar — keeping backtests free of intrabar entries.
    if(EnableNewBarEntryOnly && ReentryRespectsNewBarGate)
    {
        datetime reentryBarTime = iTime(_Symbol, _Period, 0);
        if(lastEntryBarTime == reentryBarTime) return;
    }

    // Same guards as a fresh entry - stop flags, pauses, hours, market close, spread,
    // open/losing position limits - plus the per-candle limit, opposite-candle block,
    // dampening hard block, loss cooldown and HTF filter. Only the duplicate-distance
    // filter is skipped (re-entering near the old price is the point of a re-entry).
    if(!IsAllowedToOpenPosition()) return;
    double reentryPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(!CheckEntryConditions(posType, reentryPrice, false)) return;

    // Get current signal strength for the same direction (closed candles only when the
    // re-entry is itself gated to the new bar - same reasoning as fresh entries)
    ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    SignalStrength strength = GetSignalStrength(orderType, ReentryRespectsNewBarGate);
    if(strength.deadMarket)
    {
        LogPrint("[VIRTUAL SL] No re-entry: dead market (ATR/AvgATR < ", DoubleToString(MinVolRatioToTrade, 2), ")");
        return;
    }
    
    // Check minimum re-entry threshold
    double minReentryScore = initialScore * ReentryMinSignalPct;
    
    if(strength.finalScore >= minReentryScore)
    {
        // Check direction-specific order enable
        if(posType == POSITION_TYPE_BUY && !EnableBuyOrders) return;
        if(posType == POSITION_TYPE_SELL && !EnableSellOrders) return;
        
        LogPrint("+-----------------------------------------+");
        LogPrint("[VIRTUAL SL RE-ENTRY] Re-entering ", posType == POSITION_TYPE_BUY ? "BUY" : "SELL");
        LogPrint("New Signal: ", DoubleToString(strength.finalScore, 1), 
                 " >= Min: ", DoubleToString(minReentryScore, 1),
                 " (", DoubleToString(ReentryMinSignalPct * 100, 0), "% of ", 
                 DoubleToString(initialScore, 1), ")");
        LogPrint("+-----------------------------------------+");
        
        // Open new position at current (better) price
        OpenPosition(orderType, strength.finalScore);

        // Mark this bar as consumed so the gate (and a normal entry this bar) won't double-enter
        if(EnableNewBarEntryOnly && ReentryRespectsNewBarGate)
            lastEntryBarTime = iTime(_Symbol, _Period, 0);
    }
    else
    {
        LogPrint("[VIRTUAL SL] No re-entry. Signal: ", DoubleToString(strength.finalScore, 1), " < Required: ", DoubleToString(minReentryScore, 1));
    }
}


int CountLosingPositions()
{   
    int count = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        double profit = PositionGetDouble(POSITION_PROFIT);
        
        if(profit < 0)
        {
            count++;  
        }
    }
    
    return count;
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Manage Trailing TP & SL                                          |
// | Adjusts TP/SL based on signal strength and trails price          |
// +------------------------------------------------------------------+
void ManageTrailingTPSL(ulong ticket)
{   
    if (!EnableTrailing) return;

    if(!PositionSelectByTicket(ticket)) return;

    // Get Position Details
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

    // HEDGE CHAIN: skip any leg that belongs to an active chain. The chain logic
    // (ManageHedgeChains) exclusively manages these legs (covered / roll / stop).
    if(EnableHedgeChain)
    {
        int hpi = GetManagedPositionIndex(ticket);
        if(hpi != -1 && managedPositions[hpi].chainId != 0)
            return;
    }

    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double profit = PositionGetDouble(POSITION_PROFIT);
    double volume = PositionGetDouble(POSITION_VOLUME);
    
    // Get Signal Strength (smoothed score for management)
    ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    SignalStrength currentStrength = GetSignalStrength(orderType);
    double currentScore = currentStrength.finalScore;
    
    double initialScore = 0;
    int posIndex = GetManagedPositionIndex(ticket);
    if(posIndex != -1)
    {
        initialScore = managedPositions[posIndex].signalScore;
    }
    
    // ADAPTIVE LOGIC (Delta Based)
    double tpAdjustment = 0;
    double slAdjustment = 0;
    string adaptiveReason = "Normal";

    // Calculate score delta (Current - Initial)
    // Positive delta = Signal Strengthened
    // Negative delta = Signal Weakened
    double scoreDelta = currentScore - initialScore;
    
    if(initialScore > 0)
    {
        if(EnableAdaptiveTP) 
        {
             tpAdjustment = scoreDelta * TrailingValueMultiplier;
        }
        
        if(EnableAdaptiveSL) 
        {
             slAdjustment = scoreDelta * TrailingValueMultiplier;
        }
        
        if(MathAbs(scoreDelta) > 0)
        {
            adaptiveReason = "Adaptive (Delta: " + DoubleToString(scoreDelta, 1) + ")";
        }
    }
    
    // TAKE PROFIT MANAGEMENT (Adaptive)
    // Independent R:R owns the TP target: keep it fixed at the entry-set
    // R:R level and skip adaptive recomputation so it isn't overwritten.
    double newTP = currentTP;

    // (Checkpoint mode owns the TP as a virtual checkpoint - never re-send a broker TP then.)
    if(EnableTakeProfit && !EnableRiskReward && !EnableCheckpointExit)
    {
        double effectiveTP = TPValue + tpAdjustment;
        
        // Ensure effective TP doesn't go negative or too small
        if(effectiveTP < (TrailingValueMultiplier * 0.1)) effectiveTP = TrailingValueMultiplier * 0.1;

        double tpPoints = ConvertToPoints(TPInputType, effectiveTP, volume);
        double targetTP = 0;
        
        if(posType == POSITION_TYPE_BUY) targetTP = NormalizePrice(entryPrice + tpPoints * _Point);
        else targetTP = NormalizePrice(entryPrice - tpPoints * _Point);

        // The adaptive TP may have shrunk past the price: that target is reached - take it now
        // (sending it would be rejected as an invalid stop, and block the SL update with it)
        double tpMinDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
        double closePx = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        bool tpReached = (posType == POSITION_TYPE_BUY) ? (targetTP <= closePx + tpMinDist) : (targetTP >= closePx - tpMinDist);
        if(tpReached && targetTP != currentTP)
        {
            LogPrint("[ADAPTIVE TP] Target ", targetTP, " already reached for ", ticket, " - closing");
            ClosePosition(ticket);
            return;
        }

        // Only modify if significant difference (> 1 point)
        if(MathAbs(targetTP - currentTP) > _Point)
        {
            newTP = targetTP;
        }
    }

    // TRAILING STOP MANAGEMENT
    double newSL = currentSL; // Default to current
    bool shouldModifySL = false;

    // Filter by profit threshold if enabled (only trail if profit > threshold)
    double profitThreshold = MinBreakEvenProfit * ProfitThresholdMultiplier;
    bool canTrail = (MinBreakEvenProfit <= 0 || !TrailingSLOnProfitableOnly || profit >= profitThreshold);

    // ATR mode: trailing starts only after the price has moved TrailStartATR x ATR in favor
    if(TrailStartATR > 0)
    {
        double trailAtr = GetCurrentATR();
        double favorableMove = (posType == POSITION_TYPE_BUY) ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
        if(trailAtr > 0) canTrail = canTrail && (favorableMove >= TrailStartATR * trailAtr);
    }

    if(canTrail)
    {
        // Calculate effective Trailing Distance
        double effectiveDist = TrailingDistanceValue + slAdjustment; // Adaptive TS

        // Ensure distance is safe (not negative)
        if(effectiveDist < (TrailingValueMultiplier * 0.1)) effectiveDist = TrailingValueMultiplier * 0.1;

        // Graduated hedge: trail at HedgeTrailATR x ATR (lot-independent). A large hedge
        // lot turns a small dollar-based distance into a near-zero price gap, so the stop
        // lands at market and closes instantly; an ATR distance gives it real room to run.
        double finalTrailingPoints;
        double trailingDistancePrice;
        bool useHedgeTrail = (posIndex != -1 && managedPositions[posIndex].hedgeGraduated && HedgeTrailATR > 0);
        double hedgeAtr = 0;
        if(useHedgeTrail)
        {
            double _bufATR[];
            ArraySetAsSeries(_bufATR, true);
            if(CopyBuffer(atrSignalHandle, 0, 0, 2, _bufATR) >= 2) hedgeAtr = _bufATR[1];
        }

        if(useHedgeTrail && hedgeAtr > 0)
        {
            trailingDistancePrice = HedgeTrailATR * hedgeAtr;
            finalTrailingPoints   = trailingDistancePrice / _Point;
        }
        else
        {
            finalTrailingPoints   = ConvertToPoints(TSInputType, effectiveDist, volume);
            trailingDistancePrice = finalTrailingPoints * _Point;
        }
        
        long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
        long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
        
        double minStopDistance = stopLevel * _Point;
        double minFreezeDistance = freezeLevel * _Point;
        double minDistance = MathMax(minStopDistance, minFreezeDistance);
        
        double breakEvenPrice = CalculateBreakEvenPrice(ticket, posType, entryPrice, volume);
        
        double calculatedSL = 0;

        // Buy position trailing logic
        if(posType == POSITION_TYPE_BUY)
        {
            double profitPoints = (currentPrice - entryPrice) / _Point;
            if(profitPoints >= finalTrailingPoints) // Use finalTrailingPoints check logic from original
            {
                calculatedSL = currentPrice - trailingDistancePrice;
                double maxAllowedSL = SymbolInfoDouble(_Symbol, SYMBOL_BID) - minDistance;
                
                if(calculatedSL > maxAllowedSL) calculatedSL = maxAllowedSL;
                
                // Break-even lock
                if(TrailingEnableBreakEvenLock && calculatedSL < breakEvenPrice) calculatedSL = breakEvenPrice;
                
                // Only modify if moving UP
                if(currentSL == 0 || calculatedSL > currentSL)
                {
                    if(calculatedSL < SymbolInfoDouble(_Symbol, SYMBOL_BID)) // Safety
                    {
                        newSL = calculatedSL;
                        shouldModifySL = true;
                    }
                }
            }
        }
        // Sell position trailing logic
        else
        {
            double profitPoints = (entryPrice - currentPrice) / _Point;
            if(profitPoints >= finalTrailingPoints)
            {
                calculatedSL = currentPrice + trailingDistancePrice;
                double minAllowedSL = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + minDistance;
                
                if(calculatedSL < minAllowedSL) calculatedSL = minAllowedSL;
                
                // Break-even lock
                if(TrailingEnableBreakEvenLock && calculatedSL > breakEvenPrice) calculatedSL = breakEvenPrice;
                
                // Only modify if moving DOWN
                if(currentSL == 0 || calculatedSL < currentSL)
                {
                    if(calculatedSL > SymbolInfoDouble(_Symbol, SYMBOL_ASK)) // Safety
                    {
                        newSL = calculatedSL;
                        shouldModifySL = true;
                    }
                }
            }
        }
    }

    // HEDGE RECOVERY LOCK: a graduated hedge must never give back below the recovery level
    // (profit = HedgeRecoveryPct% of the older leg's locked loss). Floor the SL at that
    // profit, independent of the trailing gate; trailing still rides the SL above it.
    if(posIndex != -1 && managedPositions[posIndex].hedgeLockProfit > 0)
    {
        double lockProfit = managedPositions[posIndex].hedgeLockProfit;
        double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        if(tv > 0 && ts > 0 && volume > 0)
        {
            double lockDist = (lockProfit / volume) * (ts / tv);   // dollars -> price distance
            double bidNow = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double askNow = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double baseSL = shouldModifySL ? newSL : currentSL;

            if(posType == POSITION_TYPE_BUY)
            {
                double lockPrice = NormalizeDouble(entryPrice + lockDist, _Digits);
                // Raise the SL up to the lock (but keep an already-better trailed SL)
                if(lockPrice > baseSL && lockPrice < bidNow)
                {
                    newSL = lockPrice;
                    shouldModifySL = true;
                }
            }
            else
            {
                double lockPrice = NormalizeDouble(entryPrice - lockDist, _Digits);
                // Cap the SL down to the lock (but keep an already-better trailed SL)
                if((baseSL == 0 || lockPrice < baseSL) && lockPrice > askNow)
                {
                    newSL = lockPrice;
                    shouldModifySL = true;
                }
            }
        }
    }

    // Skip if nothing changed
    if(!shouldModifySL && MathAbs(newTP - currentTP) < _Point) return;
    
    // Normalize
    newSL = NormalizeDouble(newSL, _Digits);
    newTP = NormalizeDouble(newTP, _Digits);
    
    // Skip if SL is visually same (if modifier flag was triggered but value didn't change enough - redundant check)
    if(shouldModifySL && MathAbs(newSL - currentSL) < _Point && MathAbs(newTP - currentTP) < _Point) return;

    // Trail in steps of at least 10% of the SL's distance from the price (min 10 points), not on
    // every new tick high - a fast market would otherwise flood the server with modify requests
    if(shouldModifySL && currentSL > 0)
    {
        double px = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double minStep = MathMax(10 * PointScale() * _Point, 0.1 * MathAbs(px - newSL));
        if(MathAbs(newSL - currentSL) < minStep)
        {
            shouldModifySL = false;
            newSL = currentSL;
            if(MathAbs(newTP - currentTP) < _Point) return;
        }
    }

    // Validate new SL
    if(shouldModifySL && !IsSLValid(posType, newSL))
    {
        LogPrint("SL invalid, skipping. Ticket: ", ticket);
        return;
    }

    LogPrint("+-----------------------------------------+");
    LogPrint("POSITION UPDATE (", adaptiveReason, ")");
    LogPrint("Ticket: ", ticket, " | Profit: $", profit);
    LogPrint("Signal: Init=", initialScore, " -> Current=", currentScore, " (Delta: ", scoreDelta, ")");
    if(shouldModifySL) LogPrint("SL: ", currentSL, " -> ", newSL, " (Dist: ", (TrailingDistanceValue + slAdjustment), ")");
    if(MathAbs(newTP - currentTP) > _Point) LogPrint("TP: ", currentTP, " -> ", newTP, " (Base+Adj: ", (TPValue + tpAdjustment), ")");
    LogPrint("+-----------------------------------------+");

    // Try to modify
    if(!ModifyPosition(ticket, newSL, newTP))
    {
        LogPrint("Modify failed. Ticket: ", ticket);
        
        // EMERGENCY CLOSE MECHANISM
        // Trigger if modification failed AND profit is substantial
        // Prevents losing substantial profit due to inability to trail
        
        // Define substantial as 3x minimum target profit. A busy / moving market (requote,
        // throttling, frozen level) is retried on the next tick instead of closing the trade.
        double minSubstantialProfit = MinBreakEvenProfit * 3.0;
        bool retryLater = IsTransientRetcode(lastModifyRetcode) || lastModifyRetcode == TRADE_RETCODE_FROZEN;

        if(MinBreakEvenProfit > 0 && profit >= minSubstantialProfit && !retryLater)
        {
            LogPrint("!! EMERGENCY CLOSE TRIGGERED !!");
            ClosePosition(ticket);
        }
    }
}
    
// +------------------------------------------------------------------+
// | Positions Management                                             |
// +------------------------------------------------------------------+
// Register managed position with initial score and entry price
void RegisterManagedPosition(ulong ticket, ENUM_POSITION_TYPE type, double signalScore, double entryPrice = 0, ulong chainId = 0, int hedgeLevel = 0, double chainAnchorLoss = 0, int cycleNum = 0)
{
    // Resize array
    ArrayResize(managedPositions, managedPositionCount + 1);

    // Fill position data
    managedPositions[managedPositionCount].ticket = ticket;
    managedPositions[managedPositionCount].type = type;
    managedPositions[managedPositionCount].signalScore = signalScore;
    managedPositions[managedPositionCount].entryPrice = entryPrice;
    managedPositions[managedPositionCount].partialCloseLevel = 0;
    managedPositions[managedPositionCount].breakEvenLocked = false;
    // Initialize profit offset SL tracking
    managedPositions[managedPositionCount].profitOffsetConsecWins = 0;
    managedPositions[managedPositionCount].profitOffsetAccumulated = 0;
    // Initialize hedge chain linkage
    managedPositions[managedPositionCount].chainId = chainId;
    managedPositions[managedPositionCount].hedgeLevel = hedgeLevel;
    managedPositions[managedPositionCount].chainAnchorLoss = chainAnchorLoss;
    managedPositions[managedPositionCount].cycleNum = cycleNum;
    managedPositions[managedPositionCount].noRehedge = false;
    managedPositions[managedPositionCount].hedgeGraduated = false;
    managedPositions[managedPositionCount].hedgeLockProfit = 0;
    // Checkpoint exit state (armed by InitCheckpoint after an entry fills)
    managedPositions[managedPositionCount].cpPrice = 0;
    managedPositions[managedPositionCount].cpStep = 0;
    managedPositions[managedPositionCount].virtSL = 0;
    managedPositions[managedPositionCount].virtStep = 0;
    managedPositions[managedPositionCount].cpSkipsLeft = 0;
    managedPositions[managedPositionCount].cpCount = 0;
    managedPositions[managedPositionCount].chainBooked = 0;
    managedPositions[managedPositionCount].cpLock = 0;
    // Capture original SL from broker if position exists
    double origSL = 0;
    if(PositionSelectByTicket(ticket)) origSL = PositionGetDouble(POSITION_SL);
    managedPositions[managedPositionCount].profitOffsetOriginalSL = origSL;

    managedPositionCount++;

    LogPrint("Registered position. Ticket: ", ticket,
             " | Type: ", EnumToString(type),
             " | Score: ", signalScore,
             " | Entry: ", entryPrice,
             " | Managed Positions: ", managedPositionCount);
}

// Remove Position from Managed Array
void RemoveManagedPosition(ulong ticket)
{
    for(int i = 0; i < managedPositionCount; i++)
    {
        if(managedPositions[i].ticket == ticket)
        {
            // Shift array elements left
            for(int j = i; j < managedPositionCount - 1; j++)
            {
                managedPositions[j] = managedPositions[j + 1];
            }

            managedPositionCount--;
            ArrayResize(managedPositions, managedPositionCount);

            LogPrint("Removed position: ", ticket,
                     " | Remaining Managed Positions: ", managedPositionCount);
            break;
        }
    }
}

// Sync Managed Positions with Broker (reconciliation fallback)
// OnTradeTransaction is the PRIMARY, event-driven close handler. This per-tick pass
// only catches closes that a transaction event might have missed (e.g. an event lost
// across a restart). Both paths funnel through ProcessClosedPosition, which is
// idempotent, so a single close is never accounted for twice.
void SyncManagedPositions()
{
    for(int i = managedPositionCount - 1; i >= 0; i--)
    {
        if(i >= managedPositionCount) continue;
        ulong closedTicket = managedPositions[i].ticket;
        if(PositionSelectByTicket(closedTicket)) continue;

        // Look up this position's own deals (any exit type and magic: SL/TP, manual, close-by)
        bool closed = false;
        if(HistorySelectByPosition(closedTicket))
        {
            for(int d = HistoryDealsTotal() - 1; d >= 0 && !closed; d--)
            {
                ulong deal = HistoryDealGetTicket(d);
                if(deal == 0) continue;
                long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
                closed = (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT);
            }
        }

        if(closed)
        {
            ProcessClosedPosition(closedTicket, 0);          // the net result is read from its deals
            continue;
        }

        // The closing deal may not be in the history yet: wait before dropping the entry unaccounted
        if(!GoneLongEnough(closedTicket)) continue;
        Print("[SYNC] Position ", closedTicket, " is gone but no closing deal was found - removed without accounting");
        RemoveManagedPosition(closedTicket);
    }
}

// Positions that disappeared without a closing deal yet: first-seen time per ticket
ulong goneTickets[];
datetime goneSince[];

bool GoneLongEnough(ulong ticket)
{
    int n = ArraySize(goneTickets);
    for(int i = 0; i < n; i++)
        if(goneTickets[i] == ticket) return (TimeCurrent() - goneSince[i] >= 60);
    if(n >= 200) { ArrayResize(goneTickets, 0); ArrayResize(goneSince, 0); n = 0; }
    ArrayResize(goneTickets, n + 1);
    ArrayResize(goneSince, n + 1);
    goneTickets[n] = ticket;
    goneSince[n] = TimeCurrent();
    return false;
}

// Net result of a whole position: all its deals (partial closes, entry + exit commission, swap, fees)
double PositionNetResult(ulong positionId, double fallback)
{
    if(!HistorySelectByPosition(positionId)) return fallback;
    double net = 0;
    bool exited = false;
    for(int d = 0; d < HistoryDealsTotal(); d++)
    {
        ulong deal = HistoryDealGetTicket(d);
        if(deal == 0) continue;
        net += HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP)
             + HistoryDealGetDouble(deal, DEAL_COMMISSION) + HistoryDealGetDouble(deal, DEAL_FEE);
        long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
        if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT) exited = true;
    }
    // Live, the exit deal can reach the history a moment after the close: until it is there,
    // the caller's estimate (the P/L at the moment of closing) is the better number
    return exited ? net : fallback;
}

// +------------------------------------------------------------------+
// | Loss-Streak Pause (LossStreakPauseCount > 0)                     |
// | Losing streaks cluster: after a loss the next trade wins less     |
// | often, i.e. the market is temporarily not suited to the signal.  |
// | After N losses in a row, real entries stop; every signal that     |
// | would have opened a trade opens a PAPER trade instead (same entry |
// | price, stop and first checkpoint / TP). Real trading resumes on   |
// | the first paper win - or when a still-open real position closes   |
// | in profit. Real and paper results feed one streak counter.        |
// +------------------------------------------------------------------+
void RecordStreakResult(bool isWin, string source)
{
    if(LossStreakPauseCount <= 0) return;

    if(isWin)
    {
        if(streakPaused)
            LogPrint("[LOSS STREAK] Win (", source, ") -> real trading RESUMED after ", streakLosses, " losses in a row");
        streakLosses = 0;
        streakPaused = false;
        paperDir = 0;
        return;
    }

    streakLosses++;
    if(!streakPaused && streakLosses >= LossStreakPauseCount)
    {
        streakPaused = true;
        LogPrint("[LOSS STREAK] ", streakLosses, " losses in a row (", source, ") -> real entries PAUSED, paper trading until a win");
        if(EnableDiscordAlerts)
            SendDiscordAlert("⏸️ LOSS STREAK PAUSE",
                             "**Instrument:** " + _Symbol + "\n**Losses in a row:** " + IntegerToString(streakLosses) +
                             "\n**Action:** New entries paused - paper trading signals until one wins", 16705372);
    }
}

// Open a paper trade for a signal that a loss-streak pause kept from trading (one at a time)
void OpenPaperTrade(int dir, double signalScore)
{
    if(paperDir != 0) return;

    double lot = CalculateDynamicLotSize(signalScore);       // same lot the real entry would use
    double slPts = GetSLPoints(lot);
    double tpPts = GetTPPoints(lot);                          // = the first checkpoint in checkpoint mode
    if(slPts <= 0) slPts = tpPts;                             // define both sides even if one is disabled
    if(tpPts <= 0) tpPts = slPts;
    if(slPts <= 0)
    {
        RecordStreakResult(true, "no SL/TP distance to paper-trade with");
        return;
    }

    paperDir    = dir;
    paperEntry  = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    paperTarget = paperEntry + dir * tpPts * _Point;
    paperStop   = paperEntry - dir * slPts * _Point;
    LogPrint("[LOSS STREAK] Paper ", (dir > 0 ? "BUY" : "SELL"), " at ", paperEntry, " (target ", paperTarget, ", stop ", paperStop, ")");
}

// Resolve the open paper trade at the prices a real position would be closed at
void ManagePaperTrade()
{
    if(paperDir == 0) return;
    double px = (paperDir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if(paperDir * (px - paperTarget) >= 0)
        RecordStreakResult(true, "paper trade hit its target");
    else if(paperDir * (px - paperStop) <= 0)
    {
        paperDir = 0;
        RecordStreakResult(false, "paper trade hit its stop");
    }
}

// +------------------------------------------------------------------+
// | Process a Fully-Closed Managed Position (idempotent)             |
// | Updates the consecutive-loss cooldown and profit-offset tracking |
// | for remaining open positions, then removes the closed position   |
// | from the managed array. Safe to call from both OnTradeTransaction |
// | (primary) and SyncManagedPositions (fallback): the index guard   |
// | ensures each close is accounted for exactly once.                |
// +------------------------------------------------------------------+
void ProcessClosedPosition(ulong closedTicket, double closedProfit)
{
    // Idempotency guard: if it is no longer tracked, this close was already handled
    if(GetManagedPositionIndex(closedTicket) == -1) return;

    // Judge the whole trade (earlier partial closes, commission at entry and exit, swap, fees),
    // not just the final closing deal. Exactly break-even counts as neither a win nor a loss.
    closedProfit = PositionNetResult(closedTicket, closedProfit);

    // LOSS-STREAK PAUSE: real results feed the same streak as paper results
    if(closedProfit != 0)
        RecordStreakResult(closedProfit > 0, StringFormat("real position %I64u closed %+.2f", closedTicket, closedProfit));

    // SIGNAL DAMPENING: Track consecutive losses for cooldown
    if(EnableSignalDampening)
    {
        if(closedProfit < 0)
        {
            consecutiveLossCount++;
            LogPrint("[LOSS TRACKER] Position ", closedTicket, " closed at loss: $",
                     DoubleToString(closedProfit, 2),
                     ". Consecutive losses: ", consecutiveLossCount);

            // Activate cooldown after the configured number of consecutive losses
            if(ConsecutiveLossesBeforeCooldown > 0 && consecutiveLossCount >= ConsecutiveLossesBeforeCooldown)
            {
                datetime currBar = iTime(_Symbol, _Period, 0);
                cooldownUntilBarTime = currBar + (ConsecutiveLossCooldownBars + 1) * PeriodSeconds(_Period);
                LogPrint("[COOLDOWN ACTIVATED] ", consecutiveLossCount,
                         " consecutive losses. No new entries until bar: ",
                         TimeToString(cooldownUntilBarTime));
            }
        }
        else if(closedProfit > 0)
        {
            if(consecutiveLossCount > 0)
            {
                LogPrint("[LOSS TRACKER] Win streak started. Reset from ",
                         consecutiveLossCount, " consecutive losses.");
            }
            consecutiveLossCount = 0; // Reset on any win
        }
    }

    // PROFIT OFFSET SL: Update tracking on all remaining open positions
    if(EnableProfitOffsetSL)
    {
        for(int p = 0; p < managedPositionCount; p++)
        {
            // Skip the position being removed (closedTicket)
            if(managedPositions[p].ticket == closedTicket) continue;

            // Only track for positions that are currently in loss
            if(!PositionSelectByTicket(managedPositions[p].ticket)) continue;
            double posProfit = PositionGetDouble(POSITION_PROFIT);
            if(posProfit >= 0) continue; // Only for losing positions

            if(closedProfit > 0)
            {
                // Winning trade: accumulate
                managedPositions[p].profitOffsetConsecWins++;
                managedPositions[p].profitOffsetAccumulated += closedProfit;

                LogPrint("[PROFIT OFFSET] Ticket ", managedPositions[p].ticket,
                         " | Win #", managedPositions[p].profitOffsetConsecWins,
                         " | +$", DoubleToString(closedProfit, 2),
                         " | Total: $", DoubleToString(managedPositions[p].profitOffsetAccumulated, 2));
            }
            else if(closedProfit < 0)
            {
                // Losing trade: reset consecutive counter and accumulated profit
                if(managedPositions[p].profitOffsetConsecWins > 0)
                {
                    LogPrint("[PROFIT OFFSET] Ticket ", managedPositions[p].ticket,
                             " | Consecutive wins reset (closed loss: $",
                             DoubleToString(closedProfit, 2), ")");
                }
                managedPositions[p].profitOffsetConsecWins = 0;
                managedPositions[p].profitOffsetAccumulated = 0;
            }
        }
    }

    RemoveManagedPosition(closedTicket);
}

// Get Managed Position by Ticket    
int GetManagedPositionIndex(ulong ticket)
{
    for(int i = 0; i < managedPositionCount; i++)
    {
        if(managedPositions[i].ticket == ticket)
        {
            return i;
        }
    }
    return -1;
}

// Distance from `price` to the nearest open managed position of this direction (DBL_MAX if none)
double NearestOpenEntryDistance(ENUM_POSITION_TYPE dir, double price)
{
    double nearest = DBL_MAX;
    for(int i = 0; i < managedPositionCount; i++)
    {
        if(managedPositions[i].type != dir) continue;
        if(!PositionSelectByTicket(managedPositions[i].ticket)) continue;
        nearest = MathMin(nearest, MathAbs(price - PositionGetDouble(POSITION_PRICE_OPEN)));
    }
    return nearest;
}

// Get Last Position Ticket by Type
// Returns the ticket of the most recently opened position
ulong GetLastPositionTicket(ENUM_POSITION_TYPE type)
{
    ulong lastTicket = 0;
    datetime lastTime = 0;

    for(int i = 0; i < managedPositionCount; i++)
    {
        ulong ticket = managedPositions[i].ticket;
        
        if(managedPositions[i].type != type) continue;

        if(PositionSelectByTicket(ticket))
        {
             datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
             if(posTime > lastTime)
             {
                 lastTime = posTime;
                 lastTicket = ticket;
             }
        }
    }
    
    return lastTicket;
}

// Open Position
void OpenPosition(ENUM_ORDER_TYPE orderType, double signalScore = 0)
{   
    if (!IsAllowedToOpenPosition()) return;

    LockOrderSend(true);

    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    // Calculate lot size based on equity drop recovery
    // This must be done BEFORE SL/TP conversion so dollar-based values are accurate
    double currentLot = CalculateDynamicLotSize(signalScore);
    
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double price = (orderType == ORDER_TYPE_BUY) ? ask : bid;
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = currentLot;
    request.type = orderType;
    request.price = price;
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = "Open Position by Nyao Scalper";
    request.type_filling = GetFillingMode();

    // Resolve SL (risk) and TP distances. Independent R:R mode overrides
    // both manual SL and manual TP; otherwise the manual settings apply.
    double slPoints = GetSLPoints(currentLot);
    if(slPoints <= 0 && (EnableStopLoss || EnableRiskReward))
    {
        LogPrint("[ENTRY SKIPPED] SL distance unavailable (ATR / tick value not ready) - not opening without a stop");
        LockOrderSend(false);
        return;
    }

    // Checkpoint loss-side skips: the broker SL sits at the hard cap (1 + skips) x SL distance,
    // the inner stops are EA-managed - so risk is sized on the full worst-case distance
    int cpSkips = CheckpointSkipsFor(slPoints);

    // Risk-based sizing: size the lot so the SL loses RiskPerTradePct of equity (skip if even the
    // minimum lot would lose more). TP is resolved afterwards because $-based TPs depend on lot.
    if(!ApplyRiskSizing(currentLot, slPoints * (1 + cpSkips)))
    {
        LockOrderSend(false);
        return;
    }
    request.volume = currentLot;
    double tpPoints = GetTPPoints(currentLot);

    // The SL the risk setting allows must be legally placeable. With an equity-based SL on a
    // small/shrinking account (or a lot bumped up by drawdown steps) it can fall inside the
    // spread + stop level: the broker rejects the order ("Invalid stops") on every bar. Widening
    // the SL would break the risk limit, so the entry is skipped instead.
    if(slPoints > 0 && !IsStopDistanceValid(slPoints))
    {
        LogPrint("[ENTRY SKIPPED] SL distance ", DoubleToString(slPoints, 0), " pts (", currentLot,
                 " lots) is inside spread + stop level - risk setting too small for this lot size");
        LockOrderSend(false);
        return;
    }

    if(slPoints > 0)
    {
        double brokerSL = slPoints * (1 + cpSkips);            // = slPoints unless checkpoint skips are on
        if(orderType == ORDER_TYPE_BUY)
            request.sl = NormalizePrice(price - (brokerSL * _Point));
        else
            request.sl = NormalizePrice(price + (brokerSL * _Point));
    }

    // Checkpoint mode keeps the TP virtual (EA-managed) - a broker TP would just close the trade
    if(tpPoints > 0 && !EnableCheckpointExit)
    {
        if(orderType == ORDER_TYPE_BUY)
            request.tp = NormalizePrice(price + (tpPoints * _Point));
        else
            request.tp = NormalizePrice(price - (tpPoints * _Point));
    }

    bool orderResult = OrderSend(request, result);
    
    if(orderResult)
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {   
            double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
            double equityDropAmount = lastPeakEquity - currentEquity;
            
            double equityDropPercentage = 0;
            if(lastPeakEquity > 0)
            {
                equityDropPercentage = (equityDropAmount / lastPeakEquity) * 100.0;
            }
            
            LogPrint("Order opened successfully. Ticket: ", result.order, 
                     ", Type: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL",
                     ", Lot Size: ", currentLot,
                     ", Signal Score: ", signalScore,
                     " (Peak: $", lastPeakEquity, 
                     ", Current: $", currentEquity,
                     ", Drop: ", equityDropPercentage, "%)");
            
            if(request.sl > 0)
            {
                LogPrint(" | SL: ", request.sl);
            }
            if(request.tp > 0)
            {
                LogPrint(" | TP: ", request.tp, EnableRiskReward ? StringFormat(" (R:R 1:%.2f)", RiskRewardRatio) : "");
            }
            
            // Register position to managed array
            ENUM_POSITION_TYPE posType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            RegisterManagedPosition(result.order, posType, signalScore, price);
            InitCheckpoint(result.order, posType, price, tpPoints, slPoints, cpSkips);
            
            // Update Candle Counters
            datetime currBarTime = iTime(_Symbol, _Period, 0);
            if(currentBarTime != currBarTime)
            {
                currentBarTime = currBarTime;
                buysOnCurrentBar = 0;
                sellsOnCurrentBar = 0;
            }
            
            if(orderType == ORDER_TYPE_BUY) buysOnCurrentBar++;
            else sellsOnCurrentBar++;
            
            // Update global last position tracking
            if(orderType == ORDER_TYPE_BUY)
            {
                lastBuyTime = TimeCurrent();
                lastBuyPrice = price;
            }
            else
            {
                lastSellTime = TimeCurrent();
                lastSellPrice = price;
            }
        }
        else
        {
            LogPrint("Order failed. Return code: ", result.retcode);
            lastOrderRetryable = IsPriceRetcode(result.retcode);
        }
    }
    else
    {
        LogPrint("OrderSend error: ", GetLastError(), " retcode ", result.retcode);
        lastOrderRetryable = IsPriceRetcode(result.retcode);
    }

    LockOrderSend(false);
}

// The price moved before the order arrived: nothing was opened, so the entry may be retried.
// (A timeout or connection error may still have filled - never resend those blindly.)
bool IsPriceRetcode(uint code)
{
    return code == TRADE_RETCODE_REQUOTE || code == TRADE_RETCODE_PRICE_CHANGED || code == TRADE_RETCODE_PRICE_OFF;
}

// Rejections worth retrying later (price moved, server busy, connection blip)
bool IsTransientRetcode(uint code)
{
    return code == TRADE_RETCODE_REQUOTE || code == TRADE_RETCODE_PRICE_CHANGED || code == TRADE_RETCODE_PRICE_OFF
        || code == TRADE_RETCODE_TIMEOUT || code == TRADE_RETCODE_CONNECTION || code == TRADE_RETCODE_TOO_MANY_REQUESTS;
}

// +------------------------------------------------------------------+
// | Compute the Lot Needed to Recover the Older Leg                   |
// | Sizes the hedge so that, after a favorable move of                |
// | HedgeRecoveryATR x ATR, its profit covers HedgeRecoveryPct% of    |
// | the older leg's loss - accounting for the older leg continuing to |
// | bleed over that same move. Money<->price uses the EA's standard   |
// | tickValue/tickSize convention.                                    |
// |   lot = p*olderLot + p*loss / (moneyGainedPerLotOverTargetMove)   |
// | Returns 0 if it cannot be computed (caller falls back).           |
// +------------------------------------------------------------------+
double ComputeRecoveryLot(double olderLot, double olderLoss, double atr)
{
    double p = HedgeRecoveryPct / 100.0;
    if(p <= 0) p = 1.0;

    double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double targetPrice = HedgeRecoveryATR * atr;       // favorable move (price units) to recover within
    if(tickValue <= 0 || tickSize <= 0 || targetPrice <= 0) return 0;

    // Money gained per 1.0 lot over the target favorable move
    double moneyPerLot = (targetPrice / tickSize) * tickValue;
    if(moneyPerLot <= 0) return 0;

    // p*olderLot outpaces the older leg's continued bleed; the second term funds the loss.
    return p * olderLot + p * olderLoss / moneyPerLot;
}

// +------------------------------------------------------------------+
// | Decide the Hedge Lot for the Next Leg                            |
// | Auto-recover sizing (default) or fixed multiplier, then clamped   |
// | to HedgeMaxLot and broker volume limits.                          |
// +------------------------------------------------------------------+
double ComputeHedgeLot(double olderLot, double olderLoss, double atr)
{
    double lot = 0;
    if(HedgeAutoLot)
        lot = ComputeRecoveryLot(olderLot, olderLoss, atr);

    // Fallback to fixed multiplier if auto-size is off or could not be computed
    if(lot <= 0)
        lot = olderLot * HedgeLotMultiplier;

    // The hedge must exceed the older leg, otherwise the opposite-direction pair has
    // no net recovery power. Use one volume step above as the hard minimum.
    double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minLot = olderLot + (stepVol > 0 ? stepVol : 0.01);
    if(lot < minLot) lot = minLot;

    if(HedgeMaxLot > 0 && lot > HedgeMaxLot) lot = HedgeMaxLot;
    // Round DOWN to the volume step so rounding can never push the leg above HedgeMaxLot;
    // 0 (= no hedge) when even that is below the broker minimum
    lot = FloorToVolumeStep(MathMin(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)));
    return (lot >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) ? lot : 0;
}

// +------------------------------------------------------------------+
// | Open One Rolling-Hedge Leg                                        |
// | Reversed market order at the pre-computed hedgeLot. Opened NAKED   |
// | (no SL/TP): chain logic closes it. Registers the leg under the    |
// | shared chainId at the given level, carrying the anchor loss        |
// | forward. Bypasses IsAllowedToOpenPosition / MaxOpenOrders.        |
// | Returns the new ticket, or 0 on failure.                          |
// +------------------------------------------------------------------+
ulong OpenChainHedge(ulong chainId, ENUM_POSITION_TYPE prevType, double hedgeLot, int newLevel, double anchorLoss, int cycleNum)
{
    LockOrderSend(true);

    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    // Reverse the previous leg's direction (chain alternates BUY/SELL)
    ENUM_ORDER_TYPE hedgeOrderType = (prevType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;

    hedgeLot = FloorToVolumeStep(hedgeLot);
    if(hedgeLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        LockOrderSend(false);
        return 0;
    }

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double price = (hedgeOrderType == ORDER_TYPE_BUY) ? ask : bid;

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = hedgeLot;
    request.type = hedgeOrderType;
    request.price = price;
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = "Hedge L" + IntegerToString(newLevel) + " by Nyao Scalper";
    request.type_filling = GetFillingMode();

    // NAKED: no SL/TP. The chain's covered / roll / stop logic closes it.

    ulong newTicket = 0;
    bool orderResult = OrderSend(request, result);
    // A partial fill, or a timeout after which the position exists anyway, is still a live leg
    bool filled = orderResult && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL);
    if(!filled && result.order != 0 && PositionSelectByTicket(result.order)) filled = true;

    if(filled)
    {
        ENUM_POSITION_TYPE hedgePosType = (hedgeOrderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        double booked = ChainBooked(chainId);
        int existing = GetManagedPositionIndex(result.order);   // a late fill may already be registered
        if(existing != -1) RemoveManagedPosition(result.order);
        RegisterManagedPosition(result.order, hedgePosType, 0, price, chainId, newLevel, anchorLoss, cycleNum);
        int ni = GetManagedPositionIndex(result.order);
        if(ni != -1) managedPositions[ni].chainBooked = booked;
        newTicket = result.order;

        LogPrint("+-----------------------------------------+");
        LogPrint("[HEDGE CHAIN] Opened hedge L", newLevel, " | Chain: ", chainId, " | Cycle: ", cycleNum);
        LogPrint("Leg ", result.order, " (", EnumToString(hedgePosType), ")",
                 " | Lot: ", hedgeLot, " | Sizing: ", (HedgeAutoLot ? "Auto-Recover" : "Fixed x" + DoubleToString(HedgeLotMultiplier, 2)));
        LogPrint("+-----------------------------------------+");
    }
    else
    {
        LogPrint("[HEDGE CHAIN] OrderSend failed. Retcode: ", result.retcode, " | Error: ", GetLastError());
    }

    LockOrderSend(false);
    return newTicket;
}

// +------------------------------------------------------------------+
// | Graduate a Leg out of Its Chain                                   |
// | Clears the chain flags so normal trailing / loss management take  |
// | over (used when a hedge has covered the loss and should be        |
// | trailed, or when only a single orphan leg remains).               |
// +------------------------------------------------------------------+
void GraduateChainLeg(ulong ticket)
{
    int idx = GetManagedPositionIndex(ticket);
    if(idx == -1) return;
    managedPositions[idx].chainId         = 0;
    managedPositions[idx].hedgeLevel      = 0;
    managedPositions[idx].chainAnchorLoss = 0;
    managedPositions[idx].cycleNum        = 0;
    managedPositions[idx].hedgeGraduated  = true;   // trail this big-lot leg with HedgeTrailATR
    managedPositions[idx].hedgeLockProfit = 0;      // caller sets a recovery floor if applicable
    managedPositions[idx].noRehedge       = true;   // never restart a chain (and its cycle limits) on it
    managedPositions[idx].chainBooked     = 0;
}

// Booked (realized) chain result carried on the legs ($, most negative wins)
double ChainBooked(ulong chainId)
{
    double booked = 0;
    for(int i = 0; i < managedPositionCount; i++)
        if(managedPositions[i].chainId == chainId) booked = MathMin(booked, managedPositions[i].chainBooked);
    return booked;
}

void SetChainBooked(ulong chainId, double booked)
{
    for(int i = 0; i < managedPositionCount; i++)
        if(managedPositions[i].chainId == chainId) managedPositions[i].chainBooked = booked;
}

// Chains whose loss stop fired: their legs are closed again on every tick until all are gone
ulong stoppingChains[];

bool IsChainStopping(ulong chainId)
{
    for(int i = 0; i < ArraySize(stoppingChains); i++) if(stoppingChains[i] == chainId) return true;
    return false;
}

void SetChainStopping(ulong chainId, bool stopping)
{
    int n = ArraySize(stoppingChains);
    for(int i = 0; i < n; i++)
    {
        if(stoppingChains[i] != chainId) continue;
        if(!stopping) { stoppingChains[i] = stoppingChains[n - 1]; ArrayResize(stoppingChains, n - 1); }
        return;
    }
    if(stopping) { ArrayResize(stoppingChains, n + 1); stoppingChains[n] = chainId; }
}

// With the hedge chain switched off nothing manages active chain legs (naked hedges, a root whose
// SL was cleared): release them so ProtectGraduatedHedges puts a stop on each one
void ReleaseOrphanChainLegs()
{
    for(int i = 0; i < managedPositionCount; i++)
        if(managedPositions[i].chainId != 0) ReleaseChainToLossMgmt(managedPositions[i].chainId);
}

// +------------------------------------------------------------------+
// | Close Every Open Leg of a Hedge Chain                            |
// +------------------------------------------------------------------+
void CloseChain(ulong chainId)
{
    for(int z = managedPositionCount - 1; z >= 0; z--)
    {
        if(managedPositions[z].chainId != chainId) continue;
        if(PositionSelectByTicket(managedPositions[z].ticket))
            ClosePosition(managedPositions[z].ticket);
    }
}

// +------------------------------------------------------------------+
// | Release an exhausted chain to adaptive loss management            |
// | When a chain can no longer expand (max cycles / lot ceiling), it  |
// | is NOT force-closed: every leg is handed back to normal trailing  |
// | + loss management and flagged noRehedge so no new chain starts on |
// | it. The legs then resolve via health close / partial / trailing,  |
// | and (being chainId 0 again) are re-covered by the basket stop.    |
// +------------------------------------------------------------------+
void ReleaseChainToLossMgmt(ulong chainId)
{
    int released = 0;
    for(int z = 0; z < managedPositionCount; z++)
    {
        if(managedPositions[z].chainId != chainId) continue;
        managedPositions[z].chainId         = 0;
        managedPositions[z].hedgeLevel      = 0;
        managedPositions[z].chainAnchorLoss = 0;
        managedPositions[z].cycleNum        = 0;
        managedPositions[z].noRehedge       = true;   // exhausted - do not hedge these again
        managedPositions[z].hedgeGraduated  = true;   // trail these big-lot legs with HedgeTrailATR
        managedPositions[z].chainBooked     = 0;
        released++;
    }
    LogPrint("[HEDGE CHAIN] Released chain ", chainId, " (", released,
             " legs) to adaptive loss management - no re-hedge.");
}

// +------------------------------------------------------------------+
// | Effective chain-loss stop ($): combines the fixed-$, %-of-equity  |
// | and x-SL caps. Returns the tightest (smallest) of whichever are   |
// | enabled, or 0 if none is set.                                     |
// +------------------------------------------------------------------+
double ChainLossStopThreshold()
{
    double caps[3];
    caps[0] = (HedgeMaxChainLossUSD > 0) ? HedgeMaxChainLossUSD : 0;
    caps[1] = (HedgeMaxChainLossPct > 0)
              ? AccountInfoDouble(ACCOUNT_EQUITY) * HedgeMaxChainLossPct / 100.0
              : 0;
    // Relative to the trade's own stop: a chain may never cost much more than the SL it replaced
    caps[2] = 0;
    double slPts = GetSLPoints(BaseLotSize);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(HedgeMaxChainLossSL > 0 && slPts > 0 && tickValue > 0 && tickSize > 0)
        caps[2] = HedgeMaxChainLossSL * (slPts * _Point / tickSize) * tickValue * BaseLotSize;

    double thr = 0;
    for(int k = 0; k < 3; k++)
        if(caps[k] > 0 && (thr == 0 || caps[k] < thr)) thr = caps[k];
    return thr;
}

// +------------------------------------------------------------------+
// | Reseed a new cycle when a roll can't proceed (cycle level limit   |
// | or lot ceiling). Closes the recovered older leg, partial-closes   |
// | the deepest hedge by HedgeCyclePartialPct%, makes the reduced      |
// | hedge the level-0 root of a NEW cycle, and opens a fresh L1 to     |
// | recover it. Returns false if the hedge can't be reduced.          |
// +------------------------------------------------------------------+
bool ReseedCycle(ulong id, ulong olderTicket, ulong hedgeTicket, double hedgeLot,
                 ENUM_POSITION_TYPE hedgeType, int cycleNum, double atr)
{
    double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

    double closeVol = FloorToVolumeStep(hedgeLot * HedgeCyclePartialPct / 100.0);
    double remaining = hedgeLot - closeVol;
    if(remaining < minL)
    {
        closeVol  = FloorToVolumeStep(hedgeLot - minL);
        remaining = hedgeLot - closeVol;
    }
    if(closeVol < minL || remaining < minL)
        return false;                                   // can't reduce meaningfully

    // Realized result of this reseed: the share of the hedge's open P/L that the partial close
    // books, plus the older leg's P/L (it is closed below). It counts toward the chain loss stop.
    double booked = ChainBooked(id);
    if(PositionSelectByTicket(hedgeTicket))
        booked += (PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP)) * closeVol / hedgeLot;
    if(olderTicket != 0 && PositionSelectByTicket(olderTicket))
        booked += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

    // 1) Partial-close the deepest hedge FIRST (shrink exposure). If it fails, leave the
    //    chain fully INTACT (older not yet closed) and bail so the caller releases both
    //    legs cleanly to loss management - never a half-dismantled chain.
    if(!PartialClosePosition(hedgeTicket, closeVol))
    {
        LogPrint("[HEDGE CHAIN RESEED] Partial close failed for ", hedgeTicket,
                 " - chain left intact, releasing to loss management.");
        return false;
    }

    // 2) Close the recovered older leg (free / near breakeven). If that fails, don't build a
    //    new cycle on top of a pair we couldn't untangle - hand both legs to loss management.
    if(olderTicket != 0 && !ClosePosition(olderTicket))
    {
        LogPrint("[HEDGE CHAIN RESEED] Closing older leg ", olderTicket,
                 " failed - releasing chain ", id, " to loss management.");
        ReleaseChainToLossMgmt(id);
        return true;
    }

    // 3) Re-read the reduced hedge -> becomes the new cycle's level-0 root
    if(!PositionSelectByTicket(hedgeTicket)) return false;
    double remLot = PositionGetDouble(POSITION_VOLUME);
    double remPL  = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
    double newAnchor = (remPL < 0) ? -remPL : 0.01;

    int idx = GetManagedPositionIndex(hedgeTicket);
    if(idx == -1) return false;
    managedPositions[idx].chainId         = hedgeTicket;   // new cycle id = this ticket
    managedPositions[idx].hedgeLevel      = 0;
    managedPositions[idx].chainAnchorLoss = newAnchor;
    managedPositions[idx].cycleNum        = cycleNum + 1;
    managedPositions[idx].chainBooked     = MathMin(0, booked);

    LogPrint("+-----------------------------------------+");
    LogPrint("[HEDGE CHAIN RESEED] New cycle ", cycleNum + 1, " | Chain ", id);
    LogPrint("Closed older ", olderTicket, "; closed ", DoubleToString(closeVol, 2),
             " of hedge ", hedgeTicket, " (remain ", DoubleToString(remLot, 2),
             ", anchor $", DoubleToString(newAnchor, 2), ")");
    LogPrint("+-----------------------------------------+");

    // 4) Open a fresh L1 hedge to recover the reduced root (within the per-leg ceiling AND
    //    the total-lots cap across all chains)
    double hLot = ComputeHedgeLot(remLot, newAnchor, atr);
    if(hLot > remLot && ChainLotsWithinCap(hLot))
        OpenChainHedge(hedgeTicket, hedgeType, hLot, 1, newAnchor, cycleNum + 1);
    else
        LogPrint("[HEDGE CHAIN RESEED] Reduced root can't be hedged within the lot ceiling / total-lots cap - holding as free leg.");

    return true;
}

// +------------------------------------------------------------------+
// | Manage Hedge Chains (Rolling Martingale Recovery)                |
// | A "chain" keeps at most TWO open legs: the OLDER leg (being       |
// | hedged) and its HEDGE (newer, larger, opposite direction).        |
// |                                                                   |
// |  - COVERED : hedge profit >= HedgeRecoveryPct% of the older leg's |
// |              current loss -> close older, trail the hedge. End.   |
// |  - ROLL    : hedge losing AND older recovered to >= roll min ->    |
// |              close older (free), open a bigger reverse hedge, up   |
// |              to HedgeCycleLevels per cycle.                        |
// |  - RESEED  : at the cycle level limit OR lot ceiling -> close      |
// |              older, partial-close the deepest hedge by             |
// |              HedgeCyclePartialPct%, start a NEW cycle from the      |
// |              reduced leg (up to HedgeMaxCycles cycles).            |
// |  - STOP    : combined chain loss >= HedgeMaxChainLoss($/%) -> close.|
// |              Evaluated first, before any roll.                     |
// |                                                                   |
// | Anything that ADDS exposure (start / roll / reseed) obeys the      |
// | fresh-entry gates (pause, news, hours, market close, leverage,     |
// | spread), HedgeMaxActiveChains and HedgeMaxTotalLots.               |
// |                                                                   |
// | WARNING: martingale - lots grow each roll; ranging markets can    |
// | compound drawdown. Bounded by cycle caps / HedgeMaxLot / total     |
// | lots / chain loss stop / MaxTotalLossPct hard stop.               |
// +------------------------------------------------------------------+
void ManageHedgeChains()
{
    if(!EnableHedgeChain)
    {
        ReleaseOrphanChainLegs();
        return;
    }

    // Current ATR (closed-candle [1] for stability, matching ManageLosingPositions)
    double bufATR[];
    ArraySetAsSeries(bufATR, true);
    if(CopyBuffer(atrSignalHandle, 0, 0, 2, bufATR) < 2) return;
    double atr = bufATR[1];
    if(atr <= 0) return;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Can the chain ADD exposure right now? (starts, rolls, reseeds). Closing actions -
    // covered, stop, release - always run regardless.
    string newRiskWhy = "";
    bool newRiskOk = IsNewRiskAllowed(newRiskWhy);

    // ---- Collect distinct chain ids currently in the managed array ----
    ulong chains[];
    int chainCount = 0;
    for(int i = 0; i < managedPositionCount; i++)
    {
        ulong id = managedPositions[i].chainId;
        if(id == 0) continue;
        bool seen = false;
        for(int k = 0; k < chainCount; k++) if(chains[k] == id) { seen = true; break; }
        if(!seen) { ArrayResize(chains, chainCount + 1); chains[chainCount++] = id; }
    }

    // ---- Phase A: manage each existing chain (rolling pair) ----
    for(int c = 0; c < chainCount; c++)
    {
        ulong id = chains[c];

        // Identify the OLDER leg (lowest level) and the HEDGE (highest level).
        ulong olderTicket = 0, hedgeTicket = 0;
        int olderLevel = INT_MAX, hedgeLevel = -1;
        double olderPL = 0, hedgePL = 0;
        double hedgeLot = 0;
        ENUM_POSITION_TYPE hedgeType = POSITION_TYPE_BUY;
        double anchorLoss = 0;
        int openLegs = 0;
        int cycleNum = 0;
        double totalPL = 0;

        for(int i = 0; i < managedPositionCount; i++)
        {
            if(managedPositions[i].chainId != id) continue;
            ulong t = managedPositions[i].ticket;
            if(!PositionSelectByTicket(t)) continue;       // leg already gone
            openLegs++;
            double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            totalPL += pl;
            int lvl = managedPositions[i].hedgeLevel;
            cycleNum = managedPositions[i].cycleNum;
            if(managedPositions[i].chainAnchorLoss > 0) anchorLoss = managedPositions[i].chainAnchorLoss;

            if(lvl < olderLevel) { olderLevel = lvl; olderTicket = t; olderPL = pl; }
            if(lvl > hedgeLevel)
            {
                hedgeLevel = lvl;
                hedgeTicket = t;
                hedgePL = pl;
                hedgeLot = PositionGetDouble(POSITION_VOLUME);
                hedgeType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            }
        }

        // No legs left: the chain is gone (also ends a stop that has closed everything)
        if(openLegs == 0) { SetChainStopping(id, false); continue; }

        // A chain whose loss stop fired keeps closing until every leg is gone (a failed close
        // must not leave a survivor that is graduated - or that seeds a new chain)
        if(IsChainStopping(id))
        {
            CloseChain(id);
            continue;
        }

        // Only one leg (orphan / transient): graduate the survivor back to normal management
        // and let the chain dissolve.
        if(openLegs == 1)
        {
            if(hedgeTicket != 0) GraduateChainLeg(hedgeTicket);
            continue;
        }

        // STOP (checked first - a hard cap must win over any roll): open loss across the chain plus
        // the loss its reseeds already booked exceeds the backstop ($ and/or % equity; the tighter
        // threshold wins) -> close all.
        double booked = ChainBooked(id);
        double stopThr = ChainLossStopThreshold();
        if(stopThr > 0 && totalPL + booked <= -stopThr)
        {
            LogPrint("+-----------------------------------------+");
            LogPrint("[HEDGE CHAIN STOPPED] Chain ", id, " | Open legs: ", openLegs);
            LogPrint("Total loss $", DoubleToString(totalPL + booked, 2), " (open $", DoubleToString(totalPL, 2),
                     ", booked $", DoubleToString(booked, 2), ") <= stop $", DoubleToString(-stopThr, 2));
            LogPrint("Closing all chain legs (loss backstop).");
            LogPrint("+-----------------------------------------+");
            SetChainStopping(id, true);
            CloseChain(id);
            continue;
        }

        // COVERED: hedge profit covers the older leg's current loss -> close older, trail hedge.
        // (Reduces risk, so it is always allowed - even while new entries are blocked.)
        if(olderPL < 0)
        {
            double olderLoss = -olderPL;
            double coverNeeded = (HedgeRecoveryPct / 100.0) * olderLoss;
            if(hedgePL >= coverNeeded)
            {
                LogPrint("+-----------------------------------------+");
                LogPrint("[HEDGE CHAIN COVERED] Chain ", id);
                LogPrint("Hedge ", hedgeTicket, " profit $", DoubleToString(hedgePL, 2),
                         " >= ", DoubleToString(HedgeRecoveryPct, 0), "% of older ", olderTicket,
                         " loss $", DoubleToString(olderLoss, 2));
                LogPrint("Closing older leg; hedge graduates and trails (SL floored at recovery).");
                LogPrint("+-----------------------------------------+");
                if(!ClosePosition(olderTicket)) continue;   // keep the pair intact; retry next tick
                GraduateChainLeg(hedgeTicket);
                // Recovery floor: keep at least coverNeeded profit locked on the hedge so the
                // pair never gives back below the HedgeRecoveryPct net. Trailing rides above it.
                int hgi = GetManagedPositionIndex(hedgeTicket);
                if(hgi != -1) managedPositions[hgi].hedgeLockProfit = coverNeeded;
                continue;
            }
        }

        // ROLL: hedge losing AND older recovered -> close older (free), open next hedge.
        if(hedgePL < 0 && olderPL >= HedgeRollMinProfit)
        {
            // A normal roll needs: room in the cycle (level cap), a strictly larger hedge
            // (per-leg ceiling) and room under the total-lots cap across all chains.
            // If any fails, reseed a new cycle instead.
            bool   levelOk = (hedgeLevel < HedgeCycleLevels);
            double newLot  = levelOk ? ComputeHedgeLot(hedgeLot, -hedgePL, atr) : 0;
            bool   lotOk   = (newLot > hedgeLot) && ChainLotsWithinCap(newLot, olderTicket);
            bool   cyclesLeft = (HedgeMaxCycles <= 0 || cycleNum + 1 < HedgeMaxCycles);

            // Rolls and reseeds ADD exposure (a new leg). Never do that while new entries are
            // blocked (news, wide spread, outside hours, near market close, pause): hold the pair
            // instead - it stays bounded by the chain loss cap and the total-loss hard stop.
            // (Releasing an exhausted chain adds nothing, so that path is never deferred.)
            bool addsRisk = (levelOk && lotOk) || (EnableHedgeCycleReset && cyclesLeft);
            if(!newRiskOk && addsRisk)
            {
                LogPrint("[HEDGE CHAIN] Chain ", id, ": roll/reseed deferred (", newRiskWhy, ") - holding pair.");
                continue;
            }

            if(levelOk && lotOk)
            {
                LogPrint("+-----------------------------------------+");
                LogPrint("[HEDGE CHAIN ROLL] Chain ", id, " | Cycle ", cycleNum);
                LogPrint("Older ", olderTicket, " recovered to $", DoubleToString(olderPL, 2),
                         "; hedge ", hedgeTicket, " losing $", DoubleToString(hedgePL, 2));
                LogPrint("Closing older; opening hedge L", hedgeLevel + 1, " (lot ",
                         DoubleToString(newLot, 2), " > ", DoubleToString(hedgeLot, 2), ").");
                LogPrint("+-----------------------------------------+");
                // Only open the bigger leg once the older one is really gone - otherwise the
                // chain would hold three legs and the pair logic would ignore the middle one.
                if(!ClosePosition(olderTicket)) continue;
                SetChainBooked(id, booked + olderPL);           // the closed older leg's result is booked
                OpenChainHedge(id, hedgeType, newLot, hedgeLevel + 1, anchorLoss, cycleNum);
                continue;
            }

            // Cannot roll within this cycle (level cap, lot ceiling or total-lots cap) -> reseed or release.
            string why = (!levelOk) ? "cycle level limit" : "lot ceiling / total-lots cap";

            if(EnableHedgeCycleReset && cyclesLeft)
            {
                LogPrint("[HEDGE CHAIN] Chain ", id, " cyc ", cycleNum, ": ", why,
                         " reached -> partial-close & reseed new cycle.");
                if(!ReseedCycle(id, olderTicket, hedgeTicket, hedgeLot, hedgeType, cycleNum, atr))
                {
                    LogPrint("[HEDGE CHAIN] Reseed failed (cannot reduce hedge) -> release to loss mgmt.");
                    ReleaseChainToLossMgmt(id);
                }
                continue;
            }
            else
            {
                // Chain exhausted (max cycles / lot ceiling with reseed off). Do NOT close:
                // hand the legs to adaptive loss management and stop hedging them.
                LogPrint("[HEDGE CHAIN EXHAUSTED] Chain ", id, " cyc ", cycleNum, ": ", why, ", ",
                         (!EnableHedgeCycleReset ? "reseed disabled" : "max cycles reached"),
                         " -> release to adaptive loss management (no re-hedge).");
                ReleaseChainToLossMgmt(id);
                continue;
            }
        }

        // Otherwise hold and wait for price to resolve the pair.
    }

    // ---- Phase B: start a new chain for a qualifying standalone losing position ----
    // Starting a chain opens a NEW, larger, naked position: it obeys the same gates as a
    // fresh entry (pause/news, hours, market close, leverage, spread) ...
    if(!newRiskOk) return;

    // ... and the concurrency cap, so a sharp reversal can't spawn a hedge for every
    // stacked position on the same tick.
    int activeChains = CountActiveChains();

    for(int i = 0; i < managedPositionCount; i++)
    {
        if(HedgeMaxActiveChains > 0 && activeChains >= HedgeMaxActiveChains) break;
        if(managedPositions[i].chainId != 0) continue;     // already in a chain
        if(managedPositions[i].noRehedge) continue;        // exhausted chain leg - left to loss mgmt

        ulong ticket = managedPositions[i].ticket;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        if(pl >= 0) continue;                              // not losing

        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double volume = PositionGetDouble(POSITION_VOLUME);
        double curTP = PositionGetDouble(POSITION_TP);
        double curSL = PositionGetDouble(POSITION_SL);

        double adverse = (posType == POSITION_TYPE_BUY) ? (entryPrice - bid) : (ask - entryPrice);
        if(adverse <= 0) continue;
        if((adverse / atr) < HedgeTriggerATR) continue;

        // ANTI-SPIKE: only hedge if the REVERSE direction's signal score confirms the move.
        // A wick/spike that crosses the ATR trigger intrabar but isn't a real reversal will
        // not have a strong opposite-direction score, so no doubled hedge is opened. If the
        // reversal is genuine the score builds up and the hedge fires on a later tick; if it
        // was a spike the position recovers and no hedge is needed.
        if(HedgeRequireSignal)
        {
            ENUM_ORDER_TYPE hedgeDir = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            double hedgeScore = GetSignalStrength(hedgeDir).finalScore;
            if(hedgeScore < HedgeMinSignalScore)
            {
                LogPrint("[HEDGE CHAIN] Skip start for ", ticket, ": reverse signal ",
                         DoubleToString(hedgeScore, 2), " < ", DoubleToString(HedgeMinSignalScore, 2),
                         " (likely spike) - waiting for confirmation.");
                continue;
            }
        }

        double anchorLoss = -pl;                           // positive loss magnitude at chain start

        // A root already at / past the chain loss stop would be stopped on the next tick: the
        // extra hedge only adds spread. Leave it to its own SL instead.
        double startStop = ChainLossStopThreshold();
        if(startStop > 0 && anchorLoss >= startStop)
        {
            managedPositions[i].noRehedge = true;
            LogPrint("[HEDGE CHAIN] Skip start for ", ticket, ": loss $", DoubleToString(anchorLoss, 2),
                     " already >= chain loss stop $", DoubleToString(startStop, 2));
            continue;
        }

        // Size the first hedge to recover the original's loss. Only start the chain if
        // that hedge can be strictly larger than the original - otherwise the pair would
        // freeze (equal opposite lots never recover). If the original is already at/above
        // HedgeMaxLot, leave it to normal loss management instead of starting a doomed chain.
        double hedgeLot = ComputeHedgeLot(volume, anchorLoss, atr);
        if(hedgeLot <= volume)
        {
            LogPrint("[HEDGE CHAIN] Skip start for ", ticket, ": hedge lot ", DoubleToString(hedgeLot, 2),
                     " not > position lot ", DoubleToString(volume, 2), " (HedgeMaxLot ",
                     DoubleToString(HedgeMaxLot, 2), "). Left to normal management.");
            continue;
        }

        // Total-lots cap across every active chain (this root joins the chains too)
        if(!ChainLotsWithinCap(volume + hedgeLot))
        {
            LogPrint("[HEDGE CHAIN] Skip start for ", ticket, ": total chain lots would exceed HedgeMaxTotalLots ",
                     DoubleToString(HedgeMaxTotalLots, 2), ". Left to normal management.");
            continue;
        }

        // Promote this position to the first leg (level 0, cycle 0) of a new chain.
        // (Must precede OpenChainHedge: the new leg's registration finds its root by chainId.)
        ManagedPosition before = managedPositions[i];      // restored in full if the hedge fails
        managedPositions[i].chainId         = ticket;
        managedPositions[i].hedgeLevel      = 0;
        managedPositions[i].chainAnchorLoss = anchorLoss;
        managedPositions[i].cycleNum        = 0;
        managedPositions[i].hedgeGraduated  = false;   // active chain leg again, not a graduated trailer
        managedPositions[i].hedgeLockProfit = 0;
        managedPositions[i].cpPrice         = 0;       // the chain owns this position now - drop checkpoint exits
        managedPositions[i].virtSL          = 0;

        LogPrint("+-----------------------------------------+");
        LogPrint("[HEDGE CHAIN STARTED] First leg ", ticket, " (", EnumToString(posType), ")");
        LogPrint("Start loss: $", DoubleToString(anchorLoss, 2),
                 " | Adverse: ", DoubleToString(adverse / atr, 2), " ATR >= ", DoubleToString(HedgeTriggerATR, 2));
        LogPrint("+-----------------------------------------+");

        // Open the first hedge (level 1) against this losing position.
        if(OpenChainHedge(ticket, posType, hedgeLot, 1, anchorLoss, 0) == 0)
        {
            // Hedge not opened: undo the promotion so the position keeps its SL and stays
            // under normal management (never leave a root naked without its hedge).
            int ri = GetManagedPositionIndex(ticket);
            if(ri != -1) managedPositions[ri] = before;     // checkpoint, graduation and floor come back too
            LogPrint("[HEDGE CHAIN] Start aborted for ", ticket, ": hedge order failed - root SL kept.");
            continue;
        }

        // Clear the first position's SL only now that its hedge exists (optional).
        if(HedgeClearRootSL && curSL != 0) ModifyPosition(ticket, 0, curTP);

        activeChains++;
    }
}

// +------------------------------------------------------------------+
// | Protect Graduated / Released Hedge Legs                          |
// | Hedge legs are opened naked (no SL/TP) and the chain's root SL is |
// | cleared. When a leg leaves its chain - graduated after covering   |
// | the loss, or released when the chain is exhausted - its only      |
// | protection used to be the trailing routine (exits early when       |
// | EnableTrailing = false) and loss management (EnableLossManagement)|
// | With both off, a 0.08-0.10 lot leg could run completely unguarded.|
// | This runs every tick regardless of those toggles:                 |
// |  1. a leg without a stop gets the profile's SL distance (from     |
// |     entry, or from the current price if already past it)          |
// |  2. when EnableTrailing is off, the recovery floor and the hedge   |
// |     trailing (normally inside ManageTrailingTPSL) are applied here|
// | The stop only ever moves in the protective direction.             |
// +------------------------------------------------------------------+
void ProtectGraduatedHedges()
{
    double atr = GetCurrentATR();
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    for(int i = 0; i < managedPositionCount; i++)
    {
        if(!managedPositions[i].hedgeGraduated || managedPositions[i].chainId != 0) continue;

        ulong ticket = managedPositions[i].ticket;
        if(!PositionSelectByTicket(ticket)) continue;

        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        bool isBuy   = (type == POSITION_TYPE_BUY);
        double entry = PositionGetDouble(POSITION_PRICE_OPEN);
        double vol   = PositionGetDouble(POSITION_VOLUME);
        double sl    = PositionGetDouble(POSITION_SL);
        double tp    = PositionGetDouble(POSITION_TP);
        double price = isBuy ? bid : ask;
        double newSL = sl;

        // Distance used for the initial stop and (fallback) for trailing: the hedge trail distance
        // when set, otherwise the regular trailing distance for this lot
        double trailDist = (HedgeTrailATR > 0 && atr > 0) ? HedgeTrailATR * atr
                                                          : ConvertToPoints(TSInputType, TrailingDistanceValue, vol) * _Point;

        // 1. Never leave a hedge leg without a stop
        if(sl == 0)
        {
            double slDist = GetSLPoints(vol) * _Point;
            if(slDist <= 0) slDist = trailDist;
            if(slDist > 0)
            {
                double cand = isBuy ? entry - slDist : entry + slDist;
                if(!IsSLValid(type, cand))                         // already beyond it: cap further loss
                    cand = isBuy ? price - slDist : price + slDist;
                newSL = cand;
            }
        }

        // 2. With normal trailing off, apply the recovery floor and trail here
        if(!EnableTrailing)
        {
            double lockProfit = managedPositions[i].hedgeLockProfit;
            if(lockProfit > 0 && tickValue > 0 && tickSize > 0 && vol > 0)
            {
                double lockDist = (lockProfit / vol) * (tickSize / tickValue);
                double lockPrice = isBuy ? entry + lockDist : entry - lockDist;
                if(isBuy ? (newSL == 0 || lockPrice > newSL) : (newSL == 0 || lockPrice < newSL))
                    if(IsSLValid(type, lockPrice)) newSL = lockPrice;
            }

            double inProfit = isBuy ? price - entry : entry - price;
            if(trailDist > 0 && inProfit >= trailDist)
            {
                double cand = isBuy ? price - trailDist : price + trailDist;
                if(isBuy ? (newSL == 0 || cand > newSL) : (newSL == 0 || cand < newSL))
                    if(IsSLValid(type, cand)) newSL = cand;
            }
        }

        newSL = NormalizeDouble(newSL, _Digits);
        if(newSL != 0 && MathAbs(newSL - sl) >= _Point && IsSLValid(type, newSL))
        {
            if(ModifyPosition(ticket, newSL, tp))
                LogPrint("[HEDGE PROTECT] Leg ", ticket, " (", DoubleToString(vol, 2), " lots) SL ", sl, " -> ", newSL);
        }
    }
}

// +------------------------------------------------------------------+
// | Checkpoint Exit                                                  |
// | The TP is not sent to the broker; it becomes a checkpoint. When  |
// | price reaches it the EA re-checks the trade (HTF trend / score / |
// | both, per CheckpointHoldMode):                                    |
// |   still valid -> keep it, move the SL to lock CheckpointLockPct%  |
// |                  of the move, next checkpoint one TP-distance on  |
// |   not valid   -> close at the checkpoint                         |
// | Loss side (CheckpointMaxSkips > 0): the broker SL is placed at    |
// | the hard cap (1 + skips) x SL distance; the EA manages the inner  |
// | stops. Touching an inner stop closes the trade unless the score   |
// | still agrees AND skips remain - then the inner stop moves one SL  |
// | distance further. The worst case is always the broker hard cap,   |
// | even if the EA / terminal is offline.                             |
// +------------------------------------------------------------------+

// Loss-side skips that apply to a new entry with this SL distance
int CheckpointSkipsFor(double slPoints)
{
    if(!EnableCheckpointExit || slPoints <= 0) return 0;
    if(!EnableTakeProfit && !EnableRiskReward) return 0;       // no TP distance -> no checkpoint mode
    return MathMax(0, CheckpointMaxSkips);
}

// Arm checkpoint state for a freshly opened position
void InitCheckpoint(ulong ticket, ENUM_POSITION_TYPE type, double entryPrice, double tpPoints, double slPoints, int skips)
{
    if(!EnableCheckpointExit || tpPoints <= 0) return;
    int idx = GetManagedPositionIndex(ticket);
    if(idx == -1) return;

    double entry = PositionSelectByTicket(ticket) ? PositionGetDouble(POSITION_PRICE_OPEN) : entryPrice;
    double dir = (type == POSITION_TYPE_BUY) ? 1.0 : -1.0;

    managedPositions[idx].cpStep      = tpPoints * _Point;
    managedPositions[idx].cpPrice     = entry + dir * tpPoints * _Point;
    managedPositions[idx].cpCount     = 0;
    managedPositions[idx].virtStep    = (skips > 0) ? slPoints * _Point : 0;
    managedPositions[idx].virtSL      = (skips > 0) ? entry - dir * slPoints * _Point : 0;
    managedPositions[idx].cpSkipsLeft = skips;
}

// Does the (closed-candle) signal score still point in the position's direction?
bool CheckpointScoreAgrees(bool isBuy)
{
    double b = GetSignalStrength(ORDER_TYPE_BUY, true, true).finalScore;
    double s = GetSignalStrength(ORDER_TYPE_SELL, true, true).finalScore;
    return isBuy ? (b > s) : (s > b);
}

datetime cpRetryAfter = 0;                                // Checkpoint SL modifies wait after a failure

// Smallest-profit stop: one tick beyond the entry plus round-trip commission and any negative swap.
// The close-side price (bid for buys, ask for sells) already includes the spread paid at entry.
double MinProfitLockPrice(ulong ticket, bool isBuy, double entry)
{
    if(!PositionSelectByTicket(ticket)) return 0;
    double volume = PositionGetDouble(POSITION_VOLUME);
    double swap = PositionGetDouble(POSITION_SWAP);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickValue <= 0 || tickSize <= 0 || volume <= 0) return 0;

    double cost = GetPositionRoundTripCommission(ticket) + ((swap < 0) ? -swap : 0);
    double dist = cost / volume * (tickSize / tickValue) + tickSize;
    double lock = isBuy ? entry + dist : entry - dist;
    // Round away from the entry so rounding can never turn the lock into a loss
    lock = isBuy ? MathCeil(lock / tickSize - 1e-9) * tickSize : MathFloor(lock / tickSize + 1e-9) * tickSize;
    PositionSelectByTicket(ticket);
    return NormalizeDouble(lock, _Digits);
}

// +------------------------------------------------------------------+
// | Trend-Flip Exit (TrendFlipExitScore > 0)                         |
// | A losing trade is closed once the OPPOSITE side's closed-candle  |
// | score reaches TrendFlipExitScore: the reason for the trade is    |
// | gone, so the loss is cut instead of waiting for the full SL.     |
// | Hedge chain legs are left to the chain logic.                    |
// +------------------------------------------------------------------+
void ManageTrendFlipExits()
{
    if(TrendFlipExitScore <= 0) return;

    for(int i = managedPositionCount - 1; i >= 0; i--)
    {
        if(i >= managedPositionCount) continue;
        if(managedPositions[i].chainId != 0) continue;

        ulong ticket = managedPositions[i].ticket;
        if(!PositionSelectByTicket(ticket)) continue;
        double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        if(pl >= 0) continue;

        bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
        double against = GetSignalStrength(isBuy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY, true, true).finalScore;
        if(against < TrendFlipExitScore) continue;

        LogPrint("[TREND FLIP EXIT] ", ticket, " losing $", DoubleToString(-pl, 2), " and the opposite score is ",
                 DoubleToString(against, 2), " >= ", DoubleToString(TrendFlipExitScore, 2), " -> closing");
        ClosePositionAndAccount(ticket);
    }
}

void ManageCheckpoints()
{
    if(!EnableCheckpointExit) return;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Backwards: a close removes the entry from managedPositions
    for(int i = managedPositionCount - 1; i >= 0; i--)
    {
        if(i >= managedPositionCount) continue;
        if(managedPositions[i].chainId != 0) continue;          // active hedge legs belong to the chain logic
        if(managedPositions[i].cpPrice <= 0 && managedPositions[i].virtSL <= 0) continue;

        ulong ticket = managedPositions[i].ticket;
        if(!PositionSelectByTicket(ticket)) continue;

        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        bool isBuy   = (type == POSITION_TYPE_BUY);
        double dir   = isBuy ? 1.0 : -1.0;
        double entry = PositionGetDouble(POSITION_PRICE_OPEN);
        double sl    = PositionGetDouble(POSITION_SL);
        double tp    = PositionGetDouble(POSITION_TP);
        double price = isBuy ? bid : ask;

        // A) Loss side: EA-managed inner stop with limited skips
        double vsl = managedPositions[i].virtSL;
        if(vsl > 0 && dir * (price - vsl) <= 0)
        {
            if(managedPositions[i].cpSkipsLeft > 0 && CheckpointScoreAgrees(isBuy))
            {
                managedPositions[i].virtSL = vsl - dir * managedPositions[i].virtStep;
                managedPositions[i].cpSkipsLeft--;
                LogPrint("[CHECKPOINT] ", ticket, " inner stop ", vsl, " touched, score still agrees -> pushed to ",
                         managedPositions[i].virtSL, " (", managedPositions[i].cpSkipsLeft, " skip(s) left, hard cap ", sl, ")");
            }
            else
            {
                LogPrint("[CHECKPOINT] ", ticket, " inner stop ", vsl, " hit -> closing");
                ClosePositionAndAccount(ticket);
                continue;
            }
        }

        // B) Profit side: checkpoint reached?
        double newSL = sl;
        double cp = managedPositions[i].cpPrice;
        bool cpHeld = false, trendOk = true, scoreOk = true;
        if(cp > 0 && dir * (price - cp) >= 0)
        {
            trendOk = HTFTrendAllows(isBuy);
            scoreOk = CheckpointScoreAgrees(isBuy);
            bool hold = (CheckpointHoldMode == CP_HOLD_TREND) ? trendOk
                      : (CheckpointHoldMode == CP_HOLD_SCORE) ? scoreOk
                      : (trendOk && scoreOk);

            if(!hold)
            {
                LogPrint("[CHECKPOINT] ", ticket, " reached ", cp, " - trend ", (trendOk ? "ok" : "AGAINST"),
                         ", score ", (scoreOk ? "ok" : "AGAINST"), " -> closing");
                ClosePositionAndAccount(ticket);
                continue;
            }

            // Keep the trade: lock part of the move for every checkpoint passed, then roll the checkpoint on
            double step = managedPositions[i].cpStep;
            while(dir * (price - cp) >= 0 && step > 0)
            {
                double lock = entry + dir * (CheckpointLockPct / 100.0) * MathAbs(cp - entry);
                if(newSL == 0 || dir * (lock - newSL) > 0) newSL = lock;
                if(managedPositions[i].cpLock == 0 || dir * (lock - managedPositions[i].cpLock) > 0)
                    managedPositions[i].cpLock = lock;
                cp += dir * step;
                managedPositions[i].cpCount++;
            }
            managedPositions[i].cpPrice = cp;
            managedPositions[i].virtSL  = 0;                  // in profit now: loss-side skips no longer apply
            cpHeld = true;
        }

        // C) Optional trailing stop: follow the price at a % of the checkpoint distance once far enough in profit
        bool trailed = false;
        if(CheckpointTrailPct > 0 && managedPositions[i].cpStep > 0)
        {
            double trailDist = (CheckpointTrailPct / 100.0) * managedPositions[i].cpStep;
            bool active = (CheckpointTrailStartPct > 0) ? (dir * (price - entry) >= (CheckpointTrailStartPct / 100.0) * managedPositions[i].cpStep)
                                                        : (managedPositions[i].cpCount >= 1);
            double trail = price - dir * trailDist;
            // Move only in steps of >= 5% of the distance so a fast market doesn't flood the server with modifies
            if(active && (newSL == 0 || dir * (trail - newSL) >= MathMax(0.05 * trailDist, _Point)))
            {
                newSL = trail;
                trailed = true;
            }
        }
        // C2) Optional break-even lock: once the trade is CheckpointBreakEvenPct% of the checkpoint
        // distance in profit, the SL moves to the smallest profit (and, like every stop here, only forward)
        bool beDue = false;
        if(CheckpointBreakEvenPct > 0 && managedPositions[i].cpStep > 0
           && (sl == 0 || dir * (sl - entry) <= 0)                       // not locked in profit yet
           && dir * (price - entry) >= (CheckpointBreakEvenPct / 100.0) * managedPositions[i].cpStep)
        {
            double be = MinProfitLockPrice(ticket, isBuy, entry);
            if(be > 0 && (newSL == 0 || dir * (be - newSL) > 0))
            {
                newSL = be;
                beDue = (sl == 0 || dir * (be - sl) > _Point);
            }
        }

        // D) The lock of the last checkpoint passed stays owed until the broker has it: a rejected
        // modify (requote, busy server) is retried, and if price falls back to the lock before
        // the broker SL got there, the EA closes the trade at the lock itself
        bool lockDue = false;
        double lockLevel = managedPositions[i].cpLock;
        if(lockLevel > 0)
        {
            if(sl == 0 || dir * (lockLevel - sl) > _Point)
            {
                if(dir * (price - lockLevel) <= 0)
                {
                    LogPrint("[CHECKPOINT] ", ticket, " fell back to its lock ", lockLevel, " before the SL was set -> closing");
                    ClosePositionAndAccount(ticket);
                    continue;
                }
                if(newSL == 0 || dir * (lockLevel - newSL) > 0) newSL = lockLevel;
                lockDue = true;
            }
        }
        if(!cpHeld && !trailed && !lockDue && !beDue) continue;
        if(TimeCurrent() < cpRetryAfter) continue;              // a modify just failed: retry after a second

        newSL = NormalizePrice(newSL);
        if(newSL == sl || !IsSLValid(type, newSL)) continue;
        if(ModifyPosition(ticket, newSL, tp))
        {
            if(cpHeld)
                LogPrint("[CHECKPOINT] ", ticket, " checkpoint #", managedPositions[i].cpCount, " held (trend ",
                         (trendOk ? "ok" : "-"), ", score ", (scoreOk ? "ok" : "-"), "): SL ", sl, " -> ", newSL, ", next checkpoint ", cp);
            else
                LogPrint("[CHECKPOINT] ", ticket, " SL ", sl, " -> ", newSL);
        }
        else
            cpRetryAfter = TimeCurrent() + 1;
    }
}

// Number of distinct active hedge chains in the managed array
int CountActiveChains()
{
    ulong ids[];
    int count = 0;
    for(int i = 0; i < managedPositionCount; i++)
    {
        ulong id = managedPositions[i].chainId;
        if(id == 0) continue;
        bool seen = false;
        for(int k = 0; k < count; k++) if(ids[k] == id) { seen = true; break; }
        if(!seen) { ArrayResize(ids, count + 1); ids[count++] = id; }
    }
    // Graduated / released legs (big lots out of a former chain) still occupy a chain slot
    for(int i = 0; i < managedPositionCount; i++)
        if(managedPositions[i].chainId == 0 && managedPositions[i].hedgeGraduated
           && PositionSelectByTicket(managedPositions[i].ticket)) { count++; break; }
    return count;
}

// Open volume of every chain leg, active or graduated (optionally excluding one ticket about to be closed)
double ActiveChainLots(ulong excludeTicket = 0)
{
    double lots = 0;
    for(int i = 0; i < managedPositionCount; i++)
    {
        // Active legs, and graduated / released legs that are still open
        if(managedPositions[i].chainId == 0 && !managedPositions[i].hedgeGraduated) continue;
        if(managedPositions[i].ticket == excludeTicket) continue;
        if(PositionSelectByTicket(managedPositions[i].ticket))
            lots += PositionGetDouble(POSITION_VOLUME);
    }
    return lots;
}

// True if adding addLots keeps all active chain legs within HedgeMaxTotalLots (0 = no cap)
bool ChainLotsWithinCap(double addLots, ulong excludeTicket = 0)
{
    if(HedgeMaxTotalLots <= 0) return true;
    return (ActiveChainLots(excludeTicket) + addLots <= HedgeMaxTotalLots + 1e-8);
}

// +------------------------------------------------------------------+
// | Compute Pullback Limit Entry Price for a Direction                |
// | Honors LimitEntryAnchor:                                          |
// |   FIXED_ATR : flat depth = LimitEntryATRFraction * ATR            |
// |   EMA       : anchor at the fast EMA                              |
// |   SWING     : anchor at the recent swing low/high (structure)     |
// |   SMART     : nearer-to-price of swing/EMA                        |
// | The structural modes are capped no deeper than the ATR fraction   |
// | and always clamped to the broker stop level. Falls back to the    |
// | fixed depth when no valid level sits on the pullback side.        |
// | Returns 0 on data error.                                          |
// +------------------------------------------------------------------+
double ComputeLimitEntryPrice(ENUM_ORDER_TYPE dir, double atr)
{
    bool isBuy = (dir == ORDER_TYPE_BUY);
    double ref = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minStopDist = stopLevel * _Point;
    double maxDist = atr * LimitEntryATRFraction;          // ATR cap / fixed depth
    if(maxDist <= 0) return 0;

    double fixedDepthPrice = isBuy ? (ref - maxDist)     : (ref + maxDist);      // deepest allowed
    double minDistPrice    = isBuy ? (ref - minStopDist) : (ref + minStopDist);  // shallowest allowed

    // FIXED_ATR: flat depth, no structural anchor (clamp to broker stop level)
    if(LimitEntryAnchor == LIMIT_ANCHOR_FIXED_ATR)
    {
        double pf = isBuy ? MathMin(fixedDepthPrice, minDistPrice)
                          : MathMax(fixedDepthPrice, minDistPrice);
        return NormalizeDouble(pf, _Digits);
    }

    // Gather structural anchors on the pullback side of price
    // ("nearer to price" = max for buy, min for sell)
    double anchor = isBuy ? -DBL_MAX : DBL_MAX;
    bool haveAnchor = false;

    // Fast EMA (current value)
    if(LimitEntryAnchor == LIMIT_ANCHOR_EMA || LimitEntryAnchor == LIMIT_ANCHOR_SMART)
    {
        double bufEMA[];
        ArraySetAsSeries(bufEMA, true);
        if(CopyBuffer(emaFastHandle, 0, 0, 1, bufEMA) >= 1)
        {
            double ema = bufEMA[0];
            if(isBuy ? (ema < ref) : (ema > ref))
            {
                anchor = isBuy ? MathMax(anchor, ema) : MathMin(anchor, ema);
                haveAnchor = true;
            }
        }
    }

    // Swing level over the health swing lookback
    if(LimitEntryAnchor == LIMIT_ANCHOR_SWING || LimitEntryAnchor == LIMIT_ANCHOR_SMART)
    {
        int look = MathMax(5, HealthSwingLookback);
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        int copied = CopyRates(_Symbol, _Period, 1, look, rates);
        if(copied > 0)
        {
            double sw = isBuy ? rates[0].low : rates[0].high;
            for(int j = 1; j < copied; j++)
                sw = isBuy ? MathMin(sw, rates[j].low) : MathMax(sw, rates[j].high);
            if(isBuy ? (sw < ref) : (sw > ref))
            {
                anchor = isBuy ? MathMax(anchor, sw) : MathMin(anchor, sw);
                haveAnchor = true;
            }
        }
    }

    // No valid anchor on the pullback side -> fall back to fixed depth
    double price = haveAnchor ? anchor : fixedDepthPrice;

    // Cap: never deeper than the ATR fraction...
    price = isBuy ? MathMax(price, fixedDepthPrice) : MathMin(price, fixedDepthPrice);
    // ...and always respect the broker stop level (this bound wins)
    price = isBuy ? MathMin(price, minDistPrice) : MathMax(price, minDistPrice);

    return NormalizeDouble(price, _Digits);
}

// +------------------------------------------------------------------+
// | Place Pending Limit Entry (pullback) - fresh entries only        |
// | Used when EnableLimitEntry is on. The resulting position is       |
// | registered at FILL time via OnTradeTransaction (DEAL_ENTRY_IN);   |
// | the entry-thesis score is stashed in the order comment so it      |
// | survives until the fill. Virtual-SL re-entries never come here.   |
// +------------------------------------------------------------------+
void PlaceLimitEntry(ENUM_ORDER_TYPE dir, double signalScore)
{
    if(!IsAllowedToOpenPosition()) return;

    // One working pending at a time (one entry decision per signal)
    if(CountWorkingLimitOrders() > 0) return;

    // Current ATR drives both the fixed depth and the cap for structural anchors
    double bufATR[];
    ArraySetAsSeries(bufATR, true);
    if(CopyBuffer(atrSignalHandle, 0, 0, 1, bufATR) < 1) return;
    double atr = bufATR[0];
    if(atr <= 0) return;

    double entry = ComputeLimitEntryPrice(dir, atr);
    if(entry <= 0) return;

    double currentLot = CalculateDynamicLotSize(signalScore);
    double ref = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    LockOrderSend(true);

    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    request.action = TRADE_ACTION_PENDING;
    request.symbol = _Symbol;
    request.volume = currentLot;
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = "NyaoLE|" + DoubleToString(signalScore, 2); // stash entry-thesis score

    // Expiry is normally handled by ManagePendingOrders (bar age). As a backstop for when the
    // EA isn't running (terminal closed, VPS down), also give the order a broker-side expiry one
    // bar after the EA's own when the symbol supports it - so it can't rest and fill unmanaged.
    request.type_time = ORDER_TIME_GTC;
    if(LimitEntryExpiryBars > 0
       && (SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE) & SYMBOL_EXPIRATION_SPECIFIED) != 0)
    {
        request.type_time = ORDER_TIME_SPECIFIED;
        request.expiration = TimeCurrent() + (LimitEntryExpiryBars + 1) * PeriodSeconds(_Period);
    }
    entry = NormalizePrice(entry);
    request.price = entry;

    double slPts = GetSLPoints(currentLot);
    if(slPts <= 0 && (EnableStopLoss || EnableRiskReward))
    {
        LogPrint("[LIMIT ENTRY SKIPPED] SL distance unavailable (ATR / tick value not ready) - not placing without a stop");
        LockOrderSend(false);
        return;
    }
    int cpSkips = CheckpointSkipsFor(slPts);                   // broker SL at the hard cap when skips are on
    if(!ApplyRiskSizing(currentLot, slPts * (1 + cpSkips)))
    {
        LockOrderSend(false);
        return;
    }
    request.volume = currentLot;
    double tpPts = GetTPPoints(currentLot);
    if(slPts > 0 && !IsStopDistanceValid(slPts))
    {
        LogPrint("[LIMIT ENTRY SKIPPED] SL distance ", DoubleToString(slPts, 0), " pts is inside spread + stop level");
        LockOrderSend(false);
        return;
    }
    double brokerSlPts = slPts * (1 + cpSkips);
    bool sendTP = (tpPts > 0 && !EnableCheckpointExit);        // checkpoint mode keeps the TP virtual
    if(dir == ORDER_TYPE_BUY)
    {
        request.type = ORDER_TYPE_BUY_LIMIT;
        if(slPts > 0)
            request.sl = NormalizePrice(entry - brokerSlPts * _Point);
        if(sendTP)
            request.tp = NormalizePrice(entry + tpPts * _Point);
    }
    else
    {
        request.type = ORDER_TYPE_SELL_LIMIT;
        if(slPts > 0)
            request.sl = NormalizePrice(entry + brokerSlPts * _Point);
        if(sendTP)
            request.tp = NormalizePrice(entry - tpPts * _Point);
    }

    if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
    {
        double depthPts = MathAbs(ref - entry) / _Point;
        LogPrint("+-----------------------------------------+");
        LogPrint("[LIMIT ENTRY PLACED] ", dir == ORDER_TYPE_BUY ? "BUY LIMIT" : "SELL LIMIT",
                 " | Anchor: ", EnumToString(LimitEntryAnchor));
        LogPrint("Price: ", entry, " | Depth: ", DoubleToString(depthPts, 0),
                 " pts (cap ", DoubleToString(LimitEntryATRFraction, 2), " ATR)");
        LogPrint("Lot: ", currentLot, " | Signal: ", DoubleToString(signalScore, 1));
        LogPrint("+-----------------------------------------+");
    }
    else
    {
        LogPrint("[LIMIT ENTRY] OrderSend failed. Retcode: ", result.retcode, " Error: ", GetLastError());
    }

    LockOrderSend(false);
}

// Count our working (pending) limit orders on this symbol
int CountWorkingLimitOrders()
{
    int count = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket)) continue;
        if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT) count++;
    }
    return count;
}

// Count ALL our pending orders on this symbol (any pending type)
int CountPendingOrders()
{
    int count = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket)) continue;
        if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        count++;
    }
    return count;
}

// Cancel ALL our pending orders on this symbol (stop path, deinit, blocked entry window)
void DeleteAllPendingOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket)) continue;
        if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        DeletePendingOrder(ticket);
    }
}

// Cancel a pending order
bool DeletePendingOrder(ulong ticket)
{
    LockOrderSend(true);
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    request.action = TRADE_ACTION_REMOVE;
    request.order = ticket;
    bool ok = OrderSend(request, result);
    if(!ok || result.retcode != TRADE_RETCODE_DONE)
        LogPrint("[LIMIT ENTRY] Cancel failed for ", ticket, " Retcode: ", result.retcode, " Error: ", GetLastError());
    LockOrderSend(false);
    return (ok && result.retcode == TRADE_RETCODE_DONE);
}

// Recover the stashed entry-thesis score from a limit-order comment (-1 if absent)
double ParseLimitEntryScore(string comment)
{
    int p = StringFind(comment, "NyaoLE|");
    if(p < 0) return -1;
    return StringToDouble(StringSubstr(comment, p + 7));
}

// +------------------------------------------------------------------+
// | Manage Pending Limit Entries                                     |
// | Cancels unfilled pendings on expiry (bar age) or when the         |
// | directional signal no longer clears its threshold, and cancels    |
// | ALL of them whenever new entries are blocked (pause / news /      |
// | hours / market close / leverage) - a resting limit would otherwise|
// | fill into exactly the window the block exists for. Runs in every  |
// | state (called from ManagePositions) so stale pendings can't fill. |
// +------------------------------------------------------------------+
void ManagePendingOrders()
{
    if(OrdersTotal() == 0) return;

    if(!IsEntryWindowOpen())
    {
        if(CountPendingOrders() > 0)
        {
            LogPrint("[LIMIT ENTRY] Entry window closed (", GetEntryBlockReason(), "). Cancelling pending orders.");
            DeleteAllPendingOrders();
        }
        return;
    }

    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket)) continue;
        if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

        ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;

        // 1. Expiry by bar age (broker-agnostic; placed GTC and aged out here)
        if(LimitEntryExpiryBars > 0)
        {
            datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            int barsElapsed = iBarShift(_Symbol, _Period, setup, false);
            if(barsElapsed >= LimitEntryExpiryBars)
            {
                LogPrint("[LIMIT ENTRY] Expired after ", barsElapsed, " bar(s). Cancelling ticket ", ticket);
                DeletePendingOrder(ticket);
                continue;
            }
        }

        // 2. Cancel when the directional signal no longer clears its threshold
        //    (same scoring mode the entry decision used)
        if(LimitEntryCancelOnFlip)
        {
            bool buy = (ot == ORDER_TYPE_BUY_LIMIT);
            SignalStrength s = GetSignalStrength(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, true);
            double thr = buy ? MinBuySignalScore : MinSellSignalScore;
            if(s.finalScore < thr || s.deadMarket)
            {
                LogPrint("[LIMIT ENTRY] Signal faded (", DoubleToString(s.finalScore, 1),
                         " < ", DoubleToString(thr, 1), "). Cancelling ticket ", ticket);
                DeletePendingOrder(ticket);
            }
        }
    }
}

// Close Position
bool ClosePosition(ulong ticket)
{
    ulong deal = 0;
    return ClosePositionEx(ticket, deal);
}

// +------------------------------------------------------------------+
// | Close a position AND account for it right away                   |
// | OnTradeTransaction normally does the close accounting, but it    |
// | only runs after the current OnTick returns. Callers that decide  |
// | something on the same tick (virtual-SL re-entry) need the loss   |
// | streak / cooldown to already include this close. The accounting  |
// | is idempotent, so the later transaction event is a no-op.        |
// +------------------------------------------------------------------+
bool ClosePositionAndAccount(ulong ticket)
{
    double estimatedPL = 0;
    if(PositionSelectByTicket(ticket))
        estimatedPL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

    ulong deal = 0;
    if(!ClosePositionEx(ticket, deal)) return false;

    // Partially filled close: the position is still open - leave accounting to the full close
    if(PositionSelectByTicket(ticket)) return true;

    double closedPL = estimatedPL;
    if(deal > 0 && HistoryDealSelect(deal))
        closedPL = HistoryDealGetDouble(deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(deal, DEAL_SWAP)
                 + HistoryDealGetDouble(deal, DEAL_COMMISSION);

    ProcessClosedPosition(ticket, closedPL);
    return true;
}

// Close Position (returns the closing deal ticket when available)
bool ClosePositionEx(ulong ticket, ulong &dealOut)
{
    dealOut = 0;
    if(!PositionSelectByTicket(ticket))
    {
        LogPrint("Position ", ticket, " not found");
        return false;
    }

    LockOrderSend(true);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.deviation = 10;
    request.magic = PositionGetInteger(POSITION_MAGIC);
    request.type_filling = GetFillingMode();

    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (type == POSITION_TYPE_BUY) ?
                    SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                    SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // OrderSend() returning true only means the request passed basic checks -
    // the close actually happened only if the server answered DONE.
    if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)
    {
        LogPrint("Failed to close position ", ticket, " Retcode: ", result.retcode, " Error: ", GetLastError());
        LockOrderSend(false);
        return false;
    }

    dealOut = result.deal;
    LogPrint("Position ", ticket, " closed successfully");
    LockOrderSend(false);
    return true;
}

// Close all positions regardless of profit/loss
void CloseAllPositions(bool unProfitableOnly = false, bool skipChainLegs = false)
{
    int closedCount = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);

        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                double profit = PositionGetDouble(POSITION_PROFIT);

                if (unProfitableOnly && profit >= 0) continue;

                // Leave active hedge-chain legs alone (basket stop only sweeps normal trades)
                if(skipChainLegs && EnableHedgeChain)
                {
                    int idx = GetManagedPositionIndex(ticket);
                    if(idx != -1 && managedPositions[idx].chainId != 0) continue;
                }

                LogPrint("Closing position. Ticket: ", ticket, ", Profit/Loss: $", profit);

                if(ClosePosition(ticket))
                {
                    closedCount++;
                    LogPrint("Position closed successfully: ", ticket);
                }
                else
                {
                    LogPrint("ERROR: Failed to close position: ", ticket, ". Error: ", GetLastError());
                }
            }
        }
    }
    
    if(closedCount > 0)
    {
        LogPrint("Total positions closed: ", closedCount);
    }
}

// Modify position SL/TP
uint lastModifyRetcode = 0;                                // Retcode of the last ModifyPosition request

bool ModifyPosition(ulong ticket, double newSL, double newTP)
{
    // Select the position
    if(!PositionSelectByTicket(ticket))
    {
        LogPrint("Error: Failed to select position #", ticket);
        return false;
    }
    
    // Get position information
    string symbol = PositionGetString(POSITION_SYMBOL);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    
    // Prepare request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = symbol;
    request.sl = (newSL > 0) ? NormalizePrice(newSL) : 0;
    request.tp = (newTP > 0) ? NormalizePrice(newTP) : 0;

    // Prevent unnecessary modifications
    if(request.sl == NormalizeDouble(currentSL, _Digits) && request.tp == NormalizeDouble(currentTP, _Digits))
    {
        return true;
    }
    
    // Send modification request (success = DONE, or NO_CHANGES when the levels already match)
    bool sent = OrderSend(request, result);
    lastModifyRetcode = result.retcode;
    if(!sent
       || (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_NO_CHANGES))
    {
        LogPrint("PositionModify failed for position #", ticket, " Error: ", GetLastError());
        LogPrint("Retcode: ", result.retcode, " - ", result.comment);
        return false;
    }
    
    LogPrint("Position #", ticket, " modified successfully");
    LogPrint("Old SL: ", currentSL, " -> New SL: ", newSL);
    LogPrint("Old TP: ", currentTP, " -> New TP: ", newTP);
    
    return true;
}

// +------------------------------------------------------------------+
// | Entry window: everything that blocks NEW exposure for a period   |
// | (equity stops, pauses incl. news, trading hours, leverage change,|
// | market close). Shared by fresh entries, virtual-SL re-entries,   |
// | hedge-chain starts/rolls and pending-order housekeeping.         |
// +------------------------------------------------------------------+
string GetEntryBlockReason(bool ignoreStreakPause = false)
{
    if(targetEquityReached || minimumEquityReached || minEquityTriggersExceeded) return "trading stopped";
    if(IsPaused()) return "paused: " + GetPauseReasons();
    if(streakPaused && !ignoreStreakPause) return "loss-streak pause (paper trading until a paper win)";
    if(isOutsideTradingHours) return "outside trading hours";
    if(isLeverageDiffFromInitial) return "leverage changed";
    if(isNearMarketClose) return "market closing soon";
    return "";
}

bool IsEntryWindowOpen()
{
    return (GetEntryBlockReason() == "");
}

// Entry window + per-tick conditions (order lock, spread). "why" explains a block.
bool IsNewRiskAllowed(string &why)
{
    why = GetEntryBlockReason();
    if(why != "") return false;
    if(isOrderSendLocked) { why = "order in progress"; return false; }
    if(IsSpreadTooWide()) { why = "spread too wide"; return false; }
    return true;
}

// Helper function to check is allowed to open position
bool IsAllowedToOpenPosition(bool ignoreStreakPause = false)
{
    string blockReason = GetEntryBlockReason(ignoreStreakPause);
    if (blockReason != "")
    {
        LogPrint("+-----------------------------------------+");
        LogPrint("OPEN ORDER BLOCKED!");
        LogPrint("No new positions: ", blockReason);
        LogPrint("+-----------------------------------------+");
        return false;
    }

    if (CountLosingPositions() >= MaxHoldingLossPositions)
    {
        LogPrint("+-----------------------------------------+");
        LogPrint("OPEN ORDER BLOCKED!");
        LogPrint("Maximum holding loss positions reached!");
        LogPrint("+-----------------------------------------+");
        return false;
    }

    if (CountOpenOrders() >= MaxOpenOrders)
    {
        LogPrint("+-----------------------------------------+");
        LogPrint("OPEN ORDER BLOCKED!");
        LogPrint("Maximum consecutive open order reached!");
        LogPrint("+-----------------------------------------+");
        return false;
    }

    if (isOrderSendLocked) {
        LogPrint("+-----------------------------------------+");
        LogPrint("OPEN ORDER BLOCKED!");
        LogPrint("An order is still being processed!");
        LogPrint("+-----------------------------------------+");
        return false;
    }

    if (IsSpreadTooWide())
    {
        LogPrint("+-----------------------------------------+");
        LogPrint("OPEN ORDER BLOCKED!");
        LogPrint("Spread too wide for entry.");
        LogPrint("+-----------------------------------------+");
        return false;
    }

    return true;
}

// +------------------------------------------------------------------+
// | Spread Filter - Block entries when spread is too wide            |
// | When MaxSpreadPoints > 0 uses a fixed cap, otherwise derives a   |
// | cap from current ATR (MaxSpreadATRRatio fraction of ATR points)  |
// +------------------------------------------------------------------+
// Current spread cap in points (0 = filter off or no usable ATR yet: never blocks)
double SpreadCapPoints()
{
    if(!EnableMaxSpreadFilter) return 0;

    double cap = MaxSpreadPoints * PointScale();
    if(cap <= 0)
    {
        // Auto mode: cap = fraction of current ATR expressed in points
        double bufATR[];
        ArraySetAsSeries(bufATR, true);
        if(CopyBuffer(atrSignalHandle, 0, 0, 1, bufATR) < 1) return 0; // can't judge, don't block
        double atrPoints = (_Point > 0) ? bufATR[0] / _Point : 0;
        cap = atrPoints * MaxSpreadATRRatio;
        if(cap <= 0) return 0; // no usable ATR, don't block
    }
    return cap;
}

bool IsSpreadTooWide()
{
    double cap = SpreadCapPoints();
    if(cap <= 0) return false;

    double spreadPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if(spreadPoints > cap)
    {
        LogPrint("[SPREAD] Blocked: spread ", DoubleToString(spreadPoints, 0),
                 " pts > cap ", DoubleToString(cap, 0), " pts");
        return true;
    }

    return false;
}


// Round a price to the symbol's tick size (some symbols trade in ticks larger than one point)
double NormalizePrice(double price)
{
    double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(ts <= 0) return NormalizeDouble(price, _Digits);
    return NormalizeDouble(MathRound(price / ts) * ts, _Digits);
}

// Helper function to lock/unlock OrderSend execution
void LockOrderSend(bool isLocked)
{
    isOrderSendLocked = isLocked;
}

// Helper function to get the supported filling mode for the current symbol
ENUM_ORDER_TYPE_FILLING GetFillingMode()
{
    uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    if((filling & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
    if((filling & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
    return ORDER_FILLING_RETURN;
}

// +------------------------------------------------------------------+
// | Risk-Based Lot Sizing (RiskPerTradePct > 0)                      |
// | lot = equity x risk% / money lost per lot at the SL distance.    |
// | Only meaningful when the SL distance does not depend on the lot  |
// | (ATR or Points units, or R:R in ATR/Points) - with a $ or %-of-  |
// | equity SL the risk is already fixed by the SL itself, so the lot  |
// | is left unchanged. When even the broker's minimum lot loses more |
// | than the allowed risk, the minimum lot is still traded while its |
// | loss stays within MaxRiskPerTradePct (small accounts, flagged on |
// | the dashboard and in the log); above that cap the entry is       |
// | skipped - with volatility-scaled stops that is how wild sessions |
// | are sat out instead of being traded with oversized risk.         |
// +------------------------------------------------------------------+
bool RiskSizingApplies()
{
    if(RiskPerTradePct <= 0) return false;
    return EnableRiskReward
        ? (RRRiskMode == RR_RISK_ATR || RRRiskInputType == INPUT_POINTS || RRRiskInputType == INPUT_ATR)
        : (SLInputType == INPUT_ATR || SLInputType == INPUT_POINTS);
}

// The lot RiskPerTradePct allows at this SL distance, without side effects: the minimum lot when it
// loses more than RiskPerTradePct but no more than MaxRiskPerTradePct (lossAtMinLot > riskMoney),
// 0 = even the minimum lot loses more than that cap, -1 = symbol data not ready (can't judge).
// lossAtMinLot / riskMoney are what the minimum lot loses at the SL and the RiskPerTradePct loss.
double RiskSizedLot(double slPoints, double &lossAtMinLot, double &riskMoney)
{
    lossAtMinLot = 0; riskMoney = 0;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickValue <= 0 || tickSize <= 0 || _Point <= 0 || slPoints <= 0) return -1;

    double moneyPerLotAtSL = slPoints * _Point / tickSize * tickValue;   // loss of 1.0 lot at the SL
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPerTradePct / 100.0;
    lossAtMinLot = minLot * moneyPerLotAtSL;
    double riskLot = FloorToVolumeStep(riskMoney / moneyPerLotAtSL);
    if(riskLot < minLot)
        return (lossAtMinLot <= AccountInfoDouble(ACCOUNT_EQUITY) * MaxRiskPerTradePct / 100.0 + 1e-9) ? minLot : 0;
    return MathMin(riskLot, MathMin(MaxLotSize, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)));
}

// The highest % one trade may lose: the cap a minimum-lot trade on a small account may reach
double MaxTradeRiskPct() { return MathMax(RiskPerTradePct, MaxRiskPerTradePct); }

// With a fixed-distance stop a too-small account can never trade - that must be visible even
// with EnableLogging off: printed at start-up and at most once an hour while it lasts
void WarnRiskBlocksEntries(double lossAtMinLot, double riskMoney)
{
    static datetime lastWarn = 0;
    datetime now = TimeCurrent();
    if(lastWarn != 0 && now - lastWarn < 3600) return;
    lastWarn = now;
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    PrintFormat("[RISK SIZING] No new trades: the minimum lot %.2f would lose $%.2f at the stop = %.2f%% of equity, "
                "more than RiskPerTradePct %.2f%% ($%.2f) and MaxRiskPerTradePct %.2f%%. Needs about $%.0f equity "
                "(or a cent account), or set RiskPerTradePct = 0 to trade a fixed BaseLotSize.",
                SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), lossAtMinLot, equity > 0 ? 100.0 * lossAtMinLot / equity : 0,
                RiskPerTradePct, riskMoney, MaxRiskPerTradePct, lossAtMinLot / (MaxTradeRiskPct() / 100.0));
}

// The minimum lot is traded above RiskPerTradePct (within MaxRiskPerTradePct): always printed, at
// start-up and at most once a day while it lasts, so the higher risk is never a surprise
void NoteRiskAboveBudget(double lossAtMinLot, double riskMoney)
{
    static datetime lastNote = 0;
    datetime now = TimeCurrent();
    if(lastNote != 0 && now - lastNote < 86400) return;
    lastNote = now;
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    PrintFormat("[RISK SIZING] Small account: the minimum lot %.2f loses $%.2f at the stop = %.2f%% of equity, above "
                "RiskPerTradePct %.2f%% ($%.2f). Trading it anyway (MaxRiskPerTradePct allows up to %.2f%%); "
                "about $%.0f equity brings each trade back to %.2f%%.",
                SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), lossAtMinLot, equity > 0 ? 100.0 * lossAtMinLot / equity : 0,
                RiskPerTradePct, riskMoney, MaxRiskPerTradePct, lossAtMinLot / (RiskPerTradePct / 100.0), RiskPerTradePct);
}

bool ApplyRiskSizing(double &lot, double slPoints)
{
    if(slPoints <= 0 || !RiskSizingApplies()) return true;

    double lossAtMinLot, riskMoney;
    double sized = RiskSizedLot(slPoints, lossAtMinLot, riskMoney);
    if(sized < 0) return true;                                           // can't judge - keep the lot
    if(sized == 0)
    {
        LogPrint("[RISK SIZING] Entry skipped: min lot ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), " would risk $",
                 DoubleToString(lossAtMinLot, 2), " > ", DoubleToString(MaxTradeRiskPct(), 2),
                 "% of equity ($", DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY) * MaxTradeRiskPct() / 100.0, 2), ")");
        WarnRiskBlocksEntries(lossAtMinLot, riskMoney);
        return false;
    }
    if(lossAtMinLot > riskMoney) NoteRiskAboveBudget(lossAtMinLot, riskMoney);
    lot = sized;
    return true;
}

// True if an SL this many points from the entry price can legally be placed: it must clear the
// spread (a buy's SL is measured from the ask but validated against the bid) plus the broker's
// stop/freeze level, with one point to spare
bool IsStopDistanceValid(double slPoints)
{
    double spreadPts = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
    long levelPts = MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                            SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));
    return (slPoints > spreadPts + (double)levelPts + 1.0);
}

// Helper function to validate SL price
bool IsSLValid(ENUM_POSITION_TYPE posType, double sl)
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    long stopLevel   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);

    double minDistance = MathMax(stopLevel, freezeLevel) * _Point;

    if(posType == POSITION_TYPE_BUY)
    {
        if(sl >= bid - minDistance) return false;
    }
    else
    {
        if(sl <= ask + minDistance) return false;
    }

    return true;
}

// Decimal places of the symbol's volume step (0.01 -> 2, 0.1 -> 1, 1 -> 0)
int VolumeDigits()
{
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(step <= 0) return 2;
    int digits = 0;
    while(digits < 8 && MathAbs(step - MathRound(step)) > 1e-9)
    {
        step *= 10.0;
        digits++;
    }
    return digits;
}

// Helper for normalize volume
double NormalizeVolume(double volume)
{
    double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(stepVol <= 0) stepVol = 0.01;

    volume = MathMax(volume, minVol);
    volume = MathMin(volume, maxVol);
    volume = MathRound(volume / stepVol) * stepVol;

    return NormalizeDouble(volume, VolumeDigits());
}

// Round a volume DOWN to the volume step. The epsilon absorbs binary floating-point error
// (e.g. 0.29 / 0.01 = 28.999999... would otherwise floor to 0.28).
double FloorToVolumeStep(double volume)
{
    double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(stepVol <= 0) stepVol = 0.01;
    if(volume <= 0) return 0;
    return NormalizeDouble(MathFloor(volume / stepVol + 1e-7) * stepVol, VolumeDigits());
}

// Helper to count open orders
int CountOpenOrders()
{
    int count = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);

        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                count++;
            }
        }
    }
    
    return count;
}

int CountOpenOrdersByType(ENUM_POSITION_TYPE posType)
{
    int count = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);

        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetInteger(POSITION_TYPE) == posType)
            {
                count++;
            }
        }
    }
    
    return count;
}
// +------------------------------------------------------------------+

//+-------------------------------------------------------------------+
//| Calculate Dynamic Lot Size - Equity Drop Recovery Based           |
//| Lot increases based on equity drop from peak to recover losses    |
//| Only applies when signal score meets MinSignalStrengthForLot      |
//+-------------------------------------------------------------------+
double CalculateDynamicLotSize(double signalScore = 0)
{
    if(!EnableDynamicLots) return FloorToVolumeStep(MathMin(BaseLotSize, MaxLotSize));
    
    double currentLot = BaseLotSize;
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Calculate equity drop from peak as percentage
    double equityDropPercent = 0;
    if(peakEquity > 0)
    {
        equityDropPercent = ((peakEquity - currentEquity) / peakEquity) * 100.0;
    }
    
    // Each EquityDropPercent step adds LotStepSize
    // Only increase lot if signal score validates the entry
    // GUARDRAILS: never scale up while already bleeding (cooldown after losses
    // or an active basket loss), and cap the number of drawdown-based steps.
    bool inCooldown = (cooldownUntilBarTime > 0 && iTime(_Symbol, _Period, 0) < cooldownUntilBarTime);
    bool basketBleeding = (EnableBasketStop && GetTotalFloatingPL() < 0);

    int equitySteps = 0;
    if(equityDropPercent > 0 && EquityDropPercent > 0 && signalScore >= MinSignalStrengthForLot
       && !inCooldown && !basketBleeding)
    {
        equitySteps = (int)(equityDropPercent / EquityDropPercent);

        // Cap cumulative drawdown lot steps (0 = unlimited)
        if(MaxEquityDropLotSteps > 0 && equitySteps > MaxEquityDropLotSteps)
            equitySteps = MaxEquityDropLotSteps;
    }

    double equityLotIncrease = equitySteps * LotStepSize;
    currentLot += equityLotIncrease;
    
    // APPLY LIMITS
    // Apply user-defined limits
    if(currentLot < BaseLotSize) currentLot = BaseLotSize;
    if(currentLot > MaxLotSize) currentLot = MaxLotSize;
    
    // Round to 2 decimal places (standard lot step)
    currentLot = NormalizeDouble(currentLot, 2);
    
    // Apply broker limits
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(currentLot < minLot) currentLot = minLot;
    if(currentLot > maxLot) currentLot = maxLot;
        
    // Round to valid lot step (epsilon-safe floor)
    currentLot = FloorToVolumeStep(currentLot);
    if(currentLot < minLot) currentLot = minLot;
    
    // MARGIN CHECK
    double marginNeeded = 0;

    if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, currentLot, SymbolInfoDouble(_Symbol, SYMBOL_ASK), marginNeeded))
    {
        LogPrint("ERROR: Failed to calculate margin: ", GetLastError());
        return minLot;
    }

    double availableMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

    if(marginNeeded > availableMargin)
    {
        double symbolLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        double maxAffordableLot = minLot;
        double testMargin = 0;  
        
        if (symbolLotStep == 0) symbolLotStep = 0.01;
        
        double testLot = minLot;
        
        while(testLot <= currentLot)
        {   
            if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, testLot, SymbolInfoDouble(_Symbol, SYMBOL_ASK), testMargin))
            {
                if(testMargin <= availableMargin)
                {
                    maxAffordableLot = testLot;
                    testLot += symbolLotStep;
                }
                else
                {
                    break;
                }
            }
            else
            {
                break;
            }
        }
        
        currentLot = maxAffordableLot;
        
        if(currentLot < minLot)
        {
            LogPrint("WARNING: Insufficient margin. Required: $", marginNeeded, 
                  ", Available: $", availableMargin);
            return minLot;
        }
        
        LogPrint("WARNING: Reduced lot from calculated to affordable: ", currentLot, 
              " (Required margin: $", marginNeeded, ", Available: $", availableMargin, ")");
    }
    
    LogPrint("Dynamic Lot Calculation: Base=", BaseLotSize, 
             " | Equity Drop Steps=", equitySteps, " (+", equityLotIncrease, ")",
             " | Signal Steps=", (signalScore >= MinSignalStrengthForLot ? (signalScore - MinSignalStrengthForLot) / 2 : 0),
             " | Final Lot=", currentLot);

    return NormalizeVolume(currentLot);
}

// +------------------------------------------------------------------+
// | Calculate True Break-even Price                                  |
// +------------------------------------------------------------------+
double CalculateBreakEvenPrice(ulong ticket, ENUM_POSITION_TYPE posType, double entryPrice, double volume)
{
    // Get current spread
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double spread = ask - bid;
    
    // Get commission using deals 
    double commission = GetPositionRoundTripCommission(ticket);
    
    // Get swap
    double swap = 0;
    if(PositionSelectByTicket(ticket))
    {
        swap = PositionGetDouble(POSITION_SWAP);
    }
    
    // For total cost, only count swap if it's negative (a cost)
    double swapCost = (swap < 0) ? MathAbs(swap) : 0;

    // Calculate total cost in account currency
    double totalCost = commission + swapCost;
    
    // Convert cost to price distance
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    double costInPrice = 0;
    double minProfitInPrice = 0;

    if(tickValue != 0 && volume != 0)
    {   
        // Convert cost to price
        costInPrice = (totalCost / volume) * (tickSize / tickValue);

        // Convert MinBreakEvenProfit ($) to price (0 = disabled, no offset)
        if(MinBreakEvenProfit > 0)
            minProfitInPrice = (MinBreakEvenProfit / volume) * (tickSize / tickValue);
    }
    
    // Calculate break-even price
    double breakEvenPrice;
    if(posType == POSITION_TYPE_BUY)
    {
        // BUY: Entry + spread + costs
        breakEvenPrice = entryPrice + spread + costInPrice + minProfitInPrice;
    }
    else
    {
        // SELL: Entry - spread - costs
        breakEvenPrice = entryPrice - spread - costInPrice - minProfitInPrice;
    }
    
    return NormalizeDouble(breakEvenPrice, _Digits);
}

// Get Total Commission for a position (entry + exit estimate)
double GetPositionRoundTripCommission(ulong positionTicket)
{
    double entryCommission = 0.0;
    
    if(!HistorySelectByPosition(positionTicket)) return 0.0;
    
    // Get entry commission
    for(int i = 0; i < HistoryDealsTotal(); i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        
        if(dealTicket > 0)
        {
            ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            
            if(dealEntry == DEAL_ENTRY_IN)
            {
                entryCommission += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                break; // Found entry, no need to continue
            }
        }
    }
    
    // Double it to estimate round-trip (entry + exit)
    // This is an approximation since exit commission hasn't happened yet
    return MathAbs(entryCommission) * 2.0;
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Point-input scale: point values are written for PointInputDigits |
// | -decimal quotes (3 for the default XAUUSDm profile). On a symbol |
// | quoted with other decimals they keep the same price distance:    |
// | x0.1 on 2-decimal gold, so 20000 points stay a 20.00 move.       |
// +------------------------------------------------------------------+
double PointScale()
{
    if(PointInputDigits <= 0 || _Digits == PointInputDigits) return 1.0;
    return MathPow(10.0, _Digits - PointInputDigits);
}

// +------------------------------------------------------------------+
// | Convert Input Value to Points Based on Input Type                |
// +------------------------------------------------------------------+
double ConvertToPoints(ENUM_INPUT_TYPE inputType, double value, double lotSize)
{
    double points = 0;

    switch(inputType)
    {
        case INPUT_POINTS:
            points = value * PointScale();
            break;

        case INPUT_ATR:
            {
                // Volatility-scaled distance: value x ATR of the last closed bar. Unlike fixed
                // dollars/points it keeps the same meaning as price level and volatility change.
                double atr = GetCurrentATR();
                if(atr > 0 && _Point > 0) points = value * atr / _Point;
                else LogPrint("Error: ATR unavailable for ATR-based distance");
            }
            break;

        case INPUT_DOLLAR:
            {
                double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                
                if(tickValue > 0 && tickSize > 0 && lotSize > 0 && point > 0)
                {
                    // Normalize tick value to the lot size we're using
                    double normalizedTickValue = tickValue * lotSize;
                    
                    // Calculate how many points in one tick
                    double pointsPerTick = tickSize / point;

                    if(pointsPerTick <= 0)
                    {
                        LogPrint("Error: Invalid pointsPerTick (", pointsPerTick, ")");
                        return 0;
                    }

                    // Value per point = (value per tick) / (points per tick)
                    double valuePerPoint = normalizedTickValue / pointsPerTick;
                    
                    // Convert dollars to points
                    points = value / valuePerPoint;
                }
                else
                {
                    LogPrint("Error: Invalid tick value (", tickValue, "), tick size (", tickSize, "), point (", point, "), or lot size (", lotSize, ")");
                }
            }
            break;
            
        case INPUT_PERCENT:
            {
                double equity = AccountInfoDouble(ACCOUNT_EQUITY);  
                double dollarAmount = equity * (value / 100.0);
                
                // Reuse the dollar conversion logic
                double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                
                if(tickValue > 0 && tickSize > 0 && lotSize > 0 && point > 0)
                {   
                    // Normalize tick value to the lot size we're using
                    double normalizedTickValue = tickValue * lotSize;

                    // Calculate how many points in one tick
                    double pointsPerTick = tickSize / point;

                    if(pointsPerTick <= 0)
                    {
                        LogPrint("Error: Invalid pointsPerTick in percent conversion (", pointsPerTick, ")");
                        return 0;
                    }
                    
                    // Value per point = (value per tick) / (points per tick)
                    double valuePerPoint = normalizedTickValue / pointsPerTick;

                    // Convert dollars to points
                    points = dollarAmount / valuePerPoint;
                }
                else
                {
                    LogPrint("Error: Invalid parameters for percent conversion");
                }
            }
            break;
    }
    
    return points;
}

// +------------------------------------------------------------------+
// | Current ATR value in price terms (last closed bar, 0 on failure). |
// +------------------------------------------------------------------+
double GetCurrentATR()
{
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(atrSignalHandle, 0, 1, 1, buf) < 1) return 0;
    return buf[0];
}

// +------------------------------------------------------------------+
// | Risk:Reward risk (SL) leg in points - independent of manual SL.   |
// | Manual mode: own input (points/dollar/percent).                   |
// | ATR mode: SL = ATR × multiplier, auto-calculated on entry.        |
// +------------------------------------------------------------------+
double GetRRRiskPoints(double lotSize)
{
    if(RRRiskMode == RR_RISK_ATR)
    {
        double atr = GetCurrentATR();
        if(atr <= 0 || _Point <= 0) return 0;
        double atrPoints = atr / _Point;
        return atrPoints * RRAtrMultiplier;
    }

    // Manual distance
    return ConvertToPoints(RRRiskInputType, RRRiskValue, lotSize);
}

// +------------------------------------------------------------------+
// | Resolve SL distance in points for a given lot (0 = no SL).        |
// | Independent R:R mode overrides the manual Stop Loss entirely.     |
// +------------------------------------------------------------------+
double GetSLPoints(double lotSize)
{
    if(EnableRiskReward)
        return GetRRRiskPoints(lotSize);

    if(EnableStopLoss)
        return ConvertToPoints(SLInputType, SLValue, lotSize);

    return 0;
}

// +------------------------------------------------------------------+
// | Resolve TP distance in points for a given lot (0 = no TP).        |
// | Independent R:R mode sets TP = risk distance × ratio, overriding  |
// | the manual Take Profit entirely.                                  |
// +------------------------------------------------------------------+
double GetTPPoints(double lotSize)
{
    if(EnableRiskReward)
    {
        double slPts = GetRRRiskPoints(lotSize);
        if(slPts > 0 && RiskRewardRatio > 0)
            return slPts * RiskRewardRatio;
        return 0;
    }

    if(EnableTakeProfit)
        return ConvertToPoints(TPInputType, TPValue, lotSize);

    return 0;
}

// +------------------------------------------------------------------+
// | Monitor High-Impact News Events & Return Event Details           |
// +------------------------------------------------------------------+
string IsHighImpactNewsTime(int minutesBefore, int minutesAfter, ulong &eventID, datetime &eventTimeOut)
{
    eventTimeOut = 0;
    MqlCalendarValue values[];
    
    datetime serverTime = TimeTradeServer();
    // Use the max of both windows to cover all events in their active pause window
    // Add 120s buffer to avoid boundary exclusion issues in CalendarValueHistory
    int lookRange = (int)MathMax(minutesBefore, minutesAfter);
    datetime start = serverTime - lookRange * 60;
    datetime end = serverTime + lookRange * 60 + 120;
    
    bool calendarOk = CalendarValueHistory(values, start, end);
    static bool testerCalendarWarned = false;
    if(!calendarOk && MQLInfoInteger(MQL_TESTER) && !testerCalendarWarned)
    {
        testerCalendarWarned = true;
        Print("[NEWS] The economic calendar is not available in the Strategy Tester - the news filter is inactive in this backtest");
    }
    if(calendarOk)
    {
        for(int i = 0; i < ArraySize(values); i++)
        {
            MqlCalendarEvent event;
            if(CalendarEventById(values[i].event_id, event))
            {
                if(event.importance == CALENDAR_IMPORTANCE_HIGH)
                {
                    // Get country info
                    MqlCalendarCountry country;
                    CalendarCountryById(event.country_id, country);
                    
                    // Check if event currency matches symbol currencies
                    if(country.currency != symbolBaseCurrency && 
                       country.currency != symbolQuoteCurrency)
                    {
                        continue;
                    }
                    
                    // Check if we're within the event window (before OR after)
                    datetime eventTime = values[i].time;
                    datetime pauseStart = eventTime - minutesBefore * 60;
                    datetime pauseEnd = eventTime + minutesAfter * 60;
                    
                    if(serverTime < pauseStart || serverTime > pauseEnd)
                    {
                        continue;
                    }
                    
                    eventID = values[i].event_id;
                    eventTimeOut = eventTime;

                    int secondsUntil = (int)(eventTime - serverTime);
                    int minutesUntil = secondsUntil / 60;
                    
                    string eventDetails = "";
                    eventDetails += "**Event Name:** " + event.name + "\n";
                    eventDetails += "**Country:** " + country.name + " (" + country.code + ")\n";
                    eventDetails += "**Currency:** " + country.currency + "\n";
                    eventDetails += "**Event Time:** " + TimeToString(eventTime, TIME_DATE|TIME_SECONDS) + "\n";
                    eventDetails += "**Time Until:** " + IntegerToString(minutesUntil) + " minutes\n";
                    
                    if(values[i].HasActualValue())
                        eventDetails += "**Actual:** " + DoubleToString(values[i].GetActualValue(), 2) + "\n";
                    if(values[i].HasForecastValue())
                        eventDetails += "**Forecast:** " + DoubleToString(values[i].GetForecastValue(), 2) + "\n";
                    if(values[i].HasPreviousValue())
                        eventDetails += "**Previous:** " + DoubleToString(values[i].GetPreviousValue(), 2) + "\n";
                    
                    eventDetails += "**Importance:** " + EnumToString(event.importance) + "\n";
                    eventDetails += "**Pause Window:** " + TimeToString(pauseStart, TIME_SECONDS) + 
                                   " to " + TimeToString(pauseEnd, TIME_SECONDS);
                    
                    LogPrint("High impact event for ", country.currency, ": ", event.name);
                    
                    return eventDetails;
                }
            }
        }
    }
    
    eventID = 0;
    return "";
}

// +------------------------------------------------------------------+
// | Check If Current Time is Within Allowed Trading Hours            |
// +------------------------------------------------------------------+
bool IsWithinTradingHours()
{   
    // Always allow trading if feature is disabled
    if(!EnableTradingHours) return true;
    
    // Get current server time
    datetime currentTime = TimeTradeServer();
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    
    // Current time in minutes from midnight
    int currentMinutes = timeStruct.hour * 60 + timeStruct.min;
    
    // Parse start time
    string startParts[];

    int startCount = StringSplit(TradingStartTime, ':', startParts);
    if(startCount != 2)
    {
        LogPrint("ERROR: Invalid TradingStartTime format. Use HH:MM");
        return false;
    }

    int startHour = (int)StringToInteger(startParts[0]);
    int startMin = (int)StringToInteger(startParts[1]);
    int startMinutes = startHour * 60 + startMin;
    
    // Parse end time
    string endParts[];

    int endCount = StringSplit(TradingEndTime, ':', endParts);
    if(endCount != 2)
    {
        LogPrint("ERROR: Invalid TradingEndTime format. Use HH:MM");
        return false;
    }

    int endHour = (int)StringToInteger(endParts[0]);
    int endMin = (int)StringToInteger(endParts[1]);
    int endMinutes = endHour * 60 + endMin;
    
    // Handle overnight trading sessions (e.g., 22:00 to 02:00)
    if(startMinutes > endMinutes)
    {
        // Trading period crosses midnight
        return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
    }
    else
    {
        // Normal trading period within same day
        return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
    }
}

// +------------------------------------------------------------------+
// | Pause State                                                      |
// | Each pause reason keeps its own end time so one can never cancel |
// | or shorten another (e.g. a new equity peak no longer lifts a news|
// | pause, and a drawdown pause no longer hides a news window).      |
// +------------------------------------------------------------------+
bool IsPaused()
{
    datetime now = TimeTradeServer();
    return (now < equityPauseUntil || now < basketPauseUntil || now < newsPauseUntil);
}

string GetPauseReasons()
{
    datetime now = TimeTradeServer();
    string reasons = "";
    if(now < newsPauseUntil)   reasons += (reasons == "" ? "" : ", ") + "News";
    if(now < basketPauseUntil) reasons += (reasons == "" ? "" : ", ") + "Basket Stop";
    if(now < equityPauseUntil) reasons += (reasons == "" ? "" : ", ") + "Equity Drawdown";
    return reasons;
}

// Minutes until every active pause has ended (0 = not paused)
int PauseMinutesRemaining()
{
    datetime now = TimeTradeServer();
    datetime until = MathMax(equityPauseUntil, MathMax(basketPauseUntil, newsPauseUntil));
    if(until <= now) return 0;
    return (int)((until - now + 59) / 60);
}

// Start (or extend) the basket / hard-stop cool-off. Returns its length in minutes.
int StartBasketPause()
{
    int minutes = (MaxPauseMinutes > 0) ? MathMin(PauseMinutes, MaxPauseMinutes) : PauseMinutes;
    datetime now = TimeTradeServer();
    datetime until = now + (datetime)minutes * 60;

    if(basketPauseUntil <= now)
    {
        totalPauseCount++;
        totalPauseDurationMinutes += minutes;
    }
    if(until > basketPauseUntil) basketPauseUntil = until;
    return minutes;
}

// +------------------------------------------------------------------+
// | Check and Update Peak Equity                                     |
// +------------------------------------------------------------------+
void CheckPeakEquity()
{
    if(DrawdownScope == DD_SCOPE_OWN)
        ownPeakPL = MathMax(ownPeakPL, ownClosedPL + GetTotalFloatingPL());

    // Right after a balance change the deposit may not be applied to the baselines yet: wait a
    // few seconds so it can't become a false new peak (and then a false drawdown)
    if(TimeCurrent() - balanceChangedAt < 5) return;

    // Get current equity
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Update peak equity if current is higher
    if(currentEquity > peakEquity)
    {
        peakEquity = currentEquity;
        lastPeakEquity = currentEquity;
        
        // Reset min equity triggers on new peak
        if (ResetOnNewPeak) minEquityTriggerCount = 0; 
        
        LogPrint("New Peak Equity reached: $", peakEquity);

        // Equity recovered above peak -> the DRAWDOWN pause has served its purpose.
        // News and basket-stop pauses are time windows and are deliberately left running.
        if(equityPauseUntil > TimeTradeServer())
        {
            equityPauseUntil = 0;
            LogPrint("Equity drawdown pause lifted - equity recovered above peak!");
        }
    }
}

// +------------------------------------------------------------------+
// | Check Target Equity                                              |
// +------------------------------------------------------------------+
void CheckTargetEquity()
{   
    // Get current equity
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

    if(TargetEquity > 0 && !targetEquityReached && currentEquity >= TargetEquity)
    {
        targetEquityReached = true;
        
        LogPrint("+-----------------------------------------+");
        LogPrint("TARGET EQUITY REACHED!");
        LogPrint("Current Equity: $", currentEquity);
        LogPrint("Target Equity: $", TargetEquity);
        LogPrint("Closing ALL positions and stopping trading...");
        LogPrint("+-----------------------------------------+");
        
        // Send Discord alert for target equity reached
        if(EnableDiscordAlerts)
        {
            string alertMsg = "**Instrument:** " + _Symbol + "\n";
            alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
            alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
            alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Target Equity:** $" + DoubleToString(TargetEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Profit:** $" + DoubleToString(TargetEquity - initialBalance, 2) + "\n";
            alertMsg += "**Action:** All Positions Closed, Trading Stopped!";
            
            SendDiscordAlert("🎯 TARGET EQUITY REACHED!", alertMsg, 5763719); // Green color
        }
        
        Alert("TARGET EQUITY REACHED! Closing all positions and stopping trading.");
    }
}

// +------------------------------------------------------------------+
// | Check minimum Tradeable Equity                                   |
// +------------------------------------------------------------------+
void CheckMinTradeableEquity() 
{   
    // Get current equity
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

    if(MinimumEquity > 0 && !minimumEquityReached && currentEquity <= MinimumEquity)
    {
        minimumEquityReached = true;
        LogPrint("+-----------------------------------------+");
        LogPrint("MINIMUM TRADEABLE EQUITY REACHED!");
        LogPrint("Current Equity: $", currentEquity);
        LogPrint("Minimum Equity: $", MinimumEquity);
        LogPrint("Closing ALL positions and stopping trading...");
        LogPrint("+-----------------------------------------+");
        
        // Send Discord alert for minimum equity reached
        if(EnableDiscordAlerts)
        {   
            string alertMsg = "**Instrument:** " + _Symbol + "\n";
            alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
            alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
            alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Minimum Equity:** $" + DoubleToString(MinimumEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Loss:** $" + DoubleToString(initialBalance - currentEquity, 2) + "\n";
            alertMsg += "**Action:** All Positions Closed, Trading Stopped!";
            
            SendDiscordAlert("🔴 MINIMUM TRADEABLE EQUITY REACHED", alertMsg, 15158332); // Red color
        }
        
        Alert("MINIMUM TRADEABLE EQUITY REACHED! Closing all positions and stopping trading.");
    }
}

// +------------------------------------------------------------------+
// | Check Equity Drawdawn                                            |
// +------------------------------------------------------------------+
void CheckEquityDrawdawn()
{
    // Same wait after a balance change: a withdrawal is not a drawdown
    if(TimeCurrent() - balanceChangedAt < 5) return;

    // Get current equity
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

    // Calculate allowed drawdown
    double drawdownFromPercent = lastPeakEquity * ((100.0 - MinEquityPercent) / 100.0);
    
    // If MaxDrawdownFromPeak is 0 or negative, don't cap it
    double allowedDrawdown = (MaxDrawdownFromPeak > 0) ? 
    MathMin(drawdownFromPercent, MaxDrawdownFromPeak)
    : drawdownFromPercent;
    
    double minAllowedEquity = lastPeakEquity - allowedDrawdown;
    
    // Check equity condition and handle pause (independent of news / basket pauses)
    if(currentEquity < minAllowedEquity)
    {
        if(equityPauseUntil <= TimeTradeServer())
        {
            // Increment trigger counter
            minEquityTriggerCount++;
            
            // Check if max triggers exceeded
            if(MaxMinEquityTriggers > 0 && minEquityTriggerCount > MaxMinEquityTriggers)
            {
                minEquityTriggersExceeded = true;
                LogPrint("+-----------------------------------------+" );
                LogPrint("MAX MIN EQUITY TRIGGERS EXCEEDED!");
                LogPrint("Triggers Used: ", minEquityTriggerCount, " / ", MaxMinEquityTriggers);
                LogPrint("Closing ALL positions and STOPPING TRADING...");
                LogPrint("+-----------------------------------------+" );
                
                if(EnableDiscordAlerts)
                {   
                    string alertMsg = "**Instrument:** " + _Symbol + "\n";
                    alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
                    alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                    alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                    alertMsg += "**Peak Equity:** $" + DoubleToString(lastPeakEquity, 2) + "\n";
                    alertMsg += "**Triggers Used:** " + IntegerToString(minEquityTriggerCount) + " / " + IntegerToString(MaxMinEquityTriggers) + "\n";
                    alertMsg += "**Action:** All Positions Closed, Trading Stopped!";
                    
                    SendDiscordAlert("🔴 MAX MIN EQUITY TRIGGERS EXCEEDED", alertMsg, 15158332); // Red color
                }
                
                Alert("MAX MIN EQUITY TRIGGERS EXCEEDED! Closing all positions and stopping trading.");
                return;
            }
            
            // First time hitting minimum equity
            datetime pauseStart = TimeTradeServer();

            // Use the trigger count to calculate exponential pause duration
            double calculatedDuration = PauseMinutes * MathPow(PauseMinutesMultiplier, minEquityTriggerCount - 1);
            if(calculatedDuration > INT_MAX) calculatedDuration = INT_MAX;
            int pauseMinutes = (int)MathMin(calculatedDuration, MaxPauseMinutes > 0 ? MaxPauseMinutes : INT_MAX);
            equityPauseUntil = pauseStart + (datetime)pauseMinutes * 60;

            // Update Pause Stats
            totalPauseCount++;
            totalPauseDurationMinutes += pauseMinutes;
            
            // Calculate drop peek equity
            double equityDrop = lastPeakEquity - currentEquity;
            double equityDropPercent = (equityDrop / lastPeakEquity) * 100.0;
            
            // Store old peak for Discord alert
            double oldPeakEquity = lastPeakEquity;
            
            // Update peak equity to current balance
            lastPeakEquity = AccountInfoDouble(ACCOUNT_BALANCE);
            
            LogPrint("+-----------------------------------------+");
            LogPrint("EQUITY PROTECTION TRIGGERED!");
            LogPrint("Current Equity: $", currentEquity);
            LogPrint("Peak Equity: $", peakEquity);
            LogPrint("Old Peak Equity: $", oldPeakEquity);
            LogPrint("New Peak Equity (Balance): $", lastPeakEquity);
            LogPrint("Min Allowed (", MinEquityPercent, "%): $", minAllowedEquity);
            LogPrint("Trading PAUSED for ", pauseMinutes, " minutes");
            LogPrint("Resume Time: ", TimeToString(equityPauseUntil));
            LogPrint("+-----------------------------------------+");

            // Send Discord alert for minimum equity reached
            if(EnableDiscordAlerts)
            {
                string alertMsg = "**Instrument:** " + _Symbol + "\n";
                alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
                alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
                alertMsg += "**Previous Peak:** $" + DoubleToString(oldPeakEquity, 2) + "\n";
                alertMsg += "**New Peak (Balance):** $" + DoubleToString(lastPeakEquity, 2) + "\n";
                alertMsg += "**Equity Drop:** $" + DoubleToString(equityDrop, 2) + " (" + DoubleToString(equityDropPercent, 2) + "%)\n";
                alertMsg += "**Min Allowed (" + DoubleToString(MinEquityPercent, 0) + "%):** $" + DoubleToString(minAllowedEquity, 2) + "\n";
                alertMsg += "**Trading Paused:** " + IntegerToString(pauseMinutes) + " minutes\n";
                alertMsg += "**Resume Time:** " + TimeToString(equityPauseUntil) + "\n";
                alertMsg += "**Action:** Trading Paused";
                
                SendDiscordAlert("⚠️ MINIMUM EQUITY PROTECTION TRIGGERED", alertMsg, 16705372); // Yellow color
            }
        }
    }
}

// +------------------------------------------------------------------+
// | Check High Impact News Event                                     |
// +------------------------------------------------------------------+
void CheckHighImpactNews()
{
    if(!EnableNewsFilter) return;

    // The calendar lookup is comparatively heavy; once every 10 seconds is plenty because
    // the resulting pause window is stored in newsPauseUntil and enforced on every tick.
    datetime serverNow = TimeTradeServer();
    if(lastNewsCheckTime > 0 && serverNow - lastNewsCheckTime < 10) return;
    lastNewsCheckTime = serverNow;

    ulong newsEventID = 0;
    datetime eventTime = 0;
    string newsDetails = IsHighImpactNewsTime(NewsMinutesBefore, NewsMinutesAfter, newsEventID, eventTime);
    if(newsDetails == "") return;

    // Keep the news window enforced for as long as ANY qualifying event is in range,
    // independent of other pauses and of equity peaks (each pause has its own timer).
    datetime windowEnd = ((eventTime > 0) ? eventTime : serverNow) + NewsMinutesAfter * 60 + 60; // +1 min safety
    bool newPause = (newsPauseUntil <= serverNow);
    if(windowEnd > newsPauseUntil) newsPauseUntil = windowEnd;

    if(newPause)
    {
        int pauseMinutes = (int)((newsPauseUntil - serverNow + 59) / 60);
        totalPauseCount++;
        totalPauseDurationMinutes += pauseMinutes;
    }

    // Log / alert once per event
    if(lastProcessedNewsEventID != newsEventID)
    {
        // Update last processed news event ID
        lastProcessedNewsEventID = newsEventID;

        int currentPauseDuration = (int)((newsPauseUntil - serverNow + 59) / 60);
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

        LogPrint("+-----------------------------------------+");
        LogPrint("HIGH-IMPACT NEWS EVENT DETECTED!");
        LogPrint("Server Time: ", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS));
        LogPrint("Current Equity: $", currentEquity);
        LogPrint("Trading PAUSED for ", currentPauseDuration, " minutes");
        LogPrint("Resume Time: ", TimeToString(newsPauseUntil));
        LogPrint("+-----------------------------------------+");
        
        // Send Discord alert with full event details
        if(EnableDiscordAlerts)
        {
            // Add event details
            string alertMsg =  newsDetails + "\n\n";
            
            // Add trading info
            alertMsg += "**Instrument:** " + _Symbol + "\n";
            alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
            alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
            alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Trading Paused:** " + IntegerToString(currentPauseDuration) + " minutes\n";
            alertMsg += "**Resume Time:** " + TimeToString(newsPauseUntil) + "\n";
            alertMsg += "**Action:** Trading Paused";

            SendDiscordAlert("⚠️ HIGH-IMPACT NEWS DETECTED!", alertMsg, 16705372); // Yellow color
        }
    }
}

// +------------------------------------------------------------------+
// | Check Trading Hours                                              |
// +------------------------------------------------------------------+
void CheckTradingHours()
{
    if(!EnableTradingHours) { isOutsideTradingHours = false; return; }
    
    bool currentlyWithinHours = IsWithinTradingHours();
    
    // Check for transition from outside to inside trading hours (Trading Started)
    if(isOutsideTradingHours && currentlyWithinHours)
    {
        isOutsideTradingHours = false;

        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        LogPrint("+-----------------------------------------+");
        LogPrint("TRADING HOURS STARTED");
        LogPrint("Server Time: ", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS));
        LogPrint("Trading Period: ", TradingStartTime, " - ", TradingEndTime);
        LogPrint("Current Equity: $", currentEquity);
        LogPrint("+-----------------------------------------+");
        
        // Send Discord alert for trading started
        if(EnableDiscordAlerts)
        {
            string alertMsg = "**Instrument:** " + _Symbol + "\n";
            alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
            alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
            alertMsg += "**Trading Period:** " + TradingStartTime + " - " + TradingEndTime + "\n";
            alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Action:** Trading Started";
            
            SendDiscordAlert("🟢 TRADING HOURS STARTED!", alertMsg, 5763719); // Green color
        }
    }
    // Check for transition from inside to outside trading hours (Trading Paused)
    else if(!isOutsideTradingHours && !currentlyWithinHours)
    {
        isOutsideTradingHours = true;

        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        LogPrint("+-----------------------------------------+");
        LogPrint("TRADING HOURS ENDED");
        LogPrint("Server Time: ", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS));
        LogPrint("Trading Period: ", TradingStartTime, " - ", TradingEndTime);
        LogPrint("Current Equity: $", currentEquity);
        LogPrint("+-----------------------------------------+");
        
        // Send Discord alert for trading paused
        if(EnableDiscordAlerts)
        {
            string alertMsg = "**Instrument:** " + _Symbol + "\n";
            alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
            alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
            alertMsg += "**Trading Period:** " + TradingStartTime + " - " + TradingEndTime + "\n";
            alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Action:** Trading Stopped";
            
            SendDiscordAlert("🔴 TRADING HOURS ENDED!", alertMsg, 15158332); // Red color
            
            // Send Daily Report
            SendTradeReport();
        }
    }
}

// +------------------------------------------------------------------+
// | Check Market Close Time                                          |
// +------------------------------------------------------------------+
void CheckMarketClose()
{
    if(!EnableMarketCloseFilter || MinutesBeforeClose <= 0)
    {
        isNearMarketClose = false;
        return;
    }

    datetime currentTime = TimeCurrent();
    datetime sessionEnd = 0;

    // Not inside any quote session (market closed per schedule) -> nothing to warn about
    if(!GetCurrentSessionEnd(currentTime, sessionEnd))
    {
        isNearMarketClose = false;
        return;
    }

    long secondsUntilClose = (long)(sessionEnd - currentTime);
    int minutesUntilClose = (int)(secondsUntilClose / 60);

    if(secondsUntilClose > 0 && secondsUntilClose <= (long)MinutesBeforeClose * 60)
    {
        // Send alert once per session
        if(!marketCloseAlertSent && EnableDiscordAlerts)
        {
            double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

            string alertMsg = "**Instrument:** " + _Symbol + "\n";
            alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
            alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
            alertMsg += "**Market Closes In:** " + IntegerToString(minutesUntilClose) + " minutes\n";
            alertMsg += "**Market Close Time:** " + TimeToString(sessionEnd, TIME_DATE|TIME_MINUTES) + "\n";
            alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Action:** Stopped Opening New Positions";

            SendDiscordAlert("⏰ MARKET CLOSING SOON", alertMsg, 16776960); // Yellow
        }
        marketCloseAlertSent = true;

        if(!isNearMarketClose)
            LogPrint("Market closes in ", minutesUntilClose, " minutes (", TimeToString(sessionEnd, TIME_DATE|TIME_MINUTES),
                     "). Not opening new positions.");
        isNearMarketClose = true;
        return;
    }

    // Outside the warning window -> reset for the next session
    isNearMarketClose = false;
    marketCloseAlertSent = false;
}

// +------------------------------------------------------------------+
// | End of the CURRENT continuous quote session (absolute time)      |
// | SymbolInfoSessionQuote returns from/to as TIME OF DAY (seconds   |
// | since 00:00 - the date part must be ignored), so they are mapped |
// | onto the actual calendar day here. Sessions that continue        |
// | seamlessly (e.g. 24:00 -> next day 00:00, or a gap of a couple of|
// | minutes) are followed, so only a REAL break counts as a close.   |
// | Returns false when the current time is not inside any session.   |
// +------------------------------------------------------------------+
bool GetCurrentSessionEnd(datetime now, datetime &sessionEnd)
{
    sessionEnd = 0;
    datetime from, to;
    datetime dayStart = now - (now % 86400);
    int nowSec = (int)(now - dayStart);
    MqlDateTime dt;
    TimeToStruct(now, dt);

    // 1) Which of today's sessions contains "now"?
    datetime end = 0;
    for(uint s = 0; s < 16 && SymbolInfoSessionQuote(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, s, from, to); s++)
    {
        int f = (int)((long)from % 86400);
        int t = (int)((long)to % 86400);
        if(t == 0) t = 86400;                         // 24:00
        if(nowSec >= f && nowSec < t)
        {
            end = dayStart + t;
            break;
        }
    }
    if(end == 0) return false;

    // 2) Follow sessions that start (almost) exactly where the previous one ended
    const int gapTolerance = 300;                     // <= 5 min gap = same trading period
    for(int guard = 0; guard < 14; guard++)
    {
        bool extended = false;
        // Candidate days: the day containing "end" and the day containing end + tolerance
        for(int d = 0; d < 2 && !extended; d++)
        {
            datetime probe = end + d * gapTolerance;
            datetime pDayStart = probe - (probe % 86400);
            if(d == 1 && pDayStart == end - (end % 86400)) break;   // same day already checked
            MqlDateTime pdt;
            TimeToStruct(probe, pdt);

            for(uint k = 0; k < 16 && SymbolInfoSessionQuote(_Symbol, (ENUM_DAY_OF_WEEK)pdt.day_of_week, k, from, to); k++)
            {
                int f = (int)((long)from % 86400);
                int t = (int)((long)to % 86400);
                if(t == 0) t = 86400;
                datetime sStart = pDayStart + f;
                datetime sEnd   = pDayStart + t;
                if(sStart >= end && sStart <= end + gapTolerance && sEnd > end)
                {
                    end = sEnd;
                    extended = true;
                    break;
                }
            }
        }
        if(!extended) break;
    }

    sessionEnd = end;
    return true;
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Check for Leverage Changes                                       |
// +------------------------------------------------------------------+
void CheckLeverageChange()
{
    // Skip if feature is disabled (and lift a block it raised before it was switched off)
    if(!EnableLeveragePause) { isLeverageDiffFromInitial = false; return; }
    
    long currentLeverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    
    // Leverage changed from initial
    if(currentLeverage != initialLeverage && !isLeverageDiffFromInitial)
    {
        isLeverageDiffFromInitial = true;
        
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        LogPrint("+-----------------------------------------+");
        LogPrint("LEVERAGE CHANGE DETECTED - TRADING PAUSED");
        LogPrint("Initial Leverage: 1:", (int)initialLeverage);
        LogPrint("Current Leverage: 1:", (int)currentLeverage);
        LogPrint("Current Equity: $", currentEquity);
        LogPrint("Trading will resume when leverage returns to 1:", (int)initialLeverage);
        LogPrint("+-----------------------------------------+");
        
        // Send Discord alert
        if(EnableDiscordAlerts)
        {
            string alertMsg = "**Instrument:** " + _Symbol + "\n";
            alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
            alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
            alertMsg += "**Initial Leverage:** 1:" + IntegerToString((int)initialLeverage) + "\n";
            alertMsg += "**Current Leverage:** 1:" + IntegerToString((int)currentLeverage) + "\n";
            alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Action:** Trading Paused";
            
            SendDiscordAlert("⚠️ LEVERAGE CHANGE - TRADING PAUSED", alertMsg, 16705372); // Orange color
        }

        // Optional: brokers with dynamic leverage change it around news / weekends / equity
        // tiers - set CloseAllOnLeverageChange = false there to only pause new entries.
        if(CloseAllOnLeverageChange) CloseAllPositions();
    }
    // Leverage returned to initial -> resume (independent of any other pause timer)
    else if(currentLeverage == initialLeverage && isLeverageDiffFromInitial)
    {
        isLeverageDiffFromInitial = false;
        
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        LogPrint("+-----------------------------------------+");
        LogPrint("LEVERAGE RESTORED - TRADING RESUMED");
        LogPrint("Leverage: 1:", (int)currentLeverage);
        LogPrint("Current Equity: $", currentEquity);
        LogPrint("+-----------------------------------------+");
        
        // Send Discord alert
        if(EnableDiscordAlerts)
        {
            string alertMsg = "**Instrument:** " + _Symbol + "\n";
            alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
            alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
            alertMsg += "**Leverage:** 1:" + IntegerToString((int)currentLeverage) + "\n";
            alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Action:** Trading Resumed";
            
            SendDiscordAlert("▶️ LEVERAGE RESTORED - TRADING RESUMED", alertMsg, 3066993); // Blue color
        }
    }
}

// +------------------------------------------------------------------+
// | Check and Send Trade Report                                      |
// +------------------------------------------------------------------+
void CheckTradeReport()
{   
    if (!EnableReports) return;
    
    datetime serverTime = TimeTradeServer();
    MqlDateTime dt;
    TimeToStruct(serverTime, dt);
    
    bool sendReport = false;
    
    // Check for hourly report
    if (SendReportEveryHour > 0)
    {
        if (lastDailyReportTime == 0)
        {
            lastDailyReportTime = serverTime;
        }
        else if (serverTime - lastDailyReportTime >= SendReportEveryHour * 3600)
        {
            sendReport = true;
        }
    }
    
    // End-of-day report: sent on the first tick of a new server day. A tick exactly at 23:59 is
    // not guaranteed (Friday's early close, the near-close filter, pauses, quiet markets).
    static int reportDay = -1;
    if(reportDay == -1) reportDay = dt.day_of_year;
    else if(dt.day_of_year != reportDay)
    {
        reportDay = dt.day_of_year;
        if(!EnableTradingHours) sendReport = true;
    }
    
    if (sendReport)
    {
        SendTradeReport();
    }
}

// Cached statistics (recomputed when a deal is added, or at most once a minute)
TradeStats cachedDailyStats;
TradeStats cachedAllTimeStats;

// Get Trade Statistics (cached - full history scans are expensive)
void GetTradeStats(TradeStats& daily, TradeStats& allTime)
{
    datetime now = TimeCurrent();
    if(tradeStatsDirty || lastStatsCalcTime == 0 || now - lastStatsCalcTime >= 60)
    {
        ComputeTradeStats(cachedDailyStats, cachedAllTimeStats);
        tradeStatsDirty = false;
        lastStatsCalcTime = now;
    }
    daily = cachedDailyStats;
    allTime = cachedAllTimeStats;
}

// Reset a stats bucket before accumulation
void ResetTradeStats(TradeStats& s)
{
    s.count = 0; s.won = 0; s.lost = 0;
    s.profit = 0; s.loss = 0;
    s.avgProfit = 0; s.avgLoss = 0;
    s.maxProfit = 0; s.minProfit = DBL_MAX;
    s.maxLoss = 0; s.minLoss = -DBL_MAX;
}

// Add one closed trade's net result to a stats bucket
void AddTradeToStats(TradeStats& s, double profit)
{
    s.count++;
    if(profit >= 0)
    {
        s.won++;
        s.profit += profit;
        if(profit > s.maxProfit) s.maxProfit = profit;
        if(profit < s.minProfit) s.minProfit = profit;
    }
    else
    {
        s.lost++;
        s.loss += profit;
        if(profit < s.maxLoss) s.maxLoss = profit;
        if(profit > s.minLoss) s.minLoss = profit;
    }
}

// Calculate averages and fix min/max initialization when a bucket has no trades
void FinalizeTradeStats(TradeStats& s)
{
    if(s.won > 0) s.avgProfit = s.profit / s.won; else { s.avgProfit = 0; s.minProfit = 0; }
    if(s.lost > 0) s.avgLoss = s.loss / s.lost; else { s.avgLoss = 0; s.minLoss = 0; s.maxLoss = 0; }
}

// +------------------------------------------------------------------+
// | Compute Trade Statistics from deal history                       |
// | One trade = one fully closed POSITION. All of its deals (entry   |
// | commission, partial closes, final exit) are summed first, so     |
// | partial closes don't inflate the trade count / win rate and the  |
// | entry-side commission is included in the result.                 |
// +------------------------------------------------------------------+
void ComputeTradeStats(TradeStats& daily, TradeStats& allTime)
{
    ResetTradeStats(daily);
    ResetTradeStats(allTime);

    // Trade Stats Session Start Time
    // Start from last report generated, or from start of bot started if no last report
    datetime sessionStartTime = (lastDailyReportTime > 0) ? lastDailyReportTime : startTime;

    if(HistorySelect(0, TimeCurrent() + 86400))
    {
        CHashMap<ulong, int> posIndex;
        ulong    posIds[];
        double   posPL[];
        datetime posLastOut[];
        bool     posHasOut[];
        int      n = 0;

        int deals = HistoryDealsTotal();
        for(int i = 0; i < deals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket == 0) continue;
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;

            long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            bool isOut = (entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT || entryType == DEAL_ENTRY_OUT_BY);
            if(!isOut && entryType != DEAL_ENTRY_IN) continue;

            ulong posId = (ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
            if(posId == 0) continue;

            // Our positions are those we opened (our magic). Their exits count whatever magic they
            // carry: a manual or close-by close has none (history is in time order, so the entry is known)
            int known;
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber && !(isOut && posIndex.TryGetValue(posId, known)))
                continue;

            double pl = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                      + HistoryDealGetDouble(ticket, DEAL_SWAP)
                      + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                      + HistoryDealGetDouble(ticket, DEAL_FEE);

            int k;
            if(!posIndex.TryGetValue(posId, k))
            {
                k = n++;
                if(n > ArraySize(posIds))
                {
                    int newSize = MathMax(64, n * 2);
                    ArrayResize(posIds, newSize);
                    ArrayResize(posPL, newSize);
                    ArrayResize(posLastOut, newSize);
                    ArrayResize(posHasOut, newSize);
                }
                posIds[k] = posId;
                posPL[k] = 0;
                posLastOut[k] = 0;
                posHasOut[k] = false;
                posIndex.Add(posId, k);
            }

            posPL[k] += pl;
            if(isOut)
            {
                posHasOut[k] = true;
                datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                if(dealTime > posLastOut[k]) posLastOut[k] = dealTime;
            }
        }

        for(int k = 0; k < n; k++)
        {
            if(!posHasOut[k]) continue;                       // never exited
            if(PositionSelectByTicket(posIds[k])) continue;   // still open (only partially closed)

            AddTradeToStats(allTime, posPL[k]);

            // SESSION STATS (Since Last Report or Start) - by the time the position closed
            if(posLastOut[k] >= sessionStartTime) AddTradeToStats(daily, posPL[k]);
        }
    }

    FinalizeTradeStats(allTime);
    FinalizeTradeStats(daily);
}

// Send Daily Report
void SendTradeReport() 
{
    if(!EnableDiscordAlerts) return;

    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double deposit = initialBalance;
    
    TradeStats dailyStats;
    TradeStats allTimeStats;
    tradeStatsDirty = true;                 // reports always use fresh numbers
    GetTradeStats(dailyStats, allTimeStats);

    // Session net profit
    double sessionNetProfit = dailyStats.profit + dailyStats.loss; // loss is already negative
    double sessionStartBalance = balance - sessionNetProfit;           // balance when the session began
    double sessionNetPercent = (sessionStartBalance > 0) ? (sessionNetProfit / sessionStartBalance) * 100.0 : 0.0;
    
    // All time net profit
    double allTimeNetProfit = allTimeStats.profit + allTimeStats.loss;
    double allTimeNetPercent = (deposit > 0) ? (allTimeNetProfit / deposit) * 100.0 : 0.0;
    
    // All time profit/loss percentages (kept for existing lines)
    double profitPercent = (balance > 0) ? (allTimeStats.profit / balance) * 100.0 : 0.0;
    double lossPercent = (balance > 0) ? (allTimeStats.loss / balance) * 100.0 : 0.0;
    
    // Duration
    long durationSeconds = TimeCurrent() - startTime;
    int days = (int)(durationSeconds / 86400);
    int hours = (int)((durationSeconds % 86400) / 3600);
    int minutes = (int)((durationSeconds % 3600) / 60);
    string durationStr = "";
    if(days > 0) durationStr += IntegerToString(days) + "d ";
    if(hours > 0) durationStr += IntegerToString(hours) + "h ";
    durationStr += IntegerToString(minutes) + "m";
    
    // Report Interval Duration
    long reportInterval = (lastDailyReportTime > 0) ? (TimeCurrent() - lastDailyReportTime) : durationSeconds;
    int rHours = (int)(reportInterval / 3600);
    int rMinutes = (int)((reportInterval % 3600) / 60);
    string reportDurationStr = "";
    if(rHours > 0) reportDurationStr += IntegerToString(rHours) + "h ";
    reportDurationStr += IntegerToString(rMinutes) + "m";

    string alertMsg = "**Instrument:** " + _Symbol + "\n";
    alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
    alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
    alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
    alertMsg += "**Previous Report Equity:** $" + DoubleToString(lastReportEquity, 2) + "\n";
    alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
    alertMsg += "**Initial Balance:** $" + DoubleToString(deposit, 2) + "\n";
    alertMsg += "**Current Balance:** $" + DoubleToString(balance, 2) + "\n\n";
    
    alertMsg += "**Trades:** " + IntegerToString(dailyStats.count) + "\n";
    alertMsg += "**Won:** " + IntegerToString(dailyStats.won) + "\n";
    alertMsg += "**Lost:** " + IntegerToString(dailyStats.lost) + "\n";
    alertMsg += "**Profit:** $" + DoubleToString(dailyStats.profit, 2) + "\n";
    alertMsg += "**Loss:** $" + DoubleToString(dailyStats.loss, 2) + "\n";
    alertMsg += "**Net Profit:** $" + DoubleToString(sessionNetProfit, 2) + " (" + DoubleToString(sessionNetPercent, 2) + "%)\n\n";
    
    alertMsg += "**All Time Trades:** " + IntegerToString(allTimeStats.count) + "\n";
    alertMsg += "**All Time Won:** " + IntegerToString(allTimeStats.won) + "\n";
    alertMsg += "**All Time Lost:** " + IntegerToString(allTimeStats.lost) + "\n";
    alertMsg += "**All Time Profit:** $" + DoubleToString(allTimeStats.profit, 2) + " (" + DoubleToString(profitPercent, 2) + "%)\n";
    alertMsg += "**All Time Loss:** $" + DoubleToString(allTimeStats.loss, 2) + " (" + DoubleToString(lossPercent, 2) + "%)\n";
    alertMsg += "**All Time Net Profit:** $" + DoubleToString(allTimeNetProfit, 2) + " (" + DoubleToString(allTimeNetPercent, 2) + "%)\n\n";
    
    alertMsg += "**Average Profit:** $" + DoubleToString(allTimeStats.avgProfit, 2) + "\n";
    alertMsg += "**Largest Profit:** $" + DoubleToString(allTimeStats.maxProfit, 2) + "\n";
    alertMsg += "**Smallest Profit:** $" + DoubleToString(allTimeStats.minProfit, 2) + "\n";
    alertMsg += "**Average Loss:** $" + DoubleToString(allTimeStats.avgLoss, 2) + "\n";
    alertMsg += "**Largest Loss:** $" + DoubleToString(allTimeStats.maxLoss, 2) + "\n";
    alertMsg += "**Smallest Loss:** $" + DoubleToString(allTimeStats.minLoss, 2) + "\n";
    alertMsg += "**Expectancy:** $" + DoubleToString(TradeExpectancy(allTimeStats), 2) + " per trade\n";
    alertMsg += "**Profit Factor:** " + ProfitFactorText(allTimeStats) + "\n\n";

    alertMsg += "**Pauses Triggered:** " + IntegerToString(totalPauseCount) + "\n";
    alertMsg += "**Total Paused Duration:** " + DoubleToString(totalPauseDurationMinutes, 0) + " minutes" + "\n";
    alertMsg += "**Report Generated For:** " + reportDurationStr + "\n";
    alertMsg += "**Run Duration:** " + durationStr + "\n";
    
    SendDiscordAlert("📊 TRADE REPORT", alertMsg, 16776960); // Yellow/Gold color

    lastDailyReportTime = TimeCurrent();
    lastReportEquity = currentEquity;
    tradeStatsDirty = true;                 // session window moved
}

// Average net result per closed trade (the number that actually decides profitability)
double TradeExpectancy(const TradeStats& s)
{
    return (s.count > 0) ? (s.profit + s.loss) / s.count : 0;
}

// Gross profit / gross loss
string ProfitFactorText(const TradeStats& s)
{
    if(s.loss < 0) return DoubleToString(s.profit / -s.loss, 2);
    return (s.profit > 0) ? "inf" : "-";
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Algo Trading MT5                                                 |
// +------------------------------------------------------------------+
void CheckAlgoTradingStatus()
{
    bool currentStatus = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   
   // Detect status change
   if(currentStatus != algoTradingStatus)
   {
      if(currentStatus)
      {
        LogPrint("Algo Trading has been ENABLED");

        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);

        string alertMsg = "**Instrument:** " + _Symbol + "\n";
        alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
        alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
        alertMsg += "**Trading Hours:** " + (EnableTradingHours ? TradingStartTime + " - " + TradingEndTime + "\n" : "DISABLED\n");
        alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
        alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
        alertMsg += "**Current Balance:** $" + DoubleToString(balance, 2) + "\n";
        alertMsg += "**Initial Balance:** $" + DoubleToString(initialBalance, 2) + "\n";
        alertMsg += "**Action:** Trading Started (Algo Trading Enabled)";
        
        SendDiscordAlert("🟢 AUTOMATED TRADING STARTED", alertMsg, 5763719); // Green color
      }
      else
      {
        LogPrint("Algo Trading has been DISABLED");

        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);

        string alertMsg = "**Instrument:** " + _Symbol + "\n";
        alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
        alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
        alertMsg += "**Trading Hours:** " + (EnableTradingHours ? TradingStartTime + " - " + TradingEndTime + "\n" : "DISABLED\n");
        alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
        alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
        alertMsg += "**Current Balance:** $" + DoubleToString(balance, 2) + "\n";
        alertMsg += "**Initial Balance:** $" + DoubleToString(initialBalance, 2) + "\n";
        alertMsg += "**Action:** Trading Stopped (Algo Trading Disabled)";
        
        SendDiscordAlert("🔴 AUTOMATED TRADING STOPPED", alertMsg, 15158332); // Green color
      }
      
      // Update status
      algoTradingStatus = currentStatus;
   }
}

// +------------------------------------------------------------------+
// | Persistent State                                                 |
// | managedPositions (chain links, partial-close level, break-even,  |
// | entry score, profit-offset tracking...) and the account-level    |
// | guards (peak equity, loss streak, cooldown, pauses) live only in |
// | memory. They are saved to MQL5\Files\NyaoScalper\ whenever they  |
// | change and restored in InitializeEA, so a terminal/VPS restart,  |
// | recompile, input change or timeframe switch can no longer turn   |
// | active hedge-chain legs into "new" positions that start fresh     |
// | chains, or reset the drawdown baseline. Disabled in the tester.  |
// +------------------------------------------------------------------+
struct PersistHeader
{
    int      version;
    int      recordSize;
    int      count;
    long     login;
    long     magic;
    double   peakEquity;
    double   lastPeakEquity;
    int      minEquityTriggerCount;
    int      consecutiveLossCount;
    datetime cooldownUntilBarTime;
    datetime equityPauseUntil;
    datetime basketPauseUntil;
    int      streakLosses;
    bool     streakPaused;
    int      paperDir;
    double   paperEntry;
    double   paperTarget;
    double   paperStop;
    long     initialLeverage;
    double   initialBalance;
    datetime savedAt;
    ulong    lastBalanceDeal;
};

bool IsPersistenceActive()
{
    return (EnablePersistState && !MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION));
}

string StateFileName()
{
    string sym = _Symbol;
    string bad[] = {"\\", "/", ":", "*", "?", "\"", "<", ">", "|"};
    for(int i = 0; i < ArraySize(bad); i++) StringReplace(sym, bad[i], "_");
    long login = (stateLogin > 0) ? stateLogin : AccountInfoInteger(ACCOUNT_LOGIN);
    return StringFormat("NyaoScalper\\state_%I64d_%s_%I64d.bin", login, sym, (long)MagicNumber);
}

bool SameManagedPosition(const ManagedPosition &a, const ManagedPosition &b)
{
    return a.ticket == b.ticket && a.type == b.type && a.signalScore == b.signalScore
        && a.entryPrice == b.entryPrice && a.partialCloseLevel == b.partialCloseLevel
        && a.breakEvenLocked == b.breakEvenLocked && a.profitOffsetConsecWins == b.profitOffsetConsecWins
        && a.profitOffsetAccumulated == b.profitOffsetAccumulated && a.profitOffsetOriginalSL == b.profitOffsetOriginalSL
        && a.chainId == b.chainId && a.hedgeLevel == b.hedgeLevel && a.chainAnchorLoss == b.chainAnchorLoss
        && a.cycleNum == b.cycleNum && a.noRehedge == b.noRehedge && a.hedgeGraduated == b.hedgeGraduated
        && a.hedgeLockProfit == b.hedgeLockProfit
        && a.cpPrice == b.cpPrice && a.cpStep == b.cpStep && a.virtSL == b.virtSL && a.virtStep == b.virtStep
        && a.cpSkipsLeft == b.cpSkipsLeft && a.cpCount == b.cpCount && a.chainBooked == b.chainBooked && a.cpLock == b.cpLock;
}

void FillPersistHeader(PersistHeader &h)
{
    h.version               = STATE_FILE_VERSION;
    h.recordSize            = sizeof(ManagedPosition);
    h.count                 = managedPositionCount;
    h.login                 = stateLogin;
    h.magic                 = MagicNumber;
    h.peakEquity            = peakEquity;
    h.lastPeakEquity        = lastPeakEquity;
    h.minEquityTriggerCount = minEquityTriggerCount;
    h.consecutiveLossCount  = consecutiveLossCount;
    h.cooldownUntilBarTime  = cooldownUntilBarTime;
    h.equityPauseUntil      = equityPauseUntil;
    h.basketPauseUntil      = basketPauseUntil;
    h.streakLosses          = streakLosses;
    h.streakPaused          = streakPaused;
    h.paperDir              = paperDir;
    h.paperEntry            = paperEntry;
    h.paperTarget           = paperTarget;
    h.paperStop             = paperStop;
    h.initialLeverage       = initialLeverage;
    h.initialBalance        = initialBalance;
    h.savedAt               = TimeCurrent();
    h.lastBalanceDeal       = lastBalanceDeal;
}

// Write state if anything changed since the last save (force = always write)
void SaveState(bool force = false)
{
    if(!IsPersistenceActive()) return;
    if(!eaInitialized || stopRemoveRequested) return;   // nothing (valid) to save

    static PersistHeader lastHeader;
    PersistHeader header;
    FillPersistHeader(header);

    if(!force && lastSavedCount == managedPositionCount
       && header.peakEquity == lastHeader.peakEquity
       && header.lastPeakEquity == lastHeader.lastPeakEquity
       && header.minEquityTriggerCount == lastHeader.minEquityTriggerCount
       && header.consecutiveLossCount == lastHeader.consecutiveLossCount
       && header.cooldownUntilBarTime == lastHeader.cooldownUntilBarTime
       && header.equityPauseUntil == lastHeader.equityPauseUntil
       && header.basketPauseUntil == lastHeader.basketPauseUntil
       && header.streakLosses == lastHeader.streakLosses && header.streakPaused == lastHeader.streakPaused
       && header.paperDir == lastHeader.paperDir && header.paperEntry == lastHeader.paperEntry
       && header.initialLeverage == lastHeader.initialLeverage && header.initialBalance == lastHeader.initialBalance
       && header.lastBalanceDeal == lastHeader.lastBalanceDeal)
    {
        bool same = true;
        for(int i = 0; i < managedPositionCount && same; i++)
            same = SameManagedPosition(managedPositions[i], lastSavedPositions[i]);
        if(same) return;
    }

    FolderCreate("NyaoScalper");
    int h = FileOpen(StateFileName(), FILE_WRITE | FILE_BIN);
    if(h == INVALID_HANDLE)
    {
        LogPrint("[STATE] Cannot write ", StateFileName(), " Error: ", GetLastError());
        return;
    }
    FileWriteStruct(h, header);
    if(managedPositionCount > 0) FileWriteArray(h, managedPositions, 0, managedPositionCount);
    FileClose(h);

    ArrayResize(lastSavedPositions, managedPositionCount);
    for(int i = 0; i < managedPositionCount; i++) lastSavedPositions[i] = managedPositions[i];
    lastSavedCount = managedPositionCount;
    lastHeader = header;
}

// Apply every deposit / withdrawal / credit newer than the last one applied (deals since `from`)
void CatchUpBalanceOperations(datetime from)
{
    if(!HistorySelect(MathMax(0, from), TimeCurrent() + 86400)) return;
    int total = HistoryDealsTotal();
    for(int d = 0; d < total; d++)                          // oldest first: lastBalanceDeal only grows
    {
        ulong deal = HistoryDealGetTicket(d);
        if(deal == 0) continue;
        long type = HistoryDealGetInteger(deal, DEAL_TYPE);
        if(type == DEAL_TYPE_BALANCE || type == DEAL_TYPE_CREDIT)
            ApplyBalanceOperation(deal, HistoryDealGetDouble(deal, DEAL_PROFIT));
    }
}

// Newest deposit / withdrawal deal in the whole account history (0 = none)
ulong LatestBalanceDeal()
{
    ulong latest = 0;
    if(!HistorySelect(0, TimeCurrent() + 86400)) return 0;
    for(int d = HistoryDealsTotal() - 1; d >= 0; d--)
    {
        ulong deal = HistoryDealGetTicket(d);
        long type = HistoryDealGetInteger(deal, DEAL_TYPE);
        if(deal > latest && (type == DEAL_TYPE_BALANCE || type == DEAL_TYPE_CREDIT)) latest = deal;
    }
    return latest;
}

// A deposit / withdrawal shifts the equity baselines by the same amount, so it never reads as a
// drawdown (or a new peak) for the drawdown gate, the min-equity pause and the reports.
// Each deal is applied once: it may be seen by the transaction event, the per-tick catch-up
// and the restart catch-up.
void ApplyBalanceOperation(ulong deal, double amount)
{
    if(deal <= lastBalanceDeal) return;
    lastBalanceDeal = deal;
    if(amount == 0) return;
    peakEquity     = MathMax(0, peakEquity + amount);
    lastPeakEquity = MathMax(0, lastPeakEquity + amount);
    initialBalance = MathMax(0, initialBalance + amount);
    LogPrint("[BALANCE] ", (amount > 0 ? "Deposit" : "Withdrawal"), " of $", DoubleToString(MathAbs(amount), 2),
             " - equity baselines adjusted (peak $", DoubleToString(peakEquity, 2), ")");
}

bool WasRestored(ulong ticket)
{
    for(int i = 0; i < ArraySize(restoredTickets); i++)
        if(restoredTickets[i] == ticket) return true;
    return false;
}

// Positions the saved state did not cover (no file, ResetSavedState, other version, a crash before
// the save): give them the protection a fresh entry gets - a stop if they have none (e.g. a hedge
// root whose SL was cleared) and the checkpoint exit, which has no broker TP to fall back on.
void AdoptUnrestoredPositions()
{
    int adopted = 0;
    ArrayResize(adoptPending, 0);
    for(int i = 0; i < managedPositionCount; i++)
    {
        ulong ticket = managedPositions[i].ticket;
        if(WasRestored(ticket) || !PositionSelectByTicket(ticket)) continue;
        if(!AdoptPosition(i))
        {
            int n = ArraySize(adoptPending);
            ArrayResize(adoptPending, n + 1);
            adoptPending[n] = ticket;
        }
        adopted++;
    }
    if(adopted > 0)
        Print("[STATE] ", adopted, " open position(s) had no saved state - stop and checkpoint exit re-armed",
              (ArraySize(adoptPending) > 0 ? " (some still pending, retried every tick)" : ""));
}

// Retry the positions whose stop / checkpoint could not be set yet
void RetryAdoption()
{
    for(int k = ArraySize(adoptPending) - 1; k >= 0; k--)
    {
        int idx = GetManagedPositionIndex(adoptPending[k]);
        if(idx == -1 || !PositionSelectByTicket(adoptPending[k]) || AdoptPosition(idx))
        {
            adoptPending[k] = adoptPending[ArraySize(adoptPending) - 1];
            ArrayResize(adoptPending, ArraySize(adoptPending) - 1);
        }
    }
}

// Stop + checkpoint for one unrestored position (position must be selected). True = nothing left to do.
bool AdoptPosition(int i)
{
    bool done = true;
    {
        ulong ticket = managedPositions[i].ticket;

        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        bool isBuy  = (type == POSITION_TYPE_BUY);
        double dir  = isBuy ? 1.0 : -1.0;
        double vol  = PositionGetDouble(POSITION_VOLUME);
        double entry = PositionGetDouble(POSITION_PRICE_OPEN);
        double sl   = PositionGetDouble(POSITION_SL);
        double tp   = PositionGetDouble(POSITION_TP);
        double slPts = GetSLPoints(vol);

        if(sl == 0)
        {
            // Unknown history: never let it seed a hedge chain, and put a stop on it
            managedPositions[i].noRehedge = true;
            if(slPts > 0)
            {
                double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double newSL = entry - dir * slPts * _Point;
                if(!IsSLValid(type, NormalizePrice(newSL))) newSL = price - dir * slPts * _Point;  // already past it
                newSL = NormalizePrice(newSL);
                if(IsSLValid(type, newSL) && ModifyPosition(ticket, newSL, tp))
                    Print("[STATE] Position ", ticket, " had no stop loss - SL set at ", DoubleToString(newSL, _Digits));
                else
                    done = false;
            }
            else
                done = false;                                // SL distance not available yet (ATR / tick value)
        }

        if(EnableCheckpointExit && managedPositions[i].cpStep <= 0 && managedPositions[i].chainId == 0)
        {
            double tpPts = GetTPPoints(vol);
            if(tpPts > 0) InitCheckpoint(ticket, type, entry, tpPts, slPts, 0);
            else done = false;
        }
    }
    return done;
}

// Restore saved state onto the freshly rebuilt managedPositions (call after the position scan)
void RestoreState()
{
    lastSavedCount = -1;
    ArrayResize(restoredTickets, 0);
    if(!IsPersistenceActive()) return;

    string fileName = StateFileName();
    if(ResetSavedState)
    {
        if(FileIsExist(fileName)) FileDelete(fileName);
        Print("[STATE] ResetSavedState = true: saved state discarded. Set it back to false for normal restarts.");
        return;
    }
    if(!FileIsExist(fileName)) return;

    int h = FileOpen(fileName, FILE_READ | FILE_BIN);
    if(h == INVALID_HANDLE)
    {
        Print("[STATE] Cannot read ", fileName, " Error: ", GetLastError());
        return;
    }

    PersistHeader header;
    ZeroMemory(header);
    bool ok = (FileReadStruct(h, header) == sizeof(PersistHeader));
    ok = ok && header.version == STATE_FILE_VERSION
            && header.recordSize == sizeof(ManagedPosition)
            && header.login == stateLogin
            && header.magic == MagicNumber
            && header.count >= 0 && header.count <= 10000;

    ManagedPosition saved[];
    if(ok && header.count > 0)
        ok = (FileReadArray(h, saved, 0, header.count) == (uint)header.count);
    FileClose(h);

    if(!ok)
    {
        Print("[STATE] Saved state in ", fileName, " is from another version/account - ignored.");
        return;
    }

    // Account-level guards. Deposits / withdrawals made while the EA was offline move the
    // equity baselines too - a withdrawal is not a drawdown. Each one is applied exactly once.
    double currentEquity = peakEquity;                       // InitializeEA set it to the current equity
    peakEquity = header.peakEquity;
    if(header.lastPeakEquity > 0) lastPeakEquity = header.lastPeakEquity;
    if(header.initialBalance > 0) initialBalance = header.initialBalance;
    lastBalanceDeal = header.lastBalanceDeal;
    CatchUpBalanceOperations(header.savedAt - 86400);
    if(currentEquity > peakEquity) peakEquity = currentEquity;
    // Keep the original leverage reference while positions are open (a restart during a temporary
    // leverage change must not turn the normal leverage into a "change" later); when flat, start fresh.
    if(header.initialLeverage > 0 && managedPositionCount > 0) initialLeverage = header.initialLeverage;
    minEquityTriggerCount = header.minEquityTriggerCount;
    consecutiveLossCount  = header.consecutiveLossCount;
    cooldownUntilBarTime  = header.cooldownUntilBarTime;
    equityPauseUntil      = header.equityPauseUntil;
    basketPauseUntil      = header.basketPauseUntil;
    streakLosses          = header.streakLosses;
    streakPaused          = header.streakPaused && LossStreakPauseCount > 0;
    paperDir              = streakPaused ? header.paperDir : 0;
    paperEntry            = header.paperEntry;
    paperTarget           = header.paperTarget;
    paperStop             = header.paperStop;

    // Per-position state (records of positions closed while the EA was offline are dropped)
    int restored = 0, chainLegs = 0;
    for(int i = 0; i < ArraySize(saved); i++)
    {
        int idx = GetManagedPositionIndex(saved[i].ticket);
        if(idx == -1) continue;
        managedPositions[idx] = saved[i];
        int n = ArraySize(restoredTickets);
        ArrayResize(restoredTickets, n + 1);
        restoredTickets[n] = saved[i].ticket;
        restored++;
        if(saved[i].chainId != 0) chainLegs++;
    }

    Print("[STATE] Restored ", restored, " position(s) (", chainLegs, " active hedge-chain leg(s)), peak equity $",
          DoubleToString(peakEquity, 2), ", loss streak ", consecutiveLossCount);
}

// +------------------------------------------------------------------+
// | Send Discord alert via webhook                                   |
// +------------------------------------------------------------------+
// Discord alerts are queued and sent at most one per tick, after the tick's trading work:
// WebRequest blocks, so a slow or unreachable Discord must never hold up position management
string   alertTitles[];
string   alertMessages[];
int      alertColors[];
int      alertTries = 0;
datetime alertRetryAfter = 0;

bool SendDiscordAlert(string title, string message, int embedColor = 3447003)
{
    if(!EnableDiscordAlerts || DiscordWebhookURL == "") return false;
    if(MQLInfoInteger(MQL_TESTER)) return false;           // WebRequest is not available in the tester
    int n = ArraySize(alertTitles);
    if(n >= 20) return false;                               // backlog full - drop rather than pile up
    ArrayResize(alertTitles, n + 1);
    ArrayResize(alertMessages, n + 1);
    ArrayResize(alertColors, n + 1);
    alertTitles[n] = title;
    alertMessages[n] = message;
    alertColors[n] = embedColor;
    return true;
}

// Send the oldest queued alert (call once per tick). Failures back off 30s; 3 failures drop it.
void FlushDiscordAlerts()
{
    if(ArraySize(alertTitles) == 0 || TimeCurrent() < alertRetryAfter) return;
    bool ok = PostDiscordAlert(alertTitles[0], alertMessages[0], alertColors[0]);
    if(!ok && ++alertTries < 3)
    {
        alertRetryAfter = TimeCurrent() + 30;
        return;
    }
    alertTries = 0;
    int n = ArraySize(alertTitles);
    for(int i = 1; i < n; i++)
    {
        alertTitles[i - 1] = alertTitles[i];
        alertMessages[i - 1] = alertMessages[i];
        alertColors[i - 1] = alertColors[i];
    }
    ArrayResize(alertTitles, n - 1);
    ArrayResize(alertMessages, n - 1);
    ArrayResize(alertColors, n - 1);
}

// JSON string escaping: quotes, backslash and every control character
string JsonEscape(string text)
{
    string out = "";
    int len = StringLen(text);
    for(int i = 0; i < len; i++)
    {
        ushort c = StringGetCharacter(text, i);
        if(c == '"') out += "\\\"";
        else if(c == '\\') out += "\\\\";
        else if(c == '\n') out += "\\n";
        else if(c == '\r') out += "\\r";
        else if(c == '\t') out += "\\t";
        else if(c < 32) out += StringFormat("\\u%04x", c);
        else out += ShortToString(c);
    }
    return out;
}

bool PostDiscordAlert(string title, string message, int embedColor)
{
    // Build JSON payload
    string json = "";
    json += "{\"embeds\":[{";
    json += "\"title\":\"" + JsonEscape(title) + "\",";
    json += "\"description\":\"" + JsonEscape(message) + "\",";
    json += "\"color\":" + IntegerToString(embedColor) + ",";
    json += "\"footer\":{\"text\":\"" + JsonEscape(EA_TITLE) + "\"}";
    json += "}]}";

    // Prepare HTTP request
    char post[];
    char result[];
    string headers = "Content-Type: application/json\r\n";
    string resultHeaders = "";
    int timeout = 3000;
    
    // Convert JSON to char array
    StringToCharArray(json, post, 0, WHOLE_ARRAY, CP_UTF8);
    ArrayResize(post, ArraySize(post) - 1); // Remove null terminator

    // Send webhook
    int res = WebRequest("POST", DiscordWebhookURL, headers, timeout, post, result, resultHeaders);

    if(res == 200 || res == 204)
    {
        LogPrint("Discord alert sent: ", title);
        return true;
    }
    else
    {
        LogPrint("Discord ERROR: ", res);
        LogPrint("Payload: ", json);
        LogPrint("Response: ", CharArrayToString(result));
        LogPrint("MT5 Error: ", GetLastError());
        return false;
    }
}

// +------------------------------------------------------------------+
// | Check and Test Discord Alert                                     |
// +------------------------------------------------------------------+
void CheckDiscordAlert() 
{
    if(DiscordWebhookURL == "")
    {
        Print("WARNING: Discord alerts enabled but webhook URL is empty!");
    }
    else if(StringFind(DiscordWebhookURL, "https://discord.com/api/webhooks/") != 0 &&
            StringFind(DiscordWebhookURL, "https://discordapp.com/api/webhooks/") != 0)
    {
        Print("WARNING: Discord webhook URL format may be incorrect!");
    }
    else
    {   
        CheckAlgoTradingStatus();
    }
}

// +------------------------------------------------------------------+
// | Update On-Chart Dashboard                                        |
// +------------------------------------------------------------------+
int dashTextRight = 0;                                    // right edge (px) of the widest label this redraw

void DrawDashboardLabel(string name, string text, int x, int y, int fontSize, color clr, bool bold = false)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    }

    // MT5 shows at most 63 characters of a label: make a cut visible instead of silent
    if(StringLen(text) > 63) text = StringSubstr(text, 0, 62) + "\x2026";

    // Position every redraw: optional lines (hedge chains) shift the rows below them
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");

    // Measure the text the way the label renders it (points, scaled like the chart) for the background
    uint w = 0, h = 0;
    if(TextSetFont(bold ? "Arial Bold" : "Arial", -fontSize * 10) && TextGetSize(text, w, h))
        dashTextRight = MathMax(dashTextRight, x + (int)w);
    else
        dashTextRight = MathMax(dashTextRight, x + StringLen(text) * fontSize * 3 / 4);
}

// Dark panel behind the dashboard. Created before any label so it is drawn underneath them.
void DrawDashboardBackground(int x, int y, int width, int height, color bg, color border)
{
    string name = "NyaoDash_Bg";
    if(ObjectFind(0, name) < 0)
    {
        ObjectsDeleteAll(0, "NyaoDash_");                 // labels made before the panel would sit under it
        ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, MathMax(width, 10));
    ObjectSetInteger(0, name, OBJPROP_YSIZE, MathMax(height, 10));
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
    ObjectSetInteger(0, name, OBJPROP_COLOR, border);
}

// +------------------------------------------------------------------+
// | Dashboard: what the next bar's entry decision would say          |
// | The same gates, in the same order, as CheckForTradingSignal ->   |
// | DirectionSignal -> OpenPosition. "" = this direction is ready.   |
// +------------------------------------------------------------------+
string DashboardEntryGate(bool isBuy, EntryScore &e, string riskBlock)
{
    if(!(isBuy ? EnableBuyOrders : EnableSellOrders)) return isBuy ? "buys disabled" : "sells disabled";
    string why = GetEntryBlockReason(true);               // equity stops, pauses, hours, market close
    if(why != "") return why;
    double cap = SpreadCapPoints();
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if(cap > 0 && spread > cap) return StringFormat("spread %d pts > cap %.0f", (int)spread, cap);
    why = EntryConditionsBlock(isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL,
                               SymbolInfoDouble(_Symbol, isBuy ? SYMBOL_ASK : SYMBOL_BID));
    if(why != "") return why;
    if(e.strength.deadMarket) return "dead market (ATR below MinVolRatioToTrade)";
    if(e.score < e.threshold) return StringFormat("score %.2f below %.2f", e.score, e.threshold);
    if(CountLosingPositions() >= MaxHoldingLossPositions)
        return StringFormat("%d losing positions held (max %d)", CountLosingPositions(), MaxHoldingLossPositions);
    if(CountOpenOrders() >= MaxOpenOrders) return StringFormat("%d positions open (max %d)", CountOpenOrders(), MaxOpenOrders);
    return riskBlock;
}

// Score components for the dashboard (the log keeps the full reasoning with the smoothing settings)
string DashReasonText(SignalStrength &s)
{
    if(ScoreModel == SCORE_TREND)
        return StringFormat("Rng:%+.2f EMA:%+.2f Eff:%+.2f Mom:%+.2f | Vel:%.2f%s", s.trendRange, s.trendEma,
                            s.trendEfficiency, s.trendMomentum, s.normalizedVelocity, s.deadMarket ? " DEAD" : "");
    return StringFormat("T:%.1f M:%.1f(Imp:%.2f) C:%.1f P:%.1f V:%.1f | Vel:%.2f%s", s.trendScore, s.momentumScore,
                        s.impulseStrength, s.chopScore, s.peakScore, s.volatilityScore, s.normalizedVelocity,
                        s.deadMarket ? " DEAD" : "");
}

// $1.23 / -$1.23
string Usd(double v)
{
    return (v < 0 ? "-$" : "$") + DoubleToString(MathAbs(v), 2);
}

string EntryLineText(EntryScore &e)
{
    string parts = "";
    if(e.candleBoost > 0) parts += StringFormat("+%.1f candles", e.candleBoost);
    if(e.ddBoost > 0)     parts += (parts == "" ? "" : ", ") + StringFormat("+%.1f DD", e.ddBoost);
    if(e.penalty > 0)     parts += (parts == "" ? "" : ", ") + StringFormat("-%.1f losing", e.penalty);
    return StringFormat("Entry: %.2f / need %.2f", e.score, e.threshold) + (parts == "" ? "" : " (" + parts + ")");
}

string GateLineText(string gate)
{
    if(gate != "") return "> Blocked: " + gate;
    return streakPaused ? "> Ready: paper trade at the next bar (loss-streak pause)" : "> Ready: enters at the next bar";
}

color GateLineColor(string gate)
{
    if(gate == "") return clrLime;
    return (StringFind(gate, "score ") == 0) ? clrGray : clrOrange;   // a low score is the normal waiting state
}

void UpdateDashboard()
{
    // Nobody can see the chart in a non-visual backtest / optimization - skip the work
    if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;

    // Redraw at most once per second (it was every tick, incl. a full history scan)
    ulong nowMs = GetTickCount64();
    if(lastDashboardMs != 0 && nowMs - lastDashboardMs < 1000) return;
    lastDashboardMs = nowMs;

    // Clear old comment based dashboard
    Comment("");

    // Background first, so every label is drawn on top of it (sized to the content at the end)
    if(ObjectFind(0, "NyaoDash_Bg") < 0) DrawDashboardBackground(10, 10, 10, 10, C'30,30,30', clrGold);
    dashTextRight = 0;

    // Layout Constants
    int startX = 20;
    int startY = 36;                                      // panel top at 30 px: below the chart's symbol / OHLC line
    int lineHeight = 18;
    int headersize = 10;
    int textsize = 9;
    int detailsSize = 8;
    
    color colorHeader = clrGold;
    color colorText = clrWhite;
    color colorBuy = clrLime;
    color colorSell = clrRed;
    color colorNeutral = clrGray;
    color colorBg = C'30,30,30';
    color colorBorder = clrGold;

    int currentY = startY;

    // Header
    DrawDashboardLabel("NyaoDash_Title", EA_TITLE, startX, currentY, 11, colorHeader, true);
    currentY += lineHeight + 5;

    // Lot the next entry would use (risk sizing), or why none can be opened
    string lotText, riskBlock = "";
    bool riskHigh = false;                                               // min lot traded above RiskPerTradePct
    double dashEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dashSl = GetSLPoints(BaseLotSize);
    if(RiskSizingApplies() && dashSl > 0)
    {
        double lossAtMinLot, riskMoney;
        double lot = RiskSizedLot(dashSl * (1 + CheckpointSkipsFor(dashSl)), lossAtMinLot, riskMoney);
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double pctAtMin = (dashEquity > 0) ? 100.0 * lossAtMinLot / dashEquity : 0;
        if(lot < 0)
            lotText = "Lot: waiting for symbol data";
        else if(lot == 0)
        {
            riskBlock = StringFormat("account too small: %.2f lot risks %.1f%% > %.2f%%", minLot, pctAtMin, MaxTradeRiskPct());
            lotText = StringFormat("Lot: NONE - %.2f lot risks $%.2f (%.1f%%) > %.2f%%, needs ~$%.0f",
                                   minLot, lossAtMinLot, pctAtMin, MaxTradeRiskPct(), lossAtMinLot / (MaxTradeRiskPct() / 100.0));
        }
        else if(lossAtMinLot > riskMoney)
        {
            riskHigh = true;
            lotText = StringFormat("Lot: %.2f (risks $%.2f = %.2f%%, above %.2f%%; max %.2f%%)", lot, lossAtMinLot,
                                   pctAtMin, RiskPerTradePct, MaxRiskPerTradePct);
        }
        else
            lotText = StringFormat("Lot: %.2f (risks $%.2f = %.2f%% at the stop)", lot, lossAtMinLot / minLot * lot,
                                   pctAtMin / minLot * lot);
    }
    else
        lotText = StringFormat("Lot: %.2f (fixed BaseLotSize)", BaseLotSize);

    // Status logic (hard stops first, then pauses with their reasons, then soft blocks)
    string status = "Active";
    color statusColor = clrLime;
    if(targetEquityReached) { status = "STOPPED (Target)"; statusColor = clrRed; }
    else if(minimumEquityReached) { status = "STOPPED (Min Equity)"; statusColor = clrRed; }
    else if(minEquityTriggersExceeded) { status = "STOPPED (Max Triggers)"; statusColor = clrRed; }
    else if(IsPaused()) { status = "PAUSED: " + GetPauseReasons() + " (" + IntegerToString(PauseMinutesRemaining()) + "m)"; statusColor = clrOrange; }
    else if(isOutsideTradingHours) { status = "Closed (Time)"; statusColor = clrGray; }
    else if(isNearMarketClose) { status = "No Entries (Market Closing)"; statusColor = clrGray; }
    else if(isLeverageDiffFromInitial) { status = "PAUSED (Leverage Changed)"; statusColor = clrOrange; }
    else if(streakPaused) { status = StringFormat("PAUSED (Loss Streak %d - paper %s)", streakLosses, paperDir > 0 ? "BUY open" : paperDir < 0 ? "SELL open" : "waiting"); statusColor = clrOrange; }
    else if(riskBlock != "") { status = "No Entries (Account Too Small)"; statusColor = clrOrange; }

    DrawDashboardLabel("NyaoDash_Status", "Status: " + status, startX, currentY, textsize, statusColor, true);
    currentY += lineHeight;

    // Account Info
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double equityDrop = (peakEquity > 0) ? ((peakEquity - equity) / peakEquity) * 100.0 : 0.0;
    
    DrawDashboardLabel("NyaoDash_Bal", "Balance: " + Usd(balance), startX, currentY, textsize, colorText);
    currentY += lineHeight;
    DrawDashboardLabel("NyaoDash_Eq", "Equity: " + Usd(equity), startX, currentY, textsize, colorText);
    currentY += lineHeight;
    DrawDashboardLabel("NyaoDash_Peak", "Peak: " + Usd(peakEquity) + StringFormat(" (Drop: %.1f%%)", equityDrop), startX, currentY, textsize, colorText);
    currentY += lineHeight + 5;

    // Hedge Chain status (only when feature enabled)
    if(EnableHedgeChain)
    {
        // Count distinct active chains, total chain legs, and deepest cycle in progress
        ulong dashIds[];
        int dashChains = 0;
        int dashLegs = 0;
        int dashMaxCycle = 0;
        for(int h = 0; h < managedPositionCount; h++)
        {
            ulong r = managedPositions[h].chainId;
            if(r == 0) continue;
            dashLegs++;
            if(managedPositions[h].cycleNum > dashMaxCycle) dashMaxCycle = managedPositions[h].cycleNum;
            bool seen = false;
            for(int k = 0; k < dashChains; k++) if(dashIds[k] == r) { seen = true; break; }
            if(!seen) { ArrayResize(dashIds, dashChains + 1); dashIds[dashChains++] = r; }
        }

        string lotsCap = (HedgeMaxTotalLots > 0) ? DoubleToString(HedgeMaxTotalLots, 2) : "-";
        DrawDashboardLabel("NyaoDash_Hedge",
                           StringFormat("Hedge Chains: %d (legs %d, lots %.2f/%s, cycle %d/%d)", dashChains, dashLegs,
                                        ActiveChainLots(), lotsCap, dashMaxCycle,
                                        (HedgeMaxCycles > 0 ? HedgeMaxCycles : 0)),
                           startX, currentY, textsize, dashChains > 0 ? clrOrange : colorText);
        currentY += lineHeight + 5;
    }
    else
    {
        // Hide stale label when feature is toggled off
        ObjectDelete(0, "NyaoDash_Hedge");
    }

    // Signal Strength: the live score, the entry decision (closed bars, losing-position penalty,
    // boosted threshold) and the first gate that blocks the next entry
    SignalStrength buyStrength = GetSignalStrength(ORDER_TYPE_BUY);
    SignalStrength sellStrength = GetSignalStrength(ORDER_TYPE_SELL);

    quietLog = true;                                      // re-running the entry checks must not spam the log
    EntryScore buyEntry, sellEntry;
    ComputeEntryScore(true, buyEntry);
    ComputeEntryScore(false, sellEntry);
    string buyGate  = DashboardEntryGate(true, buyEntry, riskBlock);
    string sellGate = DashboardEntryGate(false, sellEntry, riskBlock);
    quietLog = false;

    // Labels of the former layout
    ObjectDelete(0, "NyaoDash_ReqBuy");
    ObjectDelete(0, "NyaoDash_ReqSell");
    ObjectDelete(0, "NyaoDash_CurrentBuy");
    ObjectDelete(0, "NyaoDash_CurrentSell");

    DrawDashboardLabel("NyaoDash_SigHead", "SIGNAL STRENGTH:", startX, currentY, headersize, colorHeader, true);
    currentY += lineHeight;

    DrawDashboardLabel("NyaoDash_Lot", lotText, startX, currentY, detailsSize, (riskBlock != "" || riskHigh) ? clrOrange : colorText);
    currentY += lineHeight;

    // Buy Row
    string buyText = StringFormat("BUY SCORE: %.2f", buyStrength.finalScore);
    DrawDashboardLabel("NyaoDash_Buy", buyText, startX, currentY, textsize, buyStrength.finalScore > sellStrength.finalScore ? colorBuy : colorText, true);
    currentY += lineHeight;

    DrawDashboardLabel("NyaoDash_BuyEntry", EntryLineText(buyEntry), startX, currentY, detailsSize, colorText);
    currentY += lineHeight;

    DrawDashboardLabel("NyaoDash_BuyGate", GateLineText(buyGate), startX, currentY, detailsSize, GateLineColor(buyGate));
    currentY += lineHeight;

    string buyDet = DashReasonText(buyStrength);
    DrawDashboardLabel("NyaoDash_BuyDet", buyDet, startX, currentY, detailsSize, colorText);
    currentY += lineHeight + 2;

    // Sell Row
    string sellText = StringFormat("SELL SCORE: %.2f", sellStrength.finalScore);
    DrawDashboardLabel("NyaoDash_Sell", sellText, startX, currentY, textsize, sellStrength.finalScore > buyStrength.finalScore ? colorSell : colorText, true);
    currentY += lineHeight;

    DrawDashboardLabel("NyaoDash_SellEntry", EntryLineText(sellEntry), startX, currentY, detailsSize, colorText);
    currentY += lineHeight;

    DrawDashboardLabel("NyaoDash_SellGate", GateLineText(sellGate), startX, currentY, detailsSize, GateLineColor(sellGate));
    currentY += lineHeight;

    string sellDet = DashReasonText(sellStrength);
    DrawDashboardLabel("NyaoDash_SellDet", sellDet, startX, currentY, detailsSize, colorText);
    currentY += lineHeight + 10;

    // Statistics
    TradeStats daily, allTime;
    GetTradeStats(daily, allTime);
    double allTimeNetProfit = allTime.profit + allTime.loss;
    
    DrawDashboardLabel("NyaoDash_StatHead", "STATISTICS:", startX, currentY, headersize, colorHeader, true);
    currentY += lineHeight;
    
    DrawDashboardLabel("NyaoDash_Trades", StringFormat("Trades: %d (W:%d / L:%d)", allTime.count, allTime.won, allTime.lost), startX, currentY, textsize, colorText);
    currentY += lineHeight;

    DrawDashboardLabel("NyaoDash_PL", "Profit: " + Usd(allTime.profit) + " | Loss: " + Usd(allTime.loss), startX, currentY, textsize, colorText);
    currentY += lineHeight;

    // Win rate alone hides a small-wins / big-losses payoff - show the numbers that decide it
    DrawDashboardLabel("NyaoDash_AvgWL", "Avg Win: " + Usd(allTime.avgProfit) + " | Avg Loss: " + Usd(allTime.avgLoss),
                       startX, currentY, textsize, colorText);
    currentY += lineHeight;

    double expectancy = TradeExpectancy(allTime);
    DrawDashboardLabel("NyaoDash_Expect", "Expectancy: " + Usd(expectancy) + "/trade | PF: " + ProfitFactorText(allTime),
                       startX, currentY, textsize, expectancy >= 0 ? colorText : colorSell);
    currentY += lineHeight;

    color profitColor = allTimeNetProfit >= 0 ? colorBuy : colorSell;
    DrawDashboardLabel("NyaoDash_Net", "NET PROFIT: " + Usd(allTimeNetProfit), startX, currentY, textsize, profitColor, true);

    // Panel around everything drawn above
    int pad = 10;
    DrawDashboardBackground(startX - pad, startY - pad, dashTextRight - startX + 2 * pad,
                            currentY + lineHeight - startY + 2 * pad, colorBg, colorBorder);
    ChartRedraw(0);
}
// +------------------------------------------------------------------+