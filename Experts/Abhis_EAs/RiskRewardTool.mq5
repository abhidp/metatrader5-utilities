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

enum ENUM_PANEL_THEME
{
    THEME_DARK,   // Dark Mode
    THEME_LIGHT   // Light Mode
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
input group "Visual Settings"
input ENUM_PANEL_THEME PanelTheme = THEME_LIGHT;   // Panel Theme
input int FontSize = 9;                            // Font Size
input int LineWidth = 1;                           // Line Width
input ENUM_LINE_STYLE LineStyle = STYLE_DASHDOT;  // Line Style
input int ZoneOpacity = 10;                        // Zone Opacity (0-100%)

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

// Track if lines are currently selectable (disabled when mouse over panel)
bool linesSelectable = true;

// Current theme (can be toggled at runtime)
ENUM_PANEL_THEME currentTheme;

// Theme Colors (set by InitThemeColors)
color clrPanelBg;           // Main panel background
color clrPanelBorder;       // Panel border
color clrSectionBg;         // Section background (for grouping)
color clrTextPrimary;       // Primary text color
color clrTextSecondary;     // Secondary/dimmed text
color clrTextMuted;         // Muted text (separators, labels)
color clrInputBg;           // Input field background
color clrInputBorder;       // Input field border
color clrInputText;         // Input field text
color clrBtnBg;             // Button background
color clrBtnBorder;         // Button border
color clrBtnText;           // Button text
color clrBtnPlusMinus;      // +/- button background
color clrAccentBuy;         // Buy/Long accent (green) - for MARKET BUY
color clrAccentBuyLight;    // Light green - for BUY LIMIT/BUY STOP
color clrAccentSell;        // Sell/Short accent (red) - for MARKET SELL
color clrAccentEntry;       // Entry line/field accent (blue)
color clrAccentWarning;     // Warning/Risk accent (orange)
color clrAccentGold;        // Gold accent for R:R, lots
color clrHeaderBg;          // Header/title bar background
color clrHeaderText;        // Header text color

// Dynamic risk value (can be adjusted from panel)
double currentRiskValue;

// Dynamic R:R ratio (can be adjusted from panel)
double currentRRRatio;

// Panel dimensions
int panelWidth = 270;
int panelHeight = 450;
int panelHeightMinimized = 28;

// Double-click detection for panel title (milliseconds)
uint lastTitleClickTime = 0;

// Price increment for +/- buttons (will be calculated based on symbol)
double priceIncrement;

//+------------------------------------------------------------------+
//| Initialize theme colors based on selected theme                  |
//+------------------------------------------------------------------+
void InitThemeColors()
{
    if (currentTheme == THEME_LIGHT)
    {
        // Light Theme - Clean, modern, high contrast
        clrPanelBg = C'245,245,247';        // Light gray background
        clrPanelBorder = C'200,200,205';    // Subtle border
        clrSectionBg = C'255,255,255';      // White sections
        clrTextPrimary = C'30,30,35';       // Near black text
        clrTextSecondary = C'80,80,90';     // Dark gray
        clrTextMuted = C'150,150,160';      // Muted gray
        clrInputBg = C'255,255,255';        // White input background
        clrInputBorder = C'180,180,190';    // Input border
        clrInputText = C'30,30,35';         // Dark input text
        clrBtnBg = C'235,235,240';          // Light button background
        clrBtnBorder = C'180,180,190';      // Button border
        clrBtnText = C'50,50,60';           // Button text
        clrBtnPlusMinus = C'225,225,230';   // +/- button background
        clrAccentBuy = C'34,139,34';        // Forest green (MARKET BUY)
        clrAccentBuyLight = C'60,179,113';  // Medium sea green (BUY LIMIT/STOP)
        clrAccentSell = C'178,34,34';       // Firebrick red (MARKET SELL)
        clrAccentEntry = C'30,100,180';     // Blue (Entry)
        clrAccentWarning = C'210,105,30';   // Chocolate orange (Risk)
        clrAccentGold = C'180,130,20';      // Dark gold
        clrHeaderBg = C'50,55,65';          // Dark header
        clrHeaderText = C'255,255,255';     // White header text
    }
    else
    {
        // Dark Theme - Modern dark with good contrast
        clrPanelBg = C'32,34,37';           // Dark background
        clrPanelBorder = C'60,63,68';       // Subtle border
        clrSectionBg = C'44,47,51';         // Slightly lighter sections
        clrTextPrimary = C'220,222,225';    // Off-white text
        clrTextSecondary = C'160,165,175';  // Light gray
        clrTextMuted = C'100,105,115';      // Muted gray
        clrInputBg = C'55,58,62';           // Dark input background
        clrInputBorder = C'80,85,95';       // Input border
        clrInputText = C'230,232,235';      // Light input text
        clrBtnBg = C'55,58,62';             // Dark button background
        clrBtnBorder = C'80,85,95';         // Button border
        clrBtnText = C'200,205,215';        // Light button text
        clrBtnPlusMinus = C'65,68,75';      // +/- button background
        clrAccentBuy = C'50,205,50';        // Lime green (MARKET BUY)
        clrAccentBuyLight = C'100,220,100'; // Light lime green (BUY LIMIT/STOP)
        clrAccentSell = C'255,80,80';       // Bright red (MARKET SELL)
        clrAccentEntry = C'65,145,255';     // Bright blue (Entry)
        clrAccentWarning = C'255,165,50';   // Orange (Risk)
        clrAccentGold = C'255,200,50';      // Bright gold
        clrHeaderBg = C'25,27,30';          // Darker header
        clrHeaderText = C'255,200,50';      // Gold header text
    }
}

//+------------------------------------------------------------------+
//| Toggle theme between light and dark                              |
//+------------------------------------------------------------------+
void ToggleTheme()
{
    currentTheme = (currentTheme == THEME_LIGHT) ? THEME_DARK : THEME_LIGHT;

    // Save theme to GlobalVariable (persists across timeframe changes)
    GlobalVariableSet(prefix + "Theme", (double)currentTheme);

    // Reinitialize colors and recreate panel
    InitThemeColors();
    RecreatePanel();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set unique prefix for this instance
    prefix = InstanceName + "_";

    // Restore theme from GlobalVariable or use input default
    string gvTheme = prefix + "Theme";
    if (GlobalVariableCheck(gvTheme))
        currentTheme = (ENUM_PANEL_THEME)(int)GlobalVariableGet(gvTheme);
    else
        currentTheme = PanelTheme;

    // Initialize theme colors
    InitThemeColors();

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

    // Restore line prices from GlobalVariables (persists across timeframe changes)
    string gvEntryPrice = prefix + "EntryPrice";
    string gvSLPrice = prefix + "SLPrice";
    string gvTPPrice = prefix + "TPPrice";

    if (GlobalVariableCheck(gvEntryPrice) && GlobalVariableCheck(gvSLPrice) && GlobalVariableCheck(gvTPPrice))
    {
        // Restore saved prices
        entryPrice = NormalizeDouble(GlobalVariableGet(gvEntryPrice), digits);
        slPrice = NormalizeDouble(GlobalVariableGet(gvSLPrice), digits);
        tpPrice = NormalizeDouble(GlobalVariableGet(gvTPPrice), digits);
    }
    else
    {
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
    }

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
        GlobalVariableDel(prefix + "EntryPrice");
        GlobalVariableDel(prefix + "SLPrice");
        GlobalVariableDel(prefix + "TPPrice");
        GlobalVariableDel(prefix + "Theme");
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

    // === Handle Chart Click - Reset line selectability when clicking outside panel ===
    if (id == CHARTEVENT_CLICK)
    {
        int mouseX = (int)lparam;
        int mouseY = (int)dparam;

        // If clicking outside the panel, ensure lines are selectable
        if (!IsMouseOverPanel(mouseX, mouseY))
        {
            SetLinesSelectable(true);
        }
    }

    // === Handle Mouse Move for Panel Dragging (press-and-hold style) ===
    if (id == CHARTEVENT_MOUSE_MOVE)
    {
        int mouseX = (int)lparam;
        int mouseY = (int)dparam;
        uint mouseState = (uint)sparam; // Mouse button state

        // Check if left mouse button is pressed (bit 0)
        bool leftButtonPressed = (mouseState & 1) == 1;

        // Disable line selectability when mouse is over the panel (prevents clicking through)
        bool overPanel = IsMouseOverPanel(mouseX, mouseY);
        SetLinesSelectable(!overPanel);

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
                // Get the new dragged price
                double newPrice = ObjectGetDouble(0, sparam, OBJPROP_PRICE);
                bool isLong = IsLongPosition();
                bool isValid = true;

                // Validate line positions based on direction
                // LONG: SL < Entry < TP
                // SHORT: TP < Entry < SL
                if (sparam == prefix + "EntryLine")
                {
                    if (isLong)
                    {
                        // Entry must be above SL and below TP
                        if (newPrice <= slPrice || newPrice >= tpPrice)
                            isValid = false;
                    }
                    else
                    {
                        // Entry must be below SL and above TP
                        if (newPrice >= slPrice || newPrice <= tpPrice)
                            isValid = false;
                    }

                    if (!isValid)
                    {
                        // Revert to previous position
                        ObjectSetDouble(0, sparam, OBJPROP_PRICE, entryPrice);
                        ChartRedraw();
                        return;
                    }
                }
                else if (sparam == prefix + "SLLine")
                {
                    if (isLong)
                    {
                        // SL must be below Entry
                        if (newPrice >= entryPrice)
                            isValid = false;
                    }
                    else
                    {
                        // SL must be above Entry
                        if (newPrice <= entryPrice)
                            isValid = false;
                    }

                    if (!isValid)
                    {
                        // Revert to previous position
                        ObjectSetDouble(0, sparam, OBJPROP_PRICE, slPrice);
                        ChartRedraw();
                        return;
                    }
                }
                else if (sparam == prefix + "TPLine")
                {
                    if (isLong)
                    {
                        // TP must be above Entry
                        if (newPrice <= entryPrice)
                            isValid = false;
                    }
                    else
                    {
                        // TP must be below Entry
                        if (newPrice >= entryPrice)
                            isValid = false;
                    }

                    if (!isValid)
                    {
                        // Revert to previous position
                        ObjectSetDouble(0, sparam, OBJPROP_PRICE, tpPrice);
                        ChartRedraw();
                        return;
                    }
                }

                UpdatePricesFromLines();
                UpdateRRRatioFromLines(); // Update R:R ratio based on new line positions
                SaveLinePrices(); // Persist across timeframe changes
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
                SaveLinePrices();
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
                SaveLinePrices();
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
                SaveLinePrices();
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
                RedrawLabels();
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
        if (sparam == prefix + "EditLots")
        {
            string text = ObjectGetString(0, sparam, OBJPROP_TEXT);
            double newLots = StringToDouble(text);

            // Normalize to broker requirements
            double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

            if (newLots >= minLot)
            {
                // Normalize lot size
                newLots = NormalizeDouble(MathRound(newLots / lotStep) * lotStep, 2);
                newLots = MathMax(minLot, MathMin(maxLot, newLots));

                // Back-calculate risk from the entered lot size
                CalculateRiskFromLots(newLots);

                // Update lot field with normalized value
                ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(newLots, 2));

                // Update panel (except lots to preserve entered value) and labels
                UpdatePanelExceptLots();
                RedrawLabels();
                ChartRedraw();
            }
            else
            {
                // Restore the calculated lot size if invalid
                ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(CalculateLotSize(), 2));
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

        // Theme toggle button
        if (sparam == prefix + "BtnTheme")
        {
            ToggleTheme();
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
        }

        // Double-click on panel title bar area to toggle minimize
        // Works on title label, header background rect, or panel background within title bar region
        bool isTitleBarClick = false;

        if (sparam == prefix + "LblTitle" || sparam == prefix + "RectHeaderBg")
        {
            isTitleBarClick = true;
        }
        else if (sparam == prefix + "PanelBg")
        {
            // Check if click is within title bar region (top 28 pixels of panel)
            int clickY = (int)dparam;
            if (clickY >= currentPanelY && clickY <= currentPanelY + 28)
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

        // === Lot Size +/- Buttons ===
        if (sparam == prefix + "BtnLotsPlus")
        {
            AdjustLotSize(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)); // Increase by lot step
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            ChartRedraw();
            return;
        }
        if (sparam == prefix + "BtnLotsMinus")
        {
            AdjustLotSize(-SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)); // Decrease by lot step
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
//| Save line prices to GlobalVariables (persist across TF changes)  |
//+------------------------------------------------------------------+
void SaveLinePrices()
{
    GlobalVariableSet(prefix + "EntryPrice", entryPrice);
    GlobalVariableSet(prefix + "SLPrice", slPrice);
    GlobalVariableSet(prefix + "TPPrice", tpPrice);
}

//+------------------------------------------------------------------+
//| Check if mouse is over the panel area                            |
//+------------------------------------------------------------------+
bool IsMouseOverPanel(int x, int y)
{
    int actualPanelHeight = panelMinimized ? panelHeightMinimized : panelHeight;
    return (x >= currentPanelX && x <= currentPanelX + panelWidth &&
            y >= currentPanelY && y <= currentPanelY + actualPanelHeight);
}

//+------------------------------------------------------------------+
//| Set line selectability state                                     |
//+------------------------------------------------------------------+
void SetLinesSelectable(bool selectable)
{
    linesSelectable = selectable;

    // Only modify lines if they exist (panel is expanded)
    if (!panelMinimized)
    {
        string lineNames[] = {prefix + "EntryLine", prefix + "SLLine", prefix + "TPLine"};
        for (int i = 0; i < 3; i++)
        {
            if (ObjectFind(0, lineNames[i]) >= 0)
            {
                ObjectSetInteger(0, lineNames[i], OBJPROP_SELECTABLE, selectable);
                ObjectSetInteger(0, lineNames[i], OBJPROP_SELECTED, selectable);
            }
        }
        ChartRedraw();
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
    // Note: RectHeaderBg is NOT included - it should always be visible
    string panelObjectsToHide[] = {
        "RectPriceSection", "RectRiskSection", "RectLotSection",
        "LblDirection", "BtnDirection",
        "BtnToggleDisplay",
        "LblEntry", "EditEntry",
        "BtnEntryMinus", "BtnEntryPlus",
        "LblSL", "EditSL",
        "BtnSLMinus", "BtnSLPlus",
        "LblTP", "EditTP",
        "BtnTPMinus", "BtnTPPlus",
        "LblRiskPct", "EditRisk",
        "BtnRiskMinus", "BtnRiskPlus",
        "LblRisk", "LblRiskVal",
        "LblReward", "LblRewardVal",
        "LblRRRatio", "LblRRPrefix", "EditRR",
        "BtnRRMinus", "BtnRRPlus",
        "LblLots", "EditLots", "BtnLotsMinus", "BtnLotsPlus",
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
    ObjectSetString(0, prefix + "BtnMinimize", OBJPROP_TEXT, "□");
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
    RedrawLabels();
    ChartRedraw();
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
//| Adjust lot size value                                            |
//+------------------------------------------------------------------+
void AdjustLotSize(double adjustment)
{
    // Read current lot size from the edit field (not calculated) to avoid precision drift
    string currentText = ObjectGetString(0, prefix + "EditLots", OBJPROP_TEXT);
    double currentLots = StringToDouble(currentText);

    // If field is empty or invalid, use calculated value as fallback
    if (currentLots <= 0)
        currentLots = CalculateLotSize();

    double newLots = currentLots + adjustment;

    // Normalize to broker requirements
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    // Round to lot step precision
    newLots = NormalizeDouble(MathRound(newLots / lotStep) * lotStep, 2);
    newLots = MathMax(minLot, MathMin(maxLot, newLots));

    // Back-calculate risk from the new lot size
    CalculateRiskFromLots(newLots);

    // Update the edit field directly with the new lot size (avoid recalculation drift)
    ObjectSetString(0, prefix + "EditLots", OBJPROP_TEXT, DoubleToString(newLots, 2));

    // Update rest of panel and labels (but skip lot field update in UpdatePanel)
    UpdatePanelExceptLots();
    RedrawLabels();
    ChartRedraw();
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

    // Persist across timeframe changes
    SaveLinePrices();

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
    SaveLinePrices(); // Persist across timeframe changes
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

    // Recreate lines to ensure proper properties (including selectability)
    CreateEntryLine();
    CreateSLLine();
    CreateTPLine();
    CreateRiskZone();
    CreateRewardZone();
    CreatePriceLabels();

    UpdateRRRatioFromLines(); // Update R:R ratio (should stay the same, but recalculate to be safe)
    SaveLinePrices(); // Persist across timeframe changes
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
    if (ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, entryPrice);
    }
    else
    {
        ObjectSetDouble(0, name, OBJPROP_PRICE, entryPrice);
    }
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrAccentEntry);
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
    if (ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, slPrice);
    }
    else
    {
        ObjectSetDouble(0, name, OBJPROP_PRICE, slPrice);
    }
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrAccentSell);
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
    if (ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, tpPrice);
    }
    else
    {
        ObjectSetDouble(0, name, OBJPROP_PRICE, tpPrice);
    }
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrAccentBuy);
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
    color blendedColor = BlendColorWithBackground(clrAccentSell, ZoneOpacity);

