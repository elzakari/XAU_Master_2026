//+------------------------------------------------------------------+
//|                                              XAU_Master_EA.mq5   |
//|                                   Copyright 2026, XAU_Master_2026|
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property version   "1.32"
#property strict

#include <Trade/Trade.mqh>

//--- Input Parameters
input double InpRiskPct        = 1.0;
input int    InpMagicNumber    = 202601;
input bool   InpKillSwitch     = false;
input bool   InpShowHUD        = true;
input bool   InpEnableLog      = true;  // Enable CSV logging

//--- Global Objects
CTrade trade;
bool   g_tradingEnabled = true;

//--- Include project headers
#include <XAU_Master_Core.mqh>
#include <XAU_Risk_Manager.mqh> // This must come after InpMagicNumber
#include <XAU_HUD_Panel.mqh>
#include <XAU_News_Filter.mqh>
#include <XAU_DXY_Monitor.mqh>
#include <XAU_Logger.mqh>

//+------------------------------------------------------------------+
//| Helper: Close All Positions                                      |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
                trade.PositionClose(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Helper: Count Positions                                          |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Main Execution Logic                                             |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(InpMagicNumber);

    // 3. Print Init Info
    Print("XAU_Master_2026 v1.32 initialised | Magic:", InpMagicNumber, " | Risk:", InpRiskPct, "%");

    // Check Build for News Filter
    if(TerminalInfoInteger(TERMINAL_BUILD) < 2260)
    {
        Print("WARNING: MT5 Build < 2260. News calendar filter disabled.");
    }

    // Init Logger (Create file if not exists)
    if(InpEnableLog) InitLogger();

    // 4. Init HUD if needed
    if(InpShowHUD) DrawHUD();

    return(INIT_SUCCEEDED);
}

void OnTick()
{
    // Update Indicators & Logic
    CalcDailyVWAP();
    CalcDXYMomentumScore();
    UpdateNewsGlobal();

    // 1. Check Kill Switch
    if(InpKillSwitch)
    {
        CloseAllPositions(); // Now correctly identified
        g_tradingEnabled = false;
        Comment("XAU_MASTER: KILL SWITCH ACTIVE");
        return;
    }

    if(!g_tradingEnabled) return;

    // 2. Manage existing trades
    ManageOpenPositions(trade);

    // 3. Entry Logic
    if(CountOpenPositions() == 0)
    {
        XAU_SignalResult result = EvaluateSignal();
        if(result.signal != XAU_NO_SIGNAL)
        {
            double sl = CalcDynamicSL(result.signal);
            double pips = MathAbs(result.entryPrice - sl) / (_Point * 10.0);
            double lots = CalcLotSize(InpRiskPct, pips);
            
            if(lots > 0)
            {
                if(result.signal == XAU_BUY)
                    trade.Buy(lots, _Symbol, result.entryPrice, sl, result.takeProfit);
                else
                    trade.Sell(lots, _Symbol, result.entryPrice, sl, result.takeProfit);
            }
        }
    }
}

// Handle exit event logic
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &res)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(HistoryDealSelect(trans.deal))
        {
            if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == InpMagicNumber)
            {
                // Reset loss counters if needed
            }
        }
    }
}