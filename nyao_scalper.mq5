// +------------------------------------------------------------------+
// |                                          Nyao Scalper v15.0      |
// |       Candle Prediction with Reversal, Hedge & Pyramiding        |
// |              with Equity & Risk Management + Discord Alerts      |
// |                                    © Copyright Nyao Scalper      |
// +------------------------------------------------------------------+
#property copyright "© Copyright Nyao Scalper by Elriz Wiraswara"
#property version   "15.0"
#property description "Auto Trading EA Robot with Equity Management + Discord Alerts."
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
input group " Nyao Scalper v15.0"
input group "「結果が出ない努力はただの言い訳」"
input group " © Copyright Nyao Scalper by Elriz Wiraswara"
input group "+-----------------------------------------+"

// +------------------------------------------------------------------+
// | Input Parameters                                                 |
// +------------------------------------------------------------------+
input group "🚦 Indicator Settings"
input int SR_Lookback = 10;                               // S/R Lookback Period (Shorter = More Signals)
input int PeakValleyLookback = 3;                         // Peak/Valley Detection Lookback (Smaller = More Sensitive)
input int Lookback = 7;                                   // Lookback Period for Signal Confirmation
input double ZonePoints = 10000;                          // Zone Points to Avoid Duplicate Signals (Smaller = Less Signals)
input double SR_TouchTolerance = 1.0;                     // S/R Touch Tolerance (Multiplier of ZonePoints)
input int SR_MinTouches = 1;                              // Minimum Touches to Validate S/R Level (1 = Most Signals)
input double SR_BreakoutConfirmation = 1.0;               // S/R Breakout Confirmation (Multiplier of ZonePoints)
input double MinCandleRangeMultiplier = 0.3;              // Minimum Candle Size (Lower = More Signals)
input double MaxCandleRangeMultiplier = 8.0;              // Maximum Candle Size (Spike filter)



input group "📝 Order Settings"
input bool EnableBuyOrders = true;                        // Enable Buy Orders
input bool EnableSellOrders = true;                       // Enable Sell Orders
input double BaseLotSize = 0.01;                          // Base Lot Size
input int MaxOpenOrders = 25;                             // Maximum Consecutive Open Orders
input double BuyDuplicateMultiplier  = 0.1;               // Minimum Distance Multiplier to Avoid Duplicate Buy Signals
input double SellDuplicateMultiplier = 0.1;               // Minimum Distance Multiplier to Avoid Duplicate Sell Signals
input double MinBreakEvenProfit = 1.5;                    // Minimum Profit to Trigger Break-Even ($)
input double BreakEvenThresholdMultiplier = 1.5;          // Threshold Multiplier for Min Break-Even Profit
input bool EnableAutoReverse = true;                      // Enable Auto Reverse on Opposite Signal
input int ReverseCooldownMinutes = 2;                     // Cooldown Duration Minutes after Reverse (0 = No Cooldown)
input bool EnableAutoHedge = true;                        // Enable Auto Hedge on Opposite Signal
input int MaxHedgeDurationMinutes = 480;                  // Max Hedge Duration (Minutes)
input bool EnablePyramiding = true;                       // Enable Pyramiding (Open new position on winning position)
input int MaxPyramidingPositions = 5;                     // Max Total Pyramiding Positions
input int PyramidCooldownSeconds = 3;                     // Pyramiding Cooldown Duration (Seconds)

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
bool isLeverageDiffFromInitial = false;                   // Flag if leverage has changed
ulong lastProcessedNewsEventID = 0;                       // Last processed news event ID
string symbolBaseCurrency = "";                           // Base currency of the symbol
string symbolQuoteCurrency = "";                          // Quote currency of the symbol
long initialLeverage = 0;                                 // Initial Account Leverage
bool isOrderSendLocked = false;                           // Flag for locking OrderSend execution


// Duplicate Signal Filter Variables
double lastBuyPrice = 0;
double lastSellPrice = 0;
datetime lastReverseTime = 0;
datetime startTime = 0;                                   // EA Start Time
datetime lastDailyReportTime = 0;                         // Last time daily report was sent

// Hedge pair structure
struct HedgePair
{
    ulong originalTicket;
    ulong hedgeTicket;
    datetime hedgeOpenTime;
};
HedgePair activePairs[];

// Invalidation details structure for logging
struct InvalidationDetails
{
    bool immediateReversal;      // Price moves sharply against position
    bool keyLevelBroken;         // Support/Resistance broken
    bool momentumShift;          // S/R breakout momentum shift
    bool microStructureFlip;     // Recent swing structure breaks
    int totalScore;
    string reason;
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

    ArrayResize(activePairs, 0);
    
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
    symbolBaseCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
    symbolQuoteCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
    initialLeverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    isOrderSendLocked = false;
    
    LogPrint("+-----------------------------------------+");
    LogPrint("Nyao Scalper v15.0 Initialized Successfully");
    LogPrint("+-----------------------------------------+");

    if(EnableDiscordAlerts) CheckDiscordAlert();
    
    return(INIT_SUCCEEDED);
}

// +------------------------------------------------------------------+
// | Expert Deinitialization Function                                 |
// +------------------------------------------------------------------+
void OnDeinit(const int reason)
{   
    ArrayFree(activePairs);
    
    LogPrint("Nyao Scalper EA Deinitialized");
}

// +------------------------------------------------------------------+
// | Expert Tick Function                                             |
// +------------------------------------------------------------------+
void OnTick()
{   
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

    if (isOutsideTradingHours || isLeverageDiffFromInitial)
    {   
        // Don't open new positions, but continue managing existing ones
        ManagePositions();
        LogPrint("[PAUSED] Trading paused.");
        return;
    }
    
    // Check for high-impact news events
    CheckHighImpactNews();
    
    // Check for End of Day (23:59) Report (if Trading Hours Disabled or missed)
    CheckDailyReport();

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
                alertMsg += "**Status:** Monitoring for new trading signals";
                
                SendDiscordAlert("▶️ TRADING RESUMED!", alertMsg, 3066993); // Blue color
            }
        }
    }
    
    // Manage existing positions
    ManagePositions();

    // Check for trading signals
    CheckForTradingSignal();
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

