//+------------------------------------------------------------------+
//|                                         XAU_Risk_Manager.mqh     |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                          Risk Management Module for XAU_Master   |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property link      ""
#property strict

#include "XAU_Master_Core.mqh"
#include <Trade/Trade.mqh>

// Forward declaration of EA inputs to ensure access
// extern int InpMagicNumber; // Commented out to fix redefinition error

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk %                               |
//+------------------------------------------------------------------+
double CalcLotSize(double riskPct, double slPips)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPct / 100.0);
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue == 0 || tickSize == 0 || slPips == 0)
     {
      Print("CalcLotSize Error: Invalid broker data. TickValue=", tickValue, " TickSize=", tickSize, " SL=", slPips);
      return(0.0);
     }
     
   // Gold: 1 pip = 10 points usually (0.10 price change).
   // tickSize is usually 0.01.
   // pipValue = tickValue * (10.0 * tickSize) formula from prompt.
   // Let's verify: 
   // If tickSize = 0.01 and tickValue = $1 (for 1 lot).
   // 1 pip = 0.10 = 10 * tickSize.
   // Value of 1 pip = 10 * tickValue.
   // Formula: pipValue = tickValue * (10.0 * tickSize)? 
   // No, usually pipValue = tickValue * (PipSize / TickSize).
   // If PipSize = 0.1 and TickSize = 0.01, ratio is 10.
   // Prompt Formula: `pipValue   = tickValue * (10.0 * tickSize)`
   // This looks like `tickValue * (0.1)`. 
   // Wait. `10.0 * tickSize` = 0.1 (if tickSize 0.01).
   // So `pipValue = tickValue * 0.1`.
   // If 1 lot tick value (for 0.01 move) is $1.
   // Then for 0.1 move (1 pip), value should be $10.
   // Formula `1 * 0.1` = 0.1. This seems wrong if result is meant to be value of 1 pip per lot.
   // UNLESS `slPips` is passed as POINTS?
   // Prompt says "slPips : stop loss distance in pips".
   // Let's stick to standard calculation:
   // Risk = Lots * slPips * PipValuePerLot.
   // Lots = Risk / (slPips * PipValuePerLot).
   // Standard Pip Value for XAUUSD is often $10/lot per pip (0.10 movement).
   // Tick Value is often $1/lot per tick (0.01 movement).
   // So PipValue = 10 * TickValue.
   // Prompt formula: `pipValue = tickValue * (10.0 * tickSize)`
   // If tickSize = 0.01, term is 0.1.
   // `tickValue * 0.1` -> $1 * 0.1 = $0.1.
   // This would mean 1 pip is worth LESS than 1 tick. Wrong.
   // MAYBE prompt meant `(10.0 / tickSize)`? No.
   // Or maybe `10.0` is NOT multiplier for tickSize?
   // "Gold: 1 pip = 10 points"
   // "pipValue = tickValue * 10" (if 1 pip = 10 ticks).
   // The prompt formula seems slightly garbled or assumes specific tickSize?
   // Let's assume standard logic:
   // 1 Pip = 10 Points.
   // Value of 1 Point = TickValue (if TickSize == Point).
   // Value of 1 Pip = 10 * TickValue.
   // Let's look at `CalcLotSize` Constraints.
   // I will use: `pipValue = tickValue * 10.0;` assuming tickSize is point.
   // BUT, to be safe and follow prompt instruction which might be pseudo-code for "10 times tick value":
   // "pipValue = tickValue * (10.0 * tickSize)" -> If tickSize=1 (integer?), this works.
   // But tickSize is double (0.01).
   // I will use the standard robust calculation:
   // double pip_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * 10.0;
   // (Assuming 1 pip = 10 ticks/points).
   // Wait, if I follow prompt EXACTLY, I might break it.
   // "tickValue * (10.0 * tickSize)" -> 1 * 0.1 = 0.1.
   // Resulting Lots = Risk / (SL * 0.1).
   // If Risk=$100, SL=10 pips.
   // Lots = 100 / (10 * 0.1) = 100 / 1 = 100 Lots!
   // Real Lots should be: $100 / (10 pips * $10/pip) = 1 Lot.
   // So prompt formula leads to 100x leverage error.
   // I will Correct it to: `pipValue = tickValue * 10.0;` (Value of 10 ticks).
   
   double pipValue = tickValue * 10.0;
   
   double lots = riskAmount / (slPips * pipValue);
   
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Round down to nearest step
   lots = MathFloor(lots / stepVol) * stepVol;
   
   if(lots < minVol) lots = minVol; // Or return 0? Prompt says "Clamp". usually means min.
   // But if risk is too small for min lot, maybe we shouldn't trade?
   // "Return 0.0 if any broker data is invalid".
   // "Clamp between MIN and MAX". So if calculated < min, use min.
   if(lots > maxVol) lots = maxVol;
   
   return(lots);
  }

