// +------------------------------------------------------------------+
// |                                          Nyao Scalper v21.0      |
// |             Candle Prediction with Smart Multi-Entry System      |
// |              with Equity & Risk Management + Discord Alerts      |
// |                                    © Copyright Nyao Scalper      |
// +------------------------------------------------------------------+
#property copyright "© Copyright Nyao Scalper by Elriz Wiraswara"
#property version   "21.0"
#property description "Auto Trading EA Robot with Smart Multi-Entry & Position Management."
#property description "Do with your own risk. Results may vary based on market conditions."
#property strict

// Windows API for Algo Trading Button Control
#define MT_WMCMD_EXPERTS   32851
#define WM_COMMAND 0x0111
#define GA_ROOT    2
#include <WinAPI\winapi.mqh>

// Print wrapper with logging control
#define LogPrint if(EnableLogging) Print

enum ENUM_INPUT_TYPE
{
    INPUT_DOLLAR,                                         // Dollar Amount
    INPUT_PERCENT,                                        // Percent of Equity
    INPUT_POINTS                                          // Points
};

input group "+-----------------------------------------+"
input group " Nyao Scalper v21.0"
input group "「結果が出ない努力はただの言い訳」"
input group " © Copyright Nyao Scalper by Elriz Wiraswara"
input group "+-----------------------------------------+"

// +------------------------------------------------------------------+
// | Input Parameters                                                 |
// +------------------------------------------------------------------+
input group "📝 Order Settings"
input bool EnableBuyOrders = true;                        // Enable Buy Orders
input bool EnableSellOrders = true;                       // Enable Sell Orders
input double BaseLotSize = 0.01;                          // Base Lot Size
input int MaxOpenOrders = 25;                             // Maximum Consecutive Open Orders
input double ZonePoints = 1000;                           // Zone Points to Avoid Duplicate Signals (Smaller = Less Signals)
input double BuyDuplicateMultiplier  = 1.0;               // Minimum Distance Multiplier to Avoid Duplicate Buy Signals
input double SellDuplicateMultiplier = 1.0;               // Minimum Distance Multiplier to Avoid Duplicate Sell Signals
input double MinBreakEvenProfit = 1.0;                    // Minimum Profit to Trigger Break-Even ($)
input double ProfitThresholdMultiplier = 1.0;             // Threshold Multiplier for Min Break-Even Profit
input double LossThresholdMultiplier = 1.0;               // Threshold Multiplier for Max Break-Even Loss

input group "🚀 Smart Multi-Entry Settings"
input bool EnableMultiEntry = true;                       // Enable Multi-Entry on Strong Signals
input int MaxMultiEntryPositions = 10;                    // Max Total Multi-Entry Positions per Direction
input double MultiEntryMinDistance = 5.0;                 // Min Distance Between Entries (Points)
input int MultiEntryMinStrength = 7;                      // Min Signal Strength to Allow Multi-Entry (0-10+)
input double MultiEntryProfitThreshold = 1;               // Min Profit ($) of Winning Positions to Add
input int MultiEntryCooldownSeconds = 1;                  // Cooldown Between Multi-Entries (Seconds)

input group "🛡️ Position Loss Management"
input bool EnableLossManagement = true;                   // Enable Independent Loss Management
input int MaxHoldingLossPositions = 3;                    // Max Losing Positions to Hold (0 = Close Immediately)
input int StrongInvalidationThreshold = 10;               // Strong Invalidation Score Threshold (0-10+)
input int MediumInvalidationThreshold = 3;                // Medium Invalidation Score (Can Hold If Recoverable)
input double MaxRecoverableLoss = 15.0;                   // Max Loss ($) Considered Recoverable
input bool CloseFromMostLosing = true;                    // Close from Most Losing Position First

input group "🧮 Dynamic Lot Sizing Settings"
input bool EnableDynamicLots = true;                      // Enable Dynamic Lot Sizing
input double EquityDropPercent = 5.0;                     // Equity Drop % per Lot Step
input double LotStepSize = 0.01;                          // Lot Increase Step Size
input double MaxLotSize = 0.1;                            // Maximum Lot Size

input group "🏦 Equity Settings"
input double MinEquityPercent = 50.0;                     // Min Equity % from Peak - Pause Trading when Reached
input double MaxDrawdownFromPeak = 0;                     // Max Equity $ Drawdown - Pause Trading when Reached (0 = Disabled)
input int PauseMinutes = 30;                              // Pause Duration when Reached (Minutes)
input double PauseMinutesMultiplier = 1;                  // Multiply Pause Duration on Each Trigger
input int MaxPauseMinutes = 0;                            // Max Pause Duration Minutes (0 = Maximum 24,855 days)
input int MaxMinEquityTriggers = 0;                       // Max Times Trigger - Stop Trading when Reached (0 = Unlimited)
input bool ResetOnNewPeak = true;                         // Reset Min Equity Triggers on New Peak Equity
input double TargetEquity = 0;                            // Target Equity - Stop Trading when Reached (0 = Disabled)
input double MinimumEquity = 20;                          // Minimum Equity - Stop Trading when Reached (0 = Disabled)

input group "📈 Take Profit Settings"
input bool EnableTakeProfit = false;                      // Enable Take Profit
input ENUM_INPUT_TYPE TPInputType = INPUT_DOLLAR;         // TP Input Type
input double TPValue = 5.0;                               // TP Value

input group "💸 Trailing Stop Settings"
input bool EnableTrailingStop = true;                     // Enable Trailing Stop
input bool TSEnableBreakEvenLock = true;                  // Enable Break-Even Lock Point
input bool TSOnProfitableOnly = true;                     // TS on Profitable Position Only
input ENUM_INPUT_TYPE TSInputType = INPUT_DOLLAR;         // TS Input Type
input double TSValue = 0.05;                              // TS Initial Value