// Buy Signal - Simple Candle-Based Prediction (Maximum Signal Frequency)
// Predicts next candle will go UP based on current candle patterns
bool BuySignal()
{
   double close1  = iClose(_Symbol, _Period, 1);
   double open1   = iOpen(_Symbol, _Period, 1);
   double high1   = iHigh(_Symbol, _Period, 1);
   double low1    = iLow(_Symbol, _Period, 1);
   double close2  = iClose(_Symbol, _Period, 2);
   double open2   = iOpen(_Symbol, _Period, 2);
   
   if(!AllowNewBuy(close1)) return false;
   
   // PREDICTION SIGNALS (any one triggers buy):
   
   // 1. Bullish candle - expect continuation up
   bool bullishCandle = close1 > open1;
   
   // 2. Bullish reversal - bearish candle followed by price holding (potential bottom)
   bool bearishThenHold = (close2 < open2) && (close1 >= close2);
   
   // 3. Lower wick rejection - price rejected lower prices (buyers stepping in)
   double lowerWick = MathMin(open1, close1) - low1;
   double body = MathAbs(close1 - open1);
   bool lowerWickRejection = (lowerWick > body * 0.5) && (body > 0);
   
   // 4. Higher low pattern - uptrend structure
   bool higherLow = (low1 > iLow(_Symbol, _Period, 2));
   
   // 5. Doji at support zone (indecision after down move = potential reversal)
   bool dojiAfterDown = (body < (high1 - low1) * 0.3) && (close2 < open2);
   
   // Trigger on ANY bullish signal
   if(bullishCandle || bearishThenHold || lowerWickRejection || higherLow || dojiAfterDown)
   {
      lastBuyPrice = close1;
      return true;
   }

   return false;
}


