//+------------------------------------------------------------------+
//|                                               RiskRewardTool.mq5 |
//|                                    TradingView-style R:R Tool    |
//|                        Visual trade planning with one-click exec |
//+------------------------------------------------------------------+
#property copyright "Abhi"
#property link ""
#property version "1.00"
#property description "Risk/Reward Trading Tool - TradingView Style"
#property description "Drag entry, SL, TP lines to plan trades"
#property description "One-click order execution with auto lot sizing"

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_RISK_MODE
{
    RISK_FIXED_CASH_BALANCE, // Fixed $ from Balance
    RISK_FIXED_CASH_EQUITY,  // Fixed $ from Equity
    RISK_PERCENT_BALANCE,    // % of Balance
    RISK_PERCENT_EQUITY      // % of Equity
};

enum ENUM_CLICK_MODE
{
    CLICK_MODE_NONE,  // None (drag lines manually)
    CLICK_MODE_ENTRY, // Click to set Entry
    CLICK_MODE_SL,    // Click to set Stop Loss
    CLICK_MODE_TP     // Click to set Take Profit
};

enum ENUM_PRICE_DISPLAY_MODE
{
    DISPLAY_ABSOLUTE_PRICE, // Show absolute prices
    DISPLAY_PIPS_DISTANCE   // Show pips from entry
};

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+

// === Risk Settings ===
input group "Risk Settings" input ENUM_RISK_MODE RiskMode = RISK_PERCENT_BALANCE; // Risk Mode
input double RiskValue = 1.0;                                                     // Risk Value ($ or %)
input double DefaultRRRatio = 2.0;                                                // Default Risk:Reward Ratio

// === Order Settings ===
input group "Order Settings"
input bool ShowConfirmation = true;   // Show Confirmation Dialog
input int Slippage = 10;              // Slippage (points)
input string InstanceName = "RR1";    // Instance Name (for multiple charts)

// === Visual Settings ===
input group "Visual Settings" input color EntryColor = clrDodgerBlue; // Entry Line Color
input color StopLossColor = clrCrimson;                               // Stop Loss Line Color
input color TakeProfitColor = clrLimeGreen;                           // Take Profit Line Color
input color RiskZoneColor = clrCrimson;                               // Risk Zone Color
input color RewardZoneColor = clrLimeGreen;                           // Reward Zone Color
input int ZoneOpacity = 10;                                           // Zone Opacity (0-100%)
input int LineWidth = 1;                                              // Line Width
input ENUM_LINE_STYLE LineStyle = STYLE_DASHDOT;                      // Line Style
input int FontSize = 9;                                               // Font Size
input color TextColor = clrWhite;                                     // Text Color
input color PanelBgColor = C'40,40,40';                                // Panel Background Color
input color PanelBorderColor = clrGray;                               // Panel Border Color

// === Panel Settings ===
input group "Panel Settings" input ENUM_BASE_CORNER PanelCorner = CORNER_LEFT_UPPER; // Panel Corner
input int PanelX = 20;                                                               // Panel X Offset
input int PanelY = 50;                                                               // Panel Y Offset

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
string prefix;     // Unique prefix for all objects
double entryPrice; // Current entry price
double slPrice;    // Current stop loss price
double tpPrice;    // Current take profit price

// Click mode for placing lines
ENUM_CLICK_MODE clickMode = CLICK_MODE_NONE;

// Price display mode
ENUM_PRICE_DISPLAY_MODE priceDisplayMode = DISPLAY_ABSOLUTE_PRICE;

// Panel state
bool panelMinimized = false;

// Panel dragging state
bool panelDragging = false;
int panelDragOffsetX = 0;
int panelDragOffsetY = 0;
int currentPanelX;
int currentPanelY;

// Dynamic risk value (can be adjusted from panel)
double currentRiskValue;

// Dynamic R:R ratio (can be adjusted from panel)
double currentRRRatio;

// Panel dimensions
int panelWidth = 250;
int panelHeight = 440;
int panelHeightMinimized = 30;

// Double-click detection for panel title (milliseconds)
uint lastTitleClickTime = 0;

