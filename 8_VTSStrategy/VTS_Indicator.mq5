//+------------------------------------------------------------------+
//|                                                VTS_Indicator.mq5 |
//|                                  Copyright 2026, AI Assistant    |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   3

//--- plot Trail
#property indicator_label1  "TrailS"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime,clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- plot Buy
#property indicator_label2  "Buy Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  2

//--- plot Sell
#property indicator_label3  "Sell Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRed
#property indicator_width3  2

//--- inputs
input int    InpAtrPeriod = 35;        // ATR Period
input double InpAtrFactor = 1.2;       // ATR Factor
input int    InpStart = 1;             // Lookback Start
input int    InpEnd = 45;              // Lookback End
input int    InpThresL = 40;           // Long Threshold
input int    InpThresS = -10;          // Short Threshold

//--- indicator buffers
double         TrailSBuffer[];
double         TrailColors[];
double         BuyBuffer[];
double         SellBuffer[];

//--- handles
int            atrHandle;
double         atrBuffer[];
int            trendDir = 0; // 1 = long, -1 = short

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, TrailSBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, TrailColors, INDICATOR_COLOR_INDEX);
   
   SetIndexBuffer(2, BuyBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_ARROW, 233);
   
   SetIndexBuffer(3, SellBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(2, PLOT_ARROW, 234);

   atrHandle = iATR(_Symbol, _Period, InpAtrPeriod);
   if(atrHandle == INVALID_HANDLE) return(INIT_FAILED);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(TrailSBuffer, true);
   ArraySetAsSeries(TrailColors, true);
   ArraySetAsSeries(BuyBuffer, true);
   ArraySetAsSeries(SellBuffer, true);

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
   if(rates_total < InpEnd + InpAtrPeriod) return(0);
   int limit = rates_total - prev_calculated;
   if(limit == 0) limit = 1;
   
   if(CopyBuffer(atrHandle, 0, 0, limit + 1, atrBuffer) <= 0) return(0);
   
   ArraySetAsSeries(close, true);
   
   for(int i = limit - 1; i >= 0; i--)
     {
      double atr = atrBuffer[i];
      double band = atr * InpAtrFactor;
      
      double up = close[i] + band;
      double dn = close[i] - band;
      
      double prevTrail = (i + 1 < rates_total && TrailSBuffer[i+1] != 0.0 && TrailSBuffer[i+1] != EMPTY_VALUE) ? TrailSBuffer[i+1] : close[i];
      double trailS = prevTrail;
      
      if(dn > prevTrail) trailS = dn;
      if(up < prevTrail) trailS = up;
      
      TrailSBuffer[i] = trailS;
      
      double scoreS = 0;
      for(int j = InpStart; j <= InpEnd; j++)
        {
         if(i + j < rates_total)
           {
            scoreS += (trailS > TrailSBuffer[i + j]) ? 1 : -1;
           }
        }
        
      bool longCond = (scoreS > InpThresL);
      bool shortCond = (scoreS < InpThresS);
      
      int prevDir = trendDir;
      if(longCond && !shortCond) trendDir = 1;
      else if(shortCond) trendDir = -1;
      
      TrailColors[i] = (trendDir == 1) ? 0 : 1;
      
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;
      
      if(trendDir == 1 && prevDir != 1) BuyBuffer[i] = low[i] - atr;
      if(trendDir == -1 && prevDir != -1) SellBuffer[i] = high[i] + atr;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
