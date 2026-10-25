// +------------------------------------------------------------------+
// | Nyao Straddle v1.6                                               |
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
#property version "1.6"
#property description "Gold M1 breakout straddle, extreme markets only (H1 ATR >= $34)"
#property description "Buy & sell stop $1 away; first fill cancels the other; $1 trail"
#property description ""
#property description "Open-source, for educational and experimental purposes only"
#property description "Source: https://github.com/elrizwiraswara/nyao_scalper_mt5 [BSD-3-Clause]"
#property description ""
#property description "EXPERIMENTAL - demo forward-test first. No guarantee of profit."
#property strict

#define EA_TITLE "Nyao Straddle v1.6"

#include <Trade\Trade.mqh>
#include <Generic\HashMap.mqh>

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

// +------------------------------------------------------------------+
// | Trade statistics for the dashboard                               |
// | One trade = one closed position of this EA (magic and symbol),   |
// | all of its deals summed (entry commission included), the way     |
// | Nyao Scalper counts them. One history scan when the dashboard    |
// | first draws, then each position is added when it closes.         |
// +------------------------------------------------------------------+
struct TradeStats
{
    int count;
    int won;
    int lost;
    double profit;                                        // sum of winning trades
    double loss;                                          // sum of losing trades (negative)
};
TradeStats stats;
bool statsReady = false;                                  // false until the first history scan

void AddTrade(double net)
{
    stats.count++;
    if(net >= 0) { stats.won++; stats.profit += net; }
    else { stats.lost++; stats.loss += net; }
}

void LoadTradeStats()
{
    ZeroMemory(stats);
    statsReady = true;
    if(!HistorySelect(0, TimeCurrent() + 86400)) return;
    CHashMap<long, int> index;
    double net[];
    bool ours[];
    bool closed[];
    int n = 0;
    int deals = HistoryDealsTotal();
    for(int i = 0; i < deals; i++)
    {
        ulong d = HistoryDealGetTicket(i);
        if(d == 0 || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
        long type = HistoryDealGetInteger(d, DEAL_TYPE);
        if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL) continue;
        long pos = HistoryDealGetInteger(d, DEAL_POSITION_ID);
        int k;
        if(!index.TryGetValue(pos, k))
        {
            k = n++;
            ArrayResize(net, n, 1000);
            ArrayResize(ours, n, 1000);
            ArrayResize(closed, n, 1000);
            net[k] = 0;
            ours[k] = false;
            closed[k] = false;
            index.Add(pos, k);
        }
        net[k] += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
        long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
        if(entry == DEAL_ENTRY_IN) ours[k] = HistoryDealGetInteger(d, DEAL_MAGIC) == MagicNumber;
        else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) closed[k] = true;
    }
    for(int k = 0; k < n; k++)
        if(ours[k] && closed[k]) AddTrade(net[k]);
}

// A position of this EA closed: add its net result (all of its deals) once it is fully closed
void AddClosedPosition(long positionId)
{
    if(!statsReady || PositionSelectByTicket(positionId)) return;
    if(!HistorySelectByPosition(positionId)) return;
    double net = 0;
    for(int i = 0; i < HistoryDealsTotal(); i++)
    {
        ulong d = HistoryDealGetTicket(i);
        net += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
    }
    AddTrade(net);
}

// +------------------------------------------------------------------+
// | On-chart dashboard (the same panel as Nyao Scalper's)            |
// +------------------------------------------------------------------+
#define DASH "NyaoStraddleDash_"
int dashTextRight = 0;                                    // right edge (px) of the widest label this redraw
double peakEquity = 0;                                    // highest equity seen since the EA started

