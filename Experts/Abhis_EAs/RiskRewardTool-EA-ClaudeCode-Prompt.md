# MT5 Risk/Reward Trading Tool - Expert Advisor (EA) Development Prompt

## Project Overview

Build a professional MT5 **Expert Advisor (EA)** called "RiskRewardTool" that replicates TradingView's risk/reward drawing tool functionality. This EA allows traders to visually plan trades with draggable entry, stop-loss, and take-profit levels while automatically calculating position sizing based on risk parameters. **One-click order execution** — no manual SL/TP placement required.

## IMPORTANT: This is an EA, NOT an Indicator

This must be an EA (Expert Advisor) because:
- Indicators CANNOT place trades in MT5
- EAs CAN attach to multiple charts simultaneously (one instance per chart)
- Each instance uses `InstanceName` parameter to avoid object name conflicts

File extension: `.mq5` (same as indicator, but structured as EA)

## Core Requirements

### 1. Visual Components

Create three draggable horizontal lines:
- **Entry Line** (Blue) - The planned entry price
- **Stop Loss Line** (Red) - Below entry for longs, above for shorts
- **Take Profit Line** (Green) - Above entry for longs, below for shorts

Create two semi-transparent rectangle zones:
- **Risk Zone** (Red, 20% opacity) - Between Entry and Stop Loss
- **Reward Zone** (Green, 20% opacity) - Between Entry and Take Profit

All lines must have:
- `OBJPROP_SELECTABLE = true`
- `OBJPROP_SELECTED = true` (initially)
- Price labels showing the exact price level on the right side
- Pips/points distance label from entry

### 2. Risk Calculation Modes

Implement these risk modes via input parameter enum:
```mql5
enum ENUM_RISK_MODE {
    RISK_FIXED_CASH_BALANCE,    // Fixed $ from Balance
    RISK_FIXED_CASH_EQUITY,     // Fixed $ from Equity
    RISK_PERCENT_BALANCE,       // % of Balance
    RISK_PERCENT_EQUITY         // % of Equity
};
```

### 3. Order Type Options

```mql5
enum ENUM_ORDER_TYPE_ENTRY {
    ORDER_TYPE_MARKET,         // Market Order (instant execution)
    ORDER_TYPE_PENDING_LIMIT,  // Limit Order (at Entry price)
    ORDER_TYPE_PENDING_STOP    // Stop Order (at Entry price)
};
```

### 4. Input Parameters

```mql5
//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// === Risk Settings ===
input group "Risk Settings"
input ENUM_RISK_MODE RiskMode = RISK_PERCENT_BALANCE;  // Risk Mode
input double RiskValue = 1.0;                           // Risk Value ($ or %)
input double DefaultRRRatio = 2.0;                      // Default Risk:Reward Ratio

// === Order Settings ===
input group "Order Settings"
input ENUM_ORDER_TYPE_ENTRY OrderType = ORDER_TYPE_MARKET;  // Order Type
input bool ShowConfirmation = true;                          // Show Confirmation Dialog
input int Slippage = 10;                                     // Slippage (points)
input string InstanceName = "RR1";                           // Instance Name (for multiple charts)

// === Visual Settings ===
input group "Visual Settings"
input color EntryColor = clrDodgerBlue;                 // Entry Line Color
input color StopLossColor = clrCrimson;                 // Stop Loss Line Color
input color TakeProfitColor = clrLimeGreen;             // Take Profit Line Color
input color RiskZoneColor = clrCrimson;                 // Risk Zone Color
input color RewardZoneColor = clrLimeGreen;             // Reward Zone Color
input int ZoneOpacity = 20;                             // Zone Opacity (0-100%)
input int LineWidth = 2;                                // Line Width
input ENUM_LINE_STYLE LineStyle = STYLE_SOLID;          // Line Style
input int FontSize = 9;                                 // Font Size
input color TextColor = clrWhite;                       // Text Color
input color PanelBgColor = C'40,40,40';                 // Panel Background Color
input color PanelBorderColor = clrGray;                 // Panel Border Color

// === Panel Settings ===
input group "Panel Settings"
input ENUM_BASE_CORNER PanelCorner = CORNER_LEFT_UPPER; // Panel Corner
input int PanelX = 20;                                  // Panel X Offset
input int PanelY = 50;                                  // Panel Y Offset
```

