//+------------------------------------------------------------------+
//|                                              TimezoneOverlay.mq5 |
//|                                                          AbidTrd |
//|                    Displays local/custom timezone on chart x-axis |
//+------------------------------------------------------------------+
#property copyright "AbidTrd"
#property link ""
#property version "2.00"
#property indicator_chart_window
#property indicator_plots 0

// Timezone mode enum
enum ENUM_TZ_MODE
{
   TZ_LOCAL,      // Local Computer Time
   TZ_CUSTOM      // Custom UTC Offset
};

// Date format enum
enum ENUM_DATE_FORMAT
{
   DATE_DD_MMM_YYYY,     // 03 Feb 2025
   DATE_MMM_DD_YYYY,     // Feb 03, 2025
   DATE_DD_MM_YYYY,      // 03/02/2025
   DATE_MM_DD_YYYY,      // 02/03/2025
   DATE_YYYY_MM_DD,      // 2025-02-03
   DATE_DD_MMM,          // 03 Feb (no year)
   DATE_MMM_DD           // Feb 03 (no year)
};

// Time format enum
enum ENUM_TIME_FORMAT
{
   TIME_24H,             // 24-hour (14:30)
   TIME_12H              // 12-hour (2:30 PM)
};

// Input Parameters
input group "=== Timezone Settings ==="
input ENUM_TZ_MODE TimezoneMode = TZ_LOCAL;        // Timezone Mode
input double CustomUTCOffset = 0;                   // Custom UTC Offset (hours, e.g., 10.5 for UTC+10:30)

input group "=== Time Strip Appearance ==="
input color PanelColor = clrBlack;                  // Panel Background Color
input int PanelHeight = 20;                         // Panel Height (pixels)
input color TextColor = clrWhite;                   // Time Label Color
input int FontSize = 10;                             // Font Size
input string FontName = "Arial";                    // Font Name
input bool ShowTimezoneLabel = true;                // Show Timezone Indicator

input group "=== Crosshair Popup ==="
input bool EnableCrosshairPopup = true;             // Enable Crosshair Time Popup
input color PopupBgColor = C'40,40,40';             // Popup Background Color
input color PopupTextColor = clrWhite;              // Popup Text Color
input int PopupFontSize = 10;                       // Popup Font Size
input bool ShowDayName = true;                      // Show Day Name (Mon, Tue, etc.)
input ENUM_DATE_FORMAT DateFormat = DATE_DD_MMM_YYYY;  // Date Format
input ENUM_TIME_FORMAT TimeFormat = TIME_24H;          // Time Format (24h/12h)

input group "=== Persistent Crosshair ==="
input bool EnableCrosshair = true;                  // Enable Persistent Crosshair
input color CrosshairColor = clrGray;               // Crosshair Line Color
input ENUM_LINE_STYLE CrosshairStyle = STYLE_DOT;   // Crosshair Line Style
input bool ShowPriceLabel = true;                   // Show Price Label on Y-axis
input color PriceLabelBgColor = C'40,40,40';        // Price Label Background
input color PriceLabelTextColor = clrWhite;         // Price Label Text Color

// Globals
string prefix = "TZOverlay_";
int chartHeight, chartWidth;
double serverToLocalOffset = 0;  // Offset in seconds from server time to display time
bool mouseOnChart = false;
int lastMouseX = -1;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Calculate timezone offset
   CalculateTimezoneOffset();

   // Get initial chart dimensions
   chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   // Enable chart events for mouse tracking
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

   // Initial draw
   DrawTimezoneOverlay();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up all objects
   ObjectsDeleteAll(0, prefix);
}

