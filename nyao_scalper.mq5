// +------------------------------------------------------------------+
// |                                          Nyao Scalper v27.0      |
// |              Indicator-Based Signal Strength Trading System      |
// |              with Equity & Risk Management + Discord Alerts      |
// |                                    © Copyright Nyao Scalper      |
// +------------------------------------------------------------------+
#property copyright "© Copyright Nyao Scalper by Elriz Wiraswara"
#property version   "27.0"
#property description "Auto Trading EA Robot with Indicator-Based Signal Strength & Position Management."
#property description "Do with your own risk. Results may vary based on market conditions."
#property strict

// Windows API for Algo Trading Button Control
#define MT_WMCMD_EXPERTS   32851
#define WM_COMMAND 0x0111
#define GA_ROOT    2
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
input group " Nyao Scalper v27.0"
input group "「結果が出ない努力はただの言い訳」"
input group " © Copyright Nyao Scalper by Elriz Wiraswara"
input group "+-----------------------------------------+"

// +------------------------------------------------------------------+
// | Input Parameters                                                 |
// +------------------------------------------------------------------+
input group "📊 Indicator Settings"
input int EMA_FastPeriod = 5;                             // EMA Fast Period
input int EMA_SlowPeriod = 13;                            // EMA Slow Period
input int Bollinger_Period = 14;                          // Bollinger Bands Period
input double Bollinger_Deviation = 1.8;                   // Bollinger Bands Deviation
input int RSI_Period = 5;                                 // RSI Period
input int RSI_OversoldLevel = 30;                         // RSI Oversold Level (Default 30)
input int RSI_OverboughtLevel = 70;                       // RSI Overbought Level (Default 70)
input int Stoch_KPeriod = 5;                              // Stochastic %K Period
input int Stoch_DPeriod = 3;                              // Stochastic %D Period
input int Stoch_Slowing = 2;                              // Stochastic Slowing
input int Stoch_OversoldLevel = 20;                       // Stochastic Oversold Level (Default 20)
input int Stoch_OverboughtLevel = 80;                     // Stochastic Overbought Level (Default 80)
input int SR_LookbackPeriod = 50;                         // Support/Resistance Lookback Period

input group "⚖️ Score Weight Settings"
input int WeightEMA = 4;                                  // EMA Weight (Score 0-5 × Weight)
input int WeightBollinger = 2;                            // Bollinger Bands Weight (Score 0-2 × Weight)
input int WeightRSI = 3;                                  // RSI Weight (Score 0-3 × Weight)
input int WeightStochastic = 2;                           // Stochastic Weight (Score 0-2 × Weight)
input int ScoreCandleWick = 2;                            // Candle Wick Rejection Score
input int ScoreCandleMomentum = 2;                        // Candle Momentum Shift Score
input int ScoreNearSR = 2;                                // Near Support/Resistance Score
input int ScoreBreakoutSR = 3;                            // S/R Breakout Score

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
input int MinBuySignalScore = 10;                         // Min Signal Strength Score to Buy
input int MinSellSignalScore = 10;                        // Min Signal Strength Score to Sell
input bool EnablePyramiding = true;                       // Enable Pyramiding Positions
input int MinPyramidingBuySignalScore = 16;               // Min Signal Strength Score to Pyramiding Buy
input int MinPyramidingSellSignalScore = 16;              // Min Signal Strength Score to Pyramiding Sell
input int MaxPositionsPerCandle = 6;                      // Max Positions Per Candle
input bool EnableLossManagement = true;                   // Enable Adaptive Loss Management
input int MinSignalStrengthToHold = 8;                    // Min Signal Score to Hold Losing Position
input int MaxHoldingLossPositions = 3;                    // Max Losing Positions to Hold (0 = Close Immediately)

input group "🧮 Dynamic Lot Sizing Settings"
input bool EnableDynamicLots = true;                      // Enable Dynamic Lot Sizing
input double EquityDropPercent = 0.0;                     // Equity Drop % per Lot Step
input double LotStepSize = 0.01;                          // Lot Increase Step Size
input double MaxLotSize = 0.05;                           // Max Lot Size
input int MinSignalStrengthForLot = 20;                   // Min Signal Score for Lot Increase

input group "🏦 Equity Settings"
input double MinEquityPercent = 70.0;                     // Min Equity % from Peak - Pause Trading when Reached
input double MaxDrawdownFromPeak = 0;                     // Max Equity $ Drawdown - Pause Trading when Reached (0 = Disabled)
input int PauseMinutes = 5;                               // Pause Duration when Reached (Minutes)
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
input bool EnableStopLoss = false;                        // Enable Stop Loss
input ENUM_INPUT_TYPE SLInputType = INPUT_DOLLAR;         // SL Input Type
input double SLValue = 10.0;                              // SL Value

input group "💸 Trailing TP/SL Settings"
input bool EnableTrailing = true;                         // Enable Trailing TP/SL
input bool TrailingEnableBreakEvenLock = true;            // Enable Trailing Break-Even Lock
input bool TrailingSLOnProfitableOnly = true;             // Trailing SL on Profitable Position Only
input bool EnableAdaptiveTP = false;                      // Enable Adaptive TP
input bool EnableAdaptiveSL = false;                      // Enable Adaptive SL
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
CDialog g_PasswordDialog;
CEdit g_PasswordEdit;
CButton g_PasswordSubmitBtn;
CLabel g_PasswordLabel;
bool g_PasswordVerified = false;
bool g_PasswordDialogActive = false;

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

// Duplicate Signal Filter Variables
datetime lastReverseTime = 0;
datetime startTime = 0;                                   // EA Start Time
datetime lastDailyReportTime = 0;                         // Last time daily report was sent
double lastReportEquity = 0;                              // Equity at last report

// Pause Tracking
int totalPauseCount = 0;                                  // Total number of times trading was paused
double totalPauseDurationMinutes = 0;                     // Total duration of pauses in minutes

// Multi-Entry tracking
datetime lastMultiEntryTime = 0;

// Indicator handles (initialized in OnInit)
int g_RSI_Handle = INVALID_HANDLE;
int g_EMA_Fast_Handle = INVALID_HANDLE;
int g_EMA_Slow_Handle = INVALID_HANDLE;
int g_Bollinger_Handle = INVALID_HANDLE;
int g_Stochastic_Handle = INVALID_HANDLE;

// +------------------------------------------------------------------+
// | Signal Strength Structure - Indicator-Based Scoring System       |
// | Weights are adjustable via Score Weight Settings inputs          |
// +------------------------------------------------------------------+
struct SignalStrength
{
    // Individual indicator scores (raw, before weight multiplier)
    int rsiScore;              // RSI score (0-3)
    int emaScore;              // EMA crossover score (0-3)
    int bollingerScore;        // Bollinger Bands score (0-2)
    int stochasticScore;       // Stochastic score (0-2)
    int candleScore;           // Candle pattern score (aggregate)
    