// Price increment for +/- buttons (will be calculated based on symbol)
double priceIncrement;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set unique prefix for this instance
    prefix = InstanceName + "_";

    // Restore minimized state from GlobalVariable (persists across timeframe changes)
    string gvMinimized = prefix + "Minimized";
    if (GlobalVariableCheck(gvMinimized))
        panelMinimized = (GlobalVariableGet(gvMinimized) == 1.0);
    else
        panelMinimized = false;

    // Restore panel position from GlobalVariables (persists across timeframe changes)
    string gvPanelX = prefix + "PanelX";
    string gvPanelY = prefix + "PanelY";
    if (GlobalVariableCheck(gvPanelX) && GlobalVariableCheck(gvPanelY))
    {
        currentPanelX = (int)GlobalVariableGet(gvPanelX);
        currentPanelY = (int)GlobalVariableGet(gvPanelY);
    }
    else
    {
        currentPanelX = PanelX;
        currentPanelY = PanelY;
    }

    // Restore risk value from GlobalVariable or use default
    string gvRiskValue = prefix + "RiskValue";
    if (GlobalVariableCheck(gvRiskValue))
        currentRiskValue = GlobalVariableGet(gvRiskValue);
    else
        currentRiskValue = RiskValue;

    // Restore R:R ratio from GlobalVariable or use default
    string gvRRRatio = prefix + "RRRatio";
    if (GlobalVariableCheck(gvRRRatio))
        currentRRRatio = GlobalVariableGet(gvRRRatio);
    else
        currentRRRatio = DefaultRRRatio;

    // Get current price for initial placement
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    // Calculate price increment for +/- buttons (1 pip for forex, 1 point for others)
    priceIncrement = (digits == 3 || digits == 5) ? point * 10 : point;

    // Calculate sensible default distances using ATR
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    double atrValue;
    if (CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
    {
        atrValue = atrBuffer[0];
    }
    else
    {
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

    // Initial calculations and update
    RedrawZones();
    RedrawLabels();
    UpdatePanel();

    // Restore direction from GlobalVariable (default setup is LONG, flip if persisted direction was SHORT)
    string gvIsLong = prefix + "IsLong";
    if (GlobalVariableCheck(gvIsLong) && GlobalVariableGet(gvIsLong) == 0.0)
    {
        // Persisted direction was SHORT, flip from default LONG to SHORT
        FlipDirection();
    }

    // Enable chart event tracking for mouse moves (needed for panel dragging)
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

    // Apply minimized state if panel was minimized (hide lines and resize panel)
    if (panelMinimized)
    {
        ApplyMinimizedState();
    }

    ChartRedraw();

    Print("RiskRewardTool EA initialized: ", InstanceName, " on ", _Symbol);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up all objects with our prefix
    ObjectsDeleteAll(0, prefix);

    // Only delete GlobalVariables when EA is explicitly removed (not on timeframe change)
    if (reason == REASON_REMOVE)
    {
        GlobalVariableDel(prefix + "Minimized");
        GlobalVariableDel(prefix + "PanelX");
        GlobalVariableDel(prefix + "PanelY");
        GlobalVariableDel(prefix + "IsLong");
        GlobalVariableDel(prefix + "RiskValue");
        GlobalVariableDel(prefix + "RRRatio");
    }

    ChartRedraw();
    Print("RiskRewardTool EA removed: ", InstanceName);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Minimal processing - all logic is event-driven
    // Could add live P&L tracking here if desired
}

//+------------------------------------------------------------------+
//| ChartEvent handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // === Handle Chart Scale/Scroll Changes - Update label positions ===
    if (id == CHARTEVENT_CHART_CHANGE)
    {
        RedrawLabels();
        ChartRedraw();
        return;
    }

    // === Handle Mouse Move for Panel Dragging (press-and-hold style) ===
    if (id == CHARTEVENT_MOUSE_MOVE)
    {
        int mouseX = (int)lparam;
        int mouseY = (int)dparam;
        uint mouseState = (uint)sparam; // Mouse button state

        // Check if left mouse button is pressed (bit 0)
        bool leftButtonPressed = (mouseState & 1) == 1;

        if (panelDragging)
        {
            if (leftButtonPressed)
            {
                // Continue dragging - update panel position
                currentPanelX = mouseX - panelDragOffsetX;
                currentPanelY = mouseY - panelDragOffsetY;

                // Ensure panel stays within chart bounds
                int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
                int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

                currentPanelX = MathMax(0, MathMin(currentPanelX, chartWidth - panelWidth));
                currentPanelY = MathMax(0, MathMin(currentPanelY, chartHeight - (panelMinimized ? panelHeightMinimized : panelHeight)));

                // Update all panel objects positions
                UpdatePanelPosition();
                ChartRedraw();
            }
            else
            {
                // Left button released - stop dragging
                panelDragging = false;
                ChartSetInteger(0, CHART_MOUSE_SCROLL, true); // Re-enable chart scrolling

                // Save panel position to GlobalVariables (persists across timeframe changes)
                GlobalVariableSet(prefix + "PanelX", (double)currentPanelX);
                GlobalVariableSet(prefix + "PanelY", (double)currentPanelY);
            }
        }
        else
        {
            // Not currently dragging - check if we should start
            if (leftButtonPressed && IsClickOnPanelHeader(mouseX, mouseY))
            {
                panelDragging = true;
                panelDragOffsetX = mouseX - currentPanelX;
                panelDragOffsetY = mouseY - currentPanelY;
                ChartSetInteger(0, CHART_MOUSE_SCROLL, false); // Disable chart scrolling while dragging
            }
        }
    }

    // === Handle Line Dragging ===
    if (id == CHARTEVENT_OBJECT_DRAG)
    {
        if (StringFind(sparam, prefix) == 0)
        {
            if (sparam == prefix + "EntryLine" ||
                sparam == prefix + "SLLine" ||
                sparam == prefix + "TPLine")
            {
                UpdatePricesFromLines();
                UpdateRRRatioFromLines(); // Update R:R ratio based on new line positions
                RedrawZones();
                RedrawLabels();
                UpdatePanel();
                ChartRedraw();
            }
        }
    }

    // === Handle Edit Field Changes ===
    if (id == CHARTEVENT_OBJECT_ENDEDIT)
    {
        if (sparam == prefix + "EditEntry")
        {
            string text = ObjectGetString(0, sparam, OBJPROP_TEXT);
            double newPrice = StringToDouble(text);
            if (newPrice > 0)
            {
                entryPrice = NormalizeDouble(newPrice, _Digits);
                ObjectSetDouble(0, prefix + "EntryLine", OBJPROP_PRICE, entryPrice);
                UpdateRRRatioFromLines();
                RedrawZones();
                RedrawLabels();
                UpdatePanel();
                ChartRedraw();
            }
            else
            {
                // Restore the previous value if invalid
                ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(entryPrice, _Digits));
            }
            return;
        }
        if (sparam == prefix + "EditSL")
        {
            string text = ObjectGetString(0, sparam, OBJPROP_TEXT);
            double newValue = StringToDouble(text);
            if (newValue > 0)
            {
                if (priceDisplayMode == DISPLAY_ABSOLUTE_PRICE)
                {
                    // Direct price input
                    slPrice = NormalizeDouble(newValue, _Digits);
                }
                else
                {
                    // Pips input - convert to price
                    double pipSize = GetPipSize();
                    double priceDistance = newValue * pipSize;
                    // SL is on opposite side of entry from TP
                    if (IsLongPosition())
                        slPrice = NormalizeDouble(entryPrice - priceDistance, _Digits);
                    else
                        slPrice = NormalizeDouble(entryPrice + priceDistance, _Digits);
                }
                ObjectSetDouble(0, prefix + "SLLine", OBJPROP_PRICE, slPrice);
                UpdateRRRatioFromLines();
                RedrawZones();
                RedrawLabels();
                UpdatePanel();
                ChartRedraw();
            }
            else
            {
                // Restore the previous value
                if (priceDisplayMode == DISPLAY_ABSOLUTE_PRICE)
                    ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(slPrice, _Digits));
                else
                    ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(GetPipsDistance(entryPrice, slPrice), 1));
            }
            return;
        }
        if (sparam == prefix + "EditTP")
        {
            string text = ObjectGetString(0, sparam, OBJPROP_TEXT);
            double newValue = StringToDouble(text);
            if (newValue > 0)
            {
                if (priceDisplayMode == DISPLAY_ABSOLUTE_PRICE)
                {
                    // Direct price input
                    tpPrice = NormalizeDouble(newValue, _Digits);
                }
                else
                {
                    // Pips input - convert to price
                    double pipSize = GetPipSize();
                    double priceDistance = newValue * pipSize;
                    // TP is on same side as direction
                    if (IsLongPosition())
                        tpPrice = NormalizeDouble(entryPrice + priceDistance, _Digits);
                    else
                        tpPrice = NormalizeDouble(entryPrice - priceDistance, _Digits);
                }
                ObjectSetDouble(0, prefix + "TPLine", OBJPROP_PRICE, tpPrice);
                UpdateRRRatioFromLines();
                RedrawZones();
                RedrawLabels();
                UpdatePanel();
                ChartRedraw();
            }
            else
            {
                // Restore the previous value
                if (priceDisplayMode == DISPLAY_ABSOLUTE_PRICE)
                    ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(tpPrice, _Digits));
                else
                    ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(GetPipsDistance(entryPrice, tpPrice), 1));
            }
            return;
        }
        if (sparam == prefix + "EditRisk")
        {
            string text = ObjectGetString(0, sparam, OBJPROP_TEXT);
            // Remove % sign if present
            StringReplace(text, "%", "");
            StringReplace(text, "$", "");
            double newRisk = StringToDouble(text);
            if (newRisk > 0)
            {
                if (RiskMode == RISK_PERCENT_BALANCE || RiskMode == RISK_PERCENT_EQUITY)
                {
                    currentRiskValue = MathMax(0.1, MathMin(100.0, newRisk));
                }
                else
                {
                    currentRiskValue = MathMax(1.0, newRisk);
                }
                // Save to GlobalVariable (persists across timeframe changes)
                GlobalVariableSet(prefix + "RiskValue", currentRiskValue);
                UpdatePanel();
                ChartRedraw();
            }
            else
            {
                // Restore the previous value if invalid
                if (RiskMode == RISK_PERCENT_BALANCE || RiskMode == RISK_PERCENT_EQUITY)
                {
                    ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(currentRiskValue, 1) + "%");
                }
                else
                {
                    ObjectSetString(0, sparam, OBJPROP_TEXT, "$" + DoubleToString(currentRiskValue, 0));
                }
            }
            return;
        }
        if (sparam == prefix + "EditRR")
        {
            string text = ObjectGetString(0, sparam, OBJPROP_TEXT);
            double newRR = StringToDouble(text);
            if (newRR >= 0.1)
            {
                currentRRRatio = MathMax(0.1, newRR);
                // Save to GlobalVariable (persists across timeframe changes)
                GlobalVariableSet(prefix + "RRRatio", currentRRRatio);
                UpdateTPFromRRRatio();
                UpdatePanel();
                ChartRedraw();
            }
            else
            {
                // Restore the previous value if invalid
                ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(currentRRRatio, 1));
            }
            return;
        }
    }

    // === Handle Button Clicks ===
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        // Minimize button
        if (sparam == prefix + "BtnMinimize")
        {
            TogglePanelMinimize();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }

        // Double-click on panel title bar area to toggle minimize
        // Works on title label OR panel background within title bar region (top 25 pixels)
        bool isTitleBarClick = false;

        if (sparam == prefix + "LblTitle")
        {
            isTitleBarClick = true;
        }
        else if (sparam == prefix + "PanelBg")
        {
            // Check if click is within title bar region (top 25 pixels of panel)
            int clickY = (int)dparam;
            if (clickY >= currentPanelY && clickY <= currentPanelY + 25)
            {
                isTitleBarClick = true;
            }
        }

        if (isTitleBarClick)
        {
            uint currentTime = GetTickCount();
            if (currentTime - lastTitleClickTime <= 500) // Within 500ms (double-click)
            {
                TogglePanelMinimize();
                ChartRedraw();
                lastTitleClickTime = 0; // Reset to prevent triple-click
            }
            else
            {
                lastTitleClickTime = currentTime;
            }
            return;
        }

        // === Risk +/- Buttons ===
        if (sparam == prefix + "BtnRiskPlus")
        {
            AdjustRisk(0.1); // Increase by 0.1%
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }
        if (sparam == prefix + "BtnRiskMinus")
        {
            AdjustRisk(-0.1); // Decrease by 0.1%
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }

        // === R:R Ratio +/- Buttons ===
        if (sparam == prefix + "BtnRRPlus")
        {
            AdjustRRRatio(0.1); // Increase by 0.1
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }
        if (sparam == prefix + "BtnRRMinus")
        {
            AdjustRRRatio(-0.1); // Decrease by 0.1
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }

        // === Entry +/- Buttons ===
        if (sparam == prefix + "BtnEntryPlus")
        {
            AdjustPrice(CLICK_MODE_ENTRY, priceIncrement);
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }
        if (sparam == prefix + "BtnEntryMinus")
        {
            AdjustPrice(CLICK_MODE_ENTRY, -priceIncrement);
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }

        // === SL +/- Buttons ===
        if (sparam == prefix + "BtnSLPlus")
        {
            AdjustPrice(CLICK_MODE_SL, priceIncrement);
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }
        if (sparam == prefix + "BtnSLMinus")
        {
            AdjustPrice(CLICK_MODE_SL, -priceIncrement);
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }

        // === TP +/- Buttons ===
        if (sparam == prefix + "BtnTPPlus")
        {
            AdjustPrice(CLICK_MODE_TP, priceIncrement);
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }
        if (sparam == prefix + "BtnTPMinus")
        {
            AdjustPrice(CLICK_MODE_TP, -priceIncrement);
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }

        // === Price/Pips Toggle Button ===
        if (sparam == prefix + "BtnToggleDisplay")
        {
            TogglePriceDisplayMode();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }

        // === Flip Long/Short Button (click on LONG/SHORT to toggle) ===
        if (sparam == prefix + "BtnDirection")
        {
            FlipDirection();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }

        // EXECUTE ORDER - Smart order type (Limit/Stop based on price)
        if (sparam == prefix + "BtnExecute")
        {
            ExecuteOrder();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }

        // MARKET ORDER - Instant execution at current price
        if (sparam == prefix + "BtnMarketOrder")
        {
            ExecuteMarketOrder();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }

        // RESET - Reset lines to default
        if (sparam == prefix + "BtnReset")
        {
            ResetLinesToDefault();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
        }
    }
}

