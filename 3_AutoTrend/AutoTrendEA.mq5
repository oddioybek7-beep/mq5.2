//+------------------------------------------------------------------+
//|                                                  AutoTrendEA.mq5 |
//|                                  Copyright 2026, Auto-Generated  |
//+------------------------------------------------------------------+
#property copyright   "Auto-Generated"
#property version     "1.00"

#include <Trade\Trade.mqh>

input double   InpLots        = 0.01;      // Lot o'lchami ($10 balans uchun 0.01)
input int      InpLookback    = 10;        // Pivot Sezgirligi
input ulong    InpMagicNum    = 777777;    // Magic Number

CTrade         trade;

// Dashboard ma'lumotlari
string         last_buy_price = "N/A";
string         last_sell_price = "N/A";

// Holat o'zgaruvchilari
int            last_sig = 0;
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
   
   CreateDashboard();
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "DB_"); // Dashboard ob'yektlarini tozalash
   ObjectDelete(0, "EA_TrendHigh");
   ObjectDelete(0, "EA_TrendLow");
  }

//+------------------------------------------------------------------+
//| Pivotlarni qidirish funksiyasi (Indikatordagi kabi)              |
//+------------------------------------------------------------------+
void GetActivePivots(double &ph, double &pl, datetime &timeH, datetime &timeL)
  {
   double high[], low[];
   datetime time[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   
   int max_bars = 500;
   if(CopyHigh(_Symbol, _Period, 0, max_bars, high) <= 0) return;
   if(CopyLow(_Symbol, _Period, 0, max_bars, low) <= 0) return;
   if(CopyTime(_Symbol, _Period, 0, max_bars, time) <= 0) return;
   
   bool found_ph = false;
   bool found_pl = false;
   
   ph = 0; pl = 0;
   
   // Hozirgi bardan orqaga qarab eng so'nggi pivotlarni izlaymiz
   for(int i = InpLookback; i < max_bars - InpLookback; i++)
     {
      if(found_ph && found_pl) break;
      
      bool isPivotH = true;
      bool isPivotL = true;
      
      for(int j = 1; j <= InpLookback; j++)
        {
         if(high[i - j] > high[i] || high[i + j] >= high[i]) isPivotH = false;
         if(low[i - j] < low[i] || low[i + j] <= low[i]) isPivotL = false;
        }
        
      if(isPivotH && !found_ph) { ph = high[i]; timeH = time[i]; found_ph = true; }
      if(isPivotL && !found_pl) { pl = low[i]; timeL = time[i]; found_pl = true; }
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime current_time = iTime(_Symbol, _Period, 0);
   if(current_time == last_bar_time) return; // Faqat yangi yopiq svechada savdo qiladi
   
   double ph, pl;
   datetime timeH, timeL;
   GetActivePivots(ph, pl, timeH, timeL);
   
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, _Period, 0, 3, close) <= 0) return;
   
   // Hozirgi ekranga chiziqlarni chiqarish
   DrawLine("EA_TrendHigh", timeH, ph, current_time, ph, clrRed);
   DrawLine("EA_TrendLow", timeL, pl, current_time, pl, clrLime);
   
   double src = close[1];      // Yopilgan eng oxirgi svecha
   double src_1 = close[2];    // Undan bitta oldingi svecha
   
   int curr_sig = last_sig;
   
   // Breakout Strategiyasi: High Pivotdan tepaga yopilsa -> BUY, Low Pivotdan pastga yopilsa -> SELL
   if(ph > 0 && src_1 <= ph && src > ph) curr_sig = 1;
   if(pl > 0 && src_1 >= pl && src < pl) curr_sig = -1;
   
   // Savdo logikasi
   if(curr_sig == 1 && last_sig != 1)
     {
      ClosePositions(POSITION_TYPE_SELL);
      trade.Buy(InpLots, _Symbol);
      last_buy_price = DoubleToString(src, _Digits);
      UpdateDashboardValues("BUY", clrLime);
     }
   else if(curr_sig == -1 && last_sig != -1)
     {
      ClosePositions(POSITION_TYPE_BUY);
      trade.Sell(InpLots, _Symbol);
      last_sell_price = DoubleToString(src, _Digits);
      UpdateDashboardValues("SELL", clrRed);
     }
     
   last_sig = curr_sig;
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
   CreateText("DB_TITLE", "AUTO TREND EA DASHBOARD", 30, 30, clrWhite, 11, true);
   
   // Signal
   CreateText("DB_SIGNAL_LBL", "Current Signal:", 30, 60, clrWhite, 10, false);
   CreateText("DB_SIGNAL_VAL", "WAITING", 130, 60, clrYellow, 10, true);
   
   // Buy qutisi
   ObjectCreate(0, "DB_BUY_BOX", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DB_BUY_BOX", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, "DB_BUY_BOX", OBJPROP_YDISTANCE, 90);
   ObjectSetInteger(0, "DB_BUY_BOX", OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, "DB_BUY_BOX", OBJPROP_YSIZE, 60);
   ObjectSetInteger(0, "DB_BUY_BOX", OBJPROP_BGCOLOR, clrDarkGreen);
   
   CreateText("DB_BUY_LBL", "LAST BUY (BREAKOUT):", 40, 100, clrWhite, 9, false);
   CreateText("DB_BUY_VAL", "N/A", 40, 120, clrLime, 10, true);
   
   // Sell qutisi
   ObjectCreate(0, "DB_SELL_BOX", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "DB_SELL_BOX", OBJPROP_XDISTANCE, 160);
   ObjectSetInteger(0, "DB_SELL_BOX", OBJPROP_YDISTANCE, 90);
   ObjectSetInteger(0, "DB_SELL_BOX", OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, "DB_SELL_BOX", OBJPROP_YSIZE, 60);
   ObjectSetInteger(0, "DB_SELL_BOX", OBJPROP_BGCOLOR, clrMaroon);
   
   CreateText("DB_SELL_LBL", "LAST SELL (BREAKOUT):", 170, 100, clrWhite, 9, false);
   CreateText("DB_SELL_VAL", "N/A", 170, 120, clrRed, 10, true);
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
//| Ekranda chiziq chizish                                           |
//+------------------------------------------------------------------+
void DrawLine(string name, datetime t1, double p1, datetime t2, double p2, color clr)
  {
   if(p1 <= 0 || p2 <= 0 || t1 == 0) return;
   
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
     }
   else
     {
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
     }
  }
//+------------------------------------------------------------------+