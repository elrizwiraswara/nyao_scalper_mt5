// +------------------------------------------------------------------+
// |                                          Nyao Scalper v12.0      |
// |              RSI with Reversal, Hedge & Pyramiding Strategy      |
// |              with Equity & Risk Management + Discord Alerts      |
// |                                    © Copyright Nyao Scalper      |
// +------------------------------------------------------------------+
#property copyright "© Copyright Nyao Scalper by Elriz Wiraswara"
#property version   "12.0"
#property description "Auto Trading EA Robot with Equity Management + Discord Alerts."
#property description "Do with your own risk. Results may vary based on market conditions."
#property strict

// Windows API for Algo Trading Button Control
#define MT_WMCMD_EXPERTS   32851
#define WM_COMMAND 0x0111
#define GA_ROOT    2
#include <WinAPI\winapi.mqh>

enum ENUM_INPUT_TYPE
{
    INPUT_DOLLAR,                                         // Dollar Amount
    INPUT_PERCENT,                                        // Percent of Equity
    INPUT_POINTS                                          // Points
};

input group "+-----------------------------------------+"
input group " Nyao Scalper v12.0"
input group "「結果が出ない努力はただの言い訳」"
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
input double PyramidingThresholdMultiplier = 1.5;         // Multiplier for MinBreakEvenProfit to Trigger Pyramiding

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
bool wasWithinTradingHours = true;                        // Track trading hours state for alerts
static ulong lastProcessedNewsEventID = 0;                // Last processed news event ID
string symbolBaseCurrency = "";                           // Base currency of the symbol
string symbolQuoteCurrency = "";                          // Quote currency of the symbol

// RSI Indicator Handle and Buffer
int rsiHandle;
double rsi[];

// Duplicate Signal Filter Variables
double lastBuyPrice = 0;
double lastSellPrice = 0;
int lastBuyBar = -1;
int lastSellBar = -1;
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
    json += "\"footer\":{\"text\":\"Nyao Scalper v12.0\"}";
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
        Print("Discord alert sent: ", title);
        return true;
    }
    else
    {
        Print("Discord ERROR: ", res);
        Print("Payload: ", json);
        Print("Response: ", CharArrayToString(result));
        Print("MT5 Error: ", GetLastError());
        return false;
    }
}

// +------------------------------------------------------------------+
// | Check and Test Discord Alert                                     |
// +------------------------------------------------------------------+
void CheckDiscordAlert() {
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
        // Get current equity
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

        string alertMsg = "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
        alertMsg += "**Trading Hours:** " + (EnableTradingHours ? TradingStartTime + " - " + TradingEndTime + "\n" : "DISABLED\n");
        alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
        alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
        alertMsg += "**News Filter:** " + (EnableNewsFilter ? "ENABLED" : "DISABLED") + "\n";
        alertMsg += "**Status:** Trading started successfully";
        
        SendDiscordAlert("🟢 AUTOMATED TRADING STARTED", alertMsg, 5763719); // Green color
    }
}

// +------------------------------------------------------------------+
// | Get Daily Statistics                                             |
// +------------------------------------------------------------------+
void GetDailyStats(int& dailyTrades, int& totalTrades, double& dailyProfit, double& totalProfit, double& dailyLoss, double& totalLoss) {
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

// +------------------------------------------------------------------+
// | Send Daily Report                                                |
// +------------------------------------------------------------------+
void SendDailyReport() {
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
    
    string timeFrameStr = EnumToString(_Period);
    StringReplace(timeFrameStr, "PERIOD_", "");

    string alertMsg = "**Instrument:** " + _Symbol + "\n";
    alertMsg += "**Timeframe:** " + timeFrameStr + "\n";
    alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n\n";
    
    alertMsg += "**Equity Info**\n";
    alertMsg += "• Peak Equity: $" + DoubleToString(peakEquity, 2) + "\n";
    alertMsg += "• Current Equity: $" + DoubleToString(currentEquity, 2) + "\n\n";
    
    alertMsg += "**Daily Stats**\n";
    alertMsg += "• Trades: " + IntegerToString(dailyTrades) + "\n";
    alertMsg += "• Profit: $" + DoubleToString(dailyProfit, 2) + "\n";
    alertMsg += "• Loss: $" + DoubleToString(dailyLoss, 2) + "\n\n";
    
    alertMsg += "**Total Stats**\n";
    alertMsg += "• Trades: " + IntegerToString(totalTrades) + "\n";
    alertMsg += "• Profit: $" + DoubleToString(totalProfit, 2) + "\n";
    alertMsg += "• Loss: $" + DoubleToString(totalLoss, 2) + "\n\n";
    
    alertMsg += "**⏱Duration:** " + durationStr;
    
    SendDiscordAlert("📅 DAILY TRADE REPORT", alertMsg, 16776960); // Yellow/Gold color
    
    lastDailyReportTime = TimeCurrent();
}

// +------------------------------------------------------------------+
// | Expert initialization function                                   |
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
    wasWithinTradingHours = IsWithinTradingHours();
    lastProcessedNewsEventID = 0;
    startTime = TimeCurrent();
    lastDailyReportTime = 0;
    symbolBaseCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
    symbolQuoteCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
    
    Print("+-----------------------------------------+");
    Print("Nyao Scalper v12.0 Initialized Successfully");
    Print("+-----------------------------------------+");

    if(EnableDiscordAlerts) CheckDiscordAlert();
    
    return(INIT_SUCCEEDED);
}

// +------------------------------------------------------------------+
// | Expert deinitialization function                                 |
// +------------------------------------------------------------------+
void OnDeinit(const int reason)
{   
    if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);

    ArrayFree(rsi);
    ArrayFree(activePairs);
    
    Print("Nyao Scalper EA Deinitialized");
}