// Sell Signal - Simple Candle-Based Prediction (Maximum Signal Frequency)
// Predicts next candle will go DOWN based on current candle patterns
bool SellSignal()
{
   double close1  = iClose(_Symbol, _Period, 1);
   double open1   = iOpen(_Symbol, _Period, 1);
   double high1   = iHigh(_Symbol, _Period, 1);
   double low1    = iLow(_Symbol, _Period, 1);
   double close2  = iClose(_Symbol, _Period, 2);
   double open2   = iOpen(_Symbol, _Period, 2);
   
   if(!AllowNewSell(close1)) return false;
   
   // PREDICTION SIGNALS (any one triggers sell):
   
   // 1. Bearish candle - expect continuation down
   bool bearishCandle = close1 < open1;
   
   // 2. Bearish reversal - bullish candle followed by price holding (potential top)
   bool bullishThenHold = (close2 > open2) && (close1 <= close2);
   
   // 3. Upper wick rejection - price rejected higher prices (sellers stepping in)
   double upperWick = high1 - MathMax(open1, close1);
   double body = MathAbs(close1 - open1);
   bool upperWickRejection = (upperWick > body * 0.5) && (body > 0);
   
   // 4. Lower high pattern - downtrend structure
   bool lowerHigh = (high1 < iHigh(_Symbol, _Period, 2));
   
   // 5. Doji at resistance zone (indecision after up move = potential reversal)
   bool dojiAfterUp = (body < (high1 - low1) * 0.3) && (close2 > open2);
   
   // Trigger on ANY bearish signal
   if(bearishCandle || bullishThenHold || upperWickRejection || lowerHigh || dojiAfterUp)
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

// Fake break (wick + close back)
bool FakeBreakBuy(double support)
{
   double low1   = iLow(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   double open1  = iOpen(_Symbol, _Period, 1);

   bool swept    = low1 < support;
   bool closedIn = close1 > support;
   bool wick     = (MathMin(open1, close1) - low1) > CandleBody(1);

   return (swept && closedIn && wick);
}

bool FakeBreakSell(double resistance)
{
   double high1  = iHigh(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   double open1  = iOpen(_Symbol, _Period, 1);

   bool swept    = high1 > resistance;
   bool closedIn = close1 < resistance;
   bool wick     = (high1 - MathMax(open1, close1)) > CandleBody(1);

   return (swept && closedIn && wick);
}

// Micro Structures
bool HigherLow()
{
   double l1 = iLow(_Symbol, _Period, 1);
   double l2 = iLow(_Symbol,_Period, 2);
   return (l1 > l2);
}

bool LowerHigh()
{
   double h1 = iHigh(_Symbol, _Period, 1);
   double h2 = iHigh(_Symbol, _Period, 2);
   return (h1 < h2);
}

// Peak/Valley Detection for 1-Minute Scalping
// Valley = Swing Low - Lower than surrounding candles (buy signal zone)
bool IsValley(int shift)
{
   double low = iLow(_Symbol, _Period, shift);
   
   // Check if this low is lower than candles on both sides
   for(int i = 1; i <= PeakValleyLookback; i++)
   {
      if(iLow(_Symbol, _Period, shift - i) <= low) return false;  // Left side check
      if(iLow(_Symbol, _Period, shift + i) <= low) return false;  // Right side check
   }
   
   return true;
}

// Peak = Swing High - Higher than surrounding candles (sell signal zone)
bool IsPeak(int shift)
{
   double high = iHigh(_Symbol, _Period, shift);
   
   // Check if this high is higher than candles on both sides
   for(int i = 1; i <= PeakValleyLookback; i++)
   {
      if(iHigh(_Symbol, _Period, shift - i) >= high) return false;  // Left side check
      if(iHigh(_Symbol, _Period, shift + i) >= high) return false;  // Right side check
   }
   
   return true;
}

// Get the most recent valley (swing low) price level
double GetRecentValley(int maxLookback)
{
   for(int i = PeakValleyLookback + 1; i <= maxLookback; i++)
   {
      if(IsValley(i))
         return iLow(_Symbol, _Period, i);
   }
   return 0;  // No valley found
}

// Get the most recent peak (swing high) price level
double GetRecentPeak(int maxLookback)
{
   for(int i = PeakValleyLookback + 1; i <= maxLookback; i++)
   {
      if(IsPeak(i))
         return iHigh(_Symbol, _Period, i);
   }
   return 0;  // No peak found
}

// Check if price is near a recent valley (for buy signals)
bool IsNearValley()
{
   double close1 = iClose(_Symbol, _Period, 1);
   double valley = GetRecentValley(SR_Lookback);
   
   if(valley <= 0) return false;
   
   double tolerance = ZonePoints * _Point * SR_TouchTolerance;
   return MathAbs(close1 - valley) <= tolerance;
}

// Check if price is near a recent peak (for sell signals)
bool IsNearPeak()
{
   double close1 = iClose(_Symbol, _Period, 1);
   double peak = GetRecentPeak(SR_Lookback);
   
   if(peak <= 0) return false;
   
   double tolerance = ZonePoints * _Point * SR_TouchTolerance;
   return MathAbs(close1 - peak) <= tolerance;
}

// Get Support & Resistance (Basic)
double GetSupport(int shift)
{
   int index = iLowest(_Symbol, _Period, MODE_LOW, Lookback, shift);
   return iLow(_Symbol, _Period, index);
}

double GetResistance(int shift)
{
   int index = iHighest(_Symbol, _Period, MODE_HIGH, Lookback, shift);
   return iHigh(_Symbol, _Period, index);
}

// Get Validated Support - Returns support level only if it has sufficient touches
double GetValidatedSupport(int shift)
{
   int index = iLowest(_Symbol, _Period, MODE_LOW, SR_Lookback, shift);
   double support = iLow(_Symbol, _Period, index);
   
   int touches = CountSupportTouches(support, shift);
   
   if(touches >= SR_MinTouches)
      return support;
   
   return 0;  // No valid support found
}

// Get Validated Resistance - Returns resistance level only if it has sufficient touches
double GetValidatedResistance(int shift)
{
   int index = iHighest(_Symbol, _Period, MODE_HIGH, SR_Lookback, shift);
   double resistance = iHigh(_Symbol, _Period, index);
   
   int touches = CountResistanceTouches(resistance, shift);
   
   if(touches >= SR_MinTouches)
      return resistance;
   
   return 0;  // No valid resistance found
}

// Count how many times price touched the support level
int CountSupportTouches(double level, int shift)
{
   int touches = 0;
   double tolerance = ZonePoints * _Point * SR_TouchTolerance;
   
   for(int i = shift; i < SR_Lookback + shift; i++)
   {
      double low = iLow(_Symbol, _Period, i);
      double close = iClose(_Symbol, _Period, i);
      
      // Count touch: low is near the level
      if(MathAbs(low - level) <= tolerance)
         touches++;
      // Also count close near level as a touch
      else if(MathAbs(close - level) <= tolerance)
         touches++;
   }
   
   return touches;
}

// Count how many times price touched the resistance level
int CountResistanceTouches(double level, int shift)
{
   int touches = 0;
   double tolerance = ZonePoints * _Point * SR_TouchTolerance;
   
   for(int i = shift; i < SR_Lookback + shift; i++)
   {
      double high = iHigh(_Symbol, _Period, i);
      double close = iClose(_Symbol, _Period, i);
      
      // Count touch: high is near the level
      if(MathAbs(high - level) <= tolerance)
         touches++;
      // Also count close near level as a touch
      else if(MathAbs(close - level) <= tolerance)
         touches++;
   }
   
   return touches;
}

// Check for bullish momentum: price action is shifting bullish
bool IsBullishMomentum()
{
   double close1 = iClose(_Symbol, _Period, 1);
   double close2 = iClose(_Symbol, _Period, 2);
   double open1 = iOpen(_Symbol, _Period, 1);
   double open2 = iOpen(_Symbol, _Period, 2);
   
   // Current candle is bullish
   bool currentBullish = close1 > open1;
   
   // Check for momentum shift pattern: previous bearish, current bullish (reversal)
   bool reversalPattern = (close2 < open2) && currentBullish;
   
   // Or consecutive bullish pattern
   bool consecutiveBullish = (close1 > close2);
   
   return reversalPattern || consecutiveBullish;
}

// Check for bearish momentum: price action is shifting bearish
bool IsBearishMomentum()
{
   double close1 = iClose(_Symbol, _Period, 1);
   double close2 = iClose(_Symbol, _Period, 2);
   double open1 = iOpen(_Symbol, _Period, 1);
   double open2 = iOpen(_Symbol, _Period, 2);
   
   // Current candle is bearish
   bool currentBearish = close1 < open1;
   
   // Check for momentum shift pattern: previous bullish, current bearish (reversal)
   bool reversalPattern = (close2 > open2) && currentBearish;
   
   // Or consecutive bearish pattern
   bool consecutiveBearish = (close1 < close2);
   
   return reversalPattern || consecutiveBearish;
}

// Soft volatility sanity
bool IsTradableCandle(int i)
{
   double range = CandleRange(i);

   double minRange = ZonePoints * _Point * MinCandleRangeMultiplier;
   double maxRange = ZonePoints * _Point * MaxCandleRangeMultiplier;

   if(range < minRange) return false;   // Too small (dead / chop)
   if(range > maxRange) return false;   // Too big (news / spike)

   return true;
}

// Candle utils
double CandleBody(int i)
{
   return MathAbs(iClose(_Symbol,_Period, i) - iOpen(_Symbol, _Period, i));
}

double CandleRange(int i)
{
   return iHigh(_Symbol, _Period, i) - iLow(_Symbol, _Period, i);
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Manage Positions                                                 |
// +------------------------------------------------------------------+
void ManagePositions()
{   
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        if(IsPositionHedged(ticket))
        {
            ManageHedgedPositions(ticket);
        }
        else
        {
            ManageLosingPositions(ticket);

            ManageWinningPositions(ticket);
        
            if(EnableTrailingStop) ManageTrailingStop(ticket);
        }
    }
}

// +------------------------------------------------------------------+
// | Manage Hedge Pair                                                |
// +------------------------------------------------------------------+
void ManageHedgedPositions(ulong ticket)
{   
    int i = FindHedgePairIndex(ticket);
    if (i == -1)
    {
        LogPrint("Hedge pair not found or removed, ticket: ", ticket);
        return;
    }

    ulong originalTicket = activePairs[i].originalTicket;
    ulong hedgeTicket = activePairs[i].hedgeTicket;
    
    // Check if original position still exist
    if(!PositionSelectByTicket(originalTicket))
    {
        LogPrint("⚠ Original position ", originalTicket, " no longer exists");
        RemoveHedgePair(i);
        return;
    }
    
    // Cache original position data while selected
    double originalProfit = PositionGetDouble(POSITION_PROFIT);
    double originalVolume = PositionGetDouble(POSITION_VOLUME);
    
    // Check if hedge position still exist
    if(!PositionSelectByTicket(hedgeTicket))
    {
        LogPrint("⚠ Hedge position ", hedgeTicket, " no longer exists");
        RemoveHedgePair(i);
        return;
    }
    
    // Cache hedge position data while selected
    double hedgeProfit = PositionGetDouble(POSITION_PROFIT);
    double hedgeVolume = PositionGetDouble(POSITION_VOLUME);
    
    // Calculate metrics
    double combinedProfit = originalProfit + hedgeProfit;
    int hedgeDurationMinutes = (int)((TimeCurrent() - activePairs[i].hedgeOpenTime) / 60);
    
    LogPrint("+-----------------------------------------+");
    LogPrint("HEDGE PAIR STATUS");
    LogPrint("Original Ticket: ", originalTicket, " | Hedge Ticket: ", hedgeTicket);
    LogPrint("Original Volume: ", originalVolume, " | Hedge Volume: ", hedgeVolume);
    LogPrint("Original Profit: $", originalProfit, " | Hedge Profit: $", hedgeProfit);
    LogPrint("Combined Profit: $", combinedProfit, " | Duration: ", hedgeDurationMinutes, " min");
    LogPrint("+-----------------------------------------+");
    
    // RULE 1: Combined profit sufficient to exit hedge pair
    if (combinedProfit > 0)
    {
        LogPrint("RULE 1: Combined profit sufficient to exit hedge pair");
        LogPrint("Combined profit: $", combinedProfit);
        LogPrint("Close to both positions to lock in profit");

        bool isClosed1 = ClosePosition(originalTicket);
        bool isClosed2 = ClosePosition(hedgeTicket);

        if (isClosed1 || isClosed2) RemoveHedgePair(i);
        return;
    }
    
    // RULE 2: Original position recovered
    if(originalProfit >= MinBreakEvenProfit * BreakEvenThresholdMultiplier)
    {
        LogPrint("RULE 2: Original position recovered to profit/breakeven");

        int score = GetInvalidationScore(hedgeTicket);
        
        if (score >= 4) 
        {
            LogPrint("Closing hedge, keeping original");
            bool isClosed = ClosePosition(hedgeTicket);
            if (isClosed) RemoveHedgePair(i);
        }
        else
        {
            LogPrint("Hedge invalidation score: ", score, " (Weak) Keeping hedge");
        }

        if (EnableTrailingStop) ManageTrailingStop(originalTicket);
        return;
    }

    // RULE 3: Hedge position sufficient
    if(hedgeProfit >= MinBreakEvenProfit * BreakEvenThresholdMultiplier)
    {
        LogPrint("RULE 3: Hedge position sufficient to profit/breakeven");

        int score = GetInvalidationScore(originalTicket);

        if (score >= 4) 
        {
            LogPrint("Closing original, keeping hedge");
            bool isClosed = ClosePosition(originalTicket);
            if (isClosed) RemoveHedgePair(i);
        }
        else
        {
            LogPrint("Original invalidation score: ", score, " (Weak) Keeping original");
        }

        if (EnableTrailingStop) ManageTrailingStop(hedgeTicket);
        return;
    }
    
    // RULE 4: Maximum time limit reached
    if(MaxHedgeDurationMinutes > 0 && hedgeDurationMinutes >= MaxHedgeDurationMinutes)
    {
        LogPrint("RULE 4: Maximum hedge duration reached (", MaxHedgeDurationMinutes, " min)");
        LogPrint("Closing both positions to prevent prolonged exposure");

        bool isClosed1 = ClosePosition(originalTicket);
        bool isClosed2 = ClosePosition(hedgeTicket);

        if (isClosed1 || isClosed2) RemoveHedgePair(i);
        return;
    }
    
    LogPrint("Hedge pair still active, monitoring...");
}

void AddHedgePair(ulong originalTicket, ulong hedgeTicket)
{
    // Validate both positions exist
    if(!PositionSelectByTicket(originalTicket) || !PositionSelectByTicket(hedgeTicket))
    {
        LogPrint("AddHedgePair: one or both tickets not found. Original: ", originalTicket, " Hedge: ", hedgeTicket);
        return;
    }

    // Prevent duplicates
    if(IsPositionHedged(originalTicket) || IsPositionHedged(hedgeTicket))
    {
        LogPrint("AddHedgePair: hedge pair already exists for ticket ", originalTicket);
        return;
    }

    double originalProfit = PositionGetDouble(POSITION_PROFIT);

    PositionSelectByTicket(hedgeTicket);
    double hedgeProfit = PositionGetDouble(POSITION_PROFIT);

    int size = ArraySize(activePairs);
    ArrayResize(activePairs, size + 1);

    activePairs[size].originalTicket = originalTicket;
    activePairs[size].hedgeTicket    = hedgeTicket;
    activePairs[size].hedgeOpenTime  = (datetime)PositionGetInteger(POSITION_TIME);

    LogPrint("+-----------------------------------------+");
    LogPrint("HEDGE PAIR ADDED");
    LogPrint("Original Ticket: ", originalTicket, " | Hedge Ticket: ", hedgeTicket);
    LogPrint("Initial Combined P/L: $", originalProfit + hedgeProfit);
    LogPrint("Hedge Open Time: ", activePairs[size].hedgeOpenTime);
    LogPrint("+-----------------------------------------+");
}

void RemoveHedgePair(int index)
{
    int size = ArraySize(activePairs);

    if(index < 0 || index >= size)
    {
        LogPrint("RemoveHedgePair: invalid index ", index, ", size=", size);
        return;
    }

    LogPrint("Removing hedge pair at index ", index,
                " (Original=", activePairs[index].originalTicket,
                ", Hedge=", activePairs[index].hedgeTicket, ")");

    // Swap with last element
    activePairs[index] = activePairs[size - 1];
    ArrayResize(activePairs, size - 1);
}

bool IsPositionHedged(ulong ticket)
{
    int size = ArraySize(activePairs);

    for(int i = 0; i < size; i++)
    {
        if(activePairs[i].originalTicket == ticket ||
            activePairs[i].hedgeTicket == ticket)
            return true;
    }

    return false;
}

int FindHedgePairIndex(ulong ticket)
{
    int size = ArraySize(activePairs);

    for(int i = 0; i < size; i++)
    {
        if(activePairs[i].originalTicket == ticket ||
            activePairs[i].hedgeTicket == ticket)
            return i;
    }

    return -1;
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Manage Pyramiding For Winning Positions                          |
// +------------------------------------------------------------------+
void ManageWinningPositions(ulong ticket)
{
    if(!EnablePyramiding || MaxPyramidingPositions <= 0) return;

    if(!PositionSelectByTicket(ticket)) return;

    datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double price = (orderType == ORDER_TYPE_BUY) ? ask : bid;

    // Duplicate filters
    if (orderType == ORDER_TYPE_BUY && AllowNewBuy(price)) return;
    if (orderType == ORDER_TYPE_SELL && AllowNewSell(price)) return;

    // Cooldown pyramiding
    if (TimeCurrent() - openTime >= PyramidCooldownSeconds) return;

    // Only check PROFITABLE positions
    double profit = PositionGetDouble(POSITION_PROFIT);
    if(profit < MinBreakEvenProfit * BreakEvenThresholdMultiplier) return;

    // Only pyramiding on winning position with profitable SL
    double currentSL = PositionGetDouble(POSITION_SL);
    if(currentSL == 0 || currentSL < entryPrice) return;
    
    // Max pyramiding reached (only counts profitable, non-hedged positions)
    int pyramidCount = CountProfitOpenOrders(posType);
    if(pyramidCount >= MaxPyramidingPositions) return;

    // Ensure the position has a weak invalidation signal score
    InvalidationDetails details = GetDetailedInvalidationScore(ticket);
    if(details.totalScore > 1) return;

    LogPrint("+-----------------------------------------+");
    LogPrint("PYRAMIDING TRIGGERED - ", EnumToString(posType));
    LogPrint("Ticket: ", ticket, " | Profit: $", profit);
    LogPrint("Positions: ", pyramidCount, "/", MaxPyramidingPositions);
    LogPrint("+-----------------------------------------+");

    // Open pyramiding position
    OpenPyramidingPosition(orderType);
}

// +------------------------------------------------------------------+
// | Manage Losing Positions                                          |
// +------------------------------------------------------------------+
void ManageLosingPositions(ulong ticket)
{   
    // Check cooldown
    if(ReverseCooldownMinutes > 0 && EnableAutoReverse)
    {
        if(TimeTradeServer() - lastReverseTime < ReverseCooldownMinutes * 60)
            return;
    }

    if(!PositionSelectByTicket(ticket)) return;

    double profit = PositionGetDouble(POSITION_PROFIT);

    // Only manage losing positions
    if(profit >= MinBreakEvenProfit) return;

    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double volume = PositionGetDouble(POSITION_VOLUME);

    // Get detailed invalidation analysis
    InvalidationDetails details = GetDetailedInvalidationScore(ticket);

    LogPrint("+-----------------------------------------+");
    LogPrint("POSITION INVALIDATION ANALYSIS");
    LogPrint("Ticket: ", ticket, " | Type: ", EnumToString(posType));
    LogPrint("Profit: $", profit, " | Volume: ", volume);
    LogPrint("+-----------------------------------------+");
    LogPrint("SIGNALS DETECTED:");
    LogPrint("[", details.immediateReversal ? "✓" : " ", "] Immediate Reversal (Weight: 4)");
    LogPrint("[", details.keyLevelBroken ? "✓" : " ", "] Key Level Broken (Weight: 3)");
    LogPrint("[", details.momentumShift ? "✓" : " ", "] Momentum Shift (Weight: 2)");
    LogPrint("[", details.microStructureFlip ? "✓" : " ", "] Micro Structure Flip (Weight: 2)");
    LogPrint("TOTAL SCORE: ", details.totalScore, " / 13");
    LogPrint("REASON: ", details.reason);
    LogPrint("+-----------------------------------------+");

    // Decision based on score thresholds
    // Score ranges: 0-1 (monitor), 2-3 (weak), 4-5 (moderate), 6+ (strong)
    if(details.totalScore >= 6 && EnableAutoReverse)
    {
        // STRONG invalidation (6+) → REVERSE
        LogPrint("DECISION: STRONG INVALIDATION - REVERSING POSITION");
        
        lastReverseTime = TimeTradeServer();
        
        if(!ClosePosition(ticket))
        {
            LogPrint("Failed to close position for reversal");
            return;
        }
        
        ENUM_ORDER_TYPE reverseType = (posType == POSITION_TYPE_BUY) ? 
                                       ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        
        LogPrint("Opening reversed position: ", EnumToString(reverseType));
        
        if(posType == POSITION_TYPE_BUY && EnableSellOrders)
            OpenPosition(ORDER_TYPE_SELL);
        else if(posType == POSITION_TYPE_SELL && EnableBuyOrders)
            OpenPosition(ORDER_TYPE_BUY);
    }
    else if(details.totalScore >= 4 && EnableAutoHedge)
    {
        // MODERATE invalidation (4-5) → HEDGE
        LogPrint("DECISION: MODERATE INVALIDATION - HEDGING POSITION");
        
        ENUM_ORDER_TYPE hedgeType = (posType == POSITION_TYPE_BUY) ? 
                                     ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        
        ulong hedgeTicket = OpenHedgePosition(hedgeType, volume);
        
        if(hedgeTicket > 0)
        {
            AddHedgePair(ticket, hedgeTicket);
            LogPrint("Hedge created: ", ticket, " ↔ ", hedgeTicket);
        }
        else
        {
            LogPrint("Hedge failed for position ", ticket);
        }
    }
    else
    {
        // WEAK or NO invalidation (0-3) → MONITOR
        LogPrint("DECISION: WEAK/NO INVALIDATION - MONITORING");
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
// | Position Invalidation Analysis                                   |
// +------------------------------------------------------------------+
InvalidationDetails GetDetailedInvalidationScore(ulong ticket)
{
    InvalidationDetails details;
    details.immediateReversal = false;
    details.keyLevelBroken = false;
    details.momentumShift = false;
    details.microStructureFlip = false;
    details.totalScore = 0;
    details.reason = "";
    
    if(!PositionSelectByTicket(ticket)) return details;
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    // Get entry price for quick reference
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // 1. IMMEDIATE REVERSAL (Weight: 4) - CRITICAL for M1
    // Fast reaction to sharp adverse price moves
    details.immediateReversal = CheckImmediateReversal(posType, entryPrice, currentPrice);
    if(details.immediateReversal) 
    {
        details.totalScore += 4;
        details.reason += "[Immediate Reversal] ";
    }
    
    // 2. KEY LEVEL BROKEN (Weight: 3) - HIGH PRIORITY
    // S/R breaks are decisive on M1
    details.keyLevelBroken = CheckKeyLevelBroken(posType);
    if(details.keyLevelBroken) 
    {
        details.totalScore += 3;
        details.reason += "[Key Level Broken] ";
    }
    
    // 3. MOMENTUM SHIFT (Weight: 2) - MEDIUM PRIORITY
    // S/R breakout momentum shift
    details.momentumShift = CheckMomentumShift(posType);
    if(details.momentumShift) 
    {
        details.totalScore += 2;
        details.reason += "[Momentum Shift] ";
    }
    
    // 4. MICRO STRUCTURE FLIP (Weight: 2) - MEDIUM PRIORITY
    // Quick swing structure changes on M1
    details.microStructureFlip = CheckMicroStructureFlip(posType);
    if(details.microStructureFlip) 
    {
        details.totalScore += 2;
        details.reason += "[Structure Flip] ";
    }
    
    // Score 0-1:  No significant invalidation - Hold position
    // Score 2-3:  Weak invalidation - Monitor closely
    // Score 4-5:  Moderate invalidation - Consider hedge/reduce
    // Score 6+:   Strong invalidation - Exit or hedge immediately
    return details;
}

// Backward compatible simple version
int GetInvalidationScore(ulong ticket)
{
    InvalidationDetails details = GetDetailedInvalidationScore(ticket);
    return details.totalScore;
}

// 1. IMMEDIATE REVERSAL - Sharp Adverse Price Move
bool CheckImmediateReversal(ENUM_POSITION_TYPE type, double entryPrice, double currentPrice)
{
    // Get last 3 candles for quick trend check
    double close1 = iClose(_Symbol, _Period, 1);
    double close2 = iClose(_Symbol, _Period, 2);
    double close3 = iClose(_Symbol, _Period, 3);
    double open1 = iOpen(_Symbol, _Period, 1);
    
    if(close1 == 0 || open1 == 0) return false;
    
    double avgCandleBody = GetAverageCandleBody(5); // Last 5 candles
    double currentCandleBody = MathAbs(close1 - open1);
    
    if(type == POSITION_TYPE_BUY)
    {
        // BUY invalidation: Large bearish candle + consecutive bearish moves
        bool largeBearishCandle = (close1 < open1) && (currentCandleBody > avgCandleBody * 1.3);
        bool consecutiveBearish = (close1 < close2) && (close2 < close3);
        bool priceMovedAgainst = currentPrice < (entryPrice - avgCandleBody * 0.5);
        
        return (largeBearishCandle && consecutiveBearish) || priceMovedAgainst;
    }
    
    if(type == POSITION_TYPE_SELL)
    {
        // SELL invalidation: Large bullish candle + consecutive bullish moves
        bool largeBullishCandle = (close1 > open1) && (currentCandleBody > avgCandleBody * 1.3);
        bool consecutiveBullish = (close1 > close2) && (close2 > close3);
        bool priceMovedAgainst = currentPrice > (entryPrice + avgCandleBody * 0.5);
        
        return (largeBullishCandle && consecutiveBullish) || priceMovedAgainst;
    }
    
    return false;
}

// 2. KEY LEVEL BROKEN - S/R Decisively Breached
bool CheckKeyLevelBroken(ENUM_POSITION_TYPE type)
{
    double close1 = iClose(_Symbol, _Period, 1);
    double close2 = iClose(_Symbol, _Period, 2);
    double open1 = iOpen(_Symbol, _Period, 1);
    
    if(close1 == 0 || close2 == 0) return false;

    if(type == POSITION_TYPE_BUY)
    {
        double support = GetSupport(1);
        if(support <= 0) return false;
        
        // Decisive break: Body closes below support
        bool bodyBelowSupport = MathMax(open1, close1) < support;
        bool consecutiveBreak = (close1 < support) && (close2 < support);
        
        return bodyBelowSupport || consecutiveBreak;
    }

    if(type == POSITION_TYPE_SELL)
    {
        double resistance = GetResistance(1);
        if(resistance <= 0) return false;
        
        // Decisive break: Body closes above resistance
        bool bodyAboveResistance = MathMin(open1, close1) > resistance;
        bool consecutiveBreak = (close1 > resistance) && (close2 > resistance);
        
        return bodyAboveResistance || consecutiveBreak;
    }

    return false;
}

// 3. MOMENTUM SHIFT - S/R Breakout Detection
bool CheckMomentumShift(ENUM_POSITION_TYPE type)
{
    double close1 = iClose(_Symbol, _Period, 1);
    double close2 = iClose(_Symbol, _Period, 2);
    double close3 = iClose(_Symbol, _Period, 3);
    double open1 = iOpen(_Symbol, _Period, 1);
    
    if(close1 == 0 || close2 == 0) return false;
    
    double breakoutDistance = ZonePoints * _Point * SR_BreakoutConfirmation;

    if(type == POSITION_TYPE_BUY)
    {
        // BUY invalidation: Price breaking below support with momentum
        double support = GetSupport(1);
        if(support <= 0) return false;
        
        // Check for decisive breakdown: price moved below support by breakout distance
        bool breakdownConfirmed = close1 < (support - breakoutDistance);
        
        // Consecutive closes below support
        bool consecutiveBreakdown = (close1 < support) && (close2 < support);
        
        // Momentum shift: consecutive bearish candles
        bool bearishMomentum = (close1 < close2) && (close2 < close3);
        
        return breakdownConfirmed || (consecutiveBreakdown && bearishMomentum);
    }

    if(type == POSITION_TYPE_SELL)
    {
        // SELL invalidation: Price breaking above resistance with momentum
        double resistance = GetResistance(1);
        if(resistance <= 0) return false;
        
        // Check for decisive breakout: price moved above resistance by breakout distance
        bool breakoutConfirmed = close1 > (resistance + breakoutDistance);
        
        // Consecutive closes above resistance
        bool consecutiveBreakout = (close1 > resistance) && (close2 > resistance);
        
        // Momentum shift: consecutive bullish candles
        bool bullishMomentum = (close1 > close2) && (close2 > close3);
        
        return breakoutConfirmed || (consecutiveBreakout && bullishMomentum);
    }

    return false;
}

// 4. MICRO STRUCTURE FLIP - Quick Swing Changes on M1
bool CheckMicroStructureFlip(ENUM_POSITION_TYPE type)
{
    // Look at very recent highs/lows (last 5 candles)
    double high1 = iHigh(_Symbol, _Period, 1);
    double high2 = iHigh(_Symbol, _Period, 2);
    double high3 = iHigh(_Symbol, _Period, 3);
    double low1 = iLow(_Symbol, _Period, 1);
    double low2 = iLow(_Symbol, _Period, 2);
    double low3 = iLow(_Symbol, _Period, 3);
    
    if(high1 == 0 || low1 == 0) return false;

    if(type == POSITION_TYPE_BUY)
    {
        // BUY invalidation: Lower high formed
        bool lowerHigh = (high1 < high2) && (high2 >= high3);
        bool breakingLow = low1 < low2;
        
        return lowerHigh && breakingLow;
    }

    if(type == POSITION_TYPE_SELL)
    {
        // SELL invalidation: Higher low formed
        bool higherLow = (low1 > low2) && (low2 <= low3);
        bool breakingHigh = high1 > high2;
        
        return higherLow && breakingHigh;
    }

    return false;
}

// Helper: Get Average Candle Body Size
double GetAverageCandleBody(int periods)
{
    double totalBody = 0;
    for(int i = 1; i <= periods; i++)
    {
        double open = iOpen(_Symbol, _Period, i);
        double close = iClose(_Symbol, _Period, i);
        totalBody += MathAbs(close - open);
    }
    return totalBody / periods;
}
// +------------------------------------------------------------------+

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

// Open Pyramiding Position
void OpenPyramidingPosition(ENUM_ORDER_TYPE orderType)
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
    request.comment = "Pyramiding Position by Nyao Scalper";

    // Calculate and set Take Profit (Standard)
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
    
    // Calculate closest stop loss price
    long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    
    // Minimum distance in points required by broker
    long minDistancePoints = MathMax(stopLevel, freezeLevel);

    // Add trailing distance to minimum distance
    double trailingDistancePoints = ConvertToPoints(TSInputType, TSValue, currentLot);
    double minDistancePrice = (minDistancePoints + trailingDistancePoints) * _Point; 
    
    if(orderType == ORDER_TYPE_BUY)
    {
        request.sl = NormalizeDouble(price - minDistancePrice, _Digits);
    }
    else
    {
        request.sl = NormalizeDouble(price + minDistancePrice, _Digits);
    }
    
    // Fallback Check in case SL is invalid
    if(!IsSLValid((orderType == ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL), request.sl))
    {
        LogPrint("Pyramiding: Tightest Calculated SL invalid (", request.sl, "). Using Standard SL.");
        // Fallback to standard
        if(EnableStopLoss)
        {
            double slPoints = ConvertToPoints(SLInputType, SLValue, currentLot);

            if(orderType == ORDER_TYPE_BUY)
                 request.sl = NormalizeDouble(price - (slPoints * _Point), _Digits);
            else
                 request.sl = NormalizeDouble(price + (slPoints * _Point), _Digits);
        }
        else
        {
             request.sl = 0; // No SL
        }
    }
    
    bool orderResult = OrderSend(request, result);
    
    if(orderResult)
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {   
            LogPrint("Pyramiding Order Opened. Ticket: ", result.order, ", SL: ", request.sl);
        }
        else
        {
            LogPrint("Pyramiding OrderSend failed. Retcode: ", result.retcode, " - ", result.comment);
        }
    }
    else
    {
        LogPrint("Pyramiding OrderSend returned false. Error: ", GetLastError());
    }

    LockOrderSend(false);
}

// Open Hedge position
ulong OpenHedgePosition(ENUM_ORDER_TYPE type, double volume)
{   
    if (!IsAllowedToOpenPosition()) return 0;

    LockOrderSend(true);

    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double price = (type == ORDER_TYPE_BUY) ? ask : bid;
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = volume;
    request.type = type;
    request.price = price;
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = "Hedge Position by Nyao Scalper";

    // Add SL/TP like OpenPosition() does
    if(EnableTakeProfit)
    {
        double tpPoints = ConvertToPoints(TPInputType, TPValue, volume);
        
        if(type == ORDER_TYPE_BUY)
            request.tp = NormalizeDouble(price + (tpPoints * _Point), _Digits); 
        else
            request.tp = NormalizeDouble(price - (tpPoints * _Point), _Digits); 
    }
    
    if(EnableStopLoss)
    {
        double slPoints = ConvertToPoints(SLInputType, SLValue, volume);
        
        if(type == ORDER_TYPE_BUY)
            request.sl = NormalizeDouble(price - (slPoints * _Point), _Digits);
        else
            request.sl = NormalizeDouble(price + (slPoints * _Point), _Digits);
    }
    
    if(!OrderSend(request, result))
    {
        LogPrint("Failed to open hedge position. Error: ", GetLastError());
        LockOrderSend(false);
        return 0;
    }
    
    LogPrint("Hedge position opened: ", result.order);
    LockOrderSend(false);
    return result.order;
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

    if (CountOpenOrders() > MaxOpenOrders)
    {
        LogPrint("+-----------------------------------------+");
        LogPrint("OPEN ORDER BLOCKED!");
        LogPrint("Maximum consecutive open order reaced!");
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

// Helper to count profit open orders by position type (only profitable, non-hedged positions)
int CountProfitOpenOrders(ENUM_POSITION_TYPE posType)
{
    int count = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);

        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               PositionGetInteger(POSITION_TYPE) == posType &&
               PositionGetDouble(POSITION_PROFIT) >= MinBreakEvenProfit &&
               !IsPositionHedged(ticket))
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
            alertMsg += "**Status:** All positions closed, trading stopped";
            
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
            alertMsg += "**Status:** All positions closed, trading stopped";
            
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
                    alertMsg += "**Status:** All positions closed, trading stopped";
                    
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
            LogPrint("Closing unprofitable positions...");
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
                alertMsg += "**Action:** Trading Paused & Closing unprofitable positions";
                
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
            alertMsg += "**Action:** Trading paused during news period & closing unprofitable positions";
            
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
            alertMsg += "**Status:** Now accepting new trading signals";
            
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
            alertMsg += "⏸**Status:** No new positions until next trading session";
            
            SendDiscordAlert("🔴 TRADING HOURS ENDED!", alertMsg, 15158332); // Red color
            
            // Send Daily Report
            SendDailyReport();
        }
    }
}

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
            alertMsg += "**Status:** Trading paused until leverage returns to initial value";
            
            SendDiscordAlert("⚠️ LEVERAGE CHANGE - TRADING PAUSED", alertMsg, 16705372); // Orange color
        }
        
        CloseAllPositions(true); // Close only unprofitable positions
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
            alertMsg += "**Status:** Trading resumed - monitoring for new signals";
            
            SendDiscordAlert("▶️ LEVERAGE RESTORED - TRADING RESUMED", alertMsg, 3066993); // Blue color
        }
    }
}

