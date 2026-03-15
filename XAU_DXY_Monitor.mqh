//+------------------------------------------------------------------+
//|                                          XAU_DXY_Monitor.mqh     |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                          DXY Momentum Monitor for XAU_Master     |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property link      ""
#property strict

//+------------------------------------------------------------------+
//| Calculate DXY Momentum Score                                     |
//+------------------------------------------------------------------+
double CalcDXYMomentumScore()
  {
   string pairs[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "USDCAD"};
   int pair_count = 5;
   double total_score = 0.0;
   int valid_pairs = 0;
   
   for(int i=0; i<pair_count; i++)
     {
      string symbol = pairs[i];
      
      // Check if symbol exists
      // SymbolInfoInteger(symbol, SYMBOL_EXIST) not always reliable if not selected.
      // Try SymbolSelect?
      if(!SymbolSelect(symbol, true))
        {
         // Print("DXY: symbol ", symbol, " not available");
         continue;
        }
        
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      // Get last 4 closed M5 bars
      if(CopyRates(symbol, PERIOD_M5, 1, 4, rates) < 4)
        {
         // Print("DXY: Insufficient data for ", symbol);
         continue;
        }
        
      // 3-bar ROC: (Close[1] - Close[3]) / Close[3]
      // In array: rates[0] is Bar[1], rates[2] is Bar[3]
      double close1 = rates[0].close;
      double close3 = rates[2].close;
      
      double roc = (close1 - close3) / close3;
      
      // Apply direction
      if(symbol == "EURUSD" || symbol == "GBPUSD")
        {
         total_score += -roc; // Invert
        }
      else
        {
         total_score += roc;
        }
        
      valid_pairs++;
     }
     
   if(valid_pairs < 3)
     {
      Print("DXY: Insufficient pair data (", valid_pairs, "/5). Score 0.");
      GlobalVariableSet("XAU_DXY_MOMENTUM", 0.0);
      return(0.0);
     }
     
   double raw_score = total_score / valid_pairs;
   
   // Normalize using 20-period rolling min/max
   static double history[20];
   static int idx = 0;
   static bool filled = false;
   
   history[idx] = raw_score;
   idx++;
   if(idx >= 20)
     {
      idx = 0;
      filled = true;
     }
     
   double min_val = DBL_MAX;
   double max_val = -DBL_MAX;
   
   int count = filled ? 20 : idx;
   if(count == 0) count = 1; // Should be at least 1 after assignment
   
   for(int i=0; i<count; i++)
     {
      if(history[i] < min_val) min_val = history[i];
      if(history[i] > max_val) max_val = history[i];
     }
     
   double normalized = 0.0;
   if(max_val - min_val > 0.00000001) // Avoid div by zero
     {
      normalized = 2.0 * (raw_score - min_val) / (max_val - min_val) - 1.0;
     }
     
   GlobalVariableSet("XAU_DXY_MOMENTUM", normalized);
   return(normalized);
  }

//+------------------------------------------------------------------+
//| Get DXY Status String                                            |
//+------------------------------------------------------------------+
string GetDXYStatus()
  {
   double score = GlobalVariableGet("XAU_DXY_MOMENTUM");
   
   if(score > 0.5) return("BULLISH $");
   if(score < -0.5) return("BEARISH $");
   
   return("NEUTRAL");
  }