### 5. Information Panel with ONE-CLICK Execution

Create a compact on-chart panel displaying real-time calculations:

```
┌──────────────────────────────────┐
│  [InstanceName] Risk/Reward Tool │
├──────────────────────────────────┤
│  Direction:     🔼 LONG          │
│  Entry:         1.08550          │
│  Stop Loss:     1.08450 (10.0 p) │
│  Take Profit:   1.08750 (20.0 p) │
├──────────────────────────────────┤
│  Risk:          $100.00          │
│  Reward:        $200.00          │
│  R:R Ratio:     1 : 2.0          │
├──────────────────────────────────┤
│  Lot Size:      0.50             │
│  Risk Mode:     1% of Balance    │
├──────────────────────────────────┤
│  ┌────────────────────────────┐  │
│  │     🚀 EXECUTE ORDER       │  │  ← ONE-CLICK BUTTON (Large, prominent)
│  └────────────────────────────┘  │
│                                  │
│  [ RESET ]         [ REMOVE ]    │  ← Secondary buttons (smaller)
└──────────────────────────────────┘
```

**Button Behaviors:**
- **EXECUTE ORDER** — Places the trade immediately with calculated lot size, SL, and TP. One click = order sent.
- **RESET** — Resets lines to default positions around current price
- **REMOVE** — Removes all EA objects from chart (cleanup)

Use `OBJ_RECTANGLE_LABEL` for panel background, `OBJ_LABEL` for text, and `OBJ_BUTTON` for clickable buttons.

### 6. One-Click Order Execution Flow

```
User drags lines to desired levels
         ↓
EA auto-calculates: lot size, risk $, reward $, R:R
         ↓
User clicks "EXECUTE ORDER" button
         ↓
(Optional) Confirmation dialog appears
         ↓
EA places order with:
  - Calculated lot size
  - Entry price (market or pending)
  - Stop Loss (from SL line)
  - Take Profit (from TP line)
  - Comment = InstanceName
  - Magic Number = hash of InstanceName
         ↓
Success/Error message displayed
         ↓
Lines remain for reference (user can click RESET or REMOVE)
```

### 7. Position Sizing Logic

```mql5
//+------------------------------------------------------------------+
//| Calculate lot size based on risk parameters                       |
//+------------------------------------------------------------------+
double CalculateLotSize() {
    double riskAmount = GetRiskAmount();
    double slDistance = MathAbs(entryPrice - slPrice);
    
    if(slDistance == 0) return 0;
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickValue == 0 || tickSize == 0) return 0;
    
    double riskPerLot = (slDistance / tickSize) * tickValue;
    
    if(riskPerLot == 0) return 0;
    
    double lotSize = riskAmount / riskPerLot;
    
    // Normalize to broker requirements
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    
    return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Get risk amount based on selected mode                            |
//+------------------------------------------------------------------+
double GetRiskAmount() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    switch(RiskMode) {
        case RISK_FIXED_CASH_BALANCE:
        case RISK_FIXED_CASH_EQUITY:
            return RiskValue;
        case RISK_PERCENT_BALANCE:
            return balance * RiskValue / 100.0;
        case RISK_PERCENT_EQUITY:
            return equity * RiskValue / 100.0;
    }
    return 0;
}
```

### 8. Event Handling

```mql5
//+------------------------------------------------------------------+
//| ChartEvent handler                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    
    // === Handle Line Dragging ===
    if(id == CHARTEVENT_OBJECT_DRAG) {
        if(StringFind(sparam, prefix) == 0) {  // Our object
            if(sparam == prefix + "EntryLine" || 
               sparam == prefix + "SLLine" || 
               sparam == prefix + "TPLine") {
                
                // Update prices from line positions
                UpdatePricesFromLines();
                
                // Recalculate everything
                RecalculateAll();
                
                // Redraw visual elements
                RedrawZones();
                RedrawLabels();
                UpdatePanel();
                
                ChartRedraw();
            }
        }
    }
    
    // === Handle Button Clicks ===
    if(id == CHARTEVENT_OBJECT_CLICK) {
        
        // EXECUTE ORDER - One Click Trading
        if(sparam == prefix + "BtnExecute") {
            ExecuteOrder();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);  // Reset button state
        }
        
        // RESET - Reset lines to default
        if(sparam == prefix + "BtnReset") {
            ResetLinesToDefault();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
        
        // REMOVE - Clean up and remove EA visuals
        if(sparam == prefix + "BtnRemove") {
            CleanupObjects();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
    }
    
    // === Handle Chart Click (optional: click to move nearest line) ===
    if(id == CHARTEVENT_CLICK) {
        // Can implement click-to-place functionality here
    }
}
```