input group "📉 Stop Loss Settings"
input bool EnableStopLoss = true;                         // Enable Stop Loss
input ENUM_INPUT_TYPE SLInputType = INPUT_PERCENT;        // SL Input Type
input double SLValue = 20;                                // SL Value

input group "🤖 Robot Settings"
input int MagicNumber = 6926268;                          // Magic Number
input bool EnableDiscordAlerts = false;                   // Enable Discord Alerts
input string DiscordWebhookURL = "";                      // Discord Webhook URL
input bool EnableTradingHours = false;                    // Enable Trading Hours
input string TradingStartTime = "00:00";                  // Trading Start Time (HH:MM)
input string TradingEndTime = "23:59";                    // Trading End Time (HH:MM)
input bool EnableReports = true;                          // Enable Trading Reports
input int SendReportEveryHour = 1;                        // Send Report Every n Hours 
input bool EnableMarketCloseFilter = true;                // Stop Opening New Positions Near Market Close Hour
input int MinutesBeforeClose = 60;                        // Stop Opening Minutes Before Market Close
input bool EnableNewsFilter = true;                       // Enable News Filter (Pause Trading During News)
input int NewsMinutesBefore = 30;                         // Minutes Before News Event
input int NewsMinutesAfter = 30;                          // Minutes After News Event
input bool EnableLeveragePause = true;                    // Pause Trading When Leverage Changed
input bool EnableLogging = false;                         // Enable EA Logging (May cause lag)

// +------------------------------------------------------------------+
// | Global Variables                                                 |
// +------------------------------------------------------------------+
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
double lastBuyPrice = 0;
double lastSellPrice = 0;
datetime lastReverseTime = 0;
datetime startTime = 0;                                   // EA Start Time
datetime lastDailyReportTime = 0;                         // Last time daily report was sent
double lastReportEquity = 0;                              // Equity at last report

// Pause Tracking
int totalPauseCount = 0;                                  // Total number of times trading was paused
double totalPauseDurationMinutes = 0;                     // Total duration of pauses in minutes

// Multi-Entry tracking
datetime lastMultiEntryTime = 0;

// Signal Strength structure (1-5 scale)
struct SignalStrength
{
    int trendScore;              // Trend direction confirmation (0-2)
    int momentumScore;           // Momentum/candle body strength (0-2)
    int confirmationScore;       // Additional confirmations (0-1)
    int totalScore;              // Total strength (0-5)
    string reasoning;            // Explanation of score
};

// Position Invalidation structure
struct InvalidationDetails
{
    bool trendReversal;          // Trend has reversed
    bool strongMomentum;         // Strong opposite momentum
    bool priceAction;            // Price action invalidation
    bool beyondSL;               // Price moved significantly against
    int totalScore;              // Total invalidation score (0-5)
    string reason;               // Explanation
    bool isRecoverable;          // Can the position recover?
};

// Losing Position Info structure for sorting
struct LosingPositionInfo
{
    ulong ticket;
    double profit;
    int invalidationScore;
    bool isRecoverable;
};

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
// | Expert Initialization Function                                   |
// +------------------------------------------------------------------+
int OnInit()
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
    
    LogPrint("+-----------------------------------------+");
    LogPrint("Nyao Scalper v21.0 Initialized Successfully");
    LogPrint("+-----------------------------------------+");

    if(EnableDiscordAlerts) CheckDiscordAlert();
    
    return(INIT_SUCCEEDED);
}

// +------------------------------------------------------------------+
// | Expert Deinitialization Function                                 |
// +------------------------------------------------------------------+
void OnDeinit(const int reason)
{   
    LogPrint("Nyao Scalper EA Deinitialized");
}

// +------------------------------------------------------------------+
// | Expert Tick Function                                             |
void OnTick()
{   
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
}

// +------------------------------------------------------------------+
// | Check For Trading Signals                                        |
// +------------------------------------------------------------------+
void CheckForTradingSignal()
{   
    if (!IsAllowedToOpenPosition()) return;

    // Check Signals
    bool buySignal = BuySignal();
    bool sellSignal = SellSignal();

    // Get current prices
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Process BUY signals
    if(buySignal && EnableBuyOrders) 
    {
        OpenPosition(ORDER_TYPE_BUY);
        LogPrint("BUY signal accepted at price: ", currentAsk);
    }

    // Process SELL signals
    if(sellSignal && EnableSellOrders)
    {
        OpenPosition(ORDER_TYPE_SELL);
        LogPrint("SELL signal accepted at price: ", currentBid);
    }
}

// Buy Signal - Current TF candle
bool BuySignal()
{
   double close1 = iClose(_Symbol, _Period, 1);
   double open1  = iOpen(_Symbol, _Period, 1);
   
   if(!AllowNewBuy(close1)) return false;
   
   // Bullish candle = Buy signal (predict next candle goes UP)
   if(close1 > open1)
   {
      lastBuyPrice = close1;
      return true;
   }

   return false;
}

// Sell Signal - Current TF candle
bool SellSignal()
{
   double close1 = iClose(_Symbol, _Period, 1);
   double open1  = iOpen(_Symbol, _Period, 1);
   
   if(!AllowNewSell(close1)) return false;
   
   // Bearish candle = Sell signal (predict next candle goes DOWN)
   if(close1 < open1)
   {
      lastSellPrice = close1;
      return true;
   }

   return false;
}

// Duplicate buy filters
bool AllowNewBuy(double price)
{
   if(MathAbs(price - lastBuyPrice) < ZonePoints * _Point * BuyDuplicateMultiplier) return false;
   return true;
}

// Duplicate sell filters
bool AllowNewSell(double price)
{
   if(MathAbs(price - lastSellPrice) < ZonePoints * _Point * SellDuplicateMultiplier) return false;
   return true;
}

