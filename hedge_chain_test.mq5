//+------------------------------------------------------------------+
//|                                            hedge_chain_test.mq5   |
//|              Minimal harness to test the Rolling Hedge Chain      |
//|                                                                   |
//|  Scope (intentionally tiny):                                      |
//|   - Entry: open ONE position in the direction of the last closed  |
//|            candle (bullish=BUY, bearish=SELL) when flat.           |
//|   - Hedge Chain: rolling martingale recovery, FIXED-DOLLAR        |
//|     trigger / sizing (no ATR, no scoring, no loss mgmt).          |
//|                                                                   |
//|  Rolling pair (at most 2 chain legs open):                        |
//|   - COVERED : hedge profit >= HedgeRecoveryPct% of older leg's    |
//|               current loss -> close older, graduate hedge (trail). |
//|   - ROLL    : hedge losing AND older recovered to >= roll min ->   |
//|               close older (free), open a bigger reverse hedge,     |
//|               up to HedgeCycleLevels per cycle.                    |
//|   - RESEED  : at the cycle level limit OR lot ceiling -> close     |
//|               older, partial-close the deepest hedge by            |
//|               HedgeCyclePartialPct%, and start a NEW cycle from    |
//|               the reduced leg (up to HedgeMaxCycles cycles).       |
//|   - STOP    : combined chain loss >= HedgeMaxChainLoss($/%) -> close|
//|                                                                   |
//|  REQUIRES a HEDGING account (multiple opposite positions).        |
//+------------------------------------------------------------------+
#property copyright "Nyao Scalper - Hedge Chain Test"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//--- Entry ----------------------------------------------------------
input group "Entry (candle direction)"
input double BaseLotSize        = 0.01;   // First position lot size
input bool   NewBarEntryOnly    = true;   // Open entries only on a new bar
input bool   OnlyOneChainAtTime = true;   // Open a new entry only when flat (one chain at a time)

//--- Hedge Chain ----------------------------------------------------
input group "Hedge Chain (Rolling Martingale - fixed $)"
input bool   EnableHedgeChain      = true;   // Enable the rolling hedge chain
input double HedgeTriggerLossUSD   = 2.0;    // Start chain when first position loss reaches this $
input bool   HedgeAutoLot          = true;   // Auto-size hedge to recover (else fixed multiplier)
input double HedgeRecoveryWindowUSD= 2.0;    // $ the older leg may lose before hedge covers (smaller=bigger hedge)
input double HedgeLotMultiplier    = 2.0;    // Fixed hedge multiplier (used when Auto-size OFF / fallback)
input double HedgeRecoveryPct      = 100.0;  // Close older when hedge covers this % of its loss
input double HedgeRollMinProfit    = 0.0;    // Min older-leg profit ($) to roll to next hedge
input double HedgeMaxLot           = 0.4;    // Hard lot ceiling per hedge leg
input double HedgeMaxChainLossUSD  = 0.0;    // Close whole chain if combined loss >= this $ (0 = Off)
input double HedgeMaxChainLossPct  = 50.0;   // Close whole chain if combined loss >= this % of equity (0 = Off)

//--- Hedge Cycle (limit roll depth, then reseed smaller) -----------
input group "Hedge Cycle"
input int    HedgeCycleLevels      = 2;      // Max hedge levels per cycle (A->L1->..->Ln) before reseed
input bool   EnableHedgeCycleReset = true;   // At cycle/lot limit: partial-close & reseed a new cycle (else close chain)
input double HedgeCyclePartialPct  = 50.0;   // % of deepest hedge to close at reseed
input int    HedgeMaxCycles        = 3;      // Max cycles before giving up & closing chain (0 = Unlimited)

//--- Trailing (for graduated / free profitable legs) ---------------
input group "Trailing (graduated leg)"
input bool   EnableTrailing     = true;   // Trail free/graduated profitable legs
input double TrailStartUSD       = 1.0;    // Start trailing after this profit ($)
input double TrailGapUSD         = 0.5;    // Trailing lock-in gap ($)

//--- Robot ----------------------------------------------------------
input group "Robot"
input int    MagicNumber        = 555001; // Magic Number
input bool   EnableLogging      = true;    // Print chain events to the Experts log

//--- State ----------------------------------------------------------
struct Leg
{
    ulong  ticket;        // position ticket
    ulong  chainId;       // 0 = free/standalone leg; else id of the chain (current cycle's root ticket)
    int    level;         // 0 = cycle root, 1+ = each successive hedge within the cycle
    double anchorLoss;    // cycle start loss ($, positive) carried on every leg of the cycle
    int    cycleNum;      // which cycle this leg belongs to (0 = first; +1 on each reseed)
};
Leg      legs[];
datetime lastBarTime = 0;

