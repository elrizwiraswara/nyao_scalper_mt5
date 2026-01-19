// +------------------------------------------------------------------+
// |                                           Nyao Scalper v7.0      |
// |                                   EMA + Stochastic Strategy      |
// |              with Equity & Risk Management + Discord Alerts      |
// |                                    © Copyright Nyao Scalper      |
// +------------------------------------------------------------------+
#property copyright "© Copyright Nyao Scalper by Elriz Wiraswara"
#property version   "7.0"
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
    INPUT_DOLLAR,                                   // Dollar
    INPUT_PERCENT,                                  // Percent
    INPUT_POINTS                                    // Points
};

input group "+-----------------------------------------+"
input group " Nyao Scalper v7.0"
input group "「結果が出ない努力はただの言い訳」"
input group " © Copyright Nyao Scalper by Elriz Wiraswara"
input group "+-----------------------------------------+"

const int MagicNumber = 6926268;                          // Magic Number

input group "🚦 Indicator Settings"
input int EMA_Period = 50;                                // EMA Period (Trend Filter)
input ENUM_MA_METHOD EMA_Method = MODE_EMA;               // EMA Method
input ENUM_MA_METHOD Stochastic_MA_Method = MODE_SMA;     // Stochastic MA Method
input int Stochastic_K = 14;                              // Stochastic %K Period
input int Stochastic_D = 3;                               // Stochastic %D Period
input int Stochastic_Slowing = 3;                         // Stochastic Slowing
input int Stoch_Oversold = 20;                            // Stochastic Oversold Level
input int Stoch_Overbought = 80;                          // Stochastic Overbought Level
input ENUM_STO_PRICE Stoch_PriceField = STO_LOWHIGH;      // Stochastic Price Field
input int MinPriceDistancePoints = 100;                   // Min Price Distance Between Signals (Points)

input group "📝 Order Settings"
input bool EnableBuyOrders = true;                        // Enable Buy Orders
input bool EnableSellOrders = true;                       // Enable Sell Orders
input double BaseLotSize = 0.01;                          // Base Lot Size
input int MaxOpenOrders = 5;                              // Maximum Consecutive Open Orders
input bool EnablePyramiding = false;                      // Enable Adding to Winning Positions
input int MinPyramidingOpenOrders = 0;                    // Min Open Orders before Pyramiding
input int MaxPyramidLevels = 3;                           // Max Pyramiding Position to Add
input double ProfitToAddPercent = 10.0;                   // Profit % Required to Add Pyramiding (% of equity)
input bool EnableTrendReverseExit = true;                 // Close losing positions on Trend Reversal
input int MaxLosingTimeMinutes = 60;                      // Max Time for Losing Position (Minutes)

input group "🧮 Dynamic Lot Sizing Settings"
input bool EnableDynamicLots = true;                      // Enable Dynamic Lot Sizing
input double EquityDropPercent = 10.0;                    // Equity Drop % per Lot Step
input double LotStepSize = 0.01;                          // Lot Increase Step Size
input double MaxLotSize = 0.10;                           // Maximum Lot Size

input group "🏦 Equity Settings"
input double MinEquityPercent = 80.0;                     // Min Equity % from Peak - Pause Trading when Reached
input double MaxDrawdownFromPeak = 0;                     // Max Equity $ Drawdown - Pause Trading when Reached (0 = Disabled)
input int PauseMinutes = 30;                              // Pause Duration when Reached (Minutes)
input double PauseMinutesMultiplier = 1.5;                // Multiply Pause Duration on Each Trigger
input int MaxPauseMinutes = 0;                            // Max Pause Duration Minutes (0 = Maximum 24,855 days)
input int MaxMinEquityTriggers = 0;                       // Max Times Trigger - Stop Trading when Reached (0 = Unlimited)
input bool ResetOnNewPeak = true;                         // Reset Min Equity Triggers on New Peak Equity
input double TargetEquity = 0;                            // Target Equity - Stop Trading when Reached (0 = Disabled)
input double MinimumEquity = 20;                          // Minimum Equity - Stop Trading when Reached (0 = Disabled)

input group "📈 Take Profit Settings"
input bool EnableTakeProfit = false;                      // Enable Take Profit
input ENUM_INPUT_TYPE TPInputType = INPUT_DOLLAR;         // TP Input Type (Points/Dollar/Percent of Equity)
input double TPValue = 5.0;                               // TP Value

input group "💸 Trailing Stop Settings"
input bool EnableTrailingStop = true;                     // Enable Trailing Stop
input bool TSEnableBreakEvenLock = true;                  // Enable Break-Even Lock Point
input ENUM_INPUT_TYPE TSInputType = INPUT_DOLLAR;         // TS Input Type (Points/Dollar/Percent of Equity)
input double TSValue = 1.0;                               // TS Initial Value

input group "📉 Stop Loss Settings"
input bool EnableStopLoss = false;                        // Enable Stop Loss
input ENUM_INPUT_TYPE SLInputType = INPUT_DOLLAR;         // SL Input Type (Points/Dollar/Percent of Equity)
input double SLValue = 5.0;                               // SL Value

