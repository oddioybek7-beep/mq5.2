//+------------------------------------------------------------------+
//|                                                     UTBot_EA.mq5 |
//|                                  Copyright 2026, Auto-Generated  |
//+------------------------------------------------------------------+
#property copyright   "Auto-Generated"
#property link        ""
#property version     "1.00"

#include <Trade\Trade.mqh>

input double   InpLots        = 0.01;      // Lot o'lchami (10$ balans uchun 0.01)
input double   InpKeyValue    = 3.0;       // UTBot: Key Value
input int      InpAtrPeriod   = 10;        // UTBot: ATR Period
input ulong    InpMagicNum    = 123456;    // Magic Number

CTrade         trade;
int            atr_handle;

// Dashboard o'zgaruvchilari
string         last_buy_price = "N/A";
string         last_sell_price = "N/A";

// State
double         last_trailing_stop = 0;
int            last_pos = 0;
datetime       last_bar_time;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNum);
   
   // Chart ranglarini o'zgartirish (Oq fon, Oq-Qora svechalar)
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_GRID, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrWhite);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrBlack);
   ChartSetInteger(0, CHART_COLOR_VOLUME, clrGray);
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   
   // ATR indicatordan values olish uchun
   atr_handle = iATR(_Symbol, _Period, InpAtrPeriod);
   
   CreateDashboard();
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "DB_"); // Dashboard ob'yektlarini tozalash
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime current_time = iTime(_Symbol, _Period, 0);
   if(current_time == last_bar_time) return; // Faqat yopiq svechada ishlaydi
   
   double close[], atr[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(atr, true);
   
   if(CopyClose(_Symbol, _Period, 0, 3, close) <= 0) return;
   if(CopyBuffer(atr_handle, 0, 0, 3, atr) <= 0) return;
   
   // Hozirgi svechadagi Trailing Stop nuqtasini chizish
   string dot_name = "DB_DOT_" + TimeToString(last_bar_time);
   if(last_trailing_stop > 0)
     {
      ObjectCreate(0, dot_name, OBJ_ARROW, 0, last_bar_time, last_trailing_stop);
      ObjectSetInteger(0, dot_name, OBJPROP_ARROWCODE, 159);
      ObjectSetInteger(0, dot_name, OBJPROP_COLOR, (last_pos == 1 ? clrLime : clrRed));
      ObjectSetInteger(0, dot_name, OBJPROP_WIDTH, 2);
     }
   
   double src = close[1];      // Yopilgan eng oxirgi svecha
   double src_1 = close[2];    // Undan bitta oldingi svecha
   double xATR = atr[1];
   double nLoss = InpKeyValue * xATR;

   double curr_trailing_stop = 0.0;
   
   if(last_trailing_stop == 0) last_trailing_stop = src_1;
   
   if(src > last_trailing_stop && src_1 > last_trailing_stop)
      curr_trailing_stop = MathMax(last_trailing_stop, src - nLoss);
   else if(src < last_trailing_stop && src_1 < last_trailing_stop)
      curr_trailing_stop = MathMin(last_trailing_stop, src + nLoss);
   else if(src > last_trailing_stop)
      curr_trailing_stop = src - nLoss;
   else
      curr_trailing_stop = src + nLoss;
      
   int curr_pos = last_pos;
   if(src_1 < last_trailing_stop && src > last_trailing_stop) curr_pos = 1;      // BUY SIGNAL
   else if(src_1 > last_trailing_stop && src < last_trailing_stop) curr_pos = -1; // SELL SIGNAL
   
   // Savdo logikasi
   if(curr_pos == 1 && last_pos != 1)
     {
      ClosePositions(POSITION_TYPE_SELL);
      trade.Buy(InpLots, _Symbol);
      last_buy_price = DoubleToString(src, _Digits);
      UpdateDashboardValues("BUY", clrLime);
     }
   else if(curr_pos == -1 && last_pos != -1)
     {
      ClosePositions(POSITION_TYPE_BUY);
      trade.Sell(InpLots, _Symbol);
      last_sell_price = DoubleToString(src, _Digits);
      UpdateDashboardValues("SELL", clrRed);
     }
     
   last_trailing_stop = curr_trailing_stop;
   last_pos = curr_pos;
   last_bar_time = current_time;
  }

//+------------------------------------------------------------------+
//| Close positions by type                                          |
//+------------------------------------------------------------------+
void ClosePositions(long t)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
        {
         if(PositionGetInteger(POSITION_TYPE) == t)
            trade.PositionClose(ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//| Dashboard Creaton                                                |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   // Asosiy Panel (Qora)
   ObjectCreate(0, "DB_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DB_BG", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "DB_BG", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, "DB_BG", OBJPROP_XSIZE, 300);
   ObjectSetInteger(0, "DB_BG", OBJPROP_YSIZE, 180);
   ObjectSetInteger(0, "DB_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, "DB_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   
   // Title
   CreateText("DB_TITLE", "UT BOT EA DASHBOARD", 30, 30, clrWhite, 12, true);
   
   // Signal
   CreateText("DB_SIGNAL_LBL", "Current Signal:", 30, 60, clrWhite, 10, false);
   CreateText("DB_SIGNAL_VAL", "NONE", 130, 60, clrYellow, 10, true);
   
   // 2 ta Ekrancha (Buy va Sell ma'lumotlari uchun)
   
   // Buy qutisi
   ObjectCreate(0, "DB_BUY_BOX", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DB_BUY_BOX", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, "DB_BUY_BOX", OBJPROP_YDISTANCE, 90);
   ObjectSetInteger(0, "DB_BUY_BOX", OBJPROP_XSIZE, 130);
   ObjectSetInteger(0, "DB_BUY_BOX", OBJPROP_YSIZE, 60);
   ObjectSetInteger(0, "DB_BUY_BOX", OBJPROP_BGCOLOR, clrDarkGreen);
   
   CreateText("DB_BUY_LBL", "LAST BUY:", 40, 100, clrWhite, 10, false);
   CreateText("DB_BUY_VAL", "N/A", 40, 120, clrLime, 10, true);
   
   // Sell qutisi
   ObjectCreate(0, "DB_SELL_BOX", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DB_SELL_BOX", OBJPROP_XDISTANCE, 170);
   ObjectSetInteger(0, "DB_SELL_BOX", OBJPROP_YDISTANCE, 90);
   ObjectSetInteger(0, "DB_SELL_BOX", OBJPROP_XSIZE, 130);
   ObjectSetInteger(0, "DB_SELL_BOX", OBJPROP_YSIZE, 60);
   ObjectSetInteger(0, "DB_SELL_BOX", OBJPROP_BGCOLOR, clrMaroon);
   
   CreateText("DB_SELL_LBL", "LAST SELL:", 180, 100, clrWhite, 10, false);
   CreateText("DB_SELL_VAL", "N/A", 180, 120, clrRed, 10, true);
  }

void CreateText(string name, string text, int x, int y, color clr, int size = 10, bool bold = false)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
  }

void UpdateDashboardValues(string curr_sig, color sig_clr)
  {
   ObjectSetString(0, "DB_SIGNAL_VAL", OBJPROP_TEXT, curr_sig);
   ObjectSetInteger(0, "DB_SIGNAL_VAL", OBJPROP_COLOR, sig_clr);
   
   ObjectSetString(0, "DB_BUY_VAL", OBJPROP_TEXT, last_buy_price);
   ObjectSetString(0, "DB_SELL_VAL", OBJPROP_TEXT, last_sell_price);
   
   ChartRedraw();
  }
//+------------------------------------------------------------------+