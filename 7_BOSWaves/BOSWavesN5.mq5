//+------------------------------------------------------------------+
//|                                                   BOSWavesN5.mq5 |
//|                                  Converted from Pine Script [N5] |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   3

//--- Plot 1: Upper Band
#property indicator_label1  "Upper Band"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Lower Band
#property indicator_label2  "Lower Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: Signal
#property indicator_label3  "Signal Arrow"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrYellow
#property indicator_width3  2

//--- Inputs
input int      InpLen        = 21;    // Trend Length (EMA)
input double   InpCloseZone  = 0.3;   // Close Zone
input double   InpPulseDecay = 0.85;  // Pulse Decay
input int      InpPulseCap   = 8;     // Pulse Cap
input int      InpMadLen     = 17;    // MAD Length
input double   InpBandMin    = 1.4;   // Band Min (Saturated)
input double   InpBandMax    = 2.2;   // Band Max (Exhausted)

//--- Buffers
double         UpperBuffer[];
double         LowerBuffer[];
double         SignalBuffer[];
double         TrendBuffer[]; // Hidden buffer logic (1 = Bull, -1 = Bear)

//--- Internal Handles
int            ema_handle;
int            sma_handle;
double         ema_arr[];
double         sma_arr[];
double         close_arr[];
double         high_arr[];
double         low_arr[];
double         open_arr[];

// State variables (to carry over pulse values)
double         bullPulse = 0.0;
double         bearPulse = 0.0;
int            lastSignal = 0; // 1 = Long, -1 = Short
datetime       last_time = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Upper Band
   SetIndexBuffer(0, UpperBuffer, INDICATOR_DATA);
   // Lower Band
   SetIndexBuffer(1, LowerBuffer, INDICATOR_DATA);
   // Signal Arrows
   SetIndexBuffer(2, SignalBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(2, PLOT_ARROW, 233); // Arrow code (can be altered dynamically)
   
   // Trend (Hidden)
   SetIndexBuffer(3, TrendBuffer, INDICATOR_CALCULATIONS);
   
   // Moving Averages Handles
   ema_handle = iMA(_Symbol, _Period, InpLen, 0, MODE_EMA, PRICE_CLOSE);
   sma_handle = iMA(_Symbol, _Period, InpMadLen, 0, MODE_SMA, PRICE_CLOSE);
   
   ArraySetAsSeries(UpperBuffer, false);
   ArraySetAsSeries(LowerBuffer, false);
   ArraySetAsSeries(SignalBuffer, false);
   ArraySetAsSeries(TrendBuffer, false);
   
   ArraySetAsSeries(ema_arr, false);
   ArraySetAsSeries(sma_arr, false);
   ArraySetAsSeries(close_arr, false);
   ArraySetAsSeries(high_arr, false);
   ArraySetAsSeries(low_arr, false);
   ArraySetAsSeries(open_arr, false);
   
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
   if(rates_total < MathMax(InpLen, InpMadLen) + 1) return(0);
   
   int limit = prev_calculated - 1;
   if(limit < InpMadLen)
     {
      limit = InpMadLen;
      bullPulse = 0.0;
      bearPulse = 0.0;
      lastSignal = 0;
     }
     
   if(CopyBuffer(ema_handle, 0, 0, rates_total, ema_arr) <= 0) return 0;
   if(CopyBuffer(sma_handle, 0, 0, rates_total, sma_arr) <= 0) return 0;
   
   ArrayCopy(close_arr, close, 0, 0, rates_total);
   ArrayCopy(high_arr, high, 0, 0, rates_total);
   ArrayCopy(low_arr, low, 0, 0, rates_total);
   ArrayCopy(open_arr, open, 0, 0, rates_total);
   
   for(int i = limit; i < rates_total; i++)
     {
      // Process Pulse
      double c_open = open_arr[i];
      double c_high = high_arr[i];
      double c_low = low_arr[i];
      double c_close = close_arr[i];
      
      // Calculate MAD from i - InpMadLen to i
      double mad_sum = 0;
      int mad_start = MathMax(0, i - InpMadLen + 1);
      int mad_count = 0;
      
      for(int k = mad_start; k <= i; k++)
        {
         mad_sum += MathAbs(close_arr[k] - sma_arr[k]);
         mad_count++;
        }
      double mad = mad_count > 0 ? (mad_sum / mad_count) : 0;
      
      double basis = ema_arr[i];
      
      double hl_range = MathMax(c_high - c_low, SymbolInfoDouble(_Symbol, SYMBOL_POINT));
      double closeLoc = (c_close - c_low) / hl_range;
      
      bool bullConv = (closeLoc >= (1.0 - InpCloseZone)) && (c_close > c_open);
      bool bearConv = (closeLoc <= InpCloseZone) && (c_close < c_open);
      
      // State handling: save previous pulse state in case we recalculate current opening bar repeatedly
      // For actual trading platforms, we'd persist state perfectly only on new bar, but standard indicator applies recalculation.
      // E.g., we preserve pulse when time[i] changes
      static datetime last_processed_time = 0;
      static double saved_bullP = 0, saved_bearP = 0;
      static int saved_sig = 0;
      
      if(time[i] > last_processed_time)
        {
         saved_bullP = bullPulse;
         saved_bearP = bearPulse;
         saved_sig = lastSignal;
         last_processed_time = time[i];
        }
      
      // Load saved state temporarily for current bar calculation
      double temp_bullPulse = saved_bullP;
      double temp_bearPulse = saved_bearP;

      if(bullConv) temp_bullPulse = MathMin(temp_bullPulse + 1.0, (double)InpPulseCap);
      else         temp_bullPulse = temp_bullPulse * InpPulseDecay;
      
      if(bearConv) temp_bearPulse = MathMin(temp_bearPulse + 1.0, (double)InpPulseCap);
      else         temp_bearPulse = temp_bearPulse * InpPulseDecay;
      
      bullPulse = temp_bullPulse;
      bearPulse = temp_bearPulse;

      double saturation = MathMax(bullPulse, bearPulse) / (double)InpPulseCap;
      
      double bandMult = InpBandMax - (InpBandMax - InpBandMin) * saturation;
      double upper = basis + mad * bandMult;
      double lower = basis - mad * bandMult;
      
      UpperBuffer[i] = upper;
      LowerBuffer[i] = lower;
      
      // Signal Condition
      double prev_close = close_arr[i-1];
      double prev_upper = UpperBuffer[i-1];
      double prev_lower = LowerBuffer[i-1];
      
      bool longCond = (prev_close <= prev_upper && c_close > upper);
      bool shortCond = (prev_close >= prev_lower && c_close < lower);
      
      int prev_sig = saved_sig;
      int curr_sig = longCond ? 1 : (shortCond ? -1 : prev_sig);
      lastSignal = curr_sig;
      
      SignalBuffer[i] = 0.0; // empty
      if(curr_sig == 1 && prev_sig == -1) // trend flipped Up
        {
         SignalBuffer[i] = c_low - (mad * 1.5);
         PlotIndexSetInteger(2, PLOT_ARROW, 233); // Arrow UP
        }
      if(curr_sig == -1 && prev_sig == 1) // trend flipped Down
        {
         SignalBuffer[i] = c_high + (mad * 1.5);
         PlotIndexSetInteger(2, PLOT_ARROW, 234); // Arrow DOWN
        }
        
      TrendBuffer[i] = (double)curr_sig; // Stores trend state
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