// Helper: Get candle body
double CandleBody(int index)
{
    return MathAbs(iClose(_Symbol, _Period, index) - iOpen(_Symbol, _Period, index));
}

// Helper: Get candle range
double CandleRange(int index)
{
    return iHigh(_Symbol, _Period, index) - iLow(_Symbol, _Period, index);
}

// Function to get next higher timeframe
ENUM_TIMEFRAMES GetHigherTimeframe()
{
   switch(_Period)
   {
      case PERIOD_M1:  return PERIOD_M5;
      case PERIOD_M5:  return PERIOD_M15;
      case PERIOD_M15: return PERIOD_M30;
      case PERIOD_M30: return PERIOD_H1;
      case PERIOD_H1:  return PERIOD_H4;
      case PERIOD_H4:  return PERIOD_D1;
      case PERIOD_D1:  return PERIOD_W1;
      case PERIOD_W1:  return PERIOD_MN1;
      default:         return PERIOD_M5;  // fallback
   }
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Manage Positions - Unified Position Management System            |
// +------------------------------------------------------------------+
void ManagePositions()
{   
    // Step 1: Manage all losing positions (independent - no pairing)
    ManageAllLosingPositions();
    
    // Step 2: Process Multi-Entry for winning positions
    ManageMultiEntry();
    
    // Step 3: Manage trailing stops for all positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        if(EnableTrailingStop) ManageTrailingStop(ticket);
    }
}

// +------------------------------------------------------------------+
// | Signal Strength Analysis (1-10 Scale with Wick + HTF)            |
// +------------------------------------------------------------------+
SignalStrength GetSignalStrength(ENUM_ORDER_TYPE orderType)
{
    SignalStrength strength;
    strength.trendScore = 0;
    strength.momentumScore = 0;
    strength.confirmationScore = 0;
    strength.totalScore = 0;
    strength.reasoning = "";
    
    // CURRENT TIMEFRAME DATA
    double close1 = iClose(_Symbol, _Period, 1);
    double open1 = iOpen(_Symbol, _Period, 1);
    double high1 = iHigh(_Symbol, _Period, 1);
    double low1 = iLow(_Symbol, _Period, 1);
    
    double close2 = iClose(_Symbol, _Period, 2);
    double open2 = iOpen(_Symbol, _Period, 2);
    double high2 = iHigh(_Symbol, _Period, 2);
    double low2 = iLow(_Symbol, _Period, 2);
    
    double close3 = iClose(_Symbol, _Period, 3);
    double open3 = iOpen(_Symbol, _Period, 3);
    
    if(close1 == 0 || open1 == 0) return strength;
    
    // HIGHER TIMEFRAME DATA
    ENUM_TIMEFRAMES htf = GetHigherTimeframe();
    double close_htf = iClose(_Symbol, htf, 1);
    double open_htf = iOpen(_Symbol, htf, 1);
    double high_htf = iHigh(_Symbol, htf, 1);
    double low_htf = iLow(_Symbol, htf, 1);
    
    // Candle direction checks
    bool isBullish1 = close1 > open1;
    bool isBullish2 = close2 > open2;
    bool isBullish3 = close3 > open3;
    bool isBearish1 = close1 < open1;
    bool isBearish2 = close2 < open2;
    bool isBearish3 = close3 < open3;
    
    bool isBullish_htf = close_htf > open_htf;
    bool isBearish_htf = close_htf < open_htf;
    
    // Calculate body sizes and wicks
    double body1 = MathAbs(close1 - open1);
    double body2 = MathAbs(close2 - open2);
    double range1 = high1 - low1;
    double avgBody = (body1 + body2) / 2;
    
    // Wick calculations for current candle
    double upperWick1 = high1 - MathMax(close1, open1);
    double lowerWick1 = MathMin(close1, open1) - low1;
    
    // HTF wick calculations
    double body_htf = MathAbs(close_htf - open_htf);
    double upperWick_htf = high_htf - MathMax(close_htf, open_htf);
    double lowerWick_htf = MathMin(close_htf, open_htf) - low_htf;
    
    if(orderType == ORDER_TYPE_BUY)
    {
        // TREND SCORE (0-3)
        if(isBullish1)
        {
            strength.trendScore++;
            strength.reasoning += "[Bull Candle] ";
        }
        
        if(isBullish1 && isBullish2)
        {
            strength.trendScore++;
            strength.reasoning += "[Consecutive Bull] ";
        }
        
        if(isBullish1 && isBullish2 && isBullish3)
        {
            strength.trendScore++;
            strength.reasoning += "[Triple Bull] ";
        }
        
        // MOMENTUM SCORE (0-3)
        // Strong body size
        if(body1 > avgBody * 1.2)
        {
            strength.momentumScore++;
            strength.reasoning += "[Strong Body] ";
        }
        
        // High body-to-range ratio (decisive candle)
        if(range1 > 0 && body1 / range1 > 0.6)
        {
            strength.momentumScore++;
            strength.reasoning += "[High Body Ratio] ";
        }
        
        // Very strong momentum
        if(body1 > avgBody * 1.5)
        {
            strength.momentumScore++;
            strength.reasoning += "[Very Strong] ";
        }
        
        // CONFIRMATION SCORE (0-4)
        // 1. WICK CONFIRMATION - Small upper wick (no rejection)
        if(upperWick1 < body1 * 0.3)
        {
            strength.confirmationScore++;
            strength.reasoning += "[Clean Wick] ";
        }
        
        // 2. WICK POSITION - Lower wick larger (buying pressure)
        if(lowerWick1 > upperWick1)
        {
            strength.confirmationScore++;
            strength.reasoning += "[Buy Pressure] ";
        }
        
        // 3. STRUCTURE - Higher low (uptrend structure)
        if(low1 > low2)
        {
            strength.confirmationScore++;
            strength.reasoning += "[Higher Low] ";
        }
        
        // 4. HIGHER TIMEFRAME ALIGNMENT
        if(isBullish_htf)
        {
            strength.confirmationScore++;
            strength.reasoning += "[HTF Bull] ";
            
            // HTF also has good wick structure (bonus)
            if(upperWick_htf < body_htf * 0.5 && lowerWick_htf > upperWick_htf)
            {
                strength.confirmationScore++;
                strength.reasoning += "[HTF Clean] ";
            }
        }
        
        // PENALTY FOR WEAK SIGNALS
        // Large upper wick = rejection (reduce score)
        if(upperWick1 > body1 * 0.5)
        {
            strength.confirmationScore = MathMax(0, strength.confirmationScore - 2);
            strength.reasoning += "[Upper Rejection!] ";
        }
        
        // HTF bearish = counter-trend (reduce score)
        if(isBearish_htf)
        {
            strength.trendScore = MathMax(0, strength.trendScore - 1);
            strength.reasoning += "[HTF Conflict!] ";
        }
    }
    else // ORDER_TYPE_SELL
    {
        // TREND SCORE (0-3)
        {
            strength.trendScore++;
            strength.reasoning += "[Bear Candle] ";
        }
        
        if(isBearish1 && isBearish2)
        {
            strength.trendScore++;
            strength.reasoning += "[Consecutive Bear] ";
        }
        
        if(isBearish1 && isBearish2 && isBearish3)
        {
            strength.trendScore++;
            strength.reasoning += "[Triple Bear] ";
        }
        
        // MOMENTUM SCORE (0-3)
        // Strong body size
        if(body1 > avgBody * 1.2)
        {
            strength.momentumScore++;
            strength.reasoning += "[Strong Body] ";
        }
        
        // High body-to-range ratio
        if(range1 > 0 && body1 / range1 > 0.6)
        {
            strength.momentumScore++;
            strength.reasoning += "[High Body Ratio] ";
        }
        
        // Very strong momentum
        if(body1 > avgBody * 1.5)
        {
            strength.momentumScore++;
            strength.reasoning += "[Very Strong] ";
        }
        
        // CONFIRMATION SCORE (0-4)
        // 1. WICK CONFIRMATION - Small lower wick (no rejection)
        if(lowerWick1 < body1 * 0.3)
        {
            strength.confirmationScore++;
            strength.reasoning += "[Clean Wick] ";
        }
        
        // 2. WICK POSITION - Upper wick larger (selling pressure)
        if(upperWick1 > lowerWick1)
        {
            strength.confirmationScore++;
            strength.reasoning += "[Sell Pressure] ";
        }
        
        // 3. STRUCTURE - Lower high (downtrend structure)
        if(high1 < high2)
        {
            strength.confirmationScore++;
            strength.reasoning += "[Lower High] ";
        }
        
        // 4. HIGHER TIMEFRAME ALIGNMENT
        if(isBearish_htf)
        {
            strength.confirmationScore++;
            strength.reasoning += "[HTF Bear] ";
            
            // HTF also has good wick structure (bonus)
            if(lowerWick_htf < body_htf * 0.5 && upperWick_htf > lowerWick_htf)
            {
                strength.confirmationScore++;
                strength.reasoning += "[HTF Clean] ";
            }
        }
        
        // PENALTY FOR WEAK SIGNALS
        // Large lower wick = rejection (reduce score)
        if(lowerWick1 > body1 * 0.5)
        {
            strength.confirmationScore = MathMax(0, strength.confirmationScore - 2);
            strength.reasoning += "[Lower Rejection!] ";
        }
        
        // HTF bullish = counter-trend (reduce score)
        if(isBullish_htf)
        {
            strength.trendScore = MathMax(0, strength.trendScore - 1);
            strength.reasoning += "[HTF Conflict!] ";
        }
    }
    
    // Calculate total score (max 10+)
    strength.totalScore = strength.trendScore + strength.momentumScore + strength.confirmationScore;

    // Signal Strength Scale (0-10+):
    // 0-2   : Very Weak - Skip signal
    // 3-4   : Weak - Small lot only
    // 5-6   : Moderate - Normal lot
    // 7-8   : Strong - Increased lot
    // 9-10+ : Very Strong - Maximum lot
    return strength;
}

