// +------------------------------------------------------------------+
// | Nyao Scalper v36.0                                               |
// | Indicator-Based Signal Strength EA with Comprehensive Features   |
// | © Copyright Nyao Scalper by Elriz Wiraswara                      |
// +------------------------------------------------------------------+
#property copyright "© Copyright Nyao Scalper by Elriz Wiraswara"
#property version   "36.0"
#property description "Auto Trading EA Robot with Comprehensive Features"
#property description ""
#property description "This is an open-source project for educational and experimental purposes only"
#property description "Source: https://github.com/elrizwiraswara/nyao_scalper_mt5 [MIT License]"
#property description ""
#property description "No guarantee of profitability. Use at your own risk. Past performance ≠ future results"
#property description "Built with significant effort, please use and share respectfully"
#property description "I do not sell this EA myself. If sold under my name, treat it as a scam and report it"
#property description "Named after my cat MaoMao, he says 'Nyao!' when spotting good trades"
#property strict

// Windows API for Algo Trading Button Control
#define MT_WMCMD_EXPERTS 32851
#define WM_COMMAND 0x0111
#define GA_ROOT 2
#include <WinAPI\winapi.mqh>

// Dialog Controls for Password Input
#include <Controls\Dialog.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>

// Print wrapper with logging control
#define LogPrint if(EnableLogging) Print

enum ENUM_INPUT_TYPE
{
    INPUT_DOLLAR,                                         // Dollar Amount
    INPUT_PERCENT,                                        // Percent of Equity
    INPUT_POINTS                                          // Points
};

input group "+-----------------------------------------+"
input group " Nyao Scalper v36.0"
input group " © Copyright Nyao Scalper by Elriz Wiraswara"
input group "+-----------------------------------------+"

// +------------------------------------------------------------------+
// | Input Parameters                                                 |
// +------------------------------------------------------------------+
input group "📊 Indicator Settings"
input int DirectionalBodyLookback = 20;                   // Lookback for directional body analysis
input int EMAFastPeriod = 6;                              // EMA Fast Period
input int EMASlowPeriod = 15;                             // EMA Slow Period
input int RSIPeriod = 8;                                  // RSI Period
input int ATRPeriod = 8;                                  // ATR Period
input int ATRAvgLookback = 20;                            // ATR Average Lookback
input int ImpulseLookback = 4;                            // Impulse Lookback
input double ImpulseBoostWeight = 1.0;                    // Impulse Boost Weight
input double VelocityWindow = 2.0;                        // Velocity Window (Score Delta)
input double VelocitySizeWeight = 1.0;                    // Velocity Weight for Position Sizing
input int RSIOverbought = 80;                             // RSI Overbought Level (Max Buy)
input int RSIOversold = 20;                               // RSI Oversold Level (Min Sell)
input int RSIMomentumBuy = 60;                            // RSI Momentum Buy Trigger
input int RSIMomentumSell = 40;                           // RSI Momentum Sell Trigger

input group "⚖️ Score Weight Settings"
input double TrendWeight = 1.5;                           // Trend Alignment Initial Weight
input double SlopeWeight = 1.5;                           // Trend Slope Confirmation Weight
input double MomentumBaseWeight = 1.0;                    // Momentum Base Weight (RSI Sweet Spot)
input double MomentumTriggerWeight = 0.5;                 // Momentum Trigger Weight (RSI Breakout)
input double BodyMomentumWeight = 1.5;                    // Body Momentum Weight
input double ChopScoreHigh = 2.0;                         // Chop Score High (Strong Trend)
input double ChopScoreMed = 1.0;                          // Chop Score Med (Weak Trend)
input double ChopScoreLow = 0.5;                          // Chop Score Low (Chop Risk)
input double VolatilityScoreHigh = 1.0;                   // Volatility Score High
input double VolatilityScoreLow = 0.5;                    // Volatility Score Low
input double PeakScoreWeight = 1.0;                       // Peak Breakout Score Weight
input double WickRejectionWeight = 1.0;                   // Wick Rejection Penalty Weight
input double MinBodyRatio = 1.5;                          // Min Body Ratio for Wick Calculation

input group "📝 Order & Position Settings"
input bool EnableBuyOrders = true;                        // Enable Buy Orders
input bool EnableSellOrders = true;                       // Enable Sell Orders
input double BaseLotSize = 0.01;                          // Base Lot Size
input int MaxOpenOrders = 8;                              // Max Consecutive Open Orders
input double ZonePoints = 500;                            // Zone Points to Avoid Duplicate Signals
input double BuyDuplicateMultiplier  = 1.5;               // Min Distance Multiplier to Avoid Duplicate Buy Signals
input double SellDuplicateMultiplier = 1.5;               // Min Distance Multiplier to Avoid Duplicate Sell Signals
input double MinBreakEvenProfit = 0.5;                    // Min Profit to Trigger Break-Even ($)
input double ProfitThresholdMultiplier = 1.5;             // Threshold Multiplier for Min Break-Even Profit
input double LossThresholdMultiplier = 2.0;               // Threshold Multiplier for Max Break-Even Loss
input double MinBuySignalScore = 6.0;                     // Min Signal Strength Score to Buy (0.0 - 10.0)
input double MinSellSignalScore = 6.0;                    // Min Signal Strength Score to Sell (0.0 - 10.0)

input group "🛡️ Signal Dampening Settings"
input bool EnableSignalDampening = true;                 // Enable Position-Aware Signal Dampening
input int MaxLosingPositionsSameDir = 2;                // Max Losing Positions in Same Direction Before Block
input double LosingPosScorePenalty = 1.5;                  // Score Penalty Per Losing Same-Direction Position
input double DrawdownThresholdPct = 3.0;                   // Equity Drawdown % to Raise Signal Threshold
input double DrawdownScoreBoost = 2.0;                     // Extra Score Required During Drawdown
input int ConsecutiveLossCooldownBars = 3;              // Cooldown Bars After 3+ Consecutive Losses

input group "🩺 Loss Management Settings"
input bool EnableLossManagement = true;                   // Enable Adaptive Loss Management
input int MaxHoldingLossPositions = 3;                    // Max Losing Positions to Hold
input double MinHealthScore = 0.40;                       // Min Health Score to Hold Position (0.0 - 1.0)
input double MaxAdverseATR = 1.5;                         // Max Adverse Movement in ATR Multiples
input double HealthTrendWeight = 0.40;                    // Health Weight: Trend Alignment
input double HealthRSIWeight = 0.25;                      // Health Weight: RSI Zone
input double HealthATRWeight = 0.25;                      // Health Weight: Adverse Excursion
input double HealthSwingWeight = 0.10;                    // Health Weight: Swing Level
input double HealthRSIBuyMin = 45.0;                      // Health RSI Min for Buy Position
input double HealthRSISellMax = 55.0;                     // Health RSI Max for Sell Position
input int HealthSwingLookback = 20;                       // Swing Level Lookback Bars
input int HealthGraceBars = 2;                            // Grace Period (Bars Before Health Check)
input bool EnablePartialClose = true;                     // Enable Scaled Partial Close on Signal Decay
input double PartialClose75Pct = 0.25;                    // Close % When Signal Drops to 75% of Initial
input double PartialClose50Pct = 0.50;                    // Close % When Signal Drops to 50% of Initial
input double PartialClose25Pct = 1.00;                    // Close % When Signal Drops to 25% of Initial (Remaining)
input bool EnableHealthSLTightening = true;               // Tighten SL as Health Weakens
input double SLTightenATRMultiplier = 1.5;                // ATR Multiplier for Tightened SL
input double SLTightenMinHealthPct = 0.60;                // Start Tightening Below This Health %
input bool EnableBreakEvenOnSpread = true;                // Lock SL to Entry After Profit > Spread Cost
input double BreakEvenSpreadMultiplier = 1.5;             // Spread Multiplier for Break-Even Lock Trigger
input bool EnableVirtualSLReentry = true;                 // Close at Threshold Then Re-evaluate & Re-enter
input double ReentryMinSignalPct = 0.75;                  // Min % of Entry Signal Required to Re-enter

input group "🧮 Dynamic Lot Sizing Settings"
input bool EnableDynamicLots = true;                      // Enable Dynamic Lot Sizing
input double EquityDropPercent = 10.0;                    // Equity Drop % per Lot Step
input double LotStepSize = 0.01;                          // Lot Increase Step Size
input double MaxLotSize = 0.05;                           // Max Lot Size
input double MinSignalStrengthForLot = 10.0;              // Min Signal Score for Lot Increase

input group "🏦 Equity Settings"
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
input bool EnableTakeProfit = false;                      // Enable Take Profit
input ENUM_INPUT_TYPE TPInputType = INPUT_DOLLAR;         // TP Input Type
input double TPValue = 10.0;                              // TP Value

input group "📉 Stop Loss Settings"
input bool EnableStopLoss = true;                         // Enable Stop Loss
input ENUM_INPUT_TYPE SLInputType = INPUT_PERCENT;        // SL Input Type
input double SLValue = 10.0;                              // SL Value

input group "💸 Trailing TP/SL Settings"
input bool EnableTrailing = true;                         // Enable Trailing TP/SL
input bool TrailingEnableBreakEvenLock = true;            // Enable Trailing Break-Even Lock
input bool TrailingSLOnProfitableOnly = true;             // Trailing SL on Profitable Position Only
input bool EnableAdaptiveTP = true;                       // Enable Adaptive TP
input bool EnableAdaptiveSL = true;                       // Enable Adaptive SL
input ENUM_INPUT_TYPE TSInputType = INPUT_DOLLAR;         // Trailing Distance Input Type
input double TrailingDistanceValue = 0.2;                 // Trailing Distance Value
input double TrailingValueMultiplier = 0.2;               // Trailing Value Multiplier

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
input bool EnableLogging = false;                         // Enable EA Logging (May cause lag)