### 9. Order Execution — ONE CLICK

```mql5
//+------------------------------------------------------------------+
//| Execute order with one click                                      |
//+------------------------------------------------------------------+
void ExecuteOrder() {
    // Validate lot size
    double lots = CalculateLotSize();
    if(lots <= 0) {
        Alert("Invalid lot size. Check risk settings.");
        return;
    }
    
    // Get prices
    double entry = entryPrice;
    double sl = slPrice;
    double tp = tpPrice;
    
    // Determine direction
    bool isLong = IsLongPosition();
    
    // Confirmation dialog (if enabled)
    if(ShowConfirmation) {
        string direction = isLong ? "BUY" : "SELL";
        string orderTypeStr = "";
        switch(OrderType) {
            case ORDER_TYPE_MARKET: orderTypeStr = "Market"; break;
            case ORDER_TYPE_PENDING_LIMIT: orderTypeStr = "Limit"; break;
            case ORDER_TYPE_PENDING_STOP: orderTypeStr = "Stop"; break;
        }
        
        string message = StringFormat(
            "Execute %s %s Order?\n\n" +
            "Symbol: %s\n" +
            "Lots: %.2f\n" +
            "Entry: %s\n" +
            "Stop Loss: %s\n" +
            "Take Profit: %s\n\n" +
            "Risk: $%.2f\n" +
            "Reward: $%.2f\n" +
            "R:R: 1:%.1f",
            direction, orderTypeStr, _Symbol, lots,
            DoubleToString(entry, _Digits),
            DoubleToString(sl, _Digits),
            DoubleToString(tp, _Digits),
            GetRiskAmount(),
            CalculateRewardAmount(),
            CalculateRRRatio()
        );
        
        int result = MessageBox(message, "Confirm Order - " + InstanceName, MB_YESNO | MB_ICONQUESTION);
        if(result != IDYES) return;
    }
    
    // Prepare order request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.symbol = _Symbol;
    request.volume = lots;
    request.sl = NormalizeDouble(sl, _Digits);
    request.tp = NormalizeDouble(tp, _Digits);
    request.deviation = Slippage;
    request.magic = GenerateMagicNumber(InstanceName);
    request.comment = InstanceName;
    request.type_filling = GetFillingMode();
    
    // Set order type and action
    if(OrderType == ORDER_TYPE_MARKET) {
        // Market order - instant execution
        request.action = TRADE_ACTION_DEAL;
        if(isLong) {
            request.type = ORDER_TYPE_BUY;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        } else {
            request.type = ORDER_TYPE_SELL;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        }
    }
    else if(OrderType == ORDER_TYPE_PENDING_LIMIT) {
        // Limit order at entry price
        request.action = TRADE_ACTION_PENDING;
        request.price = NormalizeDouble(entry, _Digits);
        if(isLong) {
            request.type = ORDER_TYPE_BUY_LIMIT;
        } else {
            request.type = ORDER_TYPE_SELL_LIMIT;
        }
    }
    else if(OrderType == ORDER_TYPE_PENDING_STOP) {
        // Stop order at entry price
        request.action = TRADE_ACTION_PENDING;
        request.price = NormalizeDouble(entry, _Digits);
        if(isLong) {
            request.type = ORDER_TYPE_BUY_STOP;
        } else {
            request.type = ORDER_TYPE_SELL_STOP;
        }
    }
    
    // Send order
    if(!OrderSend(request, result)) {
        string errorMsg = StringFormat("Order failed!\nError code: %d\nDescription: %s", 
                                        result.retcode, GetRetcodeDescription(result.retcode));
        Alert(errorMsg);
        Print(errorMsg);
    } else {
        if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
            string successMsg = StringFormat("Order executed successfully!\nTicket: %d", result.order);
            Alert(successMsg);
            Print(successMsg);
        } else {
            string warningMsg = StringFormat("Order sent with code: %d", result.retcode);
            Alert(warningMsg);
            Print(warningMsg);
        }
    }
}

//+------------------------------------------------------------------+
//| Get correct filling mode for broker                               |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingMode() {
    uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
    if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
    return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| Generate magic number from instance name                          |
//+------------------------------------------------------------------+
ulong GenerateMagicNumber(string name) {
    ulong hash = 0;
    for(int i = 0; i < StringLen(name); i++) {
        hash = hash * 31 + StringGetCharacter(name, i);
    }
    return hash % 2147483647;  // Keep within int range
}

//+------------------------------------------------------------------+
//| Get retcode description                                           |
//+------------------------------------------------------------------+
string GetRetcodeDescription(uint retcode) {
    switch(retcode) {
        case TRADE_RETCODE_REQUOTE: return "Requote";
        case TRADE_RETCODE_REJECT: return "Request rejected";
        case TRADE_RETCODE_CANCEL: return "Request canceled";
        case TRADE_RETCODE_PLACED: return "Order placed";
        case TRADE_RETCODE_DONE: return "Request completed";
        case TRADE_RETCODE_DONE_PARTIAL: return "Partial execution";
        case TRADE_RETCODE_ERROR: return "Request error";
        case TRADE_RETCODE_TIMEOUT: return "Request timeout";
        case TRADE_RETCODE_INVALID: return "Invalid request";
        case TRADE_RETCODE_INVALID_VOLUME: return "Invalid volume";
        case TRADE_RETCODE_INVALID_PRICE: return "Invalid price";
        case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops";
        case TRADE_RETCODE_TRADE_DISABLED: return "Trading disabled";
        case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
        case TRADE_RETCODE_NO_MONEY: return "Insufficient funds";
        case TRADE_RETCODE_PRICE_CHANGED: return "Price changed";
        case TRADE_RETCODE_PRICE_OFF: return "No quotes";
        case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid expiration";
        case TRADE_RETCODE_ORDER_CHANGED: return "Order state changed";
        case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too many requests";
        default: return "Unknown error";
    }
}
```

