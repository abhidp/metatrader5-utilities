//+------------------------------------------------------------------+
//|                                                    Watermark.mq5 |
//+------------------------------------------------------------------+
#property copyright "AbidTrd"
#property link ""
#property version "2.00"
#property indicator_chart_window
#property indicator_plots 0

// Enums
enum ENUM_ROW_CONTENT
{
   ROW_TICKER,      // Ticker
   ROW_TIMEFRAME,   // Timeframe
   ROW_EXCHANGE,    // Broker/Exchange
   ROW_COUNTDOWN,   // Candle Timer
   ROW_CUSTOM,      // Custom Text
   ROW_EMPTY        // Empty
};

enum ENUM_TF_STYLE
{
   TF_TRADINGVIEW,  // TradingView (1m, 15m, 1H)
   TF_METATRADER    // MetaTrader (M1, M15, H1)
};

enum ENUM_V_POSITION
{
   V_TOP,           // Top
   V_MIDDLE,        // Middle
   V_BOTTOM         // Bottom
};

enum ENUM_H_POSITION
{
   H_LEFT,          // Left
   H_CENTER,        // Center
   H_RIGHT          // Right
};

enum ENUM_TEXT_ALIGN
{
   TEXT_LEFT,       // Left
   TEXT_CENTER,     // Center
   TEXT_RIGHT       // Right
};

// Input Parameters - Style
input group "=== Watermark Style ===";
input int FontSize = 30;                          // Font Size
input string FontName = "Arial";                  // Font Family
input color TextColor = clrGray;                  // Text Color
input int Transparency = 70;                      // Transparency (0-100)
input bool IsBold = false;                        // Bold
input bool IsItalic = false;                      // Italic

// Input Parameters - Position
input group "=== Position ===";
input ENUM_V_POSITION VerticalPos = V_TOP;        // Vertical Position
input ENUM_H_POSITION HorizontalPos = H_RIGHT;   // Horizontal Position
input ENUM_TEXT_ALIGN TextAlignment = TEXT_CENTER; // Text Alignment
input int MarginX = 120;                           // Margin X (px)
input int MarginY = 30;                           // Margin Y (px)

// Input Parameters - Content
input group "=== Row Content ===";
input ENUM_ROW_CONTENT Row1Content = ROW_TICKER;     // Row 1
input ENUM_ROW_CONTENT Row2Content = ROW_TIMEFRAME;  // Row 2
input ENUM_ROW_CONTENT Row3Content = ROW_COUNTDOWN;  // Row 3
input ENUM_ROW_CONTENT Row4Content = ROW_EMPTY;      // Row 4

// Input Parameters - Row Font Sizes
input group "=== Row Font Sizes (0 = inherit) ===";
input int Row1FontSize = 0;                       // Row 1 Font Size
input int Row2FontSize = 0;                       // Row 2 Font Size
input int Row3FontSize = 15;                      // Row 3 Font Size
input int Row4FontSize = 0;                       // Row 4 Font Size

// Input Parameters - Options
input group "=== Options ===";
input ENUM_TF_STYLE TimeframeStyle = TF_TRADINGVIEW; // Timeframe Style
input string CustomText = "custom text";          // Custom Text

// Global variables
string indicatorName = "Watermark";
string objPrefix;
int chartWidth, chartHeight;

//+------------------------------------------------------------------+
int OnInit()
{
   objPrefix = indicatorName + "_" + string(_Symbol) + "_";

   // Enable timer for countdown updates (1 second interval)
   EventSetMillisecondTimer(1000);

   // Get initial chart dimensions
   chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   CreateWatermark();
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, objPrefix);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   // Update countdown rows
   UpdateCountdownRows();
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      int newWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      int newHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

      if(newWidth != chartWidth || newHeight != chartHeight)
      {
         chartWidth = newWidth;
         chartHeight = newHeight;
         UpdatePositions();
      }
   }
}

//+------------------------------------------------------------------+
string GetRowText(ENUM_ROW_CONTENT content)
{
   switch(content)
   {
      case ROW_TICKER:    return _Symbol;
      case ROW_TIMEFRAME: return GetTimeframeText();
      case ROW_EXCHANGE:  return GetBrokerName();
      case ROW_COUNTDOWN: return GetCountdownText();
      case ROW_CUSTOM:    return CustomText;
      case ROW_EMPTY:     return "";
      default:            return "";
   }
}

//+------------------------------------------------------------------+
string GetBrokerName()
{
   string broker = AccountInfoString(ACCOUNT_COMPANY);
   if(StringLen(broker) == 0)
      broker = AccountInfoString(ACCOUNT_SERVER);
   if(StringLen(broker) == 0)
      broker = "Broker";
   return broker;
}

