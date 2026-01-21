//+------------------------------------------------------------------+
//|                                                    Watermark.mq5 |
//+------------------------------------------------------------------+
#property copyright "AbidTrd"
#property link ""
#property version "2.10"
#property indicator_chart_window
#property indicator_plots 0

// Enums
enum ENUM_ROW_CONTENT
{
   ROW_TICKER,
   ROW_TIMEFRAME,
   ROW_EXCHANGE,
   ROW_COUNTDOWN,
   ROW_CUSTOM,
   ROW_EMPTY
};

enum ENUM_TF_STYLE
{
   TF_TRADINGVIEW,
   TF_METATRADER
};

enum ENUM_V_POSITION { V_TOP, V_MIDDLE, V_BOTTOM };
enum ENUM_H_POSITION { H_LEFT, H_CENTER, H_RIGHT };
enum ENUM_TEXT_ALIGN { TEXT_LEFT, TEXT_CENTER, TEXT_RIGHT };

// Input Parameters - Style
input group "=== Watermark Style ===";
input int FontSize = 30;
input string FontName = "Arial";
input color TextColor = clrGray;
input int Transparency = 70;
input bool IsBold = false;
input bool IsItalic = false;

// Input Parameters - Position
input group "=== Position ===";
input ENUM_V_POSITION VerticalPos = V_TOP;
input ENUM_H_POSITION HorizontalPos = H_RIGHT;
input ENUM_TEXT_ALIGN TextAlignment = TEXT_CENTER;
input int MarginX = 120;
input int MarginY = 40;

// Input Parameters - Content
input group "=== Row Content ===";
input ENUM_ROW_CONTENT Row1Content = ROW_TICKER;
input ENUM_ROW_CONTENT Row2Content = ROW_TIMEFRAME;
input ENUM_ROW_CONTENT Row3Content = ROW_COUNTDOWN;
input ENUM_ROW_CONTENT Row4Content = ROW_EMPTY;

// Input Parameters - Row Font Sizes
input group "=== Row Font Sizes (0 = inherit) ===";
input int Row1FontSize = 0;
input int Row2FontSize = 0;
input int Row3FontSize = 15;
input int Row4FontSize = 0;

// Input Parameters - Options
input group "=== Options ===";
input ENUM_TF_STYLE TimeframeStyle = TF_TRADINGVIEW;
input string CustomText = "custom text";

// Globals
string indicatorName = "Watermark";
string objPrefix;
int chartWidth, chartHeight;

//+------------------------------------------------------------------+
int OnInit()
{
   objPrefix = indicatorName + "_";

   // Cleanup any old watermark objects (template-safe)
   ObjectsDeleteAll(0, objPrefix);

   EventSetMillisecondTimer(1000);

   chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   CreateWatermark();
   return INIT_SUCCEEDED;
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
   UpdateCountdownRows();
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

      // Rebuild watermark on symbol/timeframe/layout change
      CreateWatermark();
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
      default:            return "";
   }
}

//+------------------------------------------------------------------+
string GetBrokerName()
{
   string broker = AccountInfoString(ACCOUNT_COMPANY);
   if(broker == "") broker = AccountInfoString(ACCOUNT_SERVER);
   if(broker == "") broker = "Broker";
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
         case PERIOD_M1: return "1m";
         case PERIOD_M5: return "5m";
         case PERIOD_M15: return "15m";
         case PERIOD_M30: return "30m";
         case PERIOD_H1: return "1H";
         case PERIOD_H4: return "4H";
         case PERIOD_D1: return "1D";
         default: return string(PeriodSeconds(tf)/60) + "m";
      }
   }
   else
   {
      return EnumToString(tf);
   }
}

//+------------------------------------------------------------------+
string GetCountdownText()
{
   datetime barTime = iTime(_Symbol, Period(), 0);
   int periodSeconds = PeriodSeconds(Period());
   datetime barClose = barTime + periodSeconds;
   int remaining = (int)(barClose - TimeCurrent());
   if(remaining < 0) remaining = 0;
   return FormatTimeSpan(remaining);
}

//+------------------------------------------------------------------+
string FormatTimeSpan(int totalSeconds)
{
   int minutes = totalSeconds / 60;
   int seconds = totalSeconds % 60;
   return StringFormat("%02d:%02d", minutes, seconds);
}

