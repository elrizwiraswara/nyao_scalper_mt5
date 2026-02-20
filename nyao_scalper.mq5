// +------------------------------------------------------------------+
// | Nyao Scalper v34.0                                               |
// | Indicator-Based Signal Strength EA with Comprehensive Features   |
// | © Copyright Nyao Scalper by Elriz Wiraswara                      |
// +------------------------------------------------------------------+
#property copyright "© Copyright Nyao Scalper by Elriz Wiraswara"
#property version   "34.0"
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
input group " Nyao Scalper v34.0"
input group " © Copyright Nyao Scalper by Elriz Wiraswara"
input group "+-----------------------------------------+"

// +------------------------------------------------------------------+
// | Input Parameters                                                 |
// +------------------------------------------------------------------+
input group "🚦 Indicator Settings"
input int RSI_Period = 14;                                // RSI Period
input int Lookback = 50;                                  // Lookback Period for Signal Confirmation
input double ZonePoints = 10000;                          // Zone Points to Avoid Duplicate Signals (Smaller = Less Signals)
input double BuyRSIMax  = 80;                             // Overbought Value - Buy when RSI is below this
input double SellRSIMin = 20;                             // Oversold Value - Sell when RSI is above this
input double MinCandleRangeMultiplier = 0.5;              // Minimum Candle Size (Aggressiveness)
input double MaxCandleRangeMultiplier = 5.0;              // Maximum Candle Size (Spike filter)

input group "📝 Order Settings"
input bool EnableBuyOrders = true;                        // Enable Buy Orders
input bool EnableSellOrders = true;                       // Enable Sell Orders
input double BaseLotSize = 0.01;                          // Base Lot Size
input int MaxOpenOrders = 25;                             // Maximum Consecutive Open Orders
input double BuyDuplicateMultiplier  = 0.1;               // Minimum Distance Multiplier to Avoid Duplicate Buy Signals
input double SellDuplicateMultiplier = 0.1;               // Minimum Distance Multiplier to Avoid Duplicate Sell Signals
input double MinBreakEvenProfit = 1.5;                    // Minimum Profit to Trigger Break-Even ($)
input bool EnableAutoReverse = true;                      // Enable Auto Reverse on Opposite Signal
input int ReverseCooldownMinutes = 2;                     // Cooldown Duration Minutes after Reverse (0 = No Cooldown)
input bool EnableAutoHedge = true;                        // Enable Auto Hedge on Opposite Signal
input int MaxHedgeDurationMinutes = 480;                  // Max Hedge Duration (Minutes)
input bool EnablePyramiding = true;                       // Enable Pyramiding (Open new position on winning position)
input int MaxPyramidingPositions = 5;                     // Max Total Pyramiding Positions
input double PyramidingThresholdMultiplier = 1;           // Multiplier for MinBreakEvenProfit to Trigger Pyramiding

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

// RSI Indicator Handle and Buffer
int rsiHandle = INVALID_HANDLE;
double rsi[];

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
    bool structureFlip;
    bool momentumFlip;
    bool keyLevelBroken;
    bool priceActionAgainst;
    bool volumeWeakness;
    bool trendReversal;
    bool confirmedBreak;
    int totalScore;
    string reason;
};

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

    // Initialize RSI Indicator
    rsiHandle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE)
    {
        Alert("ERROR: Error creating RSI indicator");
        return(INIT_FAILED);
    }

    ArraySetAsSeries(rsi, true);
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
    lastReportEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    totalPauseCount = 0;
    totalPauseDurationMinutes = 0;
    symbolBaseCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
    symbolQuoteCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
    initialLeverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    isOrderSendLocked = false;
    algoTradingStatus = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
    
    Print("+-----------------------------------------+");
    Print("Nyao Scalper v34.0 Initialized Successfully");
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
    
    // Release RSI Handle
    if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);

    ArrayFree(rsi);
    ArrayFree(activePairs);
    
    Print("Nyao Scalper v34.0 Deinitialized");
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
// | Candle Utils                                                     |
// +------------------------------------------------------------------+
double CandleBody(int i)
{
   return MathAbs(iClose(_Symbol, _Period, i) - iOpen(_Symbol, _Period, i));
}

