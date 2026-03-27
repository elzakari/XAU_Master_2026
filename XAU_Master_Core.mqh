//+------------------------------------------------------------------+
//|                                            XAU_Master_Core.mqh   |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                          Shared signal engine for XAU_Master_2026|
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property link      ""
#property strict

#ifndef XAU_MASTER_CORE_MQH
#define XAU_MASTER_CORE_MQH

//+------------------------------------------------------------------+
//| Project Constants                                                |
//+------------------------------------------------------------------+
double g_CoreTestMode = 0.0; // Global flag for Test Mode

#define XAU_EMA_FAST        20
#define XAU_EMA_SLOW        50
#define XAU_RSI_PERIOD      14
#define XAU_ATR_PERIOD      14
#define XAU_ATR_MULTIPLIER  1.5
#define XAU_SWEEP_BARS      30
#define XAU_SPREAD_MAX      35
#define XAU_RISK_PCT        1.0
#define XAU_RR_TARGET       2.0
#define XAU_BREAKEVEN_RR    1.0
#define XAU_MAX_DAILY_LOSS  3.0
#define XAU_SESSION_START   13    // GMT hour â€” London/NY overlap open
#define XAU_SESSION_END     17    // GMT hour â€” London/NY overlap close
#define XAU_LONDON_START    8
#define XAU_LONDON_END      10
#define XAU_DEAD_START      21
#define XAU_DEAD_END        23

//+------------------------------------------------------------------+
//| Global Enums                                                     |
//+------------------------------------------------------------------+
enum ENUM_XAU_SIGNAL 
  {
   XAU_NO_SIGNAL = 0,
   XAU_BUY       = 1,
   XAU_SELL      = 2
  };

//+------------------------------------------------------------------+
//| Signal Result Structure                                          |
//+------------------------------------------------------------------+
struct XAU_SignalResult
  {
   ENUM_XAU_SIGNAL   signal;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit;
   double            atrValue;
   string            reason;
  };

//+------------------------------------------------------------------+
//| Function Prototypes                                              |
//+------------------------------------------------------------------+

/**
 * Checks the macro directional bias.
 * @param dir The direction to check (XAU_BUY or XAU_SELL).
 * @return True if bias confirms direction, false otherwise.
 */
bool CheckMacroBias(ENUM_XAU_SIGNAL dir)
  {
   // 0. Test Mode Bypass
   if(g_CoreTestMode > 0.5)
     {
      // Print("DEBUG: Macro Filter Bypassed.");
      return(true);
     }

   // 1. News Guard
   if(GlobalVariableGet("XAU_NEWS_ACTIVE") == 1.0)
     {
      Print("MacroBias: News active. Signal blocked.");
      return(false);
     }

   // 2. DXY Guard (Disabled in Strategy Tester for single symbol test)
   if(!MQLInfoInteger(MQL_TESTER))
   {
       double dxy_score = GlobalVariableGet("XAU_DXY_MOMENTUM");
       if(dxy_score > 0.5 && dir == XAU_BUY)
         {
          // Print("MacroBias: DXY pumping (" + DoubleToString(dxy_score, 2) + "). Blocked Longs.");
          return(false);
         }
       if(dxy_score < -0.5 && dir == XAU_SELL)
         {
          // Print("MacroBias: DXY dumping (" + DoubleToString(dxy_score, 2) + "). Blocked Shorts.");
          return(false);
         }
   }

   // 3. Higher Timeframe Structure (M15)
   if(!GlobalVariableGet("XAU_USE_TREND_FILTER"))
   {
       // If trend filter is disabled via EA inputs, skip macro structure check
       return(true);
   }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M15, 1, 2, rates); // Get last 2 closed bars (indices 1 and 2)

   if(copied < 2)
     {
      Print("MacroBias: Failed to copy M15 rates.");
      return(false);
     }

   // Index 0 in 'rates' array corresponds to bar 1 (latest closed), Index 1 corresponds to bar 2
   if(dir == XAU_BUY)
     {
      // Check for Higher Highs (Uptrend Structure)
      if(rates[0].high <= rates[1].high)
        {
         return(false); // Not a higher high
        }
     }
   else if(dir == XAU_SELL)
     {
      // Check for Lower Lows (Downtrend Structure)
      if(rates[0].low >= rates[1].low)
        {
         return(false); // Not a lower low
        }
     }

   return(true);
  }