    if (ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, entryPrice, timeRight, slPrice);
    }
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
    color blendedColor = BlendColorWithBackground(clrAccentBuy, ZoneOpacity);

    if (ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, entryPrice, timeRight, tpPrice);
    }
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
    CreateLineLabelWithBackground("EntryLabel", entryPrice, clrAccentEntry, "ENTRY");

    // SL price label with background
    CreateLineLabelWithBackground("SLLabel", slPrice, clrAccentSell, "SL");

    // TP price label with background
    CreateLineLabelWithBackground("TPLabel", tpPrice, clrAccentBuy, "TP");
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
    int rightBarIndex = firstVisibleBar - visibleBars + 1; // 1 bar from right edge (extreme right)
    if (rightBarIndex < 0) rightBarIndex = 0;
    datetime labelTime = iTime(_Symbol, PERIOD_CURRENT, rightBarIndex);

    string fullText = " " + labelText + ": " + DoubleToString(price, _Digits) + " ";

    // Fixed width for all labels (same width, center aligned)
    int textWidth = 280;
    int textHeight = FontSize + 10;

    // Get chart width and position label at the extreme right edge
    int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    int x = chartWidth - textWidth - 5; // 5 pixels padding from right edge

    // Convert price to screen Y coordinate
    int tempX, y;
    ChartTimePriceToXY(0, 0, labelTime, price, tempX, y);

    // Use OBJ_EDIT as a read-only label with proper background (best alignment)
    if (ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
    }
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
    int btnSize = 24;
    int smallBtnW = 26;
    int labelCol = 12;
    int valueCol = 80;
    int editWidth = 90;
    int rowHeight = 28;

    // Panel background
    string bgName = prefix + "PanelBg";
    ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, currentPanelX);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, currentPanelY);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrPanelBg);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, clrPanelBorder);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
    ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, bgName, OBJPROP_ZORDER, 9999);

    int y = 0;

    // === HEADER BAR ===
    CreatePanelRect("HeaderBg", 0, y, panelWidth, 28, clrHeaderBg);
    CreatePanelLabel("Title", labelCol, y + 6, "≡ " + InstanceName, clrHeaderText, FontSize + 1);

    // Theme toggle button (L=Light, D=Dark - shows what you'll switch TO)
    string themeIcon = (currentTheme == THEME_LIGHT) ? "D" : "L";
    CreatePanelButton("BtnTheme", panelWidth - 56, y + 4, 22, 20, clrHeaderBg, clrHeaderBg, clrHeaderText, themeIcon);

    // Minimize button
    CreatePanelButton("BtnMinimize", panelWidth - 30, y + 4, 22, 20, clrHeaderBg, clrHeaderBg, clrHeaderText, "—");

    y += 32;

    // === DIRECTION & DISPLAY MODE ===
    CreatePanelLabel("Direction", labelCol, y + 4, "Direction", clrTextSecondary, FontSize);
    CreatePanelButton("BtnDirection", valueCol, y, 60, btnSize, clrAccentBuy, clrAccentBuy, clrWhite, "LONG");
    CreatePanelButton("BtnToggleDisplay", panelWidth - 60, y, 48, btnSize, clrBtnBg, clrBtnBorder, clrTextPrimary, "PIPS");

    y += rowHeight + 4;

    // === PRICE SECTION ===
    CreatePanelRect("PriceSection", 6, y, panelWidth - 18, 95, clrSectionBg);

    y += 8;

    // Entry
    CreatePanelLabel("Entry", labelCol, y + 4, "Entry", clrTextSecondary, FontSize);
    CreatePanelEdit("EditEntry", valueCol, y, editWidth, btnSize, clrAccentEntry, "0.00000");
    CreatePanelButton("BtnEntryMinus", panelWidth - 76, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentEntry, clrAccentEntry, "−");
    CreatePanelButton("BtnEntryPlus", panelWidth - 48, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentEntry, clrAccentEntry, "+");

    y += rowHeight;

    // Stop Loss
    CreatePanelLabel("SL", labelCol, y + 4, "Stop Loss", clrTextSecondary, FontSize);
    CreatePanelEdit("EditSL", valueCol, y, editWidth, btnSize, clrAccentSell, "0.00000");
    CreatePanelButton("BtnSLMinus", panelWidth - 76, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentSell, clrAccentSell, "−");
    CreatePanelButton("BtnSLPlus", panelWidth - 48, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentSell, clrAccentSell, "+");

    y += rowHeight;

    // Take Profit
    CreatePanelLabel("TP", labelCol, y + 4, "Take Profit", clrTextSecondary, FontSize);
    CreatePanelEdit("EditTP", valueCol, y, editWidth, btnSize, clrAccentBuy, "0.00000");
    CreatePanelButton("BtnTPMinus", panelWidth - 76, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentBuy, clrAccentBuy, "−");
    CreatePanelButton("BtnTPPlus", panelWidth - 48, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentBuy, clrAccentBuy, "+");

    y += rowHeight + 12;

    // === RISK SECTION ===
    CreatePanelRect("RiskSection", 6, y, panelWidth - 18, 118, clrSectionBg);

    y += 8;

    // Risk %
    CreatePanelLabel("RiskPct", labelCol, y + 4, "Risk", clrTextSecondary, FontSize);
    CreatePanelEdit("EditRisk", valueCol, y, 70, btnSize, clrAccentWarning, "1.0%");
    CreatePanelButton("BtnRiskMinus", panelWidth - 76, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentWarning, clrAccentWarning, "−");
    CreatePanelButton("BtnRiskPlus", panelWidth - 48, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentWarning, clrAccentWarning, "+");

    y += rowHeight;

    // Risk $ and Reward $ on same line
    CreatePanelLabel("Risk", labelCol, y + 4, "Risk $", clrTextSecondary, FontSize);
    CreatePanelLabel("RiskVal", valueCol - 10, y + 4, "$0.00", clrAccentSell, FontSize);
    CreatePanelLabel("Reward", 135, y + 4, "Reward $", clrTextSecondary, FontSize);
    CreatePanelLabel("RewardVal", 195, y + 4, "$0.00", clrAccentBuy, FontSize);

    y += 24;

    // R:R Ratio
    CreatePanelLabel("RRRatio", labelCol, y + 4, "R:R Ratio", clrTextSecondary, FontSize);
    CreatePanelLabel("RRPrefix", valueCol, y + 4, "1 :", clrAccentGold, FontSize);
    CreatePanelEdit("EditRR", valueCol + 28, y, 48, btnSize, clrAccentGold, "2.0");
    CreatePanelButton("BtnRRMinus", panelWidth - 76, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentGold, clrAccentGold, "−");
    CreatePanelButton("BtnRRPlus", panelWidth - 48, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentGold, clrAccentGold, "+");

    y += rowHeight + 12;

    // === LOT SIZE & INFO ===
    CreatePanelRect("LotSection", 6, y, panelWidth - 18, 72, clrSectionBg);

    y += 8;

    // Lot Size
    CreatePanelLabel("Lots", labelCol, y + 4, "Lot Size", clrTextSecondary, FontSize);
    CreatePanelEdit("EditLots", valueCol, y, 70, btnSize, clrAccentGold, "0.00");
    CreatePanelButton("BtnLotsMinus", panelWidth - 76, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentGold, clrAccentGold, "−");
    CreatePanelButton("BtnLotsPlus", panelWidth - 48, y, smallBtnW, btnSize, clrBtnPlusMinus, clrAccentGold, clrAccentGold, "+");

    y += rowHeight;

    // Mode and Order Type on same line
    CreatePanelLabel("RiskMode", labelCol, y + 4, "Mode:", clrTextMuted, FontSize - 1);
    CreatePanelLabel("RiskModeVal", 50, y + 4, "% Balance", clrTextSecondary, FontSize - 1);
    CreatePanelLabel("OrderType", 130, y + 4, "Order:", clrTextMuted, FontSize - 1);
    CreatePanelLabel("OrderTypeVal", 168, y + 4, "BUY LIMIT", clrAccentBuy, FontSize - 1);

    y += rowHeight + 18;

    // === ACTION BUTTONS ===
    // Execute button
    CreatePanelButton("BtnExecute", 8, y, panelWidth - 16, 28, clrAccentBuy, clrAccentBuy, clrWhite, "BUY LIMIT");

    y += 32;

    // Market Order button
    CreatePanelButton("BtnMarketOrder", 8, y, panelWidth - 16, 28, clrAccentWarning, clrAccentWarning, clrWhite, "MARKET BUY");

    y += 32;

    // Reset button
    CreatePanelButton("BtnReset", 8, y, panelWidth - 16, 24, clrBtnBg, clrBtnBorder, clrTextSecondary, "RESET");
}