//+------------------------------------------------------------------+
string GetTimeframeText()
{
   ENUM_TIMEFRAMES tf = Period();

   if(TimeframeStyle == TF_TRADINGVIEW)
   {
      switch(tf)
      {
         case PERIOD_M1:  return "1m";
         case PERIOD_M2:  return "2m";
         case PERIOD_M3:  return "3m";
         case PERIOD_M4:  return "4m";
         case PERIOD_M5:  return "5m";
         case PERIOD_M6:  return "6m";
         case PERIOD_M10: return "10m";
         case PERIOD_M12: return "12m";
         case PERIOD_M15: return "15m";
         case PERIOD_M20: return "20m";
         case PERIOD_M30: return "30m";
         case PERIOD_H1:  return "1H";
         case PERIOD_H2:  return "2H";
         case PERIOD_H3:  return "3H";
         case PERIOD_H4:  return "4H";
         case PERIOD_H6:  return "6H";
         case PERIOD_H8:  return "8H";
         case PERIOD_H12: return "12H";
         case PERIOD_D1:  return "1D";
         case PERIOD_W1:  return "1W";
         case PERIOD_MN1: return "1M";
         default:         return string(PeriodSeconds(tf) / 60) + "m";
      }
   }
   else // MetaTrader style
   {
      switch(tf)
      {
         case PERIOD_M1:  return "M1";
         case PERIOD_M2:  return "M2";
         case PERIOD_M3:  return "M3";
         case PERIOD_M4:  return "M4";
         case PERIOD_M5:  return "M5";
         case PERIOD_M6:  return "M6";
         case PERIOD_M10: return "M10";
         case PERIOD_M12: return "M12";
         case PERIOD_M15: return "M15";
         case PERIOD_M20: return "M20";
         case PERIOD_M30: return "M30";
         case PERIOD_H1:  return "H1";
         case PERIOD_H2:  return "H2";
         case PERIOD_H3:  return "H3";
         case PERIOD_H4:  return "H4";
         case PERIOD_H6:  return "H6";
         case PERIOD_H8:  return "H8";
         case PERIOD_H12: return "H12";
         case PERIOD_D1:  return "D1";
         case PERIOD_W1:  return "W1";
         case PERIOD_MN1: return "MN";
         default:         return "M" + string(PeriodSeconds(tf) / 60);
      }
   }
}

//+------------------------------------------------------------------+
string GetCountdownText()
{
   datetime barTime = iTime(_Symbol, Period(), 0);
   int periodSeconds = PeriodSeconds(Period());

   // Calculate bar close time
   datetime barClose = barTime + periodSeconds;
   datetime serverTime = TimeCurrent();

   // Calculate remaining time
   int remaining = (int)(barClose - serverTime);
   if(remaining < 0) remaining = 0;

   return FormatTimeSpan(remaining);
}

//+------------------------------------------------------------------+
string FormatTimeSpan(int totalSeconds)
{
   if(totalSeconds < 0) totalSeconds = 0;

   int days = totalSeconds / 86400;
   int hours = (totalSeconds % 86400) / 3600;
   int minutes = (totalSeconds % 3600) / 60;
   int seconds = totalSeconds % 60;

   string result;

   if(days > 0)
   {
      result = StringFormat("%dd %02d:%02d:%02d", days, hours, minutes, seconds);
   }
   else if(hours > 0)
   {
      result = StringFormat("%d:%02d:%02d", hours, minutes, seconds);
   }
   else
   {
      result = StringFormat("%02d:%02d", minutes, seconds);
   }

   return result;
}

//+------------------------------------------------------------------+
int GetRowFontSize(int rowIndex)
{
   int rowFontSize = 0;
   switch(rowIndex)
   {
      case 0: rowFontSize = Row1FontSize; break;
      case 1: rowFontSize = Row2FontSize; break;
      case 2: rowFontSize = Row3FontSize; break;
      case 3: rowFontSize = Row4FontSize; break;
   }
   return (rowFontSize > 0) ? rowFontSize : FontSize;
}

//+------------------------------------------------------------------+
ENUM_ANCHOR_POINT GetAnchorPoint()
{
   // Determine anchor based on text alignment
   switch(TextAlignment)
   {
      case TEXT_LEFT:   return ANCHOR_LEFT_UPPER;
      case TEXT_CENTER: return ANCHOR_CENTER;
      case TEXT_RIGHT:  return ANCHOR_RIGHT_UPPER;
      default:          return ANCHOR_CENTER;
   }
}