#define LogPrint if(EnableLogging) Print

//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetTypeFillingBySymbol(_Symbol);
    trade.SetDeviationInPoints(20);

    if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
        Print("WARNING: This EA needs a HEDGING account to hold opposite positions. Current account is NETTING.");

    Print("Hedge Chain Test EA initialized on ", _Symbol, " ", EnumToString(_Period));
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
void OnTick()
{
    SyncLegs();                      // drop closed tickets
    if(EnableHedgeChain) ManageChains();
    TrailFreeLegs();
    TryEntry();
}

//+------------------------------------------------------------------+
//| Entry: open one candle-direction position when allowed           |
//+------------------------------------------------------------------+
void TryEntry()
{
    // New-bar gate
    datetime t0 = iTime(_Symbol, _Period, 0);
    bool isNewBar = (t0 != lastBarTime);
    if(NewBarEntryOnly && !isNewBar) return;
    lastBarTime = t0;

    if(OnlyOneChainAtTime && CountOurPositions() > 0) return;

    // Direction of the last closed candle
    double o = iOpen(_Symbol, _Period, 1);
    double c = iClose(_Symbol, _Period, 1);
    if(c == o) return;                               // doji - skip

    ENUM_ORDER_TYPE type = (c > o) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    OpenMarket(type, BaseLotSize, 0, 0, 0, 0, "Entry");
}

