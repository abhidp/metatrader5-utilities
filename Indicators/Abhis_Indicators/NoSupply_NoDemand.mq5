//+------------------------------------------------------------------+
//|                                                  NSNDHistory.mq5 |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2011, MetaQuotes Software Corp."
#property link "http://www.metaquotes.net"
#property version "1.00"
#property indicator_chart_window
#property strict

// Input Parameters
input int barcount = 500;            // Number of bars to analyze
input int NSNDcount = 10;            // Number of bars to check for NSND
input int ArrowSize = 3;             // Size of arrows (1-5)
input color NoSupplyColor = clrLime; // Color for No Supply markers
input color NoDemandColor = clrRed;  // Color for No Demand markers
input double ArrowOffset = 0.0002;   // Vertical offset for arrows

// Global Variables
int prevtime = 0;
int prevfirstbar = 0;
double prevpricemax = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
  return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  ObjectsDeleteAll(0, "NS_ND_");
  ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Create an arrow on the chart                                      |
//+------------------------------------------------------------------+
void CreateArrow(datetime time, double price, int code, color clr, string name)
{
  if (ObjectCreate(0, name, OBJ_ARROW, 0, time, price))
  {
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, ArrowSize);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
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
  if (rates_total < 3)
    return (0);

  int firstBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);

  if (firstBar != prevfirstbar || time[0] != prevtime)
  {
    ObjectsDeleteAll(0, "NS_ND_");

    int limit = MathMin(rates_total - 1, firstBar + barcount);

    for (int i = limit; i >= 0; i--)
    {
      // Check for Bull/Bear
      bool isBear = open[i] > close[i];
      bool isBull = close[i] > open[i];

      // Check for Low Volume
      bool lowVolume = false;
      if (i < rates_total - 2)
      {
        lowVolume = (volume[i] < volume[i + 1] && volume[i] < volume[i + 2]);
      }

      // Check for Pin Bar
      bool isPin = false;
      if (isBear && high[i] > open[i] + _Point && low[i] < close[i] - _Point)
        isPin = true;
      if (isBull && high[i] > close[i] + _Point && low[i] < open[i] - _Point)
        isPin = true;

      // Check subsequent closes
      bool bearCloseBelow = false;
      bool bearCloseAbove = false;
      bool bullCloseAbove = false;
      bool bullCloseBelow = false;

      for (int j = i; j > i - NSNDcount && j >= 0; j--)
      {
        if (isBear)
        {
          if (close[j] < low[i])
            bearCloseBelow = true;
          if (close[j] > high[i])
            bearCloseAbove = true;
        }
        if (isBull)
        {
          if (close[j] > high[i])
            bullCloseAbove = true;
          if (close[j] < low[i])
            bullCloseBelow = true;
        }
      }

      string label = IntegerToString(i);

      // No Demand Signal
      if (isBull && lowVolume && isPin && !bullCloseAbove && bullCloseBelow)
      {
        string ndName = "NS_ND_ND_" + label;
        CreateArrow(time[i], high[i] + ArrowOffset, 242, NoDemandColor, ndName);
      }

      // No Supply Signal
      if (isBear && lowVolume && isPin && !bearCloseBelow && bearCloseAbove)
      {
        string nsName = "NS_ND_NS_" + label;
        CreateArrow(time[i], low[i] - ArrowOffset, 241, NoSupplyColor, nsName);
      }
    }

    prevtime = (int)time[0];
    prevfirstbar = firstBar;
  }

  return (rates_total);
}