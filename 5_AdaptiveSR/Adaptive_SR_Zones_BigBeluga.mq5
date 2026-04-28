//+------------------------------------------------------------------+
//|                               Adaptive_SR_Zones_BigBeluga.mq5 |
//|                        Copyright 2026, BigBeluga (MQL5 Port) |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, BigBeluga (MQL5 Port)"
#property link      "https://www.tradingview.com/script/your-script-id-here/"
#property version   "1.01"
#property description "Adaptive Support/Resistance Zones based on pivot points."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

// --- Includes
#include <Arrays/ArrayObj.mqh>
#include <ChartObjects/ChartObjectsLines.mqh>
#include <ChartObjects/ChartObjectsShapes.mqh>

// --- Inputs

// Swing Detection
input group "Swing Detection"
input int    pivotLen     = 5;    // Pivot Length
input double minStrength  = 0.1;  // Min ATR Strength
input int    maxAgeBars   = 300;  // Max Level Age (bars)

// Levels
input group "Levels"
input bool   showSupport  = true;  // Show Support Levels
input bool   showResist   = true;  // Show Resistance Levels
input int    maxLevels    = 5;     // Max Active Levels Each
input double mergeThresh  = 0.5;   // Merge Threshold (ATR x)
input bool   showZones    = true;  // Show Level Zones
input double zoneWidth    = 0.25;  // Zone Width (ATR x)

// Breakouts
input group "Breakouts"
input bool   showBroken   = true;  // Show Broken Levels
input double breakSens    = 0.1;   // Break Sensitivity (ATR x)
input bool   showBreakLbl = true;  // Show Break Labels
input int    maxBroken    = 4;     // Max Broken Levels Shown

// Visuals
input group "Visuals"
input color  supColor        = clrDeepSkyBlue; // Support Color
input color  resColor        = clrOrangeRed;   // Resistance Color
input color  brokenColor     = clrSlateGray;   // Broken Level Color
input int    lineWidth       = 2;              // Base Line Width
input bool   useDynamicWidth = true;           // Enable Longevity Width
input int    maxLineWidth    = 7;              // Max Longevity Width
input bool   showPriceLbl    = true;           // Show Price Labels on Active Levels

// --- Global Variables
int atrHandle;
double atrVal;
double atrSafe;

// --- Level Class
class SRLevel : public CObject
{
public:
    double          price;
    datetime        barTimeStart;
    int             barIndexStart;
    int             levelType; // 1 for resistance, -1 for support
    bool            active;
    bool            broken;
    int             breakBar;
    string          mainLineName;
    string          zoneBoxName;
    string          priceLabelName;
    string          breakLabelName;

                    SRLevel(double p, int barIdx, int type);
                   ~SRLevel();
    void            DeleteObjects();
};

SRLevel::SRLevel(double p, int barIdx, int type)
{
    price         = p;
    barIndexStart = barIdx;
    levelType     = type;
    active        = true;
    broken        = false;
    breakBar      = 0;

    long chartID = ChartID();
    mainLineName   = "SRL_" + (string)TimeCurrent() + "_" + (string)MathRand() + (string)p;
    zoneBoxName    = "SRZ_" + (string)TimeCurrent() + "_" + (string)MathRand() + (string)p;
    priceLabelName = "SRP_" + (string)TimeCurrent() + "_" + (string)MathRand() + (string)p;
    breakLabelName = "SRB_" + (string)TimeCurrent() + "_" + (string)MathRand() + (string)p;
}

SRLevel::~SRLevel()
{
    // Objects are deleted explicitly to prevent accidental deletion
}

void SRLevel::DeleteObjects()
{
    ObjectDelete(0, mainLineName);
    ObjectDelete(0, zoneBoxName);
    ObjectDelete(0, priceLabelName);
    ObjectDelete(0, breakLabelName);
}

CArrayObj* activeLevels;
CArrayObj* brokenLevels;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    atrHandle = iATR(_Symbol, _Period, 14);
    activeLevels = new CArrayObj();
    activeLevels.FreeMode(false);
    brokenLevels = new CArrayObj();
    brokenLevels.FreeMode(false);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(CheckPointer(activeLevels) != POINTER_INVALID)
    {
        for(int i = activeLevels.Total() - 1; i >= 0; i--)
        {
            SRLevel* lvl = activeLevels.At(i);
            if(CheckPointer(lvl) != POINTER_INVALID)
            {
                lvl.DeleteObjects();
                delete lvl;
            }
        }
        activeLevels.Clear();
        delete activeLevels;
    }
    if(CheckPointer(brokenLevels) != POINTER_INVALID)
    {
        for(int i = brokenLevels.Total() - 1; i >= 0; i--)
        {
            SRLevel* lvl = brokenLevels.At(i);
            if(CheckPointer(lvl) != POINTER_INVALID)
            {
                lvl.DeleteObjects();
                delete lvl;
            }
        }
        brokenLevels.Clear();
        delete brokenLevels;
    }
    IndicatorRelease(atrHandle);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