//+------------------------------------------------------------------+
//| Helper: Create a panel section rectangle                         |
//+------------------------------------------------------------------+
void CreatePanelRect(string id, int x, int y, int width, int height, color bgClr)
{
    string name = prefix + "Rect" + id;
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, currentPanelX + x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, currentPanelY + y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bgClr);
    ObjectSetInteger(0, name, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 10000);
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
    // Use larger font for +/- buttons
    int btnFontSize = (text == "+" || text == "−" || text == "-") ? FontSize + 4 : FontSize;
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, btnFontSize);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 10001);
}

//+------------------------------------------------------------------+
//| Helper: Create a panel edit field                                |
//+------------------------------------------------------------------+
void CreatePanelEdit(string id, int x, int y, int width, int height,
                     color accentClr, string text)
{
    string name = prefix + id;
    ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, currentPanelX + x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, currentPanelY + y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, name, OBJPROP_CORNER, PanelCorner);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrInputBg);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, accentClr);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrInputText);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
    ObjectSetInteger(0, name, OBJPROP_READONLY, false);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 10002);
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
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 10001);
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
    int rightBarIndex = firstVisibleBar - visibleBars + 1; // 1 bar from right edge (extreme right)
    if (rightBarIndex < 0) rightBarIndex = 0;
    datetime labelTime = iTime(_Symbol, PERIOD_CURRENT, rightBarIndex);

    double slPips = GetPipsDistance(entryPrice, slPrice);
    double tpPips = GetPipsDistance(entryPrice, tpPrice);

    // Entry label with lot size and R:R ratio
    double lots = CalculateLotSize();
    string rrStr = (currentRRRatio == MathFloor(currentRRRatio))
                   ? DoubleToString(currentRRRatio, 0)
                   : DoubleToString(currentRRRatio, 1);
    string entryText = " ENTRY: " + DoubleToString(entryPrice, _Digits) + " |  Lots: " + DoubleToString(lots, 2) + "  |  RR:" + rrStr + " ";
    UpdateLineLabel("EntryLabel", labelTime, entryPrice, entryText);

    // Calculate risk percentage (for display)
    double riskPercent;
    if (RiskMode == RISK_PERCENT_BALANCE || RiskMode == RISK_PERCENT_EQUITY)
    {
        riskPercent = currentRiskValue;
    }
    else
    {
        // Fixed cash mode - calculate percentage based on balance
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        riskPercent = (balance > 0) ? (currentRiskValue / balance) * 100.0 : 0;
    }
    double rewardPercent = riskPercent * currentRRRatio;

    // Determine decimal places for percentage display (more decimals for small values)
    int riskDecimals = (riskPercent < 0.1) ? 3 : (riskPercent < 1.0) ? 2 : 1;
    int rewardDecimals = (rewardPercent < 0.1) ? 3 : (rewardPercent < 1.0) ? 2 : 1;

    // SL label with pips and risk %
    string slText = " SL: " + DoubleToString(slPrice, _Digits) + " | " + DoubleToString(slPips, 1) + " pips | -" + DoubleToString(riskPercent, riskDecimals) + "% ";
    UpdateLineLabel("SLLabel", labelTime, slPrice, slText);

    // TP label with pips and reward %
    string tpText = " TP: " + DoubleToString(tpPrice, _Digits) + " | " + DoubleToString(tpPips, 1) + " pips | +" + DoubleToString(rewardPercent, rewardDecimals) + "% ";
    UpdateLineLabel("TPLabel", labelTime, tpPrice, tpText);
}