// +------------------------------------------------------------------+
// | Multi-Entry Management for Winning Positions                     |
// +------------------------------------------------------------------+
void ManageMultiEntry()
{
    if(!EnableMultiEntry || MaxMultiEntryPositions <= 0) return;
    
    // Check cooldown
    if(TimeCurrent() - lastMultiEntryTime < MultiEntryCooldownSeconds)
    {
        return;
    }
    
    // Find best direction to add (based on current winning positions)
    int buyCount = 0;
    int sellCount = 0;
    double buyProfit = 0;
    double sellProfit = 0;
    double lastBuyEntryPrice = 0;
    double lastSellEntryPrice = 0;
    
    // Count winning positions and calculate profits
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        double profit = PositionGetDouble(POSITION_PROFIT);
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        if(profit >= MultiEntryProfitThreshold)
        {
            if(posType == POSITION_TYPE_BUY)
            {
                buyCount++;
                buyProfit += profit;
                if(entryPrice > lastBuyEntryPrice) lastBuyEntryPrice = entryPrice;
            }
            else
            {
                sellCount++;
                sellProfit += profit;
                if(lastSellEntryPrice == 0 || entryPrice < lastSellEntryPrice) 
                    lastSellEntryPrice = entryPrice;
            }
        }
    }
    
    // Get current prices
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Check for BUY multi-entry
    if(buyCount > 0 && buyCount < MaxMultiEntryPositions && EnableBuyOrders)
    {
        // Check distance from last entry
        double distanceBuy = (ask - lastBuyEntryPrice) / _Point;
        
        if(distanceBuy >= MultiEntryMinDistance)
        {
            // Check signal strength
            SignalStrength strength = GetSignalStrength(ORDER_TYPE_BUY);
            
            if(strength.totalScore >= MultiEntryMinStrength)
            {
                // Get invalidation to ensure signal is still valid
                InvalidationDetails details = GetBuyInvalidation();
                
                if(details.totalScore < MediumInvalidationThreshold)
                {
                    LogPrint("+-----------------------------------------+");
                    LogPrint("MULTI-ENTRY BUY TRIGGERED");
                    LogPrint("Winning Positions: ", buyCount, "/", MaxMultiEntryPositions);
                    LogPrint("Total Profit: $", buyProfit);
                    LogPrint("Signal Strength: ", strength.totalScore, "/5 - ", strength.reasoning);
                    LogPrint("Distance: ", distanceBuy, " points");
                    LogPrint("+-----------------------------------------+");
                    
                    OpenPosition(ORDER_TYPE_BUY);
                    lastMultiEntryTime = TimeCurrent();
                    return;
                }
                else
                {
                    LogPrint("[MULTI-ENTRY BLOCKED] Signal invalidated. Score: ", details.totalScore);
                }
            }
            else
            {
                LogPrint("[MULTI-ENTRY BLOCKED] Signal too weak. Strength: ", strength.totalScore, "/", MultiEntryMinStrength);
            }
        }
    }
    
    // Check for SELL multi-entry
    if(sellCount > 0 && sellCount < MaxMultiEntryPositions && EnableSellOrders)
    {
        // Check distance from last entry
        double distanceSell = (lastSellEntryPrice - bid) / _Point;
        
        if(distanceSell >= MultiEntryMinDistance)
        {
            // Check signal strength
            SignalStrength strength = GetSignalStrength(ORDER_TYPE_SELL);
            
            if(strength.totalScore >= MultiEntryMinStrength)
            {
                // Get invalidation to ensure signal is still valid
                InvalidationDetails details = GetSellInvalidation();
                
                if(details.totalScore < MediumInvalidationThreshold)
                {
                    LogPrint("+-----------------------------------------+");
                    LogPrint("MULTI-ENTRY SELL TRIGGERED");
                    LogPrint("Winning Positions: ", sellCount, "/", MaxMultiEntryPositions);
                    LogPrint("Total Profit: $", sellProfit);
                    LogPrint("Signal Strength: ", strength.totalScore, "/5 - ", strength.reasoning);
                    LogPrint("Distance: ", distanceSell, " points");
                    LogPrint("+-----------------------------------------+");
                    
                    OpenPosition(ORDER_TYPE_SELL);
                    lastMultiEntryTime = TimeCurrent();
                    return;
                }
                else
                {
                    LogPrint("[MULTI-ENTRY BLOCKED] Signal invalidated. Score: ", details.totalScore);
                }
            }
            else
            {
                LogPrint("[MULTI-ENTRY BLOCKED] Signal too weak. Strength: ", strength.totalScore, "/", MultiEntryMinStrength);
            }
        }
    }
}

