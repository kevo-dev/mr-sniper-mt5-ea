//+------------------------------------------------------------------+
//| MR_Sniper_MeanReversion.mq5                                    |
//| Selective, risk-controlled mean-reversion scalping EA for MT5.  |
//| Copyright 2026 Manus AI.                                       |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property version   "1.00"
#property strict
#property description "Selective mean-reversion EA. Validate in Strategy Tester and demo before any live use."

#include <Trade/Trade.mqh>

//--- Configuration enumerations
// Presets are supplied as .set files. The enum is displayed for auditability.
enum ENUM_MR_PRESET
  {
   MR_PRESET_CONSERVATIVE = 0,
   MR_PRESET_BALANCED     = 1,
   MR_PRESET_AGGRESSIVE   = 2
  };

enum ENUM_MR_TARGET_MODEL
  {
   MR_TARGET_VWAP         = 0,
   MR_TARGET_BB_MID       = 1,
   MR_TARGET_FIXED_RR     = 2,
   MR_TARGET_ATR          = 3,
   MR_TARGET_HYBRID       = 4
  };

enum ENUM_MR_TREND_MODE
  {
   MR_TREND_DISABLED      = 0,
   MR_TREND_MODERATE      = 1,
   MR_TREND_STRICT        = 2
  };

enum ENUM_MR_SPREAD_MODE
  {
   MR_SPREAD_PIPS         = 0,
   MR_SPREAD_POINTS       = 1,
   MR_SPREAD_ATR_PERCENT  = 2
  };

//--- General and execution inputs
input group "General"
input ENUM_MR_PRESET          InpPreset                    = MR_PRESET_BALANCED;
input ulong                   InpMagicNumber               = 26081201;
input ENUM_TIMEFRAMES         InpExecutionTF               = PERIOD_M5;
input ENUM_TIMEFRAMES         InpHigherTF                  = PERIOD_M15;
input bool                    InpEnableTrading             = true;
input bool                    InpManualResetRiskLock       = false;
input int                     InpMaxSlippagePoints         = 20;
input int                     InpExecutionFailurePauseSec  = 300;
input int                     InpMaxTickAgeSeconds         = 15;

input group "Mean-Reversion Model"
input int                     InpMinVWAPBars               = 12;
input double                  InpVWAPDeviationATR          = 0.70;
input int                     InpBollingerPeriod           = 20;
input double                  InpBollingerDeviation        = 2.00;
input int                     InpZScorePeriod              = 50;
input double                  InpZScoreThreshold           = 2.00;
input int                     InpRSIPeriod                 = 14;
input double                  InpRSIOverbought             = 70.0;
input double                  InpRSIOversold               = 30.0;
input int                     InpATRPeriod                 = 14;
input int                     InpATRNormalLookback         = 50;
input double                  InpAbnormalATRMultiplier     = 2.20;
input double                  InpAbnormalCandleATRMultiple = 1.80;
input double                  InpSpreadExpansionMultiple   = 2.00;
input int                     InpMinimumSignalScore        = 75;
input bool                    InpUseEngulfingConfirmation  = true;
input bool                    InpUseWickConfirmation       = true;
input bool                    InpUseStrongCloseConfirmation= true;
input bool                    InpUseReturnInsideBand       = true;

input group "Market Regime"
input ENUM_MR_TREND_MODE      InpTrendFilterMode           = MR_TREND_MODERATE;
input int                     InpADXPeriod                 = 14;
input double                  InpADXTrendThreshold         = 25.0;
input int                     InpEMA20Period               = 20;
input int                     InpEMA50Period               = 50;
input int                     InpEMA200Period              = 200;
input double                  InpEMASepATR                 = 0.60;
input double                  InpMinBandWidthATR           = 0.50;
input double                  InpMaxBandWidthATR           = 4.00;

input group "Spread, Session and News Filters"
input ENUM_MR_SPREAD_MODE     InpSpreadLimitMode           = MR_SPREAD_PIPS;
input double                  InpMaxSpreadValue            = 1.50;
input int                     InpSessionStartHour          = 7;
input int                     InpSessionStartMinute        = 0;
input int                     InpSessionEndHour            = 20;
input int                     InpSessionEndMinute          = 0;
input bool                    InpEnableRolloverBlackout    = true;
input int                     InpRolloverStartHour         = 23;
input int                     InpRolloverStartMinute       = 55;
input int                     InpRolloverEndHour           = 0;
input int                     InpRolloverEndMinute         = 10;
input bool                    InpEnableNewsFilter          = true;
input bool                    InpFailClosedOnNewsError     = true;
input int                     InpNewsBeforeMinutes         = 15;
input int                     InpNewsAfterMinutes          = 30;

input group "Risk and Position Sizing"
input double                  InpRiskPerTradePercent       = 0.50;
input double                  InpMaxDailyLossPercent       = 2.00;
input double                  InpDailyProfitTargetPercent  = 3.00;
input bool                    InpUseDailyProfitTarget      = false;
input double                  InpMaxAccountDrawdownPercent = 10.0;
input double                  InpDrawdownWarningPercent    = 5.00;
input double                  InpWarningRiskMultiplier     = 0.50;
input int                     InpMaxTradesPerDay           = 5;
input int                     InpMaxConsecutiveLosses      = 3;
input int                     InpConsecutiveLossCooldownMin= 60;
input int                     InpCooldownMinutes           = 10;
input bool                    InpClosePositionsOnDailyLoss = true;
input double                  InpMaxMarginUseFraction      = 0.80;
input bool                    InpUsePortfolioRiskGuard     = true;
input double                  InpMaxPortfolioRiskPercent   = 1.50;
input bool                    InpUseCorrelationGuard       = true;
input double                  InpMaxCorrelatedRiskPercent  = 1.00;

input group "Stops, Targets and Trade Management"
input double                  InpATRStopMultiplier         = 1.20;
input int                     InpStopBufferPoints          = 2;
input ENUM_MR_TARGET_MODEL    InpTargetModel               = MR_TARGET_HYBRID;
input double                  InpFixedRiskReward           = 1.50;
input double                  InpATRTargetMultiplier       = 1.20;
input double                  InpMinimumRR                 = 1.20;
input bool                    InpEnableBreakEven           = true;
input double                  InpBreakEvenTriggerR         = 0.80;
input int                     InpBreakEvenBufferPoints     = 2;
input bool                    InpEnableTrailingStop        = false;
input double                  InpTrailingATRMultiplier     = 1.00;
input bool                    InpEnableTimeStop            = true;
input int                     InpMaxTradeDurationMinutes   = 30;

input group "Logging and Dashboard"
input bool                    InpEnableFileLogging         = true;
input bool                    InpEnableDashboard           = true;
input int                     InpDashboardX                = 10;
input int                     InpDashboardY                = 20;

//--- Constant score weights. They deliberately sum to 100.
#define SCORE_VWAP       25
#define SCORE_BB         20
#define SCORE_ZSCORE     15
#define SCORE_RSI        10
#define SCORE_REVERSAL   10
#define SCORE_RETURN     10
#define SCORE_REGIME      5
#define SCORE_SPREAD      5