input group "🤖 Robot Settings"
input bool EnableDiscordAlerts = false;                   // Enable Discord Alerts
input string DiscordWebhookURL = "";                      // Discord Webhook URL
input bool EnableTradingHours = false;                    // Enable Trading Hours
input string TradingStartTime = "00:00";                  // Trading Start Time (HH:MM)
input string TradingEndTime = "23:59";                    // Trading End Time (HH:MM)
input bool EnableNewsFilter = true;                       // Enable News Filter (Pause Trading During News)
input int NewsMinutesBefore = 30;                         // Minutes Before News Event
input int NewsMinutesAfter = 30;                          // Minutes After News Event

// Global Variables
double initialBalance = 0;
double peakEquity = 0;
double lastPeakEquity = 0;
bool targetEquityReached = false;
bool minimumEquityReached = false;
bool minEquityTriggersExceeded = false;      // Flag when max triggers exceeded
int minEquityTriggerCount = 0;               // Counter for MinEquityPercent triggers
bool isPaused = false;
int currentPauseDuration = 0;
datetime pauseStartTime = 0;
bool wasWithinTradingHours = true;           // Track trading hours state for alerts
static ulong lastProcessedNewsEventID = 0;

// EMA + Stochastic variables
int emaHandle;
int stochHandle;
double emaBuffer[];
double stochMainBuffer[];   // %K line
double stochSignalBuffer[]; // %D line
static double lastBuySignalPrice = 0;
static double lastSellSignalPrice = 0;

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
    if(!EnableDiscordAlerts || DiscordWebhookURL == "")
        return false;

    // UTC ISO 8601 format for Discord
    datetime currentTime = TimeGMT();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    string timestamp = StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ", 
                                    dt.year, dt.mon, dt.day, 
                                    dt.hour, dt.min, dt.sec);
    
    // Prepare JSON payload
    string jsonPayload = "{";
    jsonPayload += "\"embeds\": [{";
    jsonPayload += "\"title\": \"" + title + "\",";
    jsonPayload += "\"description\": \"" + message + "\",";
    jsonPayload += "\"color\": " + IntegerToString(embedColor) + ",";
    jsonPayload += "\"timestamp\": \"" + timestamp + "\",";
    jsonPayload += "\"footer\": {";
    jsonPayload += "\"text\": \"Nyao Scalper v7.0 | " + _Symbol + "\"";
    jsonPayload += "}";
    jsonPayload += "}]";
    jsonPayload += "}";
    
    // Convert payload to char array
    char data[];
    char result[];
    string headers;
    
    StringToCharArray(jsonPayload, data, 0, StringLen(jsonPayload));
    
    // Send HTTP POST request
    int timeout = 5000; // 5 seconds timeout
    int res = WebRequest(
        "POST",
        DiscordWebhookURL,
        "Content-Type: application/json\r\n",
        timeout,
        data,
        result,
        headers
    );
    
    if(res == 200 || res == 204)
    {
        Print("Discord alert sent successfully: ", title);
        return true;
    }
    else
    {
        Print("Failed to send Discord alert. HTTP Code: ", res);
        if(res == -1)
        {
            Print("Error: ", GetLastError(), " - Make sure the URL is added to allowed URLs in Tools > Options > Expert Advisors");
        }
        return false;
    }
}