//+------------------------------------------------------------------+
//| Calculate timezone offset from server time                        |
//+------------------------------------------------------------------+
void CalculateTimezoneOffset()
{
   if (TimezoneMode == TZ_LOCAL)
   {
      // Calculate offset between server time and local time
      // Use GMT as a common reference to avoid timing discrepancies
      datetime gmtTime = TimeGMT();
      datetime localTime = TimeLocal();
      double localToGMTOffset = (double)(localTime - gmtTime);

      // Get server's offset from GMT
      datetime serverTime = TimeCurrent();
      double serverToGMTOffset = (double)(serverTime - gmtTime);

      // Round both offsets to nearest minute to avoid second-level discrepancies
      localToGMTOffset = MathRound(localToGMTOffset / 60.0) * 60.0;
      serverToGMTOffset = MathRound(serverToGMTOffset / 60.0) * 60.0;

      // Server to local = local's GMT offset - server's GMT offset
      serverToLocalOffset = localToGMTOffset - serverToGMTOffset;
   }
   else
   {
      // Custom UTC offset
      // First, find server's UTC offset by comparing server time to GMT
      datetime serverTime = TimeCurrent();
      datetime gmtTime = TimeGMT();
      double serverUTCOffset = (double)(serverTime - gmtTime);

      // Round to nearest minute
      serverUTCOffset = MathRound(serverUTCOffset / 60.0) * 60.0;

      // Calculate offset to apply: target UTC offset - server UTC offset
      serverToLocalOffset = (CustomUTCOffset * 3600) - serverUTCOffset;
   }
}

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (id == CHARTEVENT_CHART_CHANGE)
   {
      // Update dimensions
      chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

      // Recalculate offset (in case of reconnection or time sync)
      CalculateTimezoneOffset();

      // Redraw overlay
      DrawTimezoneOverlay();
   }
   else if (id == CHARTEVENT_MOUSE_MOVE)
   {
      int mouseX = (int)lparam;
      int mouseY = (int)dparam;

      // Check if mouse is within chart bounds
      if (mouseX >= 0 && mouseX < chartWidth && mouseY >= 0 && mouseY < chartHeight)
      {
         mouseOnChart = true;
         lastMouseX = mouseX;

         // Update crosshair popup (time label)
         if (EnableCrosshairPopup)
            UpdateCrosshairPopup(mouseX, mouseY);

         // Update persistent crosshair lines
         if (EnableCrosshair)
            UpdateCrosshairLines(mouseX, mouseY);
      }
      else
      {
         // Mouse left the chart area
         if (mouseOnChart)
         {
            mouseOnChart = false;
            if (EnableCrosshairPopup)
               HideCrosshairPopup();
            if (EnableCrosshair)
               HideCrosshairLines();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Main calculation function                                         |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   return rates_total;
}

//+------------------------------------------------------------------+
//| Update crosshair popup with time at cursor position               |
//+------------------------------------------------------------------+
void UpdateCrosshairPopup(int mouseX, int mouseY)
{
   // Convert mouse position to chart time
   datetime chartTime;
   double chartPrice;
   int subWindow;

   if (!ChartXYToTimePrice(0, mouseX, mouseY, subWindow, chartTime, chartPrice))
   {
      HideCrosshairPopup();
      return;
   }

   // Only show in main chart window
   if (subWindow != 0)
   {
      HideCrosshairPopup();
      return;
   }

   // Snap to bar open time (same as crosshair vertical line)
   int barIndex = iBarShift(_Symbol, PERIOD_CURRENT, chartTime);
   datetime barOpenTime = iTime(_Symbol, PERIOD_CURRENT, barIndex);

   // Convert the snapped bar time back to screen X coordinate
   // This aligns the popup with the crosshair vertical line (which snaps to bar times)
   int snappedX, tempY;
   if (!ChartTimePriceToXY(0, 0, barOpenTime, chartPrice, snappedX, tempY))
   {
      snappedX = mouseX;  // Fallback to mouse position if conversion fails
   }

   // Apply timezone offset to the snapped bar time
   datetime displayTime = barOpenTime + (int)serverToLocalOffset;

   // Format the full date/time string
   string timeText = FormatCrosshairTime(displayTime);

   // Calculate popup dimensions
   int popupWidth = CalculateTextWidth(timeText) + 16;
   int popupHeight = PopupFontSize + 12;

   // Position popup at bottom of chart, centered on snapped X (aligned with crosshair)
   int panelY = chartHeight - PanelHeight - 5;
   int popupX = snappedX - popupWidth / 2;
   int popupY = panelY - popupHeight - 2;

   // Keep popup within chart bounds
   if (popupX < 5) popupX = 5;
   if (popupX + popupWidth > chartWidth - 5) popupX = chartWidth - popupWidth - 5;

   // Create/update popup background
   string bgName = prefix + "PopupBg";
   if (ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, popupX);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, popupY);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, popupWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, popupHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, PopupBgColor);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, PopupTextColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);

   // Create/update popup text
   string textName = prefix + "PopupText";
   if (ObjectFind(0, textName) < 0)
      ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, popupX + popupWidth / 2);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, popupY + 3);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, PopupTextColor);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, PopupFontSize);
   ObjectSetString(0, textName, OBJPROP_FONT, FontName);
   ObjectSetString(0, textName, OBJPROP_TEXT, timeText);
   ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_UPPER);
   ObjectSetInteger(0, textName, OBJPROP_BACK, false);
   ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Hide crosshair popup                                              |