double CandleRange(int i)
{
   return iHigh(_Symbol, _Period, i) - iLow(_Symbol, _Period, i);
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Soft Volatility Sanity                                           |
// +------------------------------------------------------------------+
bool IsTradableCandle(int i)
{
   double range = CandleRange(i);

   double minRange = ZonePoints * _Point * MinCandleRangeMultiplier;
   double maxRange = ZonePoints * _Point * MaxCandleRangeMultiplier;

   if(range < minRange) return false;   // Too small (dead / chop)
   if(range > maxRange) return false;   // Too big (news / spike)

   return true;
}

// +------------------------------------------------------------------+
// | Micro Structures                                                 |
// +------------------------------------------------------------------+
bool HigherLow()
{
   double l1 = iLow(_Symbol, _Period, 1);
   double l2 = iLow(_Symbol, _Period, 2);
   return (l1 > l2);
}

bool LowerHigh()
{
   double h1 = iHigh(_Symbol, _Period, 1);
   double h2 = iHigh(_Symbol, _Period, 2);
   return (h1 < h2);
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Get Support & Resistance                                         |
// +------------------------------------------------------------------+
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
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | FAKE BREAK (wick + close back)                                   |
// +------------------------------------------------------------------+
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
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Duplicate Filters                                                |
// +------------------------------------------------------------------+
bool AllowNewBuy(double price)
{
   if(MathAbs(price - lastBuyPrice) < ZonePoints * _Point * BuyDuplicateMultiplier) return false;
   return true;
}

bool AllowNewSell(double price)
{
   if(MathAbs(price - lastSellPrice) < ZonePoints * _Point * SellDuplicateMultiplier) return false;
   return true;
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Buy Signal                                                       |
// +------------------------------------------------------------------+
bool BuySignal()
{
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsi) <= 0) return false;

   double close1  = iClose(_Symbol, _Period, 1);
   double support = GetSupport(1);

   bool nearSupport = MathAbs(close1 - support) <= ZonePoints * _Point;

   if(!IsTradableCandle(1)) return false;

   if(
      nearSupport &&
      rsi[1] < BuyRSIMax &&                     
      (HigherLow() || FakeBreakBuy(support) || iClose(_Symbol, _Period, 1) > iOpen(_Symbol, _Period, 1)) &&
      AllowNewBuy(close1)
     )
   {
      lastBuyPrice = close1;
      return true;
   }

   return false;
}

// +------------------------------------------------------------------+
// | Sell Signal                                                      |
// +------------------------------------------------------------------+
bool SellSignal()
{
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsi) <= 0) return false;

   double close1 = iClose(_Symbol, _Period, 1);
   double resistance = GetResistance(1);

   bool nearResistance = MathAbs(close1 - resistance) <= ZonePoints * _Point;

   if(!IsTradableCandle(1)) return false;

   if(
      nearResistance &&
      rsi[1] > SellRSIMin &&                     
      (LowerHigh() || FakeBreakSell(resistance) || iClose(_Symbol, _Period, 1) < iOpen(_Symbol, _Period, 1)) &&
      AllowNewSell(close1)
     )
   {
      lastSellPrice = close1;
      return true;
   }

   return false;
}

// +------------------------------------------------------------------+
// | Calculate current lot size based on equity drop from peak        |
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
    
    return currentLot;
}

// +------------------------------------------------------------------+
// | Count open orders with magic number                             |
// +------------------------------------------------------------------+
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
// | Check For Trading Signals                                        |
// +------------------------------------------------------------------+
void CheckForTradingSignal()
{   
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

// +------------------------------------------------------------------+
// | Manage existing positions                                        |
// +------------------------------------------------------------------+
void ManagePositions()
{   
    // Manage existing hedge pairs
    ManageHedgedPositions();

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {      
                // Skip hedged positions from individual management
                if(IsPositionHedged(ticket))
                {
                    LogPrint("Position ", ticket, " is hedged, skipping individual management");
                    continue;
                }

                // Check if losing AND trend reversed
                ManageLosingPositions(ticket);
                
                // Check for pyramiding (Add to winners)
                ManageWinningPositions(ticket);

                // Manage trailing stop if enabled
                if(EnableTrailingStop) ManageTrailingStop(ticket);
            }
        }
    }
}

