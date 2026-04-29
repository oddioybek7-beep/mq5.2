//+------------------------------------------------------------------+
//|                                     StanWeinsteinStagVol.mq5     |
//|                                  Copyright 2024, AI Assistant    |
//+------------------------------------------------------------------+
#property copyright "AI Assistant"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   4

//--- plot WMA
#property indicator_label1  "WMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot TrailingStop
#property indicator_label2  "Trailing Stop"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCrimson
#property indicator_style2  STYLE_DASHDOT
#property indicator_width2  1

//--- plot Spring
#property indicator_label3  "Spring"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLimeGreen
#property indicator_width3  2

//--- plot Upthrust
#property indicator_label4  "Upthrust"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  2

//--- input parameters
input int      InpWMAPeriod   = 30; // WMA Period
input int      InpATRPeriod   = 14; // ATR Period
input double   InpATRMulti    = 2.5;// ATR Multiplier for Trailing Stop

//--- indicator buffers
double         WMABuffer[];
double         TrailingStopBuffer[];
double         SpringBuffer[];
double         UpthrustBuffer[];
double         StageBuffer[]; // 1=Stage1, 2=Stage2, 3=Stage3, 4=Stage4
double         ATRBuffer[];

//--- handles
int            wma_handle;
int            atr_handle;

//--- Dashboard setup variables
string         dashPrefix = "SW_Dash_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, WMABuffer, INDICATOR_DATA);
   SetIndexBuffer(1, TrailingStopBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SpringBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, UpthrustBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, StageBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, ATRBuffer, INDICATOR_CALCULATIONS);
   
   PlotIndexSetInteger(2, PLOT_ARROW, 233);
   PlotIndexSetInteger(3, PLOT_ARROW, 234);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);

   wma_handle = iMA(_Symbol, _Period, InpWMAPeriod, 0, MODE_LWMA, PRICE_CLOSE);
   atr_handle = iATR(_Symbol, _Period, InpATRPeriod);

   if(wma_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE)
     {
      Print("Failed to load indicators");
      return(INIT_FAILED);
     }

   CreateDashboard();
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
   if(rates_total < InpWMAPeriod) return 0;
   
   int limit = prev_calculated == 0 ? rates_total - 1 : rates_total - prev_calculated;
   if(prev_calculated > 0) limit++;

   double wma[], atr[];
   if(CopyBuffer(wma_handle, 0, 0, limit + 2, wma) <= 0) return 0;
   if(CopyBuffer(atr_handle, 0, 0, limit + 2, atr) <= 0) return 0;
   
   ArraySetAsSeries(wma, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   for(int i = limit; i >= 0 && !IsStopped(); i--)
     {
      WMABuffer[i] = wma[i];
      if(i == rates_total-1) {
         TrailingStopBuffer[i] = low[i] - atr[i] * InpATRMulti;
         StageBuffer[i] = 1;
      } else {
         // Trailing Stop logic
         if(close[i] > TrailingStopBuffer[i+1] && close[i+1] > TrailingStopBuffer[i+1]) {
            TrailingStopBuffer[i] = MathMax(TrailingStopBuffer[i+1], low[i] - atr[i] * InpATRMulti);
         } else if(close[i] < TrailingStopBuffer[i+1] && close[i+1] < TrailingStopBuffer[i+1]) {
            TrailingStopBuffer[i] = MathMin(TrailingStopBuffer[i+1], high[i] + atr[i] * InpATRMulti);
         } else {
            TrailingStopBuffer[i] = (close[i] > TrailingStopBuffer[i+1]) ? low[i] - atr[i] * InpATRMulti : high[i] + atr[i] * InpATRMulti;
         }

         // Stage Calculation
         double wma_slope = wma[i] - wma[i+1];
         if(close[i] > wma[i] && wma_slope > 0) StageBuffer[i] = 2; // S2 PRO
         else if(close[i] < wma[i] && wma_slope < 0) StageBuffer[i] = 4; // Stage 4
         else if(close[i] > wma[i] && wma_slope <= 0) StageBuffer[i] = 3; // Stage 3
         else StageBuffer[i] = 1; // Stage 1
         
         // Springs & Upthrusts
         SpringBuffer[i] = 0.0;
         UpthrustBuffer[i] = 0.0;
         if(StageBuffer[i] == 2 && StageBuffer[i+1] != 2) SpringBuffer[i] = low[i] - atr[i]*0.5; // Breakout into Stage 2
         if(StageBuffer[i] == 4 && StageBuffer[i+1] != 4) UpthrustBuffer[i] = high[i] + atr[i]*0.5; // Breakdown into Stage 4
      }
     }
     
   UpdateDashboard(StageBuffer[0]);
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Dashboard Functions                                              |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   ObjectCreate(0, dashPrefix+"BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dashPrefix+"BG", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, dashPrefix+"BG", OBJPROP_YDISTANCE, 40);
   ObjectSetInteger(0, dashPrefix+"BG", OBJPROP_XSIZE, 180);
   ObjectSetInteger(0, dashPrefix+"BG", OBJPROP_YSIZE, 60);
   ObjectSetInteger(0, dashPrefix+"BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, dashPrefix+"BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, dashPrefix+"BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, dashPrefix+"BG", OBJPROP_COLOR, clrWhite);
   
   ObjectCreate(0, dashPrefix+"Title", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dashPrefix+"Title", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, dashPrefix+"Title", OBJPROP_YDISTANCE, 45);
   ObjectSetString(0, dashPrefix+"Title", OBJPROP_TEXT, "SW Stage Analysis");
   ObjectSetInteger(0, dashPrefix+"Title", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, dashPrefix+"Title", OBJPROP_FONTSIZE, 10);
   
   ObjectCreate(0, dashPrefix+"Stage", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dashPrefix+"Stage", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, dashPrefix+"Stage", OBJPROP_YDISTANCE, 65);
   ObjectSetString(0, dashPrefix+"Stage", OBJPROP_TEXT, "Stage: calc...");
   ObjectSetInteger(0, dashPrefix+"Stage", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, dashPrefix+"Stage", OBJPROP_FONTSIZE, 12);
}

void UpdateDashboard(double stage)
{
   string stxt = "Stage: ";
   color c = clrYellow;
   if(stage == 1) { stxt += "1 (Consolidation)"; c = clrGray; }
   else if(stage == 2) { stxt += "2 (Markup PRO)"; c = clrLime; }
   else if(stage == 3) { stxt += "3 (Distribution)"; c = clrOrange; }
   else if(stage == 4) { stxt += "4 (Decline)"; c = clrRed; }
   
   ObjectSetString(0, dashPrefix+"Stage", OBJPROP_TEXT, stxt);
   ObjectSetInteger(0, dashPrefix+"Stage", OBJPROP_COLOR, c);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, dashPrefix);
}
//+------------------------------------------------------------------+
