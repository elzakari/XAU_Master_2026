//+------------------------------------------------------------------+
//|                                               XAU_Logger.mqh     |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                          Trade Logger Module for XAU_Master      |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property link      ""
#property strict

#include "XAU_Master_Core.mqh"

//+------------------------------------------------------------------+
//| Initialize Log File (Create header if new)                       |
//+------------------------------------------------------------------+
void InitLogger()
  {
   string dateStr = TimeToString(TimeGMT(), TIME_DATE);
   StringReplace(dateStr, ".", "_");
   string filename = "XAU_Master_Log_" + dateStr + ".csv";
   
   // Open to check/create (Reverted to Local Folder for Tester compatibility)
   // Use FILE_COMMON to make file easy to find
   int handle = FileOpen(filename, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ",");
   
   if(handle == INVALID_HANDLE)
     {
      int err = GetLastError();
      Print("Logger Init: Failed to open file ", filename, ". Error Code: ", err);
      if(err == 5002) Print("Hint: Check filename format.");
      if(err == 5004) Print("Hint: File locked. CLOSE EXCEL/CSV VIEWER.");
      return;
     }
     
   if(FileSize(handle) == 0)
     {
      FileWrite(handle, "Timestamp_GMT", "Signal", "EntryPrice", "StopLoss", "TakeProfit", "Lots", "ATRValue", 
                "SpreadAtEntry", "DXYScore", "NewsActive", "EMAFast", "EMASlow", "VWAPValue", "RSIValue", "Reason");
      Print("Logger: Created new log file ", filename);
     }
     
   FileClose(handle);
  }

//+------------------------------------------------------------------+
//| Log Signal to CSV                                                |
//+------------------------------------------------------------------+
void LogSignal(XAU_SignalResult &result, double lots)
  {
   string dateStr = TimeToString(TimeGMT(), TIME_DATE);
   StringReplace(dateStr, ".", "_");
   string filename = "XAU_Master_Log_" + dateStr + ".csv";
   
   // Use FILE_COMMON to make file easy to find
   int handle = FileOpen(filename, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ",");
   
   if(handle == INVALID_HANDLE)
     {
      Print("Logger error: ", GetLastError());
      return;
     }
     
   // Check size for header (redundant if Init called, but safe)
   if(FileSize(handle) == 0)
     {
      FileWrite(handle, "Timestamp_GMT", "Signal", "EntryPrice", "StopLoss", "TakeProfit", "Lots", "ATRValue", 
                "SpreadAtEntry", "DXYScore", "NewsActive", "EMAFast", "EMASlow", "VWAPValue", "RSIValue", "Reason");
     }
   else
     {
      FileSeek(handle, 0, SEEK_END);
     }
     
   // Gather Data
   string time_gmt = TimeToString(TimeGMT(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   string signal = EnumToString(result.signal);
   string entry = DoubleToString(result.entryPrice, 2);
   string sl = DoubleToString(result.stopLoss, 2);
   string tp = DoubleToString(result.takeProfit, 2);
   string s_lots = DoubleToString(lots, 2);
   string atr = DoubleToString(result.atrValue, 2);
   
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double dxy = GlobalVariableGet("XAU_DXY_MOMENTUM");
   double news = GlobalVariableGet("XAU_NEWS_ACTIVE");
   
   // Re-get indicators for log (visual only, slight inefficiency acceptable for logger)
   double ema_f = 0, ema_s = 0, rsi = 0;
   
   // iMA handles are in Core or EA? They are static in CheckLock1.
   // We can't access them. We create temp.
   int h_ema_f = iMA(_Symbol, PERIOD_M5, XAU_EMA_FAST, 0, MODE_EMA, PRICE_CLOSE);
   int h_ema_s = iMA(_Symbol, PERIOD_M5, XAU_EMA_SLOW, 0, MODE_EMA, PRICE_CLOSE);
   int h_rsi   = iRSI(_Symbol, PERIOD_M1, XAU_RSI_PERIOD, PRICE_CLOSE);
   
   double buf[1];
   if(CopyBuffer(h_ema_f, 0, 0, 1, buf)>0) ema_f = buf[0];
   if(CopyBuffer(h_ema_s, 0, 0, 1, buf)>0) ema_s = buf[0];
   if(CopyBuffer(h_rsi, 0, 1, 1, buf)>0) rsi = buf[0]; // Bar 1
   
   double vwap = GlobalVariableGet("XAU_DAILY_VWAP");
   
   FileWrite(handle, time_gmt, signal, entry, sl, tp, s_lots, atr, 
             spread, DoubleToString(dxy, 4), DoubleToString(news, 0), 
             DoubleToString(ema_f, 2), DoubleToString(ema_s, 2), 
             DoubleToString(vwap, 2), DoubleToString(rsi, 2), result.reason);
             
   FileClose(handle);
  }

//+------------------------------------------------------------------+
//| Log Trade Close                                                  |
//+------------------------------------------------------------------+
void LogTradeClose(ulong ticket, double profit, string closeReason)
  {
   string dateStr = TimeToString(TimeGMT(), TIME_DATE);
   StringReplace(dateStr, ".", "_");
   string filename = "XAU_Master_Log_" + dateStr + ".csv";
   
   // Use FILE_COMMON to make file easy to find
   int handle = FileOpen(filename, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ",");
   
   if(handle == INVALID_HANDLE)
     {
      Print("Logger error: ", GetLastError());
      return;
     }
     
   FileSeek(handle, 0, SEEK_END);
   
   string time_gmt = TimeToString(TimeGMT(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   
   // Columns: Timestamp_GMT, "CLOSE", Ticket, ClosePrice, Profit_USD, CloseReason
   double closePrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
   
   FileWrite(handle, time_gmt, "CLOSE", IntegerToString(ticket), DoubleToString(closePrice, 2), DoubleToString(profit, 2), closeReason);
   
   FileClose(handle);
  }