// +------------------------------------------------------------------+
// | Get Buy Direction Invalidation (Current Candle + Price Action)   |
// +------------------------------------------------------------------+
InvalidationDetails GetBuyInvalidation()
{
    InvalidationDetails details;
    details.trendReversal = false;
    details.strongMomentum = false;
    details.priceAction = false;
    details.beyondSL = false;
    details.totalScore = 0;
    details.reason = "";
    details.isRecoverable = true;
    
    // Current candle (real-time)
    double close0 = iClose(_Symbol, _Period, 0);
    double open0 = iOpen(_Symbol, _Period, 0);
    double high0 = iHigh(_Symbol, _Period, 0);
    double low0 = iLow(_Symbol, _Period, 0);
    
    // Previous candles
    double close1 = iClose(_Symbol, _Period, 1);
    double open1 = iOpen(_Symbol, _Period, 1);
    double high1 = iHigh(_Symbol, _Period, 1);
    double low1 = iLow(_Symbol, _Period, 1);
    
    double close2 = iClose(_Symbol, _Period, 2);
    double open2 = iOpen(_Symbol, _Period, 2);
    double close3 = iClose(_Symbol, _Period, 3);
    double open3 = iOpen(_Symbol, _Period, 3);
    
    if(close0 == 0 || open0 == 0) return details;
    
    // Current price
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Candle direction checks
    bool isBearish0 = close0 < open0;  // Current candle forming bearish
    bool isBearish1 = close1 < open1;
    bool isBearish2 = close2 < open2;
    bool isBearish3 = close3 < open3;
    
    // Calculate bodies
    double body0 = MathAbs(close0 - open0);
    double body1 = MathAbs(close1 - open1);
    double body2 = MathAbs(close2 - open2);
    double avgBody = (body1 + body2) / 2;
    
    // CURRENT CANDLE CHECKS (Real-time)
    // 1. Current candle is bearish and growing = 1 point
    if(isBearish0 && body0 > 0)
    {
        details.totalScore += 1;
        details.reason += "[Current Bearish] ";
        
        // Strong bearish current candle = +1 point
        if(body0 > avgBody * 1.2)
        {
            details.totalScore += 1;
            details.reason += "[Strong Current Bearish] ";
        }
    }
    
    // 2. Current candle has large upper wick (rejection) = 2 points
    double upperWick0 = high0 - MathMax(close0, open0);
    double lowerWick0 = MathMin(close0, open0) - low0;
    
    if(upperWick0 > body0 * 0.5)
    {
        details.priceAction = true;
        details.totalScore += 2;
        details.reason += "[Upper Wick Rejection] ";
        
        // Very large upper wick = unrecoverable
        if(upperWick0 > body0 * 1.5)
        {
            details.isRecoverable = false;
            details.totalScore += 1;
            details.reason += "[Large Rejection] ";
        }
    }
    
    // 3. Current price moving down aggressively = 1 point
    double priceChange = currentPrice - close1;
    if(priceChange < 0 && MathAbs(priceChange) > avgBody * 0.5)
    {
        details.totalScore += 1;
        details.reason += "[Price Dropping] ";
    }
    
    // PREVIOUS CANDLES PATTERN
    // 4. Previous candle was bearish = 1 point
    if(isBearish1)
    {
        details.totalScore += 1;
        details.reason += "[Prev Bearish] ";
    }
    
    // 5. Previous candle had upper wick rejection = 1 point
    double upperWick1 = high1 - MathMax(close1, open1);
    double lowerWick1 = MathMin(close1, open1) - low1;
    
    if(upperWick1 > CandleBody(1) * 0.6 && upperWick1 > lowerWick1)
    {
        details.priceAction = true;
        details.totalScore += 1;
        details.reason += "[Prev Wick Rejection] ";
    }
    
    // 6. Consecutive bearish candles = 2 points
    if(isBearish0 && isBearish1)
    {
        details.trendReversal = true;
        details.totalScore += 2;
        details.reason += "[Consecutive Bearish] ";
    }
    
    // 7. Three consecutive bearish = strong reversal (unrecoverable)
    if(isBearish1 && isBearish2 && isBearish3)
    {
        details.totalScore += 2;
        details.reason += "[Triple Bearish Pattern] ";
        details.isRecoverable = false;
    }
    
    // 8. Strong bearish momentum on previous candle = 1 point
    if(isBearish1 && body1 > avgBody * 1.5)
    {
        details.strongMomentum = true;
        details.totalScore += 1;
        details.reason += "[Strong Momentum] ";
    }
    
    // 9. Current candle low breaking previous low (lower lows) = 2 points
    if(low0 < low1)
    {
        details.trendReversal = true;
        details.totalScore += 2;
        details.reason += "[Lower Low] ";
    }
    
    // 10. Higher timeframe confirmation
    ENUM_TIMEFRAMES htf = GetHigherTimeframe();
    double close_htf = iClose(_Symbol, htf, 0);
    double open_htf = iOpen(_Symbol, htf, 0);
    
    if(close_htf < open_htf)
    {
        details.totalScore += 1;
        details.reason += "[HTF Bearish] ";
    }
    
    // Score Breakdown (Max ~15+ points):
    // 1-3  : Minor concern (recoverable)
    // 4-6  : Moderate invalidation (watch closely)
    // 7-10 : Strong invalidation (consider closing)
    // 11+  : Critical invalidation (close immediately)
    return details;
}

