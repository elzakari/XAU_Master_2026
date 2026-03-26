//+------------------------------------------------------------------+
//|                                   XAU_Master_AI_Gatekeeper.mq5   |
//|                                   Copyright 2026, XAU_Master_2026|
//|                          Powered by Neural Gatekeeper (ONNX)     |
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property version   "1.01"
#property strict

#include <Trade/Trade.mqh>

//--- Input Parameters
input string Inp_Risk_Settings = "=== Risk Settings ==="; // .
input double InpRiskPct        = 1.0;   // Risk Percent per Trade
input int    InpMagicNumber    = 202602; // Magic Number
input double InpMaxDailyLoss   = 5.0;   // Max Daily Loss (%)

input string Inp_Strategy_Settings = "=== Strategy Settings ==="; // .
input bool   InpUseTrendFilter = true;  // Use EMA Trend Filter
input bool   InpUseNewsFilter  = true;  // Use News Filter

input string Inp_AI_Settings   = "=== AI Gatekeeper ==="; // .
input bool   InpUseAI          = true;  // Enable ONNX Vibe Check
input string InpONNXFile       = "gold_vibe.onnx"; // ONNX Model File
input float  InpAIThreshold    = 0.72f; // Minimum AI Confidence (0.0 to 1.0)

input string Inp_System_Settings = "=== System Settings ==="; // .
input bool   InpShowHUD        = true;  // Show Info Panel
input bool   InpEnableLog      = true;  // Enable CSV Logging

//--- Global Objects
CTrade trade;
bool   g_tradingEnabled = true;

//--- Include project headers
#include "XAU_Master_Core.mqh"
#include "XAU_Risk_Manager.mqh"
#include "XAU_HUD_Panel.mqh"
#include "XAU_News_Filter.mqh"
#include "XAU_DXY_Monitor.mqh"
#include "XAU_Logger.mqh"
#include "XAU_AI_Engine.mqh"

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
int OnInit(void)
{
    trade.SetExpertMagicNumber(InpMagicNumber);

    // Init Info
    Print("XAU_Master AI Gatekeeper v1.01 | Magic:", InpMagicNumber, " | Risk:", InpRiskPct, "%");

    // Check Build for News Filter
    if(TerminalInfoInteger(TERMINAL_BUILD) < 2260)
    {
        Print("WARNING: MT5 Build < 2260. News calendar filter disabled.");
    }

    // Init AI Gatekeeper
    if(InpUseAI)
    {
        if(!LoadVibeModel(InpONNXFile))
        {
            Print("WARNING: AI Gatekeeper failed to load. Will fallback to standard technical logic.");
            // If running in tester, don't crash, just disable AI so the test can proceed
            if(MQLInfoInteger(MQL_TESTER))
            {
               Print("TESTER MODE: Disabling AI Check due to missing ONNX file.");
               // We can't change InpUseAI as it's const, but we can set a global flag
               GlobalVariableSet("XAU_TESTER_AI_DISABLE", 1.0);
            }
        }
        else
        {
            GlobalVariableSet("XAU_TESTER_AI_DISABLE", 0.0);
        }
    }

    // Init Logger
    if(InpEnableLog) InitLogger();

    // Disable Test Mode for Production
    g_CoreTestMode = 0.0;

    return(INIT_SUCCEEDED);
}

void OnTick(void)
{
    // Ensure Test Mode is OFF
    g_CoreTestMode = 0.0;

    // Update Indicators & Logic
    CalcDailyVWAP();
    CalcDXYMomentumScore();
    UpdateNewsGlobal();
    
    // Check Daily Loss
    if(IsMaxDailyLossHit(InpMagicNumber))
    {
        if(g_tradingEnabled)
        {
            Print("Daily Loss Limit Hit. Stopping trading for today.");
            g_tradingEnabled = false;
        }
        return;
    }

    if(!g_tradingEnabled) return;

    // HUD Update
    if(InpShowHUD)
    {
        string status = "XAU_Master AI [ACTIVE]\n";
        status += "Spread: " + IntegerToString(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + "\n";
        status += "Macro: " + (CheckMacroBias(XAU_BUY) ? "BUY" : "") + (CheckMacroBias(XAU_SELL) ? "SELL" : "") + "\n";
        Comment(status);
    }

    // 2. Manage existing trades
    ManageOpenPositions(trade, InpMagicNumber);

    // 3. Entry Logic
    if(CountOpenPositions() == 0)
    {
        XAU_SignalResult result = EvaluateSignal();
        if(result.signal != XAU_NO_SIGNAL)
        {
            bool ai_passed = true;
            
            // AI Vibe Check Confirmation
            bool run_ai = InpUseAI;
            if(GlobalVariableGet("XAU_TESTER_AI_DISABLE") == 1.0) run_ai = false;
            
            if(run_ai)
            {
                float vibe_features[5];
                vibe_features[0] = GetRelativeVolatility();
                vibe_features[1] = GetLiquidityScore();
                vibe_features[2] = GetDXYCorrelation();
                vibe_features[3] = GetMomentumAcceleration();
                vibe_features[4] = GetTimeOfDayVibe();

                float confidence = PredictVibe(vibe_features);
                
                if(confidence < InpAIThreshold)
                {
                    ai_passed = false;
                    Print("AI Vibe Check FAILED (Confidence: ", confidence, " < ", InpAIThreshold, "). Signal ignored.");
                }
                else
                {
                    Print("AI Vibe Check PASSED (Confidence: ", confidence, "). Executing Trade.");
                }
            }

            if(ai_passed)
            {
                double sl = result.stopLoss; // Use SL from Core (Smart SL)
                double pips = MathAbs(result.entryPrice - sl) / (_Point * 10.0);
                double lots = CalcLotSize(InpRiskPct, pips);
                
                if(lots > 0)
                {
                    if(result.signal == XAU_BUY)
                    {
                        if(trade.Buy(lots, _Symbol, result.entryPrice, sl, result.takeProfit))
                        {
                            if(InpEnableLog) LogSignal(result, lots);
                        }
                    }
                    else
                    {
                        if(trade.Sell(lots, _Symbol, result.entryPrice, sl, result.takeProfit))
                        {
                            if(InpEnableLog) LogSignal(result, lots);
                        }
                    }
                }
            }
        }
    }
}

void OnDeinit(const int reason)
{
    if(InpUseAI && m_onnx_handle != INVALID_HANDLE)
    {
        OnnxRelease(m_onnx_handle);
    }
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &res)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(HistoryDealSelect(trans.deal))
        {
            if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == InpMagicNumber)
            {
                if(InpEnableLog && HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                {
                   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
                   LogTradeClose(trans.deal, profit, "Closed");
                }
            }
        }
    }
}