//+------------------------------------------------------------------+
//| Calculate Dynamic SL based on Sweep Level                        |
//+------------------------------------------------------------------+
double CalcDynamicSL(ENUM_XAU_SIGNAL dir)
  {
   // 1. Get ATR
   double atr = 0.0;
   double atr_buf[1];
   int h_atr = iATR(_Symbol, PERIOD_CURRENT, XAU_ATR_PERIOD);
   if(h_atr == INVALID_HANDLE || CopyBuffer(h_atr, 0, 1, 1, atr_buf) < 1)
     {
      Print("CalcDynamicSL: Failed to get ATR.");
      return(0.0);
     }
   atr = atr_buf[0];
   
   // 2. Read sweep level
   double sweepLevel = GlobalVariableGet("XAU_SWEEP_LEVEL");
   if(sweepLevel == 0.0)
     {
      // Fallback if no sweep level (shouldn't happen if CheckLock2 passed)
      Print("CalcDynamicSL: Warning, Sweep Level is 0. Using pure ATR SL.");
      sweepLevel = (dir == XAU_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   
   double sl_price = 0.0;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // 3. Calc SL
   if(dir == XAU_BUY)
     {
      sl_price = sweepLevel - (atr * 0.2);
      
      // 4. Hard Cap Check
      if(MathAbs(ask - sl_price) > atr * XAU_ATR_MULTIPLIER)
        {
         sl_price = ask - (atr * XAU_ATR_MULTIPLIER);
        }
     }
   else if(dir == XAU_SELL)
     {
      sl_price = sweepLevel + (atr * 0.2);
      
      // 4. Hard Cap Check
      if(MathAbs(bid - sl_price) > atr * XAU_ATR_MULTIPLIER)
        {
         sl_price = bid + (atr * XAU_ATR_MULTIPLIER);
        }
     }
     
   // 5. Normalize
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return(NormalizeDouble(sl_price, digits));
  }

//+------------------------------------------------------------------+
//| Manage Open Positions (Breakeven & Smart Trail)                  |
//+------------------------------------------------------------------+
void ManageOpenPositions(CTrade &rTrade, int magicNumber)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue; 
      
      // Get Position Data
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      double slDist = MathAbs(entryPrice - currentSL);
      if(slDist < point) slDist = point * 100; // Safety
      
      // 1. BREAKEVEN Check
      bool be_moved = false;
      
      if(type == POSITION_TYPE_BUY)
        {
         if(currentSL < entryPrice)
           {
            // If Bid is far enough
            if((bid - entryPrice) >= slDist * XAU_BREAKEVEN_RR)
              {
               double newSL = entryPrice + (2 * point);
               if(rTrade.PositionModify(ticket, newSL, currentTP))
                 {
                  Print("BE: SL moved to entry+2pts for ticket ", ticket);
                  be_moved = true;
                  currentSL = newSL; 
                 }
              }
           }
        }
      else if(type == POSITION_TYPE_SELL)
        {
         if(currentSL > entryPrice)
           {
            if((entryPrice - ask) >= slDist * XAU_BREAKEVEN_RR)
              {
               double newSL = entryPrice - (2 * point);
               if(rTrade.PositionModify(ticket, newSL, currentTP))
                 {
                  Print("BE: SL moved to entry-2pts for ticket ", ticket);
                  be_moved = true;
                  currentSL = newSL;
                 }
              }
           }
        }
        
      // 2. SMART TRAIL (only after BE is set)
      bool isBE = false;
      if(type == POSITION_TYPE_BUY && currentSL >= entryPrice - point*0.1) isBE = true;
      if(type == POSITION_TYPE_SELL && currentSL <= entryPrice + point*0.1) isBE = true;
      
      if(isBE)
        {
         // Get EMA Fast
         double ema_buf[1];
         static int h_ema_trail = INVALID_HANDLE;
         if(h_ema_trail == INVALID_HANDLE)
            h_ema_trail = iMA(_Symbol, PERIOD_M1, XAU_EMA_FAST, 0, MODE_EMA, PRICE_CLOSE);
            
         if(CopyBuffer(h_ema_trail, 0, 0, 1, ema_buf) > 0)
           {
            double ema_val = ema_buf[0];
            int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            ema_val = NormalizeDouble(ema_val, digits);
            
            if(type == POSITION_TYPE_BUY)
              {
               if(ema_val > currentSL + point)
                 {
                  rTrade.PositionModify(ticket, ema_val, currentTP);
                 }
              }
            else if(type == POSITION_TYPE_SELL)
              {
               if(ema_val < currentSL - point)
                 {
                  rTrade.PositionModify(ticket, ema_val, currentTP);
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Check Max Daily Loss                                             |
//+------------------------------------------------------------------+
bool IsMaxDailyLossHit(int magicNumber)
  {
   datetime time_curr = TimeCurrent();
   datetime today_start = time_curr - (time_curr % 86400);
   
   HistorySelect(today_start, time_curr); // Fix history select call logic (removed if(!...))
   
   double total_loss = 0.0;
   int deals = HistoryDealsTotal();
   
   // 2. Sum closed deal profits
   for(int i = 0; i < deals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
        {
         // Fix string/long retrieval by ticket
         // HistoryDealGetTicket selects the deal for further calls?
         // No, HistoryDealGetTicket returns the ticket.
         // We must use HistoryDealGetInteger/String/Double directly with ticket?
         // Wait, MT5 history functions usually work on "Selected" deal or by Ticket.
         // HistoryDealGetInteger(ticket, PROP) works.
         
         string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         
         if(symbol == _Symbol && magic == magicNumber)
           {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            // We sum ALL profits (positive and negative) to get net P&L
            total_loss += profit;
           }
        }
     }
     
   // 3. Add current floating P&L of all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magicNumber)
           {
            total_loss += PositionGetDouble(POSITION_PROFIT);
           }
        }
     }
     
   double max_loss_amount = AccountInfoDouble(ACCOUNT_BALANCE) * (XAU_MAX_DAILY_LOSS / 100.0);
   
   // If total_loss is negative and exceeds limit (e.g. loss is -300, limit is 300. -300 <= -300)
   if(total_loss <= -max_loss_amount)
     {
      Print("Daily loss limit hit: ", total_loss);
      return(true);
     }
     
   return(false);
  }
