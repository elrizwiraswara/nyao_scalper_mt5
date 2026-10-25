// +------------------------------------------------------------------+
// | Nyao Straddle v1.5                                               |
// | Volatility breakout straddle for gold (XAUUSD) on M1, the        |
// | companion EA of Nyao Scalper. Only in extreme markets (H1 ATR    |
// | >= $34 and the last 7 minutes at least 2x their normal pace) it  |
// | keeps a buy stop $1 above and a sell stop $1 below the price.    |
// | The first to fill cancels the other, the position exits on a $1 |
// | trailing stop, and a new pair goes out as soon as it closes.     |
// | After 10 losing trades in a row it pauses for 30 minutes.        |
// | Research and results: README.md, section Nyao Straddle           |
// | © Copyright Nyao Scalper by Elriz Wiraswara                      |
// +------------------------------------------------------------------+
#property copyright "© Copyright Nyao Scalper by Elriz Wiraswara"
#property version "1.5"
#property description "Gold M1 breakout straddle, extreme markets only (H1 ATR >= $34)"
#property description "Buy & sell stop $1 away; first fill cancels the other; $1 trail"
#property description ""
#property description "Open-source, for educational and experimental purposes only"
#property description "Source: https://github.com/elrizwiraswara/nyao_scalper_mt5 [BSD-3-Clause]"
#property description ""
#property description "EXPERIMENTAL - demo forward-test first. No guarantee of profit."
#property strict

#define EA_TITLE "Nyao Straddle v1.5"

#include <Trade\Trade.mqh>

// Research control test: same moments, filters and exits, but the direction is a coin flip
enum ENUM_ENTRY_MODE
{
    ENTRY_STRADDLE,                                       // Straddle (buy stop + sell stop)
    ENTRY_COIN_MARKET,                                    // Coin Flip: Market Order, Random Direction
    ENTRY_COIN_STOP                                       // Coin Flip: One Stop Order, Random Side
};

enum ENUM_DISTANCE_UNIT
{
    DIST_ATR,                                             // ATR Multiples
    DIST_PRICE                                            // Price Distance (gold: 1.00 = $1)
};

// The market must be speeding up: ATR of the last closed bars (7 on M1 = 7 minutes) at least
// 2x its average over the last 288 bars. 1x / 1.5x / 2x on 2026: more profit, but the extra
// all came from the crash and the drawdown grew (20% / 7% / 2%).
input group "Volatility Filter"
input ENUM_TIMEFRAMES VolTimeframe = PERIOD_CURRENT;      // Volatility Timeframe
input int VolATRPeriod = 7;                               // ATR Period (current volatility)
input int VolBaseBars = 288;                              // Normal Volatility = Average ATR of the Last N Bars
input double VolMinRatio = 2.0;                           // Trade Only When ATR >= This x Normal (0 = always)
input double VolMinATR = 0;                               // And ATR >= This Price Distance (0 = off)
input bool CancelWhenCalm = true;                         // Delete Untriggered Orders When Volatility Drops

// Crash-like markets only: the $1 straddle made money in February 2026 only in the hours
// when gold's H1 ATR was about $30 or more, and lost in calmer hours (even "volatile" ones).
// Of the windows compared on 2026 (M1 to D1), a 14-hour one did best; $34 = gold's most
// extreme 10% of 2026. It is a gold price distance: at a much lower gold price it is a
// bigger move (2025 at $2,650-4,300 reached it only in October).
input group "Extreme Market Filter"
input ENUM_TIMEFRAMES RegimeTimeframe = PERIOD_H1;        // Extreme Market Timeframe
input int RegimeATRPeriod = 14;                           // Extreme Market ATR Period
input double RegimeMinATR = 34;                           // Trade Only When That ATR >= This Price Distance (gold H1: 34 = $34, 0 = off)

// Session hours are in UTC; the broker's server clock is converted with SessionUTCOffset.
input group "Trading Sessions"
input bool EnableSessions = false;                        // Trade Only in the Sessions Below
input int SessionUTCOffset = 0;                           // Server Time Minus UTC, Hours (e.g. 2 for a UTC+2 server)
input bool TradeAsia = true;                              // Asia (Tokyo) Session
input int AsiaStartUTC = 0;                               // Asia Start Hour, UTC
input int AsiaEndUTC = 9;                                 // Asia End Hour, UTC
input bool TradeLondon = true;                            // London Session
input int LondonStartUTC = 7;                             // London Start Hour, UTC
input int LondonEndUTC = 16;                              // London End Hour, UTC
input bool TradeNewYork = true;                           // New York Session
input int NewYorkStartUTC = 12;                           // New York Start Hour, UTC
input int NewYorkEndUTC = 21;                             // New York End Hour, UTC