//+------------------------------------------------------------------+
//| Check if click is on panel header for dragging                   |
//+------------------------------------------------------------------+
bool IsClickOnPanelHeader(int x, int y)
{
    // Panel header is the top 25 pixels of the panel
    int headerHeight = 25;

    // First check if click is within header bounds
    if (!(x >= currentPanelX && x <= currentPanelX + panelWidth &&
          y >= currentPanelY && y <= currentPanelY + headerHeight))
        return false;

    // Exclude minimize button area (top-right corner) from header dragging
    // Button is at: panelWidth - 28, 5, with size 22x18
    int btnMinX = currentPanelX + panelWidth - 28;
    int btnMinY = currentPanelY + 5;
    int btnMaxX = btnMinX + 22;
    int btnMaxY = btnMinY + 18;

    if (x >= btnMinX && x <= btnMaxX && y >= btnMinY && y <= btnMaxY)
        return false; // Click is on minimize button, not header

    return true;
}

//+------------------------------------------------------------------+
//| Update all panel object positions after dragging                 |
//+------------------------------------------------------------------+
void UpdatePanelPosition()
{
    // Update panel background position
    ObjectSetInteger(0, prefix + "PanelBg", OBJPROP_XDISTANCE, currentPanelX);
    ObjectSetInteger(0, prefix + "PanelBg", OBJPROP_YDISTANCE, currentPanelY);

    // Update all labels and buttons relative to new panel position
    // We need to iterate through all panel objects and update their positions
    int totalObjects = ObjectsTotal(0);
    for (int i = 0; i < totalObjects; i++)
    {
        string objName = ObjectName(0, i);
        if (StringFind(objName, prefix) == 0 && objName != prefix + "PanelBg")
        {
            // Skip chart objects (lines, zones, labels on chart)
            if (StringFind(objName, "Line") >= 0 || StringFind(objName, "Zone") >= 0 ||
                StringFind(objName, "EntryLabel") >= 0 || StringFind(objName, "SLLabel") >= 0 ||
                StringFind(objName, "TPLabel") >= 0 || StringFind(objName, "LabelBg") >= 0)
                continue;

            // Get the object's current relative position from original panel position
            long objType = ObjectGetInteger(0, objName, OBJPROP_TYPE);
            if (objType == OBJ_LABEL || objType == OBJ_BUTTON || objType == OBJ_RECTANGLE_LABEL)
            {
                // Calculate relative position from stored panel base
                long oldX = ObjectGetInteger(0, objName, OBJPROP_XDISTANCE);
                long oldY = ObjectGetInteger(0, objName, OBJPROP_YDISTANCE);

                // Objects store their absolute position, we need to update based on panel movement
                // This requires recreating the panel with current position
            }
        }
    }

    // Since updating relative positions is complex, recreate the panel at new position
    RecreatePanel();
}

//+------------------------------------------------------------------+
//| Recreate panel at current position                               |
//+------------------------------------------------------------------+
void RecreatePanel()
{
    // Delete existing panel objects (keep lines, zones, and on-chart labels)
    int totalObjects = ObjectsTotal(0);
    for (int i = totalObjects - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if (StringFind(objName, prefix) == 0)
        {
            // Keep lines and zones
            if (StringFind(objName, "Line") >= 0 || StringFind(objName, "Zone") >= 0)
                continue;

            // Keep on-chart price labels (EntryLabel, SLLabel, TPLabel) and their backgrounds
            if (objName == prefix + "EntryLabel" || objName == prefix + "SLLabel" ||
                objName == prefix + "TPLabel" || StringFind(objName, "LabelBg") >= 0)
                continue;

            ObjectDelete(0, objName);
        }
    }

    // Recreate panel at current position
    CreatePanel();
    UpdatePanel();

    // Re-apply minimized state if panel was minimized
    if (panelMinimized)
    {
        ApplyMinimizedState();
    }
}