//--- Data structures
struct SignalSnapshot
  {
   datetime barTime;
   double   closePrice;
   double   previousClose;
   double   barHigh;
   double   barLow;
   double   barRange;
   double   vwap;
   double   vwapDistanceATR;
   double   bandUpper;
   double   bandMiddle;
   double   bandLower;
   double   bandUpperPrev;
   double   bandLowerPrev;
   double   bandWidth;
   double   zscore;
   double   zscorePrev;
   double   rsi;
   double   rsiPrev;
   double   atr;
   double   normalAtr;
   double   adx;
   double   ema20;
   double   ema50;
   double   ema200;
   double   ema20Prev;
   double   spreadPips;
   int      longScore;
   int      shortScore;
   bool     longReversal;
   bool     shortReversal;
   bool     longReturnInside;
   bool     shortReturnInside;
   bool     spreadOK;
   bool     abnormalVolatility;
   string   regime;
   string   action;
   string   rejection;
  };

//--- Global EA state
CTrade   g_trade;
int      g_handleBands   = INVALID_HANDLE;
int      g_handleRSI     = INVALID_HANDLE;
int      g_handleATR     = INVALID_HANDLE;
int      g_handleADX     = INVALID_HANDLE;
int      g_handleEMA20   = INVALID_HANDLE;
int      g_handleEMA50   = INVALID_HANDLE;
int      g_handleEMA200  = INVALID_HANDLE;
datetime g_lastBarTime   = 0;
datetime g_lastTradeTime = 0;
datetime g_pauseUntil    = 0;
datetime g_dayStart      = 0;
double   g_dayStartEquity= 0.0;
double   g_equityHighWater=0.0;
double   g_spreadEmaPips = 0.0;
int      g_tradesToday   = 0;
int      g_consecutiveLosses = 0;
bool     g_dailyLossLock = false;
bool     g_dailyProfitLock = false;
bool     g_drawdownLock  = false;
string   g_dashboardName = "MR_Sniper_Dashboard";
SignalSnapshot g_lastSnapshot;

//+------------------------------------------------------------------+
//| Utility functions                                                |
//+------------------------------------------------------------------+
datetime ServerNow()
  {
   datetime now=TimeTradeServer();
   if(now<=0)
      now=TimeCurrent();
   return(now);
  }

string BoolText(const bool value)
  {
   return(value ? "YES" : "NO");
  }

string DirectionText(const ENUM_ORDER_TYPE direction)
  {
   return(direction==ORDER_TYPE_BUY ? "LONG" : "SHORT");
  }

double PipSize()
  {
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(digits==3 || digits==5)
      return(10.0*_Point);
   return(_Point);
  }

double NormalizePriceToTick(const double price)
  {
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(tickSize<=0.0)
      tickSize=_Point;
   return(NormalizeDouble(MathRound(price/tickSize)*tickSize,digits));
  }

int VolumeDigits()
  {
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   int digits=0;
   while(step<1.0 && digits<8)
     {
      step*=10.0;
      digits++;
     }
   return(digits);
  }

datetime DayStartTime()
  {
   MqlDateTime st;
   TimeToStruct(ServerNow(),st);
   st.hour=0;
   st.min=0;
   st.sec=0;
   return(StructToTime(st));
  }

double DayMarker()
  {
   MqlDateTime st;
   TimeToStruct(ServerNow(),st);
   return((double)(st.year*1000+st.day_of_year));
  }

string StatePrefix()
  {
   return("MRS_"+IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+IntegerToString((long)InpMagicNumber)+"_");
  }

string DayMarkerKey()       { return(StatePrefix()+"DayMarker");       }
string DayEquityKey()       { return(StatePrefix()+"DayEquity");       }
string HighWaterKey()       { return(StatePrefix()+"HighWater");       }
string DrawdownLockKey()    { return(StatePrefix()+"DrawdownLock");    }
string InitialStopKey(const ulong ticket)
  {
   return(StatePrefix()+"InitSL_"+IntegerToString((long)ticket));
  }

bool IsTradeRetcodeSuccess(const uint retcode)
  {
   return(retcode==TRADE_RETCODE_DONE ||
          retcode==TRADE_RETCODE_DONE_PARTIAL ||
          retcode==TRADE_RETCODE_PLACED);
  }

bool IsInMinuteWindow(const int nowMinutes,const int startMinutes,const int endMinutes)
  {
   if(startMinutes==endMinutes)
      return(false);
   if(startMinutes<endMinutes)
      return(nowMinutes>=startMinutes && nowMinutes<endMinutes);
   return(nowMinutes>=startMinutes || nowMinutes<endMinutes);
  }

bool IsWithinSession()
  {
   MqlDateTime st;
   TimeToStruct(ServerNow(),st);
   int nowMinutes=st.hour*60+st.min;
   int startMinutes=InpSessionStartHour*60+InpSessionStartMinute;
   int endMinutes=InpSessionEndHour*60+InpSessionEndMinute;
   return(IsInMinuteWindow(nowMinutes,startMinutes,endMinutes));
  }

bool IsRolloverBlackout()
  {
   if(!InpEnableRolloverBlackout)
      return(false);
   MqlDateTime st;
   TimeToStruct(ServerNow(),st);
   int nowMinutes=st.hour*60+st.min;
   int startMinutes=InpRolloverStartHour*60+InpRolloverStartMinute;
   int endMinutes=InpRolloverEndHour*60+InpRolloverEndMinute;
   return(IsInMinuteWindow(nowMinutes,startMinutes,endMinutes));
  }

void ResetSnapshot(SignalSnapshot &s)
  {
   ZeroMemory(s);
   s.regime="UNKNOWN";
   s.action="WAITING";
   s.rejection="";
  }

//+------------------------------------------------------------------+
//| Persistence and daily statistics                                 |
//+------------------------------------------------------------------+
void ResetDailyStateIfNeeded()
  {
   double marker=DayMarker();
   bool newDay=(!GlobalVariableCheck(DayMarkerKey()) ||
                MathAbs(GlobalVariableGet(DayMarkerKey())-marker)>0.1);

   g_dayStart=DayStartTime();
   if(newDay)
     {
      g_dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
      g_tradesToday=0;
      g_consecutiveLosses=0;
      g_lastTradeTime=0;
      g_pauseUntil=0;
      g_dailyLossLock=false;
      g_dailyProfitLock=false;
      GlobalVariableSet(DayMarkerKey(),marker);
      GlobalVariableSet(DayEquityKey(),g_dayStartEquity);
     }
   else
     {
      if(GlobalVariableCheck(DayEquityKey()))
         g_dayStartEquity=GlobalVariableGet(DayEquityKey());
      else
        {
         g_dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
         GlobalVariableSet(DayEquityKey(),g_dayStartEquity);
        }
     }
  }

bool LongInArray(const long &values[],const long value)
  {
   for(int i=0;i<ArraySize(values);i++)
      if(values[i]==value)
         return(true);
   return(false);
  }

void RebuildDailyStats()
  {
   g_tradesToday=0;
   g_consecutiveLosses=0;
   g_lastTradeTime=0;
   if(!HistorySelect(g_dayStart,ServerNow()))
      return;

   long closedPositions[];
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0)
         continue;
      if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagicNumber)
         continue;
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol)
         continue;

      long entryType=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entryType!=DEAL_ENTRY_OUT && entryType!=DEAL_ENTRY_OUT_BY)
         continue;

      long positionId=HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(LongInArray(closedPositions,positionId))
         continue;

      int n=ArraySize(closedPositions);
      ArrayResize(closedPositions,n+1);
      closedPositions[n]=positionId;
      g_tradesToday++;

      double net=HistoryDealGetDouble(deal,DEAL_PROFIT)+
                 HistoryDealGetDouble(deal,DEAL_SWAP)+
                 HistoryDealGetDouble(deal,DEAL_COMMISSION);
      if(net<0.0)
         g_consecutiveLosses++;
      else
         g_consecutiveLosses=0;

      datetime dealTime=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
      if(dealTime>g_lastTradeTime)
         g_lastTradeTime=dealTime;
     }

   if(g_consecutiveLosses>=InpMaxConsecutiveLosses && InpMaxConsecutiveLosses>0)
      g_pauseUntil=ServerNow()+(datetime)(InpConsecutiveLossCooldownMin*60);
  }