/**
 * Checks Lock 1 conditions (e.g. Liquidity Sweep).
 * @param dir The direction to check.
 * @return True if Lock 1 is satisfied.
 */
bool CheckLock1(ENUM_XAU_SIGNAL dir)
  {
   // 0. Test Mode Bypass
   // if(g_CoreTestMode > 0.5) return(true); // Reverted to prevent crash

   // 0.5 Skip EMA Check if Trend Filter is Disabled
   bool use_trend = GlobalVariableGet("XAU_USE_TREND_FILTER") > 0.5;

   // 1. Initialize EMA Handles (Static Cache)
   static int h_ema_fast = INVALID_HANDLE;
   static int h_ema_slow = INVALID_HANDLE;

   if(h_ema_fast == INVALID_HANDLE)
     {
      h_ema_fast = iMA(_Symbol, PERIOD_M5, XAU_EMA_FAST, 0, MODE_EMA, PRICE_CLOSE);
      if(h_ema_fast == INVALID_HANDLE)
        {
         Print("CheckLock1: Failed to create Fast EMA handle.");
         return(false);
        }
     }

   if(h_ema_slow == INVALID_HANDLE)
     {
      h_ema_slow = iMA(_Symbol, PERIOD_M5, XAU_EMA_SLOW, 0, MODE_EMA, PRICE_CLOSE);
      if(h_ema_slow == INVALID_HANDLE)
        {
         Print("CheckLock1: Failed to create Slow EMA handle.");
         return(false);
        }
     }

   // 2. Retrieve EMA Values
   double fast_buf[1];
   double slow_buf[1];

   // Check if data is ready
   if(BarsCalculated(h_ema_fast) < XAU_EMA_FAST || BarsCalculated(h_ema_slow) < XAU_EMA_SLOW)
     {
      return(false); // Indicators not ready yet
     }

   if(CopyBuffer(h_ema_fast, 0, 0, 1, fast_buf) < 1 || CopyBuffer(h_ema_slow, 0, 0, 1, slow_buf) < 1)
     {
      // Print("CheckLock1: Failed to copy EMA buffers."); // Silence this to avoid log spam during warmup
      return(false);
     }

   double ema_fast_val = fast_buf[0];
   double ema_slow_val = slow_buf[0];

   // EMA Cloud Alignment (Only if Trend Filter is enabled)
   if(use_trend)
   {
       if(dir == XAU_BUY && ema_fast_val <= ema_slow_val) return(false);
       if(dir == XAU_SELL && ema_fast_val >= ema_slow_val) return(false);
   }

   // 3. VWAP Position (Skip if trend filter is disabled to allow mean reversion)
   if(use_trend)
   {
       double vwap = GlobalVariableGet("XAU_DAILY_VWAP");
       if(vwap == 0.0)
         {
          Print("CheckLock1: VWAP not yet calculated.");
          return(false);
         }
    
       // Get Close[1] for VWAP check
       MqlRates rates[1];
       if(CopyRates(_Symbol, PERIOD_M5, 1, 1, rates) < 1)
         {
          Print("CheckLock1: Failed to get Close[1].");
          return(false);
         }
       double close_1 = rates[0].close;
    
       if(dir == XAU_BUY && close_1 <= vwap) return(false);
       if(dir == XAU_SELL && close_1 >= vwap) return(false);
   }

   // 4. Psychological Level Detection
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // Round to nearest 5.00: 5000, 5005, 5010...
   // Formula: round(price / 5.0) * 5.0
   double nearest_5 = MathRound(bid / 5.0) * 5.0;
   double dist = MathAbs(bid - nearest_5);

   if(dist <= 0.50)
     {
      GlobalVariableSet("XAU_NEAR_PSYCH", 1.0);
     }
   else
     {
      GlobalVariableSet("XAU_NEAR_PSYCH", 0.0);
     }

   // 5. Return true if conditions met
   return(true);
  }

/**
 * Checks Lock 2 conditions (Liquidity Sweep).
 * @param dir The direction to check.
 * @return True if Lock 2 is satisfied.
 */
