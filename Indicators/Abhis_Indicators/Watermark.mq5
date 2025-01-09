//+------------------------------------------------------------------+
//|                                                    Watermark.mq5 |
//+------------------------------------------------------------------+
#property copyright "AbidTrd"
#property link ""
#property version "1.00"
#property indicator_chart_window
#property indicator_plots 0

// Input Parameters
input int FontSize = 60;                // Watermark Font Size
input string FontName = "Arial Narrow"; // Font Name
input color TextColor = "44,44,44";   // Watermark Color
input int Transparency = 98;            // Transparency (0-100)
input int XOffset = 1400;               // X Position from left
input int YOffset = 300;                // Y Position from top
input bool ShowTimeframe = true;        // Show Timeframe
input int DescriptionFontSize = 30;     // Description Font Size

// Currency pair descriptions - stored as array of pairs
string descriptions[10][2] = {
    {"XAUUSD", "Gold Spot / US Dollar"},
    {"EURUSD", "Euro / US Dollar"},
    {"GBPUSD", "British Pound / US Dollar"},
    {"USDJPY", "US Dollar / Japanese Yen"},
    {"USDCHF", "US Dollar / Swiss Franc"},
    {"AUDUSD", "Australian Dollar / US Dollar"},
    {"NZDUSD", "New Zealand Dollar / US Dollar"},
    {"USDCAD", "US Dollar / Canadian Dollar"},
    {"BTCUSD", "Bitcoin / US Dollar"},
    {"ETHUSD", "Ethereum / US Dollar"}};

string indicatorName = "Watermark";
string objPrefix;

//+------------------------------------------------------------------+
int OnInit()
{
  objPrefix = indicatorName + "_" + string(_Symbol) + "_";
  CreateWatermark();
  return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  ObjectsDeleteAll(0, objPrefix);
}

//+------------------------------------------------------------------+
string GetBaseSymbol(string symbol)
{
  return StringSubstr(symbol, 0, 6);
}

//+------------------------------------------------------------------+
string GetInstrumentDescription()
{
  string baseSymbol = GetBaseSymbol(_Symbol);

  for (int i = 0; i < ArrayRange(descriptions, 0); i++)
  {
    string descBaseSymbol = GetBaseSymbol(descriptions[i][0]);
    if (descBaseSymbol == baseSymbol)
      return descriptions[i][1];
  }
  return _Symbol;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void CreateWatermark()
{
  // Calculate transparency
  uchar alpha = (uchar)(255 * (100 - Transparency) / 100);
  color transparentColor = TextColor & 0xFFFFFF;

  // Create and set up the main symbol text
  string mainLabel = objPrefix + "Symbol";
  if (ObjectFind(0, mainLabel) == -1)
    ObjectCreate(0, mainLabel, OBJ_LABEL, 0, 0, 0);

  // Set text based on whether to include timeframe
  string displayText = _Symbol;
  if (ShowTimeframe)
  {
    string tfText = GetTimeframeText();
    displayText = displayText + ", " + tfText;
  }

  // Set main symbol properties
  ObjectSetString(0, mainLabel, OBJPROP_TEXT, displayText);
  ObjectSetString(0, mainLabel, OBJPROP_FONT, FontName);
  ObjectSetInteger(0, mainLabel, OBJPROP_FONTSIZE, FontSize);
  ObjectSetInteger(0, mainLabel, OBJPROP_COLOR, transparentColor);
  ObjectSetInteger(0, mainLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSetInteger(0, mainLabel, OBJPROP_ANCHOR, ANCHOR_CENTER); // Changed to center anchor
  ObjectSetInteger(0, mainLabel, OBJPROP_XDISTANCE, XOffset);
  ObjectSetInteger(0, mainLabel, OBJPROP_YDISTANCE, YOffset);
  ObjectSetInteger(0, mainLabel, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(0, mainLabel, OBJPROP_BACK, true);

  // Create and set up the description text
  string descLabel = objPrefix + "Description";
  if (ObjectFind(0, descLabel) == -1)
    ObjectCreate(0, descLabel, OBJ_LABEL, 0, 0, 0);

  // Get and set description
  string description = GetInstrumentDescription();

  // Set description properties
  ObjectSetString(0, descLabel, OBJPROP_TEXT, description);
  ObjectSetString(0, descLabel, OBJPROP_FONT, FontName);
  ObjectSetInteger(0, descLabel, OBJPROP_FONTSIZE, DescriptionFontSize);
  ObjectSetInteger(0, descLabel, OBJPROP_COLOR, transparentColor);
  ObjectSetInteger(0, descLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSetInteger(0, descLabel, OBJPROP_ANCHOR, ANCHOR_CENTER); // Changed to center anchor
  ObjectSetInteger(0, descLabel, OBJPROP_XDISTANCE, XOffset);    // Using same X offset for center alignment
  ObjectSetInteger(0, descLabel, OBJPROP_YDISTANCE, YOffset + FontSize + 80);
  ObjectSetInteger(0, descLabel, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(0, descLabel, OBJPROP_BACK, true);

  ChartRedraw();
}

//+------------------------------------------------------------------+
string GetTimeframeText()
{
  switch (Period())
  {
  case PERIOD_M1:
    return "1m";
  case PERIOD_M2:
    return "2m";
  case PERIOD_M3:
    return "3m";
  case PERIOD_M4:
    return "4m";
  case PERIOD_M5:
    return "5m";
  case PERIOD_M6:
    return "6m";
  case PERIOD_M10:
    return "10m";
  case PERIOD_M12:
    return "12m";
  case PERIOD_M15:
    return "15m";
  case PERIOD_M20:
    return "20m";
  case PERIOD_M30:
    return "30m";
  case PERIOD_H1:
    return "1h";
  case PERIOD_H2:
    return "2h";
  case PERIOD_H3:
    return "3h";
  case PERIOD_H4:
    return "4h";
  case PERIOD_H6:
    return "6h";
  case PERIOD_H8:
    return "8h";
  case PERIOD_H12:
    return "12h";
  case PERIOD_D1:
    return "D";
  case PERIOD_W1:
    return "W";
  case PERIOD_MN1:
    return "M";
  default:
    return string(Period()) + "m";
  }
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