// +------------------------------------------------------------------+
// | Check and Send Daily Report                                      |
// +------------------------------------------------------------------+
void CheckDailyReport()
{
    datetime serverTime = TimeTradeServer();
    MqlDateTime dt;
    TimeToStruct(serverTime, dt);
    
    if(!EnableTradingHours && dt.hour == 23 && dt.min == 59)
    {
        // Check if report already sent today (to avoid spamming in the last minute)
        // lastDailyReportTime checks full timestamp
        MqlDateTime lastReportDt;
        TimeToStruct(lastDailyReportTime, lastReportDt);
        
        if(lastReportDt.day != dt.day)
        {
            SendDailyReport();
        }
    }
}

// Get Daily Statistics
void GetDailyStats(int& dailyTrades, int& totalTrades, double& dailyProfit, double& totalProfit, double& dailyLoss, double& totalLoss) 
{
    dailyTrades = 0;
    totalTrades = 0;
    dailyProfit = 0;
    totalProfit = 0;
    dailyLoss = 0;
    totalLoss = 0;

    datetime now = TimeCurrent();
    datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0); // Start of current day

    // Select history
    if(HistorySelect(0, now)) {
        int deals = HistoryDealsTotal();
        for(int i = 0; i < deals; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            
            // Filter by symbol and magic number
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol || 
               HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;

            // We only care about exits (deals that finalize profit/loss)
            // DEAL_ENTRY_OUT or DEAL_ENTRY_INOUT for reversing? 
            // Usually profit is realized on OUT or INOUT.
            // Check profit != 0 to be sure, or just sum profit.
            
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                            HistoryDealGetDouble(ticket, DEAL_SWAP) + 
                            HistoryDealGetDouble(ticket, DEAL_COMMISSION);

            datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            
            // Total Stats
            if (entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT) {
                totalTrades++;
                totalProfit += profit; // Net profit
                if(profit < 0) totalLoss += profit;
                
                // Daily Stats
                if(dealTime >= startOfDay) {
                    dailyTrades++;
                    dailyProfit += profit;
                    if(profit < 0) dailyLoss += profit;
                }
            }
        }
    }
}