    // Direct scores (no weight multiplier)
    int wickScore;             // Candle Wick Rejection Score
    int momentumScore;         // Candle Momentum Shift Score
    int supportResistanceScore;// Support/Resistance Proximity Score
    int breakoutScore;         // Key Level Breakout Score
    
    // Final weighted scores (mutually exclusive)
    int buyScore;              // Total weighted buy score
    int sellScore;             // Total weighted sell score
    int totalScore;            // The winning score (higher of buy/sell)
    
    string reasoning;          // Detailed explanation of score calculation
};

// +------------------------------------------------------------------+
// | Managed Position Structure - For Position Tracking               |
// | Stores position info to avoid repeated MQL function calls        |
// +------------------------------------------------------------------+
struct ManagedPosition
{
    ulong ticket;                    // Position ticket ID
    ENUM_POSITION_TYPE type;         // Buy or Sell
    int signalScore;          // Signal strength at entry
};

// Managed positions array
ManagedPosition g_ManagedPositions[];
int g_ManagedPositionCount = 0;

// Internal Position Counters (for O(1) checks)
int g_BuyPositionCount = 0;
int g_SellPositionCount = 0;

// Candle-based Pyramiding Counters
datetime g_CurrentBarTime = 0;
int g_BuysOnCurrentBar = 0;
int g_SellsOnCurrentBar = 0;

// Last Position Tracking (for O(1) duplicate checks)
datetime g_LastBuyTime = 0;
double g_LastBuyPrice = 0;
datetime g_LastSellTime = 0;
double g_LastSellPrice = 0;

// Last signal tracking per candle (for multi-signal logic)
datetime g_LastBuySignalBarTime = 0;
int g_LastBuySignalScore = 0;
datetime g_LastSellSignalBarTime = 0;
int g_LastSellSignalScore = 0;

// Trade Statistics Structure
struct TradeStats
{
    int count;
    int won;
    int lost;
    double profit;            // Total net profit
    double loss;              // Total net loss (sum of negative profits)
    double avgProfit;         // Average of winning trades
    double maxProfit;         // Largest single profit
    double minProfit;         // Smallest single profit
    double avgLoss;           // Average of losing trades
    double maxLoss;           // Largest single loss (most negative)
    double minLoss;           // Smallest single loss (closest to 0)
};

