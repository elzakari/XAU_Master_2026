# XAU_MASTER_2026 — Trae.AI Development Prompt Pack
**Institutional Gold Scalper | MQL5 | MetaTrader 5 | v2.0**

> Sequential MQL5 prompts for building the XAU_Master_2026 system from the ground up.
> **5 Phases • 16 Prompts • Follow in strict order • Test at every step.**

---

## How to Use This Prompt Pack

1. **Paste Prompt 0** at the start of every new Trae.AI session — this primes the AI with full project context.
2. **Paste each prompt as-is** — they are complete, self-contained instructions.
3. **Run the compilation test** at the end of each prompt before proceeding.
4. **Never skip a prompt** — each module depends on the previous one.

> ⚠️ **Critical Rule:** Never proceed to the next prompt until the current file compiles with **0 errors** in MT5's MetaEditor (F7).

---

---

# PROMPT 0 — Session Context Header
**Use at the start of EVERY Trae.AI session**

---

```
You are an expert MQL5 developer specialising in MetaTrader 5 Expert Advisors
and custom indicators for high-frequency Gold (XAUUSD) scalping systems.

Context:
  Project : XAU_Master_2026 — Institutional Gold Scalper
  Asset   : XAUUSD (Gold), currently trading $5,000–$5,500 range
  Platform: MetaTrader 5 (MQL5 language)
  Style   : Liquidity Sweep + Momentum Triple-Lock scalping system
  Sessions: London Open 08:00–10:00 GMT, London/NY Overlap 13:00–17:00 GMT

File Architecture (do not deviate from these filenames):
  XAU_Master_Core.mqh        — shared signal engine (all lock logic)
  XAU_Risk_Manager.mqh       — lot sizing, SL/TP, breakeven, trailing
  XAU_News_Filter.mqh        — economic calendar integration
  XAU_DXY_Monitor.mqh        — DXY correlation and momentum scoring
  XAU_HUD_Panel.mqh          — on-chart dashboard overlay
  XAU_Logger.mqh             — trade log writer
  XAU_Master_Indicator.mq5   — indicator shell (includes Core + HUD)
  XAU_Master_EA.mq5          — EA shell (includes all .mqh files)

Coding Standards:
  - All functions must have JSDoc-style block comments
  - Use #define for all magic numbers (ATR multiplier, spread limit, etc.)
  - Every function returns a value; no void functions that silently fail
  - All array accesses must be bounds-checked
  - Use CopyBuffer() / CopyRates() for indicator data — never iCustom() chains
  - Compile target: MetaTrader 5 Build 3000+

Acknowledge this context and confirm you are ready to begin Phase 1.
```

> 📋 **Dev Notes:**
> - Wait for Trae.AI to confirm before sending Prompt 1.1.
> - If starting a new session mid-build, paste this header + a brief summary of files already completed.
> - Keep this context pinned — re-paste it if Trae.AI loses context in a long session.

---

---

# PHASE 1 — Core Signal Engine
**Deliverable: `XAU_Master_Core.mqh` — the single source of truth for all trade signal logic**

---

## Prompt 1.1 — File Scaffold & Defines
**XAU_Master_Core.mqh — Part 1 of 4**

---

```
Task:
  Create the file XAU_Master_Core.mqh with the following scaffold.

Requirements:
  1. Add a header comment block with:
       filename, version (1.0), author (XAU_Master_2026),
       description ("Shared signal engine for XAU_Master_2026").

  2. Add include guard:
       #ifndef XAU_MASTER_CORE_MQH
       #define XAU_MASTER_CORE_MQH
       ...
       #endif

  3. Define ALL project constants using #define:
       XAU_EMA_FAST        20
       XAU_EMA_SLOW        50
       XAU_RSI_PERIOD      14
       XAU_ATR_PERIOD      14
       XAU_ATR_MULTIPLIER  1.5
       XAU_SWEEP_BARS      30
       XAU_SPREAD_MAX      35
       XAU_RISK_PCT        1.0
       XAU_RR_TARGET       2.0
       XAU_BREAKEVEN_RR    1.0
       XAU_MAX_DAILY_LOSS  3.0
       XAU_SESSION_START   13    // GMT hour — London/NY overlap open
       XAU_SESSION_END     17    // GMT hour — London/NY overlap close
       XAU_LONDON_START    8
       XAU_LONDON_END      10
       XAU_DEAD_START      21
       XAU_DEAD_END        23

  4. Declare a global enum:
       enum ENUM_XAU_SIGNAL { XAU_NO_SIGNAL, XAU_BUY, XAU_SELL }

  5. Declare a struct XAU_SignalResult with these fields:
       ENUM_XAU_SIGNAL signal
       double           entryPrice
       double           stopLoss
       double           takeProfit
       double           atrValue
       string           reason

  6. Declare the following functions with stub bodies only (return stubs, no logic yet):
       bool             CheckMacroBias(ENUM_XAU_SIGNAL dir)
       bool             CheckLock1(ENUM_XAU_SIGNAL dir)
       bool             CheckLock2(ENUM_XAU_SIGNAL dir)
       bool             CheckLock3(ENUM_XAU_SIGNAL dir)
       XAU_SignalResult EvaluateSignal()
       double           CalcDailyVWAP()

Output:
  Complete XAU_Master_Core.mqh that compiles with 0 errors, 0 warnings.

Compilation test:
  In MetaEditor, create a blank .mq5, add:
    #include "XAU_Master_Core.mqh"
  Press F7. Must produce 0 errors, 0 warnings before proceeding.
```

> 📋 **Dev Notes:**
> - Save file to your `MT5/MQL5/Include/` directory.
> - The `#define` values can be overridden via EA input parameters later — use them everywhere instead of magic numbers.
> - Do not implement function bodies yet — stubs only in this prompt.

---

## Prompt 1.2 — Macro Bias & Lock 1
**XAU_Master_Core.mqh — Part 2 of 4**

---