// Send Daily Report
void SendDailyReport() 
{
    if(!EnableDiscordAlerts) return;

    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    int dailyTrades, totalTrades;
    double dailyProfit, totalProfit, dailyLoss, totalLoss;
    
    GetDailyStats(dailyTrades, totalTrades, dailyProfit, totalProfit, dailyLoss, totalLoss);
    
    // Duration
    long durationSeconds = TimeCurrent() - startTime;
    int days = (int)(durationSeconds / 86400);
    int hours = (int)((durationSeconds % 86400) / 3600);
    int minutes = (int)((durationSeconds % 3600) / 60);
    
    string durationStr = "";
    if(days > 0) durationStr += IntegerToString(days) + "d ";
    if(hours > 0) durationStr += IntegerToString(hours) + "h ";
    durationStr += IntegerToString(minutes) + "m";
    
    string alertMsg = "**Instrument:** " + _Symbol + "\n";
    alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
    alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
    alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
    alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
    alertMsg += "**Daily Trades:** " + IntegerToString(dailyTrades) + "\n";
    alertMsg += "**Total Trades:** " + IntegerToString(totalTrades) + "\n";
    alertMsg += "**Daily Profit:** $" + DoubleToString(dailyProfit, 2) + "\n";
    alertMsg += "**Total Profit:** $" + DoubleToString(totalProfit, 2) + "\n";
    alertMsg += "**Daily Loss:** $" + DoubleToString(dailyLoss, 2) + "\n";
    alertMsg += "**Total Loss:** $" + DoubleToString(totalLoss, 2) + "\n";
    alertMsg += "**Running Duration:** " + durationStr;
    
    SendDiscordAlert("📊 DAILY TRADE REPORT", alertMsg, 16776960); // Yellow/Gold color
    
    lastDailyReportTime = TimeCurrent();
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Toggle Disable Algo Trading MT5                                  |
// +------------------------------------------------------------------+
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
    json += "\"footer\":{\"text\":\"Nyao Scalper v15.0\"}";
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
        // Get current equity
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

        string alertMsg = "**Instrument:** " + _Symbol + "\n";
        alertMsg += "**Timeframe:** " + EnumToString(_Period) + "\n";
        alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
        alertMsg += "**Trading Hours:** " + (EnableTradingHours ? TradingStartTime + " - " + TradingEndTime + "\n" : "DISABLED\n");
        alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
        alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
        alertMsg += "**News Filter:** " + (EnableNewsFilter ? "ENABLED" : "DISABLED") + "\n";
        alertMsg += "**Status:** Trading started successfully";
        
        SendDiscordAlert("🟢 AUTOMATED TRADING STARTED", alertMsg, 5763719); // Green color
    }
}