// +------------------------------------------------------------------+
// | Create Password Dialog                                            |
// +------------------------------------------------------------------+
bool CreatePasswordDialog()
{
    // Dialog with enough height for input + button
    if(!g_PasswordDialog.Create(0, "PasswordDialog", 0, 10, 10, 324, 120))
        return false;
    
    g_PasswordDialog.Caption("Enter Password to Use Nyao Scalper EA");
    
    // Password input - left aligned, full width
    if(!g_PasswordEdit.Create(0, "PasswordEdit", 0, 5, 10, 300, 35))
        return false;
    g_PasswordEdit.Text("");
    if(!g_PasswordDialog.Add(g_PasswordEdit))
        return false;
    
    // Submit button - left aligned
    if(!g_PasswordSubmitBtn.Create(0, "PasswordSubmit", 0, 5, 45, 100, 75))
        return false;
    g_PasswordSubmitBtn.Text("Submit");
    if(!g_PasswordDialog.Add(g_PasswordSubmitBtn))
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
        g_PasswordVerified = false;
        g_PasswordDialogActive = true;
        
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
        g_PasswordVerified = true;
        g_PasswordDialogActive = false;
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
    
    // Initialize indicator handles
    g_RSI_Handle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
    g_EMA_Fast_Handle = iMA(_Symbol, _Period, EMA_FastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_EMA_Slow_Handle = iMA(_Symbol, _Period, EMA_SlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_Bollinger_Handle = iBands(_Symbol, _Period, Bollinger_Period, 0, Bollinger_Deviation, PRICE_CLOSE);
    g_Stochastic_Handle = iStochastic(_Symbol, _Period, Stoch_KPeriod, Stoch_DPeriod, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
    
    // Validate all indicator handles
    if(g_RSI_Handle == INVALID_HANDLE || 
       g_EMA_Fast_Handle == INVALID_HANDLE || 
       g_EMA_Slow_Handle == INVALID_HANDLE ||
       g_Bollinger_Handle == INVALID_HANDLE || 
       g_Stochastic_Handle == INVALID_HANDLE)
    {
        Alert("ERROR: Failed to create indicator handles. Check indicator parameters.");
        return(INIT_FAILED);
    }
    
    // Initialize managed positions array
    ArrayResize(g_ManagedPositions, 0);
    g_ManagedPositionCount = 0;
    
    // Scan and register existing positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        // For existing positions, try to calculate current signal strength as baseline
        // If calculation fails or returns 0, use a default safe value (MinBuySignalScore)
        int initialScore = 0;
        
        // We can't easily get the signal at open time, so we use current as baseline
        // This effectively "resets" the signal tracking for this position
        SignalStrength strength;
        if(type == POSITION_TYPE_BUY) strength = GetSignalStrength(ORDER_TYPE_BUY);
        else strength = GetSignalStrength(ORDER_TYPE_SELL);
        
        initialScore = strength.totalScore;
        if(initialScore <= 0) initialScore = (type == POSITION_TYPE_BUY) ? MinBuySignalScore : MinSellSignalScore;
        
        initialScore = strength.totalScore;
        if(initialScore <= 0) initialScore = (type == POSITION_TYPE_BUY) ? MinBuySignalScore : MinSellSignalScore;
        
        RegisterManagedPosition(ticket, type, initialScore);

        // Update global last position tracking
        datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
        double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        
        // Reconstruct Candle Counters for existing positions
        datetime posBarTime = (posTime / PeriodSeconds(_Period)) * PeriodSeconds(_Period);
        datetime currentBarTime = iTime(_Symbol, _Period, 0);
        
        // Initialize current bar time if needed
        if(g_CurrentBarTime == 0) g_CurrentBarTime = currentBarTime;
        
        if(posBarTime == currentBarTime)
        {
            if(type == POSITION_TYPE_BUY) g_BuysOnCurrentBar++;
            else g_SellsOnCurrentBar++;
        }
        
        if(type == POSITION_TYPE_BUY)
        {
            if(posTime > g_LastBuyTime)
            {
                g_LastBuyTime = posTime;
                g_LastBuyPrice = posPrice;
            }
        }
        else if(type == POSITION_TYPE_SELL)
        {
            if(posTime > g_LastSellTime)
            {
                g_LastSellTime = posTime;
                g_LastSellPrice = posPrice;
            }
        }
    }
    
    Print("+-----------------------------------------+");
    Print("Nyao Scalper v27.0 Initialized Successfully");
    Print("Indicators initialized: RSI(", RSI_Period, "), EMA(", EMA_FastPeriod, "/", EMA_SlowPeriod, 
             "), BB(", Bollinger_Period, "), Stoch(", Stoch_KPeriod, ",", Stoch_DPeriod, ",", Stoch_Slowing, ")");
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
    if(g_PasswordDialogActive)
    {
        g_PasswordDialog.Destroy();
        g_PasswordDialogActive = false;
    }
    
    // Release indicator handles
    if(g_RSI_Handle != INVALID_HANDLE) IndicatorRelease(g_RSI_Handle);
    if(g_EMA_Fast_Handle != INVALID_HANDLE) IndicatorRelease(g_EMA_Fast_Handle);
    if(g_EMA_Slow_Handle != INVALID_HANDLE) IndicatorRelease(g_EMA_Slow_Handle);
    if(g_Bollinger_Handle != INVALID_HANDLE) IndicatorRelease(g_Bollinger_Handle);
    if(g_Stochastic_Handle != INVALID_HANDLE) IndicatorRelease(g_Stochastic_Handle);
    
    // Cleanup Dashboard Objects
    ObjectsDeleteAll(0, "NyaoDash_");
    Comment(""); // Clear any residual comments
    
    Print("Nyao Scalper v27.0 Deinitialized");
}

// +------------------------------------------------------------------+
// | Expert Tick Function                                             |
void OnTick()
{   
    // Block trading until password is verified
    if(!g_PasswordVerified)
    {
        return;
    }
    
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
        return;
    }

    // Check if current time is within allowed trading hours
    CheckTradingHours();

    // Check for leverage changes
    CheckLeverageChange();

    // Check for market close time
    CheckMarketClose();

    if (isOutsideTradingHours || isLeverageDiffFromInitial || isNearMarketClose)
    {   
        // Don't open new positions, but continue managing existing ones
        ManagePositions();
        LogPrint("[PAUSED] Trading paused.");
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
            LogPrint("[PAUSED] Paused. Time remaining: ", (pauseDurationSeconds - elapsedSeconds) / 60, " minute(s)");
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
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if(g_PasswordDialogActive)
    {
        g_PasswordDialog.OnEvent(id, lparam, dparam, sparam);
        
        // Check for submit button click
        if(id == CHARTEVENT_OBJECT_CLICK && sparam == "PasswordSubmit")
        {
            string enteredPassword = g_PasswordEdit.Text();
            
            if(enteredPassword == EA_PASSWORD)
            {
                // Password correct - close dialog and initialize EA
                g_PasswordDialog.Destroy();
                g_PasswordDialogActive = false;
                g_PasswordVerified = true;
                
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
                g_PasswordEdit.Text("");
            }
        }
    }
}

// +------------------------------------------------------------------+
// | Check For Trading Signals                                        |
// +------------------------------------------------------------------+
void CheckForTradingSignal()
{   
    // Check Signals
    int buySignal = BuySignal();
    int sellSignal = SellSignal();

    // Process BUY signals
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
int BuySignal()
{   
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    bool isPyramiding = false;
    
    // Check strict conditions (limits & distance) first - O(1)
    if(!CheckBuyConditions(currentPrice, isPyramiding)) return 0;

    // Only calculate heavyweight indicators if conditions allow
    SignalStrength strength = GetSignalStrength(ORDER_TYPE_BUY);

    // Dynamic threshold based on context
    int requiredScore = isPyramiding ? MinPyramidingBuySignalScore : MinBuySignalScore;

    if (strength.totalScore >= requiredScore) 
    {   
        LogPrint("BUY SIGNAL RECEIVED (Score: ", strength.totalScore, "/", requiredScore, ")");
        LogPrint("Details: RSI=", strength.rsiScore, 
                 ", EMA=", strength.emaScore, 
                 ", BB=", strength.bollingerScore, 
                 ", Stoch=", strength.stochasticScore, 
                 ", Wick=", strength.wickScore,
                 ", Mom=", strength.momentumScore,
                 ", SR=", strength.supportResistanceScore,
                 ", Break=", strength.breakoutScore);
        LogPrint("Reasoning: ", strength.reasoning);
        LogPrint("Context: ", isPyramiding ? "Pyramiding" : "Standard");
        LogPrint("Price: ", currentPrice);

        return strength.totalScore;
    }
    
    return 0;
}

// Sell Signal
int SellSignal()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    bool isPyramiding = false;
    
    // Check strict conditions (limits & distance) first - O(1)
    // NOTE: CheckSellConditions returns true if valid
    if(!CheckSellConditions(currentPrice, isPyramiding)) return 0;

    // Only calculate heavyweight indicators if conditions allow
    SignalStrength strength = GetSignalStrength(ORDER_TYPE_SELL);

    // Dynamic threshold based on context
    int requiredScore = isPyramiding ? MinPyramidingSellSignalScore : MinSellSignalScore;

    if (strength.totalScore >= requiredScore)
    {
        LogPrint("SELL SIGNAL RECEIVED (Score: ", strength.totalScore, "/", requiredScore, ")");
        LogPrint("Details: RSI=", strength.rsiScore, 
                 ", EMA=", strength.emaScore, 
                 ", BB=", strength.bollingerScore, 
                 ", Stoch=", strength.stochasticScore, 
                 ", Wick=", strength.wickScore,
                 ", Mom=", strength.momentumScore,
                 ", SR=", strength.supportResistanceScore,
                 ", Break=", strength.breakoutScore);
        LogPrint("Reasoning: ", strength.reasoning);
        LogPrint("Context: ", isPyramiding ? "Pyramiding" : "Standard");
        LogPrint("Price: ", currentPrice);

        return strength.totalScore;
    }
    
    return 0;
}

// +------------------------------------------------------------------+
// | Get Last Position Ticket by Type                                 |
// | Returns the ticket of the most recently opened position          |
// +------------------------------------------------------------------+
ulong GetLastPositionTicket(ENUM_POSITION_TYPE type)
{
    ulong lastTicket = 0;
    datetime lastTime = 0;

    // OPTIMIZATION: Iterate through managed positions array 
    // instead of scanning all account positions
    for(int i = 0; i < g_ManagedPositionCount; i++)
    {
        ulong ticket = g_ManagedPositions[i].ticket;
        
        // Initial filter by cached type
        if(g_ManagedPositions[i].type != type) continue;

        // Verify position still exists and get exact time
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

// FAST duplicate buy filter - O(1) using globals
// Returns true if conditions allow a trade.
// Sets isPyramiding=true if we are adding to a position on the same candle.
bool CheckBuyConditions(double price, bool &isPyramiding)
{
    isPyramiding = false;
    datetime currentBarTime = iTime(_Symbol, _Period, 0);

    // Determine effective count
    int buysOnCandle = (g_CurrentBarTime == currentBarTime) ? g_BuysOnCurrentBar : 0;
    
    // Check Pyramiding Limits per Candle
    int limit = EnablePyramiding ? MaxPositionsPerCandle : 1;
    
    if(buysOnCandle >= limit)
    {
        return false;
    }

    // Check Last Position Profit (Pyramiding Logic)
    // Only allow pyramiding on the SAME CANDLE if the last position is in profit
    ulong lastTicket = GetLastPositionTicket(POSITION_TYPE_BUY);
    if(lastTicket > 0)
    {
        if(PositionSelectByTicket(lastTicket))
        {
            datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
            datetime posBarTime = (posTime / PeriodSeconds(_Period)) * PeriodSeconds(_Period);
            
            // Only apply strict profit check if on the SAME CANDLE
            if(posBarTime == currentBarTime)
            {
                double profit = PositionGetDouble(POSITION_PROFIT);
                double currentSL = PositionGetDouble(POSITION_SL);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

                // 1. Must be in profit
                if(profit <= 0)
                {
                    return false;
                }
                
                // 2. Must have profitable SL (SL > OpenPrice)
                // If SL is 0 or less than open price, it's not secured -> Block
                if(currentSL == 0 || currentSL <= openPrice)
                {
                    return false;
                }
            }
        }
    }

    // Check if we have a previous buy position
    if(g_LastBuyTime > 0)
    {
        // Fast bar time calculation
        datetime lastPosBarTime = (g_LastBuyTime / PeriodSeconds(_Period)) * PeriodSeconds(_Period);
        
        // Only check distance if opened on SAME bar
        if(lastPosBarTime == currentBarTime)
        {
            isPyramiding = true; // Adding within the same bar
            
            double minDistance = ZonePoints * _Point * BuyDuplicateMultiplier;
            double distance = MathAbs(price - g_LastBuyPrice);
            
            if(distance < minDistance)
            {
                return false;
            }
        }
    }
    
    return true;
}

// FAST duplicate sell filter - O(1) using globals
// Returns true if conditions allow a trade.
// Sets isPyramiding=true if we are adding to a position on the same candle.
bool CheckSellConditions(double price, bool &isPyramiding)
{
    isPyramiding = false;
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    
    // Determine effective count
    int sellsOnCandle = (g_CurrentBarTime == currentBarTime) ? g_SellsOnCurrentBar : 0;
    
    // Check Pyramiding Limits per Candle
    int limit = EnablePyramiding ? MaxPositionsPerCandle : 1;
    
    if(sellsOnCandle >= limit)
    {
        return false;
    }

    // Check Last Position Profit (Pyramiding Logic)
    // Only allow pyramiding on the SAME CANDLE if the last position is in profit
    ulong lastTicket = GetLastPositionTicket(POSITION_TYPE_SELL);
    if(lastTicket > 0)
    {
        if(PositionSelectByTicket(lastTicket))
        {
            datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
            datetime posBarTime = (posTime / PeriodSeconds(_Period)) * PeriodSeconds(_Period);
            
            // Only apply strict profit check if on the SAME CANDLE
            if(posBarTime == currentBarTime)
            {
                double profit = PositionGetDouble(POSITION_PROFIT);
                double currentSL = PositionGetDouble(POSITION_SL);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

                // 1. Must be in profit
                if(profit <= 0)
                {
                    return false;
                }

                // 2. Must have profitable SL (SL < OpenPrice)
                // If SL is 0 or greater than open price, it's not secured -> Block
                if(currentSL == 0 || currentSL >= openPrice)
                {
                    return false;
                }
            }
        }
    }

    // Check if we have a previous sell position
    if(g_LastSellTime > 0)
    {
        // Fast bar time calculation
        datetime lastPosBarTime = (g_LastSellTime / PeriodSeconds(_Period)) * PeriodSeconds(_Period);
        
        // Only check distance if opened on SAME bar
        if(lastPosBarTime == currentBarTime)
        {
            isPyramiding = true; // Adding within the same bar
            
            double minDistance = ZonePoints * _Point * SellDuplicateMultiplier;
            double distance = MathAbs(price - g_LastSellPrice);
            
            if(distance < minDistance)
            {
                return false;
            }
        }
    }
    
    return true;
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Manage Positions - Unified Position Management System            |
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
// | Signal Strength Analysis - Indicator-Based Scoring System        |
// | Uses RSI, EMA, Bollinger Bands, Stochastic + Candle Analysis     |
// | Weights are adjustable via input variables:                      |
// |   WeightRSI, WeightEMA, WeightBollinger, WeightStochastic        |
// |   ScoreCandleWick, ScoreCandleMomentum, ScoreNearSR, ScoreBreakSR|
// +------------------------------------------------------------------+
SignalStrength GetSignalStrength(ENUM_ORDER_TYPE orderType)
{
    SignalStrength strength;
    
    // Initialize all scores to 0
    strength.rsiScore = 0;
    strength.emaScore = 0;
    strength.bollingerScore = 0;
    strength.stochasticScore = 0;
    strength.candleScore = 0;
    strength.wickScore = 0;
    strength.momentumScore = 0;
    strength.supportResistanceScore = 0;
    strength.breakoutScore = 0;
    strength.buyScore = 0;
    strength.sellScore = 0;
    strength.totalScore = 0;
    strength.reasoning = "";
    
    // ================================================================
    // 1. EMA SCORE (Weight: 3x)
    // ================================================================
    double emaFastBuffer[], emaSlowBuffer[];
    ArraySetAsSeries(emaFastBuffer, true);
    ArraySetAsSeries(emaSlowBuffer, true);
    
    bool isUptrend = false;
    bool isDowntrend = false;
    
    if(CopyBuffer(g_EMA_Fast_Handle, 0, 0, 3, emaFastBuffer) >= 3 &&
       CopyBuffer(g_EMA_Slow_Handle, 0, 0, 3, emaSlowBuffer) >= 3)
    {
        double emaFast = emaFastBuffer[0];
        double emaSlow = emaSlowBuffer[0];
        double emaFastPrev = emaFastBuffer[1];
        double emaSlowPrev = emaSlowBuffer[1];
        double currentPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        int emaBuyScore = 0;
        int emaSellScore = 0;
        
        if(emaFast > emaSlow) isUptrend = true;
        if(emaFast < emaSlow) isDowntrend = true;
        
        if(isUptrend)
        {
            if(emaFastPrev <= emaSlowPrev) { emaBuyScore = 5; strength.reasoning += "[EMA Cross] "; }
            else if(currentPrice > emaFast) { emaBuyScore = 4; }
            else { emaBuyScore = 2; }
        }
        
        if(isDowntrend)
        {
            if(emaFastPrev >= emaSlowPrev) { emaSellScore = 5; strength.reasoning += "[EMA Cross] "; }
            else if(currentPrice < emaFast) { emaSellScore = 4; }
            else { emaSellScore = 2; }
        }
        
        strength.buyScore += emaBuyScore * WeightEMA;
        strength.sellScore += emaSellScore * WeightEMA;
        strength.emaScore = (orderType == ORDER_TYPE_BUY) ? emaBuyScore : emaSellScore;
    }

    // ================================================================
    // 2. BOLLINGER BANDS SCORE (Weight: 2x)
    // ================================================================
    double bbMiddle[], bbUpper[], bbLower[];
    ArraySetAsSeries(bbMiddle, true);
    ArraySetAsSeries(bbUpper, true);
    ArraySetAsSeries(bbLower, true);
    
    if(CopyBuffer(g_Bollinger_Handle, 0, 0, 2, bbMiddle) >= 2 &&
       CopyBuffer(g_Bollinger_Handle, 1, 0, 2, bbUpper) >= 2 &&
       CopyBuffer(g_Bollinger_Handle, 2, 0, 2, bbLower) >= 2)
    {
        double close0 = iClose(_Symbol, _Period, 0);
        double close1 = iClose(_Symbol, _Period, 1);
        int bbBuyScore = 0;
        int bbSellScore = 0;
        
        // Lower Band Rejection
        if(close1 < bbLower[1] && close0 > bbLower[0]) 
        {
            bbBuyScore = 2;
            strength.reasoning += "[BB Low Rej] ";
        }
        else if(close0 < bbLower[0]) bbBuyScore = 1; 

        // Upper Band Rejection
        if(close1 > bbUpper[1] && close0 < bbUpper[0])
        {
            bbSellScore = 2;
            strength.reasoning += "[BB High Rej] ";
        }
        else if(close0 > bbUpper[0]) bbSellScore = 1;
        
        strength.buyScore += bbBuyScore * WeightBollinger;
        strength.sellScore += bbSellScore * WeightBollinger;
        strength.bollingerScore = (orderType == ORDER_TYPE_BUY) ? bbBuyScore : bbSellScore;
    }
    
    // ================================================================
    // 3. RSI SCORE (Weight: 3x)
    // ================================================================
    double rsiBuffer[];
    ArraySetAsSeries(rsiBuffer, true);
    
    if(CopyBuffer(g_RSI_Handle, 0, 0, 3, rsiBuffer) >= 3)
    {
        double rsi = rsiBuffer[0];
        double rsiPrev = rsiBuffer[1];
        int rsiBuyScore = 0;
        int rsiSellScore = 0;
        
        if(rsi < RSI_OversoldLevel)
        {
             if(rsi > rsiPrev) { rsiBuyScore = 3; strength.reasoning += "[RSI Hook Up] "; }
             else { rsiBuyScore = 1; }
        }
        else if(rsi < (RSI_OversoldLevel + 10) && rsi > rsiPrev && isUptrend)
        {
             rsiBuyScore = 2;
             strength.reasoning += "[RSI Dip] ";
        }
        
        if(rsi > RSI_OverboughtLevel)
        {
             if(rsi < rsiPrev) { rsiSellScore = 3; strength.reasoning += "[RSI Hook Down] "; }
             else { rsiSellScore = 1; }
        }
        else if(rsi > (RSI_OverboughtLevel - 10) && rsi < rsiPrev && isDowntrend)
        {
             rsiSellScore = 2;
             strength.reasoning += "[RSI Rally] ";
        }
        
        strength.buyScore += rsiBuyScore * WeightRSI;
        strength.sellScore += rsiSellScore * WeightRSI;
        strength.rsiScore = (orderType == ORDER_TYPE_BUY) ? rsiBuyScore : rsiSellScore;
    }

    // ================================================================
    // 4. STOCHASTIC SCORE (Weight: 2x)
    // ================================================================
    double stochK[], stochD[];
    ArraySetAsSeries(stochK, true);
    ArraySetAsSeries(stochD, true);
    
    if(CopyBuffer(g_Stochastic_Handle, 0, 0, 3, stochK) >= 3 &&
       CopyBuffer(g_Stochastic_Handle, 1, 0, 3, stochD) >= 3)
    {
        double k = stochK[0];
        double d = stochD[0];
        double kPrev = stochK[1];
        double dPrev = stochD[1];
        int stochBuyScore = 0;
        int stochSellScore = 0;
        
        if(k < Stoch_OversoldLevel)
        {
            if(k > d && kPrev <= dPrev) { stochBuyScore = 2; strength.reasoning += "[Stoch Cross] "; }
            else if(k > kPrev) { stochBuyScore = 1; }
        }
        
        if(k > Stoch_OverboughtLevel)
        {
            if(k < d && kPrev >= dPrev) { stochSellScore = 2; strength.reasoning += "[Stoch Cross] "; }
            else if(k < kPrev) { stochSellScore = 1; }
        }
        
        strength.buyScore += stochBuyScore * WeightStochastic;
        strength.sellScore += stochSellScore * WeightStochastic;
        strength.stochasticScore = (orderType == ORDER_TYPE_BUY) ? stochBuyScore : stochSellScore;
    }
    
    // ================================================================
    // 5. CANDLE ANALYSIS (Separated Wick & Momentum)
    // ================================================================
    double open0 = iOpen(_Symbol, _Period, 0);
    double close0 = iClose(_Symbol, _Period, 0); // Active candle
    double high0 = iHigh(_Symbol, _Period, 0);
    double low0 = iLow(_Symbol, _Period, 0);
    
    double open1 = iOpen(_Symbol, _Period, 1);
    double close1 = iClose(_Symbol, _Period, 1); // Last completed
    double high1 = iHigh(_Symbol, _Period, 1);
    double low1 = iLow(_Symbol, _Period, 1);
    
    int wickBuyScore = 0;
    int wickSellScore = 0;
    int momentumBuyScore = 0;
    int momentumSellScore = 0;
    
    // -- Wick Analysis (Rejection) --
    double bodySize1 = MathAbs(close1 - open1);
    double upperWick1 = high1 - MathMax(open1, close1);
    double lowerWick1 = MathMin(open1, close1) - low1;
    double totalSize1 = high1 - low1;
    
    if(totalSize1 > 0)
    {
        // Hammer / Pinbar at Low
        if(lowerWick1 > bodySize1 * 2 && upperWick1 < bodySize1)
        {
            wickBuyScore = ScoreCandleWick;
            strength.reasoning += "[Hammer] ";
        }
        // Shooting Star / Pinbar at High
        if(upperWick1 > bodySize1 * 2 && lowerWick1 < bodySize1)
        {
            wickSellScore = ScoreCandleWick;
            strength.reasoning += "[Shooter] ";
        }
    }
    
    // -- Momentum Shift --
    double bodySize0 = MathAbs(close0 - open0);
    
    if(bodySize0 > bodySize1 * 1.5) // Active candle is significantly larger
    {
        if(close0 > open0) // Bullish Momentum
        {
            momentumBuyScore = ScoreCandleMomentum;
            strength.reasoning += "[Mom. Shift] ";
        }
        if(close0 < open0) // Bearish Momentum
        {
            momentumSellScore = ScoreCandleMomentum;
            strength.reasoning += "[Mom. Shift] ";
        }
    }
    
    strength.wickScore = (orderType == ORDER_TYPE_BUY) ? wickBuyScore : wickSellScore;
    strength.momentumScore = (orderType == ORDER_TYPE_BUY) ? momentumBuyScore : momentumSellScore;
    
    strength.buyScore += wickBuyScore + momentumBuyScore;
    strength.sellScore += wickSellScore + momentumSellScore;
    strength.candleScore = strength.wickScore + strength.momentumScore; 

    // ================================================================
    // 6. SUPPORT AND RESISTANCE & 7. BREAKOUT (Detailed)
    // ================================================================
    
    int srBuyScore = 0;
    int srSellScore = 0;
    int breakoutBuyScore = 0;
    int breakoutSellScore = 0;

    int lookback = SR_LookbackPeriod;
    int highestIndex = iHighest(_Symbol, _Period, MODE_HIGH, lookback, 1);
    int lowestIndex = iLowest(_Symbol, _Period, MODE_LOW, lookback, 1);
    
    if(highestIndex != -1 && lowestIndex != -1)
    {
        double resistancePrice = iHigh(_Symbol, _Period, highestIndex);
        double supportPrice = iLow(_Symbol, _Period, lowestIndex);
        double currentPrice = (close0); 
        
        double range = resistancePrice - supportPrice;
        double threshold = range * 0.1; // 10% tolerance
        
        // Near Support (Buy Potential)
        if(MathAbs(currentPrice - supportPrice) < threshold)
        {
            srBuyScore = ScoreNearSR;
            strength.reasoning += "[Near Supp] ";
        }
        
        // Near Resistance (Sell Potential)
        if(MathAbs(currentPrice - resistancePrice) < threshold)
        {
            srSellScore = ScoreNearSR;
            strength.reasoning += "[Near Res] ";
        }
        
        // Breakout Support (Sell Loophole)
        if(close0 < supportPrice)
        {
            breakoutSellScore = ScoreBreakoutSR;
            strength.reasoning += "[Supp Broken] ";
        }
        
        // Breakout Resistance (Buy Loophole)
        if(close0 > resistancePrice)
        {
            breakoutBuyScore = ScoreBreakoutSR;
            strength.reasoning += "[Res Broken] ";
        }
    }
    
    strength.supportResistanceScore = (orderType == ORDER_TYPE_BUY) ? srBuyScore : srSellScore;
    strength.breakoutScore = (orderType == ORDER_TYPE_BUY) ? breakoutBuyScore : breakoutSellScore;
    
    strength.buyScore += srBuyScore + breakoutBuyScore;
    strength.sellScore += srSellScore + breakoutSellScore;

    // ================================================================
    // FINAL SCORE & TREND FILTER
    // ================================================================
    if(isUptrend && strength.sellScore > 0)
    {
        strength.sellScore = (int)(strength.sellScore * 0.5); 
        strength.reasoning += "[Trend Filter] ";
    }
    
    if(isDowntrend && strength.buyScore > 0)
    {
        strength.buyScore = (int)(strength.buyScore * 0.5); 
        strength.reasoning += "[Trend Filter] ";
    }

    if(strength.buyScore > strength.sellScore)
    {
        strength.totalScore = strength.buyScore;
        if(orderType == ORDER_TYPE_SELL) strength.totalScore = 0;
    }
    else if(strength.sellScore > strength.buyScore)
    {
        strength.totalScore = strength.sellScore;
        if(orderType == ORDER_TYPE_BUY) strength.totalScore = 0;
    }
    else
    {
        strength.totalScore = 0;
    }
    
    return strength;
}

// +------------------------------------------------------------------+
// | Manage Losing Positions - Signal Strength Based                  |
// | Uses current signal strength vs initial to manage positions      |
// +------------------------------------------------------------------+
void ManageLosingPositions()
{
    if(!EnableLossManagement) return;
    
    int holdCount = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        double profit = PositionGetDouble(POSITION_PROFIT);
        
        // Only process losing positions
        if(profit < -(MinBreakEvenProfit * LossThresholdMultiplier))
        {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Get current signal strength for this position's direction
            SignalStrength currentStrength;
            ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            currentStrength = GetSignalStrength(orderType);
            
            int currentScore = currentStrength.totalScore;
            
            // Get initial signal score from managed positions array
            int initialScore = 0;
            for(int j = 0; j < g_ManagedPositionCount; j++)
            {
                if(g_ManagedPositions[j].ticket == ticket)
                {
                    initialScore = g_ManagedPositions[j].signalScore;
                    break;
                }
            }
            
            // Calculate signal strength change
            // Positive = signal strengthened, Negative = signal weakened
            int signalChange = currentScore - initialScore;
            
            LogPrint("+-----------------------------------------+");
            LogPrint("LOSING POSITION ANALYSIS (Signal-Based)");
            LogPrint("Ticket: ", ticket, " | Type: ", EnumToString(posType));
            LogPrint("Profit: $", profit);
            LogPrint("Initial Signal Score: ", initialScore, " | Current: ", currentScore);
            LogPrint("Signal Change: ", signalChange, " (positive = stronger)");
            LogPrint("Reasoning: ", currentStrength.reasoning);
            LogPrint("+-----------------------------------------+");
            
            // Decision logic based on signal strength:
            // 1. Signal still strong (currentScore >= initial or above threshold) = HOLD
            // 2. Signal weakened significantly (dropped by half or below threshold) = CLOSE
            
            bool shouldClose = false;
            string closeReason = "";
            
            // Check 1: Signal weakened significantly
            // If current score is below minimum threshold
            if(currentScore < MinSignalStrengthToHold && currentScore < initialScore)
            {
                shouldClose = true;
                closeReason = "Signal Below Threshold (" + IntegerToString(currentScore) + " < " + IntegerToString(MinSignalStrengthToHold) + ")";
            }
            
            if(shouldClose)
            {
                LogPrint("+-----------------------------------------+");
                LogPrint("CLOSING LOSING POSITION");
                LogPrint("Ticket: ", ticket, " | Profit: $", profit);
                LogPrint("Reason: ", closeReason);
                LogPrint("+-----------------------------------------+");
                
                ClosePosition(ticket);
            }
            else
            {
                holdCount++;
                LogPrint("HOLDING position ", ticket, " - Signal still strong (Score: ", currentScore, ", Hold: ", holdCount, "/", MaxHoldingLossPositions, ")");
            }
        }
    }
}

int CountLosingPositions()
{   
    int count = 0;  // ← Use separate counter variable

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
    if(!PositionSelectByTicket(ticket)) return;
    
    // Get Position Details
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double profit = PositionGetDouble(POSITION_PROFIT);
    double volume = PositionGetDouble(POSITION_VOLUME);
    
    // Get Signal Strength
    ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    SignalStrength currentStrength = GetSignalStrength(orderType);
    int currentScore = currentStrength.totalScore;
    
    int initialScore = 0;
    int posIndex = GetManagedPositionIndex(ticket);
    if(posIndex != -1)
    {
        initialScore = g_ManagedPositions[posIndex].signalScore;
    }
    
    // ================================================================
    // ADAPTIVE LOGIC (Delta Based)
    // ================================================================
    double tpAdjustment = 0;
    double slAdjustment = 0;
    string adaptiveReason = "Normal";

    // Calculate score delta (Current - Initial)
    // Positive delta = Signal Strengthened
    // Negative delta = Signal Weakened
    int scoreDelta = currentScore - initialScore;
    
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
            adaptiveReason = "Adaptive (Delta: " + IntegerToString(scoreDelta) + ")";
        }
    }
    
    // ================================================================
    // TAKE PROFIT MANAGEMENT (Adaptive)
    // ================================================================
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

    // ================================================================
    // TRAILING STOP MANAGEMENT
    // ================================================================
    double newSL = currentSL; // Default to current
    bool shouldModifySL = false;

    if(EnableTrailing) 
    {
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
        
        // ================================================================
        // EMERGENCY CLOSE MECHANISM
        // ================================================================
        // Trigger if modification failed AND profit is substantial
        // Prevents losing "substantial" profit due to inability to trail
        
        double minSubstantialProfit = MinBreakEvenProfit * 3.0; // Define substantial as 3x minimum target
        
        if(profit >= minSubstantialProfit)
        {
            LogPrint("!! EMERGENCY CLOSE TRIGGERED !!");
            ClosePosition(ticket);
        }
    }
}
    
// +------------------------------------------------------------------+
// | Register Position to Managed Array                               |
// +------------------------------------------------------------------+
void RegisterManagedPosition(ulong ticket, ENUM_POSITION_TYPE type, int signalScore)
{
    // Resize array
    ArrayResize(g_ManagedPositions, g_ManagedPositionCount + 1);
    
    // Fill position data
    g_ManagedPositions[g_ManagedPositionCount].ticket = ticket;
    g_ManagedPositions[g_ManagedPositionCount].type = type;
    g_ManagedPositions[g_ManagedPositionCount].signalScore = signalScore;
    
    g_ManagedPositionCount++;
    
    // Update counters
    if(type == POSITION_TYPE_BUY) g_BuyPositionCount++;
    else g_SellPositionCount++;
    
    LogPrint("Registered position. Ticket: ", ticket, 
             " | Type: ", EnumToString(type),
             " | Score: ", signalScore, 
             " | Open Buys: ", g_BuyPositionCount, " | Open Sells: ", g_SellPositionCount);
}

// +------------------------------------------------------------------+
// | Remove Position from Managed Array                               |
// +------------------------------------------------------------------+
void RemoveManagedPosition(ulong ticket)
{
    for(int i = 0; i < g_ManagedPositionCount; i++)
    {
        if(g_ManagedPositions[i].ticket == ticket)
        {
            // Update counters before removing
            if(g_ManagedPositions[i].type == POSITION_TYPE_BUY) g_BuyPositionCount--;
            else g_SellPositionCount--;
            
            // Safety check for negative counters
            if(g_BuyPositionCount < 0) g_BuyPositionCount = 0;
            if(g_SellPositionCount < 0) g_SellPositionCount = 0;

            // Shift array elements left
            for(int j = i; j < g_ManagedPositionCount - 1; j++)
            {
                g_ManagedPositions[j] = g_ManagedPositions[j + 1];
            }
            
            g_ManagedPositionCount--;
            ArrayResize(g_ManagedPositions, g_ManagedPositionCount);
            
            LogPrint("Removed position: ", ticket, 
                     " | Remaining Open Buys: ", g_BuyPositionCount, 
                     " | Remaining Open Sells: ", g_SellPositionCount);
            break;
        }
    }
}

// +------------------------------------------------------------------+
// | Sync Managed Positions with Broker                               |
// | Removes closed positions from managed array                      |
// +------------------------------------------------------------------+
void SyncManagedPositions()
{
    for(int i = g_ManagedPositionCount - 1; i >= 0; i--)
    {
        // Check if position still exists
        if(!PositionSelectByTicket(g_ManagedPositions[i].ticket))
        {
            // Position closed, remove from array
            RemoveManagedPosition(g_ManagedPositions[i].ticket);
        }
    }
}

// +------------------------------------------------------------------+
// | Get Managed Position by Ticket                                   |
// +------------------------------------------------------------------+
int GetManagedPositionIndex(ulong ticket)
{
    for(int i = 0; i < g_ManagedPositionCount; i++)
    {
        if(g_ManagedPositions[i].ticket == ticket)
        {
            return i;
        }
    }
    return -1;
}

// Open position with dynamic lot sizing AND fixed SL/TP
void OpenPosition(ENUM_ORDER_TYPE orderType, int signalScore = 0)
{   
    if (!IsAllowedToOpenPosition()) return;

    LockOrderSend(true);

    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    // Pass signal score for dynamic lot sizing
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
        double slPoints = ConvertToPoints(SLInputType, SLValue, currentLot);
        
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
                LogPrint("  SL: ", request.sl);
            }
            if(EnableTakeProfit)
            {
                LogPrint("  TP: ", request.tp);
            }
            
            // Register position to managed array
            ENUM_POSITION_TYPE posType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            RegisterManagedPosition(result.order, posType, signalScore);
            
            // Update Candle Counters
            datetime currentBarTime = iTime(_Symbol, _Period, 0);
            if(g_CurrentBarTime != currentBarTime)
            {
                g_CurrentBarTime = currentBarTime;
                g_BuysOnCurrentBar = 0;
                g_SellsOnCurrentBar = 0;
            }
            
            if(orderType == ORDER_TYPE_BUY) g_BuysOnCurrentBar++;
            else g_SellsOnCurrentBar++;
            
            // Update global last position tracking
            if(orderType == ORDER_TYPE_BUY)
            {
                g_LastBuyTime = TimeCurrent();
                g_LastBuyPrice = price;
            }
            else
            {
                g_LastSellTime = TimeCurrent();
                g_LastSellPrice = price;
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
        return true; // No change needed
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
//| Lot increases based on:                                           |
//|   1. Equity drop from peak (EquityDropPercent per step)          |
//|   2. Strong signal strength (MinSignalStrengthForLot threshold)   |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(int signalScore = 0)
{
    if(!EnableDynamicLots) return BaseLotSize;
    
    double currentLot = BaseLotSize;
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // ================================================================
    // 1. EQUITY DROP-BASED LOT INCREASE
    // ================================================================
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
    
    // ================================================================
    // 2. SIGNAL STRENGTH-BASED LOT INCREASE
    // ================================================================
    // If signal score is above threshold, add extra lot steps
    double signalLotIncrease = 0;
    if(signalScore >= MinSignalStrengthForLot)
    {
        // For every 2 points above threshold, add one lot step
        int signalSteps = (signalScore - MinSignalStrengthForLot) / 2;
        signalLotIncrease = signalSteps * LotStepSize;
        currentLot += signalLotIncrease;
    }
    
    // ================================================================
    // APPLY LIMITS
    // ================================================================
    // Apply user-defined limits
    if(currentLot < BaseLotSize) currentLot = BaseLotSize;
    if(currentLot > MaxLotSize) currentLot = MaxLotSize;

    // Apply broker limits
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(currentLot < minLot) currentLot = minLot;
    if(currentLot > maxLot) currentLot = maxLot;
        
    // Round to valid lot step
    currentLot = MathFloor(currentLot / lotStep) * lotStep;
    
    // ================================================================
    // MARGIN CHECK
    // ================================================================
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
                    LogPrint("Error: Invalid tick value (", tickValue, 
                          "), tick size (", tickSize, 
                          "), point (", point,
                          "), or lot size (", lotSize, ")");
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
    datetime start = serverTime - minutesBefore * 60;
    datetime end = serverTime + minutesAfter * 60;
    
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
                        continue; // Skip unrelated currencies
                    }
                    
                    // Check if we're within the event window (before OR after)
                    datetime eventTime = values[i].time;
                    datetime pauseStart = eventTime - minutesBefore * 60;
                    datetime pauseEnd = eventTime + minutesAfter * 60;
                    
                    if(serverTime < pauseStart || serverTime > pauseEnd)
                    {
                        continue; // Outside event window
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

        if(CalendarValueHistory(values, currentServerTime - 60, currentServerTime + NewsMinutesAfter * 60))
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
    daily.maxLoss = 0; daily.minLoss = -DBL_MAX; // maxLoss is most negative, minLoss is closest to 0 (-0.01)

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

            // Filter for exits
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
                    // Loss is negative. Max loss = most negative (smallest value). Min loss = least negative (largest value).
                    // "Largest Loss" -> -100. "Smallest Loss" -> -1.
                    if(profit < allTime.maxLoss) allTime.maxLoss = profit; // e.g. -100 < 0
                    if(profit > allTime.minLoss) allTime.minLoss = profit; // e.g. -1 > -DBL_MAX
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
    json += "\"footer\":{\"text\":\"Nyao Scalper v27.0\"}";
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
// | Update On-Chart Dashboard (Object Based)                          |
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
    int lineHeight = 18; // Increased line spacing
    int headersize = 10;
    int textsize = 9;
    int detailsSize = 8;
    
    color colorHeader = clrGold;
    color colorText = clrWhite;
    color colorBuy = clrLime;
    color colorSell = clrRed;
    color colorNeutral = clrGray;
    color colorBg = C'30,30,30'; // Dark Gray
    color colorBorder = clrGold;

    int currentY = startY;

    // Header
    DrawDashboardLabel("NyaoDash_Title", "Nyao Scalper v27.0", startX, currentY, 11, colorHeader, true);
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
    SignalStrength buyStrength = GetSignalStrength(ORDER_TYPE_BUY);
    SignalStrength sellStrength = GetSignalStrength(ORDER_TYPE_SELL);
    int buyReq = MinBuySignalScore;
    int sellReq = MinSellSignalScore;
    if(g_BuyPositionCount > 0) buyReq = MinPyramidingBuySignalScore;
    if(g_SellPositionCount > 0) sellReq = MinPyramidingSellSignalScore;

    DrawDashboardLabel("NyaoDash_SigHead", "SIGNAL STRENGTH:", startX, currentY, headersize, colorHeader, true);
    currentY += lineHeight;

    // Buy Row
    string buyText = StringFormat("BUY: %d / %d  %s", buyStrength.totalScore, buyReq, buyStrength.reasoning);
    DrawDashboardLabel("NyaoDash_Buy", buyText, startX, currentY, textsize, buyStrength.totalScore >= buyReq ? colorBuy : colorText, true);
    currentY += lineHeight;
    
    string buyDet = StringFormat("RSI:%d EMA:%d BB:%d Sto:%d Cdl:%d", 
                  buyStrength.rsiScore, buyStrength.emaScore, buyStrength.bollingerScore, 
                  buyStrength.stochasticScore, buyStrength.candleScore);
    DrawDashboardLabel("NyaoDash_BuyDet", buyDet, startX, currentY, detailsSize, colorText);
    currentY += lineHeight + 2;

    // Sell Row
    string sellText = StringFormat("SELL: %d / %d  %s", sellStrength.totalScore, sellReq, sellStrength.reasoning);
    DrawDashboardLabel("NyaoDash_Sell", sellText, startX, currentY, textsize, sellStrength.totalScore >= sellReq ? colorSell : colorText, true);
    currentY += lineHeight;

    string sellDet = StringFormat("RSI:%d EMA:%d BB:%d Sto:%d Cdl:%d", 
                  sellStrength.rsiScore, sellStrength.emaScore, sellStrength.bollingerScore, 
                  sellStrength.stochasticScore, sellStrength.candleScore);
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