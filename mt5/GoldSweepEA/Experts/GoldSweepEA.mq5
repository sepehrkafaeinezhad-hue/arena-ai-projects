//+------------------------------------------------------------------+
//|                                                  GoldSweepEA.mq5 |
//|                     Liquidity-sweep Expert Advisor for XAUUSD     |
//|                                                                  |
//|  v2.00 - full rewrite of the reviewed v1.00 (305-line) file.      |
//|                                                                  |
//|  STRATEGY (documented behaviour preserved from v1.00)             |
//|   * Trade only on CLOSED bars of InpSignalTF (default M15).       |
//|   * Sweep of liquidity: the last closed bar takes out the          |
//|     extreme of the previous N bars and closes back inside.        |
//|   * Optional trend filter: EMA fast/slow on a higher timeframe.   |
//|   * SL beyond the sweep extreme by ATR * multiplier, TP at R:R.   |
//|   * Risk-based lot sizing, daily loss hard stop, session filter.  |
//|                                                                  |
//|  IMPORTANT                                                       |
//|   - This EA is NOT a guarantee of profit. Test on DEMO and in     |
//|     the Strategy Tester before any real use.                     |
//|   - Real trading is blocked by default (InpEnableLiveTrading).    |
//|   - Designed for MT5 build 3000+ (uses input group).              |
//+------------------------------------------------------------------+
#property copyright "GoldSweepEA"
#property version   "2.00"
#property description "Liquidity-sweep EA for XAUUSD. Closed-bar signals, ATR stops, R targets, hard risk limits."
#property description "DEMO / STRATEGY TESTER FIRST. No profit guarantee. Not financial advice."

//+------------------------------------------------------------------+
//| 0. Enumerations                                                  |
//+------------------------------------------------------------------+
enum ENUM_GS_RISK_MODE
  {
   GS_RISK_PERCENT   = 0,   // Risk percent of equity/balance
   GS_RISK_FIXED_LOT = 1    // Fixed lot size
  };

enum ENUM_GS_LOSS_SCOPE
  {
   GS_SCOPE_EA      = 0,    // This EA only (magic + symbol)
   GS_SCOPE_ACCOUNT = 1     // Whole account
  };

enum ENUM_GS_FILLING
  {
   GS_FILL_AUTO   = 0,      // Auto (broker supported)
   GS_FILL_FOK    = 1,      // Force FOK
   GS_FILL_IOC    = 2,      // Force IOC
   GS_FILL_RETURN = 3       // Force RETURN
  };

//+------------------------------------------------------------------+
//| 1. Inputs                                                        |
//+------------------------------------------------------------------+
input group "===== 1) General ====="
input long            InpMagic              = 20261022;  // Magic number (unique per chart/symbol)
input bool            InpEnableTrading      = true;      // Master switch: allow new entries
input bool            InpDryRun             = false;     // Dry run: log orders, do not send
input bool            InpEnableLiveTrading  = false;     // Allow trading on REAL accounts
input bool            InpPersistState       = true;      // Persist state in MQL5/Files
input bool            InpResetState         = false;     // Ignore saved state at start (fresh test)
input int             InpLogLevel           = 2;         // Log level: 0 errors, 1 warn, 2 info, 3 debug
input bool            InpAlerts             = false;     // Popup alerts on errors/entries (live only)
input bool            InpShowDashboard      = true;      // Show on-chart dashboard
input bool            InpWriteTradeLog      = true;      // Append trade events to CSV in MQL5/Files

input group "===== 2) Signal: liquidity sweep ====="
input ENUM_TIMEFRAMES InpSignalTF           = PERIOD_M15; // Signal timeframe (closed bars only)
input int             InpSweepLookback      = 16;         // Lookback bars for the sweep level (>= 3)
input double          InpMinPenetrationATR   = 0.10;      // Min penetration beyond level (x ATR)
input double          InpReclaimBufferATR    = 0.00;      // Close back inside by this buffer (x ATR)
input bool            InpRequireReversalClose= true;      // Require reversal candle (close vs open)
input double          InpMaxBarRangeATR      = 3.00;      // Skip if signal bar range > x ATR (0 = off)
input int             InpAtrPeriod           = 14;        // ATR period

input group "===== 3) Trend filter ====="
input bool            InpUseTrendFilter     = true;       // Enable higher-timeframe EMA filter
input ENUM_TIMEFRAMES InpTrendTF            = PERIOD_H1;  // Trend timeframe
input int             InpEmaFastPeriod      = 50;         // Fast EMA period
input int             InpEmaSlowPeriod      = 200;        // Slow EMA period
input bool            InpTrendRequirePrice  = false;      // Require trend-TF close beyond slow EMA

input group "===== 4) Stops and targets ====="
input double          InpAtrSLMult          = 1.00;       // ATR multiple beyond sweep extreme for SL
input int             InpMinSLPoints        = 120;        // Minimum SL distance (points)
input int             InpMaxSLPoints        = 900;        // Maximum SL distance (points, 0 = off)
input double          InpRR                 = 2.00;       // Reward:Risk for TP (0 = no TP)
input double          InpRiskBufferPct      = 10.0;       // Inflate risk estimate for costs (%)
input double          InpCommissionPerLotRT = 0.00;       // Commission per 1.0 lot round turn (account ccy)

input group "===== 5) Risk and account protection ====="
input ENUM_GS_RISK_MODE InpRiskMode         = GS_RISK_PERCENT; // Position sizing mode
input double          InpRiskPercent        = 0.50;       // Risk per trade (% of equity/balance)
input double          InpFixedLot           = 0.01;       // Fixed lot (fixed mode only)
input bool            InpUseEquityForRisk   = true;       // Use equity (true) or balance (false)
input double          InpMaxRiskMult        = 1.00;       // Max actual/planned risk multiplier (min-lot override)
input double          InpMaxDailyLossPct    = 3.00;       // Daily loss hard stop (% of day-start balance, 0 = off)
input bool            InpDailyLossClosePos  = true;       // Close positions when daily limit is hit
input double          InpMaxDrawdownPct     = 10.0;       // Max drawdown from equity high-water mark (%, 0 = off)
input bool            InpMaxDDClosePos      = true;       // Close positions when max drawdown is hit
input double          InpMaxOpenRiskPct     = 2.00;       // Max total open risk (% of equity, 0 = off)
input double          InpMinFreeMarginPct   = 30.0;       // Min free margin after entry (% of equity)
input ENUM_GS_LOSS_SCOPE InpLossScope       = GS_SCOPE_EA; // Daily loss scope

input group "===== 6) Trade frequency and filters ====="
input int             InpMaxPositions       = 1;          // Max simultaneous EA positions
input int             InpMaxTradesPerDay    = 3;          // Max entries per server day (0 = unlimited)
input int             InpCooldownLossMin    = 30;         // Cooldown after a losing close (minutes)
input int             InpCooldownWinMin     = 0;          // Cooldown after a winning close (minutes)
input int             InpMaxSpreadPoints    = 50;         // Max spread for entry (points, 0 = off)

input group "===== 7) Session filter (server time) ====="
input bool            InpUseSession         = false;      // Enable trading-hours filter
input int             InpSessionStartHour   = 9;          // Session start hour (server time)
input int             InpSessionStartMin    = 0;          // Session start minute
input int             InpSessionEndHour     = 22;         // Session end hour (server time)
input int             InpSessionEndMin      = 0;          // Session end minute
input int             InpSessionShiftHours  = 0;          // Shift session window (+/- hours, DST/broker)
input bool            InpUseFridayCutoff    = true;       // No new trades late on Friday
input int             InpFridayCutHour      = 19;         // Friday last-entry hour (server time)
input int             InpFridayCutMin       = 0;          // Friday last-entry minute

input group "===== 8) Execution ====="
input ENUM_GS_FILLING InpFillingMode        = GS_FILL_AUTO; // Filling policy
input int             InpDeviationPoints    = 30;         // Max deviation / slippage (points)
input bool            InpUseOrderCheck      = true;       // Pre-validate requests with OrderCheck
input int             InpMaxRetriesPerBar   = 2;          // Retries per bar on transient failures
input int             InpRetryDelaySec      = 10;         // Delay between retries (seconds)

input group "===== 9) Position management ====="
input bool            InpUseBreakeven       = true;       // Move SL to breakeven
input double          InpBEStartR           = 1.00;       // Start BE when profit >= x R
input double          InpBELockR            = 0.05;       // Lock this fraction of R at BE
input int             InpBEMinStepPoints    = 20;         // Min SL improvement to modify (points)
input bool            InpUseTrailing        = false;      // Enable R-based trailing stop
input double          InpTrailStartR        = 1.50;       // Start trailing when profit >= x R
input double          InpTrailDistR         = 0.75;       // Trailing distance in R
input int             InpTrailMinStepPoints = 20;         // Min SL improvement for trailing (points)
input bool            InpCloseAtSessionEnd  = false;      // Close EA positions when session ends
input int             InpTimeExitBars       = 0;           // Close after N signal bars (0 = off)
input bool            InpTimeExitOnlyProfit = true;       // Time exit only when in profit

//+------------------------------------------------------------------+
//| 2. Constants and global structures                               |
//+------------------------------------------------------------------+
#define GS_EA_VERSION        "2.00"
#define GS_LOG_ERROR         0
#define GS_LOG_WARN          1
#define GS_LOG_INFO          2
#define GS_LOG_DEBUG         3
#define GS_MAX_POS_STATES    32
#define GS_CSV_DELIM         ";"

struct SSymbolSpec
  {
   string   name;
   int      digits;
   double   point;
   double   tickSize;
   double   tickValue;
   double   contractSize;
   double   volMin;
   double   volMax;
   double   volStep;
   int      volDigits;
   long     stopsLevel;
   long     freezeLevel;
   long     fillingMode;
   long     tradeMode;
   long     spreadPoints;
   bool     valid;
  };

struct SSignal
  {
   bool             valid;
   ENUM_ORDER_TYPE  type;
   double           sweepLevel;
   double           atr;
   double           barHigh;
   double           barLow;
   double           barClose;
   string           note;
  };

struct SDailyStats
  {
   bool     valid;
   datetime dayStart;
   datetime computedAt;
   double   startBalance;
   double   realized;
   double   floating;
   double   equity;
   double   balance;
   double   lossMoney;
   double   lossPct;
   int      entriesToday;
   datetime lastCloseTime;
   double   lastCloseProfit;
   double   netExternal;      // all external deal types (display)
   double   netBalanceFlow;   // balance/bonus only (used to correct equity-based PnL)
   string   err;
  };

struct SPosRef
  {
   ulong             ticket;
   ENUM_POSITION_TYPE posType;
   double            volume;
   double            open;
   double            sl;
   double            tp;
   double            profit;
   double            swap;
   long              magic;
   string            symbol;
   datetime          openTime;
  };

struct SPosState
  {
   ulong    ticket;
   bool     valid;
   double   entry;
   double   initialSL;
   double   riskMoney;
   double   initialRiskPoints;
   datetime opened;
   bool     beDone;
   double   lastTrailSL;
   double   volumeAtEntry;
   bool     foreignMod;
  };

struct SPersistState
  {
   int      version;
   long     magic;
   string   symbol;
   datetime lastEvalBar;
   datetime lastEntryBar;
   int      dayKey;
   bool     dailyLocked;
   bool     hardLocked;
   double   hwmEquity;
   datetime hwmTime;
   string   lockReason;
   double   startBalance;
   datetime savedAt;
  };

//+------------------------------------------------------------------+
//| 3. Global variables                                              |
//+------------------------------------------------------------------+
SSymbolSpec   g_sym;
MqlTick       g_tick;
bool          g_tickValid        = false;
bool          g_isHedging        = false;
bool          g_ready            = false;
bool          g_dryRun           = false;
bool          g_persistActive    = false;   // state files enabled (never in the tester)

datetime      g_lastSeenBar      = 0;
datetime      g_lastAttemptTime  = 0;
int           g_barAttempts      = 0;
datetime      g_lastEvalBar      = 0;
datetime      g_lastEntryBar     = 0;

SSignal       g_cachedSig;
datetime      g_cachedSigBar     = 0;
bool          g_cachedSigDone    = false;

SPersistState g_state;
SPosState     g_posStates[];
SDailyStats   g_stats;
datetime      g_statsAt          = 0;
bool          g_statsOk          = false;

string        g_lastErrorMsg     = "";
datetime      g_lastErrorTime    = 0;
datetime      g_lastGuardClose   = 0;
datetime      g_lastStateSave    = 0;
ulong         g_lastModifyTicket = 0;
datetime      g_lastModifyTime   = 0;
datetime      g_lastDailyLog     = 0;

int           g_hEmaFast         = INVALID_HANDLE;
int           g_hEmaSlow         = INVALID_HANDLE;
int           g_hAtr             = INVALID_HANDLE;

string        g_dashboard        = "";
datetime      g_dashboardAt      = 0;
bool          g_fileWarned       = false;
bool          g_historyWarned    = false;

//+------------------------------------------------------------------+
//| 4. Logging and small utilities                                   |
//+------------------------------------------------------------------+
string LevelTag(const int level)
  {
   if(level == GS_LOG_ERROR)
      return "ERR";
   if(level == GS_LOG_WARN)
      return "WRN";
   if(level == GS_LOG_INFO)
      return "INF";
   return "DBG";
  }

void GSLog(const int level, const string msg)
  {
   if(level > InpLogLevel)
      return;

   PrintFormat("[GoldSweepEA][%s] %s", LevelTag(level), msg);

   if(level <= GS_LOG_WARN)
     {
      g_lastErrorMsg  = msg;
      g_lastErrorTime = TimeCurrent();
     }

   if(level == GS_LOG_ERROR && InpAlerts && !MQLInfoInteger(MQL_TESTER))
      Alert("GoldSweepEA: ", msg);
  }

string TFToStr(const ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return StringFormat("TF%d", (int)tf);
     }
  }

string BoolStr(const bool value)
  {
   return value ? "true" : "false";
  }

string SanitizeName(const string src)
  {
   string res = src;
   StringReplace(res, "\\", "_");
   StringReplace(res, "/", "_");
   StringReplace(res, ":", "_");
   StringReplace(res, "*", "_");
   StringReplace(res, "?", "_");
   StringReplace(res, "\"", "_");
   StringReplace(res, "<", "_");
   StringReplace(res, ">", "_");
   StringReplace(res, "|", "_");
   StringReplace(res, "#", "_");
   StringReplace(res, " ", "_");
   StringReplace(res, ";", "_");
   StringReplace(res, ",", "_");
   StringReplace(res, ".", "_");
   StringReplace(res, "+", "_");
   return res;
  }

string FilePrefix()
  {
   return StringFormat("GSEA_%I64d_%s", InpMagic, SanitizeName(_Symbol));
  }

string StateFilePath()
  {
   return FilePrefix() + "_state.csv";
  }

string TradeLogFilePath()
  {
   return FilePrefix() + "_trades.csv";
  }

string PosFilePath(const ulong ticket)
  {
   return StringFormat("%s_pos_%I64u.csv", FilePrefix(), ticket);
  }