bool isTooClose(double price, int type)
{
    for(int i = 0; i < activeLevels.Total(); i++)
    {
        SRLevel* lvl = activeLevels.At(i);
        if(lvl.levelType == type && lvl.active)
        {
            if(MathAbs(lvl.price - price) < mergeThresh * atrSafe)
            {
                return true;
            }
        }
    }
    return false;
}

void addLevel(double price, int type, int barIdx, const datetime &time)
{
    if(isTooClose(price, type))
        return;

    int cnt = 0;
    for(int i = 0; i < activeLevels.Total(); i++)
    {
        SRLevel* lvl = activeLevels.At(i);
        if(lvl.levelType == type && lvl.active)
            cnt++;
    }

    if(cnt >= maxLevels)
        return;

    SRLevel* newLevel = new SRLevel(price, barIdx, type);
    newLevel.barTimeStart = time;

    color baseColor = (type == 1) ? resColor : supColor;
    datetime futureTime = time + PeriodSeconds() * 2;

    // Create Line
    ObjectCreate(0, newLevel.mainLineName, OBJ_TREND, 0, time, price);
    ObjectSetInteger(0, newLevel.mainLineName, OBJPROP_RAY_RIGHT, true);
    ObjectSetInteger(0, newLevel.mainLineName, OBJPROP_COLOR, baseColor);
    ObjectSetInteger(0, newLevel.mainLineName, OBJPROP_WIDTH, lineWidth);
    ObjectSetInteger(0, newLevel.mainLineName, OBJPROP_STYLE, STYLE_SOLID);

    // Create Zone
    if(showZones)
    {
        double zoneTop = price + zoneWidth * atrSafe * 0.5;
        double zoneBot = price - zoneWidth * atrSafe * 0.5;
        ObjectCreate(0, newLevel.zoneBoxName, OBJ_RECTANGLE, 0, time, zoneTop, futureTime, zoneBot);
        ObjectSetInteger(0, newLevel.zoneBoxName, OBJPROP_COLOR, baseColor);
        ObjectSetInteger(0, newLevel.zoneBoxName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, newLevel.zoneBoxName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, newLevel.zoneBoxName, OBJPROP_BACK, true);
        ObjectSetInteger(0, newLevel.zoneBoxName, OBJPROP_RAY_RIGHT, true);
    }

    // Create Price Label
    if(showPriceLbl)
    {
        datetime labelTime = time + PeriodSeconds() * 10;
        ObjectCreate(0, newLevel.priceLabelName, OBJ_TEXT, 0, labelTime, price);
        ObjectSetString(0, newLevel.priceLabelName, OBJPROP_TEXT, DoubleToString(price, _Digits));
        ObjectSetInteger(0, newLevel.priceLabelName, OBJPROP_COLOR, baseColor);
        ObjectSetInteger(0, newLevel.priceLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
    }

    activeLevels.Add(newLevel);
}

bool isPivotStrong(int shift, int type, const double& high[], const double& low[])
{
    if(minStrength <= 0) return true;
    
    if(shift < 1 || shift > ArraySize(high) - 2) return false;

    double price = (type == 1) ? high[shift] : low[shift];
    
    if(type == 1) // Resistance
    {
        double nearHigh = MathMax(high[shift - 1], high[shift + 1]);
        if((price - nearHigh) < minStrength * atrSafe)
            return false;
    }
    else // Support
    {
        double nearLow = MathMin(low[shift - 1], low[shift + 1]);
        if((nearLow - price) < minStrength * atrSafe)
            return false;
    }
    return true;
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
    // We need at least 2*pivotLen + 1 bars to calculate a pivot
    if(rates_total < 2 * pivotLen + 1)
        return(0);

    // --- ATR Calculation
    double atrBuffer[1];
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
    {
        // If ATR is not ready, try again on the next tick
        return(0);
    }
    atrVal = atrBuffer[0];
    atrSafe = (atrVal == 0 || atrVal == EMPTY_VALUE) ? _Point * 10 : atrVal;

    // Determine the starting bar for calculation
    int start;
    if(prev_calculated == 0) // First calculation
    {
        start = pivotLen;
    }
    else // Subsequent calculations
    {
        start = prev_calculated - 1;
    }

    // --- Main Loop for historical bars to find pivots
    // We loop up to where we have enough bars on the right for a pivot
    for(int i = start; i < rates_total - pivotLen; i++)
    {
        // --- Find Pivot High
        bool isHigh = true;
        double pivotHighPrice = high[i];
        for(int j = 1; j <= pivotLen; j++)
        {
            // Check left and right bars
            if(high[i - j] > pivotHighPrice || high[i + j] >= pivotHighPrice)
            {
                isHigh = false;
                break;
            }
        }
        if(isHigh && showResist)
        {
             if(isPivotStrong(i, 1, high, low))
                addLevel(pivotHighPrice, 1, i, time[i]);
        }

        // --- Find Pivot Low
        bool isLow = true;
        double pivotLowPrice = low[i];
        for(int j = 1; j <= pivotLen; j++)
        {
            // Check left and right bars
            if(low[i - j] < pivotLowPrice || low[i + j] <= pivotLowPrice)
            {
                isLow = false;
                break;
            }
        }
        if(isLow && showSupport)
        {
            if(isPivotStrong(i, -1, high, low))
                addLevel(pivotLowPrice, -1, i, time[i]);
        }
    }
    
    // --- Handle current bar logic (updates, breakouts, pruning)
    int currentBar = rates_total - 1;
    double currentClose = close[currentBar];
    datetime currentTime = time[currentBar];

    // Prune old levels
    for(int j = activeLevels.Total() - 1; j >= 0; j--)
    {
        SRLevel* lvl = activeLevels.At(j);
        if(lvl != NULL && lvl.active && (currentBar - lvl.barIndexStart) > maxAgeBars)
        {
            lvl.DeleteObjects();
            delete activeLevels.Detach(j);
        }
    }

    // Update/break active levels
    for(int i = activeLevels.Total() - 1; i >= 0; i--)
    {
        SRLevel* lvl = activeLevels.At(i);
        if(lvl == NULL || !lvl.active) continue;

        double breakBuffer = breakSens * atrSafe;

        bool isBroken = (lvl.levelType == 1 && currentClose > lvl.price + breakBuffer) ||
                        (lvl.levelType == -1 && currentClose < lvl.price - breakBuffer);

        if(isBroken)
        {
            lvl.active = false;
            lvl.broken = true;
            lvl.breakBar = currentBar;

            // Update visuals for broken level
            ObjectSetInteger(0, lvl.mainLineName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lvl.mainLineName, OBJPROP_COLOR, brokenColor);
            ObjectSetInteger(0, lvl.mainLineName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, lvl.mainLineName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lvl.mainLineName, OBJPROP_TIME, 1, currentTime);
            
            if(showZones)
            {
               ObjectSetInteger(0, lvl.zoneBoxName, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, lvl.zoneBoxName, OBJPROP_TIME, 1, currentTime);
               ObjectSetInteger(0, lvl.zoneBoxName, OBJPROP_COLOR, brokenColor);
            }
            
            ObjectDelete(0, lvl.priceLabelName); // Delete price label on break

            if(showBreakLbl)
            {
                ObjectCreate(0, lvl.breakLabelName, OBJ_TEXT, 0, currentTime, lvl.price);
                ObjectSetString(0, lvl.breakLabelName, OBJPROP_TEXT, "< Break");
                ObjectSetInteger(0, lvl.breakLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
                ObjectSetInteger(0, lvl.breakLabelName, OBJPROP_COLOR, (lvl.levelType == 1 ? supColor : resColor));
            }

            if(showBroken)
            {
                brokenLevels.Add(activeLevels.Detach(i));
                if(brokenLevels.Total() > maxBroken)
                {
                    SRLevel* old = brokenLevels.At(0);
                    if(old != NULL)
                    {
                        old.DeleteObjects();
                        delete brokenLevels.Detach(0);
                    }
                }
            }
            else
            {
                lvl.DeleteObjects();
                delete activeLevels.Detach(i);
            }
        }
        else // Update active levels
        {
            // Dynamic width
            if(useDynamicWidth)
            {
                int age = currentBar - lvl.barIndexStart;
                int calcWidth = (int)fmin(maxLineWidth, 1 + floor((double)age / maxAgeBars * (maxLineWidth - 1)));
                ObjectSetInteger(0, lvl.mainLineName, OBJPROP_WIDTH, calcWidth);
            }
            else
            {
                ObjectSetInteger(0, lvl.mainLineName, OBJPROP_WIDTH, lineWidth);
            }
            
            // Extend line and box
            datetime futureTime = currentTime + PeriodSeconds();
            ObjectSetInteger(0, lvl.mainLineName, OBJPROP_TIME, 1, futureTime);
            if(showZones)
                ObjectSetInteger(0, lvl.zoneBoxName, OBJPROP_TIME, 1, futureTime);
            
            // Update price label position
            if(showPriceLbl)
            {
                datetime labelTime = currentTime + PeriodSeconds() * 10;
                ObjectSetInteger(0, lvl.priceLabelName, OBJPROP_TIME, 0, labelTime);
            }
        }
    }

    return(rates_total);
}
//+------------------------------------------------------------------+