//+------------------------------------------------------------------+
//| Manage rolling hedge chains                                      |
//+------------------------------------------------------------------+
void ManageChains()
{
    // ---- Distinct chain ids ----
    ulong ids[]; int n = 0;
    for(int i = 0; i < ArraySize(legs); i++)
    {
        ulong id = legs[i].chainId;
        if(id == 0) continue;
        bool seen = false;
        for(int k = 0; k < n; k++) if(ids[k] == id) { seen = true; break; }
        if(!seen) { ArrayResize(ids, n + 1); ids[n++] = id; }
    }

    // ---- Phase A: manage each chain (older vs hedge) ----
    for(int c = 0; c < n; c++)
    {
        ulong id = ids[c];
        ulong olderT = 0, hedgeT = 0;
        int   olderLv = INT_MAX, hedgeLv = -1;
        double olderPL = 0, hedgePL = 0, hedgeLot = 0, anchor = 0, total = 0;
        int openLegs = 0;
        int cycleNum = 0;
        ENUM_POSITION_TYPE hedgeType = POSITION_TYPE_BUY;

        for(int i = 0; i < ArraySize(legs); i++)
        {
            if(legs[i].chainId != id) continue;
            if(!PositionSelectByTicket(legs[i].ticket)) continue;
            openLegs++;
            double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            total += pl;
            if(legs[i].anchorLoss > 0) anchor = legs[i].anchorLoss;
            cycleNum = legs[i].cycleNum;
            int lv = legs[i].level;
            if(lv < olderLv) { olderLv = lv; olderT = legs[i].ticket; olderPL = pl; }
            if(lv > hedgeLv)
            {
                hedgeLv  = lv;
                hedgeT   = legs[i].ticket;
                hedgePL  = pl;
                hedgeLot = PositionGetDouble(POSITION_VOLUME);
                hedgeType= (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            }
        }

        if(openLegs == 0) continue;
        if(openLegs == 1) { if(hedgeT != 0) Graduate(hedgeT); continue; }  // orphan -> free it

        // COVERED: hedge profit covers the older leg's current loss
        if(olderPL < 0)
        {
            double need = (HedgeRecoveryPct / 100.0) * (-olderPL);
            if(hedgePL >= need)
            {
                LogPrint(StringFormat("[COVERED] chain %I64u: hedge %I64u +%.2f covers older %I64u loss %.2f -> close older, trail hedge",
                                      id, hedgeT, hedgePL, olderT, -olderPL));
                ClosePos(olderT);
                Graduate(hedgeT);
                continue;
            }
        }

        // ROLL: hedge losing AND older recovered -> close older, open a bigger reverse hedge.
        if(hedgePL < 0 && olderPL >= HedgeRollMinProfit)
        {
            // A normal roll needs BOTH: room in the cycle (level cap) AND a strictly
            // larger hedge (lot ceiling). If either fails, reseed a new cycle instead.
            bool   levelOk = (hedgeLv < HedgeCycleLevels);
            double newLot  = levelOk ? ComputeHedgeLot(hedgeLot, -hedgePL) : 0;
            bool   lotOk   = (newLot > hedgeLot);

            if(levelOk && lotOk)
            {
                LogPrint(StringFormat("[ROLL] chain %I64u cyc%d: older %I64u +%.2f recovered, hedge %I64u %.2f losing -> close older, open L%d lot %.2f",
                                      id, cycleNum, olderT, olderPL, hedgeT, hedgePL, hedgeLv + 1, newLot));
                ClosePos(olderT);
                OpenMarket(Reverse(hedgeType), newLot, id, hedgeLv + 1, anchor, cycleNum, "Hedge L" + IntegerToString(hedgeLv + 1));
                continue;
            }

            // Cannot roll within this cycle (level cap or lot ceiling) -> reseed or stop.
            string why = (!levelOk) ? "cycle level limit" : "lot ceiling";
            bool cyclesLeft = (HedgeMaxCycles <= 0 || cycleNum + 1 < HedgeMaxCycles);

            if(EnableHedgeCycleReset && cyclesLeft)
            {
                LogPrint(StringFormat("[RESEED] chain %I64u cyc%d: %s reached -> partial-close hedge, start new cycle",
                                      id, cycleNum, why));
                if(!ReseedCycle(id, olderT, hedgeT, hedgeLot, hedgeType, cycleNum))
                {
                    LogPrint(StringFormat("[RESEED FAILED] chain %I64u: cannot reduce hedge -> close chain", id));
                    CloseChain(id);
                }
                continue;
            }
            else
            {
                LogPrint(StringFormat("[GIVE UP] chain %I64u cyc%d: %s, %s -> close chain",
                                      id, cycleNum, why,
                                      (!EnableHedgeCycleReset ? "reseed disabled" : "max cycles reached")));
                CloseChain(id);
                continue;
            }
        }

        // STOP: combined chain loss exceeds the backstop ($ and/or % of equity).
        // When both are set, the tighter (smaller) threshold wins.
        double stopThr = ChainLossStopThreshold();
        if(stopThr > 0 && total <= -stopThr)
        {
            LogPrint(StringFormat("[STOP] chain %I64u: total %.2f <= -%.2f -> close all (%d legs)",
                                  id, total, stopThr, openLegs));
            CloseChain(id);
            continue;
        }
        // else hold
    }

    // ---- Phase B: start a chain for a free leg whose loss crossed the trigger ----
    for(int i = 0; i < ArraySize(legs); i++)
    {
        if(legs[i].chainId != 0) continue;
        if(!PositionSelectByTicket(legs[i].ticket)) continue;

        double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        if(pl >= 0) continue;
        if(-pl < HedgeTriggerLossUSD) continue;

        double lot = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double anchor = -pl;

        double hLot = ComputeHedgeLot(lot, anchor);
        if(hLot <= lot)
        {
            LogPrint(StringFormat("[SKIP START] leg %I64u: hedge lot %.2f not > position lot %.2f (HedgeMaxLot %.2f)",
                                  legs[i].ticket, hLot, lot, HedgeMaxLot));
            continue;
        }

        legs[i].chainId    = legs[i].ticket;
        legs[i].level      = 0;
        legs[i].anchorLoss = anchor;
        legs[i].cycleNum   = 0;

        LogPrint(StringFormat("[START] leg %I64u loss %.2f >= trigger %.2f -> open hedge L1 lot %.2f",
                              legs[i].ticket, anchor, HedgeTriggerLossUSD, hLot));
        OpenMarket(Reverse(pt), hLot, legs[i].ticket, 1, anchor, 0, "Hedge L1");
    }
}

//+------------------------------------------------------------------+
//| Hedge lot to recover the older leg (fixed-dollar sizing)         |
//|   auto:  lot = olderLot * p * (1 + loss / recoveryWindow)         |
//|   fixed: lot = olderLot * HedgeLotMultiplier                      |
//| Floored strictly above the older leg, clamped to HedgeMaxLot.     |
//+------------------------------------------------------------------+
double ComputeHedgeLot(double olderLot, double olderLoss)
{
    double p = HedgeRecoveryPct / 100.0;
    if(p <= 0) p = 1.0;

    double lot = 0;
    if(HedgeAutoLot && HedgeRecoveryWindowUSD > 0)
        lot = olderLot * p * (1.0 + olderLoss / HedgeRecoveryWindowUSD);

    if(lot <= 0) lot = olderLot * HedgeLotMultiplier;   // fixed mode / fallback

    // Must exceed the older leg or the opposite-direction pair freezes.
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(step <= 0) step = 0.01;
    double minLot = olderLot + step;
    if(lot < minLot) lot = minLot;

    if(HedgeMaxLot > 0 && lot > HedgeMaxLot) lot = HedgeMaxLot;
    return NormalizeLot(lot);
}

//+------------------------------------------------------------------+
//| Trailing for free/graduated profitable legs                      |
//+------------------------------------------------------------------+
void TrailFreeLegs()
{
    if(!EnableTrailing) return;

    for(int i = 0; i < ArraySize(legs); i++)
    {
        if(legs[i].chainId != 0) continue;                   // chain legs are managed by ManageChains
        ulong t = legs[i].ticket;
        if(!PositionSelectByTicket(t)) continue;

        double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        if(pl < TrailStartUSD) continue;

        ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double lot   = PositionGetDouble(POSITION_VOLUME);
        double curSL = PositionGetDouble(POSITION_SL);
        double curTP = PositionGetDouble(POSITION_TP);
        double gap   = UsdToPrice(TrailGapUSD, lot);
        if(gap <= 0) continue;

        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        long   stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
        double minDist = stopLevel * _Point;

        if(pt == POSITION_TYPE_BUY)
        {
            double newSL = bid - gap;
            if(newSL > bid - minDist) newSL = bid - minDist;
            if((curSL == 0 || newSL > curSL + _Point) && newSL < bid)
                trade.PositionModify(t, NormalizeDouble(newSL, _Digits), curTP);
        }
        else
        {
            double newSL = ask + gap;
            if(newSL < ask + minDist) newSL = ask + minDist;
            if((curSL == 0 || newSL < curSL - _Point) && newSL > ask)
                trade.PositionModify(t, NormalizeDouble(newSL, _Digits), curTP);
        }
    }
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE Reverse(ENUM_POSITION_TYPE pt)
{
    return (pt == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
}

ulong OpenMarket(ENUM_ORDER_TYPE type, double lot, ulong chainId, int level, double anchor, int cycleNum, string tag)
{
    lot = NormalizeLot(lot);
    bool ok = (type == ORDER_TYPE_BUY)
              ? trade.Buy(lot, _Symbol, 0, 0, 0, tag)
              : trade.Sell(lot, _Symbol, 0, 0, 0, tag);

    if(!ok)
    {
        LogPrint("Open failed (", (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), " ", DoubleToString(lot, 2),
                 ") retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
        return 0;
    }

    ulong t = trade.ResultOrder();                 // position ticket on a hedging account
    RegisterLeg(t, chainId, level, anchor, cycleNum);
    LogPrint(StringFormat("Opened %s %.2f tkt %I64u | chain %I64u cyc%d L%d | %s",
                          (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), lot, t, chainId, cycleNum, level, tag));
    return t;
}

void RegisterLeg(ulong ticket, ulong chainId, int level, double anchor, int cycleNum)
{
    int sz = ArraySize(legs);
    ArrayResize(legs, sz + 1);
    legs[sz].ticket     = ticket;
    legs[sz].chainId    = chainId;
    legs[sz].level      = level;
    legs[sz].anchorLoss = anchor;
    legs[sz].cycleNum   = cycleNum;
}

void RemoveLeg(int index)
{
    int sz = ArraySize(legs);
    if(index < 0 || index >= sz) return;
    for(int j = index; j < sz - 1; j++) legs[j] = legs[j + 1];
    ArrayResize(legs, sz - 1);
}

int GetLegIndex(ulong ticket)
{
    for(int i = 0; i < ArraySize(legs); i++) if(legs[i].ticket == ticket) return i;
    return -1;
}

// Clear chain membership so the leg is managed by trailing only (covered exit / orphan).
void Graduate(ulong ticket)
{
    int idx = GetLegIndex(ticket);
    if(idx == -1) return;
    legs[idx].chainId    = 0;
    legs[idx].level      = 0;
    legs[idx].anchorLoss = 0;
    legs[idx].cycleNum   = 0;
}

// +------------------------------------------------------------------+
// | Reseed a new cycle when a roll can't proceed.                    |
// | Closes the (recovered) older leg, partially closes the deepest   |
// | hedge by HedgeCyclePartialPct%, makes the reduced hedge the      |
// | level-0 root of a NEW cycle, and opens a fresh L1 to recover it. |
// | Returns false if the hedge can't be reduced (caller closes all). |
// +------------------------------------------------------------------+
bool ReseedCycle(ulong id, ulong olderT, ulong hedgeT, double hedgeLot, ENUM_POSITION_TYPE hedgeType, int cycleNum)
{
    double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(step <= 0) step = 0.01;

    // Volume to close off the deepest hedge (rounded down to a step)
    double closeVol = MathFloor((hedgeLot * HedgeCyclePartialPct / 100.0) / step) * step;
    double remaining = hedgeLot - closeVol;

    // Keep at least the minimum lot on each side of the partial close
    if(remaining < minL)
    {
        closeVol  = MathFloor((hedgeLot - minL) / step) * step;
        remaining = hedgeLot - closeVol;
    }
    if(closeVol < minL || remaining < minL)
        return false;                                   // can't reduce meaningfully

    // 1) Close the recovered older leg (free / near breakeven)
    if(olderT != 0) ClosePos(olderT);

    // 2) Partial-close the deepest hedge (locks part of its loss, shrinks exposure)
    if(!trade.PositionClosePartial(hedgeT, closeVol))
    {
        LogPrint("[RESEED] partial close failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
        return false;
    }

    // 3) Re-read the reduced hedge -> it becomes the new cycle's level-0 root
    if(!PositionSelectByTicket(hedgeT)) return false;
    double remLot = PositionGetDouble(POSITION_VOLUME);
    double remPL  = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
    double newAnchor = (remPL < 0) ? -remPL : (HedgeTriggerLossUSD > 0 ? HedgeTriggerLossUSD : 1.0);

    int idx = GetLegIndex(hedgeT);
    if(idx == -1) return false;
    legs[idx].chainId    = hedgeT;                       // new cycle id = this ticket
    legs[idx].level      = 0;
    legs[idx].anchorLoss = newAnchor;
    legs[idx].cycleNum   = cycleNum + 1;

    LogPrint(StringFormat("[RESEED] new cycle %d: closed older %I64u, closed %.2f of hedge %I64u (remain %.2f), anchor %.2f",
                          cycleNum + 1, olderT, closeVol, hedgeT, remLot, newAnchor));

    // 4) Open a fresh L1 hedge to recover the reduced root
    double hLot = ComputeHedgeLot(remLot, newAnchor);
    if(hLot > remLot)
        OpenMarket(Reverse(hedgeType), hLot, hedgeT, 1, newAnchor, cycleNum + 1, "Hedge L1 (cyc" + IntegerToString(cycleNum + 1) + ")");
    else
        LogPrint("[RESEED] reduced root still can't be hedged within the lot ceiling - holding it as a free/trailed leg.");

    return true;
}

void ClosePos(ulong ticket)
{
    if(PositionSelectByTicket(ticket)) trade.PositionClose(ticket);
}

void CloseChain(ulong chainId)
{
    for(int i = ArraySize(legs) - 1; i >= 0; i--)
        if(legs[i].chainId == chainId)
            ClosePos(legs[i].ticket);
}

// Remove legs whose position no longer exists
void SyncLegs()
{
    for(int i = ArraySize(legs) - 1; i >= 0; i--)
        if(!PositionSelectByTicket(legs[i].ticket))
            RemoveLeg(i);
}

int CountOurPositions()
{
    int cnt = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong t = PositionGetTicket(i);
        if(t == 0) continue;
        if(!PositionSelectByTicket(t)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        cnt++;
    }
    return cnt;
}

// Effective chain-loss stop in dollars: combines the fixed-$ and %-of-equity caps.
// Returns the tighter (smaller) of whichever are enabled, or 0 if neither is set.
double ChainLossStopThreshold()
{
    double usd = (HedgeMaxChainLossUSD > 0) ? HedgeMaxChainLossUSD : 0;
    double pct = (HedgeMaxChainLossPct > 0)
                 ? AccountInfoDouble(ACCOUNT_EQUITY) * HedgeMaxChainLossPct / 100.0
                 : 0;

    if(usd > 0 && pct > 0) return MathMin(usd, pct);
    return MathMax(usd, pct);   // whichever single one is set (or 0 if neither)
}

// Convert a dollar amount to a price distance for the given lot
double UsdToPrice(double usd, double lot)
{
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickValue <= 0 || tickSize <= 0 || lot <= 0) return 0;
    return (usd / lot) * (tickSize / tickValue);
}

double NormalizeLot(double lot)
{
    double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(step <= 0) step = 0.01;
    lot = MathRound(lot / step) * step;
    if(lot < minL) lot = minL;
    if(maxL > 0 && lot > maxL) lot = maxL;
    return NormalizeDouble(lot, 2);
}
//+------------------------------------------------------------------+