```
Task:
  Implement CheckMacroBias() and CheckLock1() inside XAU_Master_Core.mqh.
  Replace the stub bodies from Prompt 1.1 with full logic.

--- CheckMacroBias(ENUM_XAU_SIGNAL dir) ---

Requirements:
  1. Create indicator handles at first call using static variables.
     Cache handles — do not recreate on each tick.

  2. Retrieve the last 3 closed bars of the M15 chart using CopyRates().

  3. Higher timeframe structure check:
       For XAU_BUY:  last 2 M15 closes must show Higher Highs (uptrend).
       For XAU_SELL: last 2 M15 closes must show Lower Lows (downtrend).
       If condition fails: return false.

  4. DXY guard:
       Read global double: GlobalVariableGet("XAU_DXY_MOMENTUM")
       If score > 0.5  AND dir == XAU_BUY:  return false (DXY pumping — block longs).
       If score < -0.5 AND dir == XAU_SELL: return false (DXY falling — block shorts).
       (XAU_DXY_Monitor.mqh will populate this global — stub the read for now.)

  5. News guard:
       Read global double: GlobalVariableGet("XAU_NEWS_ACTIVE")
       If value == 1.0: return false (news window active).
       (XAU_News_Filter.mqh will set this — stub the read for now.)

  6. Return true only if all three checks pass.

--- CheckLock1(ENUM_XAU_SIGNAL dir) ---

Requirements:
  1. Calculate EMA(XAU_EMA_FAST) and EMA(XAU_EMA_SLOW) on current symbol, M5.
     Use iMA() with handles cached in static variables.
     Use CopyBuffer() to retrieve values — always check return value.

  2. EMA Cloud alignment:
       For XAU_BUY:  ema_fast > ema_slow. Else return false.
       For XAU_SELL: ema_fast < ema_slow. Else return false.

  3. VWAP position:
       Read global double: GlobalVariableGet("XAU_DAILY_VWAP")
       For XAU_BUY:  Close[1] > vwap. Else return false.
       For XAU_SELL: Close[1] < vwap. Else return false.
       If vwap == 0.0: log warning "VWAP not yet calculated" and return false.

  4. Psychological level detection (informational only — do not block entry):
       Round current Bid to nearest 5.00.
       If within 0.50 of a $5 or $10 boundary:
         GlobalVariableSet("XAU_NEAR_PSYCH", 1.0)
       Else:
         GlobalVariableSet("XAU_NEAR_PSYCH", 0.0)

  5. Return true if EMA cloud AND VWAP conditions are both satisfied.

Output:
  Updated XAU_Master_Core.mqh. Compilation must still produce 0 errors.
```

> 📋 **Dev Notes:**
> - EMA handles must be `static int` inside each function to persist across ticks.
> - `CopyBuffer()` returns -1 on failure — always check and `Print()` the error code.
> - The VWAP and DXY globals are written by other modules — for now these are just global reads with safe fallbacks.

---

## Prompt 1.3 — Lock 2: Liquidity Sweep Detector
**XAU_Master_Core.mqh — Part 3 of 4**

---

```
Task:
  Implement CheckLock2(ENUM_XAU_SIGNAL dir) — the liquidity sweep detector.
  This is the most critical function in the system.

  A "sweep" occurs when institutional players push price through a retail stop
  cluster, then reverse sharply. We trade the reversal — not the breakout.

--- Algorithm ---

  1. Use CopyRates() on the current chart to retrieve the last
     (XAU_SWEEP_BARS + 2) closed candles into an MqlRates array.
     Only analyse closed candles — never bar[0].

  2. Calculate the 30-bar range (excluding bar[1], the sweep candle):
       range_high = highest High  of bars[2 .. XAU_SWEEP_BARS+1]
       range_low  = lowest  Low   of bars[2 .. XAU_SWEEP_BARS+1]

  3. For XAU_BUY (bullish sweep — stop hunt below range low):
       Condition A: bars[1].low  < range_low   (wick penetrated below range)
       Condition B: bars[1].close > range_low  (body closed back above range)
       Condition C: (bars[1].close - bars[1].low) > (bars[1].high - bars[1].close) * 2.0
                    (lower wick is at least 2x the upper wick — strong rejection)

  4. For XAU_SELL (bearish sweep — stop hunt above range high):
       Condition A: bars[1].high  > range_high  (wick penetrated above range)
       Condition B: bars[1].close < range_high  (body closed back below range)
       Condition C: (bars[1].high - bars[1].close) > (bars[1].close - bars[1].low) * 2.0
                    (upper wick is at least 2x the lower wick — strong rejection)

  5. Volume confirmation:
       bars[1].tick_volume must be > average tick_volume of bars[2], bars[3], bars[4].
       If this check fails: return false.

  6. Store sweep level in global:
       For XAU_BUY:  GlobalVariableSet("XAU_SWEEP_LEVEL", bars[1].low)
       For XAU_SELL: GlobalVariableSet("XAU_SWEEP_LEVEL", bars[1].high)
       This value is used by the Risk Manager for precise SL placement.

  7. Debug print on detection:
       Print("Sweep detected: ", EnumToString(dir),
             " | Price: ", bars[1].close,
             " | Wick: ",  MathAbs(bars[1].high - bars[1].low),
             " | Vol: ",   bars[1].tick_volume);

  8. Return true only if Conditions A, B, C, AND volume all pass.

Rules:
  - Only evaluate bar[1] (last fully closed candle). Never evaluate bar[0].
  - The 2x wick ratio filter (Condition C) is non-negotiable — do not soften it.

Output:
  Updated XAU_Master_Core.mqh. Compilation 0 errors.
```

> 📋 **Dev Notes:**
> - The 2x wick ratio is what separates genuine sweeps from ordinary volatility — keep it strict.
> - `XAU_SWEEP_LEVEL` is read by `CalcDynamicSL()` in the Risk Manager — ensure CheckLock2 always runs before that function.
> - Test visually: load the indicator on a chart and confirm arrows only appear on clear wick-and-reverse candles.

---

## Prompt 1.4 — Lock 3 & Master Evaluator
**XAU_Master_Core.mqh — Part 4 of 4**

---