//+------------------------------------------------------------------+
void HideCrosshairPopup()
{
   ObjectDelete(0, prefix + "PopupBg");
   ObjectDelete(0, prefix + "PopupText");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update persistent crosshair lines                                 |
//+------------------------------------------------------------------+
void UpdateCrosshairLines(int mouseX, int mouseY)
{
   // Convert mouse position to chart time/price
   datetime chartTime;
   double chartPrice;
   int subWindow;

   if (!ChartXYToTimePrice(0, mouseX, mouseY, subWindow, chartTime, chartPrice))
   {
      HideCrosshairLines();
      return;
   }

   // Only show in main chart window
   if (subWindow != 0)
   {
      HideCrosshairLines();
      return;
   }

   // Get price range for vertical line endpoints
   double priceMin = ChartGetDouble(0, CHART_PRICE_MIN);
   double priceMax = ChartGetDouble(0, CHART_PRICE_MAX);

   // Create/update vertical line using trendline (supports dashed style)
   string vLineName = prefix + "CrosshairV";
   if (ObjectFind(0, vLineName) < 0)
      ObjectCreate(0, vLineName, OBJ_TREND, 0, chartTime, priceMin, chartTime, priceMax);

   ObjectSetInteger(0, vLineName, OBJPROP_TIME, 0, chartTime);
   ObjectSetDouble(0, vLineName, OBJPROP_PRICE, 0, priceMin);
   ObjectSetInteger(0, vLineName, OBJPROP_TIME, 1, chartTime);
   ObjectSetDouble(0, vLineName, OBJPROP_PRICE, 1, priceMax);
   ObjectSetInteger(0, vLineName, OBJPROP_COLOR, CrosshairColor);
   ObjectSetInteger(0, vLineName, OBJPROP_STYLE, CrosshairStyle);
   ObjectSetInteger(0, vLineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, vLineName, OBJPROP_BACK, true);
   ObjectSetInteger(0, vLineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, vLineName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, vLineName, OBJPROP_RAY_LEFT, true);
   ObjectSetInteger(0, vLineName, OBJPROP_RAY_RIGHT, true);
   ObjectSetString(0, vLineName, OBJPROP_TOOLTIP, "\n");

   // Create/update horizontal line (supports dashed style)
   string hLineName = prefix + "CrosshairH";
   if (ObjectFind(0, hLineName) < 0)
      ObjectCreate(0, hLineName, OBJ_HLINE, 0, 0, chartPrice);

   ObjectSetDouble(0, hLineName, OBJPROP_PRICE, chartPrice);
   ObjectSetInteger(0, hLineName, OBJPROP_COLOR, CrosshairColor);
   ObjectSetInteger(0, hLineName, OBJPROP_STYLE, CrosshairStyle);
   ObjectSetInteger(0, hLineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, hLineName, OBJPROP_BACK, true);
   ObjectSetInteger(0, hLineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, hLineName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, hLineName, OBJPROP_TOOLTIP, "\n");

   // Create/update price label on the right side
   if (ShowPriceLabel)
   {
      UpdatePriceLabel(mouseY, chartPrice);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update price label on Y-axis                                      |
//+------------------------------------------------------------------+
void UpdatePriceLabel(int mouseY, double price)
{
   string bgName = prefix + "PriceLabelBg";
   string textName = prefix + "PriceLabelText";

   // Format price with correct digits
   string priceText = DoubleToString(price, _Digits);

   // Calculate label dimensions
   int labelWidth = (int)(StringLen(priceText) * 8) + 12;
   int labelHeight = 20;

   // Position on right edge of chart area
   int labelX = chartWidth - labelWidth - 2;
   int labelY = mouseY - labelHeight / 2;

   // Keep within bounds
   if (labelY < 0) labelY = 0;
   if (labelY + labelHeight > chartHeight) labelY = chartHeight - labelHeight;

   // Create/update background
   if (ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, labelY);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, labelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, labelHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, PriceLabelBgColor);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, PriceLabelTextColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, bgName, OBJPROP_TOOLTIP, "\n");

   // Create/update text
   if (ObjectFind(0, textName) < 0)
      ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, labelX + labelWidth / 2);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, labelY + 3);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, PriceLabelTextColor);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, textName, OBJPROP_FONT, FontName);
   ObjectSetString(0, textName, OBJPROP_TEXT, priceText);
   ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_UPPER);
   ObjectSetInteger(0, textName, OBJPROP_BACK, true);
   ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, textName, OBJPROP_TOOLTIP, "\n");
}