//+------------------------------------------------------------------+
int GetRowFontSize(int rowIndex)
{
   int rowFontSize = FontSize;
   if(rowIndex == 0 && Row1FontSize > 0) rowFontSize = Row1FontSize;
   if(rowIndex == 1 && Row2FontSize > 0) rowFontSize = Row2FontSize;
   if(rowIndex == 2 && Row3FontSize > 0) rowFontSize = Row3FontSize;
   if(rowIndex == 3 && Row4FontSize > 0) rowFontSize = Row4FontSize;
   return rowFontSize;
}

//+------------------------------------------------------------------+
ENUM_BASE_CORNER GetCorner()
{
   if(VerticalPos == V_TOP && HorizontalPos == H_LEFT) return CORNER_LEFT_UPPER;
   if(VerticalPos == V_TOP && HorizontalPos == H_RIGHT) return CORNER_RIGHT_UPPER;
   if(VerticalPos == V_BOTTOM && HorizontalPos == H_LEFT) return CORNER_LEFT_LOWER;
   if(VerticalPos == V_BOTTOM && HorizontalPos == H_RIGHT) return CORNER_RIGHT_LOWER;
   return CORNER_LEFT_UPPER;
}

//+------------------------------------------------------------------+
void CalculatePosition(int &x, int &y, int totalHeight)
{
   if(HorizontalPos == H_LEFT) x = MarginX;
   else if(HorizontalPos == H_CENTER) x = chartWidth/2;
   else x = MarginX;

   if(VerticalPos == V_TOP) y = MarginY;
   else if(VerticalPos == V_MIDDLE) y = (chartHeight - totalHeight)/2;
   else y = MarginY;
}

//+------------------------------------------------------------------+
void CreateWatermark()
{
   ENUM_ROW_CONTENT rows[4] = {Row1Content, Row2Content, Row3Content, Row4Content};

   int totalHeight = 0;
   int rowHeights[4];

   for(int i=0;i<4;i++)
   {
      if(rows[i] != ROW_EMPTY)
      {
         rowHeights[i] = GetRowFontSize(i) + 10;
         totalHeight += rowHeights[i];
      }
      else rowHeights[i] = 0;
   }

   int baseX, baseY;
   CalculatePosition(baseX, baseY, totalHeight);

   ENUM_BASE_CORNER corner = GetCorner();
   ENUM_ANCHOR_POINT anchor = (TextAlignment==TEXT_LEFT?ANCHOR_LEFT_UPPER:
                              TextAlignment==TEXT_RIGHT?ANCHOR_RIGHT_UPPER:
                              ANCHOR_CENTER);

   int currentY = baseY;

   for(int i=0;i<4;i++)
   {
      string labelName = objPrefix + "Row" + string(i);

      if(rows[i] == ROW_EMPTY)
      {
         ObjectDelete(0, labelName);
         continue;
      }

      if(ObjectFind(0,labelName) < 0)
         ObjectCreate(0,labelName,OBJ_LABEL,0,0,0);

      ObjectSetString(0,labelName,OBJPROP_TEXT,GetRowText(rows[i]));
      ObjectSetString(0,labelName,OBJPROP_FONT,FontName);
      ObjectSetInteger(0,labelName,OBJPROP_FONTSIZE,GetRowFontSize(i));
      ObjectSetInteger(0,labelName,OBJPROP_COLOR,TextColor);
      ObjectSetInteger(0,labelName,OBJPROP_CORNER,corner);
      ObjectSetInteger(0,labelName,OBJPROP_ANCHOR,anchor);
      ObjectSetInteger(0,labelName,OBJPROP_XDISTANCE,baseX);
      ObjectSetInteger(0,labelName,OBJPROP_YDISTANCE,currentY);
      ObjectSetInteger(0,labelName,OBJPROP_BACK,true);
      ObjectSetInteger(0,labelName,OBJPROP_SELECTABLE,false);

      currentY += rowHeights[i];
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
void UpdateCountdownRows()
{
   ENUM_ROW_CONTENT rows[4] = {Row1Content, Row2Content, Row3Content, Row4Content};

   for(int i=0;i<4;i++)
   {
      if(rows[i] == ROW_COUNTDOWN)
      {
         string labelName = objPrefix + "Row" + string(i);
         if(ObjectFind(0,labelName)>=0)
            ObjectSetString(0,labelName,OBJPROP_TEXT,GetCountdownText());
      }
   }

   ChartRedraw();
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
   return rates_total;
}