// +------------------------------------------------------------------+
// | Expert tick function - NOW CHECKS SIGNALS ON EVERY TICK          |
// +------------------------------------------------------------------+
void OnTick()
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

        Print("New Peak Equity reached: $", peakEquity);
        
        // Reset pause if equity recovered above peak
        if(isPaused)
        {
            isPaused = false;
            Print("Trading RESUMED - Equity recovered above peak!");
        }
    }
    
    // Check if target equity reached
    if(TargetEquity > 0 && !targetEquityReached && currentEquity >= TargetEquity)
    {
        targetEquityReached = true;
        Print("+-----------------------------------------+");
        Print("TARGET EQUITY REACHED!");
        Print("Current Equity: $", currentEquity);
        Print("Target Equity: $", TargetEquity);
        Print("Closing ALL positions and stopping trading...");
        Print("+-----------------------------------------+");
        
        // Send Discord alert for target equity reached
        if(EnableDiscordAlerts)
        {
            string alertMsg = "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Target Equity:** $" + DoubleToString(TargetEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Profit:** $" + DoubleToString(TargetEquity - initialBalance, 2) + "\n";
            alertMsg += "**Status:** All positions closed, trading stopped";
            
            SendDiscordAlert("🎯 TARGET EQUITY REACHED!", alertMsg, 5763719); // Green color
        }

        Alert("TARGET EQUITY REACHED! Closing all positions and stopping trading.");
        
        CloseAllPositions();

        DisableAlgoTrading();
        return;
    }

    // Check if minimum equity reached
    if(MinimumEquity > 0 && !minimumEquityReached && currentEquity <= MinimumEquity)
    {
        minimumEquityReached = true;
        Print("+-----------------------------------------+");
        Print("MINIMUM TRADEABLE EQUITY REACHED!");
        Print("Current Equity: $", currentEquity);
        Print("Minimum Equity: $", MinimumEquity);
        Print("Closing ALL positions and stopping trading...");
        Print("+-----------------------------------------+");
        
        // Send Discord alert for minimum equity reached
        if(EnableDiscordAlerts)
        {
            string alertMsg = "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "**Minimum Equity:** $" + DoubleToString(MinimumEquity, 2) + "\n";
            alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "**Loss:** $" + DoubleToString(initialBalance - currentEquity, 2) + "\n";
            alertMsg += "**Status:** All positions closed, trading stopped";
            
            SendDiscordAlert("🔴 MINIMUM TRADEABLE EQUITY REACHED", alertMsg, 15158332); // Red color
        }

        Alert("MINIMUM TRADEABLE EQUITY REACHED! Closing all positions and stopping trading.");
        
        CloseAllPositions();

        DisableAlgoTrading();
        return;
    }
    
    if(targetEquityReached || minimumEquityReached || minEquityTriggersExceeded) return;
    
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
                Print("+-----------------------------------------+" );
                Print("MAX MIN EQUITY TRIGGERS EXCEEDED!");
                Print("Triggers Used: ", minEquityTriggerCount, " / ", MaxMinEquityTriggers);
                Print("Closing ALL positions and STOPPING TRADING...");
                Print("+-----------------------------------------+" );
                
                if(EnableDiscordAlerts)
                {
                    string alertMsg = "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                    alertMsg += "**Peak Equity:** $" + DoubleToString(lastPeakEquity, 2) + "\n";
                    alertMsg += "**Triggers Used:** " + IntegerToString(minEquityTriggerCount) + " / " + IntegerToString(MaxMinEquityTriggers) + "\n";
                    alertMsg += "**Status:** All positions closed, trading stopped";
                    
                    SendDiscordAlert("🔴 MAX MIN EQUITY TRIGGERS EXCEEDED", alertMsg, 15158332); // Red color
                }

                Alert("MAX MIN EQUITY TRIGGERS EXCEEDED! Closing all positions and stopping trading.");
                
                CloseAllPositions();

                DisableAlgoTrading();
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
            
            Print("+-----------------------------------------+");
            Print("EQUITY PROTECTION TRIGGERED!");
            Print("Current Equity: $", currentEquity);
            Print("Peak Equity: $", peakEquity);
            Print("Old Peak Equity: $", oldPeakEquity);
            Print("New Peak Equity (Balance): $", lastPeakEquity);
            Print("Min Allowed (", MinEquityPercent, "%): $", minAllowedEquity);
            Print("Closing unprofitable positions...");
            Print("Trading PAUSED for ", currentPauseDuration, " minutes");
            Print("Resume Time: ", TimeToString(pauseStartTime + currentPauseDuration * 60));
            Print("+-----------------------------------------+");
            
            // Send Discord alert for minimum equity reached
            if(EnableDiscordAlerts)
            {
                string alertMsg = "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
                alertMsg += "**Previous Peak:** $" + DoubleToString(oldPeakEquity, 2) + "\n";
                alertMsg += "**New Peak (Balance):** $" + DoubleToString(lastPeakEquity, 2) + "\n";
                alertMsg += "**Equity Drop:** $" + DoubleToString(equityDrop, 2) + " (" + DoubleToString(equityDropPercent, 2) + "%)\n";
                alertMsg += "**Min Allowed (" + DoubleToString(MinEquityPercent, 0) + "%):** $" + DoubleToString(minAllowedEquity, 2) + "\n";
                alertMsg += "**Trading Paused:** " + IntegerToString(currentPauseDuration) + " minutes\n";
                alertMsg += "**Resume Time:** " + TimeToString(pauseStartTime + currentPauseDuration * 60) + "\n";
                alertMsg += "**Action:** Trading Paused & Closing unprofitable positions...";
                
                SendDiscordAlert("⚠️ MINIMUM EQUITY PROTECTION TRIGGERED", alertMsg, 16705372); // Yellow color
            }

            CloseAllPositions(true); // Close only unprofitable positions
        }
    }

    // Check for high-impact news events
    if(EnableNewsFilter)
    {   
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
            
            Print("+-----------------------------------------+");
            Print("HIGH-IMPACT NEWS EVENT DETECTED!");
            Print("Server Time: ", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS));
            Print("Current Equity: $", currentEquity);
            Print("Trading PAUSED for ", currentPauseDuration, " minutes");
            Print("Resume Time: ", TimeToString(pauseStartTime + currentPauseDuration * 60));
            Print("+-----------------------------------------+");
            
            // Send Discord alert with full event details
            if(EnableDiscordAlerts)
            {
                // Add event details
                string alertMsg =  newsDetails + "\n\n";
                
                // Add trading info
                alertMsg += "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
                alertMsg += "**Trading Paused:** " + IntegerToString(currentPauseDuration) + " minutes\n";
                alertMsg += "**Resume Time:** " + TimeToString(pauseStartTime + currentPauseDuration * 60) + "\n";
                alertMsg += "**Action:** Trading paused during news period & closing unprofitable positions...";
                
                SendDiscordAlert("⚠️ HIGH-IMPACT NEWS DETECTED!", alertMsg, 16705372); // Yellow color
            }
            
            CloseAllPositions(true); // Close only unprofitable positions
        }
    }

    // Check if current time is within allowed trading hours
    if(EnableTradingHours)
    {
        bool currentlyWithinHours = IsWithinTradingHours();
        
        // Check for transition from outside to inside trading hours (Trading Started)
        if(!wasWithinTradingHours && currentlyWithinHours)
        {
            wasWithinTradingHours = true;
            
            Print("+-----------------------------------------+");
            Print("TRADING HOURS STARTED");
            Print("Server Time: ", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS));
            Print("Trading Period: ", TradingStartTime, " - ", TradingEndTime);
            Print("Current Equity: $", currentEquity);
            Print("+-----------------------------------------+");
            
            // Send Discord alert for trading started
            if(EnableDiscordAlerts)
            {
                string alertMsg = "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                alertMsg += "**Trading Period:** " + TradingStartTime + " - " + TradingEndTime + "\n";
                alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
                alertMsg += "**Status:** Now accepting new trading signals";
                
                SendDiscordAlert("🟢 TRADING HOURS STARTED!", alertMsg, 5763719); // Green color
            }
        }
        
        // Check for transition from inside to outside trading hours (Trading Stopped)
        if(wasWithinTradingHours && !currentlyWithinHours)
        {
            wasWithinTradingHours = false;
            
            Print("+-----------------------------------------+");
            Print("TRADING HOURS ENDED");
            Print("Server Time: ", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS));
            Print("Trading Period: ", TradingStartTime, " - ", TradingEndTime);
            Print("Current Equity: $", currentEquity);
            Print("+-----------------------------------------+");
            
            // Send Discord alert for trading stopped
            if(EnableDiscordAlerts)
            {
                string alertMsg = "**Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                alertMsg += "**Trading Period:** " + TradingStartTime + " - " + TradingEndTime + "\n";
                alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
                alertMsg += "⏸**Status:** No new positions until next trading session";
                
                
                SendDiscordAlert("🔴 TRADING HOURS ENDED!", alertMsg, 15158332); // Red color
                
                // Send Daily Report
                SendDailyReport();
            }
        }
        
        // If currently outside trading hours, prevent new trades
        if(!currentlyWithinHours)
        {
            static datetime lastTradingHoursLog = 0;
            
            // Log only once per minute to avoid spam
            if(TimeTradeServer() - lastTradingHoursLog > 60)
            {
                Print("[OUTSIDE TRADING HOURS] Current time: ", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS), 
                      " | Allowed: ", TradingStartTime, " - ", TradingEndTime);
                lastTradingHoursLog = TimeTradeServer();
            }
            
            // Don't open new positions, but continue managing existing ones
            ManagePositions();
            return;
        }
    }
    
    // Check for End of Day Report (if Trading Hours Disabled or missed)
    // We check if we crossed the day boundary or if it is 23:59
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

    // Check pause duration 
    if(isPaused)
    {
        datetime currentTime = TimeTradeServer();
        int elapsedSeconds = (int)(currentTime - pauseStartTime);
        int pauseDurationSeconds = currentPauseDuration * 60;
        
        if(elapsedSeconds < pauseDurationSeconds)
        {
            // Still in pause period - close unprofitable positions and prevent ALL trading
            CloseAllPositions(true); // Close only unprofitable positions
            Print("[PAUSED] Paused. Time remaining: ", (pauseDurationSeconds - elapsedSeconds) / 60, " minute(s)");
            return;  // EXIT - prevent all new orders while paused
        }
        else
        {
            // Pause period ended - reset flag and resume trading
            isPaused = false;
            Print("+-----------------------------------------+");
            Print("PAUSE PERIOD ENDED");
            Print("Trading RESUMED after ", currentPauseDuration, " minutes");
            Print("Current Equity: $", currentEquity);
            Print("+-----------------------------------------+");
            
            // Send Discord alert for trading resumed
            if(EnableDiscordAlerts)
            {
                string alertMsg = "**Pause Duration:** " + IntegerToString(currentPauseDuration) + " minutes\n";
                alertMsg += "**Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "**Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
                alertMsg += "**Status:** Monitoring for new trading signals...";
                
                SendDiscordAlert("▶️ TRADING RESUMED!", alertMsg, 3066993); // Blue color
            }
        }
    }
    
    // Manage existing positions
    ManagePositions();

    // Check for trading signals - ON EVERY TICK
    int currentOrders = CountOpenOrders();
    
    if(currentOrders < MaxOpenOrders)
    {
        CheckForTradingSignal();
    } 
    else
    {
        Print("Max open orders reached (", currentOrders, "/", MaxOpenOrders, "). No new orders will be placed.");
    }
}