//+------------------------------------------------------------------+
//| Apply minimized state to panel (hide objects, resize background) |
//+------------------------------------------------------------------+
void ApplyMinimizedState()
{
    // List of panel objects to hide when minimized
    string panelObjectsToHide[] = {
        "LblDirection", "BtnDirection",
        "BtnToggleDisplay",
        "LblEntry", "EditEntry",
        "BtnEntryMinus", "BtnEntryPlus",
        "LblSL", "EditSL",
        "BtnSLMinus", "BtnSLPlus",
        "LblTP", "EditTP",
        "BtnTPMinus", "BtnTPPlus",
        "LblSep1",
        "LblRiskPct", "EditRisk",
        "BtnRiskMinus", "BtnRiskPlus",
        "LblRisk", "LblRiskVal",
        "LblReward", "LblRewardVal",
        "LblRRRatio", "LblRRPrefix", "EditRR",
        "BtnRRMinus", "BtnRRPlus",
        "LblSep2",
        "LblLots", "LblLotsVal",
        "LblRiskMode", "LblRiskModeVal",
        "LblOrderType", "LblOrderTypeVal",
        "BtnMarketOrder",
        "BtnExecute",
        "BtnReset"};

    int numObjects = ArraySize(panelObjectsToHide);

    for (int i = 0; i < numObjects; i++)
    {
        string objName = prefix + panelObjectsToHide[i];
        if (ObjectFind(0, objName) >= 0)
        {
            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
    }

    // Delete chart objects (lines, zones, labels) when minimized
    ObjectDelete(0, prefix + "EntryLine");
    ObjectDelete(0, prefix + "SLLine");
    ObjectDelete(0, prefix + "TPLine");
    ObjectDelete(0, prefix + "RiskZone");
    ObjectDelete(0, prefix + "RewardZone");
    ObjectDelete(0, prefix + "EntryLabel");
    ObjectDelete(0, prefix + "SLLabel");
    ObjectDelete(0, prefix + "TPLabel");

    // Resize panel background to minimized height
    ObjectSetInteger(0, prefix + "PanelBg", OBJPROP_YSIZE, panelHeightMinimized);
    ObjectSetString(0, prefix + "BtnMinimize", OBJPROP_TEXT, "+");
}

//+------------------------------------------------------------------+
//| Adjust risk value                                                |
//+------------------------------------------------------------------+
void AdjustRisk(double adjustment)
{
    currentRiskValue += adjustment;

    // Clamp to valid range
    if (RiskMode == RISK_PERCENT_BALANCE || RiskMode == RISK_PERCENT_EQUITY)
    {
        currentRiskValue = MathMax(0.1, MathMin(100.0, currentRiskValue)); // 0.1% to 100%
    }
    else
    {
        currentRiskValue = MathMax(1.0, currentRiskValue); // Minimum $1 for fixed cash
    }

    // Save to GlobalVariable (persists across timeframe changes)
    GlobalVariableSet(prefix + "RiskValue", currentRiskValue);

    UpdatePanel();
}

//+------------------------------------------------------------------+
//| Adjust R:R ratio value                                           |
//+------------------------------------------------------------------+
void AdjustRRRatio(double adjustment)
{
    currentRRRatio += adjustment;
    currentRRRatio = MathMax(0.1, currentRRRatio); // Minimum 0.1 R:R

    // Save to GlobalVariable (persists across timeframe changes)
    GlobalVariableSet(prefix + "RRRatio", currentRRRatio);

    // Update TP based on new R:R ratio
    UpdateTPFromRRRatio();
    UpdatePanel();
}

//+------------------------------------------------------------------+
//| Update TP price based on current R:R ratio                       |
//+------------------------------------------------------------------+
void UpdateTPFromRRRatio()
{
    // Calculate SL distance
    double slDistance = MathAbs(entryPrice - slPrice);

    // Calculate TP distance based on R:R ratio
    double tpDistance = slDistance * currentRRRatio;

    // Set TP based on direction
    if (IsLongPosition())
    {
        tpPrice = NormalizeDouble(entryPrice + tpDistance, _Digits);
    }
    else
    {
        tpPrice = NormalizeDouble(entryPrice - tpDistance, _Digits);
    }

    // Update the TP line
    ObjectSetDouble(0, prefix + "TPLine", OBJPROP_PRICE, tpPrice);

    // Redraw zones and labels
    RedrawZones();
    RedrawLabels();
}

//+------------------------------------------------------------------+
//| Update R:R ratio from current line positions (when lines dragged)|
//+------------------------------------------------------------------+
void UpdateRRRatioFromLines()
{
    // Calculate SL distance
    double slDistance = MathAbs(entryPrice - slPrice);

    // Calculate TP distance
    double tpDistance = MathAbs(tpPrice - entryPrice);

    // Calculate and update R:R ratio
    if (slDistance > 0)
    {
        currentRRRatio = NormalizeDouble(tpDistance / slDistance, 1);
        currentRRRatio = MathMax(0.1, currentRRRatio); // Minimum 0.1
    }
}

//+------------------------------------------------------------------+
//| Adjust price level                                               |
//+------------------------------------------------------------------+
void AdjustPrice(ENUM_CLICK_MODE priceType, double adjustment)
{
    switch (priceType)
    {
    case CLICK_MODE_ENTRY:
        entryPrice = NormalizeDouble(entryPrice + adjustment, _Digits);
        ObjectSetDouble(0, prefix + "EntryLine", OBJPROP_PRICE, entryPrice);
        break;
    case CLICK_MODE_SL:
        slPrice = NormalizeDouble(slPrice + adjustment, _Digits);
        ObjectSetDouble(0, prefix + "SLLine", OBJPROP_PRICE, slPrice);
        break;
    case CLICK_MODE_TP:
        tpPrice = NormalizeDouble(tpPrice + adjustment, _Digits);
        ObjectSetDouble(0, prefix + "TPLine", OBJPROP_PRICE, tpPrice);
        break;
    }

    UpdateRRRatioFromLines(); // Update R:R ratio based on new prices
    RedrawZones();
    RedrawLabels();
    UpdatePanel();
}

//+------------------------------------------------------------------+
//| Toggle price display mode                                        |
//+------------------------------------------------------------------+
void TogglePriceDisplayMode()
{
    priceDisplayMode = (priceDisplayMode == DISPLAY_ABSOLUTE_PRICE) ? DISPLAY_PIPS_DISTANCE : DISPLAY_ABSOLUTE_PRICE;
    UpdatePanel();

    // Update toggle button text
    string btnText = (priceDisplayMode == DISPLAY_ABSOLUTE_PRICE) ? "PIPS" : "PRICE";
    ObjectSetString(0, prefix + "BtnToggleDisplay", OBJPROP_TEXT, btnText);
}

//+------------------------------------------------------------------+
//| Flip between Long and Short positions                            |
//+------------------------------------------------------------------+
void FlipDirection()
{
    // Calculate distances from entry
    double slDistance = MathAbs(entryPrice - slPrice);
    double tpDistance = MathAbs(tpPrice - entryPrice);

    bool wasLong = IsLongPosition();

    // Save new direction to GlobalVariable (persists across timeframe changes)
    // After flip: wasLong means new direction will be SHORT (0), !wasLong means new direction will be LONG (1)
    GlobalVariableSet(prefix + "IsLong", wasLong ? 0.0 : 1.0);

    if (wasLong)
    {
        // Was Long, flip to Short: SL above entry, TP below entry
        slPrice = NormalizeDouble(entryPrice + slDistance, _Digits);
        tpPrice = NormalizeDouble(entryPrice - tpDistance, _Digits);
    }
    else
    {
        // Was Short, flip to Long: SL below entry, TP above entry
        slPrice = NormalizeDouble(entryPrice - slDistance, _Digits);
        tpPrice = NormalizeDouble(entryPrice + tpDistance, _Digits);
    }

    // Update line positions
    ObjectSetDouble(0, prefix + "SLLine", OBJPROP_PRICE, slPrice);
    ObjectSetDouble(0, prefix + "TPLine", OBJPROP_PRICE, tpPrice);

    UpdateRRRatioFromLines(); // Update R:R ratio (should stay the same, but recalculate to be safe)
    RedrawZones();
    RedrawLabels();
    UpdatePanel();
}

//+------------------------------------------------------------------+
//| Execute order using smart order type detection                   |
//+------------------------------------------------------------------+
void ExecuteOrder()
{
    // Validate lot size
    double lots = CalculateLotSize();
    if (lots <= 0)
    {
        Alert("Invalid lot size. Check risk settings.");
        return;
    }

    // Validate stops distance
    if (!ValidateStopsDistance())
    {
        return;
    }

    // Get prices
    double entry = entryPrice;
    double sl = slPrice;
    double tp = tpPrice;

    // Determine direction and smart order type
    bool isLong = IsLongPosition();
    ENUM_ORDER_TYPE smartOrderType = GetSmartOrderType();
    string orderTypeStr = GetOrderTypeDescription();

    // Confirmation dialog (if enabled)
    if (ShowConfirmation)
    {
        string message = StringFormat(
            "Execute %s?\n\n" +
                "Symbol: %s\n" +
                "Lots: %.2f\n" +
                "Entry: %s\n" +
                "Stop Loss: %s\n" +
                "Take Profit: %s\n\n" +
                "Risk: $%.2f\n" +
                "Reward: $%.2f\n" +
                "R:R: 1:%.1f",
            orderTypeStr, _Symbol, lots,
            DoubleToString(entry, _Digits),
            DoubleToString(sl, _Digits),
            DoubleToString(tp, _Digits),
            GetRiskAmount(),
            CalculateRewardAmount(),
            CalculateRRRatio());

        int result = MessageBox(message, "Confirm Order - " + InstanceName, MB_YESNO | MB_ICONQUESTION);
        if (result != IDYES)
            return;
    }

    // Prepare order request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    ZeroMemory(request);
    ZeroMemory(result);

    request.symbol = _Symbol;
    request.volume = lots;
    request.deviation = Slippage;
    request.magic = GenerateMagicNumber(InstanceName);
    request.comment = InstanceName;
    request.type = smartOrderType;

    // Get symbol info for filling mode and set the correct one
    uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    if ((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
        request.type_filling = ORDER_FILLING_FOK;
    else if ((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
        request.type_filling = ORDER_FILLING_IOC;
    else
        request.type_filling = ORDER_FILLING_RETURN;

    // Set action based on order type
    if (smartOrderType == ORDER_TYPE_BUY || smartOrderType == ORDER_TYPE_SELL)
    {
        // Market order - instant execution
        // Don't set type_time for market orders
        request.action = TRADE_ACTION_DEAL;
        request.price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        request.sl = NormalizeDouble(sl, _Digits);
        request.tp = NormalizeDouble(tp, _Digits);
    }
    else
    {
        // Pending order (LIMIT or STOP)
        request.action = TRADE_ACTION_PENDING;
        request.price = NormalizeDouble(entry, _Digits);
        request.sl = NormalizeDouble(sl, _Digits);
        request.tp = NormalizeDouble(tp, _Digits);
        request.type_time = ORDER_TIME_GTC;
    }

    // Send order
    if (!OrderSend(request, result))
    {
        string errorMsg = StringFormat("Order failed!\nError code: %d\nDescription: %s",
                                       result.retcode, GetRetcodeDescription(result.retcode));
        Alert(errorMsg);
        Print(errorMsg);
    }
    else
    {
        if (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
        {
            string successMsg = StringFormat("Order executed successfully!\nTicket: %d", result.order);
            Alert(successMsg);
            Print(successMsg);
            // Remove drawing objects after successful order
            RemoveDrawingObjects();
        }
        else
        {
            string warningMsg = StringFormat("Order sent with code: %d - %s",
                                             result.retcode, GetRetcodeDescription(result.retcode));
            Alert(warningMsg);
            Print(warningMsg);
        }
    }
}

//+------------------------------------------------------------------+
//| Execute market order at current price                            |
//+------------------------------------------------------------------+
void ExecuteMarketOrder()
{
    // Validate lot size
    double lots = CalculateLotSize();
    if (lots <= 0)
    {
        Alert("Invalid lot size. Check risk settings.");
        return;
    }

    // Get prices
    double sl = slPrice;
    double tp = tpPrice;

    // Determine direction
    bool isLong = IsLongPosition();
    string direction = isLong ? "MARKET BUY" : "MARKET SELL";

    // Confirmation dialog (if enabled)
    if (ShowConfirmation)
    {
        double currentPrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

        string message = StringFormat(
            "Execute %s at current price?\n\n" +
                "Symbol: %s\n" +
                "Lots: %.2f\n" +
                "Current Price: %s\n" +
                "Stop Loss: %s\n" +
                "Take Profit: %s\n\n" +
                "Risk: $%.2f\n" +
                "Reward: $%.2f\n" +
                "R:R: 1:%.1f",
            direction, _Symbol, lots,
            DoubleToString(currentPrice, _Digits),
            DoubleToString(sl, _Digits),
            DoubleToString(tp, _Digits),
            GetRiskAmount(),
            CalculateRewardAmount(),
            CalculateRRRatio());

        int result = MessageBox(message, "Confirm Market Order - " + InstanceName, MB_YESNO | MB_ICONQUESTION);
        if (result != IDYES)
            return;
    }

    // Prepare order request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    ZeroMemory(request);
    ZeroMemory(result);

    // Build request for market order
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lots;
    request.deviation = Slippage;
    request.magic = GenerateMagicNumber(InstanceName);
    request.comment = InstanceName;

    // For TRADE_ACTION_DEAL (market orders), do NOT set type_time
    // Market orders execute immediately, expiration doesn't apply
    // Setting type_time can cause error 10027 on some brokers

    // Get symbol info for filling mode and set the correct one
    uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    if ((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
        request.type_filling = ORDER_FILLING_FOK;
    else if ((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
        request.type_filling = ORDER_FILLING_IOC;
    else
        request.type_filling = ORDER_FILLING_RETURN;

    if (isLong)
    {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    }
    else
    {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    }

    // Send order
    if (!OrderSend(request, result))
    {
        string errorMsg = StringFormat("Market order failed!\nError code: %d\nDescription: %s",
                                       result.retcode, GetRetcodeDescription(result.retcode));
        Alert(errorMsg);
        Print(errorMsg);
    }
    else
    {
        if (result.retcode == TRADE_RETCODE_DONE)
        {
            ulong positionTicket = result.order;
            string successMsg = StringFormat("Market order executed! Ticket: %d", positionTicket);
            Print(successMsg);

            // Step 2: Modify position to add SL/TP
            Sleep(200); // Wait for position to register

            MqlTradeRequest modifyRequest = {};
            MqlTradeResult modifyResult = {};
            ZeroMemory(modifyRequest);
            ZeroMemory(modifyResult);

            modifyRequest.action = TRADE_ACTION_SLTP;
            modifyRequest.symbol = _Symbol;
            modifyRequest.position = positionTicket;
            modifyRequest.sl = NormalizeDouble(sl, _Digits);
            modifyRequest.tp = NormalizeDouble(tp, _Digits);

            if (!OrderSend(modifyRequest, modifyResult) || modifyResult.retcode != TRADE_RETCODE_DONE)
            {
                string warnMsg = StringFormat("Order placed but failed to set SL/TP!\nTicket: %d\nError: %d - %s",
                                              positionTicket, modifyResult.retcode, GetRetcodeDescription(modifyResult.retcode));
                Alert(warnMsg);
                Print(warnMsg);
            }
            else
            {
                Alert(successMsg + "\nSL/TP set successfully!");
            }

            // Remove drawing objects after successful order
            RemoveDrawingObjects();
        }
        else
        {
            string warningMsg = StringFormat("Order sent with code: %d - %s",
                                             result.retcode, GetRetcodeDescription(result.retcode));
            Alert(warningMsg);
            Print(warningMsg);
        }
    }
}

//+------------------------------------------------------------------+
//| Validate stops distance meets broker requirements                |
//+------------------------------------------------------------------+
bool ValidateStopsDistance()
{
    long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double minDistance = stopsLevel * point;

    double currentPrice = IsLongPosition() ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // For market orders, check against current price
    // For pending orders, check against entry price
    ENUM_ORDER_TYPE smartOrderType = GetSmartOrderType();
    bool isMarketOrder = (smartOrderType == ORDER_TYPE_BUY || smartOrderType == ORDER_TYPE_SELL);
    double referencePrice = isMarketOrder ? currentPrice : entryPrice;

    double slDistance = MathAbs(referencePrice - slPrice);
    double tpDistance = MathAbs(referencePrice - tpPrice);

    if (slDistance < minDistance)
    {
        Alert(StringFormat("Stop Loss too close! Minimum distance: %.5f (%.1f points)",
                           minDistance, (double)stopsLevel));
        return false;
    }

    if (tpDistance < minDistance)
    {
        Alert(StringFormat("Take Profit too close! Minimum distance: %.5f (%.1f points)",
                           minDistance, (double)stopsLevel));
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Generate magic number from instance name                         |
//+------------------------------------------------------------------+
ulong GenerateMagicNumber(string name)
{
    ulong hash = 0;
    for (int i = 0; i < StringLen(name); i++)
    {
        hash = hash * 31 + StringGetCharacter(name, i);
    }
    return hash % 2147483647; // Keep within int range
}

//+------------------------------------------------------------------+
//| Get retcode description                                          |
//+------------------------------------------------------------------+
string GetRetcodeDescription(uint retcode)
{
    switch (retcode)
    {
    case TRADE_RETCODE_REQUOTE:
        return "Requote";
    case TRADE_RETCODE_REJECT:
        return "Request rejected";
    case TRADE_RETCODE_CANCEL:
        return "Request canceled";
    case TRADE_RETCODE_PLACED:
        return "Order placed";
    case TRADE_RETCODE_DONE:
        return "Request completed";
    case TRADE_RETCODE_DONE_PARTIAL:
        return "Partial execution";
    case TRADE_RETCODE_ERROR:
        return "Request error";
    case TRADE_RETCODE_TIMEOUT:
        return "Request timeout";
    case TRADE_RETCODE_INVALID:
        return "Invalid request";
    case TRADE_RETCODE_INVALID_VOLUME:
        return "Invalid volume";
    case TRADE_RETCODE_INVALID_PRICE:
        return "Invalid price";
    case TRADE_RETCODE_INVALID_STOPS:
        return "Invalid stops";
    case TRADE_RETCODE_TRADE_DISABLED:
        return "Trading disabled";
    case TRADE_RETCODE_MARKET_CLOSED:
        return "Market closed";
    case TRADE_RETCODE_NO_MONEY:
        return "Insufficient funds";
    case TRADE_RETCODE_PRICE_CHANGED:
        return "Price changed";
    case TRADE_RETCODE_PRICE_OFF:
        return "No quotes";
    case TRADE_RETCODE_INVALID_EXPIRATION:
        return "Invalid expiration";
    case TRADE_RETCODE_ORDER_CHANGED:
        return "Order state changed";
    case TRADE_RETCODE_TOO_MANY_REQUESTS:
        return "Too many requests";
    default:
        return "Unknown error";
    }
}

//+------------------------------------------------------------------+
//| Create entry line                                                |
//+------------------------------------------------------------------+
void CreateEntryLine()
{
    string name = prefix + "EntryLine";
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, entryPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, EntryColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth + 1);
    ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, "Entry Price - Drag to adjust");
}

//+------------------------------------------------------------------+
//| Create stop loss line                                            |
//+------------------------------------------------------------------+
void CreateSLLine()
{
    string name = prefix + "SLLine";
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, slPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, StopLossColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth + 1);
    ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, "Stop Loss - Drag to adjust");
}

//+------------------------------------------------------------------+
//| Create take profit line                                          |
//+------------------------------------------------------------------+
void CreateTPLine()
{
    string name = prefix + "TPLine";
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, tpPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, TakeProfitColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth + 1);
    ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, "Take Profit - Drag to adjust");
}

//+------------------------------------------------------------------+
//| Create risk zone rectangle                                       |
//+------------------------------------------------------------------+
void CreateRiskZone()
{
    string name = prefix + "RiskZone";
    datetime timeLeft = iTime(_Symbol, PERIOD_CURRENT, 50);
    datetime timeRight = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 20;

    // Blend color with background for transparency effect
    color blendedColor = BlendColorWithBackground(RiskZoneColor, ZoneOpacity);

    ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, entryPrice, timeRight, slPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, blendedColor);
    ObjectSetInteger(0, name, OBJPROP_FILL, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create reward zone rectangle                                     |
//+------------------------------------------------------------------+
void CreateRewardZone()
{
    string name = prefix + "RewardZone";
    datetime timeLeft = iTime(_Symbol, PERIOD_CURRENT, 50);
    datetime timeRight = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 20;

    // Blend color with background for transparency effect
    color blendedColor = BlendColorWithBackground(RewardZoneColor, ZoneOpacity);

    ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, entryPrice, timeRight, tpPrice);
    ObjectSetInteger(0, name, OBJPROP_COLOR, blendedColor);
    ObjectSetInteger(0, name, OBJPROP_FILL, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Helper: Convert color to RGB components                          |
//+------------------------------------------------------------------+
void ColorToRGB(color clr, uchar &r, uchar &g, uchar &b)
{
    r = (uchar)((clr) & 0xFF);
    g = (uchar)((clr >> 8) & 0xFF);
    b = (uchar)((clr >> 16) & 0xFF);
}

//+------------------------------------------------------------------+
//| Helper: Blend color with chart background for transparency effect|
//+------------------------------------------------------------------+
color BlendColorWithBackground(color foreground, int opacityPercent)
{
    // Get chart background color
    color bgColor = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);

    uchar fgR, fgG, fgB;
    uchar bgR, bgG, bgB;

    ColorToRGB(foreground, fgR, fgG, fgB);
    ColorToRGB(bgColor, bgR, bgG, bgB);

    // Blend: result = fg * opacity + bg * (1 - opacity)
    double opacity = opacityPercent / 100.0;

    uchar newR = (uchar)(fgR * opacity + bgR * (1.0 - opacity));
    uchar newG = (uchar)(fgG * opacity + bgG * (1.0 - opacity));
    uchar newB = (uchar)(fgB * opacity + bgB * (1.0 - opacity));

    return (color)((newB << 16) | (newG << 8) | newR);
}

//+------------------------------------------------------------------+
//| Create price labels next to lines                                |
//+------------------------------------------------------------------+
void CreatePriceLabels()
{
    // Entry price label with background
    CreateLineLabelWithBackground("EntryLabel", entryPrice, EntryColor, "ENTRY");

    // SL price label with background
    CreateLineLabelWithBackground("SLLabel", slPrice, StopLossColor, "SL");

    // TP price label with background
    CreateLineLabelWithBackground("TPLabel", tpPrice, TakeProfitColor, "TP");
}

//+------------------------------------------------------------------+
//| Helper: Create a label with background box for a price line      |
//+------------------------------------------------------------------+
void CreateLineLabelWithBackground(string id, double price, color clr, string labelText)
{
    string name = prefix + id;

    // Use visible chart area instead of TimeCurrent() (works even when market is closed)
    int firstVisibleBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
    int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
    int rightBarIndex = firstVisibleBar - visibleBars + 5; // 5 bars from right edge
    if (rightBarIndex < 0) rightBarIndex = 0;
    datetime labelTime = iTime(_Symbol, PERIOD_CURRENT, rightBarIndex);

    string fullText = " " + labelText + ": " + DoubleToString(price, _Digits) + " ";

    // Convert price/time to screen coordinates
    int x, y;
    ChartTimePriceToXY(0, 0, labelTime, price, x, y);

    // Calculate text dimensions
    int textWidth = StringLen(fullText) * (FontSize - 2) + 16;
    int textHeight = FontSize + 10;

    // Use OBJ_EDIT as a read-only label with proper background (best alignment)
    ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - textHeight / 2);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, textWidth);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, textHeight);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    ObjectSetString(0, name, OBJPROP_TEXT, fullText);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
    ObjectSetInteger(0, name, OBJPROP_READONLY, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 200);
}

//+------------------------------------------------------------------+
//| Create panel background and elements                             |
//+------------------------------------------------------------------+
void CreatePanel()
{
    int btnSize = 22;
    int smallBtnW = 28;
    int labelCol = 10;      // Left column for labels
    int valueCol = 90;      // Right column for values (aligned)
    int editCol = 50;       // Column for edit fields

    // Panel background
    string bgName = prefix + "PanelBg";
    ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, currentPanelX);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, currentPanelY);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, PanelBgColor);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, PanelBorderColor);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
    ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);

    // Create labels
    int y = 8;
    // Use simple drag handle indicator (triple bar, widely supported)
    CreatePanelLabel("Title", labelCol, y, ":: " + InstanceName + " R:R", clrGold, FontSize+2);

    // Minimize button (top-right corner)
    CreatePanelButton("BtnMinimize", panelWidth - 28, 5, 22, 18, C'60,60,60', clrGray, clrWhite, "_");

    y += 25;

    // Direction row with clickable LONG/SHORT button and PIPS/PRICE toggle
    CreatePanelLabel("Direction", labelCol, y, "Direction:", TextColor, FontSize);
    CreatePanelButton("BtnDirection", 75, y - 2, 55, btnSize, C'20,60,20', clrLimeGreen, clrLimeGreen, "LONG");
    CreatePanelButton("BtnToggleDisplay", panelWidth - 55, y - 2, 50, btnSize, C'50,50,50', clrCyan, clrCyan, "PIPS");

    y += 26;

    // Entry row with editable field and +/- buttons
    CreatePanelLabel("Entry", labelCol, y, "Entry:", TextColor, FontSize);
    CreatePanelEdit("EditEntry", 75, y - 2, 95, btnSize, EntryColor, "0.00000");
    CreatePanelButton("BtnEntryMinus", panelWidth - 65, y - 2, smallBtnW, btnSize, C'30,30,80', EntryColor, EntryColor, "-");
    CreatePanelButton("BtnEntryPlus", panelWidth - 35, y - 2, smallBtnW, btnSize, C'30,30,80', EntryColor, EntryColor, "+");

    y += 28;

    // SL row with editable field and +/- buttons
    CreatePanelLabel("SL", labelCol, y, "SL:", TextColor, FontSize);
    CreatePanelEdit("EditSL", 75, y - 2, 95, btnSize, StopLossColor, "0.00000");
    CreatePanelButton("BtnSLMinus", panelWidth - 65, y - 2, smallBtnW, btnSize, C'80,30,30', StopLossColor, StopLossColor, "-");
    CreatePanelButton("BtnSLPlus", panelWidth - 35, y - 2, smallBtnW, btnSize, C'80,30,30', StopLossColor, StopLossColor, "+");

    y += 28;

    // TP row with editable field and +/- buttons
    CreatePanelLabel("TP", labelCol, y, "TP:", TextColor, FontSize);
    CreatePanelEdit("EditTP", 75, y - 2, 95, btnSize, TakeProfitColor, "0.00000");
    CreatePanelButton("BtnTPMinus", panelWidth - 65, y - 2, smallBtnW, btnSize, C'30,80,30', TakeProfitColor, TakeProfitColor, "-");
    CreatePanelButton("BtnTPPlus", panelWidth - 35, y - 2, smallBtnW, btnSize, C'30,80,30', TakeProfitColor, TakeProfitColor, "+");

    y += 28;
    CreatePanelLabel("Sep1", labelCol, y, "--------------------------------", clrGray, FontSize - 2);

    y += 18;

    // Risk % row with editable field and +/- buttons (0.1% increments)
    CreatePanelLabel("RiskPct", labelCol, y, "Risk:", TextColor, FontSize);
    CreatePanelEdit("EditRisk", valueCol, y - 2, 70, btnSize, clrOrange, "1.0%");
    CreatePanelButton("BtnRiskMinus", panelWidth - 65, y - 2, smallBtnW, btnSize, C'80,60,30', clrOrange, clrOrange, "-");
    CreatePanelButton("BtnRiskPlus", panelWidth - 35, y - 2, smallBtnW, btnSize, C'80,60,30', clrOrange, clrOrange, "+");

    y += 28;

    // Risk $
    CreatePanelLabel("Risk", labelCol, y, "Risk $:", TextColor, FontSize);
    CreatePanelLabel("RiskVal", valueCol, y, "$0.00", StopLossColor, FontSize);

    y += 20;

    // Reward $
    CreatePanelLabel("Reward", labelCol, y, "Reward $:", TextColor, FontSize);
    CreatePanelLabel("RewardVal", valueCol, y, "$0.00", TakeProfitColor, FontSize);

    y += 22;

    // R:R Ratio with editable field and +/- buttons
    CreatePanelLabel("RRRatio", labelCol, y, "R:R Ratio:", TextColor, FontSize);
    CreatePanelLabel("RRPrefix", valueCol, y, "1 :", clrGold, FontSize);
    CreatePanelEdit("EditRR", valueCol + 25, y - 2, 50, btnSize, clrGold, "2.0");
    CreatePanelButton("BtnRRMinus", panelWidth - 65, y - 2, smallBtnW, btnSize, C'80,80,30', clrGold, clrGold, "-");
    CreatePanelButton("BtnRRPlus", panelWidth - 35, y - 2, smallBtnW, btnSize, C'80,80,30', clrGold, clrGold, "+");

    y += 26;
    CreatePanelLabel("Sep2", labelCol, y, "--------------------------------", clrGray, FontSize - 2);

    y += 18;

    // Lot Size
    CreatePanelLabel("Lots", labelCol, y, "Lot Size:", TextColor, FontSize);
    CreatePanelLabel("LotsVal", valueCol, y, "0.00", clrGold, FontSize);

    y += 24;

    // Mode
    CreatePanelLabel("RiskMode", labelCol, y, "Mode:", TextColor, FontSize);
    CreatePanelLabel("RiskModeVal", valueCol, y, "% Balance", TextColor, FontSize);

    y += 22;

    // Order Type (auto-detected)
    CreatePanelLabel("OrderType", labelCol, y, "Order:", TextColor, FontSize);
    CreatePanelLabel("OrderTypeVal", valueCol, y, "BUY LIMIT", clrGold, FontSize);

    y += 26;

    // Execute button - places pending order at entry price
    CreatePanelButton("BtnExecute", 10, y, panelWidth - 20, 25, clrDarkGreen, clrLimeGreen, clrWhite, "PLACE ORDER");

    y += 28;

    // Market Order button - instant execution at current price
    CreatePanelButton("BtnMarketOrder", 10, y, panelWidth - 20, 25, clrDarkOrange, clrOrange, clrWhite, "MARKET ORDER");

    y += 28;

    // Reset button
    CreatePanelButton("BtnReset", 10, y, panelWidth - 20, 25, clrDimGray, clrGray, clrWhite, "RESET");
}