// +------------------------------------------------------------------+
// | Check invalidation conditions                                    |
// +------------------------------------------------------------------+
// +------------------------------------------------------------------+
// | 1. Structure Analysis - Market Structure Against Position        |
// +------------------------------------------------------------------+
bool StructureFlipAgainstPosition(ENUM_POSITION_TYPE type)
{
    double close1 = iClose(_Symbol, _Period, 1);
    double open1 = iOpen(_Symbol, _Period, 1);
    double close2 = iClose(_Symbol, _Period, 2);
    double open2 = iOpen(_Symbol, _Period, 2);
    
    if(close1 == 0 || open1 == 0 || close2 == 0 || open2 == 0)
    {
        LogPrint("Failed to get price data for structure flip check");
        return false;
    }
    
    if(type == POSITION_TYPE_BUY)
    {
        bool lowerHigh = LowerHigh();
        bool bearishCandle = close1 < open1;
        bool consecutiveBearish = (close1 < open1) && (close2 < open2);
        
        double candleBody = MathAbs(close1 - open1);
        double avgCandleBody = GetAverageCandleBody(10);
        bool significantBearishBody = (candleBody > avgCandleBody * 0.7);
        
        return lowerHigh && bearishCandle && (consecutiveBearish || significantBearishBody);
    }

    if(type == POSITION_TYPE_SELL)
    {
        bool higherLow = HigherLow();
        bool bullishCandle = close1 > open1;
        bool consecutiveBullish = (close1 > open1) && (close2 > open2);
        
        double candleBody = MathAbs(close1 - open1);
        double avgCandleBody = GetAverageCandleBody(10);
        bool significantBullishBody = (candleBody > avgCandleBody * 0.7);
        
        return higherLow && bullishCandle && (consecutiveBullish || significantBullishBody);
    }

    return false;
}

// +------------------------------------------------------------------+
// | 2. Momentum Analysis - RSI with Dynamic Thresholds               |
// +------------------------------------------------------------------+
bool MomentumFlipAgainstPosition(ENUM_POSITION_TYPE type)
{
    if(CopyBuffer(rsiHandle, 0, 0, 5, rsi) <= 0)
    {
        LogPrint("Failed to copy RSI buffer, error: ", GetLastError());
        return false;
    }

    double buyInvalidationLevel = 50 - (BuyRSIMax - 50) * 0.5;
    double sellInvalidationLevel = 50 + (50 - SellRSIMin) * 0.5;

    if(type == POSITION_TYPE_BUY)
    {
        bool rsiWeak = rsi[1] < buyInvalidationLevel;
        bool rsiDeclining = (rsi[1] < rsi[2]) && (rsi[2] < rsi[3]);
        bool rsiOverbought = rsi[1] > BuyRSIMax;
        
        return (rsiWeak && rsiDeclining) || (rsi[1] < buyInvalidationLevel - 10) || rsiOverbought;
    }

    if(type == POSITION_TYPE_SELL)
    {
        bool rsiStrong = rsi[1] > sellInvalidationLevel;
        bool rsiRising = (rsi[1] > rsi[2]) && (rsi[2] > rsi[3]);
        bool rsiOversold = rsi[1] < SellRSIMin;
        
        return (rsiStrong && rsiRising) || (rsi[1] > sellInvalidationLevel + 10) || rsiOversold;
    }

    return false;
}

// +------------------------------------------------------------------+
// | 3. Key Level Analysis - Support/Resistance Breaks                |
// +------------------------------------------------------------------+
bool KeyLevelBroken(ENUM_POSITION_TYPE type)
{
    double close1 = iClose(_Symbol, _Period, 1);
    double close2 = iClose(_Symbol, _Period, 2);
    
    if(close1 == 0 || close2 == 0)
    {
        LogPrint("Failed to get close price for key level check");
        return false;
    }

    if(type == POSITION_TYPE_BUY)
    {
        double support = GetSupport(1);
        if(support <= 0) return false;
        
        bool currentBelowSupport = close1 < support;
        bool previousBelowSupport = close2 < support;
        bool decisiveBreak = (support - close1) > (ZonePoints * _Point * 0.5);
        
        return (currentBelowSupport && previousBelowSupport) || 
               (currentBelowSupport && decisiveBreak);
    }

    if(type == POSITION_TYPE_SELL)
    {
        double resistance = GetResistance(1);
        if(resistance <= 0) return false;
        
        bool currentAboveResistance = close1 > resistance;
        bool previousAboveResistance = close2 > resistance;
        bool decisiveBreak = (close1 - resistance) > (ZonePoints * _Point * 0.5);
        
        return (currentAboveResistance && previousAboveResistance) || 
               (currentAboveResistance && decisiveBreak);
    }

    return false;
}

// +------------------------------------------------------------------+
// | 4. Price Action Against Position - Consecutive Opposite Candles  |
// +------------------------------------------------------------------+
bool PriceActionAgainstPosition(ENUM_POSITION_TYPE type)
{
    double close1 = iClose(_Symbol, _Period, 1);
    double open1 = iOpen(_Symbol, _Period, 1);
    double close2 = iClose(_Symbol, _Period, 2);
    double open2 = iOpen(_Symbol, _Period, 2);
    double close3 = iClose(_Symbol, _Period, 3);
    double open3 = iOpen(_Symbol, _Period, 3);
    
    if(type == POSITION_TYPE_BUY)
    {
        int bearishCount = 0;
        if(close1 < open1) bearishCount++;
        if(close2 < open2) bearishCount++;
        if(close3 < open3) bearishCount++;
        
        return bearishCount >= 2;
    }
    
    if(type == POSITION_TYPE_SELL)
    {
        int bullishCount = 0;
        if(close1 > open1) bullishCount++;
        if(close2 > open2) bullishCount++;
        if(close3 > open3) bullishCount++;
        
        return bullishCount >= 2;
    }
    
    return false;
}