//+------------------------------------------------------------------+
//| Update line label position and text                              |
//+------------------------------------------------------------------+
void UpdateLineLabel(string id, datetime labelTime, double price, string text)
{
    string name = prefix + id;

    // Fixed width for all labels (fits longest text: ENTRY with lots and R:R ratio)
    int textWidth = 230;
    int textHeight = FontSize + 10;

    // Get chart width and position label at the extreme right edge
    int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    int x = chartWidth - textWidth - 5; // 5 pixels padding from right edge

    // Convert price to screen Y coordinate
    int tempX, y;
    ChartTimePriceToXY(0, 0, labelTime, price, tempX, y);

    // Update position, size, text, and ensure font consistency
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - textHeight / 2);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, textWidth);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, textHeight);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
    ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
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
    ObjectSetInteger(0, prefix + "BtnDirection", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, prefix + "BtnDirection", OBJPROP_BGCOLOR, isLong ? clrAccentBuy : clrAccentSell);
    ObjectSetInteger(0, prefix + "BtnDirection", OBJPROP_BORDER_COLOR, isLong ? clrAccentBuy : clrAccentSell);

    // Update edit fields based on display mode
    ObjectSetString(0, prefix + "EditEntry", OBJPROP_TEXT, DoubleToString(entryPrice, _Digits));

    if (priceDisplayMode == DISPLAY_ABSOLUTE_PRICE)
    {
        // Show absolute prices in edit fields
        ObjectSetString(0, prefix + "EditSL", OBJPROP_TEXT, DoubleToString(slPrice, _Digits));
        ObjectSetString(0, prefix + "EditTP", OBJPROP_TEXT, DoubleToString(tpPrice, _Digits));
        // Update labels
        ObjectSetString(0, prefix + "LblSL", OBJPROP_TEXT, "Stop Loss");
        ObjectSetString(0, prefix + "LblTP", OBJPROP_TEXT, "Take Profit");
    }
    else
    {
        // Show pips in edit fields
        ObjectSetString(0, prefix + "EditSL", OBJPROP_TEXT, DoubleToString(slPips, 1));
        ObjectSetString(0, prefix + "EditTP", OBJPROP_TEXT, DoubleToString(tpPips, 1));
        // Update labels to indicate pips mode
        ObjectSetString(0, prefix + "LblSL", OBJPROP_TEXT, "SL (pips)");
        ObjectSetString(0, prefix + "LblTP", OBJPROP_TEXT, "TP (pips)");
    }

    // Risk % value (editable field) - show more decimals for small values
    if (RiskMode == RISK_PERCENT_BALANCE || RiskMode == RISK_PERCENT_EQUITY)
    {
        int decimals = (currentRiskValue < 0.1) ? 3 : (currentRiskValue < 1.0) ? 2 : 1;
        ObjectSetString(0, prefix + "EditRisk", OBJPROP_TEXT, DoubleToString(currentRiskValue, decimals) + "%");
    }
    else
    {
        int decimals = (currentRiskValue < 1.0) ? 2 : 0;
        ObjectSetString(0, prefix + "EditRisk", OBJPROP_TEXT, "$" + DoubleToString(currentRiskValue, decimals));
    }

    // Risk/Reward in dollars
    ObjectSetString(0, prefix + "LblRiskVal", OBJPROP_TEXT, "$" + DoubleToString(riskAmt, 2));
    ObjectSetString(0, prefix + "LblRewardVal", OBJPROP_TEXT, "$" + DoubleToString(rewardAmt, 2));
    // Update R:R ratio edit field
    ObjectSetString(0, prefix + "EditRR", OBJPROP_TEXT, DoubleToString(currentRRRatio, 1));

    // Lot size (editable field)
    ObjectSetString(0, prefix + "EditLots", OBJPROP_TEXT, DoubleToString(lots, 2));

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
    color orderTypeColor = isLong ? clrAccentBuy : clrAccentSell;
    ObjectSetInteger(0, prefix + "LblOrderTypeVal", OBJPROP_COLOR, orderTypeColor);

    // Update execute button color and text based on direction and order type
    // BUY LIMIT/STOP = Light green, SELL LIMIT/STOP = Orange
    ObjectSetInteger(0, prefix + "BtnExecute", OBJPROP_BGCOLOR, isLong ? clrAccentBuyLight : clrAccentWarning);
    ObjectSetInteger(0, prefix + "BtnExecute", OBJPROP_BORDER_COLOR, isLong ? clrAccentBuyLight : clrAccentWarning);
    ObjectSetString(0, prefix + "BtnExecute", OBJPROP_TEXT, orderTypeStr);

    // Update market order button color based on direction
    // MARKET BUY = Green, MARKET SELL = Red
    ObjectSetInteger(0, prefix + "BtnMarketOrder", OBJPROP_BGCOLOR, isLong ? clrAccentBuy : clrAccentSell);
    ObjectSetInteger(0, prefix + "BtnMarketOrder", OBJPROP_BORDER_COLOR, isLong ? clrAccentBuy : clrAccentSell);
    ObjectSetString(0, prefix + "BtnMarketOrder", OBJPROP_TEXT, isLong ? "MARKET BUY" : "MARKET SELL");
}

