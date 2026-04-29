//+------------------------------------------------------------------+
//|                                           VolRegimeCompassEA.mq5 |
//|                                     Copyright 2026, Auto-Gen     |
//+------------------------------------------------------------------+
#property copyright "EA Generator"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- Inputs
input string   InpSect1       = "--- Risk Management ---";
input int      InpPosCount    = 3;        // Bitta signalda ochiladigan bitimlar soni
input double   InpRiskPercent = 1.0;      // Risk% per Trade
input double   InpRRR         = 1.3;      // Risk:Reward Ratio (e.g. 1.2, 1.3, 1.4)
input double   InpATRMulti    = 1.5;      // ATR Multiplier for Stop Loss
input int      InpATRPeriod   = 14;       // ATR Period
input int      InpMagic       = 7772026;  // Magic Number

input string   InpSect2       = "--- Indicator Setup ---";
input string   InpIndiName    = "VolRegimeCompassN4"; // Indicator file path

// Indicatorni EA ichiga yashirish (qotirish) uchun resource:
// #resource "VolRegimeCompassN4.ex5"

//--- Globals
CTrade         trade;
int            handle_vrc;
int            handle_atr;
datetime       last_bar_time;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   
   // Ekran va svecha ranglari sozlamalari
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_GRID, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrLightGreen);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrPink);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrLightGreen);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrPink);
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   
   // Initialize Indicators
   handle_vrc = iCustom(_Symbol, _Period, "VolRegimeCompassN4");
   if(handle_vrc == INVALID_HANDLE)
      handle_vrc = iCustom(_Symbol, _Period, "\\Experts\\VolRegimeCompassN4");
   if(handle_vrc == INVALID_HANDLE)
      handle_vrc = iCustom(_Symbol, _Period, "\\Indicators\\VolRegimeCompassN4");
   if(handle_vrc == INVALID_HANDLE)
      handle_vrc = iCustom(_Symbol, _Period, "\\Experts\\4_VolRegime\\VolRegimeCompassN4");

   if(handle_vrc == INVALID_HANDLE)
     {
      Print("DIQQAT XATO: VolRegimeCompassN4.ex5 indikatori topilmadi!");
      Print("Iltimos buni bajaring: MetaEditorga o'tib, avval VolRegimeCompassN4.mq5 ni ochib COMPILE (F7) ni bosing.");
      Print("Va shundan keyingina EA ni kompile qilib ishlating!");
      return(INIT_FAILED);
     }
     
   handle_atr = iATR(_Symbol, _Period, InpATRPeriod);
   if(handle_atr == INVALID_HANDLE)
     {
      Print("Error loading ATR");
      return(INIT_FAILED);
     }

   CreateDashboard();
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "VREA_");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // TP1 yopilgandan so'ng StopLossni foydaga surish funksiyasi (har bir tickda ishlaydi)
   CheckTrailingStop();

   // Check for new bar
   datetime current_time = iTime(_Symbol, _Period, 0);
   if(current_time == last_bar_time) return;

   // Update Dashboard on new tick/bar
   UpdateDashboard();

   // Buffers for indicator
   double color_buf[];
   double atr_buf[];
   
   // We look at completed bar (index 1) and previous bar (index 2)
   if(CopyBuffer(handle_vrc, 2, 1, 2, color_buf) <= 0) return;
   if(CopyBuffer(handle_atr, 0, 1, 1, atr_buf) <= 0) return;
   
   double curr_color = color_buf[1]; // Color of bar 1
   double prev_color = color_buf[0]; // Color of bar 2 (since CopyBuffer copies oldest first when normally indexed)
   
   double atr_val = atr_buf[0];
   
   // Check if we already have open positions (if >= InpPosCount, don't open)
   if(PositionsTotal() >= InpPosCount)
     {
      // Simplistic check, prevent more than max allowed trades
      return; 
     }

   // 0 = Primary (Bullish), 1 = Secondary (Bearish)
   bool buy_signal  = (prev_color == 1 && curr_color == 0);
   bool sell_signal = (prev_color == 0 && curr_color == 1);
   
   if(buy_signal || sell_signal)
     {
      last_bar_time = current_time;
      
      double sl_dist = atr_val * InpATRMulti;
      double tp_dist = sl_dist * InpRRR;
      
      double lot_size = CalculateLotSize(sl_dist);
      
      if(buy_signal)
        {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = ask - sl_dist;
         for(int i = 0; i < InpPosCount; i++)
           {
            double tp = ask + tp_dist + (i * tp_dist * 0.5); // Har bir bitimda TP uzoqroq qo'yiladi
            trade.Buy(lot_size, _Symbol, ask, sl, tp, "VRC Buy Signal " + IntegerToString(i+1));
           }
        }
      else if(sell_signal)
        {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = bid + sl_dist;
         for(int i = 0; i < InpPosCount; i++)
           {
            double tp = bid - tp_dist - (i * tp_dist * 0.5); // Har bir bitimda TP uzoqroq qo'yiladi
            trade.Sell(lot_size, _Symbol, bid, sl, tp, "VRC Sell Signal " + IntegerToString(i+1));
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Check Trailing Stop after 1st TP is hit                          |
//+------------------------------------------------------------------+
void CheckTrailingStop()
  {
   int total = PositionsTotal();
   // Agar ochiq pozitsiyalar soni InpPosCount dan kam (1 tasi TP da yopilgan) va 0 dan ko'p bo'lsa ishlaydi
   if(total == 0 || total >= InpPosCount) return;

   for(int i = total - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      long type = PositionGetInteger(POSITION_TYPE);
      
      if(type == POSITION_TYPE_BUY)
        {
         if(sl >= entry) continue; // Agar b/e (foydaga) allaqachon tushgan bo'lsa teginmaymiz
         
         double sl_dist = entry - sl;
         double tp1_dist = sl_dist * InpRRR;
         double new_sl = NormalizeDouble(entry + (tp1_dist / 2.0), _Digits); // Dastlabki TP masofasining yarmi
         
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > new_sl) // Narx yangi qo'yiladigan SL dan tepada (xavfsiz) ekanini tekshirish
           {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
           }
        }
      else if(type == POSITION_TYPE_SELL)
        {
         if(sl <= entry && sl != 0.0) continue; // Allaqachon foydaga surilgan
         
         double sl_dist = sl - entry;
         double tp1_dist = sl_dist * InpRRR;
         double new_sl = NormalizeDouble(entry - (tp1_dist / 2.0), _Digits); // Dastlabki TP masofasining yarmi
         
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask < new_sl || new_sl == 0.0) // Narx pastlab ketgan (xavfsiz) bo'lsa
           {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Check Consecutive Wins in History                                |
//+------------------------------------------------------------------+
int GetConsecutiveWins()
  {
   HistorySelect(0, TimeCurrent());
   int wins = 0;
   int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      long entry_type = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      // Faqat yopilgan bitimlarni hisobga olamiz
      if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_INOUT)
        {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(profit > 0) wins++;
         else break; // Agar minus chiqsa sanashni to'xtatadi
        }
     }
   return wins;
  }

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk %                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_distance)
  {
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(sl_distance == 0 || tick_size == 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   double risk_money = balance * (InpRiskPercent / 100.0);
   double sl_ticks = sl_distance / tick_size;
   double base_lot = risk_money / (sl_ticks * tick_value);
   
   // Har foydadan keyin ketma-ketlikni oshirib lot hajmiga o'zgartirish qoshamiz (Anti-Martingale)
   int wins = GetConsecutiveWins();
   // Foydadan keyin har doim hajmni 1 karra ko'paytiradi. (Masalan, 1-yutuq lot * 2, 2-yutuq lot * 3)
   double lot = base_lot * (1.0 + (double)wins); 
   
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathRound(lot / step_lot) * step_lot;
   
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;
   
   return lot;
  }

//+------------------------------------------------------------------+
//| GUI Dashboard Creating                                           |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   string prefix = "VREA_";
   color bgBase = clrBlack;
   color fgText = clrWhite;
   color accent = clrDeepSkyBlue;
   
   // Background base
   ObjectCreate(0, prefix+"BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_YDISTANCE, 60);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_XSIZE, 240);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_YSIZE, 160);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_BORDER_COLOR, clrAqua);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_BORDER_TYPE, BORDER_SUNKEN);

   CreateLbl(prefix+"Title", "VOL REGIME PRO SCREEN", 30, 70, clrAqua, 10, true);
   CreateLbl(prefix+"RiskStr", "Risk / RRR:", 30, 100, clrLightGray, 9, false);
   CreateLbl(prefix+"RiskVal", DoubleToString(InpRiskPercent,1) + "% | " + "1:" + DoubleToString(InpRRR,1), 120, 100, fgText, 9, true);

   CreateLbl(prefix+"BalStr", "Balance:", 30, 120, clrLightGray, 9, false);
   CreateLbl(prefix+"BalVal", "-", 120, 120, fgText, 9, true);

   CreateLbl(prefix+"StateStr", "Agent State:", 30, 140, clrLightGray, 9, false);
   CreateLbl(prefix+"StateVal", "WAITING...", 120, 140, clrGold, 9, true);
   
   CreateLbl(prefix+"PosStr", "Active Pos:", 30, 160, clrLightGray, 9, false);
   CreateLbl(prefix+"PosVal", "-", 120, 160, fgText, 9, true);
  }

void CreateLbl(string name, string text, int x, int y, color clr, int size, bool bold)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Trebuchet MS Bold" : "Trebuchet MS");
  }

void UpdateDashboard()
  {
   ObjectSetString(0, "VREA_BalVal", OBJPROP_TEXT, DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   
   int posTotal = PositionsTotal();
   if(posTotal > 0)
     {
      ObjectSetString(0, "VREA_StateVal", OBJPROP_TEXT, "IN TRADE");
      ObjectSetInteger(0, "VREA_StateVal", OBJPROP_COLOR, clrLimeGreen);
      ObjectSetString(0, "VREA_PosVal", OBJPROP_TEXT, IntegerToString(posTotal) + " pos open");
     }
   else
     {
      ObjectSetString(0, "VREA_StateVal", OBJPROP_TEXT, "SCANNING...");
      ObjectSetInteger(0, "VREA_StateVal", OBJPROP_COLOR, clrGold);
      ObjectSetString(0, "VREA_PosVal", OBJPROP_TEXT, "None");
     }
  }
//+------------------------------------------------------------------+
