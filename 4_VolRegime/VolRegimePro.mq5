//+------------------------------------------------------------------+
//|                                                 VolRegimePro.mq5 |
//|                                  Copyright 2026, Auto-Generated  |
//|   Pro Robot with Volume Profile (FRVP) and Risk Management       |
//+------------------------------------------------------------------+
#property copyright   "Auto-Generated"
#property version     "2.00"

#include <Trade\Trade.mqh>

//--- Settings
input double   InpLots        = 0.01;      // Lot o'lchami
input int      InpSmaLookback = 200;       // SMA 200 Periodi (Asosiy Trend)
input int      InpEmaFast     = 20;        // Signal kuchi uchun (Fast EMA)
input int      InpVPPeriod    = 300;       // Volume Profile uchun bar miqdori
input int      InpSL          = 500;       // Asosiy Stop Loss (points)
input double   InpRR          = 2.0;       // Risk/Reward (1:2 -> 2.0, 1:3 -> 3.0)
input ulong    InpMagicNum    = 888888;    // Magic Number

CTrade         trade;

//--- Handles 
int            sma_handle;
int            ema_handle;

//--- State Dashboard & Engine
datetime       last_bar_time;
string         current_regime = "WAIT";
string         current_signal = "OBSERVAR";
color          signal_color   = clrGray;

//--- Volume Profile State
double         poc_level = 0;  // Point of Control
double         vah_level = 0;  // Value Area High (Qarshilik)
double         val_level = 0;  // Value Area Low (Qo'llab-quvvatlash)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNum);
   
   // --- CHART DIZAYNI (PRO QORA FON VA MAXSUS SVECHALAR) ---
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_GRID, clrNONE);
   
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrAqua);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrDeepPink);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrAqua);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrDeepPink);
   ChartSetInteger(0, CHART_COLOR_VOLUME, clrDimGray);
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   
   // --- INDICATOR HANDLES ---
   sma_handle = iMA(_Symbol, _Period, InpSmaLookback, 0, MODE_SMA, PRICE_CLOSE);
   ema_handle = iMA(_Symbol, _Period, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   
   CreateProDashboard();
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "PRO_"); // Dashboardni tozalash
   ObjectDelete(0, "VP_POC");
   ObjectDelete(0, "VP_VAH");
   ObjectDelete(0, "VP_VAL");
  }

//+------------------------------------------------------------------+
//| Calculate Fixed Range Volume Profile (FRVP)                      |
//+------------------------------------------------------------------+
void CalculateVolumeProfile()
  {
   double high[], low[];
   long vol[];
   if(CopyHigh(_Symbol, _Period, 0, InpVPPeriod, high) <= 0) return;
   if(CopyLow(_Symbol, _Period, 0, InpVPPeriod, low) <= 0) return;
   if(CopyTickVolume(_Symbol, _Period, 0, InpVPPeriod, vol) <= 0) return;

   double HH = high[ArrayMaximum(high)];
   double LL = low[ArrayMinimum(low)];

   if(HH == LL) return;

   int bins = 50; // 50 ta profil qatorlari
   double step = (HH - LL) / bins;
   double profile[];
   ArrayResize(profile, bins);
   ArrayInitialize(profile, 0.0);

   double total_vol = 0;

   // Volume larni taqsimlash
   for(int i=0; i<InpVPPeriod; i++)
     {
      int bin_start = (int)((low[i] - LL) / step);
      int bin_end = (int)((high[i] - LL) / step);
      
      if(bin_start < 0) bin_start = 0;
      if(bin_end >= bins) bin_end = bins - 1;

      int span = bin_end - bin_start + 1;
      double v = (double)vol[i] / span;
      for(int b=bin_start; b<=bin_end; b++)
        {
         profile[b] += v;
        }
      total_vol += vol[i];
     }

   // Point of Control (POC) ni topish
   int poc_idx = ArrayMaximum(profile);
   poc_level = LL + (poc_idx * step) + (step / 2.0);

   // Value Area (70% hajm aylanayotgan zona) ni hisoblash
   double sum_vol = profile[poc_idx];
   int up_idx = poc_idx;
   int dn_idx = poc_idx;

   while(sum_vol < total_vol * 0.70)
     {
      double v_up = (up_idx < bins - 1) ? profile[up_idx+1] : -1;
      double v_dn = (dn_idx > 0) ? profile[dn_idx-1] : -1;

      if(v_up > v_dn && v_up != -1) {
         up_idx++; sum_vol += profile[up_idx];
      } 
      else if(v_dn > v_up && v_dn != -1) {
         dn_idx--; sum_vol += profile[dn_idx];
      } 
      else if(v_up != -1 && v_dn != -1) {
         up_idx++; dn_idx--;
         sum_vol += profile[up_idx] + profile[dn_idx];
      } 
      else {
         break;
      }
     }

   vah_level = LL + (up_idx * step) + (step / 2.0);
   val_level = LL + (dn_idx * step) + (step / 2.0);
   
   // Ekranga chiziqlarni tortish
   DrawLine("VP_VAH", vah_level, clrRed, STYLE_SOLID);     // Qizil qarshilik
   DrawLine("VP_POC", poc_level, clrYellow, STYLE_DASH);   // Asosiy hajm (Sariq)
   DrawLine("VP_VAL", val_level, clrLime, STYLE_SOLID);    // Yashil qo'llab quvvatlash
  }

