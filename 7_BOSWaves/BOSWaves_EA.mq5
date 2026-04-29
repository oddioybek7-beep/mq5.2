//+------------------------------------------------------------------+
//|                                                   BOSWaves_EA.mq5|
//|                                     Copyright 2026, Auto-Gen     |
//+------------------------------------------------------------------+
#property copyright "EA Generator"
#property version   "1.00"

#include <Trade\Trade.mqh>

enum ENUM_RRR
  {
   RRR_1_2 = 120, // 1:1.2
   RRR_1_3 = 130, // 1:1.3
   RRR_1_4 = 140  // 1:1.4
  };

//--- Inputs
input string     InpSect1       = "--- Risk Management ---";
input int        InpPosCount    = 3;        // Bitta signalda ochiladigan bitimlar soni
input double     InpRiskPercent = 1.0;      // Risk% per Trade
input ENUM_RRR   InpRRR_Mode    = RRR_1_3;  // Risk:Reward Ratio (Tanlang)
input double     InpATRMulti    = 1.5;      // ATR Multiplier for Stop Loss
input int        InpATRPeriod   = 14;       // ATR Period
input int        InpMagic       = 7000100;  // Magic Number

input string     InpSect2       = "--- Indicator Setup ---";
input string     InpIndiName    = "BOSWavesN5"; // Indicator file name

//--- Globals
CTrade           trade;
int              handle_bos;
int              handle_atr;
datetime         last_bar_time;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   
   // Ekran va svecha ranglari zamonaviy (Modern BOSWaves Design)
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhiteSmoke);
   ChartSetInteger(0, CHART_COLOR_GRID, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrSpringGreen);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrCrimson);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrSpringGreen);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrCrimson);
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   
   // Initialize Indicators
   handle_bos = iCustom(_Symbol, _Period, InpIndiName);
   if(handle_bos == INVALID_HANDLE)
      handle_bos = iCustom(_Symbol, _Period, "\\Experts\\7_BOSWaves\\BOSWavesN5");
   if(handle_bos == INVALID_HANDLE)
      handle_bos = iCustom(_Symbol, _Period, "7_BOSWaves\\BOSWavesN5");

   if(handle_bos == INVALID_HANDLE)
     {
      Print("DIQQAT XATO: BOSWavesN5.ex5 indikatori topilmadi!");
      Print("Iltimos, avval MQL5/Experts/7_BOSWaves dagi BOSWavesN5.mq5 ni ochib COMPILE qiling!");
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
   ObjectsDeleteAll(0, "BOS_");
  }

//+------------------------------------------------------------------+
//| Get RRR multiplier                                               |
//+------------------------------------------------------------------+
double GetRRR()
  {
   if(InpRRR_Mode == RRR_1_2) return 1.2;
   if(InpRRR_Mode == RRR_1_3) return 1.3;
   if(InpRRR_Mode == RRR_1_4) return 1.4;
   return 1.3;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check Trailing Stop logic
   CheckTrailingStop();

   // Check for new bar
   datetime current_time = iTime(_Symbol, _Period, 0);
   if(current_time == last_bar_time) return;

   UpdateDashboard();

   double tr_buf[];
   double atr_buf[];
   
   // Buy, Sell states are stored in Hidden Trend Buffer (buffer index 3)
   // 1 = Bullish Trend, -1 = Bearish Trend
   if(CopyBuffer(handle_bos, 3, 1, 2, tr_buf) <= 0) return;
   if(CopyBuffer(handle_atr, 0, 1, 1, atr_buf) <= 0) return;
   
   double curr_trend = tr_buf[1]; // Trend of last closed bar
   double prev_trend = tr_buf[0]; // Trend of bar before last
   
   double atr_val = atr_buf[0];
   
   if(PositionsTotal() >= InpPosCount) return;

   bool buy_signal  = (prev_trend == -1 && curr_trend == 1);
   bool sell_signal = (prev_trend == 1 && curr_trend == -1);
   
   if(buy_signal || sell_signal)
     {
      last_bar_time = current_time;
      
      double sl_dist = atr_val * InpATRMulti;
      double rrr_multi = GetRRR();
      double tp_dist = sl_dist * rrr_multi;
      
      double lot_size = CalculateLotSize(sl_dist);
      
      if(buy_signal)
        {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = ask - sl_dist;
         for(int i = 0; i < InpPosCount; i++)
           {
            double tp = ask + tp_dist + (i * tp_dist * 0.5); 
            trade.Buy(lot_size, _Symbol, ask, sl, tp, "BOSWaves Buy " + IntegerToString(i+1));
           }
        }
      else if(sell_signal)
        {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = bid + sl_dist;
         for(int i = 0; i < InpPosCount; i++)
           {
            double tp = bid - tp_dist - (i * tp_dist * 0.5);
            trade.Sell(lot_size, _Symbol, bid, sl, tp, "BOSWaves Sell " + IntegerToString(i+1));
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
   if(total == 0 || total >= InpPosCount) return;

   for(int i = total - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      long type = PositionGetInteger(POSITION_TYPE);
      double rrr_multi = GetRRR();
      
      if(type == POSITION_TYPE_BUY)
        {
         if(sl >= entry) continue;
         
         double sl_dist = entry - sl;
         double tp1_dist = sl_dist * rrr_multi;
         double new_sl = NormalizeDouble(entry + (tp1_dist / 2.0), _Digits);
         
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > new_sl) trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
        }
      else if(type == POSITION_TYPE_SELL)
        {
         if(sl <= entry && sl != 0.0) continue;
         
         double sl_dist = sl - entry;
         double tp1_dist = sl_dist * rrr_multi;
         double new_sl = NormalizeDouble(entry - (tp1_dist / 2.0), _Digits);
         
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask < new_sl || new_sl == 0.0) trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
        }
     }
  }

//+------------------------------------------------------------------+
//| Consecutive wins & Anti-Martingale logic                         |
//+------------------------------------------------------------------+
int GetConsecutiveWins()
  {
   HistorySelect(0, TimeCurrent());
   int wins = 0;
   int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;
      long entry_type = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_INOUT)
        {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(profit > 0) wins++;
         else break;
        }
     }
   return wins;
  }

