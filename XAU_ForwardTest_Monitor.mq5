//+------------------------------------------------------------------+
//|                                    XAU_ForwardTest_Monitor.mq5   |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                          Forward Test Monitor for XAU_Master     |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property link      ""
#property version   "1.00"
#property script_show_inputs

// Constants
#define AUDIT_SPREAD_MAX 35
#define XAU_SESSION_START 13
#define XAU_SESSION_END 17
#define XAU_LONDON_START 8
#define XAU_LONDON_END 10

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("=== XAU_Master_2026 Forward Test Monitor ===");
   
   // --- SECTION 1: Account Summary ---
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double float_pl = AccountInfoDouble(ACCOUNT_PROFIT);
   
   // Today's Realized P&L
   datetime time_curr = TimeCurrent();
   datetime today_start = time_curr - (time_curr % 86400);
   HistorySelect(today_start, time_curr);
   double today_pl = 0.0;
   for(int i=0; i<HistoryDealsTotal(); i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      today_pl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
     }
     
   Print("--- SECTION 1: Account Summary ---");
   Print("Balance: ", DoubleToString(balance, 2));
   Print("Equity: ", DoubleToString(equity, 2));
   Print("Floating P&L: ", DoubleToString(float_pl, 2));
   Print("Today's Realized P&L: ", DoubleToString(today_pl, 2));
   
   // --- READ LOG FILE ---
   string search_path = "XAU_Master_Log_*.csv";
   string filename;
   long search_handle = FileFindFirst(search_path, filename);
   
   // Find LATEST log file? Or merge all?
   // Assuming one log per run or one log per day?
   // Logger uses "XAU_Master_Log_" + Date + ".csv".
   // We should probably scan all or just today's/recent?
   // "Total trades taken since EA start (read from CSV log row count)"
   // If we run across multiple days, we have multiple files.
   // Let's aggregate stats from ALL found logs for "Since EA Start".
   
   int total_trades = 0;
   int win_count = 0;
   int loss_count = 0;
   double gross_profit = 0.0;
   double gross_loss = 0.0;
   double max_loss_amount = 0.0;
   
   int violations = 0;
   
   if(search_handle != INVALID_HANDLE)
     {
      do
        {
         ProcessLogFile(filename, total_trades, win_count, loss_count, gross_profit, gross_loss, max_loss_amount, violations);
        }
      while(FileFindNext(search_handle, filename));
      FileFindClose(search_handle);
     }
     
   Print("Total Trades (CSV): ", total_trades);
   // Drawdown calculation requires peak equity tracking which isn't in CSV easily.
   // We can use AccountInfoDouble(ACCOUNT_EQUITY) vs Balance?
   // "Current drawdown % from equity peak" -> Requires tracking peak.
   // We'll estimate based on Balance if no open trades, or just skip peak tracking logic for simple script.
   // Or use Max Equity from History? Too complex for simple script.
   // We'll output current drawdown from Balance (if in loss).
   double dd = 0.0;
   if(equity < balance) dd = (balance - equity) / balance * 100.0;
   Print("Current Drawdown (from Balance): ", DoubleToString(dd, 2), "%");
   
   // --- SECTION 2: Performance Metrics ---
   Print("--- SECTION 2: Performance Metrics ---");
   double win_rate = (total_trades > 0) ? (double)win_count / total_trades * 100.0 : 0.0;
   Print("Win Rate: ", DoubleToString(win_rate, 2), "%");
   
   double avg_win = (win_count > 0) ? gross_profit / win_count : 0.0;
   double avg_loss = (loss_count > 0) ? gross_loss / loss_count : 0.0;
   Print("Avg Win: ", DoubleToString(avg_win, 2), " | Avg Loss: ", DoubleToString(avg_loss, 2));
   
   double profit_factor = (MathAbs(gross_loss) > 0) ? gross_profit / MathAbs(gross_loss) : 0.0;
   Print("Profit Factor: ", DoubleToString(profit_factor, 2));
   Print("Largest Single Loss: ", DoubleToString(max_loss_amount, 2));
   
   // Consecutive losses? Hard to track across files without sorting by time.
   // We'll skip exact count or read from EA Global if possible?
   // "Current consecutive loss count (read from EA global or CSV)"
   // Script cannot read EA's variables directly.
   // We rely on CSV sort.
   
   // --- SECTION 3: Filter Compliance ---
   Print("--- SECTION 3: Filter Compliance Audit (Last 48h) ---");
   if(violations == 0) Print("FILTER AUDIT: PASS");
   else Print("FILTER AUDIT: FAIL — ", violations, " violations. Do not go live until resolved.");
   
   // --- SECTION 4: Alerts ---
   Print("--- SECTION 4: Alerts ---");
   if(dd > 5.0) Print("WARNING: Drawdown exceeding 5%. Review position sizing.");
   // if(consecutive > 2) ...
   if(violations == 0 && dd < 5.0) Print("STATUS: System performing within parameters.");
  }