void DrawLine(string name, double price, color clr, ENUM_LINE_STYLE style)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
     }
   else
     {
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
     }
  }

//+------------------------------------------------------------------+
//| Manage Risk (Bitimlarni yopish)                                  |
//+------------------------------------------------------------------+
void ManageRiskLevels()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
        {
         long type = PositionGetInteger(POSITION_TYPE);
         double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

         // BUY uchun Value Area High (VAH) Qarshilik (Resistance) hisoblanadi
         if(type == POSITION_TYPE_BUY)
           {
            if(current_bid >= vah_level && current_bid > open_price)
              {
               trade.PositionClose(ticket);
               Print("Risk Management: BUY yopildi (Kuchli qarshilik VAH ga yetdi!)");
              }
           }
         // SELL uchun Value Area Low (VAL) Qo'llab-quvvatlash (Support) hisoblanadi
         else if(type == POSITION_TYPE_SELL)
           {
            if(current_ask <= val_level && current_ask < open_price)
              {
               trade.PositionClose(ticket);
               Print("Risk Management: SELL yopildi (Kuchli support VAL ga yetdi!)");
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   CalculateVolumeProfile(); // VP ni hisoblash va yangilash
   ManageRiskLevels();       // Bitimlarni Qarshilik zonalarda avto yopish
   UpdateDashboardLive();    // Dashboard ma'lumotlarini yangilash
   
   datetime current_time = iTime(_Symbol, _Period, 0);
   if(current_time == last_bar_time) return; 
   
   double sma[], ema[], close[];
   ArraySetAsSeries(sma, true);
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(close, true);
   
   if(CopyBuffer(sma_handle, 0, 0, 3, sma) <= 0) return;
   if(CopyBuffer(ema_handle, 0, 0, 3, ema) <= 0) return;
   if(CopyClose(_Symbol, _Period, 0, 3, close) <= 0) return;
   
   double src = close[1];
   double sma_val = sma[1];
   double ema_val = ema[1];
   double ema_prev = ema[2];
   double sma_prev = sma[2];
   
   bool isBullish = (src > sma_val);
   bool isBearish = (src < sma_val);
   
   if(isBullish) { current_regime = "COHERENTE (BULL)"; current_signal = "COMPRAR (ACT)"; signal_color = clrAqua; }
   else if(isBearish) { current_regime = "DISLOCADO (BEAR)"; current_signal = "MANTENER (HOLD)"; signal_color = clrDeepPink; }
   else { current_regime = "STRESSED"; current_signal = "ESPERAR (WAIT)"; signal_color = clrYellow; }
   
   // Savdo Signali: EMA>SMA kesishganda BUY
   bool buy_sig = (ema_prev <= sma_prev && ema_val > sma_val);
   bool sell_sig = (ema_prev >= sma_prev && ema_val < sma_val);
   
   if(buy_sig || sell_sig) Print("Signal received --> BUY: ", buy_sig, " | SELL: ", sell_sig);

   if(buy_sig)
     {
      ClosePositions(POSITION_TYPE_SELL);
      int my_pos = 0;
      for(int p = 0; p < PositionsTotal(); p++) {
         ulong tkt = PositionGetTicket(p);
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum) my_pos++;
      }
      if(my_pos == 0)
        {
         double c_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = (InpSL > 0) ? NormalizeDouble(c_ask - (InpSL * _Point), _Digits) : 0;
         double tp = (InpSL > 0) ? NormalizeDouble(c_ask + (InpSL * InpRR * _Point), _Digits) : 0;
         trade.Buy(InpLots, _Symbol, c_ask, sl, tp, "VolRegime Buy");
        }
     }
   else if(sell_sig)
     {
      ClosePositions(POSITION_TYPE_BUY);
      int my_pos = 0;
      for(int p = 0; p < PositionsTotal(); p++) {
         ulong tkt = PositionGetTicket(p);
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNum) my_pos++;
      }
      if(my_pos == 0)
        {
         double c_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = (InpSL > 0) ? NormalizeDouble(c_bid + (InpSL * _Point), _Digits) : 0;
         double tp = (InpSL > 0) ? NormalizeDouble(c_bid - (InpSL * InpRR * _Point), _Digits) : 0;
         trade.Sell(InpLots, _Symbol, c_bid, sl, tp, "VolRegime Sell");
        }
     }
     
   last_bar_time = current_time;
  }

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
//| PRO DASHBOARD CREATION                                           |
//+------------------------------------------------------------------+
void CreateProDashboard()
  {
   string p = "PRO_";
   color bg = C'13,13,17';        
   color border = C'43,45,58';    
   color txtMain = clrWhite;
   color txtDim = clrSilver;
   
   ObjectCreate(0, p+"BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, p+"BG", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, p+"BG", OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, p+"BG", OBJPROP_XSIZE, 350);
   ObjectSetInteger(0, p+"BG", OBJPROP_YSIZE, 360); // Balandligi kattalashdi VP uchun
   ObjectSetInteger(0, p+"BG", OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, p+"BG", OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, p+"BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   // Header
   CreateText(p+"H1", "VOL REGIME COMPASS [N4] + VP", 50, 40, clrAqua, 12, true);
   CreateText(p+"H2", "SMART RISK MGMT ENGINE", 50, 60, clrLime, 8, false);
   
   // Account Info
   CreateText(p+"L_Bal", "BALANCE:", 50, 95, txtDim, 10, false);
   CreateText(p+"V_Bal", "$0.00", 150, 95, txtMain, 10, true);
   
   CreateText(p+"L_Eq", "EQUITY:", 50, 115, txtDim, 10, false);
   CreateText(p+"V_Eq", "$0.00", 150, 115, txtMain, 10, true);
   
   // Volume Profile info (Qarshilik va Qo'llab-quvvatlash zonalari)
   CreateText(p+"L_VP_Hdr", "--- VOLUME PROFILE RISK ZONES ---", 50, 145, clrSlateGray, 9, true);
   
   CreateText(p+"L_VAH", "VAH (RESIST):", 50, 165, clrRed, 10, false);
   CreateText(p+"V_VAH", "0.00000", 150, 165, txtMain, 10, true);
   
   CreateText(p+"L_POC", "POC (CONTROL):", 50, 185, clrYellow, 10, false);
   CreateText(p+"V_POC", "0.00000", 150, 185, txtMain, 10, true);
   
   CreateText(p+"L_VAL", "VAL (SUPPORT):", 50, 205, clrLime, 10, false);
   CreateText(p+"V_VAL", "0.00000", 150, 205, txtMain, 10, true);
   
   // Signal Box
   ObjectCreate(0, p+"BOX_SIG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, p+"BOX_SIG", OBJPROP_XDISTANCE, 50);
   ObjectSetInteger(0, p+"BOX_SIG", OBJPROP_YDISTANCE, 240);
   ObjectSetInteger(0, p+"BOX_SIG", OBJPROP_XSIZE, 250);
   ObjectSetInteger(0, p+"BOX_SIG", OBJPROP_YSIZE, 90);
   ObjectSetInteger(0, p+"BOX_SIG", OBJPROP_BGCOLOR, C'22,24,33');
   ObjectSetInteger(0, p+"BOX_SIG", OBJPROP_BORDER_COLOR, clrNONE);
   
   CreateText(p+"L_Regime", "REGIMEN:", 65, 255, txtDim, 9, false);
   CreateText(p+"V_Regime", "WAITING...", 140, 255, clrWhite, 9, true);
   
   CreateText(p+"L_Sig", "VERBO:", 65, 280, txtDim, 10, false);
   CreateText(p+"V_Sig", "ESPERAR", 140, 278, clrGray, 12, true);
  }

void CreateText(string name, string text, int x, int y, color clr, int size = 10, bool bold = false)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Trebuchet MS Bold" : "Trebuchet MS");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  }

//+------------------------------------------------------------------+
//| Dashboard Live Updates                                           |
//+------------------------------------------------------------------+
void UpdateDashboardLive()
  {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   
   ObjectSetString(0, "PRO_V_Bal", OBJPROP_TEXT, "$" + DoubleToString(bal, 2));
   ObjectSetString(0, "PRO_V_Eq", OBJPROP_TEXT, "$" + DoubleToString(eq, 2));
   
   if(eq > bal) ObjectSetInteger(0, "PRO_V_Eq", OBJPROP_COLOR, clrLime);
   else if(eq < bal) ObjectSetInteger(0, "PRO_V_Eq", OBJPROP_COLOR, clrDeepPink);
   else ObjectSetInteger(0, "PRO_V_Eq", OBJPROP_COLOR, clrWhite);
   
   // VP Values update
   ObjectSetString(0, "PRO_V_VAH", OBJPROP_TEXT, DoubleToString(vah_level, _Digits));
   ObjectSetString(0, "PRO_V_POC", OBJPROP_TEXT, DoubleToString(poc_level, _Digits));
   ObjectSetString(0, "PRO_V_VAL", OBJPROP_TEXT, DoubleToString(val_level, _Digits));
   
   // Regime Info update
   ObjectSetString(0, "PRO_V_Regime", OBJPROP_TEXT, current_regime);
   ObjectSetString(0, "PRO_V_Sig", OBJPROP_TEXT, current_signal);
   ObjectSetInteger(0, "PRO_V_Sig", OBJPROP_COLOR, signal_color);
   
   ChartRedraw();
  }
//+------------------------------------------------------------------+