```
Task:
  Implement CheckLock3() and EvaluateSignal() to complete XAU_Master_Core.mqh.

--- CheckLock3(ENUM_XAU_SIGNAL dir) ---

  1. RSI Hook — calculate RSI(XAU_RSI_PERIOD) on M1 chart using iRSI():

       For XAU_BUY:
         rsi[1] > 50 AND rsi[2] < 50   (just crossed above 50 — the "hook")
         AND rsi[1] < 65               (not overbought — reject if >= 65)

       For XAU_SELL:
         rsi[1] < 50 AND rsi[2] > 50   (just crossed below 50)
         AND rsi[1] > 35               (not oversold — reject if <= 35)

       If RSI condition fails: return false.

  2. Stochastic Timing — calculate Stochastic(5,3,3) on M1 using iStochastic():

       For XAU_BUY:
         stoch_main[1] < 40
         OR (stoch_main[2] < 20 AND stoch_main[1] > 20)  (exiting oversold)

       For XAU_SELL:
         stoch_main[1] > 60
         OR (stoch_main[2] > 80 AND stoch_main[1] < 80)  (exiting overbought)

       If Stochastic condition fails: return false.

  3. Candle Pattern — check bar[1] for Bullish/Bearish Engulfing OR Pin Bar:

       For XAU_BUY — Bullish Engulfing:
         close[1] > open[1]             (bullish body)
         AND close[1] > open[2]         (closes above previous candle open)
         AND open[1]  < close[2]        (opens below previous candle close)

       For XAU_BUY — Bullish Pin Bar (alternative):
         (close[1] - open[1]) < (open[1] - low[1]) * 0.33
         (body is less than 33% of the lower wick)

       For XAU_SELL: mirror the above conditions for bearish patterns.

       If neither Engulfing NOR Pin Bar: return false.

  4. Return true only if RSI hook AND Stochastic AND candle pattern all pass.

--- EvaluateSignal() ---

  1. Guard — only evaluate on new bar open:
       static datetime lastBarTime = 0;
       if (iTime(_Symbol, PERIOD_CURRENT, 0) == lastBarTime) return empty result;
       lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);

  2. Update VWAP before any lock checks:
       CalcDailyVWAP();

  3. Test BUY direction first:
       if CheckMacroBias(XAU_BUY) && CheckLock1(XAU_BUY) &&
          CheckLock2(XAU_BUY)     && CheckLock3(XAU_BUY)
       → set result.signal = XAU_BUY and populate result fields.

  4. Else test SELL direction (same sequence, XAU_SELL).

  5. Else return XAU_SignalResult with signal = XAU_NO_SIGNAL.

  6. When populating XAU_SignalResult:
       entryPrice = Ask (BUY) or Bid (SELL)
       atrValue   = ATR(XAU_ATR_PERIOD) value of bar[1] from iATR()
       stopLoss   = GlobalVariableGet("XAU_SWEEP_LEVEL")  (set by CheckLock2)
       takeProfit = entryPrice + (entryPrice - stopLoss) * XAU_RR_TARGET  (BUY)
                  = entryPrice - (stopLoss - entryPrice) * XAU_RR_TARGET  (SELL)
       reason     = "MB:OK | L1:EMA+VWAP | L2:Sweep@" + DoubleToString(stopLoss,2)
                  + " | L3:RSI" + DoubleToString(rsi_value,1)
                  + "+" + pattern_name  // "ENG" or "PIN"

Output:
  Final complete XAU_Master_Core.mqh. Compilation 0 errors, 0 warnings.

  Also write a minimal test script TestCore.mq5:
    - Calls EvaluateSignal() in OnStart()
    - Prints the full XAU_SignalResult to the Experts log
    - Compiles and runs in Strategy Tester without errors
```

> 📋 **Dev Notes:**
> - The "new bar only" guard in `EvaluateSignal()` is critical — prevents duplicate signals on the same candle.
> - Run `TestCore.mq5` in Strategy Tester (M1 XAUUSD, any date range) and confirm signal results print cleanly.
> - The `reason` string is logged by `XAU_Logger.mqh` — make it descriptive enough to diagnose missed entries.

---

---

# PHASE 2 — Visual Indicator Module
**Deliverable: `XAU_Master_Indicator.mq5` + `XAU_HUD_Panel.mqh` rendering correctly on a live M1 chart**

---

## Prompt 2.1 — HUD Panel Module
**XAU_HUD_Panel.mqh**

---

```
Task:
  Create XAU_HUD_Panel.mqh — the on-chart dashboard overlay.

  Create function: void DrawHUD()
  Creates/updates OBJ_LABEL objects in CORNER_LEFT_UPPER starting at pixel (10, 30).
  All objects must be prefixed "XAU_HUD_" for clean deletion.
  Each row is 20 pixels apart.
  Add a background rectangle: OBJ_RECTANGLE_LABEL named "XAU_HUD_BG",
    dark fill (C'20,20,30'), width 200px, height 130px, at (5, 25).

  Panel rows — updated on every call:

  Row 1 — SPREAD:
    Value : SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) as "XX pts"
    Color : clrLimeGreen if <= XAU_SPREAD_MAX, else clrRed

  Row 2 — ADR%:
    Value : (iHigh(_Symbol,PERIOD_D1,0) - iLow(_Symbol,PERIOD_D1,0))
            divided by the 20-day average daily range, expressed as "XX%"
            Calculate 20-day ADR using CopyRates() on D1 for last 21 bars.
    Color : clrLimeGreen if < 70%, clrOrange if 70–90%, clrRed if > 90%

  Row 3 — DXY:
    Value : GetDXYStatus() — returns "BULLISH $" / "BEARISH $" / "NEUTRAL"
            (GetDXYStatus() will be implemented in XAU_DXY_Monitor.mqh —
             for now, stub it as: string GetDXYStatus() { return "NEUTRAL"; })
    Color : clrRed if "BULLISH $", clrLimeGreen if "BEARISH $", clrGray if "NEUTRAL"

  Row 4 — SESSION:
    Determine current GMT hour from TimeGMT().
    Display:
      "LONDON OPEN"  if hour >= XAU_LONDON_START && hour < XAU_LONDON_END
      "NY OVERLAP"   if hour >= XAU_SESSION_START && hour < XAU_SESSION_END
      "DEAD ZONE"    if hour >= XAU_DEAD_START || hour < 2
      "OFF-HOURS"    otherwise
    Color : clrLimeGreen if active session, clrRed if dead zone, clrGray otherwise

  Row 5 — NEWS:
    Value : GlobalVariableGet("XAU_NEWS_ACTIVE") == 1.0 ? "! BLOCKED !" : "CLEAR"
    Color : clrRed if blocked, clrLimeGreen if clear

  Row 6 — ATR(14):
    Value : Current ATR(XAU_ATR_PERIOD) in price points formatted to 2 decimal places
    Color : clrWhite always

  Also create function: void DeleteHUD()
    Loops ObjectsTotal() and deletes all objects with prefix "XAU_HUD_".

Output:
  XAU_HUD_Panel.mqh compiling with 0 errors.

Test:
  Create a blank indicator, include XAU_HUD_Panel.mqh, call DrawHUD() from OnTick().
  Attach to a live XAUUSD M1 chart. Confirm panel appears with correct data.
```

> 📋 **Dev Notes:**
> - `ObjectCreate()` returns false if the object already exists — use `ObjectFind()` first, or always call `ObjectDelete()` before creating.
> - The ADR calculation requires D1 data — confirm `CopyRates()` returns data before dividing.
> - Stub `GetDXYStatus()` as `return "NEUTRAL"` for now — it will be replaced in Phase 4.

---

## Prompt 2.2 — Full Indicator Implementation
**XAU_Master_Indicator.mq5**

---