input group "Orders"
input double Lots = 0.01;                                 // Lot Size
input double RiskPercent = 0;                             // Risk % of Equity at the Stop, Never Below Lot Size (0 = off)
input ENUM_DISTANCE_UNIT DistanceUnit = DIST_PRICE;       // Distances Below Are In
input double EntryDistance = 1.0;                         // Pending Order Distance from the Price
input double StopLoss = 1.0;                              // Initial Stop Loss (0 = none)
input double TakeProfit = 0;                              // Take Profit (0 = none, the trailing stop exits)
input double MaxSpread = 0;                               // Max Spread to Place Orders, Price Distance (0 = off)
input int PendingExpiryBars = 0;                          // Re-place an Untriggered Pair After N Bars (0 = keep)

input group "Trailing Stop"
input double TrailStart = 0;                              // Start Trailing at This Profit (0 = from the fill)
input double TrailDistance = 1.0;                         // Trailing Distance Behind the Price (0 = off)
input double TrailStep = 0.1;                             // Minimum Stop Move
input double BreakEvenTrigger = 0;                        // Lock the Smallest Profit Once Profit Reaches This (0 = off)
input double BreakEvenLock = 0.2;                         // Locked Stop Beyond the Entry (covers slippage; gold: 0.20 = $0.20)

input group "Losing Streak Pause"
input int LossStreakPause = 10;                           // Pause After This Many Losing Trades in a Row (0 = off)
input int LossStreakPauseMinutes = 30;                    // Pause Length, Minutes

input group "Other"
input ENUM_ENTRY_MODE EntryMode = ENTRY_STRADDLE;          // Entry Mode (coin flip = research control test)
input int CoinFlipSeed = 1;                               // Coin Flip Random Seed
input long MagicNumber = 25102501;                        // Magic Number
input bool TesterEquityLog = true;                        // Backtest Only: Save Balance & Equity Every 5 Minutes (for reports)

CTrade trade;
ENUM_TIMEFRAMES volTF;
int atrHandle = INVALID_HANDLE;
datetime volBar = 0;                                      // volTF bar the volatility state was computed on
bool volReady = false;
bool volatileNow = false;
double atrNow = 0;                                        // ATR of the last closed bar
double atrNormal = 0;                                     // average ATR of the last VolBaseBars closed bars
int regimeHandle = INVALID_HANDLE;
double regimeATR = 0;                                     // RegimeTimeframe ATR of the last closed bar
datetime retryAfter = 0;                                  // after a failed order, wait before trying again
int lossStreak = 0;                                       // losing trades in a row (LossStreakPause)
datetime pausedUntil = 0;                                 // no new pairs before this time
datetime lastWarnBar = 0;
uint lastStatusMs = 0;

// +------------------------------------------------------------------+
// | Helpers                                                          |
// +------------------------------------------------------------------+
double NormalizePrice(double price)
{
    double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tick > 0) price = MathRound(price / tick) * tick;
    return NormalizeDouble(price, _Digits);
}

double StopsLevelDistance()
{
    return (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
}

// One distance unit in price: the ATR (DIST_ATR) or 1.0 (DIST_PRICE)
double CurrentUnit()
{
    if(DistanceUnit == DIST_PRICE) return 1.0;
    return volReady ? atrNow : 0;
}

// The unit a position was opened with, stored in its comment ("NS u=<unit>"),
// so its trailing distance stays the one it was placed with.
double UnitFromComment(string comment)
{
    int p = StringFind(comment, "u=");
    if(p < 0) return 0;
    double u = StringToDouble(StringSubstr(comment, p + 2));
    return u > 0 ? u : 0;
}

// Warn at most once per bar (avoids a log line on every tick)
void WarnOncePerBar(string message)
{
    datetime bar = iTime(_Symbol, _Period, 0);
    if(bar == lastWarnBar) return;
    lastWarnBar = bar;
    Print(message);
}

double LotSize(double slDistance)
{
    double vol = Lots;
    if(RiskPercent > 0 && slDistance > 0)
    {
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
        if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        if(tickValue > 0 && tickSize > 0)
        {
            double lossPerLot = slDistance / tickSize * tickValue;
            vol = MathMax(Lots, AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0 / lossPerLot);
        }
    }
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    if(step > 0) vol = MathFloor(vol / step + 1e-9) * step;
    vol = MathMax(minVol, MathMin(maxVol, vol));
    return NormalizeDouble(vol, 2);
}

ENUM_ORDER_TYPE_TIME PendingTimeType()
{
    long mode = SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);
    if((mode & SYMBOL_EXPIRATION_GTC) != 0) return ORDER_TIME_GTC;
    if((mode & SYMBOL_EXPIRATION_DAY) != 0) return ORDER_TIME_DAY;
    return ORDER_TIME_GTC;
}

