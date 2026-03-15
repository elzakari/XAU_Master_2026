//+------------------------------------------------------------------+
//|                                                XAU_HUD_Panel.mqh |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                          HUD Panel Module for XAU_Master_2026    |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property link      ""
#property strict

//+------------------------------------------------------------------+
//| Defines                                                          |
//+------------------------------------------------------------------+
#define HUD_PREFIX "XAU_HUD_"
#define HUD_X_START 10
#define HUD_Y_START 30
#define HUD_Y_STEP 20
#define HUD_BG_NAME "XAU_HUD_BG"

#include "XAU_Master_Core.mqh" // Include Core to see Constants
#include "XAU_DXY_Monitor.mqh"

//+------------------------------------------------------------------+
//| Helper: Create/Update Label                                      |
//+------------------------------------------------------------------+
void UpdateLabel(string name, int x, int y, string text, color clr, int fontsize=10)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
     }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| Helper: Create/Update Background                                 |
//+------------------------------------------------------------------+
void UpdateBackground()
  {
   if(ObjectFind(0, HUD_BG_NAME) < 0)
     {
      ObjectCreate(0, HUD_BG_NAME, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, HUD_BG_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, HUD_BG_NAME, OBJPROP_XDISTANCE, 5);
      ObjectSetInteger(0, HUD_BG_NAME, OBJPROP_YDISTANCE, 25);
      ObjectSetInteger(0, HUD_BG_NAME, OBJPROP_XSIZE, 200);
      ObjectSetInteger(0, HUD_BG_NAME, OBJPROP_YSIZE, 130);
      ObjectSetInteger(0, HUD_BG_NAME, OBJPROP_BGCOLOR, C'20,20,30');
      ObjectSetInteger(0, HUD_BG_NAME, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, HUD_BG_NAME, OBJPROP_BACK, true); // Send to back
     }
  }

//+------------------------------------------------------------------+
//| Main Draw Function                                               |
//+------------------------------------------------------------------+
void DrawHUD()
  {
   UpdateBackground();

   int y = HUD_Y_START;

   // Row 1 — SPREAD
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   color spreadColor = (spread <= XAU_SPREAD_MAX) ? clrLimeGreen : clrRed;
   UpdateLabel(HUD_PREFIX + "SPREAD", HUD_X_START, y, "Spread: " + IntegerToString(spread) + " pts", spreadColor);
   y += HUD_Y_STEP;

   // Row 2 — ADR%
   // Calculate 20-day ADR
   double adr_pct = 0.0;
   MqlRates d1_rates[];
   ArraySetAsSeries(d1_rates, true);
   int copied = CopyRates(_Symbol, PERIOD_D1, 0, 21, d1_rates);
   
   if(copied >= 21)
     {
      double sum_range = 0.0;
      for(int i=1; i<=20; i++)
        {
         sum_range += (d1_rates[i].high - d1_rates[i].low);
        }
      double avg_range = sum_range / 20.0;
      double current_range = d1_rates[0].high - d1_rates[0].low;
      
      if(avg_range > 0)
         adr_pct = (current_range / avg_range) * 100.0;
     }

   color adrColor = clrLimeGreen;
   if(adr_pct >= 70.0 && adr_pct <= 90.0) adrColor = clrOrange;
   else if(adr_pct > 90.0) adrColor = clrRed;

   UpdateLabel(HUD_PREFIX + "ADR", HUD_X_START, y, "ADR: " + DoubleToString(adr_pct, 1) + "%", adrColor);
   y += HUD_Y_STEP;

   // Row 3 — DXY
   string dxyStatus = GetDXYStatus();
   color dxyColor = clrGray;
   if(dxyStatus == "BULLISH $") dxyColor = clrRed; // Block longs? Usually Bullish DXY = Bearish Gold. Red warning?
   // Prompt says: Color : clrRed if "BULLISH $", clrLimeGreen if "BEARISH $", clrGray if "NEUTRAL"
   // Assuming Bullish DXY is bad for Gold Longs (Red), Bearish DXY is good (Green).
   else if(dxyStatus == "BEARISH $") dxyColor = clrLimeGreen;

   UpdateLabel(HUD_PREFIX + "DXY", HUD_X_START, y, "DXY: " + dxyStatus, dxyColor);
   y += HUD_Y_STEP;

   // Row 4 — SESSION
   datetime gmt = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   int hour = dt.hour;
   
   string session = "OFF-HOURS";
   color sessionColor = clrGray;

   if(hour >= XAU_LONDON_START && hour < XAU_LONDON_END)
     {
      session = "LONDON OPEN";
      sessionColor = clrLimeGreen;
     }
   else if(hour >= XAU_SESSION_START && hour < XAU_SESSION_END)
     {
      session = "NY OVERLAP";
      sessionColor = clrLimeGreen;
     }
   else if(hour >= XAU_DEAD_START || hour < 2) // "hour < 2" from prompt (assuming GMT 21-02 is dead)
     {
      session = "DEAD ZONE";
      sessionColor = clrRed;
     }

   UpdateLabel(HUD_PREFIX + "SESSION", HUD_X_START, y, "Session: " + session, sessionColor);
   y += HUD_Y_STEP;

   // Row 5 — NEWS
   bool newsActive = (GlobalVariableGet("XAU_NEWS_ACTIVE") == 1.0);
   string newsText = newsActive ? "! BLOCKED !" : "CLEAR";
   color newsColor = newsActive ? clrRed : clrLimeGreen;
   
   UpdateLabel(HUD_PREFIX + "NEWS", HUD_X_START, y, "News: " + newsText, newsColor);
   y += HUD_Y_STEP;

   // Row 6 — ATR(14)
   double atr = 0.0;
   // Use iATR handle or direct calc? Better to use handle if cached, but this is a standalone HUD.
   // Let's create a temp handle or use static.
   static int h_atr_hud = INVALID_HANDLE;
   if(h_atr_hud == INVALID_HANDLE)
      h_atr_hud = iATR(_Symbol, PERIOD_CURRENT, XAU_ATR_PERIOD);
      
   double atr_buf[1];
   if(CopyBuffer(h_atr_hud, 0, 0, 1, atr_buf) > 0)
      atr = atr_buf[0];

   UpdateLabel(HUD_PREFIX + "ATR", HUD_X_START, y, "ATR: " + DoubleToString(atr, 2), clrWhite);
  }

//+------------------------------------------------------------------+
//| Delete HUD Function                                              |
//+------------------------------------------------------------------+
void DeleteHUD()
  {
   // Delete Background
   ObjectDelete(0, HUD_BG_NAME);

   // Delete all prefixed objects
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, HUD_PREFIX) == 0)
        {
         ObjectDelete(0, name);
        }
     }
  }