//+------------------------------------------------------------------+
//| Helper: Create a panel button                                    |
//+------------------------------------------------------------------+
void CreatePanelButton(string id, int x, int y, int width, int height,
                       color bgClr, color borderClr, color textClr, string text)
{
    string name = prefix + id;
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, currentPanelX + x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, currentPanelY + y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, name, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textClr);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Helper: Create a panel edit field                                |
//+------------------------------------------------------------------+
void CreatePanelEdit(string id, int x, int y, int width, int height,
                     color textClr, string text)
{
    string name = prefix + id;
    ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, currentPanelX + x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, currentPanelY + y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, name, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'30,30,30');
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, textClr);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textClr);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
    ObjectSetInteger(0, name, OBJPROP_READONLY, false);
}

//+------------------------------------------------------------------+
//| Helper: Create panel label                                       |
//+------------------------------------------------------------------+
void CreatePanelLabel(string id, int x, int y, string text, color clr, int size)
{
    string name = prefix + "Lbl" + id;
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, currentPanelX + x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, currentPanelY + y);
    ObjectSetInteger(0, name, OBJPROP_CORNER, PanelCorner);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Update prices from line positions                                |
//+------------------------------------------------------------------+
void UpdatePricesFromLines()
{
    entryPrice = ObjectGetDouble(0, prefix + "EntryLine", OBJPROP_PRICE);
    slPrice = ObjectGetDouble(0, prefix + "SLLine", OBJPROP_PRICE);
    tpPrice = ObjectGetDouble(0, prefix + "TPLine", OBJPROP_PRICE);

    // Normalize to symbol digits
    entryPrice = NormalizeDouble(entryPrice, _Digits);
    slPrice = NormalizeDouble(slPrice, _Digits);
    tpPrice = NormalizeDouble(tpPrice, _Digits);
}

