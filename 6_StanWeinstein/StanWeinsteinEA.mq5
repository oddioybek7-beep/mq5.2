//+------------------------------------------------------------------+
//|                                              StanWeinsteinEA.mq5 |
//|                                  Copyright 2026, AI Assistant    |
//+------------------------------------------------------------------+
#property copyright "AI Assistant"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

input double InpLotSize = 0.1;
input int InpMagicNumber = 123456;
input int InpSlippage = 3;

// Handles
int st_handle;
double stageBuffer[];
double springBuffer[];
double upthrustBuffer[];
double trailingStopBuffer[];

CTrade trade;
CPositionInfo pos;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Create indicator handle
   st_handle = iCustom(_Symbol, _Period, "6_StanWeinstein\\StanWeinsteinStagVol");
   if(st_handle == INVALID_HANDLE)
      st_handle = iCustom(_Symbol, _Period, "\\Experts\\6_StanWeinstein\\StanWeinsteinStagVol");
   if(st_handle == INVALID_HANDLE)
      st_handle = iCustom(_Symbol, _Period, "\\Experts\\StanWeinsteinStagVol");
   if(st_handle == INVALID_HANDLE)
      st_handle = iCustom(_Symbol, _Period, "StanWeinsteinStagVol");
      
   if(st_handle == INVALID_HANDLE)
     {
      Print("Error creating StanWeinsteinStagVol indicator handle");
      return(INIT_FAILED);
     }
     
   ArraySetAsSeries(stageBuffer, true);
   ArraySetAsSeries(springBuffer, true);
   ArraySetAsSeries(upthrustBuffer, true);
   ArraySetAsSeries(trailingStopBuffer, true);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(st_handle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return;
   
   // Only run on new bar (optional, simpler for SW system)
   static datetime lastBarTime = 0;
   datetime curBarTime = iTime(_Symbol, _Period, 0);
   if(curBarTime == lastBarTime) return;
   
   if(CopyBuffer(st_handle, 4, 0, 3, stageBuffer) <= 0) return;
   if(CopyBuffer(st_handle, 2, 0, 3, springBuffer) <= 0) return;
   if(CopyBuffer(st_handle, 3, 0, 3, upthrustBuffer) <= 0) return;
   if(CopyBuffer(st_handle, 1, 0, 3, trailingStopBuffer) <= 0) return;

   double stage = stageBuffer[1]; // Use completed bar
   double spring = springBuffer[1];
   double upthrust = upthrustBuffer[1];
   double stopLevel = trailingStopBuffer[1];

   int totalPositions = PositionsTotal();
   bool hasBuy = false;
   bool hasSell = false;
   
   for(int i = totalPositions - 1; i >= 0; i--)
     {
      if(pos.SelectByIndex(i))
        {
         if(pos.Symbol() == _Symbol && pos.Magic() == InpMagicNumber)
           {
            if(pos.PositionType() == POSITION_TYPE_BUY)
              {
               hasBuy = true;
               // Trailing Stop logic
               if(stopLevel > 0 && pos.StopLoss() < stopLevel)
                 {
                  trade.PositionModify(pos.Ticket(), stopLevel, pos.TakeProfit());
                 }
               // Exit condition
               if(stage == 4) 
                 {
                  trade.PositionClose(pos.Ticket());
                 }
              }
            else if(pos.PositionType() == POSITION_TYPE_SELL)
              {
               hasSell = true;
               // Trailing Stop logic
               if(stopLevel > 0 && (pos.StopLoss() > stopLevel || pos.StopLoss() == 0))
                 {
                  trade.PositionModify(pos.Ticket(), stopLevel, pos.TakeProfit());
                 }
               // Exit condition
               if(stage == 2)
                 {
                  trade.PositionClose(pos.Ticket());
                 }
              }
           }
        }
     }

   // Entry logic
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(!hasBuy && (stage == 2 || spring > 0))
     {
      trade.Buy(InpLotSize, _Symbol, ask, 0, 0, "SW Stage 2/Spring Entry");
      lastBarTime = curBarTime;
     }
   else if(!hasSell && (stage == 4 || upthrust > 0))
     {
      trade.Sell(InpLotSize, _Symbol, bid, 0, 0, "SW Stage 4/Upthrust Entry");
      lastBarTime = curBarTime;
     }
  }
//+------------------------------------------------------------------+