// +------------------------------------------------------------------+
// | Global Variables                                                 |
// +------------------------------------------------------------------+
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
double lastPeakEquity = 0;                                // Last recorded peak equity for drawdown calculations
bool targetEquityReached = false;                         // Flags for target/minimum equity reached
bool minimumEquityReached = false;                        // Flags for target/minimum equity reached
bool minEquityTriggersExceeded = false;                   // Flag when max triggers exceeded
int minEquityTriggerCount = 0;                            // Counter for MinEquityPercent triggers
bool isPaused = false;                                    // Trading pause state
int currentPauseDuration = 0;                             // Current pause duration in minutes
datetime pauseStartTime = 0;                              // Pause start time
bool isOutsideTradingHours = false;                       // Flag when outside trading hours
bool isLeverageDiffFromInitial = false;                   // Flag for leverage changed
bool isNearMarketClose = false;                           // Flag for near market close time
ulong lastProcessedNewsEventID = 0;                       // Last processed news event ID
string symbolBaseCurrency = "";                           // Base currency of the symbol
string symbolQuoteCurrency = "";                          // Quote currency of the symbol
long initialLeverage = 0;                                 // Initial Account Leverage
bool isOrderSendLocked = false;                           // Flag for locking OrderSend execution
bool marketCloseAlertSent = false;                        // Flag for near market close time
bool algoTradingStatus = false;                           // Flag for algo trading status

// Normalized Health Weights (computed in InitializeEA)
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


int emaFastHandle = INVALID_HANDLE;                      // Handle for Fast EMA
int emaSlowHandle = INVALID_HANDLE;                      // Handle for Slow EMA
int rsiHandle = INVALID_HANDLE;                          // Handle for RSI
int atrSignalHandle = INVALID_HANDLE;                    // Handle for Signal ATR

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
    double velocity;                                      // Current Score - Previous Score
    double normalizedVelocity;                            // 0.0-1.0 Normalized Velocity
    string reasoning;                                     // Detailed explanation
};

// Position Health Structure - Measurement-Based Revalidation
// Evaluates whether a position's trade thesis is still valid
struct PositionHealth
{
    double healthScore;                                   // 0.0 (dead) to 1.0 (fully healthy)
    bool   trendValid;                                    // EMA still aligned with position direction?
    bool   momentumValid;                                 // RSI still in favorable zone?
    double adverseATR;                                    // How many ATRs moved against position
    bool   swingValid;                                    // Price hasn't broken swing level?
    bool   inGracePeriod;                                 // Position too new for health check?
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
    int    partialCloseLevel;                             // 0=none, 1=75% triggered, 2=50% triggered, 3=fully closed
    bool   breakEvenLocked;                               // Whether SL has been moved to break-even by loss mgmt
};

// Managed positions array
ManagedPosition managedPositions[];
int managedPositionCount = 0;

// Internal Position Counters (for O(1) checks)
int buyPositionCount = 0;
int sellPositionCount = 0;

// Candle-based Position Counters
datetime currentBarTime = 0;
int buysOnCurrentBar = 0;
int sellsOnCurrentBar = 0;

// Signal Dampening Globals
int consecutiveLossCount = 0;                             // Track consecutive closing losses
datetime cooldownUntilBarTime = 0;                        // Bar time after which cooldown expires

// Last Position Tracking (for O(1) duplicate checks)
datetime lastBuyTime = 0;
double lastBuyPrice = 0;
datetime lastSellTime = 0;
double lastSellPrice = 0;

// Last signal tracking per candle 
double lastBuySignalScore = 0; 
double lastBuySignalScorePrev = 0; 
double lastBuyVelocity = 0; 
double lastBuyNormalizedVelocity = 0; 

double lastSellSignalScore = 0; 
double lastSellSignalScorePrev = 0; 
double lastSellVelocity = 0; 
double lastSellNormalizedVelocity = 0; 

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
// | Create Password Dialog                                            |
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
    
    // Continue with normal initialization
    return(InitializeEA());
}