// +------------------------------------------------------------------+
// | Candle Utils                                                     |
// +------------------------------------------------------------------+
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
   double l2 = iLow(_Symbol,_Period, 2);
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
   static datetime lastBuyCandleTime = 0;
   datetime currentCandleTime = iTime(_Symbol, _Period, 0);

   if(lastBuyCandleTime == currentCandleTime) return false;

   if(MathAbs(price - lastBuyPrice) < ZonePoints * _Point * BuyDuplicateMultiplier) return false;

   return true;
}

bool AllowNewSell(double price)
{
   static datetime lastSellCandleTime = 0;
   datetime currentCandleTime = iTime(_Symbol, _Period, 0);

   if(lastSellCandleTime == currentCandleTime) return false;

   if(MathAbs(price - lastSellPrice) < ZonePoints * _Point * SellDuplicateMultiplier) return false;

   return true;
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Buy Signal                                                       |
// +------------------------------------------------------------------+
bool BuySignal()
{
   CopyBuffer(rsiHandle, 0, 0, 3, rsi);

   double close1  = iClose(_Symbol, _Period, 1);
   double support = GetSupport(1);

   bool nearSupport = MathAbs(close1 - support) <= ZonePoints * _Point;

   if(!IsTradableCandle(1)) return false;

   if(
      nearSupport &&
      rsi[1] < BuyRSIMax &&                     
      (HigherLow() || FakeBreakBuy(support) || iClose(_Symbol, _Period, 1) > iOpen(_Symbol,_Period, 1)) &&
      AllowNewBuy(close1)
     )
   {
      lastBuyPrice = close1;
      lastBuyBar = iBars(_Symbol, _Period);
      return true;
   }

   return false;
}

// +------------------------------------------------------------------+
// | Sell Signal                                                      |
// +------------------------------------------------------------------+
bool SellSignal()
{
   CopyBuffer(rsiHandle, 0, 0, 3, rsi);

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
      lastSellBar = iBars(_Symbol, _Period);
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
        Print("ERROR: Failed to calculate margin: ", GetLastError());
        return minLot;
    }

    double availableMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

    if(marginNeeded > availableMargin)
    {
        double symbolLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        double maxAffordableLot = minLot;
        double testMargin = 0;  
        
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
            Print("WARNING: Insufficient margin. Required: $", marginNeeded, 
                  ", Available: $", availableMargin);
            return minLot;
        }
        
        Print("WARNING: Reduced lot from calculated to affordable: ", currentLot, 
              " (Required margin: $", marginNeeded, ", Available: $", availableMargin, ")");
    }
    
    return currentLot;
}