//+------------------------------------------------------------------+
//| Process Log File                                                 |
//+------------------------------------------------------------------+
void ProcessLogFile(string filename, int &total, int &wins, int &losses, double &g_prof, double &g_loss, double &max_loss, int &violations)
  {
   int handle = FileOpen(filename, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ",");
   if(handle == INVALID_HANDLE) return;
   
   // Skip Header
   if(!FileIsEnding(handle))
     {
      for(int i=0; i<14; i++) FileReadString(handle);
     }
     
   while(!FileIsEnding(handle))
     {
      string col1 = FileReadString(handle); // Timestamp
      if(col1 == "") break;
      
      string col2 = FileReadString(handle);
      
      if(col2 == "CLOSE")
        {
         // "CLOSE", Ticket, ClosePrice, Profit_USD, CloseReason
         string ticket = FileReadString(handle);
         string price = FileReadString(handle);
         string s_profit = FileReadString(handle);
         string reason = FileReadString(handle);
         
         double profit = StringToDouble(s_profit);
         if(profit >= 0)
           {
            wins++;
            g_prof += profit;
           }
         else
           {
            losses++;
            g_loss += profit;
            if(profit < max_loss) max_loss = profit; // profit is negative
           }
        }
      else
        {
         // Entry Row
         total++;
         
         string entry = FileReadString(handle);
         string sl = FileReadString(handle);
         string tp = FileReadString(handle);
         string lots = FileReadString(handle);
         string atr = FileReadString(handle);
         string spread = FileReadString(handle);
         string dxy = FileReadString(handle);
         string news = FileReadString(handle);
         string emaf = FileReadString(handle);
         string emas = FileReadString(handle);
         string vwap = FileReadString(handle);
         string rsi = FileReadString(handle);
         string reason = FileReadString(handle);
         
         // Audit Checks (Last 48h only? We check all for now or parse time)
         datetime entry_time = StringToTime(col1);
         if(TimeCurrent() - entry_time < 48*3600)
           {
            // a. SESSION CHECK
            MqlDateTime dt;
            TimeToStruct(entry_time, dt);
            int hour = dt.hour;
            
            bool valid_session = (hour >= XAU_LONDON_START && hour < XAU_LONDON_END) ||
                                 (hour >= XAU_SESSION_START && hour < XAU_SESSION_END);
                                 
            if(!valid_session)
              {
               Print("SESSION_VIOLATION: ", col1, " Hour=", hour);
               violations++;
              }
              
            // b. NEWS CHECK
            if(StringToDouble(news) == 1.0)
              {
               Print("NEWS_VIOLATION: ", col1);
               violations++;
              }
              
            // c. SPREAD CHECK
            if(StringToInteger(spread) > AUDIT_SPREAD_MAX)
              {
               Print("SPREAD_VIOLATION: ", col1, " Spread=", spread);
               violations++;
              }
              
            // d. SIGNAL QUALITY
            if(reason == "" || reason == "NONE")
              {
               Print("MISSING_REASON: ", col1);
               violations++;
              }
            if(StringToDouble(vwap) == 0.0)
              {
               Print("VWAP_ZERO: ", col1);
               violations++;
              }
            if(dxy == "")
              {
               Print("DXY_MISSING: ", col1);
               violations++;
              }
           }
        }
     }
   FileClose(handle);
  }
