//+------------------------------------------------------------------+
//|                                                     TestCore.mq5 |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAU_Master_2026"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

#include <XAU_Master_Core.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Reset last bar time to force evaluation
   // Since EvaluateSignal uses a static variable for lastBarTime, 
   // running this script once will work. Running it multiple times 
   // in the same chart quickly might trigger the new bar guard if not enough time passed,
   // but scripts unload static vars usually? No, scripts unload completely.
   
   Print("Starting TestCore...");
   
   // Force VWAP calculation first
   double vwap = CalcDailyVWAP();
   Print("VWAP: ", vwap);
   
   // Evaluate Signal
   XAU_SignalResult res = EvaluateSignal();
   
   Print("Signal Result:");
   Print("Signal: ", EnumToString(res.signal));
   Print("Entry: ", res.entryPrice);
   Print("SL: ", res.stopLoss);
   Print("TP: ", res.takeProfit);
   Print("ATR: ", res.atrValue);
   Print("Reason: ", res.reason);
   
   // Also print status of locks for debug
   Print("--- Diagnostics ---");
   Print("News Active: ", GlobalVariableGet("XAU_NEWS_ACTIVE"));
   Print("DXY Momentum: ", GlobalVariableGet("XAU_DXY_MOMENTUM"));
   Print("Sweep Level: ", GlobalVariableGet("XAU_SWEEP_LEVEL"));
   
   bool mb_buy = CheckMacroBias(XAU_BUY);
   bool l1_buy = CheckLock1(XAU_BUY);
   bool l2_buy = CheckLock2(XAU_BUY);
   bool l3_buy = CheckLock3(XAU_BUY);
   
   Print("BUY Checks: MB=", mb_buy, " L1=", l1_buy, " L2=", l2_buy, " L3=", l3_buy);
   
   bool mb_sell = CheckMacroBias(XAU_SELL);
   bool l1_sell = CheckLock1(XAU_SELL);
   bool l2_sell = CheckLock2(XAU_SELL);
   bool l3_sell = CheckLock3(XAU_SELL);
   
   Print("SELL Checks: MB=", mb_sell, " L1=", l1_sell, " L2=", l2_sell, " L3=", l3_sell);
  }
//+------------------------------------------------------------------+
