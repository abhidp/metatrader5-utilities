//###<Experts/Common/Utils.mqh>
//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|                                           Copyright 2025, abhidp |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, abhidp"
#property link      "https://github.com/abhidp"
#property version   "1.00"

// Common utility functions for all EAs
class Utils
{
public:
    // Convert pips to points based on symbol digits
    static double PipsToPoints(const string symbol, const double pips)
    {
        double points = pips * 10;
        return points;
    }
    
    // Calculate position size based on risk percentage
    static double CalculatePositionSize(const string symbol, const double riskPercent, const double slPoints)
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = balance * riskPercent / 100;
        
        double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        if(tickSize == 0) return 0;
        
        return NormalizeDouble(riskAmount / (slPoints * tickSize), 2);
    }
};