//+------------------------------------------------------------------+
//| Redraw zone rectangles                                           |
//+------------------------------------------------------------------+
void RedrawZones()
{
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
//| Redraw price labels                                              |
//+------------------------------------------------------------------+
void RedrawLabels()
{
    // Use visible chart area instead of TimeCurrent() (works even when market is closed)
    int firstVisibleBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
    int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
    int rightBarIndex = firstVisibleBar - visibleBars + 5; // 5 bars from right edge
    if (rightBarIndex < 0) rightBarIndex = 0;
    datetime labelTime = iTime(_Symbol, PERIOD_CURRENT, rightBarIndex);

    double slPips = GetPipsDistance(entryPrice, slPrice);
    double tpPips = GetPipsDistance(entryPrice, tpPrice);

    // Entry label with R:R ratio (show decimal only if needed)
    string rrStr = (currentRRRatio == MathFloor(currentRRRatio))
                   ? DoubleToString(currentRRRatio, 0)
                   : DoubleToString(currentRRRatio, 1);
    string entryText = " ENTRY: " + DoubleToString(entryPrice, _Digits) + " (RR:" + rrStr + ") ";
    UpdateLineLabel("EntryLabel", labelTime, entryPrice, entryText);

    // SL label with pips
    string slText = " SL: " + DoubleToString(slPrice, _Digits) + " (" + DoubleToString(slPips, 1) + "p) ";
    UpdateLineLabel("SLLabel", labelTime, slPrice, slText);

    // TP label with pips
    string tpText = " TP: " + DoubleToString(tpPrice, _Digits) + " (" + DoubleToString(tpPips, 1) + "p) ";
    UpdateLineLabel("TPLabel", labelTime, tpPrice, tpText);
}

//+------------------------------------------------------------------+
//| Update line label position and text                              |
//+------------------------------------------------------------------+
void UpdateLineLabel(string id, datetime labelTime, double price, string text)
{
    string name = prefix + id;

    // Convert price/time to screen coordinates
    int x, y;
    ChartTimePriceToXY(0, 0, labelTime, price, x, y);

    // Calculate text dimensions
    int textWidth = StringLen(text) * (FontSize - 2) + 16;
    int textHeight = FontSize + 10;

    // Update position, size, text, and ensure font consistency
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - textHeight / 2);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, textWidth);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, textHeight);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Update panel with current values                                 |
//+------------------------------------------------------------------+
void UpdatePanel()
{
    bool isLong = IsLongPosition();
    double lots = CalculateLotSize();
    double riskAmt = GetRiskAmount();
    double rewardAmt = CalculateRewardAmount();
    double slPips = GetPipsDistance(entryPrice, slPrice);
    double tpPips = GetPipsDistance(entryPrice, tpPrice);

    // Direction button - update text, text color, background color, and border color
    ObjectSetString(0, prefix + "BtnDirection", OBJPROP_TEXT, isLong ? "LONG" : "SHORT");
    ObjectSetInteger(0, prefix + "BtnDirection", OBJPROP_COLOR, isLong ? clrLimeGreen : clrCrimson);
    ObjectSetInteger(0, prefix + "BtnDirection", OBJPROP_BGCOLOR, isLong ? C'20,60,20' : C'60,20,20');
    ObjectSetInteger(0, prefix + "BtnDirection", OBJPROP_BORDER_COLOR, isLong ? clrLimeGreen : clrCrimson);

    // Update edit fields based on display mode
    ObjectSetString(0, prefix + "EditEntry", OBJPROP_TEXT, DoubleToString(entryPrice, _Digits));

    if (priceDisplayMode == DISPLAY_ABSOLUTE_PRICE)
    {
        // Show absolute prices in edit fields
        ObjectSetString(0, prefix + "EditSL", OBJPROP_TEXT, DoubleToString(slPrice, _Digits));
        ObjectSetString(0, prefix + "EditTP", OBJPROP_TEXT, DoubleToString(tpPrice, _Digits));
        // Update labels
        ObjectSetString(0, prefix + "LblSL", OBJPROP_TEXT, "SL:");
        ObjectSetString(0, prefix + "LblTP", OBJPROP_TEXT, "TP:");
    }
    else
    {
        // Show pips in edit fields
        ObjectSetString(0, prefix + "EditSL", OBJPROP_TEXT, DoubleToString(slPips, 1));
        ObjectSetString(0, prefix + "EditTP", OBJPROP_TEXT, DoubleToString(tpPips, 1));
        // Update labels to indicate pips mode
        ObjectSetString(0, prefix + "LblSL", OBJPROP_TEXT, "SL (pips):");
        ObjectSetString(0, prefix + "LblTP", OBJPROP_TEXT, "TP (pips):");
    }

    // Risk % value (editable field)
    if (RiskMode == RISK_PERCENT_BALANCE || RiskMode == RISK_PERCENT_EQUITY)
    {
        ObjectSetString(0, prefix + "EditRisk", OBJPROP_TEXT, DoubleToString(currentRiskValue, 1) + "%");
    }
    else
    {
        ObjectSetString(0, prefix + "EditRisk", OBJPROP_TEXT, "$" + DoubleToString(currentRiskValue, 0));
    }

    // Risk/Reward in dollars
    ObjectSetString(0, prefix + "LblRiskVal", OBJPROP_TEXT, "$" + DoubleToString(riskAmt, 2));
    ObjectSetString(0, prefix + "LblRewardVal", OBJPROP_TEXT, "$" + DoubleToString(rewardAmt, 2));
    // Update R:R ratio edit field
    ObjectSetString(0, prefix + "EditRR", OBJPROP_TEXT, DoubleToString(currentRRRatio, 1));

    // Lot size
    ObjectSetString(0, prefix + "LblLotsVal", OBJPROP_TEXT, DoubleToString(lots, 2));

    // Risk mode description
    string modeStr = "";
    switch (RiskMode)
    {
    case RISK_FIXED_CASH_BALANCE:
        modeStr = "$ Fixed (Bal)";
        break;
    case RISK_FIXED_CASH_EQUITY:
        modeStr = "$ Fixed (Eq)";
        break;
    case RISK_PERCENT_BALANCE:
        modeStr = "% of Balance";
        break;
    case RISK_PERCENT_EQUITY:
        modeStr = "% of Equity";
        break;
    }
    ObjectSetString(0, prefix + "LblRiskModeVal", OBJPROP_TEXT, modeStr);

    // Update order type display
    string orderTypeStr = GetOrderTypeDescription();
    ObjectSetString(0, prefix + "LblOrderTypeVal", OBJPROP_TEXT, orderTypeStr);

    // Color the order type based on whether it's limit/stop/market
    ENUM_ORDER_TYPE orderType = GetSmartOrderType();
    color orderTypeColor = clrGold;
    if (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT)
        orderTypeColor = clrDodgerBlue;
    else if (orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP)
        orderTypeColor = clrOrange;
    else
        orderTypeColor = clrLimeGreen; // Market order
    ObjectSetInteger(0, prefix + "LblOrderTypeVal", OBJPROP_COLOR, orderTypeColor);

    // Update execute button color and text based on direction and order type
    ObjectSetInteger(0, prefix + "BtnExecute", OBJPROP_BGCOLOR, isLong ? clrDarkGreen : clrDarkRed);
    ObjectSetInteger(0, prefix + "BtnExecute", OBJPROP_BORDER_COLOR, isLong ? clrLimeGreen : clrCrimson);
    ObjectSetString(0, prefix + "BtnExecute", OBJPROP_TEXT, orderTypeStr);

    // Update market order button color based on direction
    ObjectSetInteger(0, prefix + "BtnMarketOrder", OBJPROP_BGCOLOR, isLong ? C'0,100,50' : C'100,50,0');
    ObjectSetInteger(0, prefix + "BtnMarketOrder", OBJPROP_BORDER_COLOR, isLong ? clrLimeGreen : clrCrimson);
    ObjectSetString(0, prefix + "BtnMarketOrder", OBJPROP_TEXT, isLong ? "MARKET BUY" : "MARKET SELL");
}

