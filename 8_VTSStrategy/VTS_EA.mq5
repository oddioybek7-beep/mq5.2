//+------------------------------------------------------------------+
//|                                                      VTS_EA.mq5 |
//|                                  Copyright 2026, AI Assistant    |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>

input int    InpMagic = 880011;
input double InpRiskPercent = 2.0;       // Yopiq Bitimdagi Risk (Balansga % - lot uchun)
input int    InpMinPosCount = 2;         // Minimal Bitimlar soni
input int    InpMaxPosCount = 5;         // Maksimal Bitimlar soni (Balans oshganda)
input double InpAccountBalanceBase = 1000; // Bazaviy Balans miqdori o'sish hisobi uchun

CTrade trade;
int indHandle;
double buyBuffer[1];
double sellBuffer[1];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   indHandle = iCustom(_Symbol, _Period, "8_VTSStrategy\\VTS_Indicator");
   
   if(indHandle == INVALID_HANDLE)
     {
      Print("Indikatorni topib bo'lmadi! VTS_Indicator.mq5 faylini avvalo F7 (Compile) qiling!");
      return(INIT_FAILED);
     }
     
   DrawDashboard();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "DB_");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateDashboard();
   
   if(PositionsTotal() > 0) return;
   
   if(CopyBuffer(indHandle, 2, 1, 1, buyBuffer) <= 0) return;
   if(CopyBuffer(indHandle, 3, 1, 1, sellBuffer) <= 0) return;
   
   bool isBuy = (buyBuffer[0] != EMPTY_VALUE && buyBuffer[0] != 0.0);
   bool isSell = (sellBuffer[0] != EMPTY_VALUE && sellBuffer[0] != 0.0);
   
   if(isBuy)
     {
      ExecuteTrades(POSITION_TYPE_BUY);
     }
   else if(isSell)
     {
      ExecuteTrades(POSITION_TYPE_SELL);
     }
  }

//+------------------------------------------------------------------+
//| Bitimlarni amalga oshirish funksiyasi                             |
//+------------------------------------------------------------------+
void ExecuteTrades(long pos_type)
  {
   int pos_count = GetDynamicPosCount();
   double lot = GetDynamicLot();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl_dist = iATR(_Symbol, _Period, 14, 1) * 3.5;
   
   for(int i = 0; i < pos_count; i++)
     {
      double rrr = 1.0 + (i * 0.5); // Kaskadli RR: 1.0, 1.5, 2.0...
      
      if(pos_type == POSITION_TYPE_BUY)
        {
         double sl = NormalizeDouble(ask - sl_dist, _Digits);
         double tp = NormalizeDouble(ask + sl_dist * rrr, _Digits);
         trade.Buy(lot, _Symbol, ask, sl, tp);
        }
      else
        {
         double sl = NormalizeDouble(bid + sl_dist, _Digits);
         double tp = NormalizeDouble(bid - sl_dist * rrr, _Digits);
         trade.Sell(lot, _Symbol, bid, sl, tp);
        }
     }
  }

//+------------------------------------------------------------------+
//| Balansga qarab bitimlar sonini dinamik tanlash                   |
//+------------------------------------------------------------------+
int GetDynamicPosCount()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   int multiplier = (int)(balance / InpAccountBalanceBase);
   
   int pos_limit = InpMinPosCount + multiplier;
   if(pos_limit > InpMaxPosCount) pos_limit = InpMaxPosCount;
   
   return pos_limit;
  }

//+------------------------------------------------------------------+
//| Balansga qarab Lot hajmini shakllantirish                        |
//+------------------------------------------------------------------+
double GetDynamicLot()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money = balance * (InpRiskPercent / 100.0);
   
   // Juda sodda misol: 1 lot uchun 1 pips ~ margin
   // To'liq hisoblash o'rniga, balansdan to'g'ridan to'g'ri proportsiya
   double lot = NormalizeDouble((balance / 10000.0) * 0.1, 2); 
   if(lot < 0.01) lot = 0.01;
   
   return lot;
  }

//+------------------------------------------------------------------+
//| QORA Dashboard Chizish                                           |
//+------------------------------------------------------------------+
void DrawDashboard()
  {
   ObjectCreate(0, "DB_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DB_BG", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "DB_BG", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "DB_BG", OBJPROP_XSIZE, 280);
   ObjectSetInteger(0, "DB_BG", OBJPROP_YSIZE, 120);
   ObjectSetInteger(0, "DB_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, "DB_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "DB_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   ObjectCreate(0, "DB_TEXT1", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DB_TEXT1", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, "DB_TEXT1", OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, "DB_TEXT1", OBJPROP_COLOR, clrWhite);
   
   ObjectCreate(0, "DB_TEXT2", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DB_TEXT2", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, "DB_TEXT2", OBJPROP_YDISTANCE, 60);
   ObjectSetInteger(0, "DB_TEXT2", OBJPROP_COLOR, clrYellow);
   
   ObjectCreate(0, "DB_TEXT3", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DB_TEXT3", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, "DB_TEXT3", OBJPROP_YDISTANCE, 90);
   ObjectSetInteger(0, "DB_TEXT3", OBJPROP_COLOR, clrLimeGreen);
  }

void UpdateDashboard()
  {
   ObjectSetString(0, "DB_TEXT1", OBJPROP_TEXT, "--- VTS STRATEGY AI ---");
   
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot = GetDynamicLot();
   int count = GetDynamicPosCount();
   
   string txt2 = StringFormat("Balance: %.2f | Dynamic Lot: %.2f", bal, lot);
   ObjectSetString(0, "DB_TEXT2", OBJPROP_TEXT, txt2);
   
   string txt3 = StringFormat("Active Positions Bound: %d (Max %d)", count, InpMaxPosCount);
   ObjectSetString(0, "DB_TEXT3", OBJPROP_TEXT, txt3);
   
   ChartRedraw(0);
  }