//+------------------------------------------------------------------+
ENUM_BASE_CORNER GetCorner()
{
   if(VerticalPos == V_TOP && HorizontalPos == H_LEFT)
      return CORNER_LEFT_UPPER;
   if(VerticalPos == V_TOP && HorizontalPos == H_RIGHT)
      return CORNER_RIGHT_UPPER;
   if(VerticalPos == V_BOTTOM && HorizontalPos == H_LEFT)
      return CORNER_LEFT_LOWER;
   if(VerticalPos == V_BOTTOM && HorizontalPos == H_RIGHT)
      return CORNER_RIGHT_LOWER;

   // For center positions, use left upper and calculate offset
   return CORNER_LEFT_UPPER;
}

//+------------------------------------------------------------------+
void CalculatePosition(int &x, int &y, int totalHeight)
{
   // Horizontal position
   switch(HorizontalPos)
   {
      case H_LEFT:
         x = MarginX;
         break;
      case H_CENTER:
         x = chartWidth / 2;
         break;
      case H_RIGHT:
         x = MarginX;
         break;
   }

   // Vertical position
   switch(VerticalPos)
   {
      case V_TOP:
         y = MarginY;
         break;
      case V_MIDDLE:
         y = (chartHeight - totalHeight) / 2;
         break;
      case V_BOTTOM:
         y = MarginY;
         break;
   }
}

//+------------------------------------------------------------------+
void CreateWatermark()
{
   // Row contents and their font sizes
   ENUM_ROW_CONTENT rowContents[4];
   rowContents[0] = Row1Content;
   rowContents[1] = Row2Content;
   rowContents[2] = Row3Content;
   rowContents[3] = Row4Content;

   // Calculate total height (approximate)
   int totalHeight = 0;
   int rowHeights[4];
   for(int i = 0; i < 4; i++)
   {
      if(rowContents[i] != ROW_EMPTY)
      {
         int rowSize = GetRowFontSize(i);
         rowHeights[i] = rowSize + 10; // Add line spacing
         totalHeight += rowHeights[i];
      }
      else
      {
         rowHeights[i] = 0;
      }
   }

   // Get base position
   int baseX, baseY;
   CalculatePosition(baseX, baseY, totalHeight);

   ENUM_BASE_CORNER corner = GetCorner();
   ENUM_ANCHOR_POINT anchor;

   // Determine anchor based on alignment
   switch(TextAlignment)
   {
      case TEXT_LEFT:   anchor = ANCHOR_LEFT_UPPER; break;
      case TEXT_CENTER: anchor = ANCHOR_CENTER; break;
      case TEXT_RIGHT:  anchor = ANCHOR_RIGHT_UPPER; break;
      default:          anchor = ANCHOR_CENTER; break;
   }

   // Create labels for each row
   int currentY = baseY;
   for(int i = 0; i < 4; i++)
   {
      string labelName = objPrefix + "Row" + string(i);

      if(rowContents[i] == ROW_EMPTY)
      {
         // Delete if exists
         if(ObjectFind(0, labelName) >= 0)
            ObjectDelete(0, labelName);
         continue;
      }

      // Create or update label
      if(ObjectFind(0, labelName) < 0)
         ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);

      string text = GetRowText(rowContents[i]);
      int rowSize = GetRowFontSize(i);

      // Set properties
      ObjectSetString(0, labelName, OBJPROP_TEXT, text);
      ObjectSetString(0, labelName, OBJPROP_FONT, FontName);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, rowSize);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, TextColor);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, baseX);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, true);

      currentY += rowHeights[i];
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
void UpdateCountdownRows()
{
   ENUM_ROW_CONTENT rowContents[4];
   rowContents[0] = Row1Content;
   rowContents[1] = Row2Content;
   rowContents[2] = Row3Content;
   rowContents[3] = Row4Content;

   bool needsRedraw = false;

   for(int i = 0; i < 4; i++)
   {
      if(rowContents[i] == ROW_COUNTDOWN)
      {
         string labelName = objPrefix + "Row" + string(i);
         if(ObjectFind(0, labelName) >= 0)
         {
            string newText = GetCountdownText();
            ObjectSetString(0, labelName, OBJPROP_TEXT, newText);
            needsRedraw = true;
         }
      }
   }

   if(needsRedraw)
      ChartRedraw();
}

//+------------------------------------------------------------------+
void UpdatePositions()
{
   // Recalculate and update all positions
   CreateWatermark();
}

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
   return (rates_total);
}
