//+------------------------------------------------------------------+
//|                                              OmniVisualPro.mq5   |
//|                                  Copyright 2026, Auto-Generated  |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   5

//--- Settings: Trend & Gannzilla
input float    InpPriceStep = 0.125;      // Gann Step
input int      InpEmaLen    = 10;         // Trend Tekisligi (EMA)
//--- Settings: Support & Resistance Zonalari
input int      InpLeftLen   = 15;         // S/R Analiz Chap
input int      InpRightLen  = 10;         // S/R Analiz O'ng
//--- Settings: Seanslar (Broker vaqti orqali moslanadi)
input bool     InpShowSess  = true;       // Seanslarni ko'rsatish
input string   InpTokyoTime = "00:00-09:00"; // Tokyo Session
input string   InpLondonTime= "08:00-17:00"; // London Session
input string   InpNewYorkTime="13:00-22:00"; // NY Session

//--- Indicator buffers
double         TrendEmaBuffer[];
double         TrendEmaColors[]; // Color buffer for EMA
double         ResLevelBuffer[];
double         SupLevelBuffer[];
double         BuySignalBuffer[];
double         SellSignalBuffer[];
double         TrendStateBuffer[]; // Internal buffer for trend state
double         High30Buffer[];     // Internal
double         Low30Buffer[];      // Internal

//--- Globals
int            ema_handle;
double         ema_array[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, TrendEmaBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_DASHDOT);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrMediumSpringGreen);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrCrimson);
   SetIndexBuffer(1, TrendEmaColors, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(2, ResLevelBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_DOT);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrRed);

   SetIndexBuffer(3, SupLevelBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, STYLE_DOT);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrGreen);

   SetIndexBuffer(4, BuySignalBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(3, PLOT_ARROW, 233);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrMediumSpringGreen);

   SetIndexBuffer(5, SellSignalBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(4, PLOT_ARROW, 234);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, clrCrimson);

   SetIndexBuffer(6, TrendStateBuffer, INDICATOR_CALCULATIONS);
   
   ema_handle = iMA(_Symbol, _Period, InpEmaLen, 0, MODE_EMA, PRICE_CLOSE);
   ArraySetAsSeries(ema_array, true);
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Get Gann Value                                                   |
//+------------------------------------------------------------------+
double GetGann(double p, double s)
  {
   if(p < 0) return 0;
   return MathPow(MathSqrt(p) + s, 2);
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
   if(rates_total < 35 || rates_total < InpLeftLen + InpRightLen + 1)
      return(0);

   int start = (prev_calculated > 35) ? prev_calculated - 1 : 35;
   
   if(CopyBuffer(ema_handle, 0, 0, rates_total, ema_array) <= 0) return 0;

   // Simple sessions draw via Objects (Background rectangles)
   // We will plot basic rectangles if needed, omitted in this real-time loop to save performance, 
   // but can be added. The signals and trend logic:

   for(int i = start; i < rates_total; i++)
     {
      double max_h = high[i];
      double min_l = low[i];
      for(int j = 0; j < 30; j++)
        {
         if(i-j >= 0)
           {
            if(high[i-j] > max_h) max_h = high[i-j];
            if(low[i-j] < min_l) min_l = low[i-j];
           }
        }
      
      double g_res = GetGann(min_l, InpPriceStep * 2);
      double g_sup = GetGann(max_h, -InpPriceStep * 2);

      int prev_trend_val = (i > 0) ? (int)TrendStateBuffer[i-1] : 0;
      int curr_trend_val = prev_trend_val;

      // Crossover close and g_res
      if(i > 0 && close[i-1] <= g_res && close[i] > g_res)
         curr_trend_val = 1;
      // Crossunder close and g_sup
      if(i > 0 && close[i-1] >= g_sup && close[i] < g_sup)
         curr_trend_val = -1;

      TrendStateBuffer[i] = curr_trend_val;

      // Plot EMA
      TrendEmaBuffer[i] = ema_array[rates_total - 1 - i]; // Reverse if ArraySetAsSeries is true
      TrendEmaColors[i] = (curr_trend_val == 1) ? 0 : 1;

      // Buy/Sell Signals
      BuySignalBuffer[i] = EMPTY_VALUE;
      SellSignalBuffer[i] = EMPTY_VALUE;

      if(curr_trend_val == 1 && prev_trend_val != 1)
         BuySignalBuffer[i] = low[i] - 10 * _Point;
      if(curr_trend_val == -1 && prev_trend_val != -1)
         SellSignalBuffer[i] = high[i] + 10 * _Point;

      // S/R Levels
      double ph = EMPTY_VALUE;
      double pl = EMPTY_VALUE;
      
      bool isPivotH = true;
      bool isPivotL = true;
      
      int pivotIndex = i - InpRightLen;
      if(pivotIndex >= InpLeftLen)
        {
         for(int z = 1; z <= InpLeftLen; z++)
           {
            if(high[pivotIndex - z] > high[pivotIndex]) isPivotH = false;
            if(low[pivotIndex - z]  < low[pivotIndex])  isPivotL = false;
           }
         for(int z = 1; z <= InpRightLen; z++)
           {
            if(high[pivotIndex + z] > high[pivotIndex]) isPivotH = false;
            if(low[pivotIndex + z]  < low[pivotIndex])  isPivotL = false;
           }
           
         if(isPivotH) ph = high[pivotIndex];
         if(isPivotL) pl = low[pivotIndex];
        }
        
      if(ph != EMPTY_VALUE) ResLevelBuffer[i] = ph; else ResLevelBuffer[i] = (i>0) ? ResLevelBuffer[i-1] : EMPTY_VALUE;
      if(pl != EMPTY_VALUE) SupLevelBuffer[i] = pl; else SupLevelBuffer[i] = (i>0) ? SupLevelBuffer[i-1] : EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+