bool CheckLock2(ENUM_XAU_SIGNAL dir)
  {
   // 1. Get rates (XAU_SWEEP_BARS + 2)
   // We need bars from index 1 (previous closed) up to XAU_SWEEP_BARS + 1.
   // Total bars to retrieve = XAU_SWEEP_BARS + 2 (indices 0 to XAU_SWEEP_BARS+1, where 0 is current bar?).
   // No, prompt says "retrieve the last (XAU_SWEEP_BARS + 2) closed candles".
   // "Only analyse closed candles â€” never bar[0]."
   // So we copy starting from index 1.
   
   int req_bars = XAU_SWEEP_BARS + 2; // e.g., 30 + 2 = 32
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Copy starting from index 1 (last closed candle)
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, req_bars, rates) < req_bars)
     {
      // Not enough history or error
      return(false);
     }
     
   // In 'rates' array:
   // rates[0] corresponds to Bar[1] (Sweep Candle)
   // rates[1] corresponds to Bar[2]
   // ...
   // rates[req_bars-1] corresponds to Bar[req_bars]
   
   // 2. Calculate Range (excluding sweep candle rates[0])
   // Range bars: rates[1] to rates[XAU_SWEEP_BARS]
   // e.g. indices 1 to 30 (30 bars)
   
   double range_high = -DBL_MAX;
   double range_low  = DBL_MAX;
   
   for(int i = 1; i <= XAU_SWEEP_BARS; i++)
     {
      if(rates[i].high > range_high) range_high = rates[i].high;
      if(rates[i].low  < range_low)  range_low  = rates[i].low;
     }
     
   // 3/4. Check Sweep Conditions
   bool sweep_detected = false;
   double sweep_level = 0.0;
   
   if(dir == XAU_BUY)
     {
      // Bullish Sweep (Stop hunt below range low)
      // Condition A: Wick penetrated below range
      bool cond_a = (rates[0].low < range_low);
      
      // Condition B: Body closed back above range
      bool cond_b = (rates[0].close > range_low);
      
      // Condition C: Lower wick >= 2.0 * Upper wick
      // Prompt says: "(bars[1].close - bars[1].low) > (bars[1].high - bars[1].close) * 2.0"
      
      bool cond_c = (rates[0].close - rates[0].low) > (rates[0].high - rates[0].close) * 2.0;
      
      if(cond_a && cond_b && cond_c)
        {
         sweep_detected = true;
         sweep_level = rates[0].low;
        }
     }
   else if(dir == XAU_SELL)
     {
      // Bearish Sweep (Stop hunt above range high)
      // Condition A: Wick penetrated above range
      bool cond_a = (rates[0].high > range_high);
      
      // Condition B: Body closed back below range
      bool cond_b = (rates[0].close < range_high);
      
      // Condition C: Upper wick >= 2.0 * Lower wick
      // Prompt formula: "(bars[1].high - bars[1].close) > (bars[1].close - bars[1].low) * 2.0"
      
      bool cond_c = (rates[0].high - rates[0].close) > (rates[0].close - rates[0].low) * 2.0;
      
      if(cond_a && cond_b && cond_c)
        {
         sweep_detected = true;
         sweep_level = rates[0].high;
        }
     }
     
   if(!sweep_detected) return(false);
   
   // 5. Volume Confirmation
   // bars[1].tick_volume > average(bars[2], bars[3], bars[4])
   // In array: rates[0] vs avg(rates[1], rates[2], rates[3])
   
   double avg_vol = (rates[1].tick_volume + rates[2].tick_volume + rates[3].tick_volume) / 3.0;
   if(rates[0].tick_volume <= avg_vol)
     {
      // Volume failed
      return(false);
     }
     
   // 6. Store Sweep Level
   GlobalVariableSet("XAU_SWEEP_LEVEL", sweep_level);
   
   // 7. Debug Print
   // Print("Sweep detected: ", EnumToString(dir),
   //       " | Price: ", rates[0].close,
   //       " | Wick: ", MathAbs(rates[0].high - rates[0].low),
   //       " | Vol: ", rates[0].tick_volume,
   //       " | Level: ", sweep_level);
         
   return(true);
  }

