//+------------------------------------------------------------------+
//|                                         XAU_Master_Indicator.mq5 |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                          Visual Indicator for XAU_Master_2026    |
//|                                                     Version 1.1  |
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property link      ""
#property version   "1.10"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

// Include Modules
#include <XAU_Master_Core.mqh>
#include <XAU_HUD_Panel.mqh>
#include <XAU_News_Filter.mqh>
#include <XAU_DXY_Monitor.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "Indicator Settings"
input int    InpEMAFast      = XAU_EMA_FAST;
input int    InpEMASlow      = XAU_EMA_SLOW;
input int    InpRSIPeriod    = XAU_RSI_PERIOD;
input int    InpATRPeriod    = XAU_ATR_PERIOD;
input int    InpMaxSpread    = XAU_SPREAD_MAX;

input group "Alerts & Display"
input bool   InpShowHUD      = true;
input bool   InpAlertDesktop = true;
input bool   InpAlertMobile  = false;
input bool   InpAlertEmail   = false;

//+------------------------------------------------------------------+
//| Indicator Buffers                                                |
//+------------------------------------------------------------------+
double ema_fast[];
double ema_slow[];
double buy_signal[];
double sell_signal[];

//+------------------------------------------------------------------+
//| Handles                                                          |
//+------------------------------------------------------------------+
int h_ema_fast_ind = INVALID_HANDLE;
int h_ema_slow_ind = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1. Set up indicator buffers and plot properties
   SetIndexBuffer(0, ema_fast, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrGold);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   PlotIndexSetString(0, PLOT_LABEL, "EMA Fast");

   SetIndexBuffer(1, ema_slow, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrDarkOrange);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 2);
   PlotIndexSetString(1, PLOT_LABEL, "EMA Slow");

   SetIndexBuffer(2, buy_signal, INDICATOR_DATA);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(2, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrDodgerBlue);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 2);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetString(2, PLOT_LABEL, "Buy Signal");

   SetIndexBuffer(3, sell_signal, INDICATOR_DATA);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // Down Arrow
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrCrimson);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 2);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetString(3, PLOT_LABEL, "Sell Signal");

   // 2. Create iMA handles (M5 timeframe as per Core logic)
   h_ema_fast_ind = iMA(_Symbol, PERIOD_M5, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_slow_ind = iMA(_Symbol, PERIOD_M5, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);

   if(h_ema_fast_ind == INVALID_HANDLE || h_ema_slow_ind == INVALID_HANDLE)
     {
      Print("Failed to create EMA handles");
      return(INIT_FAILED);
     }

   // 3. Call DrawHUD if enabled
   if(InpShowHUD)
     {
      DrawHUD();
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   // 1. Populate EMA buffers
   int limit = rates_total - prev_calculated;
   if(limit > rates_total - 1) limit = rates_total - 1;
   
   for(int i = limit; i >= 0; i--)
     {
      int pos = rates_total - 1 - i;
      
      double buf[1];
      if(CopyBuffer(h_ema_fast_ind, 0, time[pos], 1, buf) > 0)
         ema_fast[pos] = buf[0];
      else
         ema_fast[pos] = EMPTY_VALUE;
      
      if(CopyBuffer(h_ema_slow_ind, 0, time[pos], 1, buf) > 0)
         ema_slow[pos] = buf[0];
      else
         ema_slow[pos] = EMPTY_VALUE;
     }
     
   // 2. On each new bar only (Signal Logic)
   static datetime lastBar = 0;
   datetime currentBarTime = time[rates_total - 1]; // Time of open of current bar
   
   // Update News Status (Rate Limited internally)
   UpdateNewsGlobal();

   if(currentBarTime != lastBar)
     {
      lastBar = currentBarTime;
      
      // Update DXY Momentum (Once per bar)
      CalcDXYMomentumScore();
      
      // Call Signal Logic
      XAU_SignalResult result = EvaluateSignal();
      
      // Index for signal is Bar[1] (prev bar)
      int signal_idx = rates_total - 2; 
      if(signal_idx < 0) signal_idx = 0;
      
      buy_signal[signal_idx] = EMPTY_VALUE;
      sell_signal[signal_idx] = EMPTY_VALUE;
      
      if(result.signal == XAU_BUY)
        {
         buy_signal[signal_idx] = low[signal_idx] - (result.atrValue * 0.5);
         
         if(InpAlertDesktop)
            Alert("XAU BUY @ ", DoubleToString(result.entryPrice, 2),
                  " | SL: ", DoubleToString(result.stopLoss, 2),
                  " | TP: ", DoubleToString(result.takeProfit, 2),
                  " | ", result.reason);
                  
         if(InpAlertMobile)
            SendNotification("XAU BUY @ " + DoubleToString(result.entryPrice, 2)
                             + " | SL: " + DoubleToString(result.stopLoss, 2)
                             + " | TP: " + DoubleToString(result.takeProfit, 2)
                             + " | " + result.reason);
                             
         if(InpAlertEmail)
            SendMail("XAU_Master_2026 BUY Signal", "XAU BUY @ " + DoubleToString(result.entryPrice, 2)
                     + "\nSL: " + DoubleToString(result.stopLoss, 2)
                     + "\nTP: " + DoubleToString(result.takeProfit, 2)
                     + "\n" + result.reason);
        }
      else if(result.signal == XAU_SELL)
        {
         sell_signal[signal_idx] = high[signal_idx] + (result.atrValue * 0.5);
         
         if(InpAlertDesktop)
            Alert("XAU SELL @ ", DoubleToString(result.entryPrice, 2),
                  " | SL: ", DoubleToString(result.stopLoss, 2),
                  " | TP: ", DoubleToString(result.takeProfit, 2),
                  " | ", result.reason);
                  
         if(InpAlertMobile)
            SendNotification("XAU SELL @ " + DoubleToString(result.entryPrice, 2)
                             + " | SL: " + DoubleToString(result.stopLoss, 2)
                             + " | TP: " + DoubleToString(result.takeProfit, 2)
                             + " | " + result.reason);
                             
         if(InpAlertEmail)
            SendMail("XAU_Master_2026 SELL Signal", "XAU SELL @ " + DoubleToString(result.entryPrice, 2)
                     + "\nSL: " + DoubleToString(result.stopLoss, 2)
                     + "\nTP: " + DoubleToString(result.takeProfit, 2)
                     + "\n" + result.reason);
        }
     }

   // 3. Psychological levels (Redraw occasionally or manage strictly)
   // We will manage strictly: Delete and redraw 20 lines around current price.
   ObjectsDeleteAll(0, "XAU_PSYCH_");
   
   double currentPrice = close[rates_total - 1];
   double centerLevel = MathFloor(currentPrice / 5.0) * 5.0;
   
   for(int i = -10; i < 10; i++)
     {
      double level = centerLevel + (i * 5.0);
      string name = "XAU_PSYCH_" + IntegerToString(i + 10); 
      
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, level);
        }
      else
        {
         ObjectMove(0, name, 0, 0, level);
        }
        
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      
      // Tooltip
      ObjectSetString(0, name, OBJPROP_TOOLTIP, "Psych Level " + DoubleToString(level, 2));
     }

   // 4. VWAP line
   double vwap = GlobalVariableGet("XAU_DAILY_VWAP");
   string vwap_name = "XAU_VWAP_LINE";
   
   if(vwap > 0)
     {
      if(ObjectFind(0, vwap_name) < 0)
        {
         ObjectCreate(0, vwap_name, OBJ_HLINE, 0, 0, vwap);
         ObjectSetInteger(0, vwap_name, OBJPROP_COLOR, clrCyan);
         ObjectSetInteger(0, vwap_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, vwap_name, OBJPROP_WIDTH, 1);
        }
      else
        {
         ObjectMove(0, vwap_name, 0, 0, vwap);
        }
     }

   // 5. Call DrawHUD() on every tick if InpShowHUD.
   if(InpShowHUD)
     {
      DrawHUD();
     }
     
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteHUD();
   ObjectsDeleteAll(0, "XAU_PSYCH_");
   ObjectDelete(0, "XAU_VWAP_LINE");
   
   IndicatorRelease(h_ema_fast_ind);
   IndicatorRelease(h_ema_slow_ind);
  }
//+------------------------------------------------------------------+