// +------------------------------------------------------------------+
// | Calculate current lot size based on equity drop from peak        |
// +------------------------------------------------------------------+
double CalculateDynamicLotSize()
{
    if(!EnableDynamicLots)
        return BaseLotSize;

    if(lastPeakEquity <= 0)
        return BaseLotSize;
    
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double equityDropAmount = lastPeakEquity - currentEquity;
    double equityDropPercentage = (equityDropAmount / lastPeakEquity) * 100.0;
    
    if(equityDropPercentage <= 0)
    {
        return BaseLotSize;
    }
    
    int lotSteps = (int)(equityDropPercentage / EquityDropPercent);
    
    if(lotSteps < 0)
        lotSteps = 0;
    
    double currentLot = BaseLotSize + (lotSteps * LotStepSize);
    
    if(currentLot > MaxLotSize)
        currentLot = MaxLotSize;

    // Lot Size Validation
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(currentLot < minLot)
        currentLot = minLot;
    if(currentLot > maxLot)
        currentLot = maxLot;

    // Round to valid lot step
    currentLot = MathFloor(currentLot / lotStep) * lotStep;
    
    // Validate account has enough money for this lot size
    double marginNeeded = 0;
    if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, currentLot, 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK), marginNeeded))
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
            if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, testLot, 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK), testMargin))
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

    emaHandle = iMA(_Symbol, PERIOD_CURRENT, EMA_Period, 0, EMA_Method, PRICE_CLOSE);

    if(emaHandle == INVALID_HANDLE)
    {
        Alert("ERROR: Error creating EMA indicator");
        return(INIT_FAILED);
    }
    
    stochHandle = iStochastic(_Symbol, PERIOD_CURRENT, Stochastic_K, Stochastic_D, 
                            Stochastic_Slowing, Stochastic_MA_Method, Stoch_PriceField);
    
    if(stochHandle == INVALID_HANDLE)
    {
        Alert("ERROR: Error creating Stochastic indicator");
        return(INIT_FAILED);
    }
    
    ArraySetAsSeries(emaBuffer, true);
    ArraySetAsSeries(stochMainBuffer, true);
    ArraySetAsSeries(stochSignalBuffer, true);

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
    
    Print("+-----------------------------------------+");
    Print("Nyao Scalper v7.0 Initialized Successfully");
    Print("+-----------------------------------------+");
    Print("Symbol: ", _Symbol);
    Print("Timeframe: ", EnumToString(PERIOD_CURRENT));
    Print("Base Lot Size: ", BaseLotSize);
    Print("Enable Buy Orders: ", EnableBuyOrders ? "Yes" : "No");
    Print("Enable Sell Orders: ", EnableSellOrders ? "Yes" : "No");
    Print("Trading Strategy: EMA + Stochastic Combined");
    Print("EMA Period: ", EMA_Period);
    Print("Stochastic K Period: ", Stochastic_K);
    Print("Stochastic D Period: ", Stochastic_D);
    Print("Stochastic Slowing: ", Stochastic_Slowing);
    Print("Stoch Oversold: ", Stoch_Oversold);
    Print("Stoch Overbought: ", Stoch_Overbought);
    Print("Max Open Orders: ", MaxOpenOrders);
    Print("Min Equity Percent from Peak: ", MinEquityPercent, "%");
    Print("Max Drawdown from Peak: $", MaxDrawdownFromPeak);
    Print("Max Min Equity Triggers: ", MaxMinEquityTriggers == 0 ? "Unlimited" : IntegerToString(MaxMinEquityTriggers));
    Print("Pause Duration: ", PauseMinutes, " minutes");
    Print("Pause Duration Multiplier: ", PauseMinutesMultiplier);
    Print("Initial Peak Equity: $", peakEquity);
    Print("Target Equity: ", TargetEquity > 0 ? "$" + DoubleToString(TargetEquity, 2) : "Disabled");
    Print("Minimum Equity: ", MinimumEquity > 0 ? "$" + DoubleToString(MinimumEquity, 2) : "Disabled");
    Print("+-----------------------------------------+");
    Print("Dynamic Lot Sizing: ", EnableDynamicLots ? "ENABLED" : "DISABLED");
    if(EnableDynamicLots)
    {
        Print("Base Lot Size: ", BaseLotSize);
        Print("Equity Drop % per Step: ", EquityDropPercent, "%");
        Print("Lot Step Size: ", LotStepSize);
        Print("Maximum Lot Size: ", MaxLotSize);
    }
    Print("+-----------------------------------------+");
    Print("Enable Take Profit: ", EnableTakeProfit);
    if(EnableTakeProfit)
    {
        Print("TP Input Type: ", TPInputType);
        Print("TP Value: ", TPValue);
    }
    Print("Enable Trailing Stop: ", EnableTrailingStop);
    if(EnableTrailingStop)
    {
        Print("Always Trail from Absolute Profit: ", TSEnableBreakEvenLock);
        Print("Trailing Stop Input Type: ", TSInputType);
        Print("Trailing Stop Initial Value: ", TSValue);
    }
    Print("Enable Stop Loss: ", EnableStopLoss);
    if(EnableStopLoss)
    {
        Print("SL Input Type: ", SLInputType);
        Print("SL Value: ", SLValue);
    }
    Print("+-----------------------------------------+");
    Print("Discord Alerts: ", EnableDiscordAlerts);
    if(EnableDiscordAlerts)
    {
        if(DiscordWebhookURL == "")
        {
            Print("WARNING: Discord alerts enabled but webhook URL is empty!");
        }
        else
        {
            Print("Webhook URL configured (length: ", StringLen(DiscordWebhookURL), " chars)");
            Print("Alerts will be sent for:");
            Print("  - Minimum Equity Percent reached");
            Print("  - Target Equity reached");
            Print("  - Trading paused/resumed");
        }
    }
    Print("+-----------------------------------------+");
    Print("Trading Hours: ", EnableTradingHours ? "ENABLED" : "DISABLED");
    if(EnableTradingHours)
    {
        Print("Allowed Trading Period: ", TradingStartTime, " - ", TradingEndTime, " (Server Time)");
        Print("Current Server Time: ", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS));
    }
    Print("+-----------------------------------------+");
    Print("News Filter: ", EnableNewsFilter ? "ENABLED" : "DISABLED");
    if(EnableNewsFilter)
    {
        Print("News Time Window: ", NewsMinutesBefore, " min before - ", NewsMinutesAfter, " min after");
    }
    Print("+-----------------------------------------+");
    
    return(INIT_SUCCEEDED);
}

// +------------------------------------------------------------------+
// | Expert deinitialization function                                 |
// +------------------------------------------------------------------+
void OnDeinit(const int reason)
{   
    if(emaHandle != INVALID_HANDLE)
        IndicatorRelease(emaHandle);
    if(stochHandle != INVALID_HANDLE)
        IndicatorRelease(stochHandle);
    
    Print("Nyao Scalper EA Deinitialized");
}