// +------------------------------------------------------------------+
// | Close all positions regardless of profit/loss                   |
// +------------------------------------------------------------------+
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

                Print("Closing position. Ticket: ", ticket, ", Profit/Loss: $", profit);

                if(ClosePosition(ticket))
                {
                    closedCount++;
                    Print("Position closed successfully: ", ticket);
                }
                else
                {
                    Print("ERROR: Failed to close position: ", ticket, ". Error: ", GetLastError());
                }
            }
        }
    }
    
    if(closedCount > 0)
    {
        Print("Total positions closed: ", closedCount);
    }
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
// | Check for trading signals                                        |
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
        Print("BUY signal accepted at price: ", currentAsk);
    }

    // Process SELL signals
    if(sellSignal && EnableSellOrders)
    {
        OpenPosition(ORDER_TYPE_SELL);
        Print("SELL signal accepted at price: ", currentBid);
    }
}

// +------------------------------------------------------------------+
// | Open position with dynamic lot sizing AND fixed SL/TP            |
// +------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
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
            
            Print("Order opened successfully. Ticket: ", result.order, 
                  ", Type: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL",
                  ", Lot Size: ", currentLot,
                  " (Peak: $", lastPeakEquity, 
                  ", Current: $", currentEquity,
                  ", Drop: ", equityDropPercentage, "%)");
            
            if(EnableStopLoss)
            {
                Print("  SL: ", request.sl);
            }
            if(EnableTakeProfit)
            {
                Print("  TP: ", request.tp);
            }
        }
        else
        {
            Print("Order failed. Return code: ", result.retcode);
        }
    }
    else
    {
        Print("OrderSend error: ", GetLastError());
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
                    Print("Position ", ticket, " is hedged, skipping individual management");
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
        Print("Failed to get price data for structure flip check");
        return false;
    }
    
    if(type == POSITION_TYPE_BUY)
    {
        // For BUY: Look for lower high + bearish candle + consecutive bearish structure
        bool lowerHigh = LowerHigh();
        bool bearishCandle = close1 < open1;
        bool consecutiveBearish = (close1 < open1) && (close2 < open2); // 2 bearish in a row
        
        // Stronger confirmation if candle body is significant
        double candleBody = MathAbs(close1 - open1);
        double avgCandleBody = GetAverageCandleBody(10); // Last 10 candles
        bool significantBearishBody = (candleBody > avgCandleBody * 0.7);
        
        return lowerHigh && bearishCandle && (consecutiveBearish || significantBearishBody);
    }

    if(type == POSITION_TYPE_SELL)
    {
        // For SELL: Look for higher low + bullish candle + consecutive bullish structure
        bool higherLow = HigherLow();
        bool bullishCandle = close1 > open1;
        bool consecutiveBullish = (close1 > open1) && (close2 > open2); // 2 bullish in a row
        
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
        Print("Failed to copy RSI buffer, error: ", GetLastError());
        return false;
    }

    // Calculate dynamic thresholds based on input parameters
    double buyInvalidationLevel = 50 - (BuyRSIMax - 50) * 0.5;  // Mirror of BuyRSIMax
    double sellInvalidationLevel = 50 + (50 - SellRSIMin) * 0.5; // Mirror of SellRSIMin

    if(type == POSITION_TYPE_BUY)
    {
        // BUY invalidation: RSI dropping below dynamic threshold
        bool rsiWeak = rsi[1] < buyInvalidationLevel;
        bool rsiDeclining = (rsi[1] < rsi[2]) && (rsi[2] < rsi[3]); // 3-bar decline
        
        // Also invalidate if RSI crosses above the overbought level (opposite of entry)
        bool rsiOverbought = rsi[1] > BuyRSIMax;
        
        return (rsiWeak && rsiDeclining) || (rsi[1] < buyInvalidationLevel - 10) || rsiOverbought;
    }

    if(type == POSITION_TYPE_SELL)
    {
        // SELL invalidation: RSI rising above dynamic threshold
        bool rsiStrong = rsi[1] > sellInvalidationLevel;
        bool rsiRising = (rsi[1] > rsi[2]) && (rsi[2] > rsi[3]); // 3-bar rise
        
        // Also invalidate if RSI crosses below the oversold level (opposite of entry)
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
        Print("Failed to get close price for key level check");
        return false;
    }

    if(type == POSITION_TYPE_BUY)
    {
        double support = GetSupport(1);
        if(support <= 0) return false;
        
        // More robust: Check if price decisively broke support
        bool currentBelowSupport = close1 < support;
        bool previousBelowSupport = close2 < support;
        bool decisiveBreak = (support - close1) > (ZonePoints * _Point * 0.5); // 50% of zone
        
        // Confirmed break if 2 consecutive closes below OR a decisive break
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
        // Count consecutive bearish candles
        int bearishCount = 0;
        if(close1 < open1) bearishCount++;
        if(close2 < open2) bearishCount++;
        if(close3 < open3) bearishCount++;
        
        // 2+ consecutive bearish candles against BUY
        return bearishCount >= 2;
    }
    
    if(type == POSITION_TYPE_SELL)
    {
        // Count consecutive bullish candles
        int bullishCount = 0;
        if(close1 > open1) bullishCount++;
        if(close2 > open2) bullishCount++;
        if(close3 > open3) bullishCount++;
        
        // 2+ consecutive bullish candles against SELL
        return bullishCount >= 2;
    }
    
    return false;
}