bool IsOurs(long magic, string symbol)
{
    return magic == MagicNumber && symbol == _Symbol;
}

// Hour window [start, end) in UTC; start > end wraps past midnight
bool InHours(int hour, int start, int end)
{
    if(start == end) return false;
    return start < end ? hour >= start && hour < end : hour >= start || hour < end;
}

bool InSession()
{
    if(!EnableSessions) return true;
    MqlDateTime t;
    TimeToStruct(TimeCurrent() - (datetime)(SessionUTCOffset * 3600), t);
    return (TradeAsia && InHours(t.hour, AsiaStartUTC, AsiaEndUTC))
        || (TradeLondon && InHours(t.hour, LondonStartUTC, LondonEndUTC))
        || (TradeNewYork && InHours(t.hour, NewYorkStartUTC, NewYorkEndUTC));
}

// +------------------------------------------------------------------+
// | Volatility state (recomputed once per volTF bar)                 |
// +------------------------------------------------------------------+
void UpdateVolatility()
{
    datetime bar = iTime(_Symbol, volTF, 0);
    if(bar == 0 || (bar == volBar && volReady)) return;

    int n = MathMax(VolBaseBars, 1);
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(atrHandle, 0, 1, n, atr) < n)
    {
        volReady = false;                                 // not enough history yet
        volatileNow = false;
        return;
    }
    double sum = 0;
    for(int i = 0; i < n; i++) sum += atr[i];
    atrNow = atr[0];
    atrNormal = sum / n;
    volBar = bar;
    volReady = atrNow > 0;

    double regime[];
    regimeATR = CopyBuffer(regimeHandle, 0, 1, 1, regime) == 1 ? regime[0] : 0;

    bool ok = volReady;
    if(VolMinRatio > 0) ok = ok && atrNormal > 0 && atrNow >= VolMinRatio * atrNormal;
    if(VolMinATR > 0) ok = ok && atrNow >= VolMinATR;
    if(RegimeMinATR > 0) ok = ok && regimeATR >= RegimeMinATR;
    volatileNow = ok;
}

// +------------------------------------------------------------------+
// | Positions and pending orders of this EA                          |
// +------------------------------------------------------------------+
int CountPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) == 0) continue;
        if(IsOurs(PositionGetInteger(POSITION_MAGIC), PositionGetString(POSITION_SYMBOL))) count++;
    }
    return count;
}

// Counts our buy stops / sell stops and returns the oldest setup time
int CountPendings(int &buyStops, int &sellStops, datetime &oldest)
{
    buyStops = 0;
    sellStops = 0;
    oldest = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!IsOurs(OrderGetInteger(ORDER_MAGIC), OrderGetString(ORDER_SYMBOL))) continue;
        long type = OrderGetInteger(ORDER_TYPE);
        if(type == ORDER_TYPE_BUY_STOP) buyStops++;
        else if(type == ORDER_TYPE_SELL_STOP) sellStops++;
        else continue;
        datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
        if(oldest == 0 || setup < oldest) oldest = setup;
    }
    return buyStops + sellStops;
}

void DeletePendings()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!IsOurs(OrderGetInteger(ORDER_MAGIC), OrderGetString(ORDER_SYMBOL))) continue;
        long type = OrderGetInteger(ORDER_TYPE);
        if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP) trade.OrderDelete(ticket);
    }
}

// +------------------------------------------------------------------+
// | Place the buy stop / sell stop pair                              |
// +------------------------------------------------------------------+
bool OrderPlaced()
{
    uint rc = trade.ResultRetcode();
    return rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED;
}

