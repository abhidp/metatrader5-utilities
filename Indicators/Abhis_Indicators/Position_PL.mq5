//+------------------------------------------------------------------+
//|                                                   Position_PL.mq5 |
//+------------------------------------------------------------------+
#property copyright "abhidp"
#property version "1.00"
#property indicator_chart_window

input int FontSize = 10;     // Font Size
input int XOffset = 20;      // X Position (pixels from left)
input int YOffset = 60;      // Y Position (pixels from bottom)
input int LineSpacing = 30;  // Spacing between lines
input int ValueOffset = 250; // Horizontal spacing for amounts
input int PipsOffset = 400;  // Horizontal spacing for pips
input int PosOffset = 550;   // Horizontal spacing for positions

string indicatorName = "Position_PL";
string objPrefix;

//+------------------------------------------------------------------+
int OnInit()
{
  objPrefix = indicatorName + "_" + string(_Symbol) + "_";
  EventSetTimer(1);
  return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  EventKillTimer();
  ObjectsDeleteAll(0, objPrefix);
}

//+------------------------------------------------------------------+
double CalculatePips(double openPrice, double currentPrice, ENUM_POSITION_TYPE posType)
{
  double points = posType == POSITION_TYPE_BUY ? currentPrice - openPrice : openPrice - currentPrice;
  double pips = points / _Point / 10.0;
  return NormalizeDouble(pips, 1);
}

//+------------------------------------------------------------------+
void UpdatePLDisplay()
{
  double totalProfit = 0, buyProfit = 0, sellProfit = 0;
  double totalPips = 0, buyPips = 0, sellPips = 0;
  int totalPositions = 0, buyPositions = 0, sellPositions = 0;

  for (int i = 0; i < PositionsTotal(); i++)
  {
    if (PositionSelectByTicket(PositionGetTicket(i)))
    {
      if (PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
        double positionProfit = PositionGetDouble(POSITION_PROFIT) +
                                PositionGetDouble(POSITION_SWAP);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        double positionPips = CalculatePips(openPrice, currentPrice, posType);

        totalProfit += positionProfit;
        totalPips += positionPips;
        totalPositions++;

        if (posType == POSITION_TYPE_BUY)
        {
          buyProfit += positionProfit;
          buyPips += positionPips;
          buyPositions++;
        }
        else
        {
          sellProfit += positionProfit;
          sellPips += positionPips;
          sellPositions++;
        }
      }
    }
  }

  // Buy P/L
  CreateLabel("Buy", "Buy P/L:", YOffset + (LineSpacing * 2), clrLime);
  CreateLabel("BuyValue", StringFormat("%9.2f", buyProfit),
              YOffset + (LineSpacing * 2), buyProfit >= 0 ? clrLime : clrRed,
              ValueOffset, true);
  CreateLabel("BuyPips", StringFormat("%7.1f pips", buyPips),
              YOffset + (LineSpacing * 2), buyPips >= 0 ? clrLime : clrRed,
              PipsOffset, true);
  CreateLabel("BuyPos", StringFormat("(%d pos)", buyPositions),
              YOffset + (LineSpacing * 2), buyProfit >= 0 ? clrLime : clrRed,
              PosOffset, true);

  // Sell P/L
  CreateLabel("Sell", "Sell P/L:", YOffset + LineSpacing, clrRed);
  CreateLabel("SellValue", StringFormat("%9.2f", sellProfit),
              YOffset + LineSpacing, sellProfit >= 0 ? clrLime : clrRed,
              ValueOffset, true);
  CreateLabel("SellPips", StringFormat("%7.1f pips", sellPips),
              YOffset + LineSpacing, sellPips >= 0 ? clrLime : clrRed,
              PipsOffset, true);
  CreateLabel("SellPos", StringFormat("(%d pos)", sellPositions),
              YOffset + LineSpacing, sellProfit >= 0 ? clrLime : clrRed,
              PosOffset, true);

  // Total P/L
  color totalColor = (totalProfit > 0) ? clrLime : clrRed;
  CreateLabel("Total", "Total P/L:", YOffset, totalColor);
  CreateLabel("TotalValue", StringFormat("%9.2f", totalProfit),
              YOffset, totalColor, ValueOffset, true);
  CreateLabel("TotalPips", StringFormat("%7.1f pips", totalPips),
              YOffset, totalPips >= 0 ? clrLime : clrRed,
              PipsOffset, true);
  CreateLabel("TotalPos", StringFormat("(%d pos)", totalPositions),
              YOffset, totalColor, PosOffset, true);
}

//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int y, color clr, int addX = 0, bool rightAlign = false)
{
  string labelName = objPrefix + name;

  if (ObjectFind(0, labelName) == -1)
  {
    ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, FontSize);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
  }

  ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, rightAlign ? ANCHOR_RIGHT_LOWER : ANCHOR_LEFT_LOWER);
  ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, XOffset + addX);
  ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, y);
  ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
  ObjectSetString(0, labelName, OBJPROP_TEXT, text);
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
  UpdatePLDisplay();
  return (rates_total);
}

//+------------------------------------------------------------------+
void OnTimer()
{
  UpdatePLDisplay();
}