void RefreshRiskState()
  {
   ResetDailyStateIfNeeded();
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_equityHighWater<=0.0)
      g_equityHighWater=equity;
   if(equity>g_equityHighWater)
     {
      g_equityHighWater=equity;
      GlobalVariableSet(HighWaterKey(),g_equityHighWater);
     }

   double dailyPnLPct=0.0;
   if(g_dayStartEquity>0.0)
      dailyPnLPct=100.0*(equity-g_dayStartEquity)/g_dayStartEquity;
   g_dailyLossLock=(InpMaxDailyLossPercent>0.0 && dailyPnLPct<=-InpMaxDailyLossPercent);
   g_dailyProfitLock=(InpUseDailyProfitTarget && InpDailyProfitTargetPercent>0.0 &&
                      dailyPnLPct>=InpDailyProfitTargetPercent);

   double drawdownPct=0.0;
   if(g_equityHighWater>0.0)
      drawdownPct=100.0*(g_equityHighWater-equity)/g_equityHighWater;
   if(InpMaxAccountDrawdownPercent>0.0 && drawdownPct>=InpMaxAccountDrawdownPercent)
     {
      g_drawdownLock=true;
      GlobalVariableSet(DrawdownLockKey(),1.0);
     }
  }

double CurrentDrawdownPercent()
  {
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_equityHighWater<=0.0)
      return(0.0);
   return(100.0*(g_equityHighWater-equity)/g_equityHighWater);
  }

double CurrentDailyPnLPercent()
  {
   if(g_dayStartEquity<=0.0)
      return(0.0);
   return(100.0*(AccountInfoDouble(ACCOUNT_EQUITY)-g_dayStartEquity)/g_dayStartEquity);
  }

double EffectiveRiskPercent()
  {
   double risk=InpRiskPerTradePercent;
   if(InpDrawdownWarningPercent>0.0 && CurrentDrawdownPercent()>=InpDrawdownWarningPercent)
      risk*=MathMax(0.0,MathMin(1.0,InpWarningRiskMultiplier));
   return(risk);
  }

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
string LogFileName()
  {
   return("MR_Sniper_"+_Symbol+"_"+IntegerToString((long)InpMagicNumber)+"_"+
          TimeToString(ServerNow(),TIME_DATE)+".csv");
  }

void WriteLog(const string eventName,const SignalSnapshot &s,const string direction,
              const double entry,const double sl,const double tp,const double volume,
              const string reason)
  {
   string line=StringFormat("%s | %s | %s | score L=%d S=%d | vwap=%.8f z=%.3f rsi=%.2f atr=%.8f adx=%.2f | spread=%.2f | regime=%s | entry=%.8f sl=%.8f tp=%.8f vol=%.2f | %s",
                            TimeToString(ServerNow(),TIME_DATE|TIME_SECONDS),eventName,direction,
                            s.longScore,s.shortScore,s.vwap,s.zscore,s.rsi,s.atr,s.adx,
                            s.spreadPips,s.regime,entry,sl,tp,volume,reason);
   Print(line);

   if(!InpEnableFileLogging)
      return;
   int handle=FileOpen(LogFileName(),FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_ANSI);
   if(handle==INVALID_HANDLE)
     {
      Print("MR Sniper: unable to open log file. Error=",GetLastError());
      return;
     }
   bool newFile=(FileSize(handle)==0);
   FileSeek(handle,0,SEEK_END);
   if(newFile)
      FileWrite(handle,"timestamp","event","symbol","timeframe","direction","long_score","short_score",
                "vwap","zscore","rsi","atr","adx","spread_pips","regime","entry","sl","tp",
                "volume","daily_pnl_pct","reason");
   FileWrite(handle,TimeToString(ServerNow(),TIME_DATE|TIME_SECONDS),eventName,_Symbol,
             EnumToString(InpExecutionTF),direction,s.longScore,s.shortScore,s.vwap,s.zscore,s.rsi,
             s.atr,s.adx,s.spreadPips,s.regime,entry,sl,tp,volume,CurrentDailyPnLPercent(),reason);
   FileClose(handle);
  }

//+------------------------------------------------------------------+
//| Symbol, market and calendar filters                              |
//+------------------------------------------------------------------+
void UpdateSpreadEMA()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.ask<=0.0 || tick.bid<=0.0)
      return;
   double spread=(tick.ask-tick.bid)/PipSize();
   if(g_spreadEmaPips<=0.0)
      g_spreadEmaPips=spread;
   else
      g_spreadEmaPips=0.98*g_spreadEmaPips+0.02*spread;
  }

bool IsSpreadAcceptable(const double spreadPips,const double atr)
  {
   if(InpSpreadLimitMode==MR_SPREAD_PIPS)
      return(spreadPips<=InpMaxSpreadValue);
   if(InpSpreadLimitMode==MR_SPREAD_POINTS)
      return(spreadPips*PipSize()/_Point<=InpMaxSpreadValue);
   if(atr<=0.0)
      return(false);
   double spreadPrice=spreadPips*PipSize();
   return(100.0*spreadPrice/atr<=InpMaxSpreadValue);
  }

bool ExtractCurrencyPair(const string symbol,string &base,string &quote)
  {
   string letters="";
   for(int i=0;i<StringLen(symbol);i++)
     {
      ushort c=StringGetCharacter(symbol,i);
      if((c>=65 && c<=90) || (c>=97 && c<=122))
         letters+=CharToString(c);
     }
   StringToUpper(letters);
   if(StringLen(letters)<6)
      return(false);
   base=StringSubstr(letters,0,3);
   quote=StringSubstr(letters,3,3);
   return(true);
  }

bool HasHighImpactNewsForCurrency(const string currency,bool &calendarError)
  {
   if(StringLen(currency)!=3)
      return(false);
   datetime now=ServerNow();
   MqlCalendarValue values[];
   ResetLastError();
   int count=CalendarValueHistory(values,now-InpNewsBeforeMinutes*60,
                                  now+InpNewsAfterMinutes*60,NULL,currency);
   if(count<0)
     {
      calendarError=true;
      return(false);
     }
   for(int i=0;i<count;i++)
     {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id,event))
        {
         calendarError=true;
         continue;
        }
      if(event.importance>=CALENDAR_IMPORTANCE_HIGH)
         return(true);
     }
   return(false);
  }

bool IsNewsBlackout(string &reason)
  {
   if(!InpEnableNewsFilter)
      return(false);

   string base="",quote="";
   if(!ExtractCurrencyPair(_Symbol,base,quote))
     {
      reason="news filter unavailable: symbol currencies not identifiable";
      return(InpFailClosedOnNewsError);
     }

   bool calendarError=false;
   bool highImpact=HasHighImpactNewsForCurrency(base,calendarError) ||
                   HasHighImpactNewsForCurrency(quote,calendarError);
   if(calendarError && InpFailClosedOnNewsError)
     {
      reason="news calendar unavailable; fail-closed enabled";
      return(true);
     }
   if(highImpact)
     {
      reason="high-impact scheduled news blackout";
      return(true);
     }
   return(false);
  }