// +------------------------------------------------------------------+
// | Full EA Initialization                                            |
// +------------------------------------------------------------------+
int InitializeEA()
{
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

    if(!EnableBuyOrders && !EnableSellOrders)
    {
        Alert("ERROR: Both Buy and Sell orders are disabled! EA will not trade!");
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



    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    lastPeakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    targetEquityReached = false;
    minimumEquityReached = false;
    minEquityTriggersExceeded = false;
    minEquityTriggerCount = 0;
    isPaused = false;
    pauseStartTime = 0;
    lastProcessedNewsEventID = 0;
    startTime = TimeCurrent();
    lastDailyReportTime = 0;
    lastReportEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    totalPauseCount = 0;
    totalPauseDurationMinutes = 0;
    symbolBaseCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
    symbolQuoteCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
    initialLeverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    isOrderSendLocked = false;
    algoTradingStatus = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
    
    // Initialize managed positions array
    ArrayResize(managedPositions, 0);
    managedPositionCount = 0;
    
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
        if(type == POSITION_TYPE_BUY) strength = GetSignalStrength(ORDER_TYPE_BUY, false);
        else strength = GetSignalStrength(ORDER_TYPE_SELL, false);
        
        initialScore = strength.finalScore;
        if(initialScore <= 0) initialScore = (type == POSITION_TYPE_BUY) ? MinBuySignalScore : MinSellSignalScore;
        
        RegisterManagedPosition(ticket, type, initialScore, posEntryPrice);

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
    
    Print("+-----------------------------------------+");
    Print("Nyao Scalper v36.0 Initialized Successfully");
    Print("+-----------------------------------------+");

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
    
    // Cleanup Dashboard Objects
    ObjectsDeleteAll(0, "NyaoDash_");
    Comment("");
    
    // Release ATR Handle

    IndicatorRelease(emaFastHandle);
    IndicatorRelease(emaSlowHandle);
    IndicatorRelease(rsiHandle);
    IndicatorRelease(atrSignalHandle);
    
    Print("Nyao Scalper v36.0 Deinitialized");
}

// +------------------------------------------------------------------+
// | Expert Tick Function                                             |
// +------------------------------------------------------------------+
void OnTick()
{   
    // Block trading until password is verified
    if(!passwordVerified) return;
    
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

    if(targetEquityReached || minimumEquityReached || minEquityTriggersExceeded) 
    {   
        // Close all positions and completely stop the EA
        CloseAllPositions();
        DisableAlgoTrading();
        LogPrint("[STOPPED] Trading stopped.");
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
        
        // Update Buy Stats
        SignalStrength buyStr = GetSignalStrength(ORDER_TYPE_BUY, false); // Index 1
        lastBuySignalScore = buyStr.finalScore;
        
        // Update Sell Stats
        SignalStrength sellStr = GetSignalStrength(ORDER_TYPE_SELL, false); // Index 1
        lastSellSignalScore = sellStr.finalScore;
        
        // Update Bar Time (will be updated in OpenPosition too, but good to have here)
        currentBarTime = currentBarTime;
        buysOnCurrentBar = 0;
        sellsOnCurrentBar = 0;
    }

    if (isOutsideTradingHours || isLeverageDiffFromInitial || isNearMarketClose)
    {   
        // Don't open new positions, but continue managing existing ones
        ManagePositions();
        // LogPrint("[PAUSED] Trading paused."); // Prevent LogPrint spam on every tick
        UpdateDashboard();
        return;
    }
    
    // Check for high-impact news events
    CheckHighImpactNews();
    
    // Check pause duration 
    if (isPaused)
    {
        datetime currentTime = TimeTradeServer();
        int elapsedSeconds = (int)(currentTime - pauseStartTime);
        int pauseDurationSeconds = currentPauseDuration * 60;
        
        if(currentPauseDuration == 0 || elapsedSeconds < pauseDurationSeconds)
        {
            // Don't open new positions, but continue managing existing ones
            ManagePositions();
            // LogPrint("[PAUSED] Paused. Time remaining: ", (pauseDurationSeconds - elapsedSeconds) / 60, " minute(s)"); // Prevent LogPrint spam on every tick
            UpdateDashboard();
            return;  // EXIT - prevent all new orders while paused
        }
        else
        {
            // Pause period ended - reset flag and resume trading
            isPaused = false;

            double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

            LogPrint("+-----------------------------------------+");
            LogPrint("PAUSE PERIOD ENDED");
            LogPrint("Trading RESUMED after ", currentPauseDuration, " minutes");
            LogPrint("Current Equity: $", currentEquity);
            LogPrint("+-----------------------------------------+");
            
            // Send Discord alert for trading resumed
            if(EnableDiscordAlerts)
            {   
                string alertMsg = "**Instrument:** " + _Symbol + "\n";
                alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
                alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                alertMsg += "**Pause Duration:** " + IntegerToString(currentPauseDuration) + " minutes\n";
                alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
                alertMsg += "**Action:** Trading Resumed";
                
                SendDiscordAlert("▶️ TRADING RESUMED!", alertMsg, 3066993); // Blue color
            }
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

// +------------------------------------------------------------------+
// | Chart Event Handler - Password Dialog                             |
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
                
                // Complete initialization
                if(InitializeEA() != INIT_SUCCEEDED)
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
// | Position Loss State - Aggregate loss metrics for a direction      |
// +------------------------------------------------------------------+
struct PositionLossState
{
    int   losingCount;                                    // Number of losing positions in this direction
    int   totalCount;                                     // Total positions in this direction
    double totalUnrealizedLoss;                           // Sum of unrealized losses (negative = loss)
    double worstLossPct;                                  // Worst single position loss as % of entry
};

// +------------------------------------------------------------------+
// | Get Open Position Loss State for a Direction                      |
// | Scans all open managed positions and returns aggregate loss info  |
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
// | Check For Trading Signals                                        |
// +------------------------------------------------------------------+
void CheckForTradingSignal()
{   
    // Check Signals
    double buySignal = BuySignal();
    double sellSignal = SellSignal();

    // Process signals
    if (buySignal > sellSignal)
    {
        if (!EnableBuyOrders) return;
        OpenPosition(ORDER_TYPE_BUY, buySignal);
    }
    else if (buySignal < sellSignal)
    {
        if (!EnableSellOrders) return;
        OpenPosition(ORDER_TYPE_SELL, sellSignal);
    }
}

// Buy Signal
double BuySignal()
{   
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Check strict conditions (limits & distance) first
    if(!CheckBuyConditions(currentPrice)) return 0;

    // Calculate signal strength using closed candle (index 1) for safety
    SignalStrength strength = GetSignalStrength(ORDER_TYPE_BUY, false);

    // SIGNAL DAMPENING: Apply score penalty and drawdown gating
    double adjustedScore = strength.finalScore;
    double adjustedThreshold = MinBuySignalScore;

    if(EnableSignalDampening)
    {
        // A. Score Penalty: reduce score based on losing same-direction positions
        PositionLossState lossState = GetOpenPositionLossState(POSITION_TYPE_BUY);
        if(lossState.losingCount > 0)
        {
            double penalty = lossState.losingCount * LosingPosScorePenalty;
            adjustedScore -= penalty;
            LogPrint("[DAMPENED] Buy score reduced by ", DoubleToString(penalty, 1), 
                     " (", lossState.losingCount, " losing buys). Raw: ", 
                     DoubleToString(strength.finalScore, 1), " -> Adjusted: ", 
                     DoubleToString(adjustedScore, 1));
        }
        
        // B. Drawdown Gate: raise threshold when account in drawdown
        if(peakEquity > 0)
        {
            double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
            double drawdownPct = ((peakEquity - currentEquity) / peakEquity) * 100.0;
            
            if(drawdownPct >= DrawdownThresholdPct)
            {
                adjustedThreshold += DrawdownScoreBoost;
                LogPrint("[DRAWDOWN GATE] Equity drawdown ", DoubleToString(drawdownPct, 1), 
                         "% >= ", DoubleToString(DrawdownThresholdPct, 1), 
                         "%. Buy threshold raised to ", DoubleToString(adjustedThreshold, 1));
            }
        }
    }

    if (adjustedScore >= adjustedThreshold) 
    {   
        LogPrint("BUY SIGNAL RECEIVED (Score: ", DoubleToString(strength.finalScore, 1), 
                 " | Adjusted: ", DoubleToString(adjustedScore, 1), 
                 " / Threshold: ", DoubleToString(adjustedThreshold, 1), ")");
        LogPrint("Details: Body=", DoubleToString(strength.bodySignal, _Digits),
                 ", AvgBody=", DoubleToString(strength.avgBody, _Digits),
                 ", Ratio=", DoubleToString(strength.ratio, 2),
                 ", PenBody=", DoubleToString(strength.penaltyBody, 1),
                 ", PenWick=", DoubleToString(strength.penaltyWick, 1));
        LogPrint("Reasoning: ", strength.reasoning);
        LogPrint("Price: ", currentPrice);

        return adjustedScore;
    }
    
    return 0;
}

// Sell Signal
double SellSignal()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Check strict conditions (limits & distance) first
    if(!CheckSellConditions(currentPrice)) return 0;

    // Calculate signal strength using closed candle (index 1) for safety
    SignalStrength strength = GetSignalStrength(ORDER_TYPE_SELL, false);

    // SIGNAL DAMPENING: Apply score penalty and drawdown gating
    double adjustedScore = strength.finalScore;
    double adjustedThreshold = MinSellSignalScore;

    if(EnableSignalDampening)
    {
        // A. Score Penalty: reduce score based on losing same-direction positions
        PositionLossState lossState = GetOpenPositionLossState(POSITION_TYPE_SELL);
        if(lossState.losingCount > 0)
        {
            double penalty = lossState.losingCount * LosingPosScorePenalty;
            adjustedScore -= penalty;
            LogPrint("[DAMPENED] Sell score reduced by ", DoubleToString(penalty, 1), 
                     " (", lossState.losingCount, " losing sells). Raw: ", 
                     DoubleToString(strength.finalScore, 1), " -> Adjusted: ", 
                     DoubleToString(adjustedScore, 1));
        }
        
        // B. Drawdown Gate: raise threshold when account in drawdown
        if(peakEquity > 0)
        {
            double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
            double drawdownPct = ((peakEquity - currentEquity) / peakEquity) * 100.0;
            
            if(drawdownPct >= DrawdownThresholdPct)
            {
                adjustedThreshold += DrawdownScoreBoost;
                LogPrint("[DRAWDOWN GATE] Equity drawdown ", DoubleToString(drawdownPct, 1), 
                         "% >= ", DoubleToString(DrawdownThresholdPct, 1), 
                         "%. Sell threshold raised to ", DoubleToString(adjustedThreshold, 1));
            }
        }
    }

    if (adjustedScore >= adjustedThreshold)
    {
        LogPrint("SELL SIGNAL RECEIVED (Score: ", DoubleToString(strength.finalScore, 1), 
                 " | Adjusted: ", DoubleToString(adjustedScore, 1), 
                 " / Threshold: ", DoubleToString(adjustedThreshold, 1), ")");
        LogPrint("Details: Body=", DoubleToString(strength.bodySignal, _Digits),
                 ", AvgBody=", DoubleToString(strength.avgBody, _Digits),
                 ", Ratio=", DoubleToString(strength.ratio, 2),
                 ", PenBody=", DoubleToString(strength.penaltyBody, 1),
                 ", PenWick=", DoubleToString(strength.penaltyWick, 1));
        LogPrint("Reasoning: ", strength.reasoning);
        LogPrint("Price: ", currentPrice);

        return adjustedScore;
    }
    
    return 0;
}

// FAST duplicate buy filter - O(1) using globals
// Returns true if conditions allow a trade.
bool CheckBuyConditions(double price)
{
    datetime currBarTime = iTime(_Symbol, _Period, 0);

    // Only 1 buy per candle
    int buysOnCandle = (currentBarTime == currBarTime) ? buysOnCurrentBar : 0;
    if(buysOnCandle >= 1)
    {
        return false;
    }
    
    // Prevent opposite direction trades on the same candle
    if(sellsOnCurrentBar > 0)
    {
        return false;
    }

    // SIGNAL DAMPENING: Hard block when too many losing buys are open
    if(EnableSignalDampening)
    {
        PositionLossState lossState = GetOpenPositionLossState(POSITION_TYPE_BUY);
        if(lossState.losingCount >= MaxLosingPositionsSameDir)
        {
            LogPrint("[DAMPENED] Buy BLOCKED: ", lossState.losingCount, 
                     " losing buys >= max ", MaxLosingPositionsSameDir);
            return false;
        }
    }

    // SIGNAL DAMPENING: Cooldown after consecutive losses
    if(EnableSignalDampening && cooldownUntilBarTime > 0)
    {
        if(currBarTime < cooldownUntilBarTime)
        {
            LogPrint("[COOLDOWN] Buy BLOCKED: cooldown active until ", 
                     TimeToString(cooldownUntilBarTime));
            return false;
        }
        else
        {
            cooldownUntilBarTime = 0; // Cooldown expired
        }
    }

    // Check minimum distance from last buy (duplicate signal filter)
    ulong lastTicket = GetLastPositionTicket(POSITION_TYPE_BUY);
    if(lastBuyTime > 0 && lastTicket > 0)
    {
        double minDistance = ZonePoints * _Point * BuyDuplicateMultiplier;
        double distance = MathAbs(price - lastBuyPrice);
        
        if(distance < minDistance)
        {
            return false;
        }
    }
    
    return true;
}

// FAST duplicate sell filter - O(1) using globals
// Returns true if conditions allow a trade.
bool CheckSellConditions(double price)
{
    datetime currBarTime = iTime(_Symbol, _Period, 0);
    
    // Only 1 sell per candle
    int sellsOnCandle = (currentBarTime == currBarTime) ? sellsOnCurrentBar : 0;
    if(sellsOnCandle >= 1)
    {
        return false;
    }

    // Prevent opposite direction trades on the same candle
    if(buysOnCurrentBar > 0)
    {
        return false;
    }

    // SIGNAL DAMPENING: Hard block when too many losing sells are open
    if(EnableSignalDampening)
    {
        PositionLossState lossState = GetOpenPositionLossState(POSITION_TYPE_SELL);
        if(lossState.losingCount >= MaxLosingPositionsSameDir)
        {
            LogPrint("[DAMPENED] Sell BLOCKED: ", lossState.losingCount, 
                     " losing sells >= max ", MaxLosingPositionsSameDir);
            return false;
        }
    }

    // SIGNAL DAMPENING: Cooldown after consecutive losses
    if(EnableSignalDampening && cooldownUntilBarTime > 0)
    {
        datetime currBarTimeSell = iTime(_Symbol, _Period, 0);
        if(currBarTimeSell < cooldownUntilBarTime)
        {
            LogPrint("[COOLDOWN] Sell BLOCKED: cooldown active until ", 
                     TimeToString(cooldownUntilBarTime));
            return false;
        }
        else
        {
            cooldownUntilBarTime = 0; // Cooldown expired
        }
    }

    // Check minimum distance from last sell (duplicate signal filter)
    ulong lastTicket = GetLastPositionTicket(POSITION_TYPE_SELL);
    if(lastSellTime > 0 && lastTicket > 0)
    {
        double minDistance = ZonePoints * _Point * SellDuplicateMultiplier;
        double distance = MathAbs(price - lastSellPrice);
        
        if(distance < minDistance)
        {
            return false;
        }
    }
    
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
}

// +------------------------------------------------------------------+
// | Signal Strength Analysis (Upgraded)                              |
// +------------------------------------------------------------------+
SignalStrength GetSignalStrength(ENUM_ORDER_TYPE orderType, bool includeCurrentCandle = false)
{
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
    strength.reasoning = "";
    
    // 1. Determine Signal Candle Index
    int signalIndex = includeCurrentCandle ? 0 : 1;
    
    // 2. Determine Logic Direction
    bool isBuy = (orderType == ORDER_TYPE_BUY);
    bool isSell = (orderType == ORDER_TYPE_SELL);
    
    double bufEMA_Fast[], bufEMA_Slow[], bufRSI[], bufATR[];
    ArraySetAsSeries(bufEMA_Fast, true);
    ArraySetAsSeries(bufEMA_Slow, true);
    ArraySetAsSeries(bufRSI, true);
    ArraySetAsSeries(bufATR, true);
    
    // Copy minimal buffers 
    int needed = MathMax(ImpulseLookback, MathMax(DirectionalBodyLookback, ATRAvgLookback)) + 5;
    if (needed < 30) needed = 30; // Safety buffer
    
    if(CopyBuffer(emaFastHandle, 0, signalIndex, 3, bufEMA_Fast) < 3) return strength;
    if(CopyBuffer(emaSlowHandle, 0, signalIndex, 3, bufEMA_Slow) < 3) return strength;
    if(CopyBuffer(rsiHandle, 0, signalIndex, 3, bufRSI) < 3) return strength;
    if(CopyBuffer(atrSignalHandle, 0, signalIndex, needed, bufATR) < needed) return strength; // Need more for ATR avg
    
    // Fetch Price Data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, _Period, signalIndex, needed, rates) < needed) return strength;

    // 1. TREND SCORE (Max 3)
    // Logic: EMA Alignment + Slope
    double emaFast = bufEMA_Fast[0];
    double emaSlow = bufEMA_Slow[0];
    double emaFastPrev = bufEMA_Fast[1];
    
    bool trendAligned = false;
    if (isBuy) trendAligned = (emaFast > emaSlow);
    else trendAligned = (emaFast < emaSlow);
    
    if (trendAligned) strength.trendScore += TrendWeight;
    
    // Slope confirmation
    bool slopeAligned = false;
    if (isBuy) slopeAligned = (emaFast > emaFastPrev);
    else slopeAligned = (emaFast < emaFastPrev);
    
    if (slopeAligned) strength.trendScore += SlopeWeight;
    
    // Cap Trend Score
    if(strength.trendScore > 3.0) strength.trendScore = 3.0;

    // 2. MOMENTUM SCORE (Max 3) + IMPULSE 
    // Calculate Base Body Strength
    double currentBody = MathAbs(rates[0].close - rates[0].open);
    double sumBody = 0;
    int validCandles = 0;
    for(int i=1; i<=DirectionalBodyLookback && i<needed; i++)
    {
        sumBody += MathAbs(rates[i].close - rates[i].open);
        validCandles++;
    }
    double avgRecentBody = (validCandles > 0) ? sumBody / validCandles : currentBody;
    
    // Base Momentum Score derived from RSI and Body
    double rsi = bufRSI[0];
    double baseMomentum = 0;
    
    if (isBuy)
    {
        if (rsi > 50 && rsi < RSIOverbought) baseMomentum += MomentumBaseWeight; // Sweet spot
        if (rsi > RSIMomentumBuy) baseMomentum += MomentumTriggerWeight;
        if (currentBody > avgRecentBody) baseMomentum += BodyMomentumWeight;
    }
    else
    {
        if (rsi < 50 && rsi > RSIOversold) baseMomentum += MomentumBaseWeight;
        if (rsi < RSIMomentumSell) baseMomentum += MomentumTriggerWeight;
        if (currentBody > avgRecentBody) baseMomentum += BodyMomentumWeight;
    }
    
    strength.momentumScore = baseMomentum; // Start with base
    
    // IMPULSE DETECTION LAYER
    // a. Body Acceleration
    double bodyAccel = 0;
    if (avgRecentBody > 0) bodyAccel = currentBody / avgRecentBody;
    if (bodyAccel > 3.0) bodyAccel = 3.0; // Cap internal accel
    
    // b. Range Expansion
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
    
    // c. Directional Continuity
    int sameDirCount = 0;
    for(int i=0; i<ImpulseLookback && i<needed; i++)
    {
        bool candleBullish = (rates[i].close > rates[i].open);
        bool candleBearish = (rates[i].close < rates[i].open);
        
        if (isBuy && candleBullish) sameDirCount++;
        else if (isSell && candleBearish) sameDirCount++;
        else break; // Consecutive chain broken
    }
    double continuityScore = (double)sameDirCount / ImpulseLookback;
    if(continuityScore > 1.0) continuityScore = 1.0;
    
    // Combine Impulse Strength
    // Formula: ImpulseStrength = clamp((0.5bodyAccel + 0.3rangeAccel + 0.2*continuityScore)/2.0, 0..1)
    // Note: Accel can be > 1, so division by 2.0 helps normalize, but we must clamp.
    double rawImpulse = (0.5 * bodyAccel + 0.3 * rangeAccel + 0.2 * continuityScore) / 2.0;
    strength.impulseStrength = rawImpulse;
    if (strength.impulseStrength > 1.0) strength.impulseStrength = 1.0;
    if (strength.impulseStrength < 0.0) strength.impulseStrength = 0.0;
    
    // Apply Impulse Boost to Momentum Score
    // MomentumScore = MomentumScore * (1 + ImpulseBoostWeight * ImpulseStrength)
    strength.momentumScore = strength.momentumScore * (1.0 + ImpulseBoostWeight * strength.impulseStrength);
    
    // Cap Momentum Score
    if (strength.momentumScore > 3.0) strength.momentumScore = 3.0;

    // 3. CHOP SCORE (Max 2)
    // Logic: Low ATR variance or Choppiness Index approximation
    double currentATR = bufATR[0];
    double avgATR = 0;
    // Calculate avgATR from buffer (using ATRAvgLookback)
    // We already copied enough ATR data
    if (needed >= ATRAvgLookback) {
         double sumATR = 0;
         for(int i=0; i<ATRAvgLookback && i<needed; i++) sumATR += bufATR[i];
         avgATR = sumATR / ATRAvgLookback;
    } else {
         avgATR = currentATR;
    }

    double volRatio = 0;
    if(avgATR > 0) volRatio = currentATR / avgATR;
    
    // If volume is rising (volRatio > 1.0), it's likely not chop
    if (volRatio > 1.0) strength.chopScore = ChopScoreHigh;
    else if (volRatio > 0.8) strength.chopScore = ChopScoreMed;
    else strength.chopScore = ChopScoreLow; // low volatility = chop risk
    
    if (strength.chopScore > 2.0) strength.chopScore = 2.0;

    // 4. PEAK & VOLATILITY SCORES (Max 1 each)
    strength.volatilityScore = (volRatio > 1.2) ? VolatilityScoreHigh : VolatilityScoreLow;
    
    bool breakout = false;
    double localExtreme = isBuy ? rates[1].high : rates[1].low; // Start with previous
    for(int i=2; i<=5; i++)
    {
         if(isBuy) localExtreme = MathMax(localExtreme, rates[i].high);
         else localExtreme = MathMin(localExtreme, rates[i].low);
    }
    
    if(isBuy && rates[0].close > localExtreme) breakout = true;
    if(isSell && rates[0].close < localExtreme) breakout = true;
    
    if(breakout) strength.peakScore = PeakScoreWeight;
    
    // 5. WICK / REJECTION PENALTY (Preserved/Updated)
    double maxOpenClose = MathMax(rates[0].open, rates[0].close);
    double minOpenClose = MathMin(rates[0].open, rates[0].close);
    strength.upperWick = rates[0].high - maxOpenClose;
    strength.lowerWick = minOpenClose - rates[0].low;
    strength.bodySignal = currentBody;
    strength.avgBody = avgRecentBody;
    
    // Use a smoothed body size to prevent division by zero explosion on doji candles
    double safeBody = MathMax(currentBody, avgRecentBody * MinBodyRatio); 
    
    if (safeBody > 0)
    {
        if (isBuy) strength.rejection = strength.upperWick / safeBody;
        else strength.rejection = strength.lowerWick / safeBody;
        
        strength.penaltyWick = strength.rejection * WickRejectionWeight;
    }

    // FINAL SCORE AGGREGATION
    double rawScore = strength.trendScore + strength.momentumScore + strength.chopScore + strength.peakScore + strength.volatilityScore;
    
    // Apply Penalties (Wick)
    rawScore -= strength.penaltyWick;
    
    // Clamp Final
    strength.finalScore = rawScore;
    if (strength.finalScore < 0) strength.finalScore = 0;
    if (strength.finalScore > 10.0) strength.finalScore = 10.0;
    
    // VELOCITY TRACKING
    double prevScore = 0;
    if (isBuy)
    {
        // Use Global History (Updated on New Bar)
        if (includeCurrentCandle) prevScore = lastBuySignalScore; // Index 0 vs Index 1
        else prevScore = lastBuySignalScorePrev; // Index 1 vs Index 2
    }
    else
    {
        if (includeCurrentCandle) prevScore = lastSellSignalScore;
        else prevScore = lastSellSignalScorePrev;
    }
    
    double velocity = strength.finalScore - prevScore;
    strength.velocity = velocity;
    
    // Normalized Velocity
    strength.normalizedVelocity = (velocity + VelocityWindow) / (2.0 * VelocityWindow);
    if(strength.normalizedVelocity < 0) strength.normalizedVelocity = 0;
    if(strength.normalizedVelocity > 1.0) strength.normalizedVelocity = 1.0;
    
    // Update Globals for Position Sizing (Latest Call Wins)
    if(isBuy) {
        lastBuyVelocity = strength.velocity;
        lastBuyNormalizedVelocity = strength.normalizedVelocity;
    } else {
        lastSellVelocity = strength.velocity;
        lastSellNormalizedVelocity = strength.normalizedVelocity;
    }
    
    // Debug Construction
    strength.reasoning = StringFormat("T:%.1f M:%.1f(Imp:%.2f) C:%.1f P:%.1f V:%.1f | Vel:%.2f", 
        strength.trendScore, strength.momentumScore, strength.impulseStrength,
        strength.chopScore, strength.peakScore, strength.volatilityScore, strength.normalizedVelocity);
        
    return strength;
}

// +------------------------------------------------------------------+
// | Evaluate Position Health - Measurement-Based Revalidation        |
// | Checks if the trade thesis is still valid                        |
// +------------------------------------------------------------------+
PositionHealth EvaluatePositionHealth(
    ENUM_POSITION_TYPE posType, 
    double entryPrice,
    datetime posOpenTime,
    double emaFast, 
    double emaSlow, 
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
    
    // 1. TREND ALIGNMENT (Graduated: binary — trend IS or ISN'T aligned)
    double trendScore = 0;
    if(isBuy)
        health.trendValid = (emaFast > emaSlow);
    else
        health.trendValid = (emaFast < emaSlow);
    
    if(health.trendValid)
        trendScore = 1.0;
    else
        health.reason += "Trend crossed against position. ";
    
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
    
    if(CopyBuffer(emaFastHandle, 0, 0, 2, bufEMA_Fast) < 2) return;
    if(CopyBuffer(emaSlowHandle, 0, 0, 2, bufEMA_Slow) < 2) return;
    if(CopyBuffer(rsiHandle, 0, 0, 2, bufRSI) < 2) return;
    if(CopyBuffer(atrSignalHandle, 0, 0, 2, bufATR) < 2) return;
    
    // Use closed candle values (index 1) for stability
    double emaFast   = bufEMA_Fast[1];
    double emaSlow   = bufEMA_Slow[1];
    double rsi       = bufRSI[1];
    double currentATR = bufATR[1];
    
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
        
        double entryPrice = managedPositions[posIndex].entryPrice;
        double initialScore = managedPositions[posIndex].signalScore;
        
        // Evaluate position health
        PositionHealth health = EvaluatePositionHealth(posType, entryPrice, posOpenTime, 
                                                       emaFast, emaSlow, rsi, currentATR, 
                                                       rates, ratesCopied);
        
        // Skip all management during grace period
        if(health.inGracePeriod) continue;
        
        // 1. BREAK-EVEN LOCK (when profit exceeds spread cost)
        if(EnableBreakEvenOnSpread && !managedPositions[posIndex].breakEvenLocked)
        {
            double spreadPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
            double spreadCost = spreadPoints * volume * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            double breakEvenTrigger = spreadCost * BreakEvenSpreadMultiplier;
            
            if(profit > breakEvenTrigger)
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
            SignalStrength currentStrength = GetSignalStrength(orderType, true);
            double currentScore = currentStrength.finalScore;
            double signalRatio = currentScore / initialScore;
            
            // Re-read position volume (may have changed from previous partial close)
            if(!PositionSelectByTicket(ticket)) continue;
            volume = PositionGetDouble(POSITION_VOLUME);
            
            double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            
            // Level 1: Signal drops to 75% -> Close 25%
            if(managedPositions[posIndex].partialCloseLevel == 0 && signalRatio <= 0.75)
            {
                double closeVol = NormalizeVolume(volume * PartialClose75Pct);
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
            }
            // Level 2: Signal drops to 50% -> Close 50%
            else if(managedPositions[posIndex].partialCloseLevel == 1 && signalRatio <= 0.50)
            {
                // Re-read volume after potential L1 close
                if(!PositionSelectByTicket(ticket)) continue;
                volume = PositionGetDouble(POSITION_VOLUME);
                
                double closeVol = NormalizeVolume(volume * PartialClose50Pct);
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
            }
            // Level 3: Signal drops to 25% -> Close remaining
            else if(managedPositions[posIndex].partialCloseLevel == 2 && signalRatio <= 0.25)
            {
                LogPrint("+-----------------------------------------+");
                LogPrint("[PARTIAL CLOSE L3 - FULL EXIT] Ticket: ", ticket);
                LogPrint("Signal: ", DoubleToString(currentScore, 1), " / ", 
                         DoubleToString(initialScore, 1), " (", DoubleToString(signalRatio * 100, 0), "%)");
                LogPrint("+-----------------------------------------+");
                
                managedPositions[posIndex].partialCloseLevel = 3;
                ClosePosition(ticket);
                
                // Virtual SL Re-entry after L3 full close
                if(EnableVirtualSLReentry)
                {
                    TryVirtualSLReentry(posType, initialScore);
                }
                continue; // Position is fully closed
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
                if(currentSL > 0 && newTightenedSL <= currentSL) continue;
                
                // Respect minimum stop distance
                if(newTightenedSL >= bid - minDist) continue;
            }
            else
            {
                double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                newTightenedSL = NormalizeDouble(ask + slDistance, _Digits);
                
                // Respect break-even lock
                if(managedPositions[posIndex].breakEvenLocked && newTightenedSL > entryPrice)
                    newTightenedSL = NormalizeDouble(entryPrice, _Digits);
                
                // Only move SL DOWN (more protective)
                if(currentSL > 0 && newTightenedSL >= currentSL) continue;
                
                // Respect minimum stop distance
                if(newTightenedSL <= ask + minDist) continue;
            }
            
            if(IsSLValid(posType, newTightenedSL))
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
            
            ClosePosition(ticket);
            
            // Virtual SL + Re-entry: try to re-enter at better price if signal supports it
            if(EnableVirtualSLReentry)
            {
                TryVirtualSLReentry(posType, initialScore);
            }
        }
    }
}

// +------------------------------------------------------------------+
// | Partial Close Position - Close a portion of position volume       |
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
    return (result.retcode == TRADE_RETCODE_DONE);
}

// +------------------------------------------------------------------+
// | Virtual SL Re-entry - Re-evaluate and re-enter after exit        |
// +------------------------------------------------------------------+
void TryVirtualSLReentry(ENUM_POSITION_TYPE posType, double initialScore)
{
    if(initialScore <= 0) return;
    
    // Check if trading is allowed (respects all guards except duplicate signal filter)
    if(targetEquityReached || minimumEquityReached || minEquityTriggersExceeded) return;
    if(isPaused || isOutsideTradingHours || isLeverageDiffFromInitial) return;
    if(isNearMarketClose) return;
    if(isOrderSendLocked) return;
    if(CountLosingPositions() >= MaxHoldingLossPositions) return;
    if(CountOpenOrders() >= MaxOpenOrders) return;
    
    // Get current signal strength for the same direction
    ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    SignalStrength strength = GetSignalStrength(orderType, true);
    
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
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double profit = PositionGetDouble(POSITION_PROFIT);
    double volume = PositionGetDouble(POSITION_VOLUME);
    
    // Get Signal Strength (includeCurrentCandle=true for management)
    ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    SignalStrength currentStrength = GetSignalStrength(orderType, true);
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
    double newTP = currentTP;
    
    if(EnableTakeProfit)
    {
        double effectiveTP = TPValue + tpAdjustment;
        
        // Ensure effective TP doesn't go negative or too small
        if(effectiveTP < (TrailingValueMultiplier * 0.1)) effectiveTP = TrailingValueMultiplier * 0.1;

        double tpPoints = ConvertToPoints(TPInputType, effectiveTP, volume);
        double targetTP = 0;
        
        if(posType == POSITION_TYPE_BUY) targetTP = NormalizeDouble(entryPrice + tpPoints * _Point, _Digits);
        else targetTP = NormalizeDouble(entryPrice - tpPoints * _Point, _Digits);
        
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
    bool canTrail = (!TrailingSLOnProfitableOnly || profit >= profitThreshold);
    
    if(canTrail)
    {
        // Calculate effective Trailing Distance
        double effectiveDist = TrailingDistanceValue + slAdjustment; // Adaptive TS
        
        // Ensure distance is safe (not negative)
        if(effectiveDist < (TrailingValueMultiplier * 0.1)) effectiveDist = TrailingValueMultiplier * 0.1;
        
        // Calculate trailing distance
        double finalTrailingPoints = ConvertToPoints(TSInputType, effectiveDist, volume);
        double trailingDistancePrice = finalTrailingPoints * _Point;
        
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

    // Skip if nothing changed
    if(!shouldModifySL && MathAbs(newTP - currentTP) < _Point) return;
    
    // Normalize
    newSL = NormalizeDouble(newSL, _Digits);
    newTP = NormalizeDouble(newTP, _Digits);
    
    // Skip if SL is visually same (if modifier flag was triggered but value didn't change enough - redundant check)
    if(shouldModifySL && MathAbs(newSL - currentSL) < _Point && MathAbs(newTP - currentTP) < _Point) return;

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
        
        // Define substantial as 3x minimum target profit
        double minSubstantialProfit = MinBreakEvenProfit * 3.0; 
        
        if(profit >= minSubstantialProfit)
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
void RegisterManagedPosition(ulong ticket, ENUM_POSITION_TYPE type, double signalScore, double entryPrice = 0)
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
    
    managedPositionCount++;
    
    // Update counters
    if(type == POSITION_TYPE_BUY) buyPositionCount++;
    else sellPositionCount++;
    
    LogPrint("Registered position. Ticket: ", ticket, 
             " | Type: ", EnumToString(type),
             " | Score: ", signalScore, 
             " | Entry: ", entryPrice,
             " | Open Buys: ", buyPositionCount, " | Open Sells: ", sellPositionCount);
}

// Remove Position from Managed Array
void RemoveManagedPosition(ulong ticket)
{
    for(int i = 0; i < managedPositionCount; i++)
    {
        if(managedPositions[i].ticket == ticket)
        {
            // Update counters before removing
            if(managedPositions[i].type == POSITION_TYPE_BUY) buyPositionCount--;
            else sellPositionCount--;
            
            // Safety check for negative counters
            if(buyPositionCount < 0) buyPositionCount = 0;
            if(sellPositionCount < 0) sellPositionCount = 0;

            // Shift array elements left
            for(int j = i; j < managedPositionCount - 1; j++)
            {
                managedPositions[j] = managedPositions[j + 1];
            }
            
            managedPositionCount--;
            ArrayResize(managedPositions, managedPositionCount);
            
            LogPrint("Removed position: ", ticket, 
                     " | Remaining Open Buys: ", buyPositionCount, 
                     " | Remaining Open Sells: ", sellPositionCount);
            break;
        }
    }
}

// Sync Managed Positions with Broker
// Removes closed positions from managed array
// Also tracks consecutive losses for cooldown system
void SyncManagedPositions()
{
    for(int i = managedPositionCount - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(managedPositions[i].ticket))
        {
            ulong closedTicket = managedPositions[i].ticket;
            
            // SIGNAL DAMPENING: Track consecutive losses for cooldown
            if(EnableSignalDampening)
            {
                // Query deal history to find the closing profit of this position
                double closedProfit = 0;
                bool foundDeal = false;
                
                // Select history for recent period (last 24 hours should be sufficient)
                datetime fromTime = TimeCurrent() - 86400;
                datetime toTime = TimeCurrent();
                
                if(HistorySelect(fromTime, toTime))
                {
                    int totalDeals = HistoryDealsTotal();
                    for(int d = totalDeals - 1; d >= 0; d--)
                    {
                        ulong dealTicket = HistoryDealGetTicket(d);
                        if(dealTicket == 0) continue;
                        
                        // Match deal to our position
                        ulong dealPosition = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
                        long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
                        long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
                        
                        if(dealPosition == closedTicket && dealEntry == DEAL_ENTRY_OUT && dealMagic == MagicNumber)
                        {
                            closedProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) 
                                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                            foundDeal = true;
                            break;
                        }
                    }
                }
                
                if(foundDeal)
                {
                    if(closedProfit < 0)
                    {
                        consecutiveLossCount++;
                        LogPrint("[LOSS TRACKER] Position ", closedTicket, " closed at loss: $", 
                                 DoubleToString(closedProfit, 2), 
                                 ". Consecutive losses: ", consecutiveLossCount);
                        
                        // Activate cooldown after 3+ consecutive losses
                        if(consecutiveLossCount >= 3)
                        {
                            datetime currBar = iTime(_Symbol, _Period, 0);
                            cooldownUntilBarTime = currBar + ConsecutiveLossCooldownBars * PeriodSeconds(_Period);
                            LogPrint("[COOLDOWN ACTIVATED] ", consecutiveLossCount, 
                                     " consecutive losses. No new entries until bar: ", 
                                     TimeToString(cooldownUntilBarTime));
                        }
                    }
                    else
                    {
                        if(consecutiveLossCount > 0)
                        {
                            LogPrint("[LOSS TRACKER] Win streak started. Reset from ", 
                                     consecutiveLossCount, " consecutive losses.");
                        }
                        consecutiveLossCount = 0; // Reset on any win
                    }
                }
            }
            
            RemoveManagedPosition(closedTicket);
        }
    }
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
    
    // Fetch velocity boost for final lot calculation
    double velocityBoost = 0;
    if (orderType == ORDER_TYPE_BUY) velocityBoost = lastBuyNormalizedVelocity;
    else velocityBoost = lastSellNormalizedVelocity;
    
    // Calculate final lot size with both signal score and velocity boost
    // This must be done BEFORE SL/TP conversion so dollar-based values are accurate
    double currentLot = CalculateDynamicLotSize(signalScore, velocityBoost);
    
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

    // Calculate and set Take Profit
    if(EnableTakeProfit)
    {
        double effectiveTPValue = TPValue;
        double tpPoints = ConvertToPoints(TPInputType, effectiveTPValue, currentLot);
        
        if(orderType == ORDER_TYPE_BUY)
        {
            request.tp = NormalizeDouble(price + (tpPoints * _Point), _Digits); 
        }
        else
        {
            request.tp = NormalizeDouble(price - (tpPoints * _Point), _Digits); 
        }
    }

    // Calculate and set Stop Loss
    if(EnableStopLoss)
    {
        double effectiveSLValue = SLValue;
        double slPoints = ConvertToPoints(SLInputType, effectiveSLValue, currentLot);
        
        if(orderType == ORDER_TYPE_BUY)
        {
            request.sl = NormalizeDouble(price - (slPoints * _Point), _Digits); 
        }
        else
        {
            request.sl = NormalizeDouble(price + (slPoints * _Point), _Digits); 
        }
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
            
            if(EnableStopLoss)
            {
                LogPrint(" | SL: ", request.sl);
            }
            if(EnableTakeProfit)
            {
                LogPrint(" | TP: ", request.tp);
            }
            
            // Register position to managed array
            ENUM_POSITION_TYPE posType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            RegisterManagedPosition(result.order, posType, signalScore, price);
            
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
        }
    }
    else
    {
        LogPrint("OrderSend error: ", GetLastError());
    }

    LockOrderSend(false);
}