//+------------------------------------------------------------------+
//| Update panel except lot size (used when manually adjusting lots) |
//+------------------------------------------------------------------+
void UpdatePanelExceptLots()
{
    bool isLong = IsLongPosition();
    double riskAmt = GetRiskAmount();
    double rewardAmt = CalculateRewardAmount();
    double slPips = GetPipsDistance(entryPrice, slPrice);
    double tpPips = GetPipsDistance(entryPrice, tpPrice);

    // Direction button
    ObjectSetString(0, prefix + "BtnDirection", OBJPROP_TEXT, isLong ? "LONG" : "SHORT");
    ObjectSetInteger(0, prefix + "BtnDirection", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, prefix + "BtnDirection", OBJPROP_BGCOLOR, isLong ? clrAccentBuy : clrAccentSell);
    ObjectSetInteger(0, prefix + "BtnDirection", OBJPROP_BORDER_COLOR, isLong ? clrAccentBuy : clrAccentSell);

    // Update edit fields based on display mode
    ObjectSetString(0, prefix + "EditEntry", OBJPROP_TEXT, DoubleToString(entryPrice, _Digits));

    if (priceDisplayMode == DISPLAY_ABSOLUTE_PRICE)
    {
        ObjectSetString(0, prefix + "EditSL", OBJPROP_TEXT, DoubleToString(slPrice, _Digits));
        ObjectSetString(0, prefix + "EditTP", OBJPROP_TEXT, DoubleToString(tpPrice, _Digits));
        ObjectSetString(0, prefix + "LblSL", OBJPROP_TEXT, "Stop Loss");
        ObjectSetString(0, prefix + "LblTP", OBJPROP_TEXT, "Take Profit");
    }
    else
    {
        ObjectSetString(0, prefix + "EditSL", OBJPROP_TEXT, DoubleToString(slPips, 1));
        ObjectSetString(0, prefix + "EditTP", OBJPROP_TEXT, DoubleToString(tpPips, 1));
        ObjectSetString(0, prefix + "LblSL", OBJPROP_TEXT, "SL (pips)");
        ObjectSetString(0, prefix + "LblTP", OBJPROP_TEXT, "TP (pips)");
    }

    // Risk % value - show more decimals for small values
    if (RiskMode == RISK_PERCENT_BALANCE || RiskMode == RISK_PERCENT_EQUITY)
    {
        int decimals = (currentRiskValue < 0.1) ? 3 : (currentRiskValue < 1.0) ? 2 : 1;
        ObjectSetString(0, prefix + "EditRisk", OBJPROP_TEXT, DoubleToString(currentRiskValue, decimals) + "%");
    }
    else
    {
        int decimals = (currentRiskValue < 1.0) ? 2 : 0;
        ObjectSetString(0, prefix + "EditRisk", OBJPROP_TEXT, "$" + DoubleToString(currentRiskValue, decimals));
    }

    // Risk/Reward in dollars
    ObjectSetString(0, prefix + "LblRiskVal", OBJPROP_TEXT, "$" + DoubleToString(riskAmt, 2));
    ObjectSetString(0, prefix + "LblRewardVal", OBJPROP_TEXT, "$" + DoubleToString(rewardAmt, 2));
    ObjectSetString(0, prefix + "EditRR", OBJPROP_TEXT, DoubleToString(currentRRRatio, 1));

    // NOTE: Lot size field is NOT updated here - preserves manually entered value

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

    color orderTypeColor = isLong ? clrAccentBuy : clrAccentSell;
    ObjectSetInteger(0, prefix + "LblOrderTypeVal", OBJPROP_COLOR, orderTypeColor);

    // Update buttons
    // BUY LIMIT/STOP = Light green, SELL LIMIT/STOP = Orange
    ObjectSetInteger(0, prefix + "BtnExecute", OBJPROP_BGCOLOR, isLong ? clrAccentBuyLight : clrAccentWarning);
    ObjectSetInteger(0, prefix + "BtnExecute", OBJPROP_BORDER_COLOR, isLong ? clrAccentBuyLight : clrAccentWarning);
    ObjectSetString(0, prefix + "BtnExecute", OBJPROP_TEXT, orderTypeStr);

    // MARKET BUY = Green, MARKET SELL = Red
    ObjectSetInteger(0, prefix + "BtnMarketOrder", OBJPROP_BGCOLOR, isLong ? clrAccentBuy : clrAccentSell);
    ObjectSetInteger(0, prefix + "BtnMarketOrder", OBJPROP_BORDER_COLOR, isLong ? clrAccentBuy : clrAccentSell);
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
//| Calculate risk value from lot size (back-calculation)            |
//+------------------------------------------------------------------+
void CalculateRiskFromLots(double lots)
{
    double slDistance = MathAbs(entryPrice - slPrice);

    if (slDistance == 0 || lots <= 0)
        return;

    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if (tickValue == 0 || tickSize == 0)
        return;

    // Calculate risk amount in dollars: riskAmount = lots * (slDistance / tickSize) * tickValue
    double riskAmount = lots * (slDistance / tickSize) * tickValue;

    // Convert to risk value based on current mode
    // No minimum constraint here - allow any value based on lot size
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    switch (RiskMode)
    {
    case RISK_FIXED_CASH_BALANCE:
    case RISK_FIXED_CASH_EQUITY:
        // Fixed cash mode - risk value is the dollar amount (no minimum)
        currentRiskValue = MathMax(0.01, riskAmount);
        break;
    case RISK_PERCENT_BALANCE:
        // Percent of balance mode (no minimum, max 100%)
        if (balance > 0)
            currentRiskValue = MathMax(0.001, MathMin(100.0, (riskAmount / balance) * 100.0));
        break;
    case RISK_PERCENT_EQUITY:
        // Percent of equity mode (no minimum, max 100%)
        if (equity > 0)
            currentRiskValue = MathMax(0.001, MathMin(100.0, (riskAmount / equity) * 100.0));
        break;
    }

    // Save to GlobalVariable (persists across timeframe changes)
    GlobalVariableSet(prefix + "RiskValue", currentRiskValue);
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

    // Reset risk value to default from inputs
    currentRiskValue = RiskValue;
    GlobalVariableSet(prefix + "RiskValue", currentRiskValue);

    // Reset R:R ratio to default value from inputs
    currentRRRatio = DefaultRRRatio;
    GlobalVariableSet(prefix + "RRRatio", currentRRRatio);

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

    // Recreate lines (handles both creation and property updates)
    CreateEntryLine();
    CreateSLLine();
    CreateTPLine();

    // Recreate zones and labels
    CreateRiskZone();
    CreateRewardZone();
    CreatePriceLabels();

    SaveLinePrices(); // Persist across timeframe changes
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
    // Note: RectHeaderBg is NOT included - it should always be visible
    string panelObjectsToToggle[] = {
        "RectPriceSection", "RectRiskSection", "RectLotSection",
        "LblDirection", "BtnDirection",
        "BtnToggleDisplay",
        "LblEntry", "EditEntry",
        "BtnEntryMinus", "BtnEntryPlus",
        "LblSL", "EditSL",
        "BtnSLMinus", "BtnSLPlus",
        "LblTP", "EditTP",
        "BtnTPMinus", "BtnTPPlus",
        "LblRiskPct", "EditRisk",
        "BtnRiskMinus", "BtnRiskPlus",
        "LblRisk", "LblRiskVal",
        "LblReward", "LblRewardVal",
        "LblRRRatio", "LblRRPrefix", "EditRR",
        "BtnRRMinus", "BtnRRPlus",
        "LblLots", "EditLots", "BtnLotsMinus", "BtnLotsPlus",
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
        ObjectSetString(0, prefix + "BtnMinimize", OBJPROP_TEXT, "□");

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
        // First recreate chart objects (lines, zones, labels) - these go behind panel
        CreateEntryLine();
        CreateSLLine();
        CreateTPLine();
        CreateRiskZone();
        CreateRewardZone();
        CreatePriceLabels();

        // Delete ALL panel objects to force them to be recreated on top
        // This includes all objects in panelObjectsToToggle plus header objects
        ObjectDelete(0, prefix + "PanelBg");
        ObjectDelete(0, prefix + "RectHeaderBg");
        ObjectDelete(0, prefix + "LblTitle");
        ObjectDelete(0, prefix + "BtnMinimize");
        ObjectDelete(0, prefix + "BtnTheme");
        for (int j = 0; j < numPanelObjects; j++)
        {
            ObjectDelete(0, prefix + panelObjectsToToggle[j]);
        }

        // Recreate entire panel - this puts all panel objects on top of lines
        CreatePanel();

        // Update positions and redraw
        RedrawZones();
        RedrawLabels();
        UpdatePanel();
        ChartRedraw();
    }
}
//+------------------------------------------------------------------+
