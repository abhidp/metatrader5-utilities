//+------------------------------------------------------------------+
//|                                                  LocalTimeEA.mq5 |
//|                                                     Created 2025 |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link ""
#property version "1.00"
#property strict

// Input Parameters
input int FontSize = 10;                           // Font Size
input color TimeColor = clrYellow;                 // Time Color
input string FontName = "Arial";                   // Font Name
input ENUM_BASE_CORNER Corner = CORNER_LEFT_LOWER; // Chart Corner
input int XOffset = 10;                            // X Offset (pixels)
input int YOffset = 50;                            // Y Offset (pixels)
input bool ShowSeconds = true;                     // Show Seconds
input bool ShowDate = true;                        // Show Date

// Global Variables
string ObjectName = "LocalTime";

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
  // Create text object
  if (!ObjectCreate(0, ObjectName, OBJ_LABEL, 0, 0, 0))
  {
    Print("Error creating time label object: ", GetLastError());
    return INIT_FAILED;
  }

  // Set object properties
  ObjectSetInteger(0, ObjectName, OBJPROP_CORNER, Corner);
  ObjectSetInteger(0, ObjectName, OBJPROP_XDISTANCE, XOffset);
  ObjectSetInteger(0, ObjectName, OBJPROP_YDISTANCE, YOffset);
  ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, TimeColor);
  ObjectSetInteger(0, ObjectName, OBJPROP_FONTSIZE, FontSize);
  ObjectSetString(0, ObjectName, OBJPROP_FONT, FontName);
  ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);
  ObjectSetInteger(0, ObjectName, OBJPROP_HIDDEN, true);

  // Force immediate update
  UpdateTime();

  return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  // Clean up by deleting the object
  ObjectDelete(0, ObjectName);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
  UpdateTime();
}

//+------------------------------------------------------------------+
//| Update time display                                               |
//+------------------------------------------------------------------+
void UpdateTime()
{
  MqlDateTime local_time;
  TimeLocal(local_time);

  string timeStr;

  // Add date if enabled
  if (ShowDate)
  {
    timeStr = StringFormat("%04d-%02d-%02d ",
                           local_time.year,
                           local_time.mon,
                           local_time.day);
  }

  // Add time
  if (ShowSeconds)
  {
    timeStr += StringFormat("%02d:%02d:%02d",
                            local_time.hour,
                            local_time.min,
                            local_time.sec);
  }
  else
  {
    timeStr += StringFormat("%02d:%02d",
                            local_time.hour,
                            local_time.min);
  }

  // Add timezone identifier
  timeStr += " (Local Time)";

  // Update the object text
  ObjectSetString(0, ObjectName, OBJPROP_TEXT, timeStr);

  // Redraw the chart
  ChartRedraw(0);
}