// +------------------------------------------------------------------+
// | 5. Volume Weakness Detection                                     |
// +------------------------------------------------------------------+
bool VolumeWeaknessDetected(ENUM_POSITION_TYPE type)
{
    // Get tick volumes (MT5 doesn't have true volume on Forex)
    long volume1 = iVolume(_Symbol, _Period, 1);
    long volume2 = iVolume(_Symbol, _Period, 2);
    long volume3 = iVolume(_Symbol, _Period, 3);
    
    if(volume1 <= 0) return false; // No volume data
    
    double avgVolume = (volume1 + volume2 + volume3) / 3.0;
    
    double close1 = iClose(_Symbol, _Period, 1);
    double open1 = iOpen(_Symbol, _Period, 1);
    
    if(type == POSITION_TYPE_BUY)
    {
        // BUY losing momentum if bearish candle has high volume
        bool bearishCandle = close1 < open1;
        bool highVolume = volume1 > avgVolume * 1.2;
        
        return bearishCandle && highVolume;
    }
    
    if(type == POSITION_TYPE_SELL)
    {
        // SELL losing momentum if bullish candle has high volume
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
    // Get fast and slow EMAs for trend detection
    double emaFast[];
    double emaSlow[];
    ArraySetAsSeries(emaFast, true);
    ArraySetAsSeries(emaSlow, true);
    
    // You'll need to create these handles in OnInit()
    // int emaFastHandle = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
    // int emaSlowHandle = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
    
    // For now, use simple price vs MA check
    double close1 = iClose(_Symbol, _Period, 1);
    double close5 = iClose(_Symbol, _Period, 5);
    
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
        // BUY invalidated if price crosses below MA
        bool priceBelowMA = close1 < sma20_current;
        bool maTurningDown = sma20_current < sma20_previous;
        
        return priceBelowMA && maTurningDown;
    }
    
    if(type == POSITION_TYPE_SELL)
    {
        // SELL invalidated if price crosses above MA
        bool priceAboveMA = close1 > sma20_current;
        bool maTurningUp = sma20_current > sma20_previous;
        
        return priceAboveMA && maTurningUp;
    }
    
    return false;
}