bool IsTerminalAndSymbolTradeable(string &reason)
  {
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      reason="terminal algorithmic trading disabled";
      return(false);
     }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     {
      reason="account disallows expert trading";
      return(false);
     }
   long mode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(mode!=SYMBOL_TRADE_MODE_FULL)
     {
      reason="symbol not fully tradeable";
      return(false);
     }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0)
     {
      reason="no valid current quote";
      return(false);
     }
   if(tick.time>0 && (ServerNow()-tick.time)>InpMaxTickAgeSeconds)
     {
      reason="price feed stale";
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Indicator and signal engine                                      |
//+------------------------------------------------------------------+
bool CalculateSessionVWAP(double &vwap)
  {
   vwap=0.0;
   datetime dayStart=DayStartTime();
   int oldestShift=iBarShift(_Symbol,InpExecutionTF,dayStart,false);
   if(oldestShift<0)
      oldestShift=iBarShift(_Symbol,InpExecutionTF,dayStart,true);
   if(oldestShift<=1)
      return(false);

   // On a new bar, shift 0 is the forming bar. Only closed bars are used.
   int count=oldestShift;
   if(count<InpMinVWAPBars)
      return(false);
   MqlRates bars[];
   int copied=CopyRates(_Symbol,InpExecutionTF,1,count,bars);
   if(copied<InpMinVWAPBars)
      return(false);

   double pv=0.0,vol=0.0;
   for(int i=0;i<copied;i++)
     {
      double volume=(bars[i].real_volume>0 ? (double)bars[i].real_volume : (double)bars[i].tick_volume);
      if(volume<=0.0)
         continue;
      double typical=(bars[i].high+bars[i].low+bars[i].close)/3.0;
      pv+=typical*volume;
      vol+=volume;
     }
   if(vol<=0.0)
      return(false);
   vwap=pv/vol;
   return(true);
  }

bool CalculateZScore(const int shift,const int period,double &zscore)
  {
   zscore=0.0;
   if(period<3)
      return(false);
   double closes[];
   int copied=CopyClose(_Symbol,InpExecutionTF,shift,period,closes);
   if(copied!=period)
      return(false);
   double mean=0.0;
   for(int i=0;i<copied;i++)
      mean+=closes[i];
   mean/=copied;
   double variance=0.0;
   for(int i=0;i<copied;i++)
     {
      double d=closes[i]-mean;
      variance+=d*d;
     }
   variance/=copied;
   double sd=MathSqrt(variance);
   if(sd<=0.0)
      return(false);
   // CopyClose stores the oldest requested element first in physical memory.
   zscore=(closes[copied-1]-mean)/sd;
   return(true);
  }

bool GetReversalState(SignalSnapshot &s)
  {
   MqlRates bars[];
   if(CopyRates(_Symbol,InpExecutionTF,1,3,bars)!=3)
      return(false);
   MqlRates current=bars[2];
   MqlRates previous=bars[1];
   s.barTime=current.time;
   s.closePrice=current.close;
   s.previousClose=previous.close;
   s.barHigh=current.high;
   s.barLow=current.low;
   s.barRange=current.high-current.low;

   double curRange=MathMax(current.high-current.low,_Point);
   double prevRange=MathMax(previous.high-previous.low,_Point);
   double curBody=MathAbs(current.close-current.open);
   double lowerWick=MathMin(current.open,current.close)-current.low;
   double upperWick=current.high-MathMax(current.open,current.close);

   bool bullishEngulf=(current.close>current.open && previous.close<previous.open &&
                        current.close>=previous.open && current.open<=previous.close);
   bool bearishEngulf=(current.close<current.open && previous.close>previous.open &&
                        current.close<=previous.open && current.open>=previous.close);
   bool hammer=(lowerWick>=2.0*curBody && curBody/curRange<=0.40 && upperWick<=curRange*0.35);
   bool shootingStar=(upperWick>=2.0*curBody && curBody/curRange<=0.40 && lowerWick<=curRange*0.35);
   bool strongBull=(current.close>current.open && curBody/curRange>=0.60 && current.close>previous.high);
   bool strongBear=(current.close<current.open && curBody/curRange>=0.60 && current.close<previous.low);

   bool bullCandle=(!InpUseEngulfingConfirmation || bullishEngulf) ||
                   (!InpUseWickConfirmation || hammer) ||
                   (!InpUseStrongCloseConfirmation || strongBull);
   bool bearCandle=(!InpUseEngulfingConfirmation || bearishEngulf) ||
                   (!InpUseWickConfirmation || shootingStar) ||
                   (!InpUseStrongCloseConfirmation || strongBear);
   // If every candle selector is disabled, candle confirmation is unavailable, not automatically true.
   if(!InpUseEngulfingConfirmation && !InpUseWickConfirmation && !InpUseStrongCloseConfirmation)
     {
      bullCandle=false;
      bearCandle=false;
     }
   s.longReversal=bullCandle && (s.rsi>s.rsiPrev || s.zscore>s.zscorePrev || current.close>previous.high);
   s.shortReversal=bearCandle && (s.rsi<s.rsiPrev || s.zscore<s.zscorePrev || current.close<previous.low);
   return(true);
  }

bool PopulateSnapshot(SignalSnapshot &s)
  {
   ResetSnapshot(s);
   if(!CalculateSessionVWAP(s.vwap))
      return(false);

   double upper[2],middle[2],lower[2],rsi[2],atr[1],adx[1];
   double ema20[2],ema50[2],ema200[2];
   if(CopyBuffer(g_handleBands,1,1,2,upper)!=2 ||
      CopyBuffer(g_handleBands,0,1,2,middle)!=2 ||
      CopyBuffer(g_handleBands,2,1,2,lower)!=2 ||
      CopyBuffer(g_handleRSI,0,1,2,rsi)!=2 ||
      CopyBuffer(g_handleATR,0,1,1,atr)!=1 ||
      CopyBuffer(g_handleADX,0,1,1,adx)!=1 ||
      CopyBuffer(g_handleEMA20,0,1,2,ema20)!=2 ||
      CopyBuffer(g_handleEMA50,0,1,2,ema50)!=2 ||
      CopyBuffer(g_handleEMA200,0,1,2,ema200)!=2)
      return(false);

   // Index 1 is the most recent closed bar when multiple values are copied.
   s.bandUpper=upper[1];
   s.bandMiddle=middle[1];
   s.bandLower=lower[1];
   s.bandUpperPrev=upper[0];
   s.bandLowerPrev=lower[0];
   s.bandWidth=s.bandUpper-s.bandLower;
   s.rsi=rsi[1];
   s.rsiPrev=rsi[0];
   s.atr=atr[0];
   s.adx=adx[0];
   s.ema20=ema20[1];
   s.ema20Prev=ema20[0];
   s.ema50=ema50[1];
   s.ema200=ema200[1];
   if(s.atr<=0.0)
      return(false);
   if(!CalculateZScore(1,InpZScorePeriod,s.zscore) ||
      !CalculateZScore(2,InpZScorePeriod,s.zscorePrev))
      return(false);
   if(!GetReversalState(s))
      return(false);

   double atrSeries[];
   int got=CopyBuffer(g_handleATR,0,1,InpATRNormalLookback,atrSeries);
   if(got<MathMin(InpATRNormalLookback,10))
      return(false);
   s.normalAtr=0.0;
   for(int i=0;i<got;i++)
      s.normalAtr+=atrSeries[i];
   s.normalAtr/=got;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return(false);
   s.spreadPips=(tick.ask-tick.bid)/PipSize();
   s.spreadOK=IsSpreadAcceptable(s.spreadPips,s.atr);
   s.vwapDistanceATR=(s.closePrice-s.vwap)/s.atr;

   bool strongEMAUp=(s.ema20>s.ema50 && s.ema50>s.ema200);
   bool strongEMADown=(s.ema20<s.ema50 && s.ema50<s.ema200);
   double emaSeparation=MathAbs(s.ema20-s.ema50);
   bool strongTrend=(s.adx>=InpADXTrendThreshold &&
                    (emaSeparation>=InpEMASepATR*s.atr || strongEMAUp || strongEMADown));
   bool bandWidthReasonable=(s.bandWidth>=InpMinBandWidthATR*s.atr &&
                             s.bandWidth<=InpMaxBandWidthATR*s.atr);
   bool rangeMarket=(s.adx<InpADXTrendThreshold && bandWidthReasonable &&
                     emaSeparation<=InpEMASepATR*s.atr && !strongTrend);
   if(strongTrend)
      s.regime="TREND";
   else if(rangeMarket)
      s.regime="RANGE";
   else
      s.regime="MIXED";

   s.abnormalVolatility=(s.normalAtr>0.0 && s.atr>InpAbnormalATRMultiplier*s.normalAtr) ||
                        (s.barRange>InpAbnormalCandleATRMultiple*s.atr) ||
                        (g_spreadEmaPips>0.0 && s.spreadPips>InpSpreadExpansionMultiple*g_spreadEmaPips);

   s.longReturnInside=(s.closePrice>s.bandLower && s.previousClose<=s.bandLowerPrev);
   s.shortReturnInside=(s.closePrice<s.bandUpper && s.previousClose>=s.bandUpperPrev);
   return(true);
  }

bool IsRegimeAllowed(const SignalSnapshot &s)
  {
   if(InpTrendFilterMode==MR_TREND_DISABLED)
      return(true);
   if(InpTrendFilterMode==MR_TREND_MODERATE)
      return(s.regime!="TREND");
   return(s.regime=="RANGE");
  }

void ScoreSignal(SignalSnapshot &s)
  {
   s.longScore=0;
   s.shortScore=0;

   if(s.vwapDistanceATR<=-InpVWAPDeviationATR)
      s.longScore+=SCORE_VWAP;
   if(s.vwapDistanceATR>=InpVWAPDeviationATR)
      s.shortScore+=SCORE_VWAP;
   if(s.barLow<=s.bandLower)
      s.longScore+=SCORE_BB;
   if(s.barHigh>=s.bandUpper)
      s.shortScore+=SCORE_BB;
   if(s.zscore<=-InpZScoreThreshold)
      s.longScore+=SCORE_ZSCORE;
   if(s.zscore>=InpZScoreThreshold)
      s.shortScore+=SCORE_ZSCORE;
   if(s.rsi<=InpRSIOversold)
      s.longScore+=SCORE_RSI;
   if(s.rsi>=InpRSIOverbought)
      s.shortScore+=SCORE_RSI;
   if(s.longReversal)
      s.longScore+=SCORE_REVERSAL;
   if(s.shortReversal)
      s.shortScore+=SCORE_REVERSAL;
   if(InpUseReturnInsideBand && s.longReturnInside)
      s.longScore+=SCORE_RETURN;
   if(InpUseReturnInsideBand && s.shortReturnInside)
      s.shortScore+=SCORE_RETURN;
   if(s.regime=="RANGE")
     {
      s.longScore+=SCORE_REGIME;
      s.shortScore+=SCORE_REGIME;
     }
   if(s.spreadOK)
     {
      s.longScore+=SCORE_SPREAD;
      s.shortScore+=SCORE_SPREAD;
     }

   if(s.longScore>=InpMinimumSignalScore && s.longScore>s.shortScore)
      s.action="BUY CANDIDATE";
   else if(s.shortScore>=InpMinimumSignalScore && s.shortScore>s.longScore)
      s.action="SELL CANDIDATE";
   else
      s.action="WAITING";
  }

//+------------------------------------------------------------------+
//| Position, portfolio, and execution safety                        |
//+------------------------------------------------------------------+
bool HasAnyPositionOnSymbol()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol)
         return(true);
     }
   return(false);
  }