/**
 * Checks Lock 3 conditions (RSI Hook, Stoch, Candle Pattern).
 * @param dir The direction to check.
 * @return True if Lock 3 is satisfied.
 */
bool CheckLock3(ENUM_XAU_SIGNAL dir)
  {
   // 0. Test Mode Bypass
   // if(g_CoreTestMode > 0.5) return(true); // Reverted

   // 1. RSI Hook (M1)
   // We need RSI values for indices 1 and 2 (previous closed bars)
   
   double rsi_buf[];
   ArraySetAsSeries(rsi_buf, true);
   int h_rsi = iRSI(_Symbol, PERIOD_M1, XAU_RSI_PERIOD, PRICE_CLOSE);
   
   if(h_rsi == INVALID_HANDLE)
     {
      Print("CheckLock3: Failed to create RSI handle.");
      return(false);
     }
     
   // Copy 2 values starting from index 1 (Bar 1 and Bar 2)
   if(CopyBuffer(h_rsi, 0, 1, 2, rsi_buf) < 2) 
     {
      // Handle lazy loading or error
      return(false);
     }
     
   // rsi_buf[0] is Bar[1] (Recent), rsi_buf[1] is Bar[2] (Older)
   double rsi_1 = rsi_buf[0];
   double rsi_2 = rsi_buf[1];
   
   if(dir == XAU_BUY)
     {
      // Updated Logic: "Hooking up from the 40-50 zone"
      // 1. Hook Up: RSI[1] > RSI[2]
      // 2. Zone: RSI[1] is between 30 and 70 (widened for M1)
      
      bool hook_up = (rsi_1 > rsi_2);
      bool in_zone = (rsi_1 >= 30.0 && rsi_1 <= 70.0);
      
      if( ! (hook_up && in_zone) ) return(false);
     }
   else if(dir == XAU_SELL)
     {
      // Updated Logic: "Hooking down from the 50-60 zone"
      // 1. Hook Down: RSI[1] < RSI[2]
      // 2. Zone: RSI[1] is between 30 and 70 (widened for M1)
      
      bool hook_down = (rsi_1 < rsi_2);
      bool in_zone   = (rsi_1 >= 30.0 && rsi_1 <= 70.0);
      
      if( ! (hook_down && in_zone) ) return(false);
     }
     
   // 2. Candle Pattern (M1, Bar 1)
   // Need Open, Close, High, Low of Bar[1] and Bar[2]
   MqlRates m1_rates[];
   ArraySetAsSeries(m1_rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 1, 2, m1_rates) < 2) return(false);
   
   // m1_rates[0] = Bar[1], m1_rates[1] = Bar[2]
   double c1 = m1_rates[0].close;
   double o1 = m1_rates[0].open;
   double h1 = m1_rates[0].high;
   double l1 = m1_rates[0].low;
   
   double c2 = m1_rates[1].close;
   double o2 = m1_rates[1].open;
   double h2 = m1_rates[1].high;
   double l2 = m1_rates[1].low;
   
   double body1 = MathAbs(c1 - o1);
   double lower_wick1 = MathMin(c1, o1) - l1;
   double upper_wick1 = h1 - MathMax(c1, o1);
   
   string pattern_name = "";
   bool pattern_found = false;
   
   if(dir == XAU_BUY)
     {
      // Bullish Engulfing: C1 green, C2 red, Body 1 engulfs Body 2
      // Relaxed to only require C1 > O2, O1 < C2 to be more permissive on M1 timeframe
      // Further relaxed: just need C1 > O2 to show upward momentum after sweep
      bool engulfing = (c1 > o1) && (o2 > c2) && (c1 > o2);
      
      if(engulfing)
        {
         pattern_found = true;
         pattern_name = "ENG";
        }
      else
        {
         // Bullish Pin Bar: Long lower wick, small body at the top
         // Relaxed lower wick requirement slightly from 2.0 to 1.5 for M1 timeframe
         // Further relaxed: just check lower wick is larger than body
         bool pin_bar = (lower_wick1 > body1) && (upper_wick1 < body1) && (c1 >= o1); 
         if(pin_bar)
           {
            pattern_found = true;
            pattern_name = "PIN";
           }
        }
     }
   else if(dir == XAU_SELL)
     {
      // Bearish Engulfing: C1 red, C2 green, Body 1 engulfs Body 2
      bool engulfing = (c1 < o1) && (c2 > o2) && (c1 < o2);
      
      if(engulfing)
        {
         pattern_found = true;
         pattern_name = "ENG";
        }
      else
        {
         // Bearish Pin Bar: Long upper wick, small body at the bottom
         bool pin_bar = (upper_wick1 > body1) && (lower_wick1 < body1) && (c1 <= o1);
         if(pin_bar)
           {
            pattern_found = true;
            pattern_name = "PIN";
           }
        }
     }
     
   if(!pattern_found) return(false);
   
   return(true);
  }