//+------------------------------------------------------------------+
//| Check if position is long                                        |
//+------------------------------------------------------------------+
bool IsLongPosition()
{
    // Long if TP is above entry, Short if TP is below entry
    return (tpPrice > entryPrice);
}

//+------------------------------------------------------------------+
//| Get smart order type based on entry price vs current price       |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetSmartOrderType()
{
    bool isLong = IsLongPosition();
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    if (isLong)
    {
        // BUY order
        if (entryPrice < currentAsk)
        {
            // Entry below current price = BUY LIMIT
            return ORDER_TYPE_BUY_LIMIT;
        }
        else if (entryPrice > currentAsk)
        {
            // Entry above current price = BUY STOP
            return ORDER_TYPE_BUY_STOP;
        }
        else
        {
            // Entry at current price = Market BUY
            return ORDER_TYPE_BUY;
        }
    }
    else
    {
        // SELL order
        if (entryPrice > currentBid)
        {
            // Entry above current price = SELL LIMIT
            return ORDER_TYPE_SELL_LIMIT;
        }
        else if (entryPrice < currentBid)
        {
            // Entry below current price = SELL STOP
            return ORDER_TYPE_SELL_STOP;
        }
        else
        {
            // Entry at current price = Market SELL
            return ORDER_TYPE_SELL;
        }
    }
}