//+------------------------------------------------------------------+
//| Hide persistent crosshair lines                                   |
//+------------------------------------------------------------------+
void HideCrosshairLines()
{
   ObjectDelete(0, prefix + "CrosshairV");
   ObjectDelete(0, prefix + "CrosshairH");
   ObjectDelete(0, prefix + "PriceLabelBg");
   ObjectDelete(0, prefix + "PriceLabelText");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Format time for crosshair popup (full date/time with day name)    |
//+------------------------------------------------------------------+
string FormatCrosshairTime(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);

   string dayNames[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
   string monthNames[] = {"", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

   string result = "";

   // Add day name if enabled
   if (ShowDayName)
   {
      result = dayNames[dt.day_of_week] + " ";
   }

   // Format date based on selected format
   string datePart = FormatDatePart(dt, monthNames);
   result += datePart;

   // Add separator
   result += "  ";

   // Format time based on selected format
   string timePart = FormatTimePart(dt);
   result += timePart;

   return result;
}

//+------------------------------------------------------------------+
//| Format date part based on selected format                         |
//+------------------------------------------------------------------+
string FormatDatePart(MqlDateTime &dt, string &monthNames[])
{
   int shortYear = dt.year % 100;  // 2-digit year

   switch (DateFormat)
   {
      case DATE_DD_MMM_YYYY:
         return StringFormat("%d %s %02d", dt.day, monthNames[dt.mon], shortYear);

      case DATE_MMM_DD_YYYY:
         return StringFormat("%s %d, %02d", monthNames[dt.mon], dt.day, shortYear);

      case DATE_DD_MM_YYYY:
         return StringFormat("%d/%02d/%02d", dt.day, dt.mon, shortYear);

      case DATE_MM_DD_YYYY:
         return StringFormat("%02d/%d/%02d", dt.mon, dt.day, shortYear);

      case DATE_YYYY_MM_DD:
         return StringFormat("%02d-%02d-%d", shortYear, dt.mon, dt.day);

      case DATE_DD_MMM:
         return StringFormat("%d %s", dt.day, monthNames[dt.mon]);

      case DATE_MMM_DD:
         return StringFormat("%s %d", monthNames[dt.mon], dt.day);

      default:
         return StringFormat("%d %s %02d", dt.day, monthNames[dt.mon], shortYear);
   }
}

//+------------------------------------------------------------------+
//| Format time part based on selected format (24h or 12h)            |
//+------------------------------------------------------------------+
string FormatTimePart(MqlDateTime &dt)
{
   if (TimeFormat == TIME_24H)
   {
      return StringFormat("%02d:%02d", dt.hour, dt.min);
   }
   else // TIME_12H
   {
      int hour12 = dt.hour % 12;
      if (hour12 == 0) hour12 = 12;  // 0 and 12 should display as 12
      string ampm = (dt.hour < 12) ? "AM" : "PM";
      return StringFormat("%d:%02d %s", hour12, dt.min, ampm);
   }
}

//+------------------------------------------------------------------+
//| Calculate approximate text width in pixels                        |
//+------------------------------------------------------------------+
int CalculateTextWidth(string text)
{
   // Approximate width based on font size and character count
   // Average character width is roughly 0.6 * font size for proportional fonts
   int charCount = StringLen(text);
   return (int)(charCount * PopupFontSize * 0.6);
}

//+------------------------------------------------------------------+
//| Draw the timezone overlay                                         |
//+------------------------------------------------------------------+
void DrawTimezoneOverlay()
{
   // Clean up old labels (keep panel and popup objects)
   int totalObjects = ObjectsTotal(0, 0, OBJ_LABEL);
   for (int i = totalObjects - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, OBJ_LABEL);
      if (StringFind(objName, prefix + "Label") == 0)
         ObjectDelete(0, objName);
   }

   // Get visible bar information
   int firstVisibleBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int lastVisibleBar = firstVisibleBar - visibleBars + 1;
   if (lastVisibleBar < 0) lastVisibleBar = 0;

   // Calculate panel Y position (above native x-axis)
   // The native x-axis is typically at the bottom, we place our panel above it
   int panelY = chartHeight - PanelHeight - 5;  // 5 pixels for native x-axis area

   // Create background panel
   CreatePanel(panelY);

   // Determine label interval based on visible bars and chart width
   int labelInterval = CalculateLabelInterval(visibleBars);

   // Get period duration in seconds for calculating future times
   int periodSeconds = PeriodSeconds(PERIOD_CURRENT);

   // Get the latest bar time as reference for future calculations
   datetime latestBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);

   // Calculate right margin to avoid overlapping with timezone indicator
   // "LOCAL (UTC+10.0)" is about 17 chars, estimate width based on font size
   int tzIndicatorWidth = ShowTimezoneLabel ? (int)(20 * FontSize * 0.6) + 30 : 50;
   int rightMargin = tzIndicatorWidth + 20;

   // Create time labels using bar 0 as anchor point
   int labelCount = 0;
   int maxLabels = 20;  // Limit number of labels for performance
   double priceRef = iClose(_Symbol, PERIOD_CURRENT, 0);

   // First, draw current bar (bar 0) if visible - this is the anchor
   int bar0X, bar0Y;
   bool bar0Visible = false;
   if (ChartTimePriceToXY(0, 0, latestBarTime, priceRef, bar0X, bar0Y))
   {
      if (bar0X >= 50 && bar0X <= chartWidth - rightMargin)
      {
         datetime displayTime = latestBarTime + (int)serverToLocalOffset;
         string timeStr = FormatTimeLabel(displayTime);
         CreateTimeLabel(labelCount, bar0X, panelY, timeStr);
         labelCount++;
         bar0Visible = true;
      }
   }

   // Draw labels for historic bars (going back from bar 0 at intervals)
   for (int i = labelInterval; labelCount < maxLabels; i += labelInterval)
   {
      if (i > firstVisibleBar) break;  // Beyond visible range

      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, i);
      if (barTime == 0) continue;

      // Convert bar position to screen X coordinate
      int barX, barY;
      if (!ChartTimePriceToXY(0, 0, barTime, priceRef, barX, barY))
         continue;

      // Skip if too close to edges
      if (barX < 50 || barX > chartWidth - rightMargin)
         continue;

      // Calculate display time (server time + offset)
      datetime displayTime = barTime + (int)serverToLocalOffset;

      // Format time string based on timeframe
      string timeStr = FormatTimeLabel(displayTime);

      // Create label
      CreateTimeLabel(labelCount, barX, panelY, timeStr);
      labelCount++;
   }

   // Draw labels for future times (going forward from bar 0 at intervals)
   for (int futureBar = labelInterval; labelCount < maxLabels; futureBar += labelInterval)
   {
      datetime futureTime = latestBarTime + (futureBar * periodSeconds);

      // Convert future time to screen X coordinate
      int futureX, futureY;
      if (!ChartTimePriceToXY(0, 0, futureTime, priceRef, futureX, futureY))
         break;  // Can't convert, probably too far in future

      // Stop if we're past the right edge (accounting for timezone indicator)
      if (futureX > chartWidth - rightMargin)
         break;

      // Skip if too close to left edge
      if (futureX < 50)
         continue;

      // Calculate display time (server time + offset)
      datetime displayTime = futureTime + (int)serverToLocalOffset;

      // Format time string based on timeframe
      string timeStr = FormatTimeLabel(displayTime);

      // Create label
      CreateTimeLabel(labelCount, futureX, panelY, timeStr);
      labelCount++;
   }

   // Add timezone indicator label
   if (ShowTimezoneLabel)
   {
      CreateTimezoneIndicator(panelY);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Calculate appropriate label interval based on visible bars        |
//+------------------------------------------------------------------+
int CalculateLabelInterval(int visibleBars)
{
   // Aim for approximately 8-12 labels across the chart
   int targetLabels = 10;
   int interval = visibleBars / targetLabels;

   // Ensure minimum interval
   if (interval < 1) interval = 1;

   // Round to nice numbers for cleaner appearance
   if (interval > 100) interval = (interval / 50) * 50;
   else if (interval > 20) interval = (interval / 10) * 10;
   else if (interval > 5) interval = (interval / 5) * 5;

   return interval;
}

//+------------------------------------------------------------------+
//| Format time label based on timeframe                              |
//+------------------------------------------------------------------+
string FormatTimeLabel(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);

   ENUM_TIMEFRAMES tf = Period();

   // For daily and above, show date
   if (tf >= PERIOD_D1)
   {
      return StringFormat("%02d/%02d", dt.day, dt.mon);
   }
   // For H4 and above, show date and time
   else if (tf >= PERIOD_H4)
   {
      return StringFormat("%02d/%02d %02d:%02d", dt.day, dt.mon, dt.hour, dt.min);
   }
   // For smaller timeframes, show time only
   else
   {
      return StringFormat("%02d:%02d", dt.hour, dt.min);
   }
}