void PlacePair()
{
    double unit = CurrentUnit();
    if(unit <= 0) return;

    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0 || tick.bid <= 0) return;
    if(MaxSpread > 0 && tick.ask - tick.bid > MaxSpread) return;

    double minDist = StopsLevelDistance() + _Point;
    double entryDist = MathMax(EntryDistance * unit, minDist);
    double slDist = StopLoss > 0 ? MathMax(StopLoss * unit, minDist) : 0;
    double tpDist = TakeProfit > 0 ? MathMax(TakeProfit * unit, minDist) : 0;

    double buyPrice = NormalizePrice(tick.ask + entryDist);
    double sellPrice = NormalizePrice(tick.bid - entryDist);
    double buySL = slDist > 0 ? NormalizePrice(buyPrice - slDist) : 0;
    double buyTP = tpDist > 0 ? NormalizePrice(buyPrice + tpDist) : 0;
    double sellSL = slDist > 0 ? NormalizePrice(sellPrice + slDist) : 0;
    double sellTP = tpDist > 0 ? NormalizePrice(sellPrice - tpDist) : 0;

    // Without an initial stop the risk lot uses the trailing distance
    double vol = LotSize(slDist > 0 ? slDist : TrailDistance * unit);
    if(vol <= 0) return;

    // Only one side can fill, so one order's margin is what must be free
    double margin = 0;
    if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, vol, buyPrice, margin) || margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
    {
        WarnOncePerBar(StringFormat("[NOT PLACED] %.2f lot needs %.2f margin, free margin is %.2f",
                                    vol, margin, AccountInfoDouble(ACCOUNT_MARGIN_FREE)));
        retryAfter = TimeCurrent() + 60;
        return;
    }

    string comment = StringFormat("NS u=%.6g", unit);
    ENUM_ORDER_TYPE_TIME timeType = PendingTimeType();
    if(EntryMode != ENTRY_STRADDLE)
    {
        bool buy = MathRand() % 2 == 0;
        bool ok;
        if(EntryMode == ENTRY_COIN_MARKET)
            ok = buy ? trade.Buy(vol, _Symbol, 0, slDist > 0 ? NormalizePrice(tick.ask - slDist) : 0, tpDist > 0 ? NormalizePrice(tick.ask + tpDist) : 0, comment)
                     : trade.Sell(vol, _Symbol, 0, slDist > 0 ? NormalizePrice(tick.bid + slDist) : 0, tpDist > 0 ? NormalizePrice(tick.bid - tpDist) : 0, comment);
        else
            ok = buy ? trade.BuyStop(vol, buyPrice, _Symbol, buySL, buyTP, timeType, 0, comment)
                     : trade.SellStop(vol, sellPrice, _Symbol, sellSL, sellTP, timeType, 0, comment);
        if(!ok || !OrderPlaced()) retryAfter = TimeCurrent() + 30;
        return;
    }
    bool buyOk = trade.BuyStop(vol, buyPrice, _Symbol, buySL, buyTP, timeType, 0, comment) && OrderPlaced();
    bool sellOk = buyOk && trade.SellStop(vol, sellPrice, _Symbol, sellSL, sellTP, timeType, 0, comment) && OrderPlaced();
    if(!buyOk || !sellOk)
    {
        DeletePendings();                                 // never leave half a pair
        retryAfter = TimeCurrent() + 30;
    }
}