### 10. Initialization

```mql5
//+------------------------------------------------------------------+
//| Global variables                                                  |
//+------------------------------------------------------------------+
string prefix;              // Unique prefix for all objects
double entryPrice;          // Current entry price
double slPrice;             // Current stop loss price
double tpPrice;             // Current take profit price

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    // Set unique prefix for this instance
    prefix = InstanceName + "_";
    
    // Get current price for initial placement
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    // Calculate sensible default distances using ATR
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    
    double atrValue;
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0) {
        atrValue = atrBuffer[0];
    } else {
        // Fallback: use 1% of price
        atrValue = currentPrice * 0.01;
    }
    IndicatorRelease(atrHandle);
    
    // Initialize prices (default to LONG setup)
    entryPrice = NormalizeDouble(currentPrice, digits);
    slPrice = NormalizeDouble(currentPrice - atrValue, digits);
    tpPrice = NormalizeDouble(currentPrice + (atrValue * DefaultRRRatio), digits);
    
    // Create all visual objects
    CreateEntryLine();
    CreateSLLine();
    CreateTPLine();
    CreateRiskZone();
    CreateRewardZone();
    CreatePriceLabels();
    CreatePanel();
    
    // Initial calculations
    RecalculateAll();
    UpdatePanel();
    
    ChartRedraw();
    
    Print("RiskRewardTool EA initialized: ", InstanceName, " on ", _Symbol);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Clean up all objects with our prefix
    ObjectsDeleteAll(0, prefix);
    ChartRedraw();
    Print("RiskRewardTool EA removed: ", InstanceName);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Optional: Update panel with live P&L if position is open
    // For now, minimal processing - all logic is event-driven
}
```

### 11. Object Creation Functions

