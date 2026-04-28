//+------------------------------------------------------------------+
//|                                           VolRegimeCompassN4.mq5 |
//|                                  Copyright 2026, Auto-Generated  |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   4

//--- Plot 1: Cloud (Histogram2)
#property indicator_label1  "Trend Cloud"
#property indicator_type1   DRAW_COLOR_HISTOGRAM2
#property indicator_color1  clrCoral, clrThistle // primary, secondary
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2, 3, 4: SMA Glow Layers
#property indicator_label2  "SMA200 Outer Glow"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCoral
#property indicator_width2  5

#property indicator_label3  "SMA200 Inner Glow"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCoral
#property indicator_width3  3

#property indicator_label4  "SMA200 Core"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrCoral
#property indicator_width4  1

//--- Inputs
input int      InpVolSpan        = 20;    // EWMA vol span
input int      InpMedianLookback = 252;   // Median/quantile window
input double   InpCoupCapPct     = 0.50;  // Winsor cap percentile
input bool     InpUse2x2         = true;  // 2x2 regime
input double   InpSizeMin        = 0.25;  // Floor (min %)
input double   InpSizeMax        = 2.00;  // Max %
input color    InpColorPrimary   = clrCoral;   // Bullish / ACT Color
input color    InpColorSecondary = clrThistle; // Bearish / HOLD Color

//--- Buffers
double         CloudP1Buffer[];
double         CloudP2Buffer[];
double         CloudColorBuffer[];
double         SmaOuterBuffer[];
double         SmaInnerBuffer[];
double         SmaCoreBuffer[];

//--- Internal
int            sma200_handle;
double         sma200_arr[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Cloud buffers
   SetIndexBuffer(0, CloudP1Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, CloudP2Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, CloudColorBuffer, INDICATOR_COLOR_INDEX);
   
   // SMA layers
   SetIndexBuffer(3, SmaOuterBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, SmaInnerBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, SmaCoreBuffer, INDICATOR_DATA);
   
   // Handles
   sma200_handle = iMA(_Symbol, _Period, 200, 0, MODE_SMA, PRICE_CLOSE);
   ArraySetAsSeries(sma200_arr, true);
   
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorPrimary);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpColorPrimary);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpColorPrimary);
   
   CreateDashboard();
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "VRC_");
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
   if(rates_total < 200) return(0);
   
   int copied = CopyBuffer(sma200_handle, 0, 0, rates_total, sma200_arr);
   if(copied <= 0) return(0);
   
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   
   for(int i = start; i < rates_total; i++)
     {
      double curr_close = close[i];
      double curr_sma   = sma200_arr[rates_total - 1 - i]; // Reverse if ArraySetAsSeries
      
      if(curr_sma == 0 || curr_sma == EMPTY_VALUE)
        {
         CloudP1Buffer[i] = EMPTY_VALUE;
         CloudP2Buffer[i] = EMPTY_VALUE;
         SmaOuterBuffer[i] = EMPTY_VALUE;
         SmaInnerBuffer[i] = EMPTY_VALUE;
         SmaCoreBuffer[i] = EMPTY_VALUE;
         continue;
        }
        
      // SMA Glow
      SmaOuterBuffer[i] = curr_sma;
      SmaInnerBuffer[i] = curr_sma;
      SmaCoreBuffer[i]  = curr_sma;
      
      // Cloud
      CloudP1Buffer[i] = curr_close;
      CloudP2Buffer[i] = curr_sma;
      
      // Color Logic (Bullish vs Bearish)
      // Since MQL5 DRAW_COLOR_HISTOGRAM2 color indexing doesn't support alpha per bar cleanly,
      // We assign 0 (Primary Color) if Close > SMA, and 1 (Secondary Color) if Close <= SMA.
      if(curr_close > curr_sma)
         CloudColorBuffer[i] = 0; // Bullish
      else
         CloudColorBuffer[i] = 1; // Bearish
     }
     
   if(rates_total - 1 >= 0)
     {
       UpdateDashboard(close[rates_total-1] > sma200_arr[0] ? "ACT" : "HOLD", InpColorPrimary, InpColorSecondary);
     }
     
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Subroutines for Dashboard                                        |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   string prefix = "VRC_";
   color paper = clrAntiqueWhite;
   color ink   = clrDarkSlateGray;
   color hush  = clrGray;
   
   // Background
   ObjectCreate(0, prefix+"BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_XSIZE, 180);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_YSIZE, 120);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_BGCOLOR, paper);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_BORDER_COLOR, hush);
   
   // Labels
   CreateLabel(prefix+"Title1", "la cocina", 190, 30, hush, 8, CORNER_RIGHT_UPPER);
   CreateLabel(prefix+"Title2", _Symbol, 30, 30, ink, 8, CORNER_RIGHT_UPPER, true);

   CreateLabel(prefix+"RegLbl", "régimen", 190, 50, hush, 8, CORNER_RIGHT_UPPER);
   CreateLabel(prefix+"RegVal", "coherente", 30, 50, ink, 8, CORNER_RIGHT_UPPER);

   CreateLabel(prefix+"VerbLbl", "verbo", 190, 70, hush, 8, CORNER_RIGHT_UPPER);
   CreateLabel(prefix+"VerbVal", "OBSERVE", 30, 70, ink, 12, CORNER_RIGHT_UPPER, true);

   CreateLabel(prefix+"ConvLbl", "conv · solo asset", 190, 95, hush, 8, CORNER_RIGHT_UPPER);
   CreateLabel(prefix+"ConvVal", "50", 30, 95, ink, 10, CORNER_RIGHT_UPPER, true);
  }

void CreateLabel(string name, string text, int x, int y, color clr, int size, int corner, bool bold=false)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   if(corner == CORNER_RIGHT_UPPER && x < 100)
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
  }

void UpdateDashboard(string verb, color cPr, color cSec)
  {
   string verbES = "observar";
   color vClr = clrGray;
   
   if(verb == "ACT") { verbES = "comprar"; vClr = cPr; }
   if(verb == "HOLD") { verbES = "mantener"; vClr = cSec; }
   
   ObjectSetString(0, "VRC_VerbVal", OBJPROP_TEXT, verbES);
   ObjectSetInteger(0, "VRC_VerbVal", OBJPROP_COLOR, vClr);
  }
//+------------------------------------------------------------------+