// +------------------------------------------------------------------+
// | Expert tick function - NOW CHECKS SIGNALS ON EVERY TICK          |
// +------------------------------------------------------------------+
void OnTick()
{    
    // Update indicator buffers
    int emaCopied = CopyBuffer(emaHandle, 0, 0, 1, emaBuffer);
    if(emaCopied != 1)
    {
        Alert("ERROR: Error copying EMA buffer. Expected 1, got ", emaCopied);
        return;
    }
    
    int stochMainCopied = CopyBuffer(stochHandle, 0, 0, 3, stochMainBuffer);
    int stochSignalCopied = CopyBuffer(stochHandle, 1, 0, 3, stochSignalBuffer);
    if(stochMainCopied != 3 || stochSignalCopied != 3)
    {
        Alert("ERROR: Error copying Stochastic buffers. Main: ", stochMainCopied, ", Signal: ", stochSignalCopied);
        return;
    }
    
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
            string alertMsg = "🎯 **TARGET EQUITY REACHED!**\n\n";
            alertMsg += "📊 **Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "🎯 **Target Equity:** $" + DoubleToString(TargetEquity, 2) + "\n";
            alertMsg += "📈 **Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "💰 **Profit:** $" + DoubleToString(TargetEquity - initialBalance, 2) + "\n\n";
            alertMsg += "✅ **Status:** All positions closed, trading stopped";
            
            SendDiscordAlert("🎉 Target Equity Achieved", alertMsg, 5763719); // Green color
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
            string alertMsg = "🔴 **MINIMUM TRADEABLE EQUITY REACHED!**\n\n";
            alertMsg += "📊 **Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
            alertMsg += "📉 **Minimum Equity:** $" + DoubleToString(MinimumEquity, 2) + "\n";
            alertMsg += "📈 **Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
            alertMsg += "💰 **Loss:** $" + DoubleToString(initialBalance - currentEquity, 2) + "\n\n";
            alertMsg += "✅ **Status:** All positions closed, trading stopped";
            
            SendDiscordAlert("🔴 Minimum Tradeable Equity Reached", alertMsg, 15158332); // Red color
        }

        Alert("MINIMUM TRADEABLE EQUITY REACHED! Closing all positions and stopping trading.");
        
        CloseAllPositions();

        DisableAlgoTrading();
        return;
    }
    
    if(targetEquityReached || minimumEquityReached || minEquityTriggersExceeded)
    {
        return;
    }
    
    // Calculate allowed drawdown
    double drawdownFromPercent = lastPeakEquity * ((100.0 - MinEquityPercent) / 100.0);

    // If MaxDrawdownFromPeak is 0 or negative, don't cap it
    double allowedDrawdown = (MaxDrawdownFromPeak > 0) ? 
                            MathMin(drawdownFromPercent, MaxDrawdownFromPeak) : 
                            drawdownFromPercent;

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
                    string alertMsg = "🛑 **MAX MIN EQUITY TRIGGERS EXCEEDED!**\n\n";
                    alertMsg += "📊 **Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                    alertMsg += "📈 **Peak Equity:** $" + DoubleToString(lastPeakEquity, 2) + "\n";
                    alertMsg += "⚡ **Triggers Used:** " + IntegerToString(minEquityTriggerCount) + " / " + IntegerToString(MaxMinEquityTriggers) + "\n\n";
                    alertMsg += "✅ **Status:** All positions closed, trading stopped";
                    
                    SendDiscordAlert("🛑 Max Equity Triggers Exceeded", alertMsg, 15158332); // Red color
                }

                Alert("MAX MIN EQUITY TRIGGERS EXCEEDED! Closing all positions and stopping trading.");
                
                CloseAllPositions();

                DisableAlgoTrading();
                return;
            }
            
            // First time hitting minimum equity
            isPaused = true;
            pauseStartTime = TimeCurrent();

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
                string alertMsg = "⚠️ **MINIMUM EQUITY PROTECTION TRIGGERED**\n\n";
                alertMsg += "📊 **Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "📈 **Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n";
                alertMsg += "🔄 **Previous Peak:** $" + DoubleToString(oldPeakEquity, 2) + "\n";
                alertMsg += "🆕 **New Peak (Balance):** $" + DoubleToString(lastPeakEquity, 2) + "\n";
                alertMsg += "📉 **Equity Drop:** $" + DoubleToString(equityDrop, 2) + " (" + DoubleToString(equityDropPercent, 2) + "%)\n";
                alertMsg += "🛡️ **Min Allowed (" + DoubleToString(MinEquityPercent, 0) + "%):** $" + DoubleToString(minAllowedEquity, 2) + "\n\n";
                alertMsg += "⏸️ **Trading Paused:** " + IntegerToString(currentPauseDuration) + " minutes\n";
                alertMsg += "⏰ **Resume Time:** " + TimeToString(pauseStartTime + currentPauseDuration * 60) + "\n\n";
                alertMsg += "🔄 **Action:** Closing unprofitable positions...";
                
                SendDiscordAlert("🚨 Equity Protection Activated", alertMsg, 15158332); // Red color
            }

            CloseAllPositions(true); // Close only unprofitable positions
        }
    }

    // Check for high-impact news events
    if(EnableNewsFilter && !isPaused)
    {   
        ulong newsEventID = 0;
        string newsDetails = IsHighImpactNewsTime(NewsMinutesBefore, NewsMinutesAfter, newsEventID);
        
        if(newsDetails != "" && lastProcessedNewsEventID != newsEventID) // News event detected
        {   
            // Update last processed news event ID
            lastProcessedNewsEventID = newsEventID;

            // Trigger the pause mechanism
            isPaused = true;
            pauseStartTime = TimeCurrent();
            currentPauseDuration = NewsMinutesAfter;
            
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
                string alertMsg = "📰 **HIGH-IMPACT NEWS DETECTED**\n\n";
                
                // Add event details
                alertMsg += newsDetails + "\n";
                
                // Add trading info
                alertMsg += "**─────────────────────**\n";
                alertMsg += "💼 **Trading Information**\n";
                alertMsg += "🕒 **Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                alertMsg += "⏰ **Pause Duration:** " + IntegerToString(currentPauseDuration) + " minutes\n";
                alertMsg += "📊 **Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "📈 **Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n\n";
                alertMsg += "⚠️ **Action:** Trading paused during news period\n";
                alertMsg += "🔄 **Resume Time:** " + TimeToString(pauseStartTime + currentPauseDuration * 60);
                
                SendDiscordAlert("📰 News Event - Trading Paused", alertMsg, 16776960); // Yellow color
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
                string alertMsg = "🟢 **TRADING HOURS STARTED**\n\n";
                alertMsg += "🕒 **Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                alertMsg += "⏰ **Trading Period:** " + TradingStartTime + " - " + TradingEndTime + "\n";
                alertMsg += "📊 **Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "📈 **Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n\n";
                alertMsg += "✅ **Status:** Now accepting new trading signals";
                
                SendDiscordAlert("▶️ Trading Hours Started", alertMsg, 5763719); // Green color
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
                string alertMsg = "🔴 **TRADING HOURS ENDED**\n\n";
                alertMsg += "🕒 **Server Time:** " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS) + "\n";
                alertMsg += "⏰ **Trading Period:** " + TradingStartTime + " - " + TradingEndTime + "\n";
                alertMsg += "📊 **Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "📈 **Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n\n";
                alertMsg += "⏸️ **Status:** No new positions until next trading session";
                
                SendDiscordAlert("⏸️ Trading Hours Ended", alertMsg, 15158332); // Red color
            }
        }
        
        // If currently outside trading hours, prevent new trades
        if(!currentlyWithinHours)
        {
            static datetime lastTradingHoursLog = 0;
            
            // Log only once per minute to avoid spam
            if(TimeCurrent() - lastTradingHoursLog > 60)
            {
                Print("[OUTSIDE TRADING HOURS] Current time: ", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS), 
                      " | Allowed: ", TradingStartTime, " - ", TradingEndTime);
                lastTradingHoursLog = TimeCurrent();
            }
            
            // Don't open new positions, but continue managing existing ones
            ManagePositions();
            return;
        }
    }
    
    // Check pause duration 
    if(isPaused)
    {
        datetime currentTime = TimeCurrent();
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
                string alertMsg = "✅ **TRADING RESUMED**\n\n";
                alertMsg += "⏰ **Pause Duration:** " + IntegerToString(currentPauseDuration) + " minutes\n";
                alertMsg += "📊 **Current Equity:** $" + DoubleToString(currentEquity, 2) + "\n";
                alertMsg += "📈 **Peak Equity:** $" + DoubleToString(peakEquity, 2) + "\n\n";
                alertMsg += "🔄 **Status:** Monitoring for new trading signals...";
                
                SendDiscordAlert("▶️ Trading Resumed", alertMsg, 3066993); // Blue color
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

                if (unProfitableOnly && profit >= 0)
                    continue;

                Print("Closing position. Ticket: ", ticket, ", Profit/Loss: $", profit);

                if(ClosePosition(ticket))
                    closedCount++;
                else
                    Print("Failed to close position: ", ticket);
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
    // Reset buy signal price if no open orders
    if (CountOpenOrders() == 0)
    {
        lastBuySignalPrice = 0;
        lastSellSignalPrice = 0;
    }

    bool buySignal = false;
    bool sellSignal = false;

    // Check EMA + Stochastic Strategy
    CheckEmaStochastic(buySignal, sellSignal);

    // Define minimum price distance to prevent duplicate signals (in points)
    double minPriceDistance = MinPriceDistancePoints * _Point;

    // Get current prices
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Process BUY signals
    if(buySignal && EnableBuyOrders) 
    {
        // Check if price has moved enough from last buy signal
        bool priceMovedEnough = (lastBuySignalPrice == 0) || 
                                (MathAbs(currentAsk - lastBuySignalPrice) >= minPriceDistance);

        if(priceMovedEnough)
        {
            OpenPosition(ORDER_TYPE_BUY);
            lastBuySignalPrice = currentAsk;
            Print("BUY signal accepted at price: ", currentAsk);
        }
        else
        {
            Print("BUY signal filtered - too close to last signal (Price: ", currentAsk, 
                  ", Last: ", lastBuySignalPrice, ", Distance: ", 
                  MathAbs(currentAsk - lastBuySignalPrice) / _Point, " points)");
        }
    }

    // Process SELL signals
    if(sellSignal && EnableSellOrders)
    {
        // Check if price has moved enough from last sell signal
        bool priceMovedEnough = (lastSellSignalPrice == 0) || 
                                (MathAbs(currentBid - lastSellSignalPrice) >= minPriceDistance);
        
        if(priceMovedEnough)
        {
            OpenPosition(ORDER_TYPE_SELL);
            lastSellSignalPrice = currentBid;
            Print("SELL signal accepted at price: ", currentBid);
        }
        else
        {
            Print("SELL signal filtered - too close to last signal (Price: ", currentBid, 
                  ", Last: ", lastSellSignalPrice, ", Distance: ", 
                  MathAbs(currentBid - lastSellSignalPrice) / _Point, " points)");
        }
    }
}

