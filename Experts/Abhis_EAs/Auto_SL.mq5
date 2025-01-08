//+------------------------------------------------------------------+
//|                                                   Auto_SL_EA.mq5 |
//|                                                    Created 2025  |
//+------------------------------------------------------------------+
#property copyright "abhidp"
#property link ""
#property version "1.00"
#property strict

// Include the Trade class
#include <Trade/Trade.mqh>

// Create trade object
CTrade trade;

// Input Parameters
input double FixedSLPips = 25.0;       // Initial Stop Loss in pips
input bool UseATR = true;              // Use ATR for Stop Loss and Trailing
input int ATRPeriod = 14;              // ATR Period
input double ATRMultiplier = 2.0;      // ATR Multiplier for Initial Stop Loss
input double TrailATRMultiplier = 1.5; // ATR Multiplier for Trailing Stop (lower than initial)
input bool EnableTrailing = true;      // Enable Trailing Stop
input int MinimumPips = 10;            // Minimum trailing distance in pips

// Global Variables
int ATRHandle;
double ATRBuffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
  // Initialize ATR indicator
  ATRHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
  if (ATRHandle == INVALID_HANDLE)
  {
    Print("Error creating ATR indicator!");
    return (INIT_FAILED);
  }
  ArraySetAsSeries(ATRBuffer, true);

  return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  if (ATRHandle != INVALID_HANDLE)
    IndicatorRelease(ATRHandle);
}

//+------------------------------------------------------------------+
//| Get current ATR value                                             |
//+------------------------------------------------------------------+
double GetCurrentATR()
{
  if (CopyBuffer(ATRHandle, 0, 0, 1, ATRBuffer) <= 0)
  {
    Print("Error copying ATR buffer - using minimum pips");
    return MinimumPips * 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  }
  return ATRBuffer[0];
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss price based on entry price                     |
//+------------------------------------------------------------------+
double CalculateStopLoss(const double entryPrice, const ENUM_POSITION_TYPE posType)
{
  double stopLossPrice = 0.0;
  double stopLossPoints = 0.0;

  // Get point value
  double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

  if (UseATR)
  {
    double currentATR = GetCurrentATR();
    stopLossPoints = (currentATR * ATRMultiplier) / point;
  }
  else
  {
    // Use fixed pips
    stopLossPoints = FixedSLPips * 10;
  }

  // Ensure minimum stop distance
  stopLossPoints = MathMax(stopLossPoints, MinimumPips * 10);

  // Calculate SL price based on position type
  if (posType == POSITION_TYPE_BUY)
    stopLossPrice = entryPrice - stopLossPoints * point;
  else if (posType == POSITION_TYPE_SELL)
    stopLossPrice = entryPrice + stopLossPoints * point;

  return NormalizeDouble(stopLossPrice, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate trailing stop distance based on ATR                      |
//+------------------------------------------------------------------+
double GetTrailingDistance()
{
  double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  double trailingPoints;

  if (UseATR)
  {
    double currentATR = GetCurrentATR();
    trailingPoints = (currentATR * TrailATRMultiplier) / point;
  }
  else
  {
    trailingPoints = MinimumPips * 10;
  }

  // Ensure minimum trailing distance
  return MathMax(trailingPoints, MinimumPips * 10);
}

//+------------------------------------------------------------------+
//| Check and update trailing stop                                     |
//+------------------------------------------------------------------+
void CheckTrailingStop(const ulong ticket, const double currentSL)
{
  if (!EnableTrailing)
    return;

  double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

  if (PositionSelectByTicket(ticket))
  {
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double newSL = currentSL;
    double trailingDistance = GetTrailingDistance() * point;

    // For Buy positions
    if (posType == POSITION_TYPE_BUY)
    {
      double potentialSL = NormalizeDouble(bid - trailingDistance, _Digits);
      // Only move SL up, and only if price has moved sufficient distance
      if (potentialSL > currentSL && potentialSL > openPrice)
      {
        newSL = potentialSL;
      }
    }
    // For Sell positions
    else if (posType == POSITION_TYPE_SELL)
    {
      double potentialSL = NormalizeDouble(ask + trailingDistance, _Digits);
      // Only move SL down, and only if price has moved sufficient distance
      if (potentialSL < currentSL && potentialSL < openPrice)
      {
        newSL = potentialSL;
      }
    }

    // If new SL is different from current SL, modify position
    if (NormalizeDouble(newSL, _Digits) != NormalizeDouble(currentSL, _Digits))
    {
      trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
      if (GetLastError() == 0)
        Print("Trailing Stop updated for position #", ticket, " to ", newSL);
    }
  }
}

//+------------------------------------------------------------------+
//| Expert trade function                                             |
//+------------------------------------------------------------------+
void OnTrade()
{
  // Check for new positions without SL
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket <= 0)
      continue;

    if (PositionSelectByTicket(ticket))
    {
      double currentSL = PositionGetDouble(POSITION_SL);

      // If position has no SL
      if (currentSL == 0)
      {
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        // Calculate and set initial SL
        double newSL = CalculateStopLoss(entryPrice, posType);

        // Modify position to add SL
        trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));

        if (GetLastError() == 0)
          Print("Initial Stop Loss set for position #", ticket, " at ", newSL);
        else
          Print("Error setting Stop Loss for position #", ticket, ". Error code: ", GetLastError());
      }
    }
  }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
  // Check trailing stop for all positions
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket <= 0)
      continue;

    if (PositionSelectByTicket(ticket))
    {
      double currentSL = PositionGetDouble(POSITION_SL);
      if (currentSL != 0) // Only trail positions that have a SL set
      {
        CheckTrailingStop(ticket, currentSL);
      }
    }
  }
}