// +------------------------------------------------------------------+
// | Confirmed Break Detection (Opposite of Fake Break)               |
// +------------------------------------------------------------------+
bool ConfirmedBreakAgainstPosition(ENUM_POSITION_TYPE type)
{
    double close1 = iClose(_Symbol, _Period, 1);
    double close2 = iClose(_Symbol, _Period, 2);
    double open1  = iOpen(_Symbol, _Period, 1);
    
    if(type == POSITION_TYPE_BUY)
    {
        double support = GetSupport(1);
        
        // Confirmed break: Close below support with body (not just wick)
        bool closeBelowSupport = close1 < support;
        bool previousCloseBelowSupport = close2 < support;
        bool bodyBelowSupport = (MathMax(open1, close1)) < support;
        
        // Unlike fake break, this is a REAL break - candle body is below support
        return closeBelowSupport && (previousCloseBelowSupport || bodyBelowSupport);
    }
    
    if(type == POSITION_TYPE_SELL)
    {
        double resistance = GetResistance(1);
        
        // Confirmed break: Close above resistance with body (not just wick)
        bool closeAboveResistance = close1 > resistance;
        bool previousCloseAboveResistance = close2 > resistance;
        bool bodyAboveResistance = (MathMin(open1, close1)) > resistance;
        
        // Unlike fake break, this is a REAL break - candle body is above resistance
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
    
    // Check all invalidation conditions
    details.structureFlip = StructureFlipAgainstPosition(posType);
    details.momentumFlip = MomentumFlipAgainstPosition(posType);
    details.keyLevelBroken = KeyLevelBroken(posType);
    details.priceActionAgainst = PriceActionAgainstPosition(posType);
    details.volumeWeakness = VolumeWeaknessDetected(posType);
    details.trendReversal = TrendReversalDetected(posType);
    details.confirmedBreak = ConfirmedBreakAgainstPosition(posType);
    
    // Calculate weighted score (some signals are stronger than others)
    if(details.structureFlip) details.totalScore += 2;      // Weight: 2
    if(details.momentumFlip) details.totalScore += 2;       // Weight: 2
    if(details.keyLevelBroken) details.totalScore += 3;     // Weight: 3 (strongest)
    if(details.priceActionAgainst) details.totalScore += 1; // Weight: 1
    if(details.volumeWeakness) details.totalScore += 1;     // Weight: 1
    if(details.trendReversal) details.totalScore += 2;      // Weight: 2
    if(details.confirmedBreak) details.totalScore += 2;     // Weight: 2 (mirrors fake break)
    
    // Build detailed reason string
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

// Simple version (backward compatible)
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
        double open = iOpen(_Symbol, _Period, i);
        double close = iClose(_Symbol, _Period, i);
        totalBody += MathAbs(close - open);
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
    
    Print("+-----------------------------------------+");
    Print("HEDGE PAIR ADDED");
    Print("Original Ticket: ", originalTicket, " | Hedge Ticket: ", hedgeTicket);
    Print("Initial Combined P/L: $", originalProfit);
    Print("Open Time: ", activePairs[size].hedgeOpenTime);
    Print("+-----------------------------------------+");
}

void RemoveHedgePair(int index)
{
    int size = ArraySize(activePairs);
    if(index < 0 || index >= size)
    {
        Print("RemoveHedgePair: invalid index ", index, ", size=", size);
        return;
    }
    
    Print("Removing hedge pair at index ", index);
    
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
        
        // Check if positions still exist
        if(!PositionSelectByTicket(originalTicket))
        {
            Print("Original position ", originalTicket, " no longer exists");
            RemoveHedgePair(i);
            continue;
        }
        
        if(!PositionSelectByTicket(hedgeTicket))
        {
            Print("Hedge position ", hedgeTicket, " no longer exists");
            RemoveHedgePair(i);
            continue;
        }

        // Get current P&L
        PositionSelectByTicket(originalTicket);
        double originalProfit = PositionGetDouble(POSITION_PROFIT);
        double originalVolume = PositionGetDouble(POSITION_VOLUME);
        
        PositionSelectByTicket(hedgeTicket);
        double hedgeProfit = PositionGetDouble(POSITION_PROFIT);
        double hedgeVolume = PositionGetDouble(POSITION_VOLUME);
        
        double combinedProfit = originalProfit + hedgeProfit;
        int hedgeDurationMinutes = (int)((TimeCurrent() - activePairs[i].hedgeOpenTime) / 60);
        
        Print("+-----------------------------------------+");
        Print("HEDGE PAIR STATUS");
        Print("Original Ticket: ", originalTicket, " | Hedge Ticket: ", hedgeTicket);
        Print("Original Volume: ", originalVolume, " | Hedge Volume: ", hedgeVolume);
        Print("Original Profit: $", originalProfit, " | Hedge Profit: $", hedgeProfit);
        Print("Combined Profit: $", combinedProfit, " | Duration: ", hedgeDurationMinutes, " min");
        Print("+-----------------------------------------+");
        
        // RULE 1: Combined profit sufficient to exit hedge pair
        if (combinedProfit >= MinBreakEvenProfit)
        {
            Print("RULE 1: Combined profit sufficient to exit hedge pair");
            Print("Combined profit: $", combinedProfit);
            Print("Close to both positions to lock in profit/breakeven");

            bool isClosed1 = ClosePosition(originalTicket);
            bool isClosed2 = ClosePosition(hedgeTicket);

            if (isClosed1 || isClosed2) RemoveHedgePair(i);
            continue;
        }
        
        // RULE 2: Original position recovered
        if(originalProfit >= MinBreakEvenProfit)
        {
            Print("RULE 2: Original position recovered to profit/breakeven");
            Print("Closing hedge, keeping original");

            bool isClosed = ClosePosition(hedgeTicket);
            if (isClosed) RemoveHedgePair(i);
            if (EnableTrailingStop) ManageTrailingStop(originalTicket);
            continue;
        }

        // RULE 3: Hedge position sufficient
        if(hedgeProfit >= MinBreakEvenProfit)
        {
            Print("RULE 3: Hedge position sufficient to to profit/breakeven");
            Print("Closing original, keeping hedge");

            bool isClosed = ClosePosition(originalTicket);
            if (isClosed) RemoveHedgePair(i);
            if (EnableTrailingStop) ManageTrailingStop(hedgeTicket);
            continue;
        }
        
        // RULE 4: Maximum time limit reached
        if(MaxHedgeDurationMinutes > 0 && hedgeDurationMinutes >= MaxHedgeDurationMinutes)
        {
            Print("RULE 4: Maximum hedge duration reached (", MaxHedgeDurationMinutes, " min)");
            Print("Closing both positions to prevent prolonged exposure");

            bool isClosed1 = ClosePosition(originalTicket);
            bool isClosed2 = ClosePosition(hedgeTicket);

            if (isClosed1 || isClosed2) RemoveHedgePair(i);
            continue;
        }
        
        Print("Hedge pair still active, monitoring...");
    }
}