// +------------------------------------------------------------------+
// | Check EMA + Stochastic Strategy                       |
// +------------------------------------------------------------------+
void CheckEmaStochastic(bool &buySignal, bool &sellSignal)
{   
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double currentEMA = emaBuffer[0];   
    double stochK_current = stochMainBuffer[0];
    double stochK_previous = stochMainBuffer[1];
    double stochD_current = stochSignalBuffer[0];
    double stochD_previous = stochSignalBuffer[1]; 
    
    // Stochastic crossovers
    bool stochCrossUp = (stochK_previous <= stochD_previous) && (stochK_current > stochD_current);
    bool stochCrossDown = (stochK_previous >= stochD_previous) && (stochK_current < stochD_current);
    
    // BUY SIGNAL: Price above EMA + Stochastic crosses up FROM oversold
    bool priceAboveEMA = (currentPrice > currentEMA);
    bool wasInOversold = (stochK_previous < Stoch_Oversold);
    
    if(priceAboveEMA && stochCrossUp && wasInOversold)
    {
        buySignal = true;
    }
    
    // SELL SIGNAL: Price below EMA + Stochastic crosses down FROM overbought
    bool priceBelowEMA = (currentPrice < currentEMA);
    bool wasInOverbought = (stochK_previous > Stoch_Overbought);
    
    if(priceBelowEMA && stochCrossDown && wasInOverbought)
    {
        sellSignal = true;
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
    request.comment = "Order by Nyao Scalper";

    // Calculate and set Take Profit
    if(EnableTakeProfit)
    {
        double tpPoints = ConvertToPoints(TPInputType, TPValue, currentLot);
        
        if(orderType == ORDER_TYPE_BUY)
            request.tp = NormalizeDouble(price + (tpPoints * _Point), _Digits); 
        else
            request.tp = NormalizeDouble(price - (tpPoints * _Point), _Digits); 
    }
    
    // Calculate and set Stop Loss
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
            
            Print("Order opened successfully. Ticket: ", result.order, 
                  ", Type: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL",
                  ", Lot Size: ", currentLot,
                  " (Peak: $", lastPeakEquity, 
                  ", Current: $", currentEquity,
                  ", Drop: ", equityDropPercentage, "%)");
            
            if(EnableStopLoss)
                Print("  SL: ", request.sl);
            if(EnableTakeProfit)
                Print("  TP: ", request.tp);
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
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {      
                // Check if losing AND trend reversed
                ManageLosingPositions(ticket);

                // Manage trailing stop if enabled
                if(EnableTrailingStop) ManageTrailingStop(ticket);
            }
        }
    }

    // Check for pyramiding (adding to winning positions if enabled)
    CheckForPyramiding();
}