/**
 * Main signal evaluation function.
 * @return XAU_SignalResult structure with trade details.
 */
XAU_SignalResult EvaluateSignal()
  {
   XAU_SignalResult result;
   result.signal = XAU_NO_SIGNAL;
   result.entryPrice = 0.0;
   result.stopLoss = 0.0;
   result.takeProfit = 0.0;
   result.atrValue = 0.0;
   result.reason = "";
   
   // 1. Guard â€” only evaluate on new bar open
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime == lastBarTime) return(result); // Return empty
   lastBarTime = currentBarTime;
   
   // 2. Update VWAP
   CalcDailyVWAP();
   
   // 3. Test BUY
   bool b_macro = CheckMacroBias(XAU_BUY);
   bool b_l1    = CheckLock1(XAU_BUY);
   bool b_l2    = CheckLock2(XAU_BUY);
   bool b_l3    = CheckLock3(XAU_BUY);

   // Force Override in Test Mode (REVERTED FOR REAL LOGIC)
   if(g_CoreTestMode > 0.5)
   {
       // b_macro = true; // Still bypass macro
       // b_l1 = true; // Reverted: Trend Check active
       // b_l3 = true; // Reverted: RSI Check active
       if(b_l2) Print("TEST MODE: Macro Bypass Only. Sweep found.");
   }

   if(b_macro && b_l1 && b_l2 && b_l3)
     {
      result.signal = XAU_BUY;
      result.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // Get ATR
      double atr_buf[];
      int h_atr = iATR(_Symbol, PERIOD_CURRENT, XAU_ATR_PERIOD);
      CopyBuffer(h_atr, 0, 1, 1, atr_buf); // Bar[1]
      result.atrValue = atr_buf[0];
      
      // SL: Just past sweep wick or 1.5x ATR
      double sweepLevel = GlobalVariableGet("XAU_SWEEP_LEVEL");
      double sl_wick = sweepLevel - (result.atrValue * 0.1); // Small buffer
      double sl_atr  = result.entryPrice - (result.atrValue * 1.5);
      
      result.stopLoss = sl_wick;
      if(MathAbs(result.entryPrice - result.stopLoss) > (result.atrValue * 1.5))
      {
          result.stopLoss = result.entryPrice - (result.atrValue * 1.5);
      }
      
      result.takeProfit = result.entryPrice + (result.entryPrice - result.stopLoss) * XAU_RR_TARGET;
      
      double rsi_val = 0.0;
      {
         double r_buf[]; 
         int h = iRSI(_Symbol, PERIOD_M1, XAU_RSI_PERIOD, PRICE_CLOSE);
         CopyBuffer(h, 0, 1, 1, r_buf);
         rsi_val = r_buf[0];
      }
      
      result.reason = "MB:OK | L1:EMA+VWAP | L2:Sweep@" + DoubleToString(result.stopLoss, 2)
                      + " | L3:RSI" + DoubleToString(rsi_val, 1);
      return(result);
     }
   else 
     {
      // Debug rejection reason for BUY
      // Print debug if sweep detected (L2) OR if we are in tester and L3 triggered
      if(b_l2 || b_l3) 
        {
         Print("DEBUG BUY REJECT: Macro=",b_macro," L1=",b_l1," L2=",b_l2," L3=",b_l3);
        }
     }
     
   // 4. Test SELL
   bool s_macro = CheckMacroBias(XAU_SELL);
   bool s_l1    = CheckLock1(XAU_SELL);
   bool s_l2    = CheckLock2(XAU_SELL);
   bool s_l3    = CheckLock3(XAU_SELL);

   // Force Override in Test Mode (REVERTED FOR REAL LOGIC)
   if(g_CoreTestMode > 0.5)
   {
       // s_macro = true; // Still bypass macro
       // s_l1 = true; // Reverted
       // s_l3 = true; // Reverted
       if(s_l2) Print("TEST MODE: Macro Bypass Only. Sweep found.");
   }

   if(s_macro && s_l1 && s_l2 && s_l3)
     {
      result.signal = XAU_SELL;
      result.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      double atr_buf[];
      int h_atr = iATR(_Symbol, PERIOD_CURRENT, XAU_ATR_PERIOD);
      CopyBuffer(h_atr, 0, 1, 1, atr_buf);
      result.atrValue = atr_buf[0];
      
      double sweepLevel = GlobalVariableGet("XAU_SWEEP_LEVEL");
      double sl_wick = sweepLevel + (result.atrValue * 0.1);
      
      result.stopLoss = sl_wick;
      if(MathAbs(result.stopLoss - result.entryPrice) > (result.atrValue * 1.5))
      {
          result.stopLoss = result.entryPrice + (result.atrValue * 1.5);
      }
      
      result.takeProfit = result.entryPrice - (result.stopLoss - result.entryPrice) * XAU_RR_TARGET;
      
      double rsi_val = 0.0;
      {
         double r_buf[]; 
         int h = iRSI(_Symbol, PERIOD_M1, XAU_RSI_PERIOD, PRICE_CLOSE);
         CopyBuffer(h, 0, 1, 1, r_buf);
         rsi_val = r_buf[0];
      }
      
      result.reason = "MB:OK | L1:EMA+VWAP | L2:Sweep@" + DoubleToString(result.stopLoss, 2)
                      + " | L3:RSI" + DoubleToString(rsi_val, 1);
      return(result);
     }
   else
     {
      // Debug rejection reason for SELL
      // Print debug if sweep detected (L2) OR if we are in tester and L3 triggered
      if(s_l2 || s_l3) 
        {
         Print("DEBUG SELL REJECT: Macro=",s_macro," L1=",s_l1," L2=",s_l2," L3=",s_l3);
        }
     }
     
   return(result);
  }