//+------------------------------------------------------------------+
//| Create background panel                                           |
//+------------------------------------------------------------------+
void CreatePanel(int panelY)
{
   string name = prefix + "Panel";

   if (ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 0);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, chartWidth);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, PanelHeight);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, PanelColor);
   ObjectSetInteger(0, name, OBJPROP_COLOR, PanelColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Create a time label at specified position                         |
//+------------------------------------------------------------------+
void CreateTimeLabel(int index, int x, int panelY, string text)
{
   string name = prefix + "Label" + IntegerToString(index);

   if (ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, panelY + (PanelHeight - FontSize) / 2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, TextColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, FontName);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Create timezone indicator label (e.g., "UTC+10" or "LOCAL")       |
//+------------------------------------------------------------------+
void CreateTimezoneIndicator(int panelY)
{
   string name = prefix + "TZIndicator";
   string tzText;

   if (TimezoneMode == TZ_LOCAL)
   {
      // Calculate and display the effective UTC offset
      double offsetHours = serverToLocalOffset / 3600.0;

      // Get server UTC offset for reference
      datetime serverTime = TimeCurrent();
      datetime gmtTime = TimeGMT();
      double serverUTCOffset = (double)(serverTime - gmtTime) / 3600.0;
      double localUTCOffset = serverUTCOffset + offsetHours;

      if (localUTCOffset >= 0)
         tzText = StringFormat("LOCAL (UTC+%.1f)", localUTCOffset);
      else
         tzText = StringFormat("LOCAL (UTC%.1f)", localUTCOffset);
   }
   else
   {
      if (CustomUTCOffset >= 0)
         tzText = StringFormat("UTC+%.1f", CustomUTCOffset);
      else
         tzText = StringFormat("UTC%.1f", CustomUTCOffset);
   }

   if (ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, panelY + (PanelHeight - FontSize) / 2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, TextColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, FontName);
   ObjectSetString(0, name, OBJPROP_TEXT, tzText);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
//+------------------------------------------------------------------+