bool HasOwnedPosition(const string symbol)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)==symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)
         return(true);
     }
   return(false);
  }

bool HasOwnedPendingOrder(const string symbol)
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0)
         continue;
      if(OrderGetString(ORDER_SYMBOL)==symbol &&
         (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagicNumber)
         return(true);
     }
   return(false);
  }

bool SymbolsShareCurrency(const string first,const string second)
  {
   string firstBase="",firstQuote="",secondBase="",secondQuote="";
   if(!ExtractCurrencyPair(first,firstBase,firstQuote) ||
      !ExtractCurrencyPair(second,secondBase,secondQuote))
      return(false);
   return(firstBase==secondBase || firstBase==secondQuote ||
          firstQuote==secondBase || firstQuote==secondQuote);
  }

double PositionRiskMoney()
  {
   double total=0.0;
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(tickSize<=0.0 || tickValue<=0.0)
      return(0.0);
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
         continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(!SymbolSelect(symbol,true))
         continue;
      double sl=PositionGetDouble(POSITION_SL);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double volume=PositionGetDouble(POSITION_VOLUME);
      if(sl<=0.0 || open<=0.0 || volume<=0.0)
         continue;
      double posTickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double posTickValue=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      if(posTickSize<=0.0 || posTickValue<=0.0)
         continue;
      total+=MathAbs(open-sl)/posTickSize*posTickValue*volume;
     }
   return(total);
  }

double CorrelatedOpenRiskMoney()
  {
   double total=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
         continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(!SymbolsShareCurrency(_Symbol,symbol))
         continue;
      double sl=PositionGetDouble(POSITION_SL);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double volume=PositionGetDouble(POSITION_VOLUME);
      double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double tickValue=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      if(sl>0.0 && open>0.0 && volume>0.0 && tickSize>0.0 && tickValue>0.0)
         total+=MathAbs(open-sl)/tickSize*tickValue*volume;
     }
   return(total);
  }

double CalculateVolumeByRisk(const ENUM_ORDER_TYPE direction,const double entry,const double sl)
  {
   double stopDistance=MathAbs(entry-sl);
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double minVolume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxVolume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(stopDistance<=0.0 || tickSize<=0.0 || tickValue<=0.0 || step<=0.0)
      return(0.0);

   double riskMoney=AccountInfoDouble(ACCOUNT_EQUITY)*EffectiveRiskPercent()/100.0;
   double moneyPerLot=stopDistance/tickSize*tickValue;
   if(riskMoney<=0.0 || moneyPerLot<=0.0)
      return(0.0);
   double rawVolume=riskMoney/moneyPerLot;
   double volume=MathFloor(rawVolume/step+1e-10)*step;
   volume=MathMin(volume,maxVolume);
   volume=NormalizeDouble(volume,VolumeDigits());
   if(volume<minVolume)
      return(0.0);

   // Defensive check: flooring plus floating-point error must not exceed configured risk.
   if(volume*moneyPerLot>riskMoney*(1.0+1e-8))
      volume=NormalizeDouble(MathFloor((riskMoney/moneyPerLot)/step-1e-8)*step,VolumeDigits());
   if(volume<minVolume)
      return(0.0);

   double margin=0.0;
   if(!OrderCalcMargin(direction,_Symbol,volume,entry,margin))
      return(0.0);
   if(margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)*InpMaxMarginUseFraction)
      return(0.0);
   return(volume);
  }