//+------------------------------------------------------------------+
//| Get order type description for display                           |
//+------------------------------------------------------------------+
string GetOrderTypeDescription()
{
    ENUM_ORDER_TYPE orderType = GetSmartOrderType();

    switch (orderType)
    {
    case ORDER_TYPE_BUY:
        return "MARKET BUY";
    case ORDER_TYPE_SELL:
        return "MARKET SELL";
    case ORDER_TYPE_BUY_LIMIT:
        return "BUY LIMIT";
    case ORDER_TYPE_SELL_LIMIT:
        return "SELL LIMIT";
    case ORDER_TYPE_BUY_STOP:
        return "BUY STOP";
    case ORDER_TYPE_SELL_STOP:
        return "SELL STOP";
    default:
        return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk parameters                      |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double riskAmount = GetRiskAmount();
    double slDistance = MathAbs(entryPrice - slPrice);

    if (slDistance == 0)
        return 0;

    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if (tickValue == 0 || tickSize == 0)
        return 0;

    double riskPerLot = (slDistance / tickSize) * tickValue;

    if (riskPerLot == 0)
        return 0;

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
//| Get risk amount based on selected mode                           |
//+------------------------------------------------------------------+
double GetRiskAmount()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    switch (RiskMode)
    {
    case RISK_FIXED_CASH_BALANCE:
    case RISK_FIXED_CASH_EQUITY:
        return currentRiskValue;
    case RISK_PERCENT_BALANCE:
        return balance * currentRiskValue / 100.0;
    case RISK_PERCENT_EQUITY:
        return equity * currentRiskValue / 100.0;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Calculate reward amount in dollars                               |
//+------------------------------------------------------------------+
double CalculateRewardAmount()
{
    double lots = CalculateLotSize();
    double tpDistance = MathAbs(tpPrice - entryPrice);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if (tickSize == 0 || lots == 0)
        return 0;

    return (tpDistance / tickSize) * tickValue * lots;
}

//+------------------------------------------------------------------+
//| Calculate Risk:Reward ratio                                      |
//+------------------------------------------------------------------+
double CalculateRRRatio()
{
    double slDistance = MathAbs(entryPrice - slPrice);
    double tpDistance = MathAbs(tpPrice - entryPrice);

    if (slDistance == 0)
        return 0;

    return tpDistance / slDistance;
}

//+------------------------------------------------------------------+
//| Get distance in pips                                             |
//+------------------------------------------------------------------+
double GetPipsDistance(double price1, double price2)
{
    double pipSize = GetPipSize();
    return MathAbs(price1 - price2) / pipSize;
}

//+------------------------------------------------------------------+
//| Get pip size for the current symbol                              |
//+------------------------------------------------------------------+
double GetPipSize()
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    // Check for Gold (XAU) - traders consider 1 pip = 0.10 (10 points)
    // Use first 3 chars to handle XAUUSD, XAUUSDx, XAUUSD.r, XAUUSD+, etc.
    string symbolPrefix = StringSubstr(_Symbol, 0, 3);
    if (symbolPrefix == "XAU")
    {
        return point * 10; // Gold: 1 pip = 10 points (0.10)
    }

    // Pip size: for 5-digit forex (EURUSD) pip = point * 10
    // For 2/3 digit (JPY pairs), pip = point
    return (digits == 3 || digits == 5) ? point * 10 : point;
}

//+------------------------------------------------------------------+
//| Reset lines to default positions                                 |
//+------------------------------------------------------------------+
void ResetLinesToDefault()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    double atrValue;
    if (CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
    {
        atrValue = atrBuffer[0];
    }
    else
    {
        atrValue = currentPrice * 0.01;
    }
    IndicatorRelease(atrHandle);

    // Preserve current direction (LONG or SHORT)
    bool wasLong = IsLongPosition();

    // Reset R:R ratio to default value from inputs
    currentRRRatio = DefaultRRRatio;

    entryPrice = NormalizeDouble(currentPrice, digits);

    if (wasLong)
    {
        // LONG position: SL below entry, TP above entry
        slPrice = NormalizeDouble(currentPrice - atrValue, digits);
        tpPrice = NormalizeDouble(currentPrice + (atrValue * currentRRRatio), digits);
    }
    else
    {
        // SHORT position: SL above entry, TP below entry
        slPrice = NormalizeDouble(currentPrice + atrValue, digits);
        tpPrice = NormalizeDouble(currentPrice - (atrValue * currentRRRatio), digits);
    }

    ObjectSetDouble(0, prefix + "EntryLine", OBJPROP_PRICE, entryPrice);
    ObjectSetDouble(0, prefix + "SLLine", OBJPROP_PRICE, slPrice);
    ObjectSetDouble(0, prefix + "TPLine", OBJPROP_PRICE, tpPrice);

    RedrawZones();
    RedrawLabels();
    UpdatePanel();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Remove drawing objects (lines, zones, labels) after order exec   |
//+------------------------------------------------------------------+
void RemoveDrawingObjects()
{
    // Remove the horizontal lines
    ObjectDelete(0, prefix + "EntryLine");
    ObjectDelete(0, prefix + "SLLine");
    ObjectDelete(0, prefix + "TPLine");

    // Remove the zones
    ObjectDelete(0, prefix + "RiskZone");
    ObjectDelete(0, prefix + "RewardZone");

    // Remove the price labels on chart
    ObjectDelete(0, prefix + "EntryLabel");
    ObjectDelete(0, prefix + "SLLabel");
    ObjectDelete(0, prefix + "TPLabel");

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Toggle panel minimize/expand                                      |
//+------------------------------------------------------------------+
void TogglePanelMinimize()
{
    panelMinimized = !panelMinimized;

    // Save minimized state to GlobalVariable (persists across timeframe changes)
    GlobalVariableSet(prefix + "Minimized", panelMinimized ? 1.0 : 0.0);

    // List of panel objects to hide/show using OBJPROP_TIMEFRAMES
    string panelObjectsToToggle[] = {
        "LblDirection", "BtnDirection",
        "BtnToggleDisplay",
        "LblEntry", "EditEntry",
        "BtnEntryMinus", "BtnEntryPlus",
        "LblSL", "EditSL",
        "BtnSLMinus", "BtnSLPlus",
        "LblTP", "EditTP",
        "BtnTPMinus", "BtnTPPlus",
        "LblSep1",
        "LblRiskPct", "EditRisk",
        "BtnRiskMinus", "BtnRiskPlus",
        "LblRisk", "LblRiskVal",
        "LblReward", "LblRewardVal",
        "LblRRRatio", "LblRRPrefix", "EditRR",
        "BtnRRMinus", "BtnRRPlus",
        "LblSep2",
        "LblLots", "LblLotsVal",
        "LblRiskMode", "LblRiskModeVal",
        "LblOrderType", "LblOrderTypeVal",
        "BtnMarketOrder",
        "BtnExecute",
        "BtnReset"};

    int numPanelObjects = ArraySize(panelObjectsToToggle);

    for (int i = 0; i < numPanelObjects; i++)
    {
        string objName = prefix + panelObjectsToToggle[i];
        if (ObjectFind(0, objName) >= 0)
        {
            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, panelMinimized ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
        }
    }

    // Resize panel background
    if (panelMinimized)
    {
        ObjectSetInteger(0, prefix + "PanelBg", OBJPROP_YSIZE, panelHeightMinimized);
        ObjectSetString(0, prefix + "BtnMinimize", OBJPROP_TEXT, "+");

        // Delete chart objects (lines, zones, labels) when minimizing
        ObjectDelete(0, prefix + "EntryLine");
        ObjectDelete(0, prefix + "SLLine");
        ObjectDelete(0, prefix + "TPLine");
        ObjectDelete(0, prefix + "RiskZone");
        ObjectDelete(0, prefix + "RewardZone");
        ObjectDelete(0, prefix + "EntryLabel");
        ObjectDelete(0, prefix + "SLLabel");
        ObjectDelete(0, prefix + "TPLabel");
    }
    else
    {
        ObjectSetInteger(0, prefix + "PanelBg", OBJPROP_YSIZE, panelHeight);
        ObjectSetString(0, prefix + "BtnMinimize", OBJPROP_TEXT, "_");

        // Recreate chart objects when maximizing
        CreateEntryLine();
        CreateSLLine();
        CreateTPLine();
        CreateRiskZone();
        CreateRewardZone();
        CreatePriceLabels();

        // Update positions and redraw
        RedrawZones();
        RedrawLabels();
        UpdatePanel();
    }
}
//+------------------------------------------------------------------+