void ManageLosingPositions(ulong ticket)
{   
    if(!PositionSelectByTicket(ticket)) return;

    double profit = PositionGetDouble(POSITION_PROFIT);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

    datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
    int minutesOpen = (int)((TimeCurrent() - openTime) / 60);

    bool buySignal = false;
    bool sellSignal = false;

    // Check EMA + Stochastic Strategy
    CheckEmaStochastic(buySignal, sellSignal);

    if(EnableTrendReverseExit && profit < 0 && minutesOpen >= MaxLosingTimeMinutes)
    {
        bool shouldCloseBuy = (posType == POSITION_TYPE_BUY && sellSignal);
        bool shouldCloseSell = (posType == POSITION_TYPE_SELL && buySignal);
        
        if(shouldCloseBuy || shouldCloseSell)
        {
            Print("❌ Trend reversed. Ticket: ", ticket, ", Loss: $", profit);
            ClosePosition(ticket);
        }
    }
}

// +------------------------------------------------------------------+
// | Manage trailing stop for open positions                          |
// +------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double volume = PositionGetDouble(POSITION_VOLUME);
    double currentSL = PositionGetDouble(POSITION_SL);
    
    double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double trailingDistancePoints = ConvertToPoints(TSInputType, TSValue, volume);
    double trailingDistancePrice = trailingDistancePoints * _Point;
    
    // Get broker's minimum stop level
    long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minStopDistance = stopLevel * _Point;
    
    // Calculate true break-even price (covers spread + commission + swap)
    double breakEvenPrice = CalculateBreakEvenPrice(ticket, posType, entryPrice, volume);
    
    double newSL;
    
    if(posType == POSITION_TYPE_BUY)
    {
        double profitPoints = (currentPrice - entryPrice) / _Point;
        if(profitPoints < trailingDistancePoints) return;
        
        newSL = NormalizeDouble(currentPrice - trailingDistancePrice, _Digits);
        
        // Ensure SL respects minimum stop level
        double minAllowedSL = NormalizeDouble(currentPrice - minStopDistance, _Digits);
        if(newSL > minAllowedSL)
        {
            newSL = minAllowedSL;
        }
        
        if(currentSL != 0 && newSL <= currentSL) return;
        
        // Lock at break-even (minimum profitable price), not entry
        if(TSEnableBreakEvenLock && newSL < breakEvenPrice)
        {
            newSL = breakEvenPrice;
            
            // If break-even violates stop level, check if min allowed SL is still profitable
            if(newSL > minAllowedSL)
            {
                // Can only use minAllowedSL - check if it's at least break-even
                if(minAllowedSL >= breakEvenPrice)
                {
                    // Safe: min allowed SL is still profitable
                    newSL = minAllowedSL;
                }
                else
                {
                    // Would result in loss - skip this modification
                    return;
                }
            }
        }
    }
    else // SELL position
    {
        double profitPoints = (entryPrice - currentPrice) / _Point;
        if(profitPoints < trailingDistancePoints) return;
        
        newSL = NormalizeDouble(currentPrice + trailingDistancePrice, _Digits);
        
        // Ensure SL respects minimum stop level
        double maxAllowedSL = NormalizeDouble(currentPrice + minStopDistance, _Digits);
        if(newSL < maxAllowedSL)
        {
            newSL = maxAllowedSL;
        }
        
        if(currentSL != 0 && newSL >= currentSL) return;
        
        // Lock at break-even (minimum profitable price), not entry
        if(TSEnableBreakEvenLock && newSL > breakEvenPrice)
        {
            newSL = breakEvenPrice;
            
            // If break-even violates stop level, check if max allowed SL is still profitable
            if(newSL < maxAllowedSL)
            {
                // Can only use maxAllowedSL - check if it's at least break-even
                if(maxAllowedSL <= breakEvenPrice)
                {
                    // Safe: max allowed SL is still profitable
                    newSL = maxAllowedSL;
                }
                else
                {
                    // Would result in loss - skip this modification
                    return;
                }
            }
        }
    }
    
    ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
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
    if(tickValue != 0 && volume != 0)
    {
        costInPrice = (totalCost / volume) * (tickSize / tickValue);
    }
    
    // Calculate break-even price
    double breakEvenPrice;
    if(posType == POSITION_TYPE_BUY)
    {
        // BUY: Entry + spread + costs
        breakEvenPrice = entryPrice + spread + costInPrice;
    }
    else
    {
        // SELL: Entry - spread - costs
        breakEvenPrice = entryPrice - spread - costInPrice;
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
// | Close position                                                   |
// +------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    if(!PositionSelectByTicket(ticket)) return false;
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.deviation = 10;
    request.magic = MagicNumber;
    request.comment = "Close by Nyao Scalper";
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    if(posType == POSITION_TYPE_BUY)
    {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    }
    else
    {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    }
    
    bool closeResult = OrderSend(request, result);
    
    if(closeResult && result.retcode == TRADE_RETCODE_DONE)
    {
        Print("Position closed successfully. Ticket: ", ticket);
        return true;
    }
    else
    {
        if(closeResult)
            Print("Failed to close position. Ticket: ", ticket, ", Return code: ", result.retcode);
        else
            Print("Close position error for ticket ", ticket, ": ", GetLastError());
        
        return false;
    }
}

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
// | Monitor high-impact news events using TRADE SERVER TIME          |
// | Returns event details string if high-impact news found, else ""  |
// +------------------------------------------------------------------+
string IsHighImpactNewsTime(int minutesBefore, int minutesAfter, ulong &eventID)
{
    MqlCalendarValue values[];
    
    // IMPORTANT: Use TimeTradeServer() instead of TimeCurrent()
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
                // Check for high importance events
                if(event.importance == CALENDAR_IMPORTANCE_HIGH)
                {   
                    // Set the event ID
                    eventID = values[i].event_id;

                    // Get country info
                    MqlCalendarCountry country;
                    CalendarCountryById(event.country_id, country);
                    
                    // Calculate time until event using server time
                    int secondsUntil = (int)(values[i].time - serverTime);
                    int minutesUntil = secondsUntil / 60;
                    
                    // Build detailed event information
                    string eventDetails = "";
                    eventDetails += "📰 **Event Name:** " + event.name + "\n";
                    eventDetails += "🌍 **Country:** " + country.name + " (" + country.code + ")\n";
                    eventDetails += "🕒 **Event Time:** " + TimeToString(values[i].time, TIME_DATE|TIME_SECONDS) + " (Server)\n";
                    eventDetails += "⏱️ **Time Until:** " + IntegerToString(minutesUntil) + " minutes\n";
                    
                    // Add actual/forecast/previous values if available
                    if(values[i].HasActualValue())
                    {
                        eventDetails += "📊 **Actual:** " + DoubleToString(values[i].GetActualValue(), 2) + "\n";
                    }
                    if(values[i].HasForecastValue())
                    {
                        eventDetails += "🎯 **Forecast:** " + DoubleToString(values[i].GetForecastValue(), 2) + "\n";
                    }
                    if(values[i].HasPreviousValue())
                    {
                        eventDetails += "📜 **Previous:** " + DoubleToString(values[i].GetPreviousValue(), 2) + "\n";
                    }
                    
                    // Add importance level
                    string importance = "";
                    switch(event.importance)
                    {
                        case CALENDAR_IMPORTANCE_NONE: importance = "None"; break;
                        case CALENDAR_IMPORTANCE_LOW: importance = "Low"; break;
                        case CALENDAR_IMPORTANCE_MODERATE: importance = "Moderate"; break;
                        case CALENDAR_IMPORTANCE_HIGH: importance = "🔴 High"; break;
                    }
                    eventDetails += "⚠️ **Importance:** " + importance + "\n";
                    
                    // Add event type/sector
                    string eventType = "";
                    switch(event.type)
                    {
                        case CALENDAR_TYPE_EVENT: eventType = "Event"; break;
                        case CALENDAR_TYPE_INDICATOR: eventType = "Indicator"; break;
                        case CALENDAR_TYPE_HOLIDAY: eventType = "Holiday"; break;
                    }
                    eventDetails += "📋 **Type:** " + eventType + "\n";
                    
                    // Add frequency
                    string frequency = "";
                    switch(event.frequency)
                    {
                        case CALENDAR_FREQUENCY_NONE: frequency = "None"; break;
                        case CALENDAR_FREQUENCY_WEEK: frequency = "Weekly"; break;
                        case CALENDAR_FREQUENCY_MONTH: frequency = "Monthly"; break;
                        case CALENDAR_FREQUENCY_QUARTER: frequency = "Quarterly"; break;
                        case CALENDAR_FREQUENCY_YEAR: frequency = "Yearly"; break;
                        case CALENDAR_FREQUENCY_DAY: frequency = "Daily"; break;
                    }
                    if(frequency != "")
                        eventDetails += "🔄 **Frequency:** " + frequency + "\n";
                    
                    Print("High impact event: ", event.name, " (", country.name, ")");
                    Print("Event time (Server): ", TimeToString(values[i].time, TIME_DATE|TIME_SECONDS));
                    Print("Current time (Server): ", TimeToString(serverTime, TIME_DATE|TIME_SECONDS));
                    Print("Minutes until event: ", minutesUntil);
                    
                    return eventDetails; // Return the event details string
                }
            }
        }
    }

    // No event found
    eventID = 0;
    return "";
}