```
Task:
  Create XAU_Master_Indicator.mq5 — the complete visual indicator.

Includes at top:
  #include "XAU_Master_Core.mqh"
  #include "XAU_HUD_Panel.mqh"

Properties:
  #property indicator_chart_window
  #property indicator_buffers 4
  #property indicator_plots   4

Input Parameters:
  input int    InpEMAFast      = XAU_EMA_FAST;
  input int    InpEMASlow      = XAU_EMA_SLOW;
  input int    InpRSIPeriod    = XAU_RSI_PERIOD;
  input int    InpATRPeriod    = XAU_ATR_PERIOD;
  input bool   InpShowHUD      = true;
  input bool   InpAlertDesktop = true;
  input bool   InpAlertMobile  = false;
  input bool   InpAlertEmail   = false;
  input int    InpMaxSpread    = XAU_SPREAD_MAX;

Indicator Buffers:
  Buffer 0: ema_fast[]   — LINE style, clrGold, width 2
  Buffer 1: ema_slow[]   — LINE style, clrDarkOrange, width 2
  Buffer 2: buy_signal[] — ARROW style, code 233 (up arrow), clrDodgerBlue, size 2
  Buffer 3: sell_signal[]— ARROW style, code 234 (down arrow), clrCrimson, size 2
  Set EMPTY_VALUE (DBL_MAX) as default for arrow buffers.

OnInit():
  1. Set up all 4 indicator buffers and plot properties as above.
  2. Create iMA handles for EMA fast and EMA slow (M5 timeframe).
  3. Call DrawHUD() if InpShowHUD.
  4. Return INIT_SUCCEEDED.

OnCalculate():
  1. Populate ema_fast[] and ema_slow[] using CopyBuffer() from iMA handles.

  2. On each new bar only (guard with static datetime lastBar):

     a. Call: XAU_SignalResult result = EvaluateSignal()

     b. If result.signal == XAU_BUY:
          buy_signal[1] = Low[1] - (result.atrValue * 0.5)
          if InpAlertDesktop:
            Alert("XAU BUY @ ", DoubleToString(result.entryPrice,2),
                  " | SL: ", DoubleToString(result.stopLoss,2),
                  " | TP: ", DoubleToString(result.takeProfit,2),
                  " | ", result.reason)
          if InpAlertMobile:
            SendNotification("XAU BUY @ " + DoubleToString(result.entryPrice,2)
                             + " | " + result.reason)
          if InpAlertEmail:
            SendMail("XAU_Master_2026 BUY Signal", result.reason)

     c. If result.signal == XAU_SELL: mirror for sell_signal[1].

  3. Psychological levels — draw dotted horizontal lines:
     Starting from MathFloor(Close[0] / 5.0) * 5.0, draw lines every $5.00
     within the visible chart range. Label every $10 level (e.g. "5350.00").
     Use object name prefix "XAU_PSYCH_". Limit to 20 lines — delete oldest if exceeded.
     Line style: STYLE_DOT, color: clrGold, width: 1.

  4. VWAP line — draw horizontal dashed line at GlobalVariableGet("XAU_DAILY_VWAP"):
     Object name: "XAU_VWAP_LINE". Style: STYLE_DASH. Color: clrCyan. Width: 1.
     Update position on every bar.

  5. Call DrawHUD() on every tick if InpShowHUD.

OnDeinit(const int reason):
  DeleteHUD()
  Delete all objects with prefix "XAU_PSYCH_"
  Delete object "XAU_VWAP_LINE"
  Release all indicator handles with IndicatorRelease()

Output:
  XAU_Master_Indicator.mq5 compiling with 0 errors.

Acceptance test:
  Load on a live XAUUSD M1 chart.
  Confirm: EMA lines render, HUD panel visible, no errors in Experts tab.
  Temporarily force result.signal = XAU_BUY in OnCalculate() and confirm
  an arrow appears and the desktop alert fires. Then revert.
```

> 📋 **Dev Notes:**
> - Arrow buffers must use `EMPTY_VALUE` as default — only write a price value when a signal fires, all other bars leave as `EMPTY_VALUE`.
> - The psychological level lines should be redrawn each `OnCalculate()` as price scrolls — delete and recreate each time.

---

---

# PHASE 3 — EA Foundation & Risk Engine
**Deliverable: `XAU_Master_EA.mq5` + `XAU_Risk_Manager.mqh` executing trades correctly in MT5 Strategy Tester**

---

## Prompt 3.1 — Risk Manager Module
**XAU_Risk_Manager.mqh**

---

```
Task:
  Create XAU_Risk_Manager.mqh — handles all position sizing and trade management.

Include at top:
  #include "XAU_Master_Core.mqh"
  #include <Trade/Trade.mqh>

--- CalcLotSize(double riskPct, double slPips) ---

  Parameters:
    riskPct : percentage of AccountBalance() to risk (e.g. 1.0 = 1%)
    slPips  : stop loss distance in pips

  Formula:
    riskAmount = AccountBalance() * (riskPct / 100.0)
    tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)
    tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE)
    pipValue   = tickValue * (10.0 * tickSize)   // Gold: 1 pip = 10 points
    lots       = riskAmount / (slPips * pipValue)

  Constraints:
    - Clamp between SYMBOL_VOLUME_MIN and SYMBOL_VOLUME_MAX
    - Round down to nearest SYMBOL_VOLUME_STEP
    - Return 0.0 if any broker data is invalid (log the specific error)

--- CalcDynamicSL(ENUM_XAU_SIGNAL dir) ---

  1. Get ATR value: use iATR(_Symbol, PERIOD_CURRENT, XAU_ATR_PERIOD), CopyBuffer bar[1].
  2. Read sweep level: double sweepLevel = GlobalVariableGet("XAU_SWEEP_LEVEL")
  3. For XAU_BUY:  sl_price = sweepLevel - (atr * 0.2)  (just below sweep wick)
     For XAU_SELL: sl_price = sweepLevel + (atr * 0.2)  (just above sweep wick)
  4. Hard cap check: if MathAbs(Ask - sl_price) > atr * XAU_ATR_MULTIPLIER:
       sl_price = Ask - (atr * XAU_ATR_MULTIPLIER)  (for BUY)
       sl_price = Bid + (atr * XAU_ATR_MULTIPLIER)  (for SELL)
  5. Return sl_price normalised with NormalizeDouble(_Symbol digits).

--- ManageOpenPositions(CTrade &trade) ---

  Loop all open positions for _Symbol with PositionsTotal().
  For each position matching the EA magic number:

  1. BREAKEVEN check:
       entryPrice = PositionGetDouble(POSITION_PRICE_OPEN)
       currentSL  = PositionGetDouble(POSITION_SL)
       slDistance = MathAbs(entryPrice - currentSL)

       For BUY: if (Bid - entryPrice) >= slDistance * XAU_BREAKEVEN_RR
                AND currentSL < entryPrice:
                  newSL = entryPrice + (2 * _Point)
                  trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP))
                  Print("BE: SL moved to entry+2pts for ticket ", ticket)

       For SELL: mirror logic (Ask - entryPrice direction inverted).

  2. SMART TRAIL (only after breakeven is set):
       If currentSL >= entryPrice (BUY) or currentSL <= entryPrice (SELL):
         Get current EMA(XAU_EMA_FAST) value on M1 bar[0] using CopyBuffer.
         For BUY:  if ema_value > currentSL: modify SL to ema_value
         For SELL: if ema_value < currentSL: modify SL to ema_value
         Never widen the SL — only move it in the trade's favour.

--- IsMaxDailyLossHit() ---

  1. Select today's history: HistorySelect(today_start_gmt, TimeCurrent())
  2. Sum all closed deal profits for _Symbol with EA magic number.
  3. Also add current floating P&L of all open positions.
  4. If total_loss <= -(AccountBalance() * XAU_MAX_DAILY_LOSS / 100.0):
       Print("Daily loss limit hit: ", total_loss)
       return true
  5. Return false otherwise.

Output:
  XAU_Risk_Manager.mqh compiling with 0 errors.
```