```mql5
//+------------------------------------------------------------------+
//| Create entry line                                                 |
//+------------------------------------------------------------------+
void CreateEntryLine() {
    string name = prefix + "EntryLine";
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, entryPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, EntryColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
    ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, "Entry Price - Drag to adjust");
}

//+------------------------------------------------------------------+
//| Create stop loss line                                             |
//+------------------------------------------------------------------+
void CreateSLLine() {
    string name = prefix + "SLLine";
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, slPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, StopLossColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
    ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, "Stop Loss - Drag to adjust");
}

//+------------------------------------------------------------------+
//| Create take profit line                                           |
//+------------------------------------------------------------------+
void CreateTPLine() {
    string name = prefix + "TPLine";
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, tpPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, TakeProfitColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
    ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, "Take Profit - Drag to adjust");
}

//+------------------------------------------------------------------+
//| Create risk zone rectangle                                        |
//+------------------------------------------------------------------+
void CreateRiskZone() {
    string name = prefix + "RiskZone";
    datetime timeLeft = iTime(_Symbol, PERIOD_CURRENT, 50);
    datetime timeRight = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 20;
    
    ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, entryPrice, timeRight, slPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, RiskZoneColor);
    ObjectSetInteger(0, name, OBJPROP_FILL, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create reward zone rectangle                                      |
//+------------------------------------------------------------------+
void CreateRewardZone() {
    string name = prefix + "RewardZone";
    datetime timeLeft = iTime(_Symbol, PERIOD_CURRENT, 50);
    datetime timeRight = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 20;
    
    ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, entryPrice, timeRight, tpPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, RewardZoneColor);
    ObjectSetInteger(0, name, OBJPROP_FILL, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create panel background and elements                              |
//+------------------------------------------------------------------+
void CreatePanel() {
    int panelWidth = 220;
    int panelHeight = 320;
    
    // Panel background
    string bgName = prefix + "PanelBg";
    ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, PanelX);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, PanelY);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, PanelBgColor);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, PanelBorderColor);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
    ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
    
    // Create labels (will be updated in UpdatePanel)
    CreatePanelLabel("Title", 10, 10, InstanceName + " Risk/Reward", clrGold, FontSize + 1);
    CreatePanelLabel("Direction", 10, 35, "Direction:", TextColor, FontSize);
    CreatePanelLabel("DirectionVal", 110, 35, "LONG", clrLimeGreen, FontSize);
    CreatePanelLabel("Entry", 10, 55, "Entry:", TextColor, FontSize);
    CreatePanelLabel("EntryVal", 110, 55, "0.00000", TextColor, FontSize);
    CreatePanelLabel("SL", 10, 75, "Stop Loss:", TextColor, FontSize);
    CreatePanelLabel("SLVal", 110, 75, "0.00000", StopLossColor, FontSize);
    CreatePanelLabel("TP", 10, 95, "Take Profit:", TextColor, FontSize);
    CreatePanelLabel("TPVal", 110, 95, "0.00000", TakeProfitColor, FontSize);
    
    CreatePanelLabel("Sep1", 10, 115, "─────────────────────", clrGray, FontSize);
    
    CreatePanelLabel("Risk", 10, 135, "Risk:", TextColor, FontSize);
    CreatePanelLabel("RiskVal", 110, 135, "$0.00", StopLossColor, FontSize);
    CreatePanelLabel("Reward", 10, 155, "Reward:", TextColor, FontSize);
    CreatePanelLabel("RewardVal", 110, 155, "$0.00", TakeProfitColor, FontSize);
    CreatePanelLabel("RRRatio", 10, 175, "R:R Ratio:", TextColor, FontSize);
    CreatePanelLabel("RRRatioVal", 110, 175, "1:0.0", TextColor, FontSize);
    
    CreatePanelLabel("Sep2", 10, 195, "─────────────────────", clrGray, FontSize);
    
    CreatePanelLabel("Lots", 10, 215, "Lot Size:", TextColor, FontSize);
    CreatePanelLabel("LotsVal", 110, 215, "0.00", clrGold, FontSize);
    CreatePanelLabel("RiskMode", 10, 235, "Mode:", TextColor, FontSize);
    CreatePanelLabel("RiskModeVal", 70, 235, "1% Balance", TextColor, FontSize - 1);
    
    // Execute button - prominent
    string execBtnName = prefix + "BtnExecute";
    ObjectCreate(0, execBtnName, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, execBtnName, OBJPROP_XDISTANCE, PanelX + 10);
    ObjectSetInteger(0, execBtnName, OBJPROP_YDISTANCE, PanelY + 260);
    ObjectSetInteger(0, execBtnName, OBJPROP_XSIZE, panelWidth - 20);
    ObjectSetInteger(0, execBtnName, OBJPROP_YSIZE, 30);
    ObjectSetInteger(0, execBtnName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, execBtnName, OBJPROP_BGCOLOR, clrDarkGreen);
    ObjectSetInteger(0, execBtnName, OBJPROP_BORDER_COLOR, clrLimeGreen);
    ObjectSetInteger(0, execBtnName, OBJPROP_COLOR, clrWhite);
    ObjectSetString(0, execBtnName, OBJPROP_TEXT, "EXECUTE ORDER");
    ObjectSetInteger(0, execBtnName, OBJPROP_FONTSIZE, FontSize + 1);
    ObjectSetString(0, execBtnName, OBJPROP_FONT, "Arial Bold");
    
    // Reset button
    string resetBtnName = prefix + "BtnReset";
    ObjectCreate(0, resetBtnName, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, resetBtnName, OBJPROP_XDISTANCE, PanelX + 10);
    ObjectSetInteger(0, resetBtnName, OBJPROP_YDISTANCE, PanelY + 295);
    ObjectSetInteger(0, resetBtnName, OBJPROP_XSIZE, 95);
    ObjectSetInteger(0, resetBtnName, OBJPROP_YSIZE, 20);
    ObjectSetInteger(0, resetBtnName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, resetBtnName, OBJPROP_BGCOLOR, clrDimGray);
    ObjectSetInteger(0, resetBtnName, OBJPROP_COLOR, clrWhite);
    ObjectSetString(0, resetBtnName, OBJPROP_TEXT, "RESET");
    ObjectSetInteger(0, resetBtnName, OBJPROP_FONTSIZE, FontSize);
    
    // Remove button
    string removeBtnName = prefix + "BtnRemove";
    ObjectCreate(0, removeBtnName, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, removeBtnName, OBJPROP_XDISTANCE, PanelX + 115);
    ObjectSetInteger(0, removeBtnName, OBJPROP_YDISTANCE, PanelY + 295);
    ObjectSetInteger(0, removeBtnName, OBJPROP_XSIZE, 95);
    ObjectSetInteger(0, removeBtnName, OBJPROP_YSIZE, 20);
    ObjectSetInteger(0, removeBtnName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, removeBtnName, OBJPROP_BGCOLOR, clrDarkRed);
    ObjectSetInteger(0, removeBtnName, OBJPROP_COLOR, clrWhite);
    ObjectSetString(0, removeBtnName, OBJPROP_TEXT, "REMOVE");
    ObjectSetInteger(0, removeBtnName, OBJPROP_FONTSIZE, FontSize);
}

//+------------------------------------------------------------------+
//| Helper: Create panel label                                        |
//+------------------------------------------------------------------+
void CreatePanelLabel(string id, int x, int y, string text, color clr, int size) {
    string name = prefix + "Lbl" + id;
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelX + x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, PanelY + y);
    ObjectSetInteger(0, name, OBJPROP_CORNER, PanelCorner);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create price labels next to lines                                 |
//+------------------------------------------------------------------+
void CreatePriceLabels() {
    // Implementation for price labels on chart near each line
    // These show the price and pip distance
}
```