/**
 * Calculates the daily VWAP.
 * @return The current VWAP value.
 */
double CalcDailyVWAP()
  {
   // 1. Get today's session start timestamp
   // Prompt: datetime today_start = iTime(_Symbol, PERIOD_D1, 0)
   datetime today_start = iTime(_Symbol, PERIOD_D1, 0);
   
   // 2. Use CopyRates() to retrieve all M1 bars from today_start until now
   MqlRates bars[];
   // "today_start, TimeCurrent()"
   int count = CopyRates(_Symbol, PERIOD_M1, today_start, TimeCurrent(), bars);
   
   // Fallback case 1: If count <= 0 (no bars loaded)
   if(count <= 0)
     {
      // return iClose(_Symbol, PERIOD_D1, 1)
      Print("CalcDailyVWAP: Warning, no M1 bars loaded. Using Prev D1 Close.");
      return(iClose(_Symbol, PERIOD_D1, 1));
     }
     
   // 3. Calculate cumulative VWAP
   double cum_tp_vol = 0.0;
   double cum_vol    = 0.0;
   
   for(int i = 0; i < count; i++)
     {
      double typical_price = (bars[i].high + bars[i].low + bars[i].close) / 3.0;
      cum_tp_vol += typical_price * (double)bars[i].tick_volume;
      cum_vol    += (double)bars[i].tick_volume;
     }
     
   // Fallback case 2: If cum_vol == 0.0
   if(cum_vol == 0.0)
     {
      Print("CalcDailyVWAP: Warning, Cumulative Volume is 0. Using Current Bid.");
      return(SymbolInfoDouble(_Symbol, SYMBOL_BID));
     }
     
   // 4. vwap = cum_tp_vol / cum_vol
   double vwap = cum_tp_vol / cum_vol;
   GlobalVariableSet("XAU_DAILY_VWAP", vwap);
   
   return(vwap);
  }

#endif // XAU_MASTER_CORE_MQH