int DayKey(const datetime moment)
  {
   MqlDateTime dt;
   TimeToStruct(moment, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int MinuteOfDay(const datetime moment)
  {
   MqlDateTime dt;
   TimeToStruct(moment, dt);
   return dt.hour * 60 + dt.min;
  }

int WeekDay(const datetime moment)
  {
   MqlDateTime dt;
   TimeToStruct(moment, dt);
   return dt.day_of_week;
  }

datetime StartOfDay(const datetime moment)
  {
   MqlDateTime dt;
   TimeToStruct(moment, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

string TimeStr(const datetime moment)
  {
   if(moment <= 0)
      return "n/a";
   return TimeToString(moment, TIME_DATE | TIME_SECONDS);
  }

string PriceStr(const double price)
  {
   if(g_sym.digits <= 0)
      return StringFormat("%.5f", price);
   return DoubleToString(price, g_sym.digits);
  }

bool IsSuccessRetcode(const uint rc)
  {
   return (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL);
  }

bool IsRetryableRetcode(const uint rc)
  {
   return (rc == TRADE_RETCODE_REQUOTE ||
           rc == TRADE_RETCODE_PRICE_CHANGED ||
           rc == TRADE_RETCODE_PRICE_OFF ||
           rc == TRADE_RETCODE_TIMEOUT ||
           rc == TRADE_RETCODE_CONNECTION ||
           rc == TRADE_RETCODE_TOO_MANY_REQUESTS);
  }

string RetcodeText(const uint rc)
  {
   switch(rc)
     {
      case TRADE_RETCODE_REQUOTE:           return "REQUOTE";
      case TRADE_RETCODE_REJECT:            return "REJECT";
      case TRADE_RETCODE_CANCEL:            return "CANCEL";
      case TRADE_RETCODE_PLACED:            return "PLACED";
      case TRADE_RETCODE_DONE:              return "DONE";
      case TRADE_RETCODE_DONE_PARTIAL:      return "DONE_PARTIAL";
      case TRADE_RETCODE_ERROR:             return "ERROR";
      case TRADE_RETCODE_TIMEOUT:           return "TIMEOUT";
      case TRADE_RETCODE_INVALID:           return "INVALID";
      case TRADE_RETCODE_INVALID_VOLUME:    return "INVALID_VOLUME";
      case TRADE_RETCODE_INVALID_PRICE:     return "INVALID_PRICE";
      case TRADE_RETCODE_INVALID_STOPS:     return "INVALID_STOPS";
      case TRADE_RETCODE_TRADE_DISABLED:    return "TRADE_DISABLED";
      case TRADE_RETCODE_MARKET_CLOSED:     return "MARKET_CLOSED";
      case TRADE_RETCODE_NO_MONEY:          return "NO_MONEY";
      case TRADE_RETCODE_PRICE_CHANGED:     return "PRICE_CHANGED";
      case TRADE_RETCODE_PRICE_OFF:         return "PRICE_OFF";
      case TRADE_RETCODE_INVALID_EXPIRATION:return "INVALID_EXPIRATION";
      case TRADE_RETCODE_ORDER_CHANGED:     return "ORDER_CHANGED";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "TOO_MANY_REQUESTS";
      case TRADE_RETCODE_NO_CHANGES:        return "NO_CHANGES";
      case TRADE_RETCODE_SERVER_DISABLES_AT:return "SERVER_DISABLES_AT";
      case TRADE_RETCODE_CLIENT_DISABLES_AT:return "CLIENT_DISABLES_AT";
      case TRADE_RETCODE_LOCKED:            return "LOCKED";
      case TRADE_RETCODE_FROZEN:            return "FROZEN";
      case TRADE_RETCODE_INVALID_FILL:      return "INVALID_FILL";
      case TRADE_RETCODE_CONNECTION:        return "CONNECTION";
      case TRADE_RETCODE_ONLY_REAL:         return "ONLY_REAL";
      case TRADE_RETCODE_LIMIT_ORDERS:      return "LIMIT_ORDERS";
      case TRADE_RETCODE_LIMIT_VOLUME:      return "LIMIT_VOLUME";
      case TRADE_RETCODE_INVALID_ORDER:     return "INVALID_ORDER";
      case TRADE_RETCODE_POSITION_CLOSED:   return "POSITION_CLOSED";
      case TRADE_RETCODE_INVALID_CLOSE_VOLUME: return "INVALID_CLOSE_VOLUME";
      case TRADE_RETCODE_CLOSE_ORDER_EXIST: return "CLOSE_ORDER_EXIST";
      case TRADE_RETCODE_LIMIT_POSITIONS:   return "LIMIT_POSITIONS";
      case TRADE_RETCODE_REJECT_CANCEL:     return "REJECT_CANCEL";
      case TRADE_RETCODE_LONG_ONLY:         return "LONG_ONLY";
      case TRADE_RETCODE_SHORT_ONLY:        return "SHORT_ONLY";
      case TRADE_RETCODE_CLOSE_ONLY:        return "CLOSE_ONLY";
      case TRADE_RETCODE_FIFO_CLOSE:        return "FIFO_CLOSE";
      case 10046:                           return "HEDGE_PROHIBITED";  // newer builds only
      default:                              return StringFormat("RETCODE_%u", rc);
     }
  }

string ErrText()
  {
   return StringFormat("last_error=%d", GetLastError());
  }

//+------------------------------------------------------------------+
//| 5. Symbol cache and price helpers                                |
//+------------------------------------------------------------------+
int VolumeStepDigits(const double step)
  {
   if(step <= 0.0)
      return 2;
   int digits = 0;
   double probe = step;
   while(probe < 1.0 - 1e-12 && digits < 8)
     {
      probe *= 10.0;
      digits++;
     }
   return digits;
  }

bool RefreshSymbolSpec()
  {
   ZeroMemory(g_sym);
   g_sym.name = _Symbol;
   g_sym.valid = false;

   if(!SymbolSelect(_Symbol, true))
     {
      GSLog(GS_LOG_ERROR, StringFormat("SymbolSelect failed for %s. %s", _Symbol, ErrText()));
      return false;
     }

   g_sym.digits       = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_sym.point        = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_sym.tickSize     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_sym.tickValue    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   g_sym.contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   g_sym.volMin       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_sym.volMax       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_sym.volStep      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_sym.stopsLevel   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   g_sym.freezeLevel  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   g_sym.fillingMode  = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   g_sym.tradeMode    = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   g_sym.spreadPoints = 0;
   g_sym.volDigits    = VolumeStepDigits(g_sym.volStep);

   if(g_sym.point <= 0.0 || g_sym.digits <= 0)
     {
      GSLog(GS_LOG_ERROR, StringFormat("%s: invalid point/digits (point=%.10f digits=%d)",
                                       _Symbol, g_sym.point, g_sym.digits));
      return false;
     }
   if(g_sym.tickSize <= 0.0)
     {
      GSLog(GS_LOG_ERROR, StringFormat("%s: invalid tick size (%.10f)", _Symbol, g_sym.tickSize));
      return false;
     }
   if(g_sym.tickValue <= 0.0)
     {
      GSLog(GS_LOG_ERROR, StringFormat("%s: invalid tick value (%.10f)", _Symbol, g_sym.tickValue));
      return false;
     }
   if(g_sym.volMin <= 0.0 || g_sym.volStep <= 0.0 || g_sym.volMax < g_sym.volMin)
     {
      GSLog(GS_LOG_ERROR, StringFormat("%s: invalid volume spec (min=%.4f step=%.4f max=%.4f)",
                                       _Symbol, g_sym.volMin, g_sym.volStep, g_sym.volMax));
      return false;
     }

   g_sym.valid = true;
   return true;
  }

bool RefreshTick()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
     {
      g_tickValid = false;
      return false;
     }
   if(!(tick.ask > 0.0) || !(tick.bid > 0.0) || tick.ask < tick.bid)
     {
      g_tickValid = false;
      return false;
     }

   g_tick      = tick;
   g_tickValid = true;

   if(g_sym.point > 0.0)
      g_sym.spreadPoints = (long)MathRound((tick.ask - tick.bid) / g_sym.point);

   // Broker stop/freeze levels and trade mode can change intraday.
   static datetime lastSpecRefresh = 0;
   datetime  now = TimeCurrent();
   if(now != lastSpecRefresh)
     {
      lastSpecRefresh    = now;
      g_sym.stopsLevel   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      g_sym.freezeLevel  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      g_sym.tradeMode    = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
      g_sym.fillingMode  = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
     }

   return true;
  }

double CurrentSpreadPoints()
  {
   if(!g_tickValid || g_sym.point <= 0.0)
      return 1e9;
   return (g_tick.ask - g_tick.bid) / g_sym.point;
  }

double RoundToTick(const double price, const int mode)
  {
   if(g_sym.tickSize <= 0.0)
      return NormalizeDouble(price, g_sym.digits);

   double steps = price / g_sym.tickSize;
   double rounded = price;

   if(mode == 1)
      rounded = MathFloor(steps + 1e-9) * g_sym.tickSize;
   else
      if(mode == 2)
         rounded = MathCeil(steps - 1e-9) * g_sym.tickSize;
      else
         rounded = MathRound(steps) * g_sym.tickSize;

   return NormalizeDouble(rounded, g_sym.digits);
  }

int SecondsPerSignalBar()
  {
   int secs = PeriodSeconds(InpSignalTF);
   if(secs <= 0)
      secs = 900;
   return secs;
  }

//+------------------------------------------------------------------+
//| 6. Position helpers                                              |
//+------------------------------------------------------------------+
bool IsOurMagic(const long magic)
  {
   return (magic == InpMagic);
  }

bool GetPositionRef(const ulong ticket, SPosRef &ref)
  {
   ZeroMemory(ref);
   if(ticket == 0)
      return false;
   if(!PositionSelectByTicket(ticket))
      return false;

   ref.ticket   = ticket;
   ref.posType  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   ref.volume   = PositionGetDouble(POSITION_VOLUME);
   ref.open     = PositionGetDouble(POSITION_PRICE_OPEN);
   ref.sl       = PositionGetDouble(POSITION_SL);
   ref.tp       = PositionGetDouble(POSITION_TP);
   ref.profit   = PositionGetDouble(POSITION_PROFIT);
   ref.swap     = PositionGetDouble(POSITION_SWAP);
   ref.magic    = (long)PositionGetInteger(POSITION_MAGIC);
   ref.symbol   = PositionGetString(POSITION_SYMBOL);
   ref.openTime = (datetime)PositionGetInteger(POSITION_TIME);
   return true;
  }

int CollectPositions(SPosRef &out[], const bool onlyOurs)
  {
   ArrayResize(out, 0);

   int total = PositionsTotal();
   for(int idx = 0; idx < total; idx++)
     {
      ulong ticket = PositionGetTicket(idx);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      if(sym != _Symbol)
         continue;

      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(onlyOurs && !IsOurMagic(magic))
         continue;

      SPosRef ref;
      ZeroMemory(ref);
      ref.ticket   = ticket;
      ref.posType  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ref.volume   = PositionGetDouble(POSITION_VOLUME);
      ref.open     = PositionGetDouble(POSITION_PRICE_OPEN);
      ref.sl       = PositionGetDouble(POSITION_SL);
      ref.tp       = PositionGetDouble(POSITION_TP);
      ref.profit   = PositionGetDouble(POSITION_PROFIT);
      ref.swap     = PositionGetDouble(POSITION_SWAP);
      ref.magic    = magic;
      ref.symbol   = sym;
      ref.openTime = (datetime)PositionGetInteger(POSITION_TIME);

      int n = ArraySize(out);
      if(ArrayResize(out, n + 1) != n + 1)
         break;
      out[n] = ref;
     }

   return ArraySize(out);
  }

int OurPositionsCount()
  {
   SPosRef list[];
   return CollectPositions(list, true);
  }

bool HasOurPosition()
  {
   return (OurPositionsCount() > 0);
  }

bool HasForeignNettingPosition(string &desc)
  {
   desc = "";
   if(g_isHedging)
      return false;
   if(!PositionSelect(_Symbol))
      return false;

   long magic = (long)PositionGetInteger(POSITION_MAGIC);
   if(IsOurMagic(magic))
      return false;

   desc = StringFormat("foreign netting position on %s (magic=%I64d volume=%.2f)",
                       _Symbol, magic, PositionGetDouble(POSITION_VOLUME));
   return true;
  }

double OurFloatingPnL()
  {
   double sum = 0.0;
   SPosRef list[];
   int n = CollectPositions(list, true);
   for(int i = 0; i < n; i++)
      sum += list[i].profit + list[i].swap;
   return sum;
  }

double OurOpenRiskMoney()
  {
   double sum = 0.0;
   if(g_sym.tickSize <= 0.0 || g_sym.tickValue <= 0.0)
      return 0.0;

   SPosRef list[];
   int n = CollectPositions(list, true);
   for(int i = 0; i < n; i++)
     {
      if(list[i].sl <= 0.0)
         return 1e12;  // unprotected position = unlimited risk
      double dist = MathAbs(list[i].open - list[i].sl);
      sum += (dist / g_sym.tickSize) * g_sym.tickValue * list[i].volume;
     }
   return sum;
  }

//+------------------------------------------------------------------+
//| 7. State persistence (CSV in MQL5/Files)                         |
//+------------------------------------------------------------------+
bool NextField(const string line, int &pos, string &field)
  {
   if(pos < 0)
     {
      field = "";
      return false;
     }

   int sep = StringFind(line, GS_CSV_DELIM, pos);
   if(sep < 0)
     {
      field = StringSubstr(line, pos);
      pos   = -1;
     }
   else
     {
      field = StringSubstr(line, pos, sep - pos);
      pos   = sep + 1;
     }
   return true;
  }

void InitStateDefaults()
  {
   ZeroMemory(g_state);
   g_state.version     = 1;
   g_state.magic       = InpMagic;
   g_state.symbol      = _Symbol;
   g_state.lastEvalBar = 0;
   g_state.lastEntryBar = 0;
   g_state.dayKey      = DayKey(TimeCurrent());
   g_state.dailyLocked = false;
   g_state.hardLocked  = false;
   g_state.hwmEquity   = AccountInfoDouble(ACCOUNT_EQUITY);
   g_state.hwmTime     = TimeCurrent();
   g_state.lockReason  = "";
   g_state.startBalance = 0.0;   // unknown until the first day rollover
   g_state.savedAt     = 0;
  }

bool LoadState()
  {
   InitStateDefaults();

   if(!g_persistActive)
      return true;

   string path = StateFilePath();
   if(!FileIsExist(path))
     {
      GSLog(GS_LOG_INFO, StringFormat("state: no saved state (%s), starting fresh", path));
      return true;
     }

   int handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      GSLog(GS_LOG_WARN, StringFormat("state: cannot open %s (%s), starting fresh", path, ErrText()));
      return false;
     }

   string line = FileReadString(handle);
   FileClose(handle);

   if(StringLen(line) < 5)
     {
      GSLog(GS_LOG_WARN, "state: file empty/corrupt, starting fresh");
      return false;
     }

   int pos = 0;
   string f;
   int version = 0;
   long magic = 0;
   string symbol = "";
   datetime evalBar = 0;
   datetime entryBar = 0;
   int dayKey = 0;
   int dailyLocked = 0;
   int hardLocked = 0;
   double hwm = 0.0;
   datetime hwmTime = 0;
   string reason = "";
   double startBalance = 0.0;
   datetime savedAt = 0;

   NextField(line, pos, f); version = (int)StringToInteger(f);
   NextField(line, pos, f); magic = StringToInteger(f);
   NextField(line, pos, f); symbol = f;
   NextField(line, pos, f); evalBar = (datetime)StringToInteger(f);
   NextField(line, pos, f); entryBar = (datetime)StringToInteger(f);
   NextField(line, pos, f); dayKey = (int)StringToInteger(f);
   NextField(line, pos, f); dailyLocked = (int)StringToInteger(f);
   NextField(line, pos, f); hardLocked = (int)StringToInteger(f);
   NextField(line, pos, f); hwm = StringToDouble(f);
   NextField(line, pos, f); hwmTime = (datetime)StringToInteger(f);
   NextField(line, pos, f); reason = f;
   NextField(line, pos, f); startBalance = StringToDouble(f);
   NextField(line, pos, f); savedAt = (datetime)StringToInteger(f);

   if(version != 1 || magic != InpMagic || symbol != _Symbol)
     {
      GSLog(GS_LOG_WARN, StringFormat("state: incompatible state file (v=%d magic=%I64d symbol=%s), starting fresh",
                                      version, magic, symbol));
      InitStateDefaults();
      return false;
     }

   g_state.version      = version;
   g_state.magic        = magic;
   g_state.symbol       = symbol;
   g_state.lastEvalBar  = evalBar;
   g_state.lastEntryBar = entryBar;
   g_state.dayKey       = dayKey;
   g_state.dailyLocked  = (dailyLocked != 0);
   g_state.hardLocked   = (hardLocked != 0);
   g_state.hwmEquity    = hwm;
   g_state.hwmTime      = hwmTime;
   g_state.lockReason   = reason;
   g_state.startBalance = startBalance;
   g_state.savedAt      = savedAt;

   if(g_state.hwmEquity <= 0.0)
      g_state.hwmEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   GSLog(GS_LOG_INFO, StringFormat("state restored: evalBar=%s entryBar=%s dailyLocked=%s hardLocked=%s hwm=%.2f",
                                   TimeStr(g_state.lastEvalBar), TimeStr(g_state.lastEntryBar),
                                   BoolStr(g_state.dailyLocked), BoolStr(g_state.hardLocked),
                                   g_state.hwmEquity));
   return true;
  }

bool SaveState(const bool force)
  {
   if(!g_persistActive)
      return true;

   datetime now = TimeCurrent();
   if(!force && g_lastStateSave > 0 && (now - g_lastStateSave) < 5)
      return true;

   string reason = g_state.lockReason;
   StringReplace(reason, GS_CSV_DELIM, ",");
   StringReplace(reason, "\r", " ");
   StringReplace(reason, "\n", " ");

   g_state.savedAt = now;

   int handle = FileOpen(StateFilePath(), FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      if(!g_fileWarned)
        {
         g_fileWarned = true;
         GSLog(GS_LOG_WARN, StringFormat("state: cannot write %s (%s)", StateFilePath(), ErrText()));
        }
      return false;
     }

   string line = StringFormat("1;%I64d;%s;%I64d;%I64d;%d;%d;%d;%.2f;%I64d;%s;%.2f;%I64d",
                              InpMagic, _Symbol,
                              (long)g_state.lastEvalBar, (long)g_state.lastEntryBar,
                              g_state.dayKey,
                              (g_state.dailyLocked ? 1 : 0),
                              (g_state.hardLocked ? 1 : 0),
                              g_state.hwmEquity,
                              (long)g_state.hwmTime,
                              reason,
                              g_state.startBalance,
                              (long)now);

   FileWriteString(handle, line + "\r\n");
   FileClose(handle);
   g_lastStateSave = now;
   return true;
  }

bool LoadPosState(const ulong ticket, SPosState &st)
  {
   ZeroMemory(st);
   st.ticket = ticket;

   if(!g_persistActive)
      return false;

   string path = PosFilePath(ticket);
   if(!FileIsExist(path))
      return false;

   int handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return false;

   string line = FileReadString(handle);
   FileClose(handle);
   if(StringLen(line) < 5)
      return false;

   int pos = 0;
   string f;
   int version = 0;
   ulong fileTicket = 0;
   double entry = 0.0;
   double initialSL = 0.0;
   double riskMoney = 0.0;
   double initialRiskPoints = 0.0;
   datetime opened = 0;
   int beDone = 0;
   double lastTrailSL = 0.0;
   double volumeAtEntry = 0.0;
   int foreignMod = 0;

   NextField(line, pos, f); version = (int)StringToInteger(f);
   NextField(line, pos, f); fileTicket = (ulong)StringToInteger(f);
   NextField(line, pos, f); entry = StringToDouble(f);
   NextField(line, pos, f); initialSL = StringToDouble(f);
   NextField(line, pos, f); riskMoney = StringToDouble(f);
   NextField(line, pos, f); initialRiskPoints = StringToDouble(f);
   NextField(line, pos, f); opened = (datetime)StringToInteger(f);
   NextField(line, pos, f); beDone = (int)StringToInteger(f);
   NextField(line, pos, f); lastTrailSL = StringToDouble(f);
   NextField(line, pos, f); volumeAtEntry = StringToDouble(f);
   NextField(line, pos, f); foreignMod = (int)StringToInteger(f);

   if(version != 1 || fileTicket != ticket)
      return false;

   st.valid            = true;
   st.entry            = entry;
   st.initialSL        = initialSL;
   st.riskMoney        = riskMoney;
   st.initialRiskPoints = initialRiskPoints;
   st.opened           = opened;
   st.beDone           = (beDone != 0);
   st.lastTrailSL      = lastTrailSL;
   st.volumeAtEntry    = volumeAtEntry;
   st.foreignMod       = (foreignMod != 0);
   return true;
  }

bool SavePosState(const SPosState &st)
  {
   if(!g_persistActive || !st.valid)
      return true;

   int handle = FileOpen(PosFilePath(st.ticket), FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      if(!g_fileWarned)
        {
         g_fileWarned = true;
         GSLog(GS_LOG_WARN, StringFormat("state: cannot write position file for #%I64u (%s)",
                                         st.ticket, ErrText()));
        }
      return false;
     }

   string line = StringFormat("1;%I64u;%.5f;%.5f;%.2f;%.1f;%I64d;%d;%.5f;%.2f;%d",
                              st.ticket, st.entry, st.initialSL, st.riskMoney,
                              st.initialRiskPoints, (long)st.opened,
                              (st.beDone ? 1 : 0), st.lastTrailSL, st.volumeAtEntry,
                              (st.foreignMod ? 1 : 0));
   FileWriteString(handle, line + "\r\n");
   FileClose(handle);
   return true;
  }

void DeletePosState(const ulong ticket)
  {
   if(g_persistActive && ticket > 0)
     {
      string path = PosFilePath(ticket);
      if(FileIsExist(path))
         FileDelete(path);
     }

   for(int i = ArraySize(g_posStates) - 1; i >= 0; i--)
     {
      if(g_posStates[i].ticket != ticket)
         continue;
      int last = ArraySize(g_posStates) - 1;
      if(i != last)
         g_posStates[i] = g_posStates[last];
      ArrayResize(g_posStates, last);
      break;
     }
  }

int FindPosState(const ulong ticket)
  {
   int n = ArraySize(g_posStates);
   for(int i = 0; i < n; i++)
      if(g_posStates[i].ticket == ticket)
         return i;
   return -1;
  }

bool UpsertPosState(const SPosState &st)
  {
   int idx = FindPosState(st.ticket);
   if(idx >= 0)
     {
      g_posStates[idx] = st;
     }
   else
     {
      int n = ArraySize(g_posStates);
      if(n >= GS_MAX_POS_STATES)
        {
         GSLog(GS_LOG_WARN, "state: position state table full");
         return false;
        }
      if(ArrayResize(g_posStates, n + 1) != n + 1)
         return false;
      g_posStates[n] = st;
     }
   SavePosState(st);
   return true;
  }

void BuildFallbackPosState(const SPosRef &ref, SPosState &st)
  {
   ZeroMemory(st);
   st.ticket       = ref.ticket;
   st.valid        = true;
   st.entry        = ref.open;
   st.initialSL    = ref.sl;
   st.riskMoney    = 0.0;
   st.initialRiskPoints = (ref.sl > 0.0 && g_sym.point > 0.0) ? MathAbs(ref.open - ref.sl) / g_sym.point : 0.0;
   st.opened       = ref.openTime;
   st.beDone       = false;
   st.lastTrailSL  = 0.0;
   st.volumeAtEntry = ref.volume;
   st.foreignMod   = false;

   bool be = false;
   if(ref.posType == POSITION_TYPE_BUY && ref.sl > 0.0 && ref.sl >= ref.open)
      be = true;
   if(ref.posType == POSITION_TYPE_SELL && ref.sl > 0.0 && ref.sl <= ref.open)
      be = true;
   st.beDone = be;
  }

void ReconcilePosStates()
  {
   ArrayResize(g_posStates, 0);

   SPosRef list[];
   int n = CollectPositions(list, true);
   for(int i = 0; i < n; i++)
     {
      SPosState st;
      if(!LoadPosState(list[i].ticket, st))
        {
         BuildFallbackPosState(list[i], st);
         GSLog(GS_LOG_WARN, StringFormat("state: no stored state for position #%I64u, reconstructed from position",
                                         list[i].ticket));
        }

      st.entry = list[i].open;
      st.volumeAtEntry = (st.volumeAtEntry > 0.0) ? st.volumeAtEntry : list[i].volume;
      UpsertPosState(st);
     }

   if(n > 0)
      GSLog(GS_LOG_INFO, StringFormat("state: reconciled %d open EA position(s)", n));
  }

void SyncPosStates()
  {
   for(int i = ArraySize(g_posStates) - 1; i >= 0; i--)
     {
      SPosRef ref;
      if(!GetPositionRef(g_posStates[i].ticket, ref))
        {
         DeletePosState(g_posStates[i].ticket);
         continue;
        }
      if(!IsOurMagic(ref.magic))
        {
         GSLog(GS_LOG_WARN, StringFormat("position #%I64u magic changed to %I64d (external action on netting account?) - state dropped",
                                         g_posStates[i].ticket, ref.magic));
         DeletePosState(g_posStates[i].ticket);
         continue;
        }

      if(!g_isHedging && g_posStates[i].volumeAtEntry > 0.0 && g_sym.volStep > 0.0)
        {
         if(ref.volume > g_posStates[i].volumeAtEntry + g_sym.volStep * 0.5)
           {
            if(!g_posStates[i].foreignMod)
              {
               g_posStates[i].foreignMod = true;
               SavePosState(g_posStates[i]);
               GSLog(GS_LOG_ERROR, StringFormat("netting: position #%I64u volume grew from %.2f to %.2f (external action?) - EA management disabled for it",
                                                ref.ticket, g_posStates[i].volumeAtEntry, ref.volume));
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| 8. Daily statistics (history based, deposit safe)                |
//+------------------------------------------------------------------+
bool IsExternalDealType(const long dealType)
  {
   return (dealType == DEAL_TYPE_BALANCE ||
           dealType == DEAL_TYPE_CREDIT  ||
           dealType == DEAL_TYPE_BONUS);
  }

bool ComputeDailyStats(SDailyStats &stats, const bool force)
  {
   datetime now = TimeCurrent();

   if(!force && g_statsAt > 0 && (now - g_statsAt) < 2)
     {
      stats = g_stats;
      return g_stats.valid;
     }

   ZeroMemory(stats);
   stats.computedAt = now;
   stats.dayStart   = StartOfDay(now);
   stats.equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   stats.balance    = AccountInfoDouble(ACCOUNT_BALANCE);

   if(stats.equity <= 0.0 || stats.balance <= 0.0)
     {
      stats.valid = false;
      stats.err   = "account equity/balance is zero";
      g_stats     = stats;
      g_statsAt   = now;
      g_statsOk   = false;
      return false;
     }

   if(!HistorySelect(stats.dayStart, now + 60))
     {
      stats.valid = false;
      stats.err   = StringFormat("HistorySelect failed (%s)", ErrText());
      g_stats     = stats;
      g_statsAt   = now;
      g_statsOk   = false;

      if(!g_historyWarned)
        {
         g_historyWarned = true;
         GSLog(GS_LOG_ERROR, "history unavailable - new entries are blocked until it recovers");
        }
      return false;
     }
   g_historyWarned = false;

   double allPnL = 0.0;
   int dealsTotal = HistoryDealsTotal();

   for(int idx = 0; idx < dealsTotal; idx++)
     {
      ulong dealTicket = HistoryDealGetTicket(idx);
      if(dealTicket == 0)
         continue;

      long   dealType  = (long)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      long   dealEntry = (long)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      long   dealMagic = (long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      string dealSym   = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      double dealPnL   = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                       + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                       + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION)
                       + HistoryDealGetDouble(dealTicket, DEAL_FEE);

      // Balance equation: balance_now = balance_start + sum(balance-affecting deal PnL).
      // Deposits/withdrawals are deals too, so the reconstructed start balance stays exact.
      // Credit deals change ACCOUNT_CREDIT, not ACCOUNT_BALANCE, so they are excluded here.
      if(dealType != DEAL_TYPE_CREDIT)
         allPnL += dealPnL;

      bool isTradeDeal = (dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL);
      if(!isTradeDeal)
        {
         if(IsExternalDealType(dealType))
            stats.netExternal += dealPnL;
         if(dealType == DEAL_TYPE_BALANCE || dealType == DEAL_TYPE_BONUS)
            stats.netBalanceFlow += dealPnL;
         continue;
        }

      bool inScope = (InpLossScope == GS_SCOPE_ACCOUNT) ||
                     (dealSym == _Symbol && dealMagic == InpMagic);
      if(!inScope)
         continue;

      stats.realized += dealPnL;

      if(dealEntry == DEAL_ENTRY_IN)
         stats.entriesToday++;

      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT || dealEntry == DEAL_ENTRY_OUT_BY)
        {
         datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         if(dealTime >= stats.lastCloseTime)
           {
            stats.lastCloseTime   = dealTime;
            stats.lastCloseProfit = dealPnL;
           }
        }
     }

   stats.startBalance = stats.balance - allPnL;

   // Cross-check against the balance snapshot persisted at day start. A large
   // difference means the deal history is incomplete; use the safer (lower) base.
   if(g_state.savedAt > 0 && g_state.dayKey == DayKey(now) && g_state.startBalance > 0.0)
     {
      double diffPct = MathAbs(stats.startBalance - g_state.startBalance) / g_state.startBalance * 100.0;
      if(diffPct > 5.0)
        {
         static int warnedDay = 0;
         if(warnedDay != g_state.dayKey)
           {
            warnedDay = g_state.dayKey;
            GSLog(GS_LOG_WARN, StringFormat("daily baseline mismatch: history %.2f vs saved %.2f (%.1f%%) - using the lower value",
                                            stats.startBalance, g_state.startBalance, diffPct));
           }
         stats.startBalance = MathMin(stats.startBalance, g_state.startBalance);
        }
     }

   if(InpLossScope == GS_SCOPE_ACCOUNT)
      stats.floating = stats.equity - stats.balance;
   else
      stats.floating = OurFloatingPnL();

   if(stats.startBalance <= 0.0)
     {
      stats.valid = false;
      stats.err   = StringFormat("invalid reconstructed start balance (%.2f)", stats.startBalance);
      g_stats     = stats;
      g_statsAt   = now;
      g_statsOk   = false;
      return false;
     }

   double pnlForLimit = 0.0;
   if(InpLossScope == GS_SCOPE_ACCOUNT)
      pnlForLimit = (stats.equity - stats.startBalance) - stats.netBalanceFlow;   // deposits/withdrawals removed
   else
      pnlForLimit = stats.realized + stats.floating;     // this EA only

   stats.lossMoney = (pnlForLimit < 0.0) ? -pnlForLimit : 0.0;
   stats.lossPct   = stats.lossMoney / stats.startBalance * 100.0;

   stats.valid = true;
   g_stats     = stats;
   g_statsAt   = now;
   g_statsOk   = true;
   return true;
  }

void InvalidateStats()
  {
   g_statsAt = 0;
  }

//+------------------------------------------------------------------+
//| 9. Risk sizing                                                   |
//+------------------------------------------------------------------+
double RiskPerLot(const ENUM_ORDER_TYPE type, const double entry, const double sl, bool &ok)
  {
   ok = false;

   if(entry <= 0.0 || sl <= 0.0 || MathAbs(entry - sl) < 1e-9)
      return 0.0;

   double profit = 0.0;
   if(OrderCalcProfit(type, _Symbol, 1.0, entry, sl, profit))
     {
      double loss = -profit;
      if(loss > 0.0)
        {
         ok = true;
         return loss;
        }
     }

   // Fallback: tick based estimate (also covers brokers where OrderCalcProfit fails).
   if(g_sym.tickSize > 0.0 && g_sym.tickValue > 0.0)
     {
      double loss = (MathAbs(entry - sl) / g_sym.tickSize) * g_sym.tickValue;
      if(loss > 0.0)
        {
         static bool warned = false;
         if(!warned)
           {
            warned = true;
            GSLog(GS_LOG_WARN, "risk: OrderCalcProfit unavailable, using tick-value estimate");
           }
         ok = true;
         return loss;
        }
     }

   return 0.0;
  }

double ApplyRiskBuffer(const double rawRisk)
  {
   double buffer = InpRiskBufferPct;
   if(buffer < 0.0)
      buffer = 0.0;
   if(buffer > 200.0)
      buffer = 200.0;
   return rawRisk * (1.0 + buffer / 100.0);
  }

double IncludingCommission(const double rawRisk)
  {
   double extra = InpCommissionPerLotRT;
   if(extra < 0.0)
      extra = 0.0;
   return rawRisk + extra;
  }

double FloorToVolumeStep(const double lots)
  {
   if(g_sym.volStep <= 0.0)
      return 0.0;

   double steps = MathFloor((lots + 1e-9) / g_sym.volStep);
   double result = NormalizeDouble(steps * g_sym.volStep, g_sym.volDigits);

   if(result > g_sym.volMax)
     {
      steps  = MathFloor((g_sym.volMax + 1e-9) / g_sym.volStep);
      result = NormalizeDouble(steps * g_sym.volStep, g_sym.volDigits);
     }

   if(result < 0.0)
      result = 0.0;

   return result;
  }

double ClampVolume(const double lots)
  {
   double result = FloorToVolumeStep(lots);
   if(result < g_sym.volMin)
      result = 0.0;
   if(result > g_sym.volMax)
      result = FloorToVolumeStep(g_sym.volMax);
   return NormalizeDouble(result, g_sym.volDigits);
  }

double RiskBaseMoney()
  {
   double base = InpUseEquityForRisk ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
   if(base <= 0.0)
      base = AccountInfoDouble(ACCOUNT_BALANCE);
   return base;
  }

double CalcLots(const ENUM_ORDER_TYPE type,
                const double entry,
                const double sl,
                double &riskMoneyOut,
                double &riskPctOut,
                string &err)
  {
   riskMoneyOut = 0.0;
   riskPctOut   = 0.0;
   err          = "";

   double base = RiskBaseMoney();
   if(base <= 0.0)
     {
      err = "account risk base is zero";
      return 0.0;
     }

   bool perLotOk = false;
   double perLot = RiskPerLot(type, entry, sl, perLotOk);
   if(!perLotOk || perLot <= 0.0)
     {
      err = "cannot estimate risk per lot";
      return 0.0;
     }

   perLot = ApplyRiskBuffer(IncludingCommission(perLot));
   if(perLot <= 0.0)
     {
      err = "invalid risk per lot";
      return 0.0;
     }

   if(InpRiskMode == GS_RISK_FIXED_LOT)
     {
      double fixedLots = ClampVolume(InpFixedLot);
      if(fixedLots <= 0.0)
        {
         if(InpFixedLot > 0.0 && g_sym.volMin <= g_sym.volMax)
           {
            fixedLots = g_sym.volMin;
            GSLog(GS_LOG_WARN, StringFormat("fixed lot %.3f is below broker minimum -> using %.2f",
                                            InpFixedLot, fixedLots));
           }
         else
           {
            err = StringFormat("fixed lot %.3f is outside broker limits (min %.3f step %.3f max %.3f)",
                               InpFixedLot, g_sym.volMin, g_sym.volStep, g_sym.volMax);
            return 0.0;
           }
        }
      riskMoneyOut = perLot * fixedLots;
      riskPctOut   = riskMoneyOut / base * 100.0;
      return fixedLots;
     }

   double targetRisk = base * InpRiskPercent / 100.0;
   if(targetRisk <= 0.0)
     {
      err = "risk percent results in zero risk budget";
      return 0.0;
     }

   double rawLots = targetRisk / perLot;
   double lots    = FloorToVolumeStep(rawLots);

   if(lots < g_sym.volMin)
     {
      double minLotRisk = perLot * g_sym.volMin;
      double maxAllowed = targetRisk * InpMaxRiskMult;

      if(InpMaxRiskMult > 0.0 && minLotRisk <= maxAllowed + 1e-9)
        {
         lots = g_sym.volMin;
         GSLog(GS_LOG_WARN, StringFormat("risk: computed %.5f lot -> broker min %.2f lot; actual risk %.2f (%.2f%% of %.2f), limit %.2f%% x %.2f",
                                         rawLots, g_sym.volMin, minLotRisk,
                                         minLotRisk / base * 100.0, base,
                                         InpRiskPercent, InpMaxRiskMult));
        }
      else
        {
         err = StringFormat("min lot %.2f risks %.2f (%.2f%%), above the %.2f%% x %.2f cap - trade skipped",
                            g_sym.volMin, minLotRisk, minLotRisk / base * 100.0,
                            InpRiskPercent, InpMaxRiskMult);
         return 0.0;
        }
     }

   if(lots <= 0.0)
     {
      err = "lot size rounded down to zero";
      return 0.0;
     }

   riskMoneyOut = perLot * lots;
   riskPctOut   = riskMoneyOut / base * 100.0;

   if(InpMaxRiskMult > 0.0 && riskMoneyOut > targetRisk * InpMaxRiskMult * (1.0 + 1e-9))
     {
      err = StringFormat("actual risk %.2f exceeds cap %.2f", riskMoneyOut, targetRisk * InpMaxRiskMult);
      return 0.0;
     }

   return lots;
  }

bool CheckMargin(const ENUM_ORDER_TYPE type, const double lots, const double price, string &err)
  {
   err = "";
   double required = 0.0;
   if(!OrderCalcMargin(type, _Symbol, lots, price, required))
     {
      err = StringFormat("OrderCalcMargin failed (%s)", ErrText());
      return false;
     }

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double buffer     = equity * InpMinFreeMarginPct / 100.0;

   if(required > freeMargin - buffer)
     {
      err = StringFormat("margin %.2f leaves less than %.1f%% of equity free (free %.2f)",
                         required, InpMinFreeMarginPct, freeMargin);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| 10. Execution (raw OrderSend with full result handling)          |
//+------------------------------------------------------------------+
struct SExecResult
  {
   bool     ok;
   bool     sent;
   uint     retcode;
   ulong    order;
   ulong    deal;
   double   reqPrice;
   double   reqVolume;
   double   fillPrice;
   double   fillVolume;
   string   comment;
  };

double MinStopDistance()
  {
   double point = g_sym.point;
   if(point <= 0.0)
      return 0.0;
   double dist = MathMax((double)g_sym.stopsLevel, (double)g_sym.freezeLevel) * point;
   if(dist < point)
      dist = point;
   return dist;
  }

ENUM_ORDER_TYPE_FILLING ResolveFilling()
  {
   long modes = g_sym.fillingMode;

   static bool fillWarned = false;

   if(InpFillingMode == GS_FILL_FOK)
     {
      if((modes & SYMBOL_FILLING_FOK) != 0)
         return ORDER_FILLING_FOK;
      if(!fillWarned)
        {
         fillWarned = true;
         GSLog(GS_LOG_WARN, "filling: FOK not supported by symbol, falling back to auto");
        }
     }
   else
      if(InpFillingMode == GS_FILL_IOC)
        {
         if((modes & SYMBOL_FILLING_IOC) != 0)
            return ORDER_FILLING_IOC;
         if(!fillWarned)
           {
            fillWarned = true;
            GSLog(GS_LOG_WARN, "filling: IOC not supported by symbol, falling back to auto");
           }
        }
      else
         if(InpFillingMode == GS_FILL_RETURN)
            return ORDER_FILLING_RETURN;

   if((modes & SYMBOL_FILLING_FOK) != 0)
      return ORDER_FILLING_FOK;
   if((modes & SYMBOL_FILLING_IOC) != 0)
      return ORDER_FILLING_IOC;

   return ORDER_FILLING_RETURN;
  }

bool ValidateStops(const ENUM_ORDER_TYPE type,
                   const double sl,
                   const double tp,
                   const MqlTick &tick,
                   string &err)
  {
   err = "";
   if(g_sym.point <= 0.0)
     {
      err = "invalid point";
      return false;
     }

   double minDist = MinStopDistance();
   double tol     = g_sym.tickSize * 0.01;

   if(type == ORDER_TYPE_BUY)
     {
      if(sl > 0.0 && (tick.bid - sl) < minDist)
        {
         err = StringFormat("SL too close to Bid: dist=%.1f pts, min=%.1f pts",
                            (tick.bid - sl) / g_sym.point, minDist / g_sym.point);
         return false;
        }
      if(tp > 0.0 && (tp - tick.bid) < minDist)
        {
         err = StringFormat("TP too close to Bid: dist=%.1f pts, min=%.1f pts",
                            (tp - tick.bid) / g_sym.point, minDist / g_sym.point);
         return false;
        }
     }
   else
     {
      if(sl > 0.0 && (sl - tick.ask) < minDist)
        {
         err = StringFormat("SL too close to Ask: dist=%.1f pts, min=%.1f pts",
                            (sl - tick.ask) / g_sym.point, minDist / g_sym.point);
         return false;
        }
      if(tp > 0.0 && (tick.ask - tp) < minDist)
        {
         err = StringFormat("TP too close to Ask: dist=%.1f pts, min=%.1f pts",
                            (tick.ask - tp) / g_sym.point, minDist / g_sym.point);
         return false;
        }
     }

   if(sl > 0.0 && MathAbs(sl - RoundToTick(sl, 0)) > tol)
     {
      err = StringFormat("SL %.5f is not aligned to tick size %.5f", sl, g_sym.tickSize);
      return false;
     }
   if(tp > 0.0 && MathAbs(tp - RoundToTick(tp, 0)) > tol)
     {
      err = StringFormat("TP %.5f is not aligned to tick size %.5f", tp, g_sym.tickSize);
      return false;
     }

   return true;
  }

bool SendMarketOrder(const ENUM_ORDER_TYPE type,
                     const double lots,
                     const double sl,
                     const double tp,
                     SExecResult &res)
  {
   ZeroMemory(res);
   res.ok = false;

   if(!RefreshTick())
     {
      res.comment = "no valid tick";
      return false;
     }

   if(g_dryRun)
     {
      res.ok        = true;
      res.sent      = false;
      res.reqPrice  = (type == ORDER_TYPE_BUY) ? g_tick.ask : g_tick.bid;
      res.reqVolume = lots;
      res.comment   = "dry-run";
      GSLog(GS_LOG_INFO, StringFormat("DRY-RUN %s %.2f lot @ %s SL %s TP %s",
                                      (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), lots,
                                      PriceStr(res.reqPrice), PriceStr(sl), PriceStr(tp)));
      return true;
     }

   ENUM_ORDER_TYPE_FILLING filling = ResolveFilling();
   int maxAttempts = 3;

   for(int attempt = 1; attempt <= maxAttempts; attempt++)
     {
      if(!RefreshTick())
        {
         res.comment = "no valid tick";
         return false;
        }

      MqlTradeRequest req;
      MqlTradeResult  tr;
      ZeroMemory(req);
      ZeroMemory(tr);

      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = _Symbol;
      req.volume       = lots;
      req.type         = type;
      req.price        = (type == ORDER_TYPE_BUY) ? g_tick.ask : g_tick.bid;
      req.sl           = sl;
      req.tp           = tp;
      req.deviation    = (ulong)MathMax(0, InpDeviationPoints);
      req.magic        = (ulong)InpMagic;
      req.comment      = "GoldSweep";
      req.type_filling = filling;
      req.type_time    = ORDER_TIME_GTC;

      string stopErr;
      if(!ValidateStops(type, sl, tp, g_tick, stopErr))
        {
         res.comment = StringFormat("pre-check rejected stops: %s", stopErr);
         return false;
        }

      if(InpUseOrderCheck)
        {
         MqlTradeCheckResult chk;
         ZeroMemory(chk);
         if(!OrderCheck(req, chk))
           {
            res.comment = StringFormat("OrderCheck call failed (%s)", ErrText());
            return false;
           }
         if(chk.retcode != 0 && !IsSuccessRetcode(chk.retcode))
           {
            res.retcode = chk.retcode;
            res.comment = StringFormat("OrderCheck: %u (%s) %s",
                                       chk.retcode, RetcodeText(chk.retcode), chk.comment);
            return false;
           }
        }

      res.reqPrice  = req.price;
      res.reqVolume = lots;
      res.retcode   = 0;

      bool sent = OrderSend(req, tr);
      res.sent      = true;
      res.retcode   = tr.retcode;
      res.order     = tr.order;
      res.deal      = tr.deal;
      res.fillPrice = tr.price;
      res.fillVolume = tr.volume;
      res.comment   = tr.comment;

      if(sent && IsSuccessRetcode(tr.retcode))
        {
         res.ok = true;
         return true;
        }

      if(IsRetryableRetcode(tr.retcode) && attempt < maxAttempts)
        {
         GSLog(GS_LOG_WARN, StringFormat("order attempt %d/%d retryable: %u (%s) - retrying",
                                         attempt, maxAttempts, tr.retcode, RetcodeText(tr.retcode)));
         continue;
        }

      if(!sent && GetLastError() != 0)
         res.comment = StringFormat("%s; %s", res.comment, ErrText());

      return false;
     }

   return false;
  }

bool ModifyStops(const ulong ticket,
                 const double wantSL,
                 const double wantTP,
                 string &err,
                 const bool silent)
  {
   err = "";

   SPosRef pos;
   if(!GetPositionRef(ticket, pos))
     {
      err = "position not found";
      return false;
     }

   if(g_dryRun)
     {
      GSLog(GS_LOG_INFO, StringFormat("DRY-RUN modify #%I64u SL %s TP %s",
                                      ticket, PriceStr(wantSL), PriceStr(wantTP)));
      return true;
     }

   if(!RefreshTick())
     {
      err = "no valid tick";
      return false;
     }

   double point = g_sym.point;
   if(point <= 0.0)
     {
      err = "invalid point";
      return false;
     }

   bool isBuy = (pos.posType == POSITION_TYPE_BUY);
   double newSL = wantSL;
   double newTP = wantTP;

   if(newSL > 0.0)
      newSL = RoundToTick(newSL, isBuy ? 1 : 2);
   if(newTP > 0.0)
      newTP = RoundToTick(newTP, isBuy ? 2 : 1);

   double minDist = MinStopDistance();

   if(isBuy)
     {
      double maxSL = g_tick.bid - minDist;
      if(newSL > 0.0 && newSL > maxSL)
         newSL = RoundToTick(maxSL, 1);
      double minTP = g_tick.bid + minDist;
      if(newTP > 0.0 && newTP < minTP)
         newTP = RoundToTick(minTP, 2);
     }
   else
     {
      double minSL = g_tick.ask + minDist;
      if(newSL > 0.0 && newSL < minSL)
         newSL = RoundToTick(minSL, 2);
      double maxTP = g_tick.ask - minDist;
      if(newTP > 0.0 && newTP > maxTP)
         newTP = RoundToTick(maxTP, 1);
     }

   if(g_sym.freezeLevel > 0)
     {
      double freeze = (double)g_sym.freezeLevel * point;
      double price  = isBuy ? g_tick.bid : g_tick.ask;
      if(newSL > 0.0 && MathAbs(price - newSL) < freeze)
        {
         err = "freeze level prevents SL modification";
         return false;
        }
      if(newTP > 0.0 && MathAbs(price - newTP) < freeze)
        {
         err = "freeze level prevents TP modification";
         return false;
        }
     }

   if(MathAbs(newSL - pos.sl) < point * 0.5 && MathAbs(newTP - pos.tp) < point * 0.5)
      return true;

   if(g_lastModifyTicket == ticket && (TimeCurrent() - g_lastModifyTime) < 3)
     {
      err = "modify throttled";
      return false;
     }

   MqlTradeRequest req;
   MqlTradeResult  tr;
   MqlTradeCheckResult chk;
   ZeroMemory(req);
   ZeroMemory(tr);
   ZeroMemory(chk);

   req.action = TRADE_ACTION_SLTP;
   req.symbol = _Symbol;
   req.sl     = newSL;
   req.tp     = newTP;
   if(g_isHedging)
      req.position = ticket;

   g_lastModifyTicket = ticket;
   g_lastModifyTime   = TimeCurrent();

   if(InpUseOrderCheck)
     {
      if(!OrderCheck(req, chk))
        {
         err = StringFormat("OrderCheck call failed (%s)", ErrText());
         return false;
        }
      if(chk.retcode != 0 && !IsSuccessRetcode(chk.retcode))
        {
         err = StringFormat("OrderCheck: %u (%s) %s", chk.retcode, RetcodeText(chk.retcode), chk.comment);
         return false;
        }
     }

   bool sent = OrderSend(req, tr);
   if(sent && (IsSuccessRetcode(tr.retcode) || tr.retcode == TRADE_RETCODE_NO_CHANGES))
     {
      g_lastModifyTicket = ticket;
      g_lastModifyTime   = TimeCurrent();
      if(!silent)
         GSLog(GS_LOG_INFO, StringFormat("position #%I64u stops updated: SL %s TP %s",
                                         ticket, PriceStr(newSL), PriceStr(newTP)));
      return true;
     }

   err = StringFormat("modify failed: %u (%s) %s", tr.retcode, RetcodeText(tr.retcode), tr.comment);
   if(!sent && GetLastError() != 0)
      err = StringFormat("%s; %s", err, ErrText());
   if(!silent)
      GSLog(GS_LOG_WARN, StringFormat("position #%I64u %s", ticket, err));
   return false;
  }

bool ClosePositionByTicket(const ulong ticket, string &err)
  {
   err = "";

   SPosRef pos;
   if(!GetPositionRef(ticket, pos))
      return true;

   if(g_dryRun)
     {
      GSLog(GS_LOG_INFO, StringFormat("DRY-RUN close #%I64u volume %.2f", ticket, pos.volume));
      return true;
     }

   if(!RefreshTick())
     {
      err = "no valid tick";
      return false;
     }

   ENUM_ORDER_TYPE closeType = (pos.posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;

   MqlTradeRequest req;
   MqlTradeResult  tr;
   MqlTradeCheckResult chk;
   ZeroMemory(req);
   ZeroMemory(tr);
   ZeroMemory(chk);

   req.action       = TRADE_ACTION_DEAL;
   req.position     = ticket;
   req.symbol       = _Symbol;
   req.volume       = pos.volume;
   req.type         = closeType;
   req.price        = (closeType == ORDER_TYPE_BUY) ? g_tick.ask : g_tick.bid;
   req.deviation    = (ulong)MathMax(0, InpDeviationPoints);
   req.magic        = (ulong)InpMagic;
   req.comment      = "GoldSweep close";
   req.type_filling = ResolveFilling();
   req.type_time    = ORDER_TIME_GTC;

   if(InpUseOrderCheck)
     {
      if(!OrderCheck(req, chk))
        {
         err = StringFormat("OrderCheck call failed (%s)", ErrText());
         return false;
        }
      if(chk.retcode != 0 && !IsSuccessRetcode(chk.retcode))
        {
         err = StringFormat("OrderCheck: %u (%s) %s", chk.retcode, RetcodeText(chk.retcode), chk.comment);
         return false;
        }
     }

   bool sent = OrderSend(req, tr);
   if(sent && IsSuccessRetcode(tr.retcode))
     {
      GSLog(GS_LOG_INFO, StringFormat("closed #%I64u %.2f lot at %s (retcode %u)",
                                      ticket, tr.volume, PriceStr(tr.price), tr.retcode));
      return true;
     }

   err = StringFormat("close failed: %u (%s) %s", tr.retcode, RetcodeText(tr.retcode), tr.comment);
   return false;
  }

void DeleteOurPendingOrders()
  {
   int total = OrdersTotal();
   for(int idx = total - 1; idx >= 0; idx--)
     {
      ulong ticket = OrderGetTicket(idx);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic)
         continue;

      MqlTradeRequest req;
      MqlTradeResult  tr;
      ZeroMemory(req);
      ZeroMemory(tr);
      req.action = TRADE_ACTION_REMOVE;
      req.order  = ticket;

      if(OrderSend(req, tr) && IsSuccessRetcode(tr.retcode))
         GSLog(GS_LOG_INFO, StringFormat("pending order #%I64u removed", ticket));
      else
         GSLog(GS_LOG_WARN, StringFormat("pending order #%I64u remove failed: %u (%s)",
                                         ticket, tr.retcode, RetcodeText(tr.retcode)));
     }
  }

void DeleteStalePosState(const ulong ticket)
  {
   if(ticket == 0)
      return;
   if(PositionSelectByTicket(ticket))
      return;
   DeletePosState(ticket);
  }

void CloseAllOurPositions(const string reason)
  {
   SPosRef list[];
   int count = CollectPositions(list, true);
   if(count <= 0)
      return;

   GSLog(GS_LOG_WARN, StringFormat("closing %d EA position(s): %s", count, reason));

   for(int i = 0; i < count; i++)
     {
      string err;
      bool closed = ClosePositionByTicket(list[i].ticket, err);
      if(closed)
        {
         if(!PositionSelectByTicket(list[i].ticket))
            DeletePosState(list[i].ticket);
         GSLog(GS_LOG_INFO, StringFormat("position #%I64u close requested (%s)",
                                         list[i].ticket, reason));
        }
      else
        {
         GSLog(GS_LOG_ERROR, StringFormat("position #%I64u close failed: %s",
                                          list[i].ticket, err));
        }
     }
  }

//+------------------------------------------------------------------+
//| 11. Trade event log (CSV)                                        |
//+------------------------------------------------------------------+
void LogTradeEvent(const string eventName,
                   const ulong ticket,
                   const string direction,
                   const double lots,
                   const double price,
                   const double sl,
                   const double tp,
                   const double riskMoney,
                   const uint retcode,
                   const string note)
  {
   if(!InpWriteTradeLog || MQLInfoInteger(MQL_OPTIMIZATION))
      return;

   string path = TradeLogFilePath();
   bool isNew = !FileIsExist(path);

   int handle = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      if(!g_fileWarned)
        {
         g_fileWarned = true;
         GSLog(GS_LOG_WARN, StringFormat("tradelog: cannot open %s (%s)", path, ErrText()));
        }
      return;
     }

   FileSeek(handle, 0, SEEK_END);

   if(isNew)
      FileWriteString(handle, "time;event;symbol;magic;ticket;dir;lots;price;sl;tp;risk;retcode;note\r\n");

   string safeNote = note;
   StringReplace(safeNote, GS_CSV_DELIM, ",");
   StringReplace(safeNote, "\r", " ");
   StringReplace(safeNote, "\n", " ");

   string line = StringFormat("%s;%s;%s;%I64d;%I64u;%s;%.2f;%.5f;%.5f;%.5f;%.2f;%u;%s\r\n",
                              TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                              eventName, _Symbol, InpMagic, ticket, direction,
                              lots, price, sl, tp, riskMoney, retcode, safeNote);
   FileWriteString(handle, line);
   FileClose(handle);
  }

//+------------------------------------------------------------------+
//| 12. Session and trading-hours logic (server time)                |
//+------------------------------------------------------------------+
int NormalizeMinute(int minute)
  {
   int result = minute % 1440;
   if(result < 0)
      result += 1440;
   return result;
  }

bool InSession(const datetime moment)
  {
   if(!InpUseSession)
      return true;

   int weekday = WeekDay(moment);
   if(weekday == 0 || weekday == 6)
      return false;

   int startMinute = NormalizeMinute(InpSessionStartHour * 60 + InpSessionStartMin + InpSessionShiftHours * 60);
   int endMinute   = NormalizeMinute(InpSessionEndHour * 60 + InpSessionEndMin + InpSessionShiftHours * 60);
   int current     = MinuteOfDay(moment);

   if(startMinute == endMinute)
      return true;

   if(startMinute < endMinute)
      return (current >= startMinute && current < endMinute);

   // Overnight session (start > end) - the window wraps midnight.
   return (current >= startMinute || current < endMinute);
  }

bool FridayBlocked(const datetime moment)
  {
   if(!InpUseFridayCutoff)
      return false;
   if(WeekDay(moment) != 5)
      return false;

   int cut     = InpFridayCutHour * 60 + InpFridayCutMin;
   int current = MinuteOfDay(moment);
   return (current >= cut);
  }

string SessionStatusText()
  {
   if(!InpUseSession)
      return "OFF";
   if(FridayBlocked(TimeCurrent()))
      return "FRIDAY-CUT";
   if(InSession(TimeCurrent()))
      return "OPEN";
   return "CLOSED";
  }

//+------------------------------------------------------------------+
//| 13. Hard risk guards                                             |
//+------------------------------------------------------------------+
bool IsLocked(string &reason)
  {
   reason = "";

   if(g_state.hardLocked)
     {
      reason = StringFormat("PERMANENT LOCK: %s", g_state.lockReason);
      return true;
     }

   if(g_state.dailyLocked)
     {
      if(g_state.dayKey == DayKey(TimeCurrent()))
        {
         reason = StringFormat("DAILY LOCK: %s", g_state.lockReason);
         return true;
        }

      g_state.dailyLocked = false;
      g_state.lockReason  = "";
      SaveState(true);
      GSLog(GS_LOG_INFO, "new server day - daily lock released automatically");
     }

   return false;
  }

void LockDaily(const string reason)
  {
   if(g_state.dailyLocked)
      return;

   g_state.dailyLocked = true;
   g_state.lockReason  = reason;
   SaveState(true);

   GSLog(GS_LOG_ERROR, StringFormat("DAILY LOSS LIMIT HIT: %s | trading locked until next server day", reason));
   LogTradeEvent("LOCK_DAILY", 0, "", 0.0, 0.0, 0.0, 0.0, 0.0, 0, reason);

   DeleteOurPendingOrders();

   if(InpDailyLossClosePos)
      CloseAllOurPositions("daily loss limit");
  }

void LockHard(const string reason)
  {
   if(g_state.hardLocked)
      return;

   g_state.hardLocked = true;
   g_state.lockReason = reason;
   SaveState(true);

   GSLog(GS_LOG_ERROR, StringFormat("MAX DRAWDOWN LIMIT HIT: %s | permanent lock, restart with InpResetState=true after review", reason));
   LogTradeEvent("LOCK_HARD", 0, "", 0.0, 0.0, 0.0, 0.0, 0.0, 0, reason);

   DeleteOurPendingOrders();

   if(InpMaxDDClosePos)
      CloseAllOurPositions("max drawdown limit");
  }

void EvaluateGuards()
  {
   datetime now = TimeCurrent();
   int today = DayKey(now);

   if(g_state.dayKey != today)
     {
      g_state.dayKey       = today;
      g_state.dailyLocked  = false;
      if(!g_state.hardLocked)
         g_state.lockReason = "";
      g_state.startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      SaveState(true);
      GSLog(GS_LOG_INFO, StringFormat("new server day %d - daily counters reset (hardLocked=%s)",
                                      today, BoolStr(g_state.hardLocked)));
     }

   string lockReason;
   if(IsLocked(lockReason))
     {
      bool mustClose = (g_state.dailyLocked && InpDailyLossClosePos) ||
                       (g_state.hardLocked && InpMaxDDClosePos);
      if(mustClose && (g_lastGuardClose == 0 || (now - g_lastGuardClose) >= 5))
        {
         g_lastGuardClose = now;
         CloseAllOurPositions(lockReason);
        }
      return;
     }

   SDailyStats stats;
   if(!ComputeDailyStats(stats, false))
      return;

   if(stats.equity > g_state.hwmEquity)
     {
      g_state.hwmEquity = stats.equity;
      g_state.hwmTime   = now;
      SaveState(false);
     }

   if(InpMaxDailyLossPct > 0.0 && stats.lossPct >= InpMaxDailyLossPct)
     {
      string reason = StringFormat("daily loss %.2f%% >= %.2f%% (loss %.2f, start balance %.2f)",
                                   stats.lossPct, InpMaxDailyLossPct,
                                   stats.lossMoney, stats.startBalance);
      LockDaily(reason);
      return;
     }

   if(InpMaxDrawdownPct > 0.0 && g_state.hwmEquity > 0.0)
     {
      double drawdownPct = (g_state.hwmEquity - stats.equity) / g_state.hwmEquity * 100.0;
      if(drawdownPct >= InpMaxDrawdownPct)
        {
         string reason = StringFormat("drawdown %.2f%% >= %.2f%% (HWM %.2f, equity %.2f)",
                                      drawdownPct, InpMaxDrawdownPct,
                                      g_state.hwmEquity, stats.equity);
         LockHard(reason);
        }
     }
  }

//+------------------------------------------------------------------+
//| 14. Indicators and signal detection                              |
//+------------------------------------------------------------------+
void ReleaseIndicators()
  {
   if(g_hEmaFast != INVALID_HANDLE)
     {
      IndicatorRelease(g_hEmaFast);
      g_hEmaFast = INVALID_HANDLE;
     }
   if(g_hEmaSlow != INVALID_HANDLE)
     {
      IndicatorRelease(g_hEmaSlow);
      g_hEmaSlow = INVALID_HANDLE;
     }
   if(g_hAtr != INVALID_HANDLE)
     {
      IndicatorRelease(g_hAtr);
      g_hAtr = INVALID_HANDLE;
     }
  }

bool InitIndicators()
  {
   ReleaseIndicators();

   if(InpUseTrendFilter)
     {
      g_hEmaFast = iMA(_Symbol, InpTrendTF, InpEmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_hEmaSlow = iMA(_Symbol, InpTrendTF, InpEmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_hEmaFast == INVALID_HANDLE || g_hEmaSlow == INVALID_HANDLE)
        {
         GSLog(GS_LOG_ERROR, StringFormat("cannot create EMA handles on %s (%s)",
                                          TFToStr(InpTrendTF), ErrText()));
         ReleaseIndicators();
         return false;
        }
     }

   g_hAtr = iATR(_Symbol, InpSignalTF, InpAtrPeriod);
   if(g_hAtr == INVALID_HANDLE)
     {
      GSLog(GS_LOG_ERROR, StringFormat("cannot create ATR handle on %s (%s)",
                                       TFToStr(InpSignalTF), ErrText()));
      ReleaseIndicators();
      return false;
     }

   return true;
  }

double CurrentATR()
  {
   if(g_hAtr == INVALID_HANDLE)
      return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);

   int copied = CopyBuffer(g_hAtr, 0, 1, 2, buffer);
   if(copied < 1 || ArraySize(buffer) < 1)
     {
      GSLog(GS_LOG_DEBUG, StringFormat("ATR not ready (copied=%d)", copied));
      return 0.0;
     }

   if(buffer[0] <= 0.0 || !MathIsValidNumber(buffer[0]))
      return 0.0;

   return buffer[0];
  }

bool ReadTrend(int &direction, string &description)
  {
   direction   = 0;
   description = "filter off";

   if(!InpUseTrendFilter)
      return true;

   if(g_hEmaFast == INVALID_HANDLE || g_hEmaSlow == INVALID_HANDLE)
     {
      description = "EMA handles missing";
      return false;
     }

   double fast[];
   double slow[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);

   if(CopyBuffer(g_hEmaFast, 0, 1, 2, fast) < 1 || ArraySize(fast) < 1)
     {
      description = "fast EMA copy failed";
      return false;
     }
   if(CopyBuffer(g_hEmaSlow, 0, 1, 2, slow) < 1 || ArraySize(slow) < 1)
     {
      description = "slow EMA copy failed";
      return false;
     }

   if(fast[0] > slow[0])
      direction = 1;
   else
      if(fast[0] < slow[0])
         direction = -1;
      else
         direction = 0;

   if(InpTrendRequirePrice && direction != 0)
     {
      MqlRates trendRates[];
      ArraySetAsSeries(trendRates, true);
      if(CopyRates(_Symbol, InpTrendTF, 1, 1, trendRates) < 1 || ArraySize(trendRates) < 1)
        {
         description = "trend price copy failed";
         return false;
        }
      bool priceConfirmed = ((direction > 0 && trendRates[0].close >= slow[0]) ||
                             (direction < 0 && trendRates[0].close <= slow[0]));
      if(!priceConfirmed)
         direction = 0;   // 0 = no trend permission (filter blocks both sides)
     }

   description = StringFormat("EMA%d %s EMA%d", InpEmaFastPeriod,
                              (direction > 0 ? "above" : (direction < 0 ? "below" : "neutral")),
                              InpEmaSlowPeriod);
   return true;
  }

datetime ClosedBarTime()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   if(CopyRates(_Symbol, InpSignalTF, 0, 2, rates) < 2 || ArraySize(rates) < 2)
      return 0;

   return rates[1].time;
  }

bool DetectSignal(SSignal &signal)
  {
   ZeroMemory(signal);
   signal.valid      = false;
   signal.type       = ORDER_TYPE_BUY;
   signal.sweepLevel = 0.0;
   signal.atr        = 0.0;
   signal.barHigh    = 0.0;
   signal.barLow     = 0.0;
   signal.barClose   = 0.0;
   signal.note       = "";

   if(!g_sym.valid || g_sym.point <= 0.0)
     {
      signal.note = "symbol not ready";
      return false;
     }

   int lookback = InpSweepLookback;
   int need     = lookback + 2;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, InpSignalTF, 1, need, rates);
   if(copied < need || ArraySize(rates) < need)
     {
      signal.note = StringFormat("not enough bars (copied %d, need %d)", copied, need);
      return false;
     }

   double atr = CurrentATR();
   if(atr <= 0.0)
     {
      signal.note = "ATR unavailable";
      return false;
     }
   signal.atr = atr;

   // rates[0] is the last CLOSED bar (shift 1), rates[1..] are older bars.
   double barHigh  = rates[0].high;
   double barLow   = rates[0].low;
   double barOpen  = rates[0].open;
   double barClose = rates[0].close;

   signal.barHigh  = barHigh;
   signal.barLow   = barLow;
   signal.barClose = barClose;

   if(InpMaxBarRangeATR > 0.0 && (barHigh - barLow) > InpMaxBarRangeATR * atr)
     {
      signal.note = StringFormat("bar range %.0f pts > %.1f x ATR", (barHigh - barLow) / g_sym.point, InpMaxBarRangeATR);
      return false;
     }

   int trendDirection = 0;
   string trendDescription = "";
   if(!ReadTrend(trendDirection, trendDescription))
     {
      signal.note = StringFormat("trend filter unavailable: %s", trendDescription);
      return false;
     }

   double support    = rates[1].low;
   double resistance = rates[1].high;
   for(int idx = 2; idx <= lookback; idx++)
     {
      if(rates[idx].low < support)
         support = rates[idx].low;
      if(rates[idx].high > resistance)
         resistance = rates[idx].high;
     }

   double minPenetration = InpMinPenetrationATR * atr;
   double reclaimBuffer  = InpReclaimBufferATR * atr;

   bool bullishSweep = ((support - barLow) > minPenetration) && (barClose > support + reclaimBuffer);
   bool bearishSweep = ((barHigh - resistance) > minPenetration) && (barClose < resistance - reclaimBuffer);

   bool reversalOkBuy  = (!InpRequireReversalClose || barClose > barOpen);
   bool reversalOkSell = (!InpRequireReversalClose || barClose < barOpen);

   bool trendOkBuy  = (!InpUseTrendFilter) || (trendDirection > 0);
   bool trendOkSell = (!InpUseTrendFilter) || (trendDirection < 0);

   if(bullishSweep && !bearishSweep && reversalOkBuy && trendOkBuy)
     {
      signal.valid      = true;
      signal.type       = ORDER_TYPE_BUY;
      signal.sweepLevel = barLow;
      signal.note       = StringFormat("bullish sweep below %s, close back above (trend %s)",
                                       PriceStr(support), trendDescription);
      return true;
     }

   if(bearishSweep && !bullishSweep && reversalOkSell && trendOkSell)
     {
      signal.valid      = true;
      signal.type       = ORDER_TYPE_SELL;
      signal.sweepLevel = barHigh;
      signal.note       = StringFormat("bearish sweep above %s, close back below (trend %s)",
                                       PriceStr(resistance), trendDescription);
      return true;
     }

   if(bullishSweep || bearishSweep)
      signal.note = StringFormat("sweep found but filtered (trend=%d ok=%s/%s, reversal=%s)",
                                 trendDirection,
                                 BoolStr(trendOkBuy), BoolStr(trendOkSell),
                                 (bullishSweep ? BoolStr(reversalOkBuy) : BoolStr(reversalOkSell)));

   return false;
  }

//+------------------------------------------------------------------+
//| 15. Position management: breakeven, trailing, time exit          |
//+------------------------------------------------------------------+
void TryBreakEven(const SPosRef &position, SPosState &state)
  {
   if(!InpUseBreakeven || state.beDone)
      return;

   if(state.entry <= 0.0 || state.initialSL <= 0.0)
      return;

   double risk = MathAbs(state.entry - state.initialSL);
   if(risk <= 0.0)
      return;

   if(!RefreshTick())
      return;

   bool isBuy = (position.posType == POSITION_TYPE_BUY);
   double price = isBuy ? g_tick.bid : g_tick.ask;
   double moved = isBuy ? (price - state.entry) : (state.entry - price);

   if(moved < InpBEStartR * risk)
      return;

   double target = isBuy ? (state.entry + InpBELockR * risk)
                         : (state.entry - InpBELockR * risk);
   double minStep = (double)InpBEMinStepPoints * g_sym.point;

   double minDistance = MinStopDistance();
   if(isBuy && (g_tick.bid - target) < minDistance)
      return;
   if(!isBuy && (target - g_tick.ask) < minDistance)
      return;

   if(position.sl > 0.0)
     {
      if(isBuy && target <= position.sl + minStep)
        {
         state.beDone = true;
         SavePosState(state);
         return;
        }
      if(!isBuy && target >= position.sl - minStep)
        {
         state.beDone = true;
         SavePosState(state);
         return;
        }
     }

   string err;
   if(ModifyStops(position.ticket, target, position.tp, err, true))
     {
      state.beDone = true;
      SavePosState(state);
      GSLog(GS_LOG_INFO, StringFormat("#%I64u breakeven: SL -> %s (R=%.0f pts, locked %.2fR)",
                                      position.ticket, PriceStr(target),
                                      risk / g_sym.point, InpBELockR));
      LogTradeEvent("BREAKEVEN", position.ticket, "", position.volume, target, target, position.tp, 0.0, 0, "breakeven");
     }
   else
     {
      GSLog(GS_LOG_DEBUG, StringFormat("#%I64u breakeven attempt failed: %s", position.ticket, err));
     }
  }

void TryTrailing(const SPosRef &position, SPosState &state)
  {
   if(!InpUseTrailing)
      return;

   if(state.entry <= 0.0 || state.initialSL <= 0.0)
      return;

   double risk = MathAbs(state.entry - state.initialSL);
   if(risk <= 0.0)
      return;

   if(!RefreshTick())
      return;

   bool isBuy = (position.posType == POSITION_TYPE_BUY);
   double price = isBuy ? g_tick.bid : g_tick.ask;
   double moved = isBuy ? (price - state.entry) : (state.entry - price);

   if(moved < InpTrailStartR * risk)
      return;

   double target = isBuy ? (price - InpTrailDistR * risk)
                         : (price + InpTrailDistR * risk);
   double minStep = (double)InpTrailMinStepPoints * g_sym.point;

   double minDistance = MinStopDistance();
   if(isBuy && (g_tick.bid - target) < minDistance)
      return;
   if(!isBuy && (target - g_tick.ask) < minDistance)
      return;

   if(position.sl > 0.0)
     {
      if(isBuy && target <= position.sl + minStep)
         return;
      if(!isBuy && target >= position.sl - minStep)
         return;
     }

   if(MathAbs(target - state.lastTrailSL) < g_sym.point * 0.5 && state.lastTrailSL > 0.0)
      return;

   string err;
   if(ModifyStops(position.ticket, target, position.tp, err, true))
     {
      state.lastTrailSL = target;
      SavePosState(state);
      GSLog(GS_LOG_DEBUG, StringFormat("#%I64u trailing: SL -> %s", position.ticket, PriceStr(target)));
      LogTradeEvent("TRAIL", position.ticket, "", position.volume, target, target, position.tp, 0.0, 0, "trailing");
     }
  }

void TryTimeExit(const SPosRef &position, SPosState &state)
  {
   if(InpTimeExitBars <= 0 || state.opened <= 0)
      return;

   int barsHeld = (int)((TimeCurrent() - state.opened) / SecondsPerSignalBar());
   if(barsHeld < InpTimeExitBars)
      return;

   if(InpTimeExitOnlyProfit && (position.profit + position.swap) <= 0.0)
      return;

   string err;
   if(ClosePositionByTicket(position.ticket, err))
     {
      GSLog(GS_LOG_INFO, StringFormat("#%I64u time exit after %d bars (%s)",
                                      position.ticket, barsHeld, err));
      LogTradeEvent("TIME_EXIT", position.ticket, "", position.volume, 0.0, 0.0, 0.0, 0.0, 0, "time exit");
      DeleteStalePosState(position.ticket);
     }
   else
      GSLog(GS_LOG_WARN, StringFormat("#%I64u time exit failed: %s", position.ticket, err));
  }

void ManagePositions()
  {
   SyncPosStates();

   if(InpCloseAtSessionEnd && InpUseSession && !InSession(TimeCurrent()) && HasOurPosition())
     {
      if(g_lastGuardClose == 0 || (TimeCurrent() - g_lastGuardClose) >= 5)
        {
         g_lastGuardClose = TimeCurrent();
         CloseAllOurPositions("session end");
         return;
        }
     }

   SPosRef list[];
   int count = CollectPositions(list, true);
   if(count <= 0)
      return;

   for(int i = 0; i < count; i++)
     {
      int idx = FindPosState(list[i].ticket);
      SPosState state;
      if(idx < 0)
        {
         BuildFallbackPosState(list[i], state);
         UpsertPosState(state);
        }
      else
         state = g_posStates[idx];

      if(state.foreignMod)
         continue;

      if(list[i].open > 0.0 && MathAbs(state.entry - list[i].open) > g_sym.tickSize * 0.01)
        {
         state.entry = list[i].open;
         SavePosState(state);
        }

      if(InpUseBreakeven)
         TryBreakEven(list[i], state);

      if(InpUseTrailing)
         TryTrailing(list[i], state);

      if(InpTimeExitBars > 0)
         TryTimeExit(list[i], state);

      int writeIdx = FindPosState(list[i].ticket);
      if(writeIdx >= 0)
         g_posStates[writeIdx] = state;
     }
  }

//+------------------------------------------------------------------+
//| 16. Entry engine                                                 |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_RESULT
  {
   ENTRY_SKIP      = -1,
   ENTRY_TRANSIENT =  0,
   ENTRY_FILLED    =  1
  };

bool BuildLevels(const SSignal &signal,
                 const double entry,
                 double &sl,
                 double &tp,
                 string &err)
  {
   sl = 0.0;
   tp = 0.0;
   err = "";

   if(signal.atr <= 0.0 || g_sym.point <= 0.0)
     {
      err = "invalid ATR/point";
      return false;
     }

   double point = g_sym.point;
   double rawDistance = 0.0;

   if(signal.type == ORDER_TYPE_BUY)
      rawDistance = entry - (signal.sweepLevel - InpAtrSLMult * signal.atr);
   else
      rawDistance = (signal.sweepLevel + InpAtrSLMult * signal.atr) - entry;

   if(rawDistance <= 0.0)
     {
      err = StringFormat("invalid geometry: entry %s, sweep %s, ATR %.0f pts",
                         PriceStr(entry), PriceStr(signal.sweepLevel), signal.atr / point);
      return false;
     }

   double minDistance = (double)InpMinSLPoints * point;
   double maxDistance = (double)InpMaxSLPoints * point;

   if(rawDistance < minDistance)
      rawDistance = minDistance;

   if(InpMaxSLPoints > 0 && rawDistance > maxDistance + 1e-9)
     {
      err = StringFormat("required SL %.0f pts exceeds max %d pts (volatile bar)",
                         rawDistance / point, InpMaxSLPoints);
      return false;
     }

   if(signal.type == ORDER_TYPE_BUY)
     {
      sl = RoundToTick(entry - rawDistance, 1);
      tp = (InpRR > 0.0) ? RoundToTick(entry + InpRR * rawDistance, 2) : 0.0;
     }
   else
     {
      sl = RoundToTick(entry + rawDistance, 2);
      tp = (InpRR > 0.0) ? RoundToTick(entry - InpRR * rawDistance, 1) : 0.0;
     }

   if(MathAbs(entry - sl) < point)
     {
      err = "SL distance collapsed after tick rounding";
      return false;
     }

   return true;
  }

bool CanTradeNow(string &reason, bool &transient)
  {
   reason    = "";
   transient = false;

   if(!InpEnableTrading)
     {
      reason = "trading disabled by InpEnableTrading";
      return false;
     }
   if(!g_sym.valid)
     {
      reason = "symbol specification invalid";
      return false;
     }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      reason = "terminal AutoTrading button is OFF";
      return false;
     }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      reason = "algo trading not allowed for this EA";
      return false;
     }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     {
      reason = "broker disabled expert trading on this account";
      return false;
     }
   if(g_sym.tradeMode != SYMBOL_TRADE_MODE_FULL)
     {
      reason = StringFormat("symbol trade mode is %I64d (need FULL)", g_sym.tradeMode);
      return false;
     }

   string lockReason;
   if(IsLocked(lockReason))
     {
      reason = lockReason;
      return false;
     }

   if(!InSession(TimeCurrent()))
     {
      reason = "outside trading session";
      return false;
     }
   if(FridayBlocked(TimeCurrent()))
     {
      reason = "Friday cutoff reached";
      return false;
     }

   SDailyStats stats;
   if(!ComputeDailyStats(stats, false))
     {
      reason = "daily statistics unavailable (history)";
      return false;
     }

   if(InpMaxTradesPerDay > 0 && stats.entriesToday >= InpMaxTradesPerDay)
     {
      reason = StringFormat("daily entry limit reached (%d/%d)", stats.entriesToday, InpMaxTradesPerDay);
      return false;
     }

   if(InpMaxPositions > 0 && OurPositionsCount() >= InpMaxPositions)
     {
      reason = "max simultaneous positions reached";
      return false;
     }

   string foreignDescription;
   if(HasForeignNettingPosition(foreignDescription))
     {
      reason = foreignDescription;
      return false;
     }

   for(int i = 0; i < ArraySize(g_posStates); i++)
     {
      if(g_posStates[i].foreignMod)
        {
         reason = "netting position was modified externally";
         return false;
        }
     }

   if(InpMaxSpreadPoints > 0)
     {
      double spread = CurrentSpreadPoints();
      if(spread > (double)InpMaxSpreadPoints)
        {
         reason    = StringFormat("spread %.0f pts > limit %d pts", spread, InpMaxSpreadPoints);
         transient = true;
         return false;
        }
     }

   if(stats.lastCloseTime > 0)
     {
      int minutesSince = (int)((TimeCurrent() - stats.lastCloseTime) / 60);
      int required = (stats.lastCloseProfit < 0.0) ? InpCooldownLossMin : InpCooldownWinMin;
      if(required > 0 && minutesSince < required)
        {
         reason = StringFormat("cooldown %d/%d min after last close", minutesSince, required);
         return false;
        }
     }

   return true;
  }

bool FindOurNewestPosition(ulong &ticket, SPosRef &result)
  {
   SPosRef list[];
   int count = CollectPositions(list, true);
   if(count <= 0)
      return false;

   int best = 0;
   for(int i = 1; i < count; i++)
     {
      if(list[i].ticket > list[best].ticket)
         best = i;
      else
         if(list[i].ticket == list[best].ticket && list[i].openTime > list[best].openTime)
            best = i;
     }

   ticket = list[best].ticket;
   result = list[best];
   return true;
  }

ENUM_ENTRY_RESULT TryEnter(const SSignal &signal)
  {
   string reason;
   bool transient = false;

   if(!CanTradeNow(reason, transient))
     {
      GSLog(transient ? GS_LOG_INFO : GS_LOG_DEBUG,
            StringFormat("entry blocked: %s", reason));
      return (transient ? ENTRY_TRANSIENT : ENTRY_SKIP);
     }

   if(!RefreshTick())
      return ENTRY_TRANSIENT;

   double entry = (signal.type == ORDER_TYPE_BUY) ? g_tick.ask : g_tick.bid;
   double sl = 0.0;
   double tp = 0.0;
   string err;

   if(!BuildLevels(signal, entry, sl, tp, err))
     {
      GSLog(GS_LOG_WARN, StringFormat("signal rejected: %s", err));
      return ENTRY_SKIP;
     }

   bool geometryOk = false;
   if(signal.type == ORDER_TYPE_BUY)
      geometryOk = (sl < entry) && (tp <= 0.0 || tp > entry);
   else
      geometryOk = (sl > entry) && (tp <= 0.0 || tp < entry);

   if(!geometryOk)
     {
      GSLog(GS_LOG_ERROR, StringFormat("bad level geometry: entry %s SL %s TP %s",
                                       PriceStr(entry), PriceStr(sl), PriceStr(tp)));
      return ENTRY_SKIP;
     }

   if(!ValidateStops(signal.type, sl, tp, g_tick, err))
     {
      GSLog(GS_LOG_INFO, StringFormat("stops not valid yet (spread/price): %s", err));
      return ENTRY_TRANSIENT;
     }

   double riskMoney = 0.0;
   double riskPct   = 0.0;
   double lots = CalcLots(signal.type, entry, sl, riskMoney, riskPct, err);
   if(lots <= 0.0)
     {
      GSLog(GS_LOG_WARN, StringFormat("sizing rejected: %s", err));
      return ENTRY_SKIP;
     }

   if(!CheckMargin(signal.type, lots, entry, err))
     {
      GSLog(GS_LOG_WARN, StringFormat("margin rejected: %s", err));
      return ENTRY_SKIP;
     }

   if(InpMaxDailyLossPct > 0.0 && g_statsOk && g_stats.startBalance > 0.0)
     {
      double allowedLoss = g_stats.startBalance * InpMaxDailyLossPct / 100.0;
      double remaining   = allowedLoss - g_stats.lossMoney;
      if(remaining <= 0.0)
        {
         GSLog(GS_LOG_WARN, "daily loss capacity exhausted - no new risk");
         return ENTRY_SKIP;
        }
      if(riskMoney > remaining + 1e-9)
        {
         GSLog(GS_LOG_WARN, StringFormat("planned risk %.2f exceeds remaining daily capacity %.2f",
                                         riskMoney, remaining));
         return ENTRY_SKIP;
        }
     }

   if(InpMaxOpenRiskPct > 0.0)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double cap    = equity * InpMaxOpenRiskPct / 100.0;
      double openRisk = OurOpenRiskMoney();
      if(openRisk + riskMoney > cap + 1e-9)
        {
         GSLog(GS_LOG_WARN, StringFormat("open risk cap: existing %.2f + new %.2f > %.2f",
                                         openRisk, riskMoney, cap));
         return ENTRY_SKIP;
        }
     }

   GSLog(GS_LOG_INFO, StringFormat("ENTRY REQUEST %s %.2f lot | ref %s SL %s TP %s | risk %.2f (%.2f%%) | spread %.0f pts | %s",
                                   (signal.type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                                   lots, PriceStr(entry), PriceStr(sl), PriceStr(tp),
                                   riskMoney, riskPct, CurrentSpreadPoints(), signal.note));

   SPosRef beforeList[];
   int beforeCount = CollectPositions(beforeList, true);
   ulong beforeMaxTicket = 0;
   for(int i = 0; i < beforeCount; i++)
      if(beforeList[i].ticket > beforeMaxTicket)
         beforeMaxTicket = beforeList[i].ticket;

   SExecResult res;
   if(!SendMarketOrder(signal.type, lots, sl, tp, res))
     {
      GSLog(GS_LOG_ERROR, StringFormat("order failed: retcode=%u (%s) %s",
                                       res.retcode, RetcodeText(res.retcode), res.comment));

      // An ambiguous result (timeout, partial fill, disconnected terminal) can
      // still leave a real position behind. Detect and adopt it instead of
      // sending a duplicate order on the next retry.
      SPosRef latePos;
      ulong lateTicket = 0;
      if(FindOurNewestPosition(lateTicket, latePos) && lateTicket > beforeMaxTicket)
        {
         double lateSL = (latePos.sl > 0.0) ? latePos.sl : sl;

         SPosState lateState;
         ZeroMemory(lateState);
         lateState.ticket            = lateTicket;
         lateState.valid             = true;
         lateState.entry             = latePos.open;
         lateState.initialSL         = lateSL;
         lateState.riskMoney         = 0.0;
         lateState.initialRiskPoints = (g_sym.point > 0.0) ? MathAbs(latePos.open - lateSL) / g_sym.point : 0.0;
         lateState.opened            = TimeCurrent();
         lateState.beDone            = false;
         lateState.lastTrailSL       = 0.0;
         lateState.volumeAtEntry     = latePos.volume;
         lateState.foreignMod        = false;
         UpsertPosState(lateState);

         GSLog(GS_LOG_ERROR, StringFormat("order returned failure (retcode=%u) but position #%I64u exists - adopted and will be managed",
                                          res.retcode, lateTicket));
         LogTradeEvent("ADOPT", lateTicket, (signal.type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                       latePos.volume, latePos.open, lateSL, latePos.tp, 0.0, res.retcode,
                       "ambiguous result adopted");
         return ENTRY_FILLED;
        }

      bool retryable = (res.retcode == 0) || IsRetryableRetcode(res.retcode);
      return (retryable ? ENTRY_TRANSIENT : ENTRY_SKIP);
     }

   if(g_dryRun)
     {
      GSLog(GS_LOG_INFO, StringFormat("DRY-RUN entry accepted: %s %.2f lot SL %s TP %s risk %.2f",
                                      (signal.type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                                      lots, PriceStr(sl), PriceStr(tp), riskMoney));
      LogTradeEvent("DRY_ENTRY", 0, (signal.type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                    lots, res.reqPrice, sl, tp, riskMoney, res.retcode, "dry run");
      return ENTRY_FILLED;
     }

   ulong ticket = 0;
   SPosRef position;
   if(!FindOurNewestPosition(ticket, position))
     {
      GSLog(GS_LOG_ERROR, "order reported success but no EA position was found - check broker journal");
      return ENTRY_SKIP;
     }

   double fillPrice = (res.fillPrice > 0.0) ? res.fillPrice : position.open;
   double actualSL  = (position.sl > 0.0) ? position.sl : sl;

   if(res.fillVolume > 0.0 && MathAbs(res.fillVolume - lots) > g_sym.volStep * 0.5)
      GSLog(GS_LOG_WARN, StringFormat("partial fill: requested %.2f, filled %.2f", lots, res.fillVolume));

   // Actual risk after the fill (entry price can differ from the request).
   bool actualPerLotOk = false;
   double actualPerLot = RiskPerLot(signal.type, position.open, actualSL, actualPerLotOk);
   double actualRiskMoney = actualPerLotOk ? (actualPerLot * position.volume) : riskMoney;
   if(actualRiskMoney > riskMoney * 1.25 + 0.01)
      GSLog(GS_LOG_WARN, StringFormat("actual risk %.2f is above planned %.2f after fill (slippage)",
                                      actualRiskMoney, riskMoney));

   SPosState state;
   ZeroMemory(state);
   state.ticket            = ticket;
   state.valid             = true;
   state.entry             = position.open;
   state.initialSL         = actualSL;
   state.riskMoney         = actualRiskMoney;
   state.initialRiskPoints = (g_sym.point > 0.0) ? MathAbs(position.open - actualSL) / g_sym.point : 0.0;
   state.opened            = TimeCurrent();
   state.beDone            = false;
   state.lastTrailSL       = 0.0;
   state.volumeAtEntry     = position.volume;
   state.foreignMod        = false;
   UpsertPosState(state);

   GSLog(GS_LOG_INFO, StringFormat("position opened #%I64u %.2f lot @ %s (requested %s), SL %s TP %s, risk %.2f",
                                   ticket, position.volume, PriceStr(fillPrice),
                                   PriceStr(entry), PriceStr(actualSL), PriceStr(tp), actualRiskMoney));
   LogTradeEvent("ENTRY", ticket, (signal.type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                 position.volume, position.open, actualSL, tp, actualRiskMoney, res.retcode, signal.note);

   // Safety net: if the broker did not keep the protective stop, attach it now.
   if(position.sl <= 0.0)
     {
      string attachErr;
      if(ModifyStops(ticket, sl, (position.tp > 0.0 ? position.tp : tp), attachErr, false))
        {
         GSLog(GS_LOG_WARN, StringFormat("#%I64u had no stop loss after fill - SL %s attached",
                                         ticket, PriceStr(sl)));
         state.initialSL = sl;
         state.initialRiskPoints = MathAbs(position.open - sl) / g_sym.point;
         SavePosState(state);
        }
      else
        {
         GSLog(GS_LOG_ERROR, StringFormat("#%I64u position has NO stop loss and attach failed: %s - manual attention required",
                                          ticket, attachErr));
        }
     }

   // Recalculate TP from the actual fill so the R:R stays correct after slippage.
   if(InpRR > 0.0 && position.open > 0.0 && MathAbs(position.open - entry) > g_sym.point * 0.5)
     {
      double actualRisk = MathAbs(position.open - sl);
      if(actualRisk > g_sym.point)
        {
         double correctedTP = (signal.type == ORDER_TYPE_BUY)
                              ? position.open + InpRR * actualRisk
                              : position.open - InpRR * actualRisk;
         if(MathAbs(correctedTP - tp) > (double)InpBEMinStepPoints * g_sym.point)
           {
            string adjustErr;
            if(ModifyStops(ticket, sl, correctedTP, adjustErr, true))
              {
               GSLog(GS_LOG_INFO, StringFormat("#%I64u TP adjusted to %s for actual fill %s",
                                               ticket, PriceStr(correctedTP), PriceStr(position.open)));
              }
            else
               GSLog(GS_LOG_WARN, StringFormat("#%I64u TP adjustment failed: %s", ticket, adjustErr));
           }
        }
     }

   return ENTRY_FILLED;
  }

void ProcessClosedBar(const datetime barTime)
  {
   if(g_lastEvalBar == barTime || g_lastEntryBar == barTime)
      return;

   if(g_cachedSigBar != barTime || !g_cachedSigDone)
     {
      g_cachedSigBar  = barTime;
      g_cachedSigDone = true;
      DetectSignal(g_cachedSig);

      if(g_cachedSig.valid)
        {
         GSLog(GS_LOG_INFO, StringFormat("signal %s on closed bar %s: %s",
                                         (g_cachedSig.type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                                         TimeStr(barTime), g_cachedSig.note));
        }
      else
        {
         GSLog(GS_LOG_DEBUG, StringFormat("no signal on bar %s: %s",
                                          TimeStr(barTime), g_cachedSig.note));
        }
     }

   if(!g_cachedSig.valid)
      return;

   int maxAttempts = 1 + (InpMaxRetriesPerBar > 0 ? InpMaxRetriesPerBar : 0);
   if(g_barAttempts >= maxAttempts)
     {
      if(g_lastEvalBar != barTime)
        {
         g_lastEvalBar       = barTime;
         g_state.lastEvalBar = barTime;
         SaveState(true);
         GSLog(GS_LOG_WARN, StringFormat("entry attempts exhausted (%d) for bar %s - signal skipped",
                                         g_barAttempts, TimeStr(barTime)));
        }
      return;
     }

   if(g_lastAttemptTime > 0 && (TimeCurrent() - g_lastAttemptTime) < InpRetryDelaySec)
      return;

   g_lastAttemptTime = TimeCurrent();
   g_barAttempts++;

   ENUM_ENTRY_RESULT result = TryEnter(g_cachedSig);

   if(result == ENTRY_FILLED)
     {
      g_lastEntryBar       = barTime;
      g_lastEvalBar        = barTime;
      g_state.lastEntryBar = barTime;
      g_state.lastEvalBar  = barTime;
      SaveState(true);
     }
   else
      if(result == ENTRY_SKIP)
        {
         g_lastEvalBar       = barTime;
         g_state.lastEvalBar = barTime;
         SaveState(true);
        }
  }

//+------------------------------------------------------------------+
//| 17. Input validation                                             |
//+------------------------------------------------------------------+
bool ValidateInputs()
  {
   bool ok = true;

   if(InpLogLevel < 0 || InpLogLevel > 3)
     {
      PrintFormat("[GoldSweepEA][ERR] InpLogLevel must be 0..3 (got %d)", InpLogLevel);
      return false;
     }

   if(InpMagic <= 0)
     { GSLog(GS_LOG_ERROR, "InpMagic must be > 0"); ok = false; }

   if(InpSweepLookback < 3 || InpSweepLookback > 500)
     { GSLog(GS_LOG_ERROR, StringFormat("InpSweepLookback must be 3..500 (got %d)", InpSweepLookback)); ok = false; }

   if(InpAtrPeriod < 2 || InpAtrPeriod > 500)
     { GSLog(GS_LOG_ERROR, StringFormat("InpAtrPeriod must be 2..500 (got %d)", InpAtrPeriod)); ok = false; }

   if(InpMinPenetrationATR < 0.0 || InpMinPenetrationATR > 10.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMinPenetrationATR must be 0..10 (got %.3f)", InpMinPenetrationATR)); ok = false; }

   if(InpReclaimBufferATR < 0.0 || InpReclaimBufferATR > 10.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpReclaimBufferATR must be 0..10 (got %.3f)", InpReclaimBufferATR)); ok = false; }

   if(InpMaxBarRangeATR < 0.0 || InpMaxBarRangeATR > 50.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMaxBarRangeATR must be 0..50 (got %.3f)", InpMaxBarRangeATR)); ok = false; }

   if(InpUseTrendFilter)
     {
      if(InpEmaFastPeriod < 1 || InpEmaFastPeriod > 1000)
        { GSLog(GS_LOG_ERROR, StringFormat("InpEmaFastPeriod must be 1..1000 (got %d)", InpEmaFastPeriod)); ok = false; }
      if(InpEmaSlowPeriod < 2 || InpEmaSlowPeriod > 2000)
        { GSLog(GS_LOG_ERROR, StringFormat("InpEmaSlowPeriod must be 2..2000 (got %d)", InpEmaSlowPeriod)); ok = false; }
      if(InpEmaFastPeriod >= InpEmaSlowPeriod)
        { GSLog(GS_LOG_ERROR, "InpEmaFastPeriod must be smaller than InpEmaSlowPeriod"); ok = false; }
     }

   if(PeriodSeconds(InpTrendTF) < PeriodSeconds(InpSignalTF))
     { GSLog(GS_LOG_ERROR, StringFormat("trend timeframe %s must be >= signal timeframe %s",
                                        TFToStr(InpTrendTF), TFToStr(InpSignalTF))); ok = false; }

   if(InpMinSLPoints < 1 || InpMinSLPoints > 100000)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMinSLPoints must be 1..100000 (got %d)", InpMinSLPoints)); ok = false; }

   if(InpMaxSLPoints < 0 || InpMaxSLPoints > 1000000)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMaxSLPoints must be 0..1000000 (got %d)", InpMaxSLPoints)); ok = false; }
   else
      if(InpMaxSLPoints > 0 && InpMaxSLPoints < InpMinSLPoints)
        { GSLog(GS_LOG_ERROR, "InpMaxSLPoints must be >= InpMinSLPoints (or 0 = off)"); ok = false; }

   if(InpRR < 0.0 || InpRR > 1000.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpRR must be 0..1000 (got %.3f)", InpRR)); ok = false; }

   if(InpRiskBufferPct < 0.0 || InpRiskBufferPct > 200.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpRiskBufferPct must be 0..200 (got %.2f)", InpRiskBufferPct)); ok = false; }

   if(InpCommissionPerLotRT < 0.0 || InpCommissionPerLotRT > 100000.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpCommissionPerLotRT must be 0..100000 (got %.2f)", InpCommissionPerLotRT)); ok = false; }

   if(InpRiskMode != GS_RISK_PERCENT && InpRiskMode != GS_RISK_FIXED_LOT)
     { GSLog(GS_LOG_ERROR, "InpRiskMode has an unknown value"); ok = false; }

   if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpRiskPercent must be 0..10 (got %.3f)", InpRiskPercent)); ok = false; }
   else
      if(InpRiskPercent > 2.0)
         GSLog(GS_LOG_WARN, StringFormat("InpRiskPercent %.2f%% is aggressive for a single trade", InpRiskPercent));

   if(InpFixedLot <= 0.0 || InpFixedLot > 10000.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpFixedLot must be 0..10000 (got %.3f)", InpFixedLot)); ok = false; }

   if(InpMaxRiskMult < 0.0 || InpMaxRiskMult > 10.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMaxRiskMult must be 0..10 (got %.2f)", InpMaxRiskMult)); ok = false; }

   if(InpMaxDailyLossPct < 0.0 || InpMaxDailyLossPct > 100.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMaxDailyLossPct must be 0..100 (got %.2f)", InpMaxDailyLossPct)); ok = false; }

   if(InpMaxDrawdownPct < 0.0 || InpMaxDrawdownPct > 100.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMaxDrawdownPct must be 0..100 (got %.2f)", InpMaxDrawdownPct)); ok = false; }

   if(InpMaxOpenRiskPct < 0.0 || InpMaxOpenRiskPct > 100.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMaxOpenRiskPct must be 0..100 (got %.2f)", InpMaxOpenRiskPct)); ok = false; }

   if(InpMinFreeMarginPct < 0.0 || InpMinFreeMarginPct > 100.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMinFreeMarginPct must be 0..100 (got %.2f)", InpMinFreeMarginPct)); ok = false; }

   if(InpLossScope != GS_SCOPE_EA && InpLossScope != GS_SCOPE_ACCOUNT)
     { GSLog(GS_LOG_ERROR, "InpLossScope has an unknown value"); ok = false; }

   if(InpMaxPositions < 1 || InpMaxPositions > 50)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMaxPositions must be 1..50 (got %d)", InpMaxPositions)); ok = false; }

   if(InpMaxTradesPerDay < 0 || InpMaxTradesPerDay > 1000)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMaxTradesPerDay must be 0..1000 (got %d)", InpMaxTradesPerDay)); ok = false; }

   if(InpCooldownLossMin < 0 || InpCooldownLossMin > 10080)
     { GSLog(GS_LOG_ERROR, StringFormat("InpCooldownLossMin must be 0..10080 (got %d)", InpCooldownLossMin)); ok = false; }

   if(InpCooldownWinMin < 0 || InpCooldownWinMin > 10080)
     { GSLog(GS_LOG_ERROR, StringFormat("InpCooldownWinMin must be 0..10080 (got %d)", InpCooldownWinMin)); ok = false; }

   if(InpMaxSpreadPoints < 0 || InpMaxSpreadPoints > 100000)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMaxSpreadPoints must be 0..100000 (got %d)", InpMaxSpreadPoints)); ok = false; }

   if(InpSessionStartHour < 0 || InpSessionStartHour > 23 ||
      InpSessionEndHour   < 0 || InpSessionEndHour   > 23 ||
      InpSessionStartMin  < 0 || InpSessionStartMin  > 59 ||
      InpSessionEndMin    < 0 || InpSessionEndMin    > 59)
     { GSLog(GS_LOG_ERROR, "session hour must be 0..23 and minute 0..59"); ok = false; }

   if(InpSessionShiftHours < -12 || InpSessionShiftHours > 12)
     { GSLog(GS_LOG_ERROR, StringFormat("InpSessionShiftHours must be -12..12 (got %d)", InpSessionShiftHours)); ok = false; }

   if(InpFridayCutHour < 0 || InpFridayCutHour > 23 || InpFridayCutMin < 0 || InpFridayCutMin > 59)
     { GSLog(GS_LOG_ERROR, "Friday cutoff hour/minute invalid"); ok = false; }

   if(InpFillingMode != GS_FILL_AUTO && InpFillingMode != GS_FILL_FOK &&
      InpFillingMode != GS_FILL_IOC && InpFillingMode != GS_FILL_RETURN)
     { GSLog(GS_LOG_ERROR, "InpFillingMode has an unknown value"); ok = false; }

   if(InpDeviationPoints < 0 || InpDeviationPoints > 100000)
     { GSLog(GS_LOG_ERROR, StringFormat("InpDeviationPoints must be 0..100000 (got %d)", InpDeviationPoints)); ok = false; }

   if(InpMaxRetriesPerBar < 0 || InpMaxRetriesPerBar > 50)
     { GSLog(GS_LOG_ERROR, StringFormat("InpMaxRetriesPerBar must be 0..50 (got %d)", InpMaxRetriesPerBar)); ok = false; }

   if(InpRetryDelaySec < 0 || InpRetryDelaySec > 3600)
     { GSLog(GS_LOG_ERROR, StringFormat("InpRetryDelaySec must be 0..3600 (got %d)", InpRetryDelaySec)); ok = false; }

   if(InpBEStartR < 0.0 || InpBEStartR > 100.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpBEStartR must be 0..100 (got %.2f)", InpBEStartR)); ok = false; }

   if(InpBELockR < 0.0 || InpBELockR > 100.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpBELockR must be 0..100 (got %.2f)", InpBELockR)); ok = false; }

   if(InpBEMinStepPoints < 0 || InpBEMinStepPoints > 100000)
     { GSLog(GS_LOG_ERROR, StringFormat("InpBEMinStepPoints must be 0..100000 (got %d)", InpBEMinStepPoints)); ok = false; }

   if(InpTrailStartR < 0.0 || InpTrailStartR > 100.0)
     { GSLog(GS_LOG_ERROR, StringFormat("InpTrailStartR must be 0..100 (got %.2f)", InpTrailStartR)); ok = false; }

   if(InpUseTrailing && (InpTrailDistR <= 0.0 || InpTrailDistR > 100.0))
     { GSLog(GS_LOG_ERROR, StringFormat("InpTrailDistR must be 0..100 when trailing is enabled (got %.2f)", InpTrailDistR)); ok = false; }

   if(InpTrailMinStepPoints < 0 || InpTrailMinStepPoints > 100000)
     { GSLog(GS_LOG_ERROR, StringFormat("InpTrailMinStepPoints must be 0..100000 (got %d)", InpTrailMinStepPoints)); ok = false; }

   if(InpTimeExitBars < 0 || InpTimeExitBars > 10000)
     { GSLog(GS_LOG_ERROR, StringFormat("InpTimeExitBars must be 0..10000 (got %d)", InpTimeExitBars)); ok = false; }

   if(InpSignalTF == PERIOD_M1 || InpSignalTF == PERIOD_M5)
      GSLog(GS_LOG_WARN, StringFormat("signal timeframe %s is very fast for XAUUSD; spread/slippage will dominate",
                                      TFToStr(InpSignalTF)));

   if(InpMaxDailyLossPct <= 0.0)
      GSLog(GS_LOG_WARN, "InpMaxDailyLossPct = 0 - daily loss hard stop is DISABLED");

   if(InpMaxDrawdownPct <= 0.0)
      GSLog(GS_LOG_WARN, "InpMaxDrawdownPct = 0 - equity drawdown protection is DISABLED");

   if(InpUseSession && InpSessionStartHour == InpSessionEndHour && InpSessionStartMin == InpSessionEndMin)
      GSLog(GS_LOG_INFO, "session start == end -> 24-hour session window");

   if(!ok)
      GSLog(GS_LOG_ERROR, "input validation failed - EA will not start");

   return ok;
  }

bool LooksLikeGoldSymbol()
  {
   string sym = _Symbol;
   StringToUpper(sym);
   return (StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0);
  }

string MarginModeText()
  {
   ENUM_ACCOUNT_MARGIN_MODE mode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return "HEDGING";
   if(mode == ACCOUNT_MARGIN_MODE_EXCHANGE)
      return "EXCHANGE-NETTING";
   return "RETAIL-NETTING";
  }

string TradeModeText()
  {
   ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode == ACCOUNT_TRADE_MODE_DEMO)
      return "DEMO";
   if(mode == ACCOUNT_TRADE_MODE_CONTEST)
      return "CONTEST";
   if(mode == ACCOUNT_TRADE_MODE_REAL)
      return "REAL";
   return "UNKNOWN";
  }

//+------------------------------------------------------------------+
//| 18. Dashboard                                                    |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   if(!InpShowDashboard || MQLInfoInteger(MQL_OPTIMIZATION))
     {
      if(g_dashboard != "")
        {
         Comment("");
         g_dashboard = "";
        }
      return;
     }

   datetime now = TimeCurrent();
   if(now == g_dashboardAt)
      return;
   g_dashboardAt = now;

   SDailyStats stats;
   ComputeDailyStats(stats, false);

   int trendDirection = 0;
   string trendText = "n/a";
   ReadTrend(trendDirection, trendText);

   double atr = CurrentATR();
   double spread = CurrentSpreadPoints();
   int positions = OurPositionsCount();

   string status = "OK";
   if(g_state.hardLocked)
      status = "HARD LOCK";
   else
      if(g_state.dailyLocked && g_state.dayKey == DayKey(now))
         status = "DAILY LOCK";

   string text = "";
   text += StringFormat("GoldSweepEA %s  |  %s %s  |  %s  |  magic %I64d\n",
                        GS_EA_VERSION, _Symbol, TFToStr(InpSignalTF), MarginModeText(), InpMagic);
   string spreadLimit = (InpMaxSpreadPoints > 0) ? StringFormat("%d", InpMaxSpreadPoints) : "off";
   string entryLimit  = (InpMaxTradesPerDay > 0) ? StringFormat("%d", InpMaxTradesPerDay) : "inf";

   text += StringFormat("Server %s  |  session %s  |  spread %.0f/%s pts  |  ATR %.0f pts  |  %s\n",
                        TimeToString(now, TIME_DATE | TIME_MINUTES), SessionStatusText(),
                        spread, spreadLimit,
                        (g_sym.point > 0.0 ? atr / g_sym.point : 0.0), trendText);
   text += StringFormat("Equity %.2f  |  balance %.2f  |  floating %.2f  |  day loss %.2f%% (limit %.2f%%)\n",
                        stats.equity, stats.balance, stats.floating, stats.lossPct, InpMaxDailyLossPct);
   text += StringFormat("Entries today %d/%s  |  positions %d/%d  |  open risk %.2f  |  status: %s\n",
                        stats.entriesToday, entryLimit, positions, InpMaxPositions,
                        OurOpenRiskMoney(), status);
   text += StringFormat("Last error: %s (%s)",
                        (g_lastErrorMsg == "" ? "none" : g_lastErrorMsg), TimeStr(g_lastErrorTime));

   Comment(text);
   g_dashboard = text;
  }

//+------------------------------------------------------------------+
//| 19. Event handlers                                               |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_ready  = false;
   g_dryRun = InpDryRun;

   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   bool isTester = (bool)MQLInfoInteger(MQL_TESTER);
   bool isReal   = ((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL);

   if(isReal && !InpEnableLiveTrading && !isTester)
     {
      GSLog(GS_LOG_ERROR, "REAL account detected and InpEnableLiveTrading=false. EA refuses to start. Use a demo account first.");
      return INIT_FAILED;
     }

   if(!RefreshSymbolSpec())
      return INIT_FAILED;

   if(!RefreshTick())
      GSLog(GS_LOG_WARN, "no valid tick at startup - will retry on every tick");

   // Each Strategy Tester run must start clean: state files are live/demo only.
   g_persistActive = (InpPersistState && !MQLInfoInteger(MQL_TESTER));
   if(InpPersistState && !g_persistActive)
      GSLog(GS_LOG_INFO, "tester: state persistence disabled for this run (isolated backtest)");

   LoadState();

   if(InpResetState)
     {
      InitStateDefaults();

      SPosRef resetList[];
      int resetCount = CollectPositions(resetList, true);
      for(int i = 0; i < resetCount; i++)
         DeletePosState(resetList[i].ticket);

      SaveState(true);
      GSLog(GS_LOG_INFO, "saved state ignored and reset (InpResetState=true)");
     }

   if(!InitIndicators())
      return INIT_FAILED;

   ReconcilePosStates();
   InvalidateStats();
   DeleteOurPendingOrders();   // this EA uses market orders only: clean any leftovers

   g_lastEvalBar  = g_state.lastEvalBar;
   g_lastEntryBar = g_state.lastEntryBar;

   datetime closedBar = ClosedBarTime();
   g_lastSeenBar = closedBar;

   // Attach policy: never execute a signal of a bar that closed before startup.
   if(closedBar > 0 && g_state.lastEvalBar != closedBar)
     {
      g_state.lastEvalBar = closedBar;
      g_lastEvalBar       = closedBar;
      SaveState(true);
      GSLog(GS_LOG_INFO, StringFormat("attach policy: skipping the bar closed at %s (no stale signal execution)",
                                      TimeStr(closedBar)));
     }

   EventSetTimer(1);
   g_ready = true;

   PrintFormat("[GoldSweepEA] ===== v%s starting (build %d) =====", GS_EA_VERSION, (int)TerminalInfoInteger(TERMINAL_BUILD));
   PrintFormat("[GoldSweepEA] symbol=%s digits=%d point=%.5f tickSize=%.5f tickValue=%.5f contract=%.2f",
               _Symbol, g_sym.digits, g_sym.point, g_sym.tickSize, g_sym.tickValue, g_sym.contractSize);
   PrintFormat("[GoldSweepEA] volume min=%.2f step=%.3f max=%.2f (digits=%d) stops=%I64d freeze=%I64d fillingMask=%I64d",
               g_sym.volMin, g_sym.volStep, g_sym.volMax, g_sym.volDigits,
               g_sym.stopsLevel, g_sym.freezeLevel, g_sym.fillingMode);
   if(g_tickValid)
      PrintFormat("[GoldSweepEA] spread=%.0f points | bid=%s ask=%s (checked against InpMaxSpreadPoints=%d)",
                  CurrentSpreadPoints(), PriceStr(g_tick.bid), PriceStr(g_tick.ask), InpMaxSpreadPoints);
   PrintFormat("[GoldSweepEA] account=%I64d %s | %s | %s | leverage 1:%I64d | currency=%s",
               AccountInfoInteger(ACCOUNT_LOGIN), AccountInfoString(ACCOUNT_COMPANY),
               TradeModeText(), MarginModeText(), AccountInfoInteger(ACCOUNT_LEVERAGE),
               AccountInfoString(ACCOUNT_CURRENCY));
   PrintFormat("[GoldSweepEA] signalTF=%s trendTF=%s risk=%.2f%% dailyLimit=%.2f%% maxDD=%.2f%% magic=%I64d dryRun=%s",
               TFToStr(InpSignalTF), TFToStr(InpTrendTF), InpRiskPercent,
               InpMaxDailyLossPct, InpMaxDrawdownPct, InpMagic, BoolStr(InpDryRun));
   PrintFormat("[GoldSweepEA] server=%s | GMT=%s | local=%s",
               TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
               TimeToString(TimeGMT(), TIME_DATE | TIME_SECONDS),
               TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS));

   if(!LooksLikeGoldSymbol())
      GSLog(GS_LOG_WARN, StringFormat("symbol %s does not look like gold (XAU/GOLD) - verify the chart", _Symbol));

   if(!InpUseSession)
      GSLog(GS_LOG_INFO, "session filter is OFF (Friday cutoff is independent and still applies)");

   if(g_sym.stopsLevel > 0)
      GSLog(GS_LOG_INFO, StringFormat("broker minimum stop distance: %I64d points (%.2f price units)",
                                      g_sym.stopsLevel, (double)g_sym.stopsLevel * g_sym.point));

   if(g_sym.digits != 2)
      GSLog(GS_LOG_WARN, StringFormat("symbol has %d digits (point=%.5f): point-based inputs (SL/spread/deviation) are calibrated for 2-digit XAUUSD - rescale them",
                                      g_sym.digits, g_sym.point));

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ReleaseIndicators();
   if(g_ready)
      SaveState(true);
   g_ready = false;

   if(InpShowDashboard)
      Comment("");

   PrintFormat("[GoldSweepEA] stopped (reason=%d) equity=%.2f balance=%.2f dayLoss=%.2f%%",
               reason, AccountInfoDouble(ACCOUNT_EQUITY), AccountInfoDouble(ACCOUNT_BALANCE),
               g_stats.lossPct);
  }

void OnTick()
  {
   if(!g_ready || IsStopped())
      return;

   if(!RefreshTick())
      return;

   EvaluateGuards();
   ManagePositions();

   datetime barTime = ClosedBarTime();
   if(barTime <= 0)
      return;

   if(barTime != g_lastSeenBar)
     {
      g_lastSeenBar     = barTime;
      g_barAttempts     = 0;
      g_lastAttemptTime = 0;
      g_cachedSigDone   = false;
     }

   if(!InpEnableTrading)
      return;

   ProcessClosedBar(barTime);
  }

void OnTimer()
  {
   if(!g_ready || IsStopped())
      return;

   if(!RefreshTick())
     {
      UpdateDashboard();
      return;
     }

   EvaluateGuards();
   ManagePositions();
   UpdateDashboard();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(!g_ready)
      return;

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      InvalidateStats();

      if(HistoryDealSelect(trans.deal))
        {
         long   magic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         string sym   = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
         long   dtype = (long)HistoryDealGetInteger(trans.deal, DEAL_TYPE);

         // Deposits/withdrawals must not look like a drawdown or a daily loss.
         if(dtype == DEAL_TYPE_BALANCE || dtype == DEAL_TYPE_BONUS)
           {
            double amount = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            if(MathAbs(amount) > 0.0)
              {
               if(amount < 0.0)
                  g_state.hwmEquity += amount;
               else
                  g_state.hwmEquity = MathMax(g_state.hwmEquity, AccountInfoDouble(ACCOUNT_EQUITY));

               if(g_state.hwmEquity <= 0.0)
                  g_state.hwmEquity = AccountInfoDouble(ACCOUNT_EQUITY);

               g_state.hwmTime = TimeCurrent();
               SaveState(true);
               GSLog(GS_LOG_INFO, StringFormat("external flow %.2f adjusted equity HWM to %.2f",
                                               amount, g_state.hwmEquity));
              }
           }

         if(sym == _Symbol && magic == InpMagic)
           {
            long dealEntry = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            GSLog(GS_LOG_INFO, StringFormat("deal #%I64u entry=%I64d volume=%.2f price=%s profit=%.2f swap=%.2f",
                                            trans.deal, dealEntry,
                                            HistoryDealGetDouble(trans.deal, DEAL_VOLUME),
                                            PriceStr(HistoryDealGetDouble(trans.deal, DEAL_PRICE)),
                                            HistoryDealGetDouble(trans.deal, DEAL_PROFIT),
                                            HistoryDealGetDouble(trans.deal, DEAL_SWAP)));

            if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY ||
               dealEntry == DEAL_ENTRY_INOUT)
               DeleteStalePosState(trans.position);
           }
        }
     }
   else
      if(trans.type == TRADE_TRANSACTION_POSITION)
         InvalidateStats();
  }
//+------------------------------------------------------------------+