// +------------------------------------------------------------------+
// | Open Pyramiding Position (Base Lot + Initial Profitable SL)      |
// +------------------------------------------------------------------+
void OpenPyramidingPosition(ENUM_ORDER_TYPE orderType)
{
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
        Print("Pyramiding: Tightest Calculated SL invalid (", request.sl, "). Using Standard SL.");
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
            Print("Pyramiding Order Opened. Ticket: ", result.order, ", SL: ", request.sl);
        }
        else
        {
            Print("Pyramiding OrderSend failed. Retcode: ", result.retcode, " - ", result.comment);
        }
    }
    else
    {
        Print("Pyramiding OrderSend returned false. Error: ", GetLastError());
    }
}

// +------------------------------------------------------------------+
// | Manage Pyramiding for Winning Positions                          |
// +------------------------------------------------------------------+
void ManageWinningPositions(ulong ticket)
{
    // Skip if pyramiding is disabled
    if(!EnablePyramiding || MaxPyramidingPositions <= 0) return;

    if(!PositionSelectByTicket(ticket)) return;

    double profit = PositionGetDouble(POSITION_PROFIT);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double volume = PositionGetDouble(POSITION_VOLUME);

    // 1. Check if profitable enough to strict pyramiding threshold
    // Threshold = MinBreakEvenProfit * PyramidingThresholdMultiplier
    if(profit < MinBreakEvenProfit * PyramidingThresholdMultiplier) return;

    // 2. Check total positions count
    int totalPositions = 0;
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
                totalPositions++;
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

    // 3. Ensure we are only pyramiding from the LATEST position
    // This prevents multiple triggers from older positions
    if(ticket != lastPositionTicket) return;

    // 4. Validate trend safety using InvalidationScore
    // We only pyramid if the trend is HEALTHY (Score < 5)
    // If Score >= 5 (Moderate/Strong invalidation), we do NOT pyramid
    InvalidationDetails details = GetDetailedInvalidationScore(ticket);
    
    if(details.totalScore >= 5)
    {
        Print("Pyramiding skipped: Invalidation score too high (", details.totalScore, ")");
        return;
    }

    // 5. Open Pyramiding Position
    Print("+-----------------------------------------+");
    Print("PYRAMIDING TRIGGERED");
    Print("Base Ticket: ", ticket, " | Profit: $", profit);
    Print("Positions: ", sameTypePositions, "/", MaxPyramidingPositions);
    Print("Invalidation Score: ", details.totalScore);
    Print("+-----------------------------------------+");
    
    ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    
    // Use OpenPyramidingPosition to ensure BaseLotSize and Initial Profitable SL attempt
    OpenPyramidingPosition(orderType);
}

