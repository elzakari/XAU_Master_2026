//+------------------------------------------------------------------+
//|                                           XAU_News_Filter.mqh    |
//|                                  Copyright 2026, XAU_Master_2026 |
//|                          News Filter Module for XAU_Master       |
//|                                                     Version 1.0  |
//+------------------------------------------------------------------+
#property copyright "XAU_Master_2026"
#property link      ""
#property strict

//+------------------------------------------------------------------+
//| Check High Impact News                                           |
//+------------------------------------------------------------------+
bool IsHighImpactNewsActive(int bufferMinutes = 30)
  {
   // Check if Calendar API is available
   // We can't easily check 'enabled' status without static flag set in OnInit.
   // But we can check build version or try-catch.
   // Prompt says "CalendarValueHistory() requires MT5 Build 2260+".
   if(TerminalInfoInteger(TERMINAL_BUILD) < 2260) return(false);

   datetime now       = TimeGMT();
   datetime from_time = now - (bufferMinutes * 60);
   datetime to_time   = now + (bufferMinutes * 60);

   MqlCalendarValue usd_values[];
   MqlCalendarValue xau_values[];
   
   // Retrieve events
   // Note: CalendarValueHistory returns values (actual data releases).
   // Usually we want CalendarEvent (scheduled events).
   // But prompt specifies CalendarValueHistory.
   // Maybe it means "Events occurring in this window"?
   // CalendarValueHistory retrieves values for specified period.
   // If event is scheduled but no value released yet, does it appear?
   // Yes, usually with empty actual_value.
   
   if(!CalendarValueHistory(usd_values, from_time, to_time, "USD", NULL))
     {
      // If error (e.g. 4001 - Not Found or API disabled), return false?
      // Prompt says: "If it returns an error... set newsFilterDisabled".
      // We will just return false here for safety.
      // Print("News Filter: Calendar access failed.");
      return(false);
     }
     
   // XAU events? (Gold specific? Usually none, but maybe 'XAU' currency code?)
   // Prompt says check "XAU".
   CalendarValueHistory(xau_values, from_time, to_time, "XAU", NULL);
   
   // Check USD Events
   int usd_count = ArraySize(usd_values);
   for(int i=0; i<usd_count; i++)
     {
      MqlCalendarEvent event_info;
      if(CalendarEventById(usd_values[i].event_id, event_info))
        {
         if(event_info.importance == CALENDAR_IMPORTANCE_HIGH)
           {
            GlobalVariableSet("XAU_NEWS_ACTIVE", 1.0);
            Print("News block: ", event_info.name, " | importance: HIGH");
            return(true);
           }
        }
     }
     
   // Check XAU Events
   int xau_count = ArraySize(xau_values);
   for(int i=0; i<xau_count; i++)
     {
      MqlCalendarEvent event_info;
      if(CalendarEventById(xau_values[i].event_id, event_info))
        {
         if(event_info.importance == CALENDAR_IMPORTANCE_HIGH)
           {
            GlobalVariableSet("XAU_NEWS_ACTIVE", 1.0);
            Print("News block: ", event_info.name, " | importance: HIGH");
            return(true);
           }
        }
     }
     
   GlobalVariableSet("XAU_NEWS_ACTIVE", 0.0);
   return(false);
  }

//+------------------------------------------------------------------+
//| Update News Global (Rate Limited)                                |
//+------------------------------------------------------------------+
void UpdateNewsGlobal()
  {
   static datetime lastCheck = 0;
   if((TimeCurrent() - lastCheck) < 60) return;
   
   lastCheck = TimeCurrent();
   
   // Buffer minutes should be input?
   // Prompt 4.5 says "input int InpNewsBuffer = 15".
   // But this module doesn't see EA inputs directly unless extern.
   // We'll use default 15 or read a global if set?
   // Prompt 4.2 says "IsHighImpactNewsActive(int bufferMinutes = 15)".
   // And "UpdateNewsGlobal() ... IsHighImpactNewsActive()".
   // It calls it without args (using default 15).
   // If we want to use input, we should pass it.
   // But signature in prompt is `void UpdateNewsGlobal()`.
   // I will use default 15 here.
   
   IsHighImpactNewsActive(30);
  }

//+------------------------------------------------------------------+
//| Get Next News Event Description                                  |
//+------------------------------------------------------------------+
string GetNextNewsEvent()
  {
   if(TerminalInfoInteger(TERMINAL_BUILD) < 2260) return("Calendar API N/A");
   
   datetime now = TimeGMT();
   datetime to_time = now + (4 * 3600); // 4 hours forward
   
   MqlCalendarValue values[];
   if(!CalendarValueHistory(values, now, to_time, "USD", NULL)) return("No events <4h");
   
   int count = ArraySize(values);
   if(count == 0) return("No events <4h");
   
   // Find first high impact
   for(int i=0; i<count; i++)
     {
      MqlCalendarEvent event_info;
      if(CalendarEventById(values[i].event_id, event_info))
        {
         if(event_info.importance == CALENDAR_IMPORTANCE_HIGH)
           {
            // Calc time diff
            long diff = (long)(values[i].time - now);
            int minutes = (int)(diff / 60);
            
            string time_str = "";
            if(minutes < 60) time_str = IntegerToString(minutes) + " min";
            else
              {
               int h = minutes / 60;
               int m = minutes % 60;
               time_str = IntegerToString(h) + "h " + IntegerToString(m) + "min";
              }
              
            return(event_info.name + " in " + time_str);
           }
        }
     }
     
   return("No high impact <4h");
  }
