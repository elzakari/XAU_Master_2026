//+------------------------------------------------------------------+
//|                                             Test_Compilation.mq5 |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, XAU_Master_2026"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "XAU_Master_Core.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   XAU_SignalResult res = EvaluateSignal();
   
   // Test individual checks
   bool macro = CheckMacroBias(XAU_BUY);
   bool lock1 = CheckLock1(XAU_BUY);
   
   if(res.signal == XAU_NO_SIGNAL)
     {
      Print("No signal");
     }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