bool BuildOrderPrices(const ENUM_ORDER_TYPE direction,const SignalSnapshot &s,
                      const double entry,double &sl,double &tp,string &reason)
  {
   double stopLevel=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point+
                    InpStopBufferPoints*_Point;
   double stopDistance=MathMax(s.atr*InpATRStopMultiplier,stopLevel);
   if(stopDistance<=0.0)
     {
      reason="invalid ATR or stop distance";
      return(false);
     }

   if(direction==ORDER_TYPE_BUY)
      sl=entry-stopDistance;
   else
      sl=entry+stopDistance;
   sl=NormalizePriceToTick(sl);

   double meanTarget=0.0;
   if(direction==ORDER_TYPE_BUY)
     {
      bool vwapValid=(s.vwap>entry+stopLevel);
      bool bbValid=(s.bandMiddle>entry+stopLevel);
      if(vwapValid && bbValid)
         meanTarget=MathMin(s.vwap,s.bandMiddle);
      else if(vwapValid)
         meanTarget=s.vwap;
      else if(bbValid)
         meanTarget=s.bandMiddle;
     }
   else
     {
      bool vwapValid=(s.vwap<entry-stopLevel);
      bool bbValid=(s.bandMiddle<entry-stopLevel);
      if(vwapValid && bbValid)
         meanTarget=MathMax(s.vwap,s.bandMiddle);
      else if(vwapValid)
         meanTarget=s.vwap;
      else if(bbValid)
         meanTarget=s.bandMiddle;
     }

   if(InpTargetModel==MR_TARGET_VWAP)
      tp=s.vwap;
   else if(InpTargetModel==MR_TARGET_BB_MID)
      tp=s.bandMiddle;
   else if(InpTargetModel==MR_TARGET_FIXED_RR)
      tp=(direction==ORDER_TYPE_BUY ? entry+stopDistance*InpFixedRiskReward : entry-stopDistance*InpFixedRiskReward);
   else if(InpTargetModel==MR_TARGET_ATR)
      tp=(direction==ORDER_TYPE_BUY ? entry+s.atr*InpATRTargetMultiplier : entry-s.atr*InpATRTargetMultiplier);
   else
      tp=meanTarget;

   tp=NormalizePriceToTick(tp);
   double reward=(direction==ORDER_TYPE_BUY ? tp-entry : entry-tp);
   double risk=MathAbs(entry-sl);
   if(risk<=0.0 || reward<=0.0)
     {
      reason="no valid mean-reversion target beyond entry";
      return(false);
     }
   if(reward<stopLevel)
     {
      reason="target violates broker minimum stop distance";
      return(false);
     }
   if(reward/risk<InpMinimumRR)
     {
      reason=StringFormat("projected R:R %.2f below minimum %.2f",reward/risk,InpMinimumRR);
      return(false);
     }
   return(true);
  }

bool CanOpenNewPosition(const SignalSnapshot &s,string &reason)
  {
   if(!InpEnableTrading)
     {
      reason="trading disabled by input";
      return(false);
     }
   if(g_drawdownLock)
     {
      reason="maximum account drawdown risk lock active";
      return(false);
     }
   if(g_dailyLossLock)
     {
      reason="daily loss limit reached";
      return(false);
     }
   if(g_dailyProfitLock)
     {
      reason="daily profit target reached";
      return(false);
     }
   if(InpMaxTradesPerDay>0 && g_tradesToday>=InpMaxTradesPerDay)
     {
      reason="maximum trades per day reached";
      return(false);
     }
   if(g_pauseUntil>ServerNow())
     {
      reason="consecutive-loss cooldown active";
      return(false);
     }
   if(g_lastTradeTime>0 && (ServerNow()-g_lastTradeTime)<InpCooldownMinutes*60)
     {
      reason="post-trade cooldown active";
      return(false);
     }
   if(g_lastTradeTime>0 && (ServerNow()-g_lastTradeTime)<InpExecutionFailurePauseSec)
     {
      // The same timestamp is also used after a failure for a conservative pause.
      // This extra check is harmless because the normal cooldown is typically longer.
     }
   if(!IsWithinSession())
     {
      reason="outside configured session";
      return(false);
     }
   if(IsRolloverBlackout())
     {
      reason="rollover blackout active";
      return(false);
     }
   if(!s.spreadOK)
     {
      reason="spread exceeds configured limit";
      return(false);
     }
   if(s.abnormalVolatility)
     {
      reason="abnormal volatility or spread expansion";
      return(false);
     }
   if(!IsRegimeAllowed(s))
     {
      reason="market regime unsuitable for mean reversion";
      return(false);
     }
   if(HasAnyPositionOnSymbol())
     {
      reason="an existing position on the symbol blocks duplicate or netting exposure";
      return(false);
     }
   if(HasOwnedPendingOrder(_Symbol))
     {
      reason="existing EA pending order detected";
      return(false);
     }
   if(!IsTerminalAndSymbolTradeable(reason))
      return(false);
   if(IsNewsBlackout(reason))
      return(false);
   return(true);
  }

bool StoreInitialStopForCurrentSymbol(const double initialStop)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)
        {
         GlobalVariableSet(InitialStopKey(ticket),initialStop);
         return(true);
        }
     }
   return(false);
  }

bool ExecuteMarketOrder(const ENUM_ORDER_TYPE direction,const SignalSnapshot &s,
                        const double volume,const double sl,const double tp)
  {
   bool accepted=false;
   if(direction==ORDER_TYPE_BUY)
      accepted=g_trade.Buy(volume,_Symbol,0.0,sl,tp,"MR_Sniper_Long");
   else
      accepted=g_trade.Sell(volume,_Symbol,0.0,sl,tp,"MR_Sniper_Short");

   uint retcode=g_trade.ResultRetcode();
   if(!accepted || !IsTradeRetcodeSuccess(retcode))
     {
      string reason=StringFormat("order rejected: accepted=%s retcode=%u %s",
                                 BoolText(accepted),retcode,g_trade.ResultRetcodeDescription());
      WriteLog("EXECUTION_FAILED",s,DirectionText(direction),0.0,sl,tp,volume,reason);
      g_lastTradeTime=ServerNow();
      return(false);
     }

   StoreInitialStopForCurrentSymbol(sl);
   double actualEntry=g_trade.ResultPrice();
   WriteLog("ENTRY_EXECUTED",s,DirectionText(direction),actualEntry,sl,tp,volume,
            StringFormat("retcode=%u %s",retcode,g_trade.ResultRetcodeDescription()));
   g_lastTradeTime=ServerNow();
   return(true);
  }

//+------------------------------------------------------------------+
//| Position management                                               |
//+------------------------------------------------------------------+
bool CloseOwnedPosition(const ulong ticket,const string reason)
  {
   if(!PositionSelectByTicket(ticket))
      return(false);
   if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
      return(false);
   string symbol=PositionGetString(POSITION_SYMBOL);
   if(!g_trade.PositionClose(ticket))
     {
      Print("MR Sniper: close request failed for ",ticket,". ",g_trade.ResultRetcodeDescription());
      return(false);
     }
   if(!IsTradeRetcodeSuccess(g_trade.ResultRetcode()))
     {
      Print("MR Sniper: close rejected for ",ticket,". ",g_trade.ResultRetcodeDescription());
      return(false);
     }
   Print("MR Sniper: closed position ",ticket," on ",symbol,". Reason: ",reason);
   return(true);
  }

void CloseAllOwnedPositions(const string reason)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)
         CloseOwnedPosition(ticket,reason);
     }
  }