// +------------------------------------------------------------------+
// | Get Sell Direction Invalidation (Current Candle + Price Action)  |
// +------------------------------------------------------------------+
InvalidationDetails GetSellInvalidation()
{
    InvalidationDetails details;
    details.trendReversal = false;
    details.strongMomentum = false;
    details.priceAction = false;
    details.beyondSL = false;
    details.totalScore = 0;
    details.reason = "";
    details.isRecoverable = true;
    
    // Current candle (real-time)
    double close0 = iClose(_Symbol, _Period, 0);
    double open0 = iOpen(_Symbol, _Period, 0);
    double high0 = iHigh(_Symbol, _Period, 0);
    double low0 = iLow(_Symbol, _Period, 0);
    
    // Previous candles
    double close1 = iClose(_Symbol, _Period, 1);
    double open1 = iOpen(_Symbol, _Period, 1);
    double high1 = iHigh(_Symbol, _Period, 1);
    double low1 = iLow(_Symbol, _Period, 1);
    
    double close2 = iClose(_Symbol, _Period, 2);
    double open2 = iOpen(_Symbol, _Period, 2);
    double close3 = iClose(_Symbol, _Period, 3);
    double open3 = iOpen(_Symbol, _Period, 3);
    
    if(close0 == 0 || open0 == 0) return details;
    
    // Current price
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Candle direction checks
    bool isBullish0 = close0 > open0;  // Current candle forming bullish
    bool isBullish1 = close1 > open1;
    bool isBullish2 = close2 > open2;
    bool isBullish3 = close3 > open3;
    
    // Calculate bodies
    double body0 = MathAbs(close0 - open0);
    double body1 = MathAbs(close1 - open1);
    double body2 = MathAbs(close2 - open2);
    double avgBody = (body1 + body2) / 2;
    
    // CURRENT CANDLE CHECKS (Real-time)
    // 1. Current candle is bullish and growing = 1 point
    if(isBullish0 && body0 > 0)
    {
        details.totalScore += 1;
        details.reason += "[Current Bullish] ";
        
        // Strong bullish current candle = +1 point
        if(body0 > avgBody * 1.2)
        {
            details.totalScore += 1;
            details.reason += "[Strong Current Bullish] ";
        }
    }
    
    // 2. Current candle has large lower wick (rejection) = 2 points
    double upperWick0 = high0 - MathMax(close0, open0);
    double lowerWick0 = MathMin(close0, open0) - low0;
    
    if(lowerWick0 > body0 * 0.5)
    {
        details.priceAction = true;
        details.totalScore += 2;
        details.reason += "[Lower Wick Rejection] ";
        
        // Very large lower wick = unrecoverable
        if(lowerWick0 > body0 * 1.5)
        {
            details.isRecoverable = false;
            details.totalScore += 1;
            details.reason += "[Large Rejection] ";
        }
    }
    
    // 3. Current price moving up aggressively = 1 point
    double priceChange = currentPrice - close1;
    if(priceChange > 0 && priceChange > avgBody * 0.5)
    {
        details.totalScore += 1;
        details.reason += "[Price Rising] ";
    }
    
    // PREVIOUS CANDLES PATTERN
    // 4. Previous candle was bullish = 1 point
    if(isBullish1)
    {
        details.totalScore += 1;
        details.reason += "[Prev Bullish] ";
    }
    
    // 5. Previous candle had lower wick rejection = 1 point
    double upperWick1 = high1 - MathMax(close1, open1);
    double lowerWick1 = MathMin(close1, open1) - low1;
    
    if(lowerWick1 > CandleBody(1) * 0.6 && lowerWick1 > upperWick1)
    {
        details.priceAction = true;
        details.totalScore += 1;
        details.reason += "[Prev Wick Rejection] ";
    }
    
    // 6. Consecutive bullish candles = 2 points
    if(isBullish0 && isBullish1)
    {
        details.trendReversal = true;
        details.totalScore += 2;
        details.reason += "[Consecutive Bullish] ";
    }
    
    // 7. Three consecutive bullish = strong reversal (unrecoverable)
    if(isBullish1 && isBullish2 && isBullish3)
    {
        details.totalScore += 2;
        details.reason += "[Triple Bullish Pattern] ";
        details.isRecoverable = false;
    }
    
    // 8. Strong bullish momentum on previous candle = 1 point
    if(isBullish1 && body1 > avgBody * 1.5)
    {
        details.strongMomentum = true;
        details.totalScore += 1;
        details.reason += "[Strong Momentum] ";
    }
    
    // 9. Current candle high breaking previous high (higher highs) = 2 points
    if(high0 > high1)
    {
        details.trendReversal = true;
        details.totalScore += 2;
        details.reason += "[Higher High] ";
    }
    
    // 10. Higher timeframe confirmation
    ENUM_TIMEFRAMES htf = GetHigherTimeframe();
    double close_htf = iClose(_Symbol, htf, 0);
    double open_htf = iOpen(_Symbol, htf, 0);
    
    if(close_htf > open_htf)
    {
        details.totalScore += 1;
        details.reason += "[HTF Bullish] ";
    }
    
    // Score Breakdown (Max ~15+ points):
    // 1-3  : Minor concern (recoverable)
    // 4-6  : Moderate invalidation (watch closely)
    // 7-10 : Strong invalidation (consider closing)
    // 11+  : Critical invalidation (close immediately)
    return details;
}