### 12. Update and Calculation Functions

```mql5
//+------------------------------------------------------------------+
//| Update prices from line positions                                 |
//+------------------------------------------------------------------+
void UpdatePricesFromLines() {
    entryPrice = ObjectGetDouble(0, prefix + "EntryLine", OBJPROP_PRICE);
    slPrice = ObjectGetDouble(0, prefix + "SLLine", OBJPROP_PRICE);
    tpPrice = ObjectGetDouble(0, prefix + "TPLine", OBJPROP_PRICE);
}

//+------------------------------------------------------------------+
//| Recalculate all values                                            |
//+------------------------------------------------------------------+
void RecalculateAll() {
    // All calculations done in UpdatePanel and helper functions
}

//+------------------------------------------------------------------+
//| Redraw zone rectangles                                            |
//+------------------------------------------------------------------+
void RedrawZones() {
    datetime timeLeft = iTime(_Symbol, PERIOD_CURRENT, 50);
    datetime timeRight = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 20;
    
    // Risk zone (entry to SL)
    ObjectMove(0, prefix + "RiskZone", 0, timeLeft, entryPrice);
    ObjectMove(0, prefix + "RiskZone", 1, timeRight, slPrice);
    
    // Reward zone (entry to TP)
    ObjectMove(0, prefix + "RewardZone", 0, timeLeft, entryPrice);
    ObjectMove(0, prefix + "RewardZone", 1, timeRight, tpPrice);
}

//+------------------------------------------------------------------+
//| Redraw price labels                                               |
//+------------------------------------------------------------------+
void RedrawLabels() {
    // Update the on-chart price labels
}

//+------------------------------------------------------------------+
//| Update panel with current values                                  |
//+------------------------------------------------------------------+
void UpdatePanel() {
    bool isLong = IsLongPosition();
    double lots = CalculateLotSize();
    double riskAmt = GetRiskAmount();
    double rewardAmt = CalculateRewardAmount();
    double rrRatio = CalculateRRRatio();
    double slPips = GetPipsDistance(entryPrice, slPrice);
    double tpPips = GetPipsDistance(entryPrice, tpPrice);
    
    // Direction
    ObjectSetString(0, prefix + "LblDirectionVal", OBJPROP_TEXT, isLong ? "▲ LONG" : "▼ SHORT");
    ObjectSetInteger(0, prefix + "LblDirectionVal", OBJPROP_COLOR, isLong ? clrLimeGreen : clrCrimson);
    
    // Prices
    ObjectSetString(0, prefix + "LblEntryVal", OBJPROP_TEXT, DoubleToString(entryPrice, _Digits));
    ObjectSetString(0, prefix + "LblSLVal", OBJPROP_TEXT, 
                    DoubleToString(slPrice, _Digits) + " (" + DoubleToString(slPips, 1) + "p)");
    ObjectSetString(0, prefix + "LblTPVal", OBJPROP_TEXT, 
                    DoubleToString(tpPrice, _Digits) + " (" + DoubleToString(tpPips, 1) + "p)");
    
    // Risk/Reward
    ObjectSetString(0, prefix + "LblRiskVal", OBJPROP_TEXT, "$" + DoubleToString(riskAmt, 2));
    ObjectSetString(0, prefix + "LblRewardVal", OBJPROP_TEXT, "$" + DoubleToString(rewardAmt, 2));
    ObjectSetString(0, prefix + "LblRRRatioVal", OBJPROP_TEXT, "1 : " + DoubleToString(rrRatio, 1));
    
    // Lot size
    ObjectSetString(0, prefix + "LblLotsVal", OBJPROP_TEXT, DoubleToString(lots, 2));
    
    // Risk mode description
    string modeStr = "";
    switch(RiskMode) {
        case RISK_FIXED_CASH_BALANCE: modeStr = "$" + DoubleToString(RiskValue, 0) + " Fixed"; break;
        case RISK_FIXED_CASH_EQUITY: modeStr = "$" + DoubleToString(RiskValue, 0) + " Fixed"; break;
        case RISK_PERCENT_BALANCE: modeStr = DoubleToString(RiskValue, 1) + "% Balance"; break;
        case RISK_PERCENT_EQUITY: modeStr = DoubleToString(RiskValue, 1) + "% Equity"; break;
    }
    ObjectSetString(0, prefix + "LblRiskModeVal", OBJPROP_TEXT, modeStr);
    
    // Update execute button color based on direction
    ObjectSetInteger(0, prefix + "BtnExecute", OBJPROP_BGCOLOR, isLong ? clrDarkGreen : clrDarkRed);
    ObjectSetInteger(0, prefix + "BtnExecute", OBJPROP_BORDER_COLOR, isLong ? clrLimeGreen : clrCrimson);
}

//+------------------------------------------------------------------+
//| Check if position is long                                         |
//+------------------------------------------------------------------+
bool IsLongPosition() {
    return (tpPrice > entryPrice);
}

//+------------------------------------------------------------------+
//| Calculate reward amount in dollars                                |
//+------------------------------------------------------------------+
double CalculateRewardAmount() {
    double lots = CalculateLotSize();
    double tpDistance = MathAbs(tpPrice - entryPrice);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize == 0) return 0;
    
    return (tpDistance / tickSize) * tickValue * lots;
}

//+------------------------------------------------------------------+
//| Calculate Risk:Reward ratio                                       |
//+------------------------------------------------------------------+
double CalculateRRRatio() {
    double slDistance = MathAbs(entryPrice - slPrice);
    double tpDistance = MathAbs(tpPrice - entryPrice);
    
    if(slDistance == 0) return 0;
    
    return tpDistance / slDistance;
}

//+------------------------------------------------------------------+
//| Get distance in pips                                              |
//+------------------------------------------------------------------+
double GetPipsDistance(double price1, double price2) {
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    // Pip size: for 5-digit forex (EURUSD) pip = point * 10
    // For 2/3 digit (JPY pairs, gold), pip = point
    double pipSize = (digits == 3 || digits == 5) ? point * 10 : point;
    
    return MathAbs(price1 - price2) / pipSize;
}

//+------------------------------------------------------------------+
//| Reset lines to default positions                                  |
//+------------------------------------------------------------------+
void ResetLinesToDefault() {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    
    double atrValue;
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0) {
        atrValue = atrBuffer[0];
    } else {
        atrValue = currentPrice * 0.01;
    }
    IndicatorRelease(atrHandle);
    
    entryPrice = NormalizeDouble(currentPrice, digits);
    slPrice = NormalizeDouble(currentPrice - atrValue, digits);
    tpPrice = NormalizeDouble(currentPrice + (atrValue * DefaultRRRatio), digits);
    
    ObjectSetDouble(0, prefix + "EntryLine", OBJPROP_PRICE, entryPrice);
    ObjectSetDouble(0, prefix + "SLLine", OBJPROP_PRICE, slPrice);
    ObjectSetDouble(0, prefix + "TPLine", OBJPROP_PRICE, tpPrice);
    
    RedrawZones();
    RedrawLabels();
    UpdatePanel();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Clean up all objects                                              |
//+------------------------------------------------------------------+
void CleanupObjects() {
    ObjectsDeleteAll(0, prefix);
    ChartRedraw();
}
```

