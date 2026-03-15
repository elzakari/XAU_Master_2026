//+------------------------------------------------------------------+
//|                                          AnalyseBacktest.mq5     |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                          Backtest Analysis Script for XAU_Master |
//|                                                     Version 1.1  |
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property link      ""
#property version   "1.10"
#property script_show_inputs

// Defines for Compliance Audit
#define AUDIT_SPREAD_MAX 60 

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("--- DEBUG MODE START ---");
   
   // 1. Debug: List ALL files in the folder to verify visibility
   string debug_name;
   long debug_handle = FileFindFirst("*", debug_name);
   if(debug_handle != INVALID_HANDLE)
     {
      Print("Found file in folder: ", debug_name);
      while(FileFindNext(debug_handle, debug_name))
        {
         Print("Found file in folder: ", debug_name);
        }
      FileFindClose(debug_handle);
     }
   else
     {
      Print("CRITICAL: Folder appears empty to the script. Error: ", GetLastError());
     }
     
   Print("--- END DEBUG LIST ---");

   // 2. Actual Search (Use FILE_COMMON)
   string search_path = "XAU_Master_Log_*.csv";
   string filename;
   long search_handle = FileFindFirst(search_path, filename, FILE_COMMON); 
   
   if(search_handle == INVALID_HANDLE)
     {
      Print("No log files found matching: ", search_path);
      Print("Error Code: ", GetLastError());
      return;
     }
     
   Print("--- Starting Backtest Analysis ---");
   
   do
     {
      Print("Analyzing: ", filename);
      AnalyzeFile(filename);
     }
   while(FileFindNext(search_handle, filename)); // Uses previous handle context
   
   FileFindClose(search_handle);
   Print("--- Analysis Complete ---");
  }

//+------------------------------------------------------------------+
//| Analyze a single CSV file                                        |
//+------------------------------------------------------------------+
void AnalyzeFile(string filename)
  {
   int handle = FileOpen(filename, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ",");
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open: ", filename);
      return;
     }
     
   // Read Header
   if(!FileIsEnding(handle))
     {
      // Skip header line
      // Header has 15 columns
      for(int i=0; i<15; i++) FileReadString(handle); 
     }
     
   // Stats
   int total_trades = 0;
   int win_count = 0;
   int loss_count = 0;
   double gross_profit = 0.0;
   double gross_loss = 0.0;
   double net_pl = 0.0;
   int max_consecutive_loss = 0;
   int curr_consecutive_loss = 0;
   
   int violations = 0;
   
   // Loop Rows
   while(!FileIsEnding(handle))
     {
      string col1 = FileReadString(handle);
      if(col1 == "") break; // End of file
      
      string col2 = FileReadString(handle); // Signal or "CLOSE"
      
      if(col2 == "CLOSE")
        {
         // Close Row
         string ticket = FileReadString(handle);
         string close_price = FileReadString(handle);
         string s_profit = FileReadString(handle);
         string close_reason = FileReadString(handle);
         
         double profit = StringToDouble(s_profit);
         net_pl += profit;
         
         if(profit >= 0)
           {
            win_count++;
            gross_profit += profit;
            curr_consecutive_loss = 0;
           }
         else
           {
            loss_count++;
            gross_loss += profit;
            curr_consecutive_loss++;
            if(curr_consecutive_loss > max_consecutive_loss) max_consecutive_loss = curr_consecutive_loss;
           }
        }
      else
        {
         // Signal Row (Entry)
         total_trades++;
         
         string entry_price = FileReadString(handle);
         string sl = FileReadString(handle);
         string tp = FileReadString(handle);
         string lots = FileReadString(handle);
         string atr = FileReadString(handle);
         string spread = FileReadString(handle);
         string dxy = FileReadString(handle);
         string news = FileReadString(handle);
         string ema_f = FileReadString(handle);
         string ema_s = FileReadString(handle);
         string vwap = FileReadString(handle);
         string rsi = FileReadString(handle);
         string reason = FileReadString(handle);
         
         // Audit Checks
         if(StringToInteger(spread) > AUDIT_SPREAD_MAX)
           {
            Print("SPREAD_VIOLATION: ", col1, " Spread=", spread);
            violations++;
           }
           
         if(StringToDouble(news) == 1.0)
           {
            Print("NEWS_VIOLATION: ", col1, " Trade during news");
            violations++;
           }
           
         if(StringToDouble(vwap) == 0.0)
           {
            Print("VWAP_WARNING: VWAP zero at ", col1);
            violations++;
           }
           
         if(dxy == "" || (dxy == "0.0000" && StringToDouble(dxy) == 0.0)) 
           {
            if(dxy == "")
              {
               Print("DXY_MISSING: ", col1);
               violations++;
              }
           }
        }
     }
     
   FileClose(handle);
   
   // Summary Output
   Print("--- Performance Summary ---");
   Print("Total Trades: ", total_trades);
   Print("Wins: ", win_count, " | Losses: ", loss_count);
   double win_rate = (total_trades > 0) ? (double)win_count / total_trades * 100.0 : 0.0;
   Print("Win Rate: ", DoubleToString(win_rate, 2), "%");
   
   double avg_win = (win_count > 0) ? gross_profit / win_count : 0.0;
   double avg_loss = (loss_count > 0) ? gross_loss / loss_count : 0.0;
   Print("Avg Win: $", DoubleToString(avg_win, 2), " | Avg Loss: $", DoubleToString(avg_loss, 2));
   
   double profit_factor = (MathAbs(gross_loss) > 0) ? gross_profit / MathAbs(gross_loss) : 0.0;
   Print("Profit Factor: ", DoubleToString(profit_factor, 2));
   Print("Max Consecutive Losses: ", max_consecutive_loss);
   Print("Total Net P&L: $", DoubleToString(net_pl, 2));
   
   Print("--- Audit Summary ---");
   if(violations == 0)
      Print("AUDIT PASSED: All filter compliance checks clean.");
   else
      Print("AUDIT FAILED: ", violations, " violations found. Review before live.");
  }