// +------------------------------------------------------------------+
// | Manage All Losing Positions - Independent (No Pairing)          |
// +------------------------------------------------------------------+
void ManageAllLosingPositions()
{
    if(!EnableLossManagement) return;
    
    // Collect all losing positions
    LosingPositionInfo losingPositions[];
    int losingCount = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        double profit = PositionGetDouble(POSITION_PROFIT);
        
        // Only process losing positions
        if(profit < 0)
        {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Get invalidation for this position's direction
            InvalidationDetails details;
            if(posType == POSITION_TYPE_BUY)
            {
                details = GetBuyInvalidation();
            }
            else
            {
                details = GetSellInvalidation();
            }
            
            // Check if loss is recoverable
            bool isRecoverable = (MathAbs(profit) <= MaxRecoverableLoss) && details.isRecoverable;
            
            // Add to array
            ArrayResize(losingPositions, losingCount + 1);
            losingPositions[losingCount].ticket = ticket;
            losingPositions[losingCount].profit = profit;
            losingPositions[losingCount].invalidationScore = details.totalScore;
            losingPositions[losingCount].isRecoverable = isRecoverable;
            losingCount++;
            
            LogPrint("+-----------------------------------------+");
            LogPrint("LOSING POSITION ANALYSIS");
            LogPrint("Ticket: ", ticket, " | Type: ", EnumToString(posType));
            LogPrint("Profit: $", profit);
            LogPrint("Invalidation Score: ", details.totalScore, "/5");
            LogPrint("Reason: ", details.reason);
            LogPrint("Recoverable: ", isRecoverable ? "YES" : "NO");
            LogPrint("+-----------------------------------------+");
        }
    }
    
    if(losingCount == 0) return;
    
    // Sort by profit (most losing first) if CloseFromMostLosing is enabled
    if(CloseFromMostLosing && losingCount > 1)
    {
        for(int i = 0; i < losingCount - 1; i++)
        {
            for(int j = i + 1; j < losingCount; j++)
            {
                if(losingPositions[j].profit < losingPositions[i].profit)
                {
                    LosingPositionInfo temp = losingPositions[i];
                    losingPositions[i] = losingPositions[j];
                    losingPositions[j] = temp;
                }
            }
        }
    }
    
    // Process each losing position
    int holdCount = 0;
    
    for(int i = 0; i < losingCount; i++)
    {
        ulong ticket = losingPositions[i].ticket;
        double profit = losingPositions[i].profit;
        int score = losingPositions[i].invalidationScore;
        bool isRecoverable = losingPositions[i].isRecoverable;
        
        // Decision logic:
        // 1. Strong invalidation (>= threshold) = Close immediately
        // 2. Not recoverable = Close immediately
        // 3. Over max hold count = Close (starting from most losing)
        // 4. Otherwise = Hold
        
        bool shouldClose = false;
        string closeReason = "";
        
        // Check 1: Strong invalidation
        if(score >= StrongInvalidationThreshold)
        {
            shouldClose = true;
            closeReason = "Strong Invalidation (Score: " + IntegerToString(score) + ")";
        }
        // Check 2: Not recoverable
        else if(!isRecoverable)
        {
            shouldClose = true;
            closeReason = "Not Recoverable (Loss: $" + DoubleToString(MathAbs(profit), 2) + ")";
        }
        // Check 3: Over max hold count
        else if(holdCount >= MaxHoldingLossPositions)
        {
            shouldClose = true;
            closeReason = "Max Hold Limit Exceeded (" + IntegerToString(holdCount) + "/" + IntegerToString(MaxHoldingLossPositions) + ")";
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
            LogPrint("HOLDING position ", ticket, " (Recoverable, Score: ", score, ", Hold: ", holdCount, "/", MaxHoldingLossPositions, ")");
        }
    }
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Manage Trailing Stop                                             |
// +------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;

    double profit = PositionGetDouble(POSITION_PROFIT);

    if(TSOnProfitableOnly && profit <= 0) return;
    
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double volume = PositionGetDouble(POSITION_VOLUME);
    double currentTP = PositionGetDouble(POSITION_TP);
    double currentSL = PositionGetDouble(POSITION_SL);
    
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
    
    double trailingDistancePoints = ConvertToPoints(TSInputType, TSValue, volume);
    double trailingDistancePrice  = trailingDistancePoints * _Point;
    
    long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    
    double minStopDistance = stopLevel * _Point;
    double minFreezeDistance = freezeLevel * _Point;
    double minDistance = MathMax(minStopDistance, minFreezeDistance);
    
    double breakEvenPrice = CalculateBreakEvenPrice(ticket, posType, entryPrice, volume);
    
    double newSL = 0;

    // Buy position trailing logic
    if(posType == POSITION_TYPE_BUY)
    {
        double profitPoints = (currentPrice - entryPrice) / _Point;
        if(profitPoints < trailingDistancePoints) return;

        newSL = currentPrice - trailingDistancePrice;
        double maxAllowedSL = bid - minDistance;
        
        if(newSL > maxAllowedSL)
        {
            newSL = maxAllowedSL;
        }

        // Break-even lock logic (still using SL)
        if(TSEnableBreakEvenLock && newSL < breakEvenPrice)
        {
            newSL = breakEvenPrice;
        }

        if(currentSL != 0 && newSL <= currentSL) return;
        if(newSL >= bid) return;
    }
    // Sell position trailing logic
    else
    {
        double profitPoints = (entryPrice - currentPrice) / _Point;
        if(profitPoints < trailingDistancePoints) return;

        newSL = currentPrice + trailingDistancePrice;
        double minAllowedSL = ask + minDistance;

        if(newSL < minAllowedSL)
        {
            newSL = minAllowedSL;
        }

        // Break-even lock logic (still using SL)
        if(TSEnableBreakEvenLock && newSL > breakEvenPrice)
        {
            newSL = breakEvenPrice;
        }

        if(currentSL != 0 && newSL >= currentSL) return;
        if(newSL <= ask) return;
    }

    // Skip if SL still same with current
    if (newSL == currentSL) return;

    newSL = NormalizeDouble(newSL, _Digits);

    LogPrint("+-----------------------------------------+");
    LogPrint("TRAILING STOP MANAGEMENT");
    LogPrint("TICKET: ", ticket, " | Profit: $", profit);
    LogPrint("Current Price: ", currentPrice, " | Entry Price: ", entryPrice);
    LogPrint("Current SL: ", currentSL, " -> New SL: ", newSL);
    LogPrint("TSEnableBreakEvenLock: ", TSEnableBreakEvenLock ? "Yes" : "No");
    LogPrint("+-----------------------------------------+");

    // Validate new SL
    if(!IsSLValid(posType, newSL))
    {
        LogPrint("SL too close / invalid, skipping modification. Ticket: ", ticket);
        return;
    }

    // Try to modify
    if(!ModifyPosition(ticket, newSL, currentTP))
    {
        LogPrint("SL modify failed. Ticket: ", ticket);
    }
}