### 13. Edge Cases to Handle

1. **SL dragged past Entry** — Prevent or auto-swap direction
2. **TP dragged past Entry** — Auto-swap direction, update colors
3. **Lot size below minimum** — Show warning, use minimum lot
4. **Lot size above maximum** — Cap at maximum with warning
5. **Insufficient margin** — Check before execution, warn user
6. **Symbol with unusual lot steps** — Handle XAUUSD, indices, crypto properly
7. **Weekend/market closed** — Disable market orders, allow pending only
8. **Invalid stops (too close to price)** — Check SYMBOL_TRADE_STOPS_LEVEL

### 14. File Structure

Create a single file: `RiskRewardTool.mq5`

Organize code in this order:
1. File header with description and copyright
2. `#property` declarations (version, description, icon, etc.)
3. Enums
4. Input parameters (grouped with `input group`)
5. Global variables
6. `OnInit()`
7. `OnDeinit()`
8. `OnTick()`
9. `OnChartEvent()`
10. Order execution functions
11. Object creation functions
12. Calculation functions
13. Update/redraw functions
14. Helper/utility functions

### 15. Important Implementation Notes

1. **Broker Compatibility**: Always detect filling mode dynamically using `GetFillingMode()` function

2. **Symbol Digits**: Handle both 4/5 digit forex and 2/3 digit (JPY, gold) properly

3. **Error Handling**: Always check return values from `ObjectCreate()`, `OrderSend()`, etc.

4. **Performance**: Only call `ChartRedraw()` after batch updates, not inside loops

5. **Multiple Instances**: The `prefix` variable ensures all object names are unique per instance

6. **Thread Safety**: All trading operations happen in response to user clicks, not in OnTick()

## Quality Requirements

1. **Compiles without warnings** in MetaEditor
2. **Clean, readable code** with consistent formatting
3. **Meaningful comments** for complex logic
4. **Proper error handling** throughout
5. **Works on any symbol** (forex, indices, commodities, crypto)
6. **Works with any broker** (different lot steps, filling modes)

## Deliverable

Generate the complete, compilable `RiskRewardTool.mq5` file that I can paste directly into MetaEditor. The EA should be fully functional with one-click order execution on first compile.

After the initial version, I will compile, test on a demo account, and provide feedback for iterations.