// +------------------------------------------------------------------+
// | Break-even lock and trailing stop                                |
// | Once profit reaches BreakEvenTrigger the stop jumps to the entry |
// | plus BreakEvenLock (the stop triggers on the closing side of the |
// | spread, so the lock only has to cover slippage); the trailing    |
// | stop then takes over from TrailStart.                            |
// +------------------------------------------------------------------+
void TrailPositions()
{
    if(TrailDistance <= 0 && BreakEvenTrigger <= 0) return;
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick)) return;
    double minDist = StopsLevelDistance();
    double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
    double halfTick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) / 2;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(!IsOurs(PositionGetInteger(POSITION_MAGIC), PositionGetString(POSITION_SYMBOL))) continue;

        double unit = UnitFromComment(PositionGetString(POSITION_COMMENT));
        if(unit <= 0) unit = CurrentUnit();
        if(unit <= 0) continue;
        double dist = MathMax(TrailDistance * unit, minDist + _Point);
        double step = MathMax(TrailStep * unit, halfTick);
        double open = PositionGetDouble(POSITION_PRICE_OPEN);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);

        bool frozen = freeze > 0 && sl > 0 && MathAbs((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? tick.bid : tick.ask) - sl) <= freeze;
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            if(BreakEvenTrigger > 0 && !frozen && tick.bid - open >= BreakEvenTrigger * unit)
            {
                double beSL = NormalizePrice(open + BreakEvenLock * unit);
                if((sl == 0 || sl < beSL) && beSL < tick.bid - minDist && trade.PositionModify(ticket, beSL, tp)) sl = beSL;
            }
            if(TrailDistance <= 0) continue;
            if(tick.bid - open < TrailStart * unit) continue;
            double newSL = NormalizePrice(tick.bid - dist);
            if(sl > 0 && newSL < sl + step) continue;
            if(freeze > 0 && sl > 0 && tick.bid - sl <= freeze) continue;
            trade.PositionModify(ticket, newSL, tp);
        }
        else
        {
            if(BreakEvenTrigger > 0 && !frozen && open - tick.ask >= BreakEvenTrigger * unit)
            {
                double beSL = NormalizePrice(open - BreakEvenLock * unit);
                if((sl == 0 || sl > beSL) && beSL > tick.ask + minDist && trade.PositionModify(ticket, beSL, tp)) sl = beSL;
            }
            if(TrailDistance <= 0) continue;
            if(open - tick.ask < TrailStart * unit) continue;
            double newSL = NormalizePrice(tick.ask + dist);
            if(sl > 0 && newSL > sl - step) continue;
            if(freeze > 0 && sl > 0 && sl - tick.ask <= freeze) continue;
            trade.PositionModify(ticket, newSL, tp);
        }
    }
}

// +------------------------------------------------------------------+
// | Main logic                                                       |
// +------------------------------------------------------------------+
void Manage()
{
    int buyStops, sellStops;
    datetime oldest;
    int pendings = CountPendings(buyStops, sellStops, oldest);

    // A position is open: the other side of the pair must go (one cancels the other)
    if(CountPositions() > 0)
    {
        if(pendings > 0) DeletePendings();
        return;
    }

    // Losing-streak pause: nothing may wait to fill until it ends
    if(TimeCurrent() < pausedUntil)
    {
        if(pendings > 0) DeletePendings();
        return;
    }

    // Outside the sessions no pending order may wait to fill; in a calm market only if CancelWhenCalm
    bool inSession = InSession();
    if(!volatileNow || !inSession)
    {
        if(pendings > 0 && (!inSession || CancelWhenCalm)) DeletePendings();
        return;
    }

    if(pendings > 0)
    {
        bool incomplete = EntryMode == ENTRY_STRADDLE ? (buyStops != 1 || sellStops != 1) : pendings != 1;
        bool expired = PendingExpiryBars > 0 && iBarShift(_Symbol, _Period, oldest) >= PendingExpiryBars;
        if(incomplete || expired) DeletePendings();       // a fresh pair goes out on the next tick
        return;
    }

    if(TimeCurrent() < retryAfter) return;
    if(!MQLInfoInteger(MQL_TESTER) && (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))) return;
    PlacePair();
}

void ShowStatus()
{
    if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
    uint now = GetTickCount();
    if(now - lastStatusMs < 1000) return;
    lastStatusMs = now;
    string state = !volReady ? "waiting for ATR history"
                 : TimeCurrent() < pausedUntil ? "paused after a losing streak until " + TimeToString(pausedUntil, TIME_MINUTES)
                 : !InSession() ? "outside trading sessions - not trading"
                 : volatileNow ? "VOLATILE - straddle active"
                 : "calm - not trading";
    double ratio = atrNormal > 0 ? atrNow / atrNormal : 0;
    Comment(StringFormat("%s\nATR %s | normal %s | ratio %.2f (needs %.2f)\n%s ATR %s (needs %s)\n%s",
                         EA_TITLE, DoubleToString(atrNow, _Digits), DoubleToString(atrNormal, _Digits),
                         ratio, VolMinRatio, EnumToString(RegimeTimeframe), DoubleToString(regimeATR, _Digits),
                         RegimeMinATR > 0 ? DoubleToString(RegimeMinATR, 2) : "off", state));
}

// +------------------------------------------------------------------+
// | Backtest equity log (TesterEquityLog, Strategy Tester only)      |
// | Same file as Nyao Scalper's (Common/Files/nyao_equity.csv), so   |
// | tools/backtest/nyao_backtest.py draws its balance & equity       |
// | charts. Never writes on a live or demo chart.                    |
// +------------------------------------------------------------------+
int equityLogHandle = INVALID_HANDLE;
bool equityLogTried = false;
datetime equityLogBar = 0;
double equityLogMin = 0;