// +------------------------------------------------------------------+
// | Position Management Functions                                    |
// +------------------------------------------------------------------+
// Open position with dynamic lot sizing AND fixed SL/TP
void OpenPosition(ENUM_ORDER_TYPE orderType)
{   
    if (!IsAllowedToOpenPosition()) return;

    LockOrderSend(true);

    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    double currentLot = CalculateDynamicLotSize();
    
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
        double tpPoints = ConvertToPoints(TPInputType, TPValue, currentLot);
        
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

    if (CountOpenOrders() > MaxOpenOrders)
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
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Calculate Lot Size Based on Equity Drop From Peak                |
// +------------------------------------------------------------------+
double CalculateDynamicLotSize()
{
    if(!EnableDynamicLots) return BaseLotSize;

    if(lastPeakEquity <= 0) return BaseLotSize;
    
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double equityDropAmount = lastPeakEquity - currentEquity;
    double equityDropPercentage = (equityDropAmount / lastPeakEquity) * 100.0;
    
    if(equityDropPercentage <= 0) return BaseLotSize;
    
    int lotSteps = (int)(equityDropPercentage / EquityDropPercent);
    
    if(lotSteps < 0) lotSteps = 0;
    
    double currentLot = BaseLotSize + (lotSteps * LotStepSize);
    
    if(currentLot > MaxLotSize) currentLot = MaxLotSize;

    // Lot Size Validation
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(currentLot < minLot) currentLot = minLot;
    if(currentLot > maxLot) currentLot = maxLot;
        
    // Round to valid lot step
    currentLot = MathFloor(currentLot / lotStep) * lotStep;
    
    // Validate account has enough money for this lot size
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
        
        // Loop safety counter
        if (symbolLotStep == 0) symbolLotStep = 0.01;
        
        // Linear search is safer and simpler for small lot ranges
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
    json += "\"footer\":{\"text\":\"Nyao Scalper v21.0\"}";
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
        LogPrint("WARNING: Discord alerts enabled but webhook URL is empty!");
    }
    else if(StringFind(DiscordWebhookURL, "https://discord.com/api/webhooks/") != 0 &&
            StringFind(DiscordWebhookURL, "https://discordapp.com/api/webhooks/") != 0)
    {
        LogPrint("WARNING: Discord webhook URL format may be incorrect!");
    }
    else
    {   
        CheckAlgoTradingStatus();
    }
}