// +------------------------------------------------------------------+
// | 5. Volume Weakness Detection                                     |
// +------------------------------------------------------------------+
bool VolumeWeaknessDetected(ENUM_POSITION_TYPE type)
{
    long volume1 = iVolume(_Symbol, _Period, 1);
    long volume2 = iVolume(_Symbol, _Period, 2);
    long volume3 = iVolume(_Symbol, _Period, 3);
    
    if(volume1 <= 0) return false;
    
    double avgVolume = (volume1 + volume2 + volume3) / 3.0;
    
    double close1 = iClose(_Symbol, _Period, 1);
    double open1 = iOpen(_Symbol, _Period, 1);
    
    if(type == POSITION_TYPE_BUY)
    {
        bool bearishCandle = close1 < open1;
        bool highVolume = volume1 > avgVolume * 1.2;
        return bearishCandle && highVolume;
    }
    
    if(type == POSITION_TYPE_SELL)
    {
        bool bullishCandle = close1 > open1;
        bool highVolume = volume1 > avgVolume * 1.2;
        return bullishCandle && highVolume;
    }
    
    return false;
}

// +------------------------------------------------------------------+
// | 6. Trend Reversal Detection - Moving Average Cross               |
// +------------------------------------------------------------------+
bool TrendReversalDetected(ENUM_POSITION_TYPE type)
{
    double close1 = iClose(_Symbol, _Period, 1);
    
    double sma20_current = 0;
    double sma20_previous = 0;
    
    for(int i = 1; i <= 20; i++)
    {
        sma20_current += iClose(_Symbol, _Period, i);
        sma20_previous += iClose(_Symbol, _Period, i + 1);
    }
    
    sma20_current /= 20.0;
    sma20_previous /= 20.0;
    
    if(type == POSITION_TYPE_BUY)
    {
        bool priceBelowMA = close1 < sma20_current;
        bool maTurningDown = sma20_current < sma20_previous;
        return priceBelowMA && maTurningDown;
    }
    
    if(type == POSITION_TYPE_SELL)
    {
        bool priceAboveMA = close1 > sma20_current;
        bool maTurningUp = sma20_current > sma20_previous;
        return priceAboveMA && maTurningUp;
    }
    
    return false;
}

// +------------------------------------------------------------------+
// | 7. Confirmed Break Detection (Opposite of Fake Break)            |
// +------------------------------------------------------------------+
bool ConfirmedBreakAgainstPosition(ENUM_POSITION_TYPE type)
{
    double close1 = iClose(_Symbol, _Period, 1);
    double close2 = iClose(_Symbol, _Period, 2);
    double open1  = iOpen(_Symbol, _Period, 1);
    
    if(type == POSITION_TYPE_BUY)
    {
        double support = GetSupport(1);
        
        bool closeBelowSupport = close1 < support;
        bool previousCloseBelowSupport = close2 < support;
        bool bodyBelowSupport = (MathMax(open1, close1)) < support;
        
        return closeBelowSupport && (previousCloseBelowSupport || bodyBelowSupport);
    }
    
    if(type == POSITION_TYPE_SELL)
    {
        double resistance = GetResistance(1);
        
        bool closeAboveResistance = close1 > resistance;
        bool previousCloseAboveResistance = close2 > resistance;
        bool bodyAboveResistance = (MathMin(open1, close1)) > resistance;
        
        return closeAboveResistance && (previousCloseAboveResistance || bodyAboveResistance);
    }
    
    return false;
}