double GetInitialStop(const ulong ticket,const double fallback)
  {
   string key=InitialStopKey(ticket);
   if(GlobalVariableCheck(key))
      return(GlobalVariableGet(key));
   return(fallback);
  }

bool CanModifyStop(const bool isBuy,const double proposedSL,const MqlTick &tick)
  {
   double minDistance=((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)+
                       (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
   if(isBuy)
      return((tick.bid-proposedSL)>=minDistance);
   return((proposedSL-tick.ask)>=minDistance);
  }

void ManageOwnedPositions()
  {
   if(g_dailyLossLock && InpClosePositionsOnDailyLoss)
      CloseAllOwnedPositions("daily loss limit breached");

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return;
   double currentATR=0.0;
   double atrValue[1];
   if(CopyBuffer(g_handleATR,0,0,1,atrValue)==1)
      currentATR=atrValue[0];

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;

      long positionType=PositionGetInteger(POSITION_TYPE);
      bool isBuy=(positionType==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL=PositionGetDouble(POSITION_SL);
      double currentTP=PositionGetDouble(POSITION_TP);
      datetime openTime=(datetime)PositionGetInteger(POSITION_TIME);
      double marketPrice=(isBuy ? tick.bid : tick.ask);

      if(InpEnableTimeStop && InpMaxTradeDurationMinutes>0 &&
         ServerNow()-openTime>=InpMaxTradeDurationMinutes*60)
        {
         CloseOwnedPosition(ticket,"maximum trade duration reached");
         continue;
        }

      double initialSL=GetInitialStop(ticket,currentSL);
      double initialRisk=MathAbs(entry-initialSL);
      if(initialRisk<=0.0)
         initialRisk=MathAbs(entry-currentSL);
      if(initialRisk<=0.0)
         continue;
      double currentProfitDistance=(isBuy ? marketPrice-entry : entry-marketPrice);

      if(InpEnableBreakEven && currentProfitDistance>=InpBreakEvenTriggerR*initialRisk)
        {
         double breakEven=(isBuy ? entry+InpBreakEvenBufferPoints*_Point : entry-InpBreakEvenBufferPoints*_Point);
         breakEven=NormalizePriceToTick(breakEven);
         bool improves=(isBuy ? (currentSL<=0.0 || breakEven>currentSL) : (currentSL<=0.0 || breakEven<currentSL));
         if(improves && CanModifyStop(isBuy,breakEven,tick))
           {
            if(g_trade.PositionModify(ticket,breakEven,currentTP) && IsTradeRetcodeSuccess(g_trade.ResultRetcode()))
               currentSL=breakEven;
           }
        }

      if(InpEnableTrailingStop && currentATR>0.0)
        {
         double trailSL=(isBuy ? marketPrice-currentATR*InpTrailingATRMultiplier : marketPrice+currentATR*InpTrailingATRMultiplier);
         trailSL=NormalizePriceToTick(trailSL);
         bool improves=(isBuy ? trailSL>currentSL : (currentSL<=0.0 || trailSL<currentSL));
         if(improves && CanModifyStop(isBuy,trailSL,tick))
            g_trade.PositionModify(ticket,trailSL,currentTP);
        }
     }
  }

//+------------------------------------------------------------------+
//| Dashboard                                                        |
//+------------------------------------------------------------------+
string TradingStatus()
  {
   if(g_drawdownLock)
      return("RISK LOCK: MAX DRAWDOWN");
   if(g_dailyLossLock)
      return("RISK LOCK: DAILY LOSS");
   if(g_dailyProfitLock)
      return("PAUSED: DAILY TARGET");
   if(g_pauseUntil>ServerNow())
      return("PAUSED: LOSS COOLDOWN");
   if(!InpEnableTrading)
      return("PAUSED: INPUT DISABLED");
   return("ACTIVE");
  }

void UpdateDashboard(const SignalSnapshot &s)
  {
   if(!InpEnableDashboard)
      return;
   if(ObjectFind(0,g_dashboardName)<0)
     {
      ObjectCreate(0,g_dashboardName,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,g_dashboardName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,g_dashboardName,OBJPROP_XDISTANCE,InpDashboardX);
      ObjectSetInteger(0,g_dashboardName,OBJPROP_YDISTANCE,InpDashboardY);
      ObjectSetInteger(0,g_dashboardName,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,g_dashboardName,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,g_dashboardName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,g_dashboardName,OBJPROP_HIDDEN,true);
     }
   string text=StringFormat(
      "MR SNIPER | HISTORICAL RESULTS DO NOT GUARANTEE FUTURE PERFORMANCE\n"
      "Status: %s | %s %s\n"
      "Regime: %s | Action: %s | Session: %s\n"
      "VWAP: %.5f | Z: %.2f | RSI: %.1f | ATR: %.5f | ADX: %.1f\n"
      "Spread: %.2f pips | Volatility: %s\n"
      "Long score: %d/100 | Short score: %d/100\n"
      "Daily P/L: %.2f%% | Loss limit: %.2f%% | Trades: %d/%d\n"
      "Consecutive losses: %d/%d | Risk/trade: %.2f%% | DD: %.2f%%\n"
      "Server time: %s",
      TradingStatus(),_Symbol,EnumToString(InpExecutionTF),
      s.regime,s.action,BoolText(IsWithinSession()),
      s.vwap,s.zscore,s.rsi,s.atr,s.adx,
      s.spreadPips,(s.abnormalVolatility ? "ABNORMAL" : "NORMAL"),
      s.longScore,s.shortScore,CurrentDailyPnLPercent(),InpMaxDailyLossPercent,
      g_tradesToday,InpMaxTradesPerDay,g_consecutiveLosses,InpMaxConsecutiveLosses,
      EffectiveRiskPercent(),CurrentDrawdownPercent(),TimeToString(ServerNow(),TIME_DATE|TIME_SECONDS));
   ObjectSetString(0,g_dashboardName,OBJPROP_TEXT,text);
   color dashboardColor=(g_drawdownLock || g_dailyLossLock ? clrTomato : (s.action!="WAITING" ? clrLime : clrWhite));
   ObjectSetInteger(0,g_dashboardName,OBJPROP_COLOR,dashboardColor);
  }

//+------------------------------------------------------------------+
//| Main decision workflow                                           |
//+------------------------------------------------------------------+
bool IsNewExecutionBar()
  {
   datetime time0=iTime(_Symbol,InpExecutionTF,0);
   if(time0<=0)
      return(false);
   if(g_lastBarTime==0)
     {
      g_lastBarTime=time0;
      return(true);
     }
   if(time0!=g_lastBarTime)
     {
      g_lastBarTime=time0;
      return(true);
     }
   return(false);
  }

void EvaluateAndTrade()
  {
   SignalSnapshot s;
   if(!PopulateSnapshot(s))
     {
      ResetSnapshot(s);
      s.action="NO TRADE";
      s.rejection="indicator or price data unavailable";
      WriteLog("DATA_REJECT",s,"NONE",0.0,0.0,0.0,0.0,s.rejection);
      UpdateDashboard(s);
      return;
     }
   ScoreSignal(s);
   g_lastSnapshot=s;
   UpdateDashboard(s);

   string reason="";
   if(!CanOpenNewPosition(s,reason))
     {
      s.action="NO TRADE";
      s.rejection=reason;
      WriteLog("SIGNAL_REJECTED",s,"NONE",0.0,0.0,0.0,0.0,reason);
      UpdateDashboard(s);
      return;
     }

   ENUM_ORDER_TYPE direction;
   if(s.longScore>=InpMinimumSignalScore && s.longScore>s.shortScore)
      direction=ORDER_TYPE_BUY;
   else if(s.shortScore>=InpMinimumSignalScore && s.shortScore>s.longScore)
      direction=ORDER_TYPE_SELL;
   else
     {
      reason=StringFormat("score below threshold: L=%d S=%d required=%d",s.longScore,s.shortScore,InpMinimumSignalScore);
      s.action="NO TRADE";
      s.rejection=reason;
      WriteLog("SIGNAL_REJECTED",s,"NONE",0.0,0.0,0.0,0.0,reason);
      UpdateDashboard(s);
      return;
     }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
     {
      WriteLog("SIGNAL_REJECTED",s,DirectionText(direction),0.0,0.0,0.0,0.0,"quote unavailable at execution");
      return;
     }
   double entry=(direction==ORDER_TYPE_BUY ? tick.ask : tick.bid);
   double sl=0.0,tp=0.0;
   if(!BuildOrderPrices(direction,s,entry,sl,tp,reason))
     {
      s.action="NO TRADE";
      s.rejection=reason;
      WriteLog("SIGNAL_REJECTED",s,DirectionText(direction),entry,sl,tp,0.0,reason);
      UpdateDashboard(s);
      return;
     }

   double volume=CalculateVolumeByRisk(direction,entry,sl);
   if(volume<=0.0)
     {
      s.action="NO TRADE";
      s.rejection="position size invalid, below broker minimum, or insufficient margin";
      WriteLog("RISK_REJECTED",s,DirectionText(direction),entry,sl,tp,0.0,s.rejection);
      UpdateDashboard(s);
      return;
     }

   double orderRiskMoney=MathAbs(entry-sl)/SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*
                         SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE)*volume;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(InpUsePortfolioRiskGuard && equity>0.0 &&
      100.0*(PositionRiskMoney()+orderRiskMoney)/equity>InpMaxPortfolioRiskPercent)
     {
      s.action="NO TRADE";
      s.rejection="maximum portfolio risk would be exceeded";
      WriteLog("PORTFOLIO_REJECTED",s,DirectionText(direction),entry,sl,tp,volume,s.rejection);
      UpdateDashboard(s);
      return;
     }
   if(InpUseCorrelationGuard && equity>0.0 &&
      100.0*(CorrelatedOpenRiskMoney()+orderRiskMoney)/equity>InpMaxCorrelatedRiskPercent)
     {
      s.action="NO TRADE";
      s.rejection="correlated currency exposure would be exceeded";
      WriteLog("CORRELATION_REJECTED",s,DirectionText(direction),entry,sl,tp,volume,s.rejection);
      UpdateDashboard(s);
      return;
     }

   s.action=(direction==ORDER_TYPE_BUY ? "BUY" : "SELL");
   UpdateDashboard(s);
   ExecuteMarketOrder(direction,s,volume,sl,tp);
  }

//+------------------------------------------------------------------+
//| MT5 event handlers                                               |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!SymbolSelect(_Symbol,true))
     {
      Print("MR Sniper: unable to select chart symbol.");
      return(INIT_FAILED);
     }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpMaxSlippagePoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);
   g_trade.SetMarginMode();

   g_handleBands=iBands(_Symbol,InpExecutionTF,InpBollingerPeriod,0,InpBollingerDeviation,PRICE_CLOSE);
   g_handleRSI=iRSI(_Symbol,InpExecutionTF,InpRSIPeriod,PRICE_CLOSE);
   g_handleATR=iATR(_Symbol,InpExecutionTF,InpATRPeriod);
   g_handleADX=iADX(_Symbol,InpExecutionTF,InpADXPeriod);
   g_handleEMA20=iMA(_Symbol,InpHigherTF,InpEMA20Period,0,MODE_EMA,PRICE_CLOSE);
   g_handleEMA50=iMA(_Symbol,InpHigherTF,InpEMA50Period,0,MODE_EMA,PRICE_CLOSE);
   g_handleEMA200=iMA(_Symbol,InpHigherTF,InpEMA200Period,0,MODE_EMA,PRICE_CLOSE);
   if(g_handleBands==INVALID_HANDLE || g_handleRSI==INVALID_HANDLE ||
      g_handleATR==INVALID_HANDLE || g_handleADX==INVALID_HANDLE ||
      g_handleEMA20==INVALID_HANDLE || g_handleEMA50==INVALID_HANDLE ||
      g_handleEMA200==INVALID_HANDLE)
     {
      Print("MR Sniper: indicator handle creation failed. Error=",GetLastError());
      return(INIT_FAILED);
     }

   if(InpManualResetRiskLock)
      GlobalVariableDel(DrawdownLockKey());
   g_drawdownLock=GlobalVariableCheck(DrawdownLockKey());
   if(GlobalVariableCheck(HighWaterKey()))
      g_equityHighWater=GlobalVariableGet(HighWaterKey());
   else
     {
      g_equityHighWater=AccountInfoDouble(ACCOUNT_EQUITY);
      GlobalVariableSet(HighWaterKey(),g_equityHighWater);
     }

   ResetDailyStateIfNeeded();
   RebuildDailyStats();
   RefreshRiskState();
   ResetSnapshot(g_lastSnapshot);
   UpdateDashboard(g_lastSnapshot);
   Print("MR Sniper initialized on ",_Symbol,". Strategy testing and demo validation are required before live use.");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_handleBands!=INVALID_HANDLE)  IndicatorRelease(g_handleBands);
   if(g_handleRSI!=INVALID_HANDLE)    IndicatorRelease(g_handleRSI);
   if(g_handleATR!=INVALID_HANDLE)    IndicatorRelease(g_handleATR);
   if(g_handleADX!=INVALID_HANDLE)    IndicatorRelease(g_handleADX);
   if(g_handleEMA20!=INVALID_HANDLE)  IndicatorRelease(g_handleEMA20);
   if(g_handleEMA50!=INVALID_HANDLE)  IndicatorRelease(g_handleEMA50);
   if(g_handleEMA200!=INVALID_HANDLE) IndicatorRelease(g_handleEMA200);
   ObjectDelete(0,g_dashboardName);
  }