void DrawDashboardLabel(string name, string text, int x, int y, int fontSize, color clr, bool bold = false)
{
    name = DASH + name;
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
    string name = DASH + "Bg";
    if(ObjectFind(0, name) < 0)
    {
        ObjectsDeleteAll(0, DASH);                        // labels made before the panel would sit under it
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

// $1.23 / -$1.23
string Usd(double v)
{
    return (v < 0 ? "-$" : "$") + DoubleToString(MathAbs(v), 2);
}

// A price or price distance with the symbol's digits
string Price(double v)
{
    return DoubleToString(v, _Digits);
}

// "H1" instead of "PERIOD_H1"
string TfName(ENUM_TIMEFRAMES tf)
{
    string s = EnumToString(tf == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : tf);
    StringReplace(s, "PERIOD_", "");
    return s;
}

bool TradingAllowed()
{
    return MQLInfoInteger(MQL_TESTER) || (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED));
}

int PauseMinutesLeft()
{
    return (int)((pausedUntil - TimeCurrent() + 59) / 60);
}

// The first check that keeps a new pair from going out, in the order Manage() applies them. "" = ready.
string DashboardGate(int pendings)
{
    if(!volReady) return "waiting for ATR history";
    if(TimeCurrent() < pausedUntil) return StringFormat("losing-streak pause, %d min left", PauseMinutesLeft());
    if(!InSession()) return "outside the trading sessions";
    if(RegimeMinATR > 0 && regimeATR < RegimeMinATR)
        return StringFormat("calm market: %s ATR %s < %s", TfName(RegimeTimeframe), Price(regimeATR), Price(RegimeMinATR));
    if(VolMinRatio > 0 && (atrNormal <= 0 || atrNow < VolMinRatio * atrNormal))
        return StringFormat("not speeding up: %.2fx < %.2fx", atrNormal > 0 ? atrNow / atrNormal : 0, VolMinRatio);
    if(VolMinATR > 0 && atrNow < VolMinATR) return StringFormat("ATR %s < VolMinATR %s", Price(atrNow), Price(VolMinATR));
    if(pendings > 0) return "";
    if(!TradingAllowed()) return "algo trading is off";
    MqlTick tick;
    if(MaxSpread > 0 && SymbolInfoTick(_Symbol, tick) && tick.ask - tick.bid > MaxSpread)
        return StringFormat("spread %s > cap %s", Price(tick.ask - tick.bid), Price(MaxSpread));
    if(TimeCurrent() < retryAfter) return StringFormat("retry in %ds after a failed order", (int)(retryAfter - TimeCurrent()));
    return "";
}

// A calm or slow market is the normal waiting state (gray); anything else needs attention (orange)
color GateColor(string gate)
{
    if(gate == "") return clrLime;
    if(StringFind(gate, "calm market") == 0 || StringFind(gate, "not speeding up") == 0
       || StringFind(gate, "outside the trading") == 0 || StringFind(gate, "waiting for ATR") == 0) return clrGray;
    return clrOrange;
}

void UpdateDashboard()
{
    // Nobody can see the chart in a non-visual backtest / optimization - skip the work
    if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;

    // Redraw at most once per second
    uint nowMs = GetTickCount();
    if(lastStatusMs != 0 && nowMs - lastStatusMs < 1000) return;
    lastStatusMs = nowMs;

    if(!statsReady) LoadTradeStats();
    Comment("");

    // Background first, so every label is drawn on top of it (sized to the content at the end)
    if(ObjectFind(0, DASH + "Bg") < 0) DrawDashboardBackground(10, 10, 10, 10, C'30,30,30', clrGold);
    dashTextRight = 0;

    // Layout and colours of Nyao Scalper's dashboard
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
    int currentY = startY;

    // Header
    DrawDashboardLabel("Title", EA_TITLE, startX, currentY, 11, colorHeader, true);
    currentY += lineHeight + 5;

    // Status (waiting for data, then blocks and pauses, then the session)
    string status = "Active";
    color statusColor = clrLime;
    if(!volReady) { status = "Waiting for ATR history"; statusColor = clrGray; }
    else if(!TradingAllowed()) { status = "No Entries (Algo Trading Off)"; statusColor = clrOrange; }
    else if(TimeCurrent() < pausedUntil) { status = StringFormat("PAUSED: losing streak (%dm)", PauseMinutesLeft()); statusColor = clrOrange; }
    else if(!InSession()) { status = "Closed (Session)"; statusColor = clrGray; }
    DrawDashboardLabel("Status", "Status: " + status, startX, currentY, textsize, statusColor, true);
    currentY += lineHeight;

    if(EntryMode != ENTRY_STRADDLE)
    {
        DrawDashboardLabel("Mode", EntryMode == ENTRY_COIN_MARKET ? "Mode: coin flip, market orders (research test)"
                                                                  : "Mode: coin flip, one stop order (research test)",
                           startX, currentY, textsize, clrOrange);
        currentY += lineHeight;
    }
    else ObjectDelete(0, DASH + "Mode");

    // Account
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    peakEquity = MathMax(peakEquity, equity);
    double equityDrop = peakEquity > 0 ? (peakEquity - equity) / peakEquity * 100.0 : 0;
    DrawDashboardLabel("Bal", "Balance: " + Usd(balance), startX, currentY, textsize, colorText);
    currentY += lineHeight;
    DrawDashboardLabel("Eq", "Equity: " + Usd(equity), startX, currentY, textsize, colorText);
    currentY += lineHeight;
    DrawDashboardLabel("Peak", "Peak: " + Usd(peakEquity) + StringFormat(" (Drop: %.1f%%, since start)", equityDrop),
                       startX, currentY, textsize, colorText);
    currentY += lineHeight + 5;

    // Market filters: the lot, the two ATR conditions and the first check that blocks a new pair
    DrawDashboardLabel("FiltHead", "MARKET FILTERS:", startX, currentY, headersize, colorHeader, true);
    currentY += lineHeight;

    string lotText = "Lot: waiting for ATR history";
    double unit = CurrentUnit();
    if(unit > 0)
    {
        double minDist = StopsLevelDistance() + _Point;
        double slDist = StopLoss > 0 ? MathMax(StopLoss * unit, minDist) : TrailDistance * unit;
        double vol = LotSize(slDist);
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
        if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double risk = tickSize > 0 ? vol * slDist / tickSize * tickValue : 0;
        lotText = StringFormat("Lot: %.2f (%s, risks %s = %.2f%% at the stop)", vol, RiskPercent > 0 ? "risk-sized" : "fixed",
                               Usd(risk), equity > 0 ? 100.0 * risk / equity : 0);
    }
    DrawDashboardLabel("Lot", lotText, startX, currentY, detailsSize, colorText);
    currentY += lineHeight;

    bool regimeOk = RegimeMinATR <= 0 || regimeATR >= RegimeMinATR;
    DrawDashboardLabel("Regime", RegimeMinATR > 0 ? StringFormat("EXTREME MARKET: %s ATR %s", TfName(RegimeTimeframe), Price(regimeATR))
                                                  : "EXTREME MARKET: off",
                       startX, currentY, textsize, volReady && regimeOk ? colorBuy : colorText, true);
    currentY += lineHeight;
    DrawDashboardLabel("RegimeNeed", RegimeMinATR > 0 ? StringFormat("Need: >= %s (ATR %d of the last closed bar)", Price(RegimeMinATR), RegimeATRPeriod)
                                                      : "Need: nothing (RegimeMinATR = 0)",
                       startX, currentY, detailsSize, colorText);
    currentY += lineHeight;

    double ratio = atrNormal > 0 ? atrNow / atrNormal : 0;
    bool speedOk = (VolMinRatio <= 0 || ratio >= VolMinRatio) && (VolMinATR <= 0 || atrNow >= VolMinATR);
    DrawDashboardLabel("Speed", VolMinRatio > 0 ? StringFormat("SPEED-UP: %.2fx normal", ratio) : "SPEED-UP: off",
                       startX, currentY, textsize, volReady && speedOk ? colorBuy : colorText, true);
    currentY += lineHeight;
    DrawDashboardLabel("SpeedNeed", StringFormat("Need: >= %.2fx | %s ATR(%d) %s vs avg %s (%d bars)", VolMinRatio, TfName(volTF),
                                                 VolATRPeriod, Price(atrNow), Price(atrNormal), VolBaseBars),
                       startX, currentY, detailsSize, colorText);
    currentY += lineHeight;

    // Our position and pending orders
    int buyStops, sellStops;
    datetime oldest;
    int pendings = CountPendings(buyStops, sellStops, oldest);
    bool inTrade = false;
    string posText = "Position: none";
    color posColor = colorText;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) == 0) continue;
        if(!IsOurs(PositionGetInteger(POSITION_MAGIC), PositionGetString(POSITION_SYMBOL))) continue;
        double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        posText = StringFormat("Position: %s %.2f @ %s | SL %s | %s%s",
                               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL", PositionGetDouble(POSITION_VOLUME),
                               Price(PositionGetDouble(POSITION_PRICE_OPEN)), Price(PositionGetDouble(POSITION_SL)),
                               pl >= 0 ? "+" : "", Usd(pl));
        posColor = pl >= 0 ? colorBuy : colorSell;
        inTrade = true;
        break;
    }
    double buyStopPrice = 0, sellStopPrice = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0 || !IsOurs(OrderGetInteger(ORDER_MAGIC), OrderGetString(ORDER_SYMBOL))) continue;
        if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) buyStopPrice = OrderGetDouble(ORDER_PRICE_OPEN);
        if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP) sellStopPrice = OrderGetDouble(ORDER_PRICE_OPEN);
    }

    string gate = inTrade ? "" : DashboardGate(pendings);
    string gateText = inTrade ? "> In trade: the trailing stop exits, then a new pair"
                    : gate != "" ? "> Blocked: " + gate
                    : pendings > 0 ? (EntryMode == ENTRY_STRADDLE ? "> Ready: buy stop + sell stop waiting" : "> Ready: stop order waiting")
                    : "> Ready: places a pair now";
    DrawDashboardLabel("Gate", gateText, startX, currentY, detailsSize, GateColor(gate));
    currentY += lineHeight + 10;

    DrawDashboardLabel("OrdHead", "ORDERS:", startX, currentY, headersize, colorHeader, true);
    currentY += lineHeight;
    DrawDashboardLabel("Pos", posText, startX, currentY, textsize, posColor, inTrade);
    currentY += lineHeight;
    string pendText = pendings == 0 ? "Pending: none"
                    : StringFormat("Buy stop: %s | Sell stop: %s", buyStopPrice > 0 ? Price(buyStopPrice) : "-",
                                   sellStopPrice > 0 ? Price(sellStopPrice) : "-");
    DrawDashboardLabel("Pend", pendText, startX, currentY, textsize, colorText);
    currentY += lineHeight;
    DrawDashboardLabel("Streak", LossStreakPause > 0 ? StringFormat("Loss streak: %d / %d (then a %d min pause)", lossStreak, LossStreakPause, LossStreakPauseMinutes)
                                                     : StringFormat("Loss streak: %d (pause off)", lossStreak),
                       startX, currentY, textsize, colorText);
    currentY += lineHeight + 10;

    // Statistics, as on Nyao Scalper's dashboard
    double netProfit = stats.profit + stats.loss;
    DrawDashboardLabel("StatHead", "STATISTICS:", startX, currentY, headersize, colorHeader, true);
    currentY += lineHeight;
    DrawDashboardLabel("Trades", StringFormat("Trades: %d (W:%d / L:%d)", stats.count, stats.won, stats.lost), startX, currentY, textsize, colorText);
    currentY += lineHeight;
    DrawDashboardLabel("PL", "Profit: " + Usd(stats.profit) + " | Loss: " + Usd(stats.loss), startX, currentY, textsize, colorText);
    currentY += lineHeight;
    DrawDashboardLabel("AvgWL", "Avg Win: " + Usd(stats.won > 0 ? stats.profit / stats.won : 0)
                                + " | Avg Loss: " + Usd(stats.lost > 0 ? stats.loss / stats.lost : 0), startX, currentY, textsize, colorText);
    currentY += lineHeight;
    double expectancy = stats.count > 0 ? netProfit / stats.count : 0;
    string pf = stats.loss < 0 ? DoubleToString(stats.profit / -stats.loss, 2) : stats.profit > 0 ? "inf" : "-";
    DrawDashboardLabel("Expect", "Expectancy: " + Usd(expectancy) + "/trade | PF: " + pf, startX, currentY, textsize,
                       expectancy >= 0 ? colorText : colorSell);
    currentY += lineHeight;
    DrawDashboardLabel("Net", "NET PROFIT: " + Usd(netProfit), startX, currentY, textsize, netProfit >= 0 ? colorBuy : colorSell, true);

    // Panel around everything drawn above
    int pad = 10;
    DrawDashboardBackground(startX - pad, startY - pad, dashTextRight - startX + 2 * pad,
                            currentY + lineHeight - startY + 2 * pad, C'30,30,30', clrGold);
    ChartRedraw(0);
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
    ObjectsDeleteAll(0, DASH);
    Comment("");
}

void OnTick()
{
    EquityLogTick();                                      // backtest balance & equity log (tester only)
    UpdateVolatility();
    TrailPositions();
    Manage();
    UpdateDashboard();                                    // on-chart dashboard (once per second, visual only)
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
// A trade closed: add it to the statistics, count the losing streak and start a pause when it gets long enough.
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
    long positionId = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
    if(magic != MagicNumber && !PositionWasOurs(positionId)) return;
    AddClosedPosition(positionId);                        // dashboard statistics
    lossStreak = pnl <= 0 ? lossStreak + 1 : 0;
    if(LossStreakPause > 0 && lossStreak >= LossStreakPause)
    {
        pausedUntil = TimeCurrent() + LossStreakPauseMinutes * 60;
        lossStreak = 0;
        DeletePendings();
    }
}