// Close Position
bool ClosePosition(ulong ticket)
{
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
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (type == POSITION_TYPE_BUY) ? 
                    SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                    SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(!OrderSend(request, result))
    {
        LogPrint("Failed to close position ", ticket, " Error: ", GetLastError());
        LockOrderSend(false);
        return false;
    }
    
    LogPrint("Position ", ticket, " closed successfully");
    LockOrderSend(false);
    return true;
}

// Close all positions regardless of profit/loss
void CloseAllPositions(bool unProfitableOnly = false)
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
    request.sl = NormalizeDouble(newSL, _Digits);
    request.tp = NormalizeDouble(newTP, _Digits);

    // Prevent unnecessary modifications
    if(NormalizeDouble(newSL, _Digits) == NormalizeDouble(currentSL, _Digits) && 
       NormalizeDouble(newTP, _Digits) == NormalizeDouble(currentTP, _Digits))
    {
        return true;
    }
    
    // Send modification request
    if(!OrderSend(request, result))
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

// Helper function to check is allowed to open position
bool IsAllowedToOpenPosition()
{
    if (targetEquityReached || minimumEquityReached || minEquityTriggersExceeded)
    {
        LogPrint("+-----------------------------------------+");
        LogPrint("OPEN ORDER BLOCKED!");
        LogPrint("Trading Stopped! Opening new order are not allowed!");
        LogPrint("+-----------------------------------------+");
        return false;
    }

    if (isPaused || isOutsideTradingHours || isLeverageDiffFromInitial)
    {
        LogPrint("+-----------------------------------------+");
        LogPrint("OPEN ORDER BLOCKED!");
        LogPrint("Trading Paused! Opening new order are not allowed during pause period!");
        LogPrint("+-----------------------------------------+");
        return false;
    }
    
    if(isNearMarketClose)
    {
        LogPrint("+-----------------------------------------+");
        LogPrint("OPEN ORDER BLOCKED!");
        LogPrint("Market closing soon! No opening new positions.");
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

    return true;
}


// Helper function to lock/unlock OrderSend execution
void LockOrderSend(bool isLocked)
{
    isOrderSendLocked = isLocked;
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

// Helper for normalize volume
double NormalizeVolume(double volume)
{
    double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    volume = MathMax(volume, minVol);
    volume = MathMin(volume, maxVol);
    volume = MathRound(volume / stepVol) * stepVol;
    
    return volume;
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

//+------------------------------------------------------------------+
//| Calculate Dynamic Lot Size - Equity Drop & Signal Strength Based |
//| Lot increases based on:                                          |
//|   1. Equity drop from peak (EquityDropPercent per step)          |
//|   2. Strong signal strength (MinSignalStrengthForLot threshold)  |
//|   3. Velocity Boost                                              |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(double signalScore = 0, double normalizedVelocity = 0)
{
    if(!EnableDynamicLots) return BaseLotSize;
    
    double currentLot = BaseLotSize;
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // 1. EQUITY DROP-BASED LOT INCREASE
    // Calculate equity drop from peak as percentage
    double equityDropPercent = 0;
    if(peakEquity > 0)
    {
        equityDropPercent = ((peakEquity - currentEquity) / peakEquity) * 100.0;
    }
    
    // Each EquityDropPercent step adds LotStepSize
    int equitySteps = 0;
    if(equityDropPercent > 0 && EquityDropPercent > 0)
    {
        equitySteps = (int)(equityDropPercent / EquityDropPercent);
    }
    
    double equityLotIncrease = equitySteps * LotStepSize;
    currentLot += equityLotIncrease;
    
    // 2. SIGNAL STRENGTH-BASED LOT INCREASE
    // If signal score is above threshold, add extra lot steps
    double signalLotIncrease = 0;
    if(signalScore >= MinSignalStrengthForLot)
    {
        // For every 2 points above threshold, add one lot step
        double signalSteps = (signalScore - MinSignalStrengthForLot) / 2;
        signalLotIncrease = signalSteps * LotStepSize;
        currentLot += signalLotIncrease;
    }
    
    // APPLY LIMITS
    // Apply user-defined limits
    if(currentLot < BaseLotSize) currentLot = BaseLotSize;
    if(currentLot > MaxLotSize) currentLot = MaxLotSize;

    // 3. VELOCITY BOOST 
    // lotSizeMultiplier *= velocityBoost
    // velocityBoost = 1 + normalizedVelocity * VelocitySizeWeight
    double velocityBoost = 1.0 + (normalizedVelocity * VelocitySizeWeight);
    currentLot *= velocityBoost;
    
    // Clamp to Max Lot Size
    if(currentLot > MaxLotSize) currentLot = MaxLotSize;
    
    // Round to 2 decimal places (standard lot step)
    currentLot = NormalizeDouble(currentLot, 2);
    
    // Apply broker limits
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(currentLot < minLot) currentLot = minLot;
    if(currentLot > maxLot) currentLot = maxLot;
        
    // Round to valid lot step
    currentLot = MathFloor(currentLot / lotStep) * lotStep;
    
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
             " | Signal Steps=", (signalScore >= MinSignalStrengthForLot ? (signalScore - MinSignalStrengthForLot) / 2 : 0), " (+", signalLotIncrease, ")",
             " | Final Lot=", currentLot);
    
    return currentLot;
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

        // Convert MinBreakEvenProfit ($) to price
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
// | Convert Input Value to Points Based on Input Type                |
// +------------------------------------------------------------------+
double ConvertToPoints(ENUM_INPUT_TYPE inputType, double value, double lotSize)
{
    double points = 0;
    
    switch(inputType)
    {
        case INPUT_POINTS:
            points = value;
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
// | Monitor High-Impact News Events & Return Event Details           |
// +------------------------------------------------------------------+
string IsHighImpactNewsTime(int minutesBefore, int minutesAfter, ulong &eventID)
{
    MqlCalendarValue values[];
    
    datetime serverTime = TimeTradeServer();
    // Use the max of both windows to cover all events in their active pause window
    // Add 120s buffer to avoid boundary exclusion issues in CalendarValueHistory
    int lookRange = (int)MathMax(minutesBefore, minutesAfter);
    datetime start = serverTime - lookRange * 60;
    datetime end = serverTime + lookRange * 60 + 120;
    
    if(CalendarValueHistory(values, start, end))
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
// | Check and Update Peak Equity                                     |
// +------------------------------------------------------------------+
void CheckPeakEquity()
{
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
        
        // Reset pause if equity recovered above peak
        if(isPaused)
        {
            isPaused = false;
            LogPrint("Trading RESUMED - Equity recovered above peak!");
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
    // Get current equity
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

    // Calculate allowed drawdown
    double drawdownFromPercent = lastPeakEquity * ((100.0 - MinEquityPercent) / 100.0);
    
    // If MaxDrawdownFromPeak is 0 or negative, don't cap it
    double allowedDrawdown = (MaxDrawdownFromPeak > 0) ? 
    MathMin(drawdownFromPercent, MaxDrawdownFromPeak)
    : drawdownFromPercent;
    
    double minAllowedEquity = lastPeakEquity - allowedDrawdown;
    
    // Check equity condition and handle pause
    if(currentEquity < minAllowedEquity)
    {
        if(!isPaused)
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
            isPaused = true;
            pauseStartTime = TimeTradeServer();
            
            // Use the trigger count to calculate exponential pause duration
            double calculatedDuration = PauseMinutes * MathPow(PauseMinutesMultiplier, minEquityTriggerCount - 1);
            if(calculatedDuration > INT_MAX) calculatedDuration = INT_MAX;
            currentPauseDuration = (int)MathMin(calculatedDuration, MaxPauseMinutes > 0 ? MaxPauseMinutes : INT_MAX);
            
            // Update Pause Stats
            totalPauseCount++;
            totalPauseDurationMinutes += currentPauseDuration;
            
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
            LogPrint("Trading PAUSED for ", currentPauseDuration, " minutes");
            LogPrint("Resume Time: ", TimeToString(pauseStartTime + currentPauseDuration * 60));
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
                alertMsg += "**Trading Paused:** " + IntegerToString(currentPauseDuration) + " minutes\n";
                alertMsg += "**Resume Time:** " + TimeToString(pauseStartTime + currentPauseDuration * 60) + "\n";
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

    ulong newsEventID = 0;
    string newsDetails = IsHighImpactNewsTime(NewsMinutesBefore, NewsMinutesAfter, newsEventID);
    
    if(!isPaused && newsDetails != "" && lastProcessedNewsEventID != newsEventID)
    {
        // Update last processed news event ID
        lastProcessedNewsEventID = newsEventID;
        
        // Trigger the pause mechanism
        isPaused = true;
        pauseStartTime = TimeTradeServer();
        
        // Calculate remaining pause time until event ends
        datetime eventTime = 0;
        datetime currentServerTime = TimeTradeServer();
        MqlCalendarValue values[];

        if(CalendarValueHistory(values, currentServerTime - NewsMinutesBefore * 60, currentServerTime + NewsMinutesAfter * 60 + 120))
        {
            for(int i = 0; i < ArraySize(values); i++)
            {
                if(values[i].event_id == newsEventID)
                {
                    eventTime = values[i].time;
                    break;
                }
            }
        }
        
        if(eventTime > 0)
        {
            int secondsUntilEventEnd = (int)((eventTime + NewsMinutesAfter * 60) - currentServerTime);
            currentPauseDuration = (secondsUntilEventEnd / 60) + 1; // +1 for safety margin
        }
        else
        {
            currentPauseDuration = NewsMinutesAfter; // Fallback
        }
        
        // Update Pause Stats
        totalPauseCount++;
        totalPauseDurationMinutes += currentPauseDuration;
        
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        LogPrint("+-----------------------------------------+");
        LogPrint("HIGH-IMPACT NEWS EVENT DETECTED!");
        LogPrint("Server Time: ", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS));
        LogPrint("Current Equity: $", currentEquity);
        LogPrint("Trading PAUSED for ", currentPauseDuration, " minutes");
        LogPrint("Resume Time: ", TimeToString(pauseStartTime + currentPauseDuration * 60));
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
            alertMsg += "**Resume Time:** " + TimeToString(pauseStartTime + currentPauseDuration * 60) + "\n";
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
    if(!EnableTradingHours) return;
    
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
    if(!EnableMarketCloseFilter || MinutesBeforeClose <= 0) return;
    
    MqlDateTime dt;
    TimeCurrent(dt);
    ENUM_DAY_OF_WEEK dayOfWeek = (ENUM_DAY_OF_WEEK)dt.day_of_week;
    
    datetime from, to;
    datetime currentTime = TimeCurrent();
    
    if(SymbolInfoSessionQuote(_Symbol, dayOfWeek, 0, from, to))
    {
        int secondsUntilClose = (int)(to - currentTime);
        int minutesUntilClose = secondsUntilClose / 60;
        
        if(minutesUntilClose > 0 && minutesUntilClose <= MinutesBeforeClose)
        {
            // Send alert once per session
            if(!marketCloseAlertSent && EnableDiscordAlerts)
            {
                double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
                
                string alertMsg = "**Instrument:** " + _Symbol + "\n";
                alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
                alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                alertMsg += "**Market Closes In:** " + IntegerToString(minutesUntilClose) + " minutes\n";
                alertMsg += "**Market Close Time:** " + TimeToString(to, TIME_DATE|TIME_MINUTES) + "\n";
                alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
                alertMsg += "**Action:** Stopped Opening New Positions";
                
                SendDiscordAlert("⏰ MARKET CLOSING SOON", alertMsg, 16776960); // Yellow
                marketCloseAlertSent = true;
            }
            
            LogPrint("Market closes in ", minutesUntilClose, " minutes. Not opening new positions.");
            isNearMarketClose = true;
            return; // Already in warning window, no need to check further
        }
        
        // Reset when outside warning period
        if(minutesUntilClose > MinutesBeforeClose)
        {
            isNearMarketClose = false;
            marketCloseAlertSent = false; // Also reset alert flag for next session
            return;
        }
        
        // Current time is past session 0 close — check session 1
        if(currentTime >= to)
        {
            datetime from2, to2;
            if(SymbolInfoSessionQuote(_Symbol, dayOfWeek, 1, from2, to2))
            {
                secondsUntilClose = (int)(to2 - currentTime);
                minutesUntilClose = secondsUntilClose / 60;
                
                if(minutesUntilClose > 0 && minutesUntilClose <= MinutesBeforeClose)
                {
                    LogPrint("Market closes in ", minutesUntilClose, " minutes. Not opening new positions.");
                    isNearMarketClose = true;
                    return;
                }
                
                if(minutesUntilClose > MinutesBeforeClose)
                {
                    isNearMarketClose = false;
                    return;
                }
            }
        }
    }
    
    // No valid session found or market is closed
    isNearMarketClose = false;
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Check for Leverage Changes                                       |
// +------------------------------------------------------------------+
void CheckLeverageChange()
{
    // Skip if feature is disabled
    if(!EnableLeveragePause) return;
    
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
        
        CloseAllPositions(); 
    }
    // Leverage returned to initial - check if we're paused due to leverage (currentPauseDuration == 0)
    else if(currentLeverage == initialLeverage && isLeverageDiffFromInitial && currentPauseDuration == 0)
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
    
    // Check for End of Day (23:59) Report
    if(!EnableTradingHours && dt.hour == 23 && dt.min == 59)
    {
        // Check if report already sent today (to avoid spamming in the last minute)
        // lastDailyReportTime checks full timestamp
        MqlDateTime lastReportDt;
        TimeToStruct(lastDailyReportTime, lastReportDt);
        
        if(lastReportDt.day != dt.day)
        {
            sendReport = true;
        }
    }
    
    if (sendReport)
    {
        SendTradeReport();
    }
}

// Get Trade Statistics
void GetTradeStats(TradeStats& daily, TradeStats& allTime) 
{
    // Initialize
    daily.count = 0; daily.won = 0; daily.lost = 0;
    daily.profit = 0; daily.loss = 0;
    daily.maxProfit = 0; daily.minProfit = DBL_MAX;
    daily.maxLoss = 0; daily.minLoss = -DBL_MAX; 

    allTime.count = 0; allTime.won = 0; allTime.lost = 0;
    allTime.profit = 0; allTime.loss = 0;
    allTime.maxProfit = 0; allTime.minProfit = DBL_MAX;
    allTime.maxLoss = 0; allTime.minLoss = -DBL_MAX;

    datetime now = TimeCurrent();
    
    // Trade Stats Session Start Time
    // Start from last report generated, or from start of bot started if no last report
    datetime sessionStartTime = (lastDailyReportTime > 0) ? lastDailyReportTime : startTime;

    if(HistorySelect(0, now)) {
        int deals = HistoryDealsTotal();
        for(int i = 0; i < deals; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol || 
               HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;

            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                            HistoryDealGetDouble(ticket, DEAL_SWAP) + 
                            HistoryDealGetDouble(ticket, DEAL_COMMISSION);

            if (entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT) {
                // ALL TIME STATS
                allTime.count++;
                if(profit >= 0) {
                    allTime.won++;
                    allTime.profit += profit;
                    if(profit > allTime.maxProfit) allTime.maxProfit = profit;
                    if(profit < allTime.minProfit) allTime.minProfit = profit;
                } else {
                    allTime.lost++;
                    allTime.loss += profit;
                    if(profit < allTime.maxLoss) allTime.maxLoss = profit; 
                    if(profit > allTime.minLoss) allTime.minLoss = profit; 
                }

                // SESSION STATS (Since Last Report or Start)
                datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                if(dealTime >= sessionStartTime) {
                    daily.count++;
                    if(profit >= 0) {
                        daily.won++;
                        daily.profit += profit;
                        if(profit > daily.maxProfit) daily.maxProfit = profit;
                        if(profit < daily.minProfit) daily.minProfit = profit;
                    } else {
                        daily.lost++;
                        daily.loss += profit;
                        if(profit < daily.maxLoss) daily.maxLoss = profit;
                        if(profit > daily.minLoss) daily.minLoss = profit;
                    }
                }
            }
        }
    }
    
    // Calculate Averages and fix Min/Max initialization if no trades
    // All Time
    if(allTime.won > 0) allTime.avgProfit = allTime.profit / allTime.won; else { allTime.avgProfit = 0; allTime.minProfit = 0; }
    if(allTime.lost > 0) allTime.avgLoss = allTime.loss / allTime.lost; else { allTime.avgLoss = 0; allTime.minLoss = 0; allTime.maxLoss = 0; }
    
    // Daily
    if(daily.won > 0) daily.avgProfit = daily.profit / daily.won; else { daily.avgProfit = 0; daily.minProfit = 0; }
    if(daily.lost > 0) daily.avgLoss = daily.loss / daily.lost; else { daily.avgLoss = 0; daily.minLoss = 0; daily.maxLoss = 0; }
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
    GetTradeStats(dailyStats, allTimeStats);
    
    // Session net profit
    double sessionNetProfit = dailyStats.profit + dailyStats.loss; // loss is already negative
    double sessionNetPercent = (balance > 0) ? (sessionNetProfit / balance) * 100.0 : 0.0;
    
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
    alertMsg += "**Smallest Loss:** $" + DoubleToString(allTimeStats.minLoss, 2) + "\n\n";
    
    alertMsg += "**Pauses Triggered:** " + IntegerToString(totalPauseCount) + "\n";
    alertMsg += "**Total Paused Duration:** " + DoubleToString(totalPauseDurationMinutes, 0) + " minutes" + "\n";
    alertMsg += "**Report Generated For:** " + reportDurationStr + "\n";
    alertMsg += "**Run Duration:** " + durationStr + "\n";
    
    SendDiscordAlert("📊 TRADE REPORT", alertMsg, 16776960); // Yellow/Gold color
    
    lastDailyReportTime = TimeCurrent();
    lastReportEquity = currentEquity;
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

// Toggle  disable algo trading in MT5
void DisableAlgoTrading()
{
    bool Status = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
    
    if(Status)
    {
        HANDLE hChart = (HANDLE)ChartGetInteger(ChartID(), CHART_WINDOW_HANDLE);
        PostMessageW(GetAncestor(hChart, GA_ROOT), WM_COMMAND, MT_WMCMD_EXPERTS, 0);
    }
}

// +------------------------------------------------------------------+
// | Send Discord alert via webhook                                   |
// +------------------------------------------------------------------+
bool SendDiscordAlert(string title, string message, int embedColor = 3447003)
{
    if(!EnableDiscordAlerts || DiscordWebhookURL == "") return false;

    // Escape special characters in message
    StringReplace(message, "\\", "\\\\");
    StringReplace(message, "\"", "\\\"");
    StringReplace(message, "\n", "\\n");
    
    // Build JSON payload
    string json = "";
    json += "{\"embeds\":[{";
    json += "\"title\":\"" + title + "\",";
    json += "\"description\":\"" + message + "\",";
    json += "\"color\":" + IntegerToString(embedColor) + ",";
    json += "\"footer\":{\"text\":\"Nyao Scalper v36.0\"}";
    json += "}]}";
    
    // Prepare HTTP request
    char post[];
    char result[];
    string headers = "Content-Type: application/json\r\n";
    string resultHeaders = "";
    int timeout = 5000;
    
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
void DrawDashboardLabel(string name, string text, int x, int y, int fontSize, color clr, bool bold = false)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    }
    
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
}

void UpdateDashboard()
{
    // Clear old comment based dashboard
    Comment("");

    // Layout Constants
    int startX = 20;
    int startY = 20;
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
    DrawDashboardLabel("NyaoDash_Title", "Nyao Scalper v36.0", startX, currentY, 11, colorHeader, true);
    currentY += lineHeight + 5;

    // Status logic
    string status = "Active";
    color statusColor = clrLime;
    if(isPaused) { status = "PAUSED (" + IntegerToString(currentPauseDuration) + "m)"; statusColor = clrOrange; }
    else if(isOutsideTradingHours) { status = "Closed (Time)"; statusColor = clrGray; }
    else if(targetEquityReached) { status = "STOPPED (Target)"; statusColor = clrRed; }
    else if(minimumEquityReached) { status = "STOPPED (Min Equity)"; statusColor = clrRed; }

    DrawDashboardLabel("NyaoDash_Status", "Status: " + status, startX, currentY, textsize, statusColor, true);
    currentY += lineHeight;

    // Account Info
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double equityDrop = (peakEquity > 0) ? ((peakEquity - equity) / peakEquity) * 100.0 : 0.0;
    
    DrawDashboardLabel("NyaoDash_Bal", StringFormat("Balance: $%.2f", balance), startX, currentY, textsize, colorText);
    currentY += lineHeight;
    DrawDashboardLabel("NyaoDash_Eq", StringFormat("Equity: $%.2f", equity), startX, currentY, textsize, colorText);
    currentY += lineHeight;
    DrawDashboardLabel("NyaoDash_Peak", StringFormat("Peak: $%.2f (Drop: %.1f%%)", peakEquity, equityDrop), startX, currentY, textsize, colorText);
    currentY += lineHeight + 5;

    // Signal Strength
    SignalStrength buyStrength = GetSignalStrength(ORDER_TYPE_BUY, true);
    SignalStrength sellStrength = GetSignalStrength(ORDER_TYPE_SELL, true);
    
    // Previous Signal Strength (Closed Candle)
    SignalStrength prevBuyStrength = GetSignalStrength(ORDER_TYPE_BUY, false);
    SignalStrength prevSellStrength = GetSignalStrength(ORDER_TYPE_SELL, false);

    DrawDashboardLabel("NyaoDash_SigHead", "SIGNAL STRENGTH:", startX, currentY, headersize, colorHeader, true);
    currentY += lineHeight;

    string reqBuyText = StringFormat("Min Buy: %.2f", MinBuySignalScore);
    DrawDashboardLabel("NyaoDash_ReqBuy", reqBuyText, startX, currentY, detailsSize, colorText);
    currentY += lineHeight;

    string reqSellText = StringFormat("Min Sell: %.2f", MinSellSignalScore);
    DrawDashboardLabel("NyaoDash_ReqSell", reqSellText, startX, currentY, detailsSize, colorText);
    currentY += lineHeight;

    // Buy Row
    string buyText = StringFormat("BUY SCORE: %.2f", prevBuyStrength.finalScore);
    DrawDashboardLabel("NyaoDash_Buy", buyText, startX, currentY, textsize, prevBuyStrength.finalScore > prevSellStrength.finalScore ? colorBuy : colorText, true);
    currentY += lineHeight;

    string currentBuyText = StringFormat("Current Score: %.2f", buyStrength.finalScore);
    DrawDashboardLabel("NyaoDash_CurrentBuy", currentBuyText, startX, currentY, detailsSize, colorText);
    currentY += lineHeight;
    
    string buyDet = StringFormat("%s", buyStrength.reasoning);
    DrawDashboardLabel("NyaoDash_BuyDet", buyDet, startX, currentY, detailsSize, colorText);
    currentY += lineHeight + 2;

    // Sell Row
    string sellText = StringFormat("SELL SCORE: %.2f", prevSellStrength.finalScore);
    DrawDashboardLabel("NyaoDash_Sell", sellText, startX, currentY, textsize, prevSellStrength.finalScore > prevBuyStrength.finalScore ? colorSell : colorText, true);
    currentY += lineHeight;

    string currentSellText = StringFormat("Current Score: %.2f", sellStrength.finalScore);
    DrawDashboardLabel("NyaoDash_CurrentSell", currentSellText, startX, currentY, detailsSize, colorText);
    currentY += lineHeight;

    string sellDet = StringFormat("%s",sellStrength.reasoning);
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

    DrawDashboardLabel("NyaoDash_PL", StringFormat("Profit: $%.2f | Loss: $%.2f", allTime.profit, allTime.loss), startX, currentY, textsize, colorText);
    currentY += lineHeight;
    
    color profitColor = allTimeNetProfit >= 0 ? colorBuy : colorSell;
    DrawDashboardLabel("NyaoDash_Net", StringFormat("NET PROFIT: $%.2f", allTimeNetProfit), startX, currentY, textsize, profitColor, true);
}
// +------------------------------------------------------------------+