double CalculateLotSize(double sl_distance)
  {
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(sl_distance == 0 || tick_size == 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   double risk_money = balance * (InpRiskPercent / 100.0);
   double sl_ticks = sl_distance / tick_size;
   double base_lot = risk_money / (sl_ticks * tick_value);
   
   int wins = GetConsecutiveWins();
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
//| Professional Dashboard                                           |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   string p = "BOS_";
   color accent = clrGold;
   
   ObjectCreate(0, p+"BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, p+"BG", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, p+"BG", OBJPROP_XDISTANCE, 270);
   ObjectSetInteger(0, p+"BG", OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, p+"BG", OBJPROP_XSIZE, 240);
   ObjectSetInteger(0, p+"BG", OBJPROP_YSIZE, 180);
   ObjectSetInteger(0, p+"BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, p+"BG", OBJPROP_BORDER_COLOR, accent);
   ObjectSetInteger(0, p+"BG", OBJPROP_BORDER_TYPE, BORDER_SUNKEN);
   
   CreateLbl(p+"Title", "BOS WAVES PRO ENGINE", 250, 60, accent, 11, true, CORNER_RIGHT_UPPER);
   CreateLbl(p+"Risk",  "Risk / RRR:", 250, 95, clrLightGray, 9, false, CORNER_RIGHT_UPPER);
   CreateLbl(p+"RVal",  DoubleToString(InpRiskPercent,1) + "% | 1:" + DoubleToString(GetRRR(),1), 120, 95, clrWhite, 9, true, CORNER_RIGHT_UPPER);

   CreateLbl(p+"Bal",   "Account Bal:", 250, 115, clrLightGray, 9, false, CORNER_RIGHT_UPPER);
   CreateLbl(p+"BVal",  "-", 120, 115, clrWhite, 9, true, CORNER_RIGHT_UPPER);

   CreateLbl(p+"State", "Signals:", 250, 135, clrLightGray, 9, false, CORNER_RIGHT_UPPER);
   CreateLbl(p+"SVal",  "SEARCHING", 120, 135, clrMagenta, 9, true, CORNER_RIGHT_UPPER);
   
   CreateLbl(p+"Lot",   "Next Lot Vol:", 250, 155, clrLightGray, 9, false, CORNER_RIGHT_UPPER);
   CreateLbl(p+"LVal",  "-", 120, 155, clrWhite, 9, true, CORNER_RIGHT_UPPER);
   
   CreateLbl(p+"Wins",  "Streak (Wins):", 250, 175, clrLightGray, 9, false, CORNER_RIGHT_UPPER);
   CreateLbl(p+"WVal",  "-", 120, 175, clrLime, 9, true, CORNER_RIGHT_UPPER);
   
   CreateLbl(p+"Brnd",  "© AI Assistant", 250, 205, clrDimGray, 8, false, CORNER_RIGHT_UPPER);
  }

void CreateLbl(string name, string text, int x, int y, color clr, int size, bool bold, ENUM_BASE_CORNER corner)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Century Gothic Bold" : "Century Gothic");
  }

void UpdateDashboard()
  {
   ObjectSetString(0, "BOS_BVal", OBJPROP_TEXT, DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   
   int posTotal = PositionsTotal();
   if(posTotal > 0)
     {
      ObjectSetString(0, "BOS_SVal", OBJPROP_TEXT, "IN MARKET ("+IntegerToString(posTotal)+")");
      ObjectSetInteger(0, "BOS_SVal", OBJPROP_COLOR, clrSpringGreen);
     }
   else
     {
      ObjectSetString(0, "BOS_SVal", OBJPROP_TEXT, "SEARCHING");
      ObjectSetInteger(0, "BOS_SVal", OBJPROP_COLOR, clrMagenta);
     }
     
   int wins = GetConsecutiveWins();
   ObjectSetString(0, "BOS_WVal", OBJPROP_TEXT, IntegerToString(wins)); // qancha marta yutayotgani
   
   // Calculate what next lot WILL be (assuming static SL logic for display)
   double sl_dist = 14 * 1.5 * SymbolInfoDouble(_Symbol, SYMBOL_POINT); // Just dummy for display
   double dummy_lot = CalculateLotSize(sl_dist); // Or show multiplier
   ObjectSetString(0, "BOS_LVal", OBJPROP_TEXT, "Multiplier " + DoubleToString(1.0+wins, 1)+"x");
  }
//+------------------------------------------------------------------+