// +------------------------------------------------------------------+
// | Enhanced Invalidation Score with Detailed Analysis               |
// +------------------------------------------------------------------+
InvalidationDetails GetDetailedInvalidationScore(ulong ticket)
{
    InvalidationDetails details;
    details.structureFlip = false;
    details.momentumFlip = false;
    details.keyLevelBroken = false;
    details.priceActionAgainst = false;
    details.volumeWeakness = false;
    details.trendReversal = false;
    details.confirmedBreak = false;
    details.totalScore = 0;
    details.reason = "";
    
    if(!PositionSelectByTicket(ticket)) return details;
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    details.structureFlip = StructureFlipAgainstPosition(posType);
    details.momentumFlip = MomentumFlipAgainstPosition(posType);
    details.keyLevelBroken = KeyLevelBroken(posType);
    details.priceActionAgainst = PriceActionAgainstPosition(posType);
    details.volumeWeakness = VolumeWeaknessDetected(posType);
    details.trendReversal = TrendReversalDetected(posType);
    details.confirmedBreak = ConfirmedBreakAgainstPosition(posType);
    
    if(details.structureFlip) details.totalScore += 2;
    if(details.momentumFlip) details.totalScore += 2;
    if(details.keyLevelBroken) details.totalScore += 3;
    if(details.priceActionAgainst) details.totalScore += 1;
    if(details.volumeWeakness) details.totalScore += 1;
    if(details.trendReversal) details.totalScore += 2;
    if(details.confirmedBreak) details.totalScore += 2;
    
    if(details.totalScore > 0)
    {
        details.reason = "Invalidation signals: ";
        if(details.keyLevelBroken) details.reason += "[Key Level Broken] ";
        if(details.structureFlip) details.reason += "[Structure Flip] ";
        if(details.momentumFlip) details.reason += "[Momentum Flip] ";
        if(details.trendReversal) details.reason += "[Trend Reversal] ";
        if(details.priceActionAgainst) details.reason += "[Opposite Price Action] ";
        if(details.volumeWeakness) details.reason += "[Volume Against Position] ";
        if(details.confirmedBreak) details.reason += "[Confirmed Break] ";
    }
    
    return details;
}

int GetInvalidationScore(ulong ticket)
{
    InvalidationDetails details = GetDetailedInvalidationScore(ticket);
    return details.totalScore;
}

// +------------------------------------------------------------------+
// | Helper: Get Average Candle Body Size                             |
// +------------------------------------------------------------------+
double GetAverageCandleBody(int periods)
{
    double totalBody = 0;
    
    for(int i = 1; i <= periods; i++)
    {
        double openPrice = iOpen(_Symbol, _Period, i);
        double closePrice = iClose(_Symbol, _Period, i);
        totalBody += MathAbs(closePrice - openPrice);
    }
    
    return totalBody / periods;
}

// +------------------------------------------------------------------+
// | Hedge pair management functions                                  |
// +------------------------------------------------------------------+
void AddHedgePair(ulong originalTicket, ulong hedgeTicket)
{
    if(!PositionSelectByTicket(originalTicket)) return;
    
    double originalProfit = PositionGetDouble(POSITION_PROFIT);

    int size = ArraySize(activePairs);
    ArrayResize(activePairs, size + 1);
    
    activePairs[size].originalTicket = originalTicket;
    activePairs[size].hedgeTicket = hedgeTicket;
    activePairs[size].hedgeOpenTime = TimeCurrent();
    
    LogPrint("+-----------------------------------------+");
    LogPrint("HEDGE PAIR ADDED");
    LogPrint("Original Ticket: ", originalTicket, " | Hedge Ticket: ", hedgeTicket);
    LogPrint("Initial Combined P/L: $", originalProfit);
    LogPrint("Open Time: ", activePairs[size].hedgeOpenTime);
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
    
    LogPrint("Removing hedge pair at index ", index);
    
    activePairs[index] = activePairs[size - 1];
    ArrayResize(activePairs, size - 1);
}

