//+------------------------------------------------------------------+
//|                                                        UTBot.mq5 |
//|                                  Copyright 2026, Auto-Generated  |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   3

//--- Plot 1: Trailing Stop Line
#property indicator_label1  "Trailing Stop"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGreen, clrRed, clrBlue
#property indicator_width1  2

//--- Plot 2: Buy Signal Arrow
#property indicator_label2  "Buy"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  2

//--- Plot 3: Sell Signal Arrow
#property indicator_label3  "Sell"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  2

//--- Settings
input double InpKeyValue = 3.0;      // Key Value (Sensitivity)
input int    InpAtrPeriod = 10;      // ATR Period

//--- Buffers
double       TrailingStopBuffer[];
double       TrailingStopColorBuffer[];
double       BuyBuffer[];
double       SellBuffer[];

//--- Internal buffers for state
double       StatePosBuffer[];
double       AtrBuffer[];

//--- ATR Handle
int          atr_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, TrailingStopBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, TrailingStopColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SellBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, AtrBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, StatePosBuffer, INDICATOR_CALCULATIONS);
   
   PlotIndexSetInteger(1, PLOT_ARROW, 233); // Arrow up
   PlotIndexSetInteger(2, PLOT_ARROW, 234); // Arrow down

   atr_handle = iATR(_Symbol, _Period, InpAtrPeriod);
   if(atr_handle == INVALID_HANDLE)
     {
      Print("Failed to create ATR indicator handle");
      return(INIT_FAILED);
     }
     
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < InpAtrPeriod + 1)
      return(0);

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 1;

   // Get ATR values
   if(CopyBuffer(atr_handle, 0, 0, rates_total, AtrBuffer) <= 0)
      return(0);

   // To iterate forwards, make sure arrays are evaluated correctly
   for(int i = start; i < rates_total; i++)
     {
      double src = close[i];
      double src_1 = close[i-1];
      double xATR = AtrBuffer[i];
      double nLoss = InpKeyValue * xATR;

      double xATRTrailingStop_1 = (i > 1) ? TrailingStopBuffer[i-1] : 0.0;
      double xATRTrailingStop_curr = 0.0;
      
      // Pine Script logic:
      // iff(src > nz(xATRTrailingStop[1], 0) and src[1] > nz(xATRTrailingStop[1], 0), max(nz(xATRTrailingStop[1]), src - nLoss),
      // iff(src < nz(xATRTrailingStop[1], 0) and src[1] < nz(xATRTrailingStop[1], 0), min(nz(xATRTrailingStop[1]), src + nLoss), 
      // iff(src > nz(xATRTrailingStop[1], 0), src - nLoss, src + nLoss)))

      if(src > xATRTrailingStop_1 && src_1 > xATRTrailingStop_1)
        {
         xATRTrailingStop_curr = MathMax(xATRTrailingStop_1, src - nLoss);
        }
      else if(src < xATRTrailingStop_1 && src_1 < xATRTrailingStop_1)
        {
         if(xATRTrailingStop_1 != 0.0)
            xATRTrailingStop_curr = MathMin(xATRTrailingStop_1, src + nLoss);
         else
            xATRTrailingStop_curr = src + nLoss;
        }
      else if(src > xATRTrailingStop_1)
        {
         xATRTrailingStop_curr = src - nLoss;
        }
      else
        {
         xATRTrailingStop_curr = src + nLoss;
        }

      TrailingStopBuffer[i] = xATRTrailingStop_curr;

      // Position logic:
      // pos := iff(src[1] < nz(xATRTrailingStop[1], 0) and src > nz(xATRTrailingStop[1], 0), 1,
      // iff(src[1] > nz(xATRTrailingStop[1], 0) and src < nz(xATRTrailingStop[1], 0), -1, nz(pos[1], 0))) 

      int pos_1 = (i > 1) ? (int)StatePosBuffer[i-1] : 0;
      int pos_curr = pos_1;

      if(src_1 < xATRTrailingStop_1 && src > xATRTrailingStop_1)
         pos_curr = 1;
      else if(src_1 > xATRTrailingStop_1 && src < xATRTrailingStop_1)
         pos_curr = -1;

      StatePosBuffer[i] = pos_curr;

      // Color assignment
      // xcolor = pos == -1 ? col.red : pos == 1 ? col.green : col.blue
      if(pos_curr == 1)
         TrailingStopColorBuffer[i] = 0; // index 0 is clrGreen
      else if(pos_curr == -1)
         TrailingStopColorBuffer[i] = 1; // index 1 is clrRed
      else
         TrailingStopColorBuffer[i] = 2; // index 2 is clrBlue

      // Buy & Sell Signals
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;

      bool crossover = (src_1 <= xATRTrailingStop_1 && src > xATRTrailingStop_curr);
      bool crossunder = (src_1 >= xATRTrailingStop_1 && src < xATRTrailingStop_curr);

      if(crossover)
         BuyBuffer[i] = low[i] - (5 * _Point);
      if(crossunder)
         SellBuffer[i] = high[i] + (5 * _Point);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+