// +------------------------------------------------------------------+
// | Main losing position management                                  |
// +------------------------------------------------------------------+
void ManageLosingPositions(ulong ticket)
{   
    // Skip if already hedged
    if(IsPositionHedged(ticket)) return;
    
    // Check cooldown
    if(ReverseCooldownMinutes > 0 && EnableAutoReverse)
    {
        if(TimeTradeServer() - lastReverseTime < ReverseCooldownMinutes * 60)
            return;
    }

    if(!PositionSelectByTicket(ticket))
    {
        Print("Failed to select position by ticket: ", ticket);
        return;
    }

    double profit = PositionGetDouble(POSITION_PROFIT);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double volume = PositionGetDouble(POSITION_VOLUME);

    // Only manage losing positions
    if(profit >= MinBreakEvenProfit) return;

    // Get detailed invalidation analysis
    InvalidationDetails details = GetDetailedInvalidationScore(ticket);

    Print("+-----------------------------------------+");
    Print("POSITION INVALIDATION ANALYSIS");
    Print("Ticket: ", ticket, " | Type: ", EnumToString(posType));
    Print("Profit: $", profit, " | Volume: ", volume);
    Print("+-----------------------------------------+");
    Print("SIGNALS DETECTED:");
    Print("[", details.structureFlip ? "✓" : " ", "] Structure Flip (Weight: 2)");
    Print("[", details.momentumFlip ? "✓" : " ", "] Momentum Flip (Weight: 2)");
    Print("[", details.keyLevelBroken ? "✓" : " ", "] Key Level Broken (Weight: 3)");
    Print("[", details.priceActionAgainst ? "✓" : " ", "] Price Action Against (Weight: 1)");
    Print("[", details.volumeWeakness ? "✓" : " ", "] Volume Weakness (Weight: 1)");
    Print("[", details.trendReversal ? "✓" : " ", "] Trend Reversal (Weight: 2)");
    Print("[", details.confirmedBreak ? "✓" : " ", "] Confirmed Break (Weight: 2)");
    Print("TOTAL SCORE: ", details.totalScore, " / 13");
    Print("REASON: ", details.reason);
    Print("+-----------------------------------------+");

    // Decision based on score thresholds
    // Score ranges: 0-4 (weak), 5-7 (moderate), 8-13 (strong)
    
    if(details.totalScore >= 8 && EnableAutoReverse)
    {
        // STRONG invalidation (8-13) → REVERSE
        Print("DECISION: STRONG INVALIDATION - REVERSING POSITION");
        
        lastReverseTime = TimeTradeServer();
        
        if(!ClosePosition(ticket))
        {
            Print("Failed to close position for reversal");
            return;
        }
        
        ENUM_ORDER_TYPE reverseType = (posType == POSITION_TYPE_BUY) ? 
                                       ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        
        Print("Opening reversed position: ", EnumToString(reverseType));
        
        if(posType == POSITION_TYPE_BUY && EnableSellOrders)
            OpenPosition(ORDER_TYPE_SELL);
        else if(posType == POSITION_TYPE_SELL && EnableBuyOrders)
            OpenPosition(ORDER_TYPE_BUY);
    }
    else if(details.totalScore >= 5 && EnableAutoHedge)
    {
        // MODERATE invalidation (5-7) → HEDGE
        Print("DECISION: MODERATE INVALIDATION - HEDGING POSITION");
        
        ENUM_ORDER_TYPE hedgeType = (posType == POSITION_TYPE_BUY) ? 
                                     ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        
        ulong hedgeTicket = OpenHedgePosition(hedgeType, volume);
        
        if(hedgeTicket > 0)
        {
            AddHedgePair(ticket, hedgeTicket);
            Print("Hedge created successfully");
        }
        else
        {
            Print("Failed to create hedge");
        }
    }
    else
    {
        // WEAK or NO invalidation (0-4) → MONITOR
        Print("DECISION: WEAK/NO INVALIDATION - MONITORING");
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

    newSL = NormalizeDouble(newSL, _Digits);

    Print("+-----------------------------------------+");
    Print("TRAILING STOP MANAGEMENT");
    Print("TICKET: ", ticket, " | Profit: $", profit);
    Print("Current Price: ", currentPrice, " | Entry Price: ", entryPrice);
    Print("Current SL: ", currentSL, " -> New SL: ", newSL);
    Print("TSEnableBreakEvenLock: ", TSEnableBreakEvenLock ? "Yes" : "No");
    Print("+-----------------------------------------+");

    // Validate new SL
    if(!IsSLValid(posType, newSL))
    {
        Print("SL too close / invalid, skipping modification. Ticket: ", ticket);
        return;
    }

    // Try to modify
    if(!ModifyPosition(ticket, newSL, currentTP))
    {
        Print("SL modify failed. Ticket: ", ticket);
    }
}

// +------------------------------------------------------------------+
// | Helper function to validate SL price                             |
// +------------------------------------------------------------------+
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


// +------------------------------------------------------------------+
// | Helper function to calculate true break-even price               |
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

// +------------------------------------------------------------------+
// | Modify position SL/TP                                            |
// +------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double newSL, double newTP)
{
    // Select the position
    if(!PositionSelectByTicket(ticket))
    {
        Print("Error: Failed to select position #", ticket);
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
        Print("PositionModify failed for position #", ticket, " Error: ", GetLastError());
        Print("Retcode: ", result.retcode, " - ", result.comment);
        return false;
    }
    
    Print("Position #", ticket, " modified successfully");
    Print("Old SL: ", currentSL, " -> New SL: ", newSL);
    Print("Old TP: ", currentTP, " -> New TP: ", newTP);
    
    return true;
}

// +------------------------------------------------------------------+
// | Position management functions                                     |
// +------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
    {
        Print("Position ", ticket, " not found");
        return false;
    }
    
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
        Print("Failed to close position ", ticket, " Error: ", GetLastError());
        return false;
    }
    
    Print("Position ", ticket, " closed successfully");
    return true;
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
        Print("Failed to open hedge position. Error: ", GetLastError());
        return 0;
    }
    
    Print("Hedge position opened: ", result.order);
    return result.order;
}
// +------------------------------------------------------------------+

// +------------------------------------------------------------------+
// | Convert input value to points based on input type                |
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
                        Print("Error: Invalid pointsPerTick (", pointsPerTick, ")");
                        return 0;
                    }

                    // Value per point = (value per tick) / (points per tick)
                    double valuePerPoint = normalizedTickValue / pointsPerTick;
                    
                    // Convert dollars to points
                    points = value / valuePerPoint;
                }
                else
                {
                    Print("Error: Invalid tick value (", tickValue, 
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
                        Print("Error: Invalid pointsPerTick in percent conversion (", pointsPerTick, ")");
                        return 0;
                    }
                    
                    // Value per point = (value per tick) / (points per tick)
                    double valuePerPoint = normalizedTickValue / pointsPerTick;

                    // Convert dollars to points
                    points = dollarAmount / valuePerPoint;
                }
                else
                {
                    Print("Error: Invalid parameters for percent conversion");
                }
            }
            break;
    }
    
    return points;
}

// +------------------------------------------------------------------+
// | Get total commission for a position (entry + exit estimate)      |
// +------------------------------------------------------------------+
double GetPositionRoundTripCommission(ulong positionTicket)
{
    double entryCommission = 0.0;
    
    if(!HistorySelectByPosition(positionTicket))
        return 0.0;
    
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
// | Monitor High-Impact News Events & return event details           |
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
                    
                    eventDetails += "**Importance:** High\n";
                    eventDetails += "**Pause Window:** " + TimeToString(pauseStart, TIME_SECONDS) + 
                                   " to " + TimeToString(pauseEnd, TIME_SECONDS);
                    
                    Print("High impact event for ", country.currency, ": ", event.name);
                    
                    return eventDetails;
                }
            }
        }
    }
    
    eventID = 0;
    return "";
}

// +------------------------------------------------------------------+
// | Check if current time is within allowed trading hours            |
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
        Print("ERROR: Invalid TradingStartTime format. Use HH:MM");
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
        Print("ERROR: Invalid TradingEndTime format. Use HH:MM");
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