bool IsPositionHedged(ulong ticket)
{
    int size = ArraySize(activePairs);
    for(int i = 0; i < size; i++)
    {
        if(activePairs[i].originalTicket == ticket || activePairs[i].hedgeTicket == ticket)
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
// | Main hedge management logic                                       |
// +------------------------------------------------------------------+
void ManageHedgedPositions()
{
    for(int i = ArraySize(activePairs) - 1; i >= 0; i--)
    {
        ulong originalTicket = activePairs[i].originalTicket;
        ulong hedgeTicket = activePairs[i].hedgeTicket;
        
        if(!PositionSelectByTicket(originalTicket))
        {
            LogPrint("Original position ", originalTicket, " no longer exists");
            RemoveHedgePair(i);
            continue;
        }
        
        if(!PositionSelectByTicket(hedgeTicket))
        {
            LogPrint("Hedge position ", hedgeTicket, " no longer exists");
            RemoveHedgePair(i);
            continue;
        }

        PositionSelectByTicket(originalTicket);
        double originalProfit = PositionGetDouble(POSITION_PROFIT);
        double originalVolume = PositionGetDouble(POSITION_VOLUME);
        
        PositionSelectByTicket(hedgeTicket);
        double hedgeProfit = PositionGetDouble(POSITION_PROFIT);
        double hedgeVolume = PositionGetDouble(POSITION_VOLUME);
        
        double combinedProfit = originalProfit + hedgeProfit;
        int hedgeDurationMinutes = (int)((TimeCurrent() - activePairs[i].hedgeOpenTime) / 60);
        
        LogPrint("+-----------------------------------------+");
        LogPrint("HEDGE PAIR STATUS");
        LogPrint("Original Ticket: ", originalTicket, " | Hedge Ticket: ", hedgeTicket);
        LogPrint("Combined Profit: $", combinedProfit, " | Duration: ", hedgeDurationMinutes, " min");
        LogPrint("+-----------------------------------------+");
        
        if (combinedProfit >= MinBreakEvenProfit)
        {
            LogPrint("RULE 1: Combined profit sufficient to exit hedge pair");
            bool isClosed1 = ClosePosition(originalTicket);
            bool isClosed2 = ClosePosition(hedgeTicket);
            if (isClosed1 || isClosed2) RemoveHedgePair(i);
            continue;
        }
        
        if(originalProfit >= MinBreakEvenProfit)
        {
            LogPrint("RULE 2: Original position recovered to profit/breakeven");
            bool isClosed = ClosePosition(hedgeTicket);
            if (isClosed) RemoveHedgePair(i);
            if (EnableTrailingStop) ManageTrailingStop(originalTicket);
            continue;
        }

        if(hedgeProfit >= MinBreakEvenProfit)
        {
            LogPrint("RULE 3: Hedge position sufficient to profit/breakeven");
            bool isClosed = ClosePosition(originalTicket);
            if (isClosed) RemoveHedgePair(i);
            if (EnableTrailingStop) ManageTrailingStop(hedgeTicket);
            continue;
        }
        
        if(MaxHedgeDurationMinutes > 0 && hedgeDurationMinutes >= MaxHedgeDurationMinutes)
        {
            LogPrint("RULE 4: Maximum hedge duration reached (", MaxHedgeDurationMinutes, " min)");
            bool isClosed1 = ClosePosition(originalTicket);
            bool isClosed2 = ClosePosition(hedgeTicket);
            if (isClosed1 || isClosed2) RemoveHedgePair(i);
            continue;
        }
        
        LogPrint("Hedge pair still active, monitoring...");
    }
}

// +------------------------------------------------------------------+
// | Open Pyramiding Position (Base Lot + Initial Profitable SL)      |
// +------------------------------------------------------------------+
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

    if(EnableTakeProfit)
    {
        double tpPoints = ConvertToPoints(TPInputType, TPValue, currentLot);
        
        if(orderType == ORDER_TYPE_BUY)
            request.tp = NormalizeDouble(price + (tpPoints * _Point), _Digits); 
        else
            request.tp = NormalizeDouble(price - (tpPoints * _Point), _Digits); 
    }
    
    long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    long minDistancePoints = MathMax(stopLevel, freezeLevel);

    double trailingDistancePoints = ConvertToPoints(TSInputType, TSValue, currentLot);
    double minDistancePrice = (minDistancePoints + trailingDistancePoints) * _Point; 
    
    if(orderType == ORDER_TYPE_BUY)
        request.sl = NormalizeDouble(price - minDistancePrice, _Digits);
    else
        request.sl = NormalizeDouble(price + minDistancePrice, _Digits);
    
    if(!IsSLValid((orderType == ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL), request.sl))
    {
        LogPrint("Pyramiding: Tightest Calculated SL invalid (", request.sl, "). Using Standard SL.");
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
             request.sl = 0;
        }
    }
    
    bool orderResult = OrderSend(request, result);
    
    if(orderResult)
    {
        if(result.retcode == TRADE_RETCODE_DONE)
            LogPrint("Pyramiding Order Opened. Ticket: ", result.order, ", SL: ", request.sl);
        else
            LogPrint("Pyramiding OrderSend failed. Retcode: ", result.retcode, " - ", result.comment);
    }
    else
    {
        LogPrint("Pyramiding OrderSend returned false. Error: ", GetLastError());
    }

    LockOrderSend(false);
}

// +------------------------------------------------------------------+
// | Manage Pyramiding for Winning Positions                          |
// +------------------------------------------------------------------+
void ManageWinningPositions(ulong ticket)
{
    if(!EnablePyramiding || MaxPyramidingPositions <= 0) return;

    if(!PositionSelectByTicket(ticket)) return;

    double profit = PositionGetDouble(POSITION_PROFIT);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

    if(profit < MinBreakEvenProfit * PyramidingThresholdMultiplier) return;

    int sameTypePositions = 0;
    ulong lastPositionTicket = 0;
    datetime lastPositionTime = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong t = PositionGetTicket(i);
        if(PositionSelectByTicket(t))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == posType)
                {
                    sameTypePositions++;
                    datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
                    if(openTime > lastPositionTime)
                    {
                        lastPositionTime = openTime;
                        lastPositionTicket = t;
                    }
                }
            }
        }
    }

    if(sameTypePositions >= MaxPyramidingPositions) return;
    if(ticket != lastPositionTicket) return;

    InvalidationDetails details = GetDetailedInvalidationScore(ticket);
    
    if(details.totalScore >= 5)
    {
        LogPrint("Pyramiding skipped: Invalidation score too high (", details.totalScore, ")");
        return;
    }

    LogPrint("+-----------------------------------------+");
    LogPrint("PYRAMIDING TRIGGERED");
    LogPrint("Base Ticket: ", ticket, " | Profit: $", profit);
    LogPrint("Positions: ", sameTypePositions, "/", MaxPyramidingPositions);
    LogPrint("Invalidation Score: ", details.totalScore);
    LogPrint("+-----------------------------------------+");
    
    ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    OpenPyramidingPosition(orderType);
}

// +------------------------------------------------------------------+
// | Main losing position management                                  |
// +------------------------------------------------------------------+
void ManageLosingPositions(ulong ticket)
{   
    if(IsPositionHedged(ticket)) return;
    
    if(ReverseCooldownMinutes > 0 && EnableAutoReverse)
    {
        if(TimeTradeServer() - lastReverseTime < ReverseCooldownMinutes * 60)
            return;
    }

    if(!PositionSelectByTicket(ticket))
    {
        LogPrint("Failed to select position by ticket: ", ticket);
        return;
    }

    double profit = PositionGetDouble(POSITION_PROFIT);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double volume = PositionGetDouble(POSITION_VOLUME);

    if(profit >= MinBreakEvenProfit) return;

    InvalidationDetails details = GetDetailedInvalidationScore(ticket);

    LogPrint("+-----------------------------------------+");
    LogPrint("POSITION INVALIDATION ANALYSIS");
    LogPrint("Ticket: ", ticket, " | Type: ", EnumToString(posType));
    LogPrint("Profit: $", profit, " | Volume: ", volume);
    LogPrint("TOTAL SCORE: ", details.totalScore, " / 13");
    LogPrint("REASON: ", details.reason);
    LogPrint("+-----------------------------------------+");

    if(details.totalScore >= 8 && EnableAutoReverse)
    {
        LogPrint("DECISION: STRONG INVALIDATION - REVERSING POSITION");
        
        lastReverseTime = TimeTradeServer();
        
        if(!ClosePosition(ticket))
        {
            LogPrint("Failed to close position for reversal");
            return;
        }
        
        if(posType == POSITION_TYPE_BUY && EnableSellOrders)
            OpenPosition(ORDER_TYPE_SELL);
        else if(posType == POSITION_TYPE_SELL && EnableBuyOrders)
            OpenPosition(ORDER_TYPE_BUY);
    }
    else if(details.totalScore >= 5 && EnableAutoHedge)
    {
        LogPrint("DECISION: MODERATE INVALIDATION - HEDGING POSITION");
        
        ENUM_ORDER_TYPE hedgeType = (posType == POSITION_TYPE_BUY) ? 
                                     ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        
        ulong hedgeTicket = OpenHedgePosition(hedgeType, volume);
        
        if(hedgeTicket > 0)
        {
            AddHedgePair(ticket, hedgeTicket);
            LogPrint("Hedge created successfully");
        }
        else
        {
            LogPrint("Failed to create hedge");
        }
    }
    else
    {
        LogPrint("DECISION: WEAK/NO INVALIDATION - MONITORING");
    }
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Manage trailing stop for open positions                          |
// +------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;

    double profit = PositionGetDouble(POSITION_PROFIT);

    if(TSOnProfitableOnly && profit <= MinBreakEvenProfit) return;
    
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

    if(posType == POSITION_TYPE_BUY)
    {
        double profitPoints = (currentPrice - entryPrice) / _Point;
        if(profitPoints < trailingDistancePoints) return;

        newSL = currentPrice - trailingDistancePrice;
        double maxAllowedSL = bid - minDistance;
        
        if(newSL > maxAllowedSL) newSL = maxAllowedSL;

        if(TSEnableBreakEvenLock && newSL < breakEvenPrice) newSL = breakEvenPrice;

        if(currentSL != 0 && newSL <= currentSL) return;
        if(newSL >= bid) return;
    }
    else
    {
        double profitPoints = (entryPrice - currentPrice) / _Point;
        if(profitPoints < trailingDistancePoints) return;

        newSL = currentPrice + trailingDistancePrice;
        double minAllowedSL = ask + minDistance;

        if(newSL < minAllowedSL) newSL = minAllowedSL;

        if(TSEnableBreakEvenLock && newSL > breakEvenPrice) newSL = breakEvenPrice;

        if(currentSL != 0 && newSL >= currentSL) return;
        if(newSL <= ask) return;
    }

    newSL = NormalizeDouble(newSL, _Digits);

    LogPrint("+-----------------------------------------+");
    LogPrint("TRAILING STOP MANAGEMENT");
    LogPrint("TICKET: ", ticket, " | Profit: $", profit);
    LogPrint("Current Price: ", currentPrice, " | Entry Price: ", entryPrice);
    LogPrint("Current SL: ", currentSL, " -> New SL: ", newSL);
    LogPrint("+-----------------------------------------+");

    if(!IsSLValid(posType, newSL))
    {
        LogPrint("SL too close / invalid, skipping modification. Ticket: ", ticket);
        return;
    }

    if(!ModifyPosition(ticket, newSL, currentTP))
    {
        LogPrint("SL modify failed. Ticket: ", ticket);
    }
}

// +------------------------------------------------------------------+
// | Open position with dynamic lot sizing AND fixed SL/TP            |
// +------------------------------------------------------------------+
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

    if(EnableTakeProfit)
    {
        double tpPoints = ConvertToPoints(TPInputType, TPValue, currentLot);
        
        if(orderType == ORDER_TYPE_BUY)
            request.tp = NormalizeDouble(price + (tpPoints * _Point), _Digits); 
        else
            request.tp = NormalizeDouble(price - (tpPoints * _Point), _Digits); 
    }
    
    if(EnableStopLoss)
    {
        double slPoints = ConvertToPoints(SLInputType, SLValue, currentLot);
        
        if(orderType == ORDER_TYPE_BUY)
            request.sl = NormalizeDouble(price - (slPoints * _Point), _Digits);
        else
            request.sl = NormalizeDouble(price + (slPoints * _Point), _Digits);
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

ulong OpenHedgePosition(ENUM_ORDER_TYPE type, double volume)
{
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
    json += "\"footer\":{\"text\":\"Nyao Scalper v34.0\"}";
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
    DrawDashboardLabel("NyaoDash_Title", "Nyao Scalper v34.0", startX, currentY, 11, colorHeader, true);
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

    // Market Data
    DrawDashboardLabel("NyaoDash_MktHead", "MARKET DATA:", startX, currentY, headersize, colorHeader, true);
    currentY += lineHeight;

    // RSI
    double currentRSI = 0;
    if(CopyBuffer(rsiHandle, 0, 0, 2, rsi) > 0)
        currentRSI = rsi[0];
    
    color rsiColor = colorText;
    if(currentRSI < SellRSIMin) rsiColor = colorSell;
    else if(currentRSI > BuyRSIMax) rsiColor = colorBuy;
    
    DrawDashboardLabel("NyaoDash_RSI", StringFormat("RSI(%d): %.1f", RSI_Period, currentRSI), startX, currentY, textsize, rsiColor);
    currentY += lineHeight;

    // Support & Resistance
    double support = GetSupport(1);
    double resistance = GetResistance(1);
    DrawDashboardLabel("NyaoDash_SR", StringFormat("S: %.2f | R: %.2f", support, resistance), startX, currentY, detailsSize, colorText);
    currentY += lineHeight;

    // Spread
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double spreadPoints = (ask - bid) / _Point;
    DrawDashboardLabel("NyaoDash_Spread", StringFormat("Spread: %.1f pts", spreadPoints), startX, currentY, detailsSize, colorText);
    currentY += lineHeight + 5;

    // Signals
    DrawDashboardLabel("NyaoDash_SigHead", "SIGNALS:", startX, currentY, headersize, colorHeader, true);
    currentY += lineHeight;
    
    bool buySignal = BuySignal();
    bool sellSignal = SellSignal();
    
    string buyText = buySignal ? "BUY: ACTIVE" : "BUY: -";
    DrawDashboardLabel("NyaoDash_Buy", buyText, startX, currentY, textsize, buySignal ? colorBuy : colorNeutral, buySignal);
    currentY += lineHeight;

    string sellText = sellSignal ? "SELL: ACTIVE" : "SELL: -";
    DrawDashboardLabel("NyaoDash_Sell", sellText, startX, currentY, textsize, sellSignal ? colorSell : colorNeutral, sellSignal);
    currentY += lineHeight;

    // Orders & Lot
    int openOrders = CountOpenOrders();
    double currentLot = CalculateDynamicLotSize();
    DrawDashboardLabel("NyaoDash_Orders", StringFormat("Orders: %d / %d | Lot: %.2f", openOrders, MaxOpenOrders, currentLot), startX, currentY, detailsSize, colorText);
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
