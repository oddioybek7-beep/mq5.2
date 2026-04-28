//+------------------------------------------------------------------+
//|                                              AutoTrendLines.mq5  |
//|                                  Copyright 2026, Auto-Generated  |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: High Pivot Circles
#property indicator_label1  "High Pivot"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_width1  1

//--- Plot 2: Low Pivot Circles
#property indicator_label2  "Low Pivot"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrGreen
#property indicator_width2  1

//--- Settings
input int      InpLookback  = 10;        // Pivot Sezgirligi
input color    InpLineColUp = clrRed;    // Yuqori chiziq rangi
input color    InpLineColDn = clrGreen;  // Pastki chiziq rangi
input bool     InpExtend    = true;      // Chiziqni davom ettirish

//--- Buffers
double         PivotHighBuffer[];
double         PivotLowBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Chart ranglarini o'zgartirish (Oq fon, Oq-Qora svechalar)
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_GRID, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrWhite);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrBlack);

   SetIndexBuffer(0, PivotHighBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 159); // Kichkina aylanacha (Circle)
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   SetIndexBuffer(1, PivotLowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_ARROW, 159); // Kichkina aylanacha (Circle)
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // Obyektlarni yaratib qo'yish
   CreateLine("AutoTrendHigh", InpLineColUp);
   CreateLine("AutoTrendLow", InpLineColDn);
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, "AutoTrendHigh");
   ObjectDelete(0, "AutoTrendLow");
  }

void CreateLine(string name, color clr)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TREND, 0, 0, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, InpExtend);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
   else
     {
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, InpExtend);
     }
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
   if(rates_total < InpLookback * 2 + 1)
      return(0);

   int start = (prev_calculated > InpLookback) ? prev_calculated - 1 : InpLookback;

   for(int i = start; i < rates_total; i++)
     {
      PivotHighBuffer[i] = EMPTY_VALUE;
      PivotLowBuffer[i] = EMPTY_VALUE;

      int pivot_idx = i - InpLookback;
      if(pivot_idx < InpLookback) continue;

      bool isPivotH = true;
      bool isPivotL = true;

      // Pivot nuqtalarini tekshirish
      for(int j = 1; j <= InpLookback; j++)
        {
         if(high[pivot_idx - j] > high[pivot_idx] || high[pivot_idx + j] >= high[pivot_idx]) isPivotH = false;
         if(low[pivot_idx - j] < low[pivot_idx] || low[pivot_idx + j] <= low[pivot_idx]) isPivotL = false;
        }

      // Agar High Pivot tasdiqlansa
      if(isPivotH)
        {
         PivotHighBuffer[pivot_idx] = high[pivot_idx];
         
         ObjectSetInteger(0, "AutoTrendHigh", OBJPROP_TIME, 0, time[pivot_idx]);
         ObjectSetDouble(0, "AutoTrendHigh", OBJPROP_PRICE, 0, high[pivot_idx]);
         ObjectSetInteger(0, "AutoTrendHigh", OBJPROP_TIME, 1, time[i]);
         ObjectSetDouble(0, "AutoTrendHigh", OBJPROP_PRICE, 1, high[pivot_idx]);
        }

      // Agar Low Pivot tasdiqlansa
      if(isPivotL)
        {
         PivotLowBuffer[pivot_idx] = low[pivot_idx];
         
         ObjectSetInteger(0, "AutoTrendLow", OBJPROP_TIME, 0, time[pivot_idx]);
         ObjectSetDouble(0, "AutoTrendLow", OBJPROP_PRICE, 0, low[pivot_idx]);
         ObjectSetInteger(0, "AutoTrendLow", OBJPROP_TIME, 1, time[i]);
         ObjectSetDouble(0, "AutoTrendLow", OBJPROP_PRICE, 1, low[pivot_idx]);
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+