> 📋 **Dev Notes:**
> - `SYMBOL_VOLUME_STEP` for Gold is typically 0.01 — always respect this or the broker will reject the order.
> - `CalcDynamicSL()` reads `XAU_SWEEP_LEVEL` set by `CheckLock2()` — ensure CheckLock2 ran before calling this.
> - Use `NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS))` on all price values before order submission.

---

## Prompt 3.2 — Expert Advisor Shell
**XAU_Master_EA.mq5**

---

```
Task:
  Create XAU_Master_EA.mq5 — the complete Expert Advisor.

Includes:
  #include <Trade/Trade.mqh>
  #include "XAU_Master_Core.mqh"
  #include "XAU_Risk_Manager.mqh"
  #include "XAU_HUD_Panel.mqh"

Input Parameters:
  input double InpRiskPct        = XAU_RISK_PCT;
  input double InpAtrMultiplier  = XAU_ATR_MULTIPLIER;
  input int    InpMagicNumber    = 202601;
  input bool   InpShowHUD        = true;
  input bool   InpKillSwitch     = false;    // set true to halt all trading instantly
  input bool   InpSessionLondon  = true;     // also trade London Open 08-10 GMT

Global variables:
  CTrade trade;
  bool   g_tradingEnabled     = true;
  int    g_consecutiveLosses  = 0;

OnInit():
  1. trade.SetExpertMagicNumber(InpMagicNumber)
  2. trade.SetDeviationInPoints(30)        // 3 pip slippage for Gold
  3. trade.SetTypeFilling(ORDER_FILLING_IOC)
  4. Verify _Symbol contains "XAU" or "GOLD" (case insensitive).
     If not: Alert("Error: EA must run on XAUUSD or GOLD"); return INIT_FAILED.
  5. Print("XAU_Master_2026 initialised | Magic:", InpMagicNumber,
           " | Risk:", InpRiskPct, "%")
  6. Return INIT_SUCCEEDED.

OnTick():
  1. Kill switch: if InpKillSwitch:
       CloseAllPositions()
       g_tradingEnabled = false
       Comment("XAU_Master: KILL SWITCH ACTIVE")
       return

  2. if !g_tradingEnabled: return

  3. if IsMaxDailyLossHit():
       g_tradingEnabled = false
       Alert("XAU_Master: Daily loss limit hit. EA stopped for today.")
       return

  4. if g_consecutiveLosses >= 3:
       g_tradingEnabled = false
       Alert("XAU_Master: 3 consecutive losses. EA paused. Manual reset required.")
       return

  5. ManageOpenPositions(trade)    // always manage open trades first

  6. if CountOpenPositions() > 0: return   // one trade at a time only

  7. Check session:
       int gmtHour = TimeGMT() / 3600 % 24  // extract GMT hour
       bool inOverlap = (gmtHour >= XAU_SESSION_START && gmtHour < XAU_SESSION_END)
       bool inLondon  = (gmtHour >= XAU_LONDON_START  && gmtHour < XAU_LONDON_END)
       bool inDead    = (gmtHour >= XAU_DEAD_START || gmtHour < 2)
       if inDead: return
       if !inOverlap && !(InpSessionLondon && inLondon): return

  8. Check spread:
       if SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > XAU_SPREAD_MAX: return

  9. XAU_SignalResult result = EvaluateSignal()
     if result.signal == XAU_NO_SIGNAL: return

  10. double sl   = CalcDynamicSL(result.signal)
      double slPips = MathAbs(result.entryPrice - sl) / (_Point * 10.0)
      double lots  = CalcLotSize(InpRiskPct, slPips)
      if lots <= 0.0: return

  11. if result.signal == XAU_BUY:
        trade.Buy(lots, _Symbol, result.entryPrice, sl, result.takeProfit,
                  "XAU_BUY|" + result.reason)
      if result.signal == XAU_SELL:
        trade.Sell(lots, _Symbol, result.entryPrice, sl, result.takeProfit,
                   "XAU_SELL|" + result.reason)

  12. if InpShowHUD: DrawHUD()

OnTradeTransaction(const MqlTradeTransaction &trans, ...):
  if trans.type == TRADE_TRANSACTION_DEAL_ADD:
    if HistoryDealSelect(trans.deal):
      double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
      if profit < 0.0: g_consecutiveLosses++
      else:            g_consecutiveLosses = 0

CloseAllPositions():
  for (int i = PositionsTotal()-1; i >= 0; i--):
    if PositionGetSymbol(i) == _Symbol &&
       PositionGetInteger(POSITION_MAGIC) == InpMagicNumber:
      trade.PositionClose(PositionGetInteger(POSITION_TICKET))

CountOpenPositions():
  int count = 0
  for each position: if symbol match && magic match: count++
  return count

OnDeinit(const int reason):
  DeleteHUD()
  Comment("")

Output:
  XAU_Master_EA.mq5 compiling with 0 errors.

Acceptance test:
  Run in Strategy Tester: XAUUSD M1, 2025.01.01–2025.03.01, Every Tick (Real).
  Confirm: trades open with correct lot size, SL and TP are set, no critical errors
  in the Journal tab. Check that no trade opens with spread > XAU_SPREAD_MAX.
```

> 📋 **Dev Notes:**
> - `ORDER_FILLING_IOC` is the most broker-compatible fill mode for Gold — `FOK` causes frequent rejections.
> - `OnTradeTransaction()` is the correct MT5 method for detecting closed trades — do not poll in `OnTick()`.
> - The `InpKillSwitch` input allows emergency halt from the EA Properties panel without recompiling.

---

---

# PHASE 4 — Filters, Safety & Supporting Modules
**Deliverable: All filter modules integrated. EA passes all filter scenarios.**

---

## Prompt 4.1 — Daily VWAP Calculator
**Add to XAU_Master_Core.mqh**

---

```
Task:
  Implement the CalcDailyVWAP() stub already declared in XAU_Master_Core.mqh.

Algorithm:
  1. Get today's session start timestamp:
       datetime today_start = iTime(_Symbol, PERIOD_D1, 0)

  2. Use CopyRates() to retrieve all M1 bars from today_start until now.
       MqlRates bars[]
       int count = CopyRates(_Symbol, PERIOD_M1, today_start, TimeCurrent(), bars)
       If count <= 0: use fallback (see step 5).

  3. Calculate cumulative VWAP:
       double cum_tp_vol = 0.0
       double cum_vol    = 0.0
       for each bar in bars[]:
         typical_price  = (bar.high + bar.low + bar.close) / 3.0
         cum_tp_vol    += typical_price * (double)bar.tick_volume
         cum_vol       += (double)bar.tick_volume

  4. vwap = cum_tp_vol / cum_vol
     GlobalVariableSet("XAU_DAILY_VWAP", vwap)
     return vwap

  5. Fallback cases (return and log a warning for each):
       - If count <= 0 (no bars loaded): return iClose(_Symbol, PERIOD_D1, 1)
       - If cum_vol == 0.0:              return SymbolInfoDouble(_Symbol, SYMBOL_BID)

Output:
  Updated XAU_Master_Core.mqh. Compilation 0 errors.

Verification:
  Print CalcDailyVWAP() result on every new bar.
  Confirm the value is close to the intraday average price.
  Confirm it resets each day at 00:00 GMT (value shifts at day open).
```

> 📋 **Dev Notes:**
> - VWAP accuracy improves significantly after 30+ bars of the day — early session values will be less stable.
> - `GlobalVariableSet("XAU_DAILY_VWAP", vwap)` makes the value available to both the Indicator and EA simultaneously.
> - Visually compare against a third-party VWAP indicator on the same chart to validate accuracy.

---

## Prompt 4.2 — News Filter
**XAU_News_Filter.mqh**

---

```
Task:
  Create XAU_News_Filter.mqh — blocks trading around high-impact news events.

  MT5 provides built-in calendar functions from Build 2260+.
  We use CalendarValueHistory() to check for upcoming USD events.

--- IsHighImpactNewsActive(int bufferMinutes = 15) ---

  1. datetime now       = TimeGMT()
     datetime from_time = now - (bufferMinutes * 60)
     datetime to_time   = now + (bufferMinutes * 60)

  2. MqlCalendarValue usd_values[]
     CalendarValueHistory(usd_values, from_time, to_time, "USD", NULL)

  3. MqlCalendarValue xau_values[]
     CalendarValueHistory(xau_values, from_time, to_time, "XAU", NULL)

  4. For each value in usd_values[] and xau_values[]:
       MqlCalendarEvent event_info
       if CalendarEventById(value.event_id, event_info):
         if event_info.importance == CALENDAR_IMPORTANCE_HIGH:
           GlobalVariableSet("XAU_NEWS_ACTIVE", 1.0)
           Print("News block: ", event_info.name, " | importance: HIGH")
           return true

  5. GlobalVariableSet("XAU_NEWS_ACTIVE", 0.0)
     return false

--- UpdateNewsGlobal() ---

  Rate-limit news checks to once every 60 seconds:
    static datetime lastCheck = 0
    if (TimeCurrent() - lastCheck) < 60: return
    lastCheck = TimeCurrent()
    IsHighImpactNewsActive()

--- GetNextNewsEvent() ---

  Returns a string describing the next upcoming high-impact USD event.
  Search forward from TimeGMT() for up to 4 hours.
  Format: "NFP in 23 min" or "CPI in 2h 10min" or "No events <4h"
  Use CalendarValueHistory() with a 4-hour forward window.

Fallback (if Calendar API unavailable):
  static bool newsFilterDisabled = false
  In OnInit() of the EA, test CalendarValueHistory() with a dummy call.
  If it returns an error, set newsFilterDisabled = true and log:
  "WARNING: MT5 Calendar API unavailable. News filter disabled."
  IsHighImpactNewsActive() returns false when disabled.

Output:
  XAU_News_Filter.mqh compiling with 0 errors.

Test:
  Call IsHighImpactNewsActive() and print result every minute.
  Confirm it returns true within 15 minutes of a known upcoming event.
```

> 📋 **Dev Notes:**
> - `CalendarValueHistory()` requires MT5 Build 2260+ — check with `TerminalInfoInteger(TERMINAL_BUILD)` in OnInit.
> - Some brokers restrict calendar access — always implement the disabled fallback gracefully.
> - In Strategy Tester, the calendar API returns no events — this is expected. The filter will be inactive during backtests.

---

## Prompt 4.3 — DXY Momentum Monitor
**XAU_DXY_Monitor.mqh**

---

```
Task:
  Create XAU_DXY_Monitor.mqh — synthetic DXY momentum scoring from USD pairs.

  Most brokers do not offer DXY as a tradeable symbol.
  We construct a momentum proxy from 5 correlated USD pairs.

--- CalcDXYMomentumScore() ---

  Pairs to use:
    USD-quote (invert ROC): EURUSD, GBPUSD
    USD-base  (keep ROC):   USDJPY, USDCHF, USDCAD

  Algorithm:
    1. For each pair, use CopyRates() to get last 4 closed M5 bars.
       If CopyRates fails for a pair: skip it, log warning, continue.

    2. Calculate 3-bar Rate of Change:
         roc = (bars[1].close - bars[3].close) / bars[3].close

    3. Apply direction:
         For EURUSD, GBPUSD: contribution = -roc  (EUR up = DXY down)
         For USDJPY, USDCHF, USDCAD: contribution = roc

    4. Average all valid contributions → raw_score

    5. Normalize using a 20-period rolling min/max stored in static arrays:
         Push raw_score into a static double array[20] (circular buffer).
         min_val = minimum of array
         max_val = maximum of array
         If (max_val - min_val) > 0:
           normalized = 2.0 * (raw_score - min_val) / (max_val - min_val) - 1.0
         Else:
           normalized = 0.0  (insufficient history)

    6. GlobalVariableSet("XAU_DXY_MOMENTUM", normalized)
       return normalized

    Edge cases:
      - Minimum 3 valid pairs required.
        If fewer: set score = 0.0, log "DXY: insufficient pair data", return 0.0.
      - If a pair symbol does not exist on broker:
        log "DXY: symbol [PAIR] not available" and skip.

--- GetDXYStatus() ---

  double score = GlobalVariableGet("XAU_DXY_MOMENTUM")
  if score >  0.5: return "BULLISH $"
  if score < -0.5: return "BEARISH $"
  return "NEUTRAL"

Integration:
  Replace the stub GetDXYStatus() in XAU_HUD_Panel.mqh with:
    #include "XAU_DXY_Monitor.mqh"
  and remove the stub.

  Call CalcDXYMomentumScore() from EvaluateSignal() in XAU_Master_Core.mqh
  before CheckMacroBias() runs (add after CalcDailyVWAP() call).

Output:
  XAU_DXY_Monitor.mqh compiling with 0 errors.
  HUD panel DXY row updated with live GetDXYStatus() output.
```

> 📋 **Dev Notes:**
> - This is a momentum proxy, not a true DXY price index — use it for directional bias only, not price levels.
> - If your broker offers DXY as a custom symbol, simplify this entire module to just reading its 3-bar ROC directly.
> - The normalization step is important — without it, the score can exceed 1.0 in high-volatility sessions.

---

## Prompt 4.4 — Trade Logger
**XAU_Logger.mqh**

---

```
Task:
  Create XAU_Logger.mqh — writes a detailed trade log to a CSV file.

File setup:
  Filename pattern: "XAU_Master_Log_" + TimeToString(TimeGMT(), TIME_DATE) + ".csv"
  (e.g. "XAU_Master_Log_2026.03.10.csv")
  Path: TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\"
  Open mode: FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON
  Always close the file handle immediately after each write.

CSV Headers (write only if file is new / size == 0):
  Timestamp_GMT, Signal, EntryPrice, StopLoss, TakeProfit, Lots, ATRValue,
  SpreadAtEntry, DXYScore, NewsActive, EMAFast, EMASlow, VWAPValue, RSIValue, Reason

--- LogSignal(XAU_SignalResult &result, double lots) ---

  Called immediately after a trade opens successfully.
  Append one data row with current values of all header fields.
  Read live values for: spread, DXY score, news status, EMA values, VWAP, RSI.
  Format prices to 2 decimal places, lots to 2 decimal places.
  On file open failure: Print("Logger error: ", GetLastError()) — do not crash.

--- LogTradeClose(ulong ticket, double profit, string closeReason) ---

  Called when a position closes.
  Append to a separate section (or same file with a "CLOSE" prefix row):
  Columns: Timestamp_GMT, "CLOSE", Ticket, ClosePrice, Profit_USD, CloseReason
  closeReason values: "SL" / "TP" / "BE" / "TRAIL" / "MANUAL" / "KILL_SWITCH"

Output:
  XAU_Logger.mqh compiling with 0 errors.

Test:
  In Strategy Tester, run XAU_Master_EA for 1 week.
  Open the MQL5/Files/ directory and confirm:
    - CSV file exists with correct filename
    - Header row is present
    - Each trade has a corresponding data row
    - File is readable in Excel while MT5 is running
```

> 📋 **Dev Notes:**
> - `FILE_SHARE_READ` allows you to open and read the CSV in Excel while MT5 is writing to it.
> - Always close the file handle (`FileClose(handle)`) — leaving it open causes file lock issues on Windows.
> - The log CSV is the primary tool for Phase 5 analysis — ensure every backtested trade appears here.

---

## Prompt 4.5 — Full Integration
**XAU_Master_EA.mq5 — Final Update**

---

```
Task:
  Update XAU_Master_EA.mq5 to include and integrate all Phase 4 modules.

Step 1 — Add includes:
  #include "XAU_News_Filter.mqh"
  #include "XAU_DXY_Monitor.mqh"
  #include "XAU_Logger.mqh"

Step 2 — Add input parameters:
  input int    InpNewsBuffer   = 15;     // minutes before/after news to block
  input bool   InpEnableLog    = true;   // write trade log CSV

Step 3 — Update OnTick() — add at the very top before signal evaluation:
  CalcDailyVWAP()               // refresh VWAP global
  CalcDXYMomentumScore()        // refresh DXY global
  UpdateNewsGlobal()            // refresh news global (rate-limited internally)

Step 4 — After successful trade.Buy() or trade.Sell():
  if (trade.ResultRetcode() == TRADE_RETCODE_DONE && InpEnableLog):
    LogSignal(result, lots)

Step 5 — In OnTradeTransaction(), after detecting a closed deal:
  if InpEnableLog:
    determine closeReason from deal comment or entry type
    LogTradeClose(trans.deal, deal_profit, closeReason)

Step 6 — Add build version check in OnInit():
  if TerminalInfoInteger(TERMINAL_BUILD) < 2260:
    Print("WARNING: MT5 Build < 2260. News calendar filter disabled.")
  (The news filter handles this gracefully internally.)

Final compilation check:
  XAU_Master_EA.mq5 must compile with 0 errors, 0 warnings.
  All includes must resolve. No circular dependencies.

Acceptance test:
  Strategy Tester: XAUUSD M1, 2025.06.01–2025.09.01, Every Tick (Real).
  Confirm in Strategy Tester Journal:
    - Trades fire only during session hours (13:00–17:00 GMT or 08:00–10:00 GMT)
    - No trades open with spread > XAU_SPREAD_MAX (verify in CSV log)
    - DXY and VWAP values are non-zero in log rows
    - CSV file is created in MQL5/Files/ with all columns populated
```

> 📋 **Dev Notes:**
> - Run the Strategy Tester with Visual Mode ON to watch the EA trade on the chart in real-time.
> - Check the Journal tab for any file I/O or global variable errors during the backtest.
> - The News filter will show no blocks in Strategy Tester (no live calendar) — this is expected behaviour.

---

---

# PHASE 5 — Stress Testing & Optimisation
**Deliverable: Backtest report meeting all acceptance criteria + 2-week demo forward test**

---

## Prompt 5.1 — Backtest Configuration & Analysis Script
**Strategy Tester + AnalyseBacktest.mq5**

---

```
Task:
  Provide the optimal Strategy Tester configuration for XAU_Master_2026
  and create an MQL5 analysis script AnalyseBacktest.mq5.

--- Strategy Tester Settings ---

  Expert Advisor : XAU_Master_EA
  Symbol         : XAUUSD (use whichever symbol has the most tick data on your broker)
  Timeframe      : M1
  Modelling      : Every Tick Based on Real Ticks  (MANDATORY — no other mode)
  Date From      : 2025.01.01
  Date To        : 2026.02.28
  Initial Deposit: 10,000 USD
  Leverage       : 1:100

Recommended optimisation parameter ranges for a first pass:
  InpRiskPct        : 0.5  to 2.0,  step 0.25
  InpAtrMultiplier  : 1.0  to 2.5,  step 0.25
  InpMaxSpread      : 25   to 45,   step 5
  InpNewsBuffer     : 10   to 20,   step 5
  (Keep all session/timing parameters fixed during first pass.)

Acceptance criteria to check in backtest report:
  Net Profit          : Positive
  Win Rate            : > 48%
  Max Drawdown        : < 8% of starting equity
  Profit Factor       : > 1.3
  Sharpe Ratio        : > 1.2
  Total Trades        : > 150 (minimum for statistical validity)
  Max Consecutive Loss: < 8

--- AnalyseBacktest.mq5 ---

  Create a script (runs once in Strategy Tester or on demand).

  The script reads the XAU_Master_Log_*.csv files from MQL5/Files/ and outputs:

  Section 1 — Performance Summary:
    Total trades, Win count, Loss count, Win Rate %
    Average win ($), Average loss ($), Profit Factor
    Max consecutive losses, Total net P&L

  Section 2 — Filter Compliance Audit:
    For each trade row in the CSV:
      a. Check SpreadAtEntry <= XAU_SPREAD_MAX.
         If violated: Print("SPREAD_VIOLATION: ticket [X], spread [Y]")
      b. Check NewsActive == 0 at entry.
         If violated: Print("NEWS_VIOLATION: trade opened during news window")
      c. Check VWAPValue != 0.
         If zero: Print("VWAP_WARNING: VWAP was zero at entry [timestamp]")
      d. Check DXYScore field is populated (not empty).

  Section 3 — Summary line:
    Print total violations count.
    If violations == 0: Print("AUDIT PASSED: All filter compliance checks clean.")
    Else: Print("AUDIT FAILED: ", violations, " violations found. Review before live.")

Output:
  AnalyseBacktest.mq5 compiling with 0 errors.
  Run against a completed backtest CSV. Confirm clean output in Experts log.
```

> 📋 **Dev Notes:**
> - Real-Tick modelling is non-negotiable for a Gold scalper — Open Price or OHLC models are meaningless on M1.
> - Run 3 separate backtests: full period, London Open only (08–10 GMT), NY Overlap only (13–17 GMT) and compare.
> - If win rate is below 45%, review the Lock 2 wick ratio — the sweep detection may be too permissive.

---

## Prompt 5.2 — Demo Forward Test Monitor
**XAU_ForwardTest_Monitor.mq5**

---

```
Task:
  Create XAU_ForwardTest_Monitor.mq5 — a script that prints a complete status
  report for the 2-week demo forward test. Run on demand each morning.

Output sections (print to Experts log with clear separators):

--- SECTION 1: Account Summary ---
  Balance, Equity, Floating P&L
  Today's realised P&L (sum of today's closed deals)
  Total trades taken since EA start (read from CSV log row count)
  Current drawdown % from equity peak

--- SECTION 2: Performance Metrics ---
  Win Rate of all closed trades (from CSV)
  Average win ($), Average loss ($)
  Profit Factor
  Largest single loss
  Current consecutive loss count (read from EA global or CSV)

--- SECTION 3: Filter Compliance Audit (last 48 hours) ---
  Check each trade entry in the CSV log for the last 48 hours:

  a. SESSION CHECK:
     Parse Timestamp_GMT from CSV. Extract GMT hour.
     If hour NOT in [08–10] and NOT in [13–17]: flag "SESSION_VIOLATION"

  b. NEWS CHECK:
     If NewsActive column == 1 for any entry: flag "NEWS_VIOLATION"

  c. SPREAD CHECK:
     If SpreadAtEntry > XAU_SPREAD_MAX for any entry: flag "SPREAD_VIOLATION"

  d. SIGNAL QUALITY:
     If Reason column is empty or "NONE": flag "MISSING_REASON"
     If VWAPValue == 0 at entry: flag "VWAP_ZERO"
     If DXYScore column is empty: flag "DXY_MISSING"

  Print total violation count.
  If 0 violations: "FILTER AUDIT: PASS"
  Else: "FILTER AUDIT: FAIL — [N] violations. Do not go live until resolved."

--- SECTION 4: Alerts ---
  If consecutive losses >= 2: "ALERT: Approaching consecutive loss limit."
  If drawdown > 5%: "WARNING: Drawdown exceeding 5%. Review position sizing."
  If no trades in last 2 active sessions: "INFO: No signals fired. Verify EA is running and filters are not over-blocking."
  If all metrics within targets: "STATUS: System performing within parameters."

Output:
  XAU_ForwardTest_Monitor.mq5 compiling with 0 errors.

Usage:
  Run this script each morning of the 2-week forward test.
  All filter audit checks must show PASS before considering live deployment.
  Any VIOLATION means there is a logic bug in the corresponding filter — fix it.
```

> 📋 **Dev Notes:**
> - The forward test is not only about profit — it is about verifying every safety system works in live conditions.
> - Any filter violation during the demo means the system is **not ready for live** — treat violations as bugs, not warnings.
> - Run the demo test on a broker account with the same trading conditions as your intended live account (same spread, same server).

---

---

# Quick Reference — Prompt Sequence

| # | File | Description | Phase |
|---|------|-------------|-------|
| 0 | *(session)* | Session Context Header — paste at start of every Trae.AI session | Setup |
| 1.1 | Core.mqh | Scaffold, `#define`, enums, struct, stubs | Phase 1 |
| 1.2 | Core.mqh | `CheckMacroBias()` + `CheckLock1()` — EMA / VWAP / DXY guard | Phase 1 |
| 1.3 | Core.mqh | `CheckLock2()` — liquidity sweep with wick ratio + volume filter | Phase 1 |
| 1.4 | Core.mqh | `CheckLock3()` + `EvaluateSignal()` — RSI / Stoch / pattern / master caller | Phase 1 |
| 2.1 | HUD.mqh | On-chart dashboard — spread, ADR%, DXY, session, news, ATR | Phase 2 |
| 2.2 | Indicator.mq5 | Full indicator — arrows, EMA cloud, VWAP, psych levels, alerts | Phase 2 |
| 3.1 | Risk.mqh | `CalcLotSize`, `CalcDynamicSL`, `ManageOpenPositions`, daily loss | Phase 3 |
| 3.2 | EA.mq5 | Expert Advisor shell — full trade lifecycle, kill switch | Phase 3 |
| 4.1 | Core.mqh | `CalcDailyVWAP()` — M1 cumulative VWAP with daily reset | Phase 4 |
| 4.2 | News.mqh | `IsHighImpactNewsActive()` — MT5 Calendar API integration | Phase 4 |
| 4.3 | DXY.mqh | `CalcDXYMomentumScore()` — synthetic DXY from 5 USD pairs | Phase 4 |
| 4.4 | Logger.mqh | CSV trade logger — all filter states per entry and exit | Phase 4 |
| 4.5 | EA.mq5 | Final integration — wire all Phase 4 modules | Phase 4 |
| 5.1 | Tester | Backtest config, optimisation ranges, `AnalyseBacktest.mq5` | Phase 5 |
| 5.2 | Monitor | Demo forward test monitor — filter audit, performance report | Phase 5 |

---

> **Execute in sequence. Compile at every step. Trade responsibly.**
>
> *XAU_Master_2026 — Trae.AI Development Prompt Pack v2.0*