void EquityLogWrite(double minEq, double eq)
{
    FileWriteString(equityLogHandle, StringFormat("%s,%.2f,%.2f,%.2f\r\n", TimeToString(equityLogBar, TIME_DATE | TIME_MINUTES),
                    AccountInfoDouble(ACCOUNT_BALANCE), eq, minEq));
}

void EquityLogTick()
{
    if(!equityLogTried)
    {
        equityLogTried = true;
        if(!TesterEquityLog || !MQLInfoInteger(MQL_TESTER)) return;
        equityLogHandle = FileOpen("nyao_equity.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
        if(equityLogHandle != INVALID_HANDLE) FileWriteString(equityLogHandle, "time,balance,equity,min_equity\r\n");
    }
    if(equityLogHandle == INVALID_HANDLE) return;
    double eq = AccountInfoDouble(ACCOUNT_EQUITY);
    datetime bar = iTime(_Symbol, PERIOD_M5, 0);
    if(bar == 0) return;
    if(equityLogBar == 0) { equityLogBar = bar; equityLogMin = eq; }
    if(bar != equityLogBar)
    {
        EquityLogWrite(MathMin(equityLogMin, eq), eq);
        equityLogBar = bar;
        equityLogMin = eq;
    }
    else if(eq < equityLogMin) equityLogMin = eq;
}

void EquityLogStop()
{
    if(equityLogHandle == INVALID_HANDLE) return;
    double eq = AccountInfoDouble(ACCOUNT_EQUITY);
    if(equityLogBar != 0) EquityLogWrite(MathMin(equityLogMin, eq), eq);
    FileClose(equityLogHandle);
    equityLogHandle = INVALID_HANDLE;
}

// +------------------------------------------------------------------+
// | Event handlers                                                   |
// +------------------------------------------------------------------+
int OnInit()
{
    if(Lots <= 0 || EntryDistance <= 0 || VolATRPeriod < 1)
    {
        Print("Lot Size, Pending Order Distance and ATR Period must be above 0");
        return INIT_PARAMETERS_INCORRECT;
    }
    volTF = VolTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : VolTimeframe;
    atrHandle = iATR(_Symbol, volTF, VolATRPeriod);
    regimeHandle = iATR(_Symbol, RegimeTimeframe, MathMax(RegimeATRPeriod, 1));
    if(atrHandle == INVALID_HANDLE || regimeHandle == INVALID_HANDLE)
    {
        Print("Could not create the ATR indicators");
        return INIT_FAILED;
    }
    MathSrand(CoinFlipSeed);
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetTypeFillingBySymbol(_Symbol);
    trade.SetDeviationInPoints(10);
    trade.LogLevel(LOG_LEVEL_ERRORS);
    if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
        Print("Note: netting account - if both orders fill in one jump, the two fills offset each other");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    EquityLogStop();
    if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
    if(regimeHandle != INVALID_HANDLE) IndicatorRelease(regimeHandle);
    Comment("");
}

void OnTick()
{
    EquityLogTick();                                      // backtest balance & equity log (tester only)
    UpdateVolatility();
    TrailPositions();
    Manage();
    ShowStatus();
}

// Was the position this deal belongs to opened by this EA? (stop-loss closes may not carry the magic)
bool PositionWasOurs(long positionId)
{
    if(!HistorySelectByPosition(positionId)) return false;
    for(int i = 0; i < HistoryDealsTotal(); i++)
    {
        ulong d = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) return HistoryDealGetInteger(d, DEAL_MAGIC) == MagicNumber;
    }
    return false;
}

// One side filled: cancel the other at once instead of waiting for the next tick.
// A trade closed: count the losing streak and start a pause when it gets long enough.
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.symbol != _Symbol) return;
    if(!HistoryDealSelect(trans.deal)) return;
    long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
    long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
    if(entry == DEAL_ENTRY_IN)
    {
        if(magic == MagicNumber) DeletePendings();
        return;
    }
    if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;
    double pnl = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
               + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
    if(magic != MagicNumber && !PositionWasOurs(HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID))) return;
    lossStreak = pnl <= 0 ? lossStreak + 1 : 0;
    if(LossStreakPause > 0 && lossStreak >= LossStreakPause)
    {
        pausedUntil = TimeCurrent() + LossStreakPauseMinutes * 60;
        lossStreak = 0;
        DeletePendings();
    }
}