void OnTick()
  {
   UpdateSpreadEMA();
   RefreshRiskState();
   ManageOwnedPositions();
   if(IsNewExecutionBar())
      EvaluateAndTrade();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if((ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=InpMagicNumber)
      return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol)
      return;

   long entryType=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(entryType==DEAL_ENTRY_OUT || entryType==DEAL_ENTRY_OUT_BY)
     {
      RebuildDailyStats();
      double profit=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+
                    HistoryDealGetDouble(trans.deal,DEAL_SWAP)+
                    HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
      WriteLog("EXIT_RECORDED",g_lastSnapshot,"EXIT",HistoryDealGetDouble(trans.deal,DEAL_PRICE),
               0.0,0.0,HistoryDealGetDouble(trans.deal,DEAL_VOLUME),
               StringFormat("realized net %.2f",profit));
     }
  }

// Custom optimization objective: favor robust efficiency over raw net profit.
double OnTester()
  {
   double profitFactor=TesterStatistics(STAT_PROFIT_FACTOR);
   double drawdown=TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double recovery=TesterStatistics(STAT_RECOVERY_FACTOR);
   double trades=TesterStatistics(STAT_TRADES);
   if(trades<30.0 || profitFactor<=0.0 || drawdown<=0.0)
      return(0.0);
   double samplePenalty=MathMin(1.0,trades/100.0);
   return(profitFactor*MathMax(0.0,recovery)*samplePenalty/MathMax(1.0,drawdown));
  }
//+------------------------------------------------------------------+