// +------------------------------------------------------------------+
// | Check if current time is within allowed trading hours            |
// +------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    if(!EnableTradingHours)
        return true; // Always allow trading if feature is disabled
    
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

// +------------------------------------------------------------------+
// | Pyramiding / Add more positions if winning                       |
// +------------------------------------------------------------------+
void CheckForPyramiding()
{
    if(!EnablePyramiding) return;

    if(EnableTradingHours && !IsWithinTradingHours()) return;

    // Prevent exceeding MaxOpenOrders
    int currentOpenOrders = CountOpenOrders();
    if(currentOpenOrders >= MaxOpenOrders) return;

    if (MinPyramidingOpenOrders > 0)
    {
        if (currentOpenOrders < MinPyramidingOpenOrders)
        {
            Print("Pyramiding skipped - current open orders (", currentOpenOrders, 
                  ") less than MinPyramidingOpenOrders (", MinPyramidingOpenOrders, ").");
            return;
        }
    }

    // Check if we have profitable positions to add to
    double totalBuyProfit = 0;
    double totalSellProfit = 0;
    int buyCount = 0;
    int sellCount = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                double profit = PositionGetDouble(POSITION_PROFIT);
                
                if(posType == POSITION_TYPE_BUY)
                {
                    totalBuyProfit += profit;
                    buyCount++;
                }
                else
                {
                    totalSellProfit += profit;
                    sellCount++;
                }
            }
        }
    }
    
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double requiredProfit = equity * (ProfitToAddPercent / 100.0);
    
    // Add to winning BUY positions
    if(buyCount > 0 && buyCount < MaxPyramidLevels && totalBuyProfit > requiredProfit)
    {   
        if(currentOpenOrders < MaxOpenOrders)
        {
            Print("Adding to winning BUY positions. Current profit: $", totalBuyProfit);
            OpenPosition(ORDER_TYPE_BUY);
        }
    }
    
    // Add to winning SELL positions
    if(sellCount > 0 && sellCount < MaxPyramidLevels && totalSellProfit > requiredProfit)
    {   
        if(currentOpenOrders < MaxOpenOrders)
        {
            Print("Adding to winning SELL positions. Current profit: $", totalSellProfit);
            OpenPosition(ORDER_TYPE_SELL);
        }
    }
}