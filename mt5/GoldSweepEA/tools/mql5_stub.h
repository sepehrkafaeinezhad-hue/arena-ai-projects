// Minimal MQL5 -> C++17 stub SHIM, used ONLY for -fsyntax-only checks.
// It is not a runtime emulation and must never be shipped with the EA.
#pragma once
#include <cstdio>
#include <cstring>
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <string>
#include <vector>
#include <iostream>
#include <type_traits>

typedef long long      datetime;
typedef unsigned int   uint;
typedef unsigned short ushort;
typedef unsigned char  uchar;
typedef signed char    schar;
typedef long long      long64;
typedef unsigned long long ulong64;
#define ulong unsigned long long

// ---------------------------------------------------------------- string
struct MqlStr
{
   char data[512];
   MqlStr() { data[0] = '\0'; }
   MqlStr(const char *s) { set(s); }
   MqlStr(char c) { data[0] = c; data[1] = '\0'; }
   void set(const char *s) { if(!s) { data[0] = '\0'; return; } std::snprintf(data, sizeof(data), "%s", s); }
   const char *c_str() const { return data; }
   int size() const { return (int)std::strlen(data); }
};
typedef MqlStr string;

inline bool operator==(const MqlStr &a, const MqlStr &b) { return std::strcmp(a.data, b.data) == 0; }
inline bool operator==(const MqlStr &a, const char *b)   { return std::strcmp(a.data, b ? b : "") == 0; }
inline bool operator==(const char *a, const MqlStr &b)   { return std::strcmp(a ? a : "", b.data) == 0; }
inline bool operator!=(const MqlStr &a, const MqlStr &b) { return !(a == b); }
inline bool operator!=(const MqlStr &a, const char *b)   { return !(a == b); }
inline bool operator!=(const char *a, const MqlStr &b)   { return !(a == b); }
inline bool operator<(const MqlStr &a, const MqlStr &b)  { return std::strcmp(a.data, b.data) < 0; }

inline MqlStr operator+(const MqlStr &a, const MqlStr &b)
{ MqlStr r; std::snprintf(r.data, sizeof(r.data), "%s%s", a.data, b.data); return r; }
inline MqlStr operator+(const MqlStr &a, const char *b)
{ MqlStr r; std::snprintf(r.data, sizeof(r.data), "%s%s", a.data, b ? b : ""); return r; }
inline MqlStr operator+(const char *a, const MqlStr &b)
{ MqlStr r; std::snprintf(r.data, sizeof(r.data), "%s%s", a ? a : "", b.data); return r; }
template<typename T, typename = std::enable_if_t<std::is_arithmetic_v<T>>>
inline MqlStr operator+(const MqlStr &a, const T &v)
{ MqlStr r; std::snprintf(r.data, sizeof(r.data), "%s%s", a.data, std::to_string(v).c_str()); return r; }
inline MqlStr &operator+=(MqlStr &a, const MqlStr &b) { a = a + b; return a; }
inline MqlStr &operator+=(MqlStr &a, const char *b)   { a = a + b; return a; }
template<typename T, typename = std::enable_if_t<std::is_arithmetic_v<T>>>
inline MqlStr &operator+=(MqlStr &a, const T &v) { a = a + v; return a; }
inline std::ostream &operator<<(std::ostream &os, const MqlStr &s) { return os << s.data; }
inline bool operator<(const MqlStr &a, const char *b) { return std::strcmp(a.data, b) < 0; }

// ---------------------------------------------------------------- structs
struct MqlDateTime { int year, mon, day, hour, min, sec, day_of_week, day_of_year; };
struct MqlTick { datetime time; double bid, ask, last; uint volume; long time_msc; uint flags; double volume_real; };
struct MqlRates { datetime time; double open, high, low, close; long tick_volume; int spread; long real_volume; };

struct MqlTradeRequest
{
   int action; ulong magic; ulong order; MqlStr symbol; double volume; double price; double stoplimit;
   double sl; double tp; ulong deviation; int type; int type_filling; int type_time; datetime expiration;
   MqlStr comment; ulong position; ulong position_by;
};
struct MqlTradeResult
{
   uint retcode; ulong deal; ulong order; double volume; double price; double bid; double ask;
   MqlStr comment; uint request_id; int retcode_external;
};
struct MqlTradeCheckResult
{
   uint retcode; double balance; double equity; double profit; double margin; double margin_free;
   double margin_level; MqlStr comment;
};
struct MqlTradeTransaction
{
   ulong deal; ulong order; MqlStr symbol; int type; int order_type; long order_state; int deal_type;
   int time_type; datetime time_expiration; double price; double price_trigger; double price_sl; double price_tp;
   double volume; ulong position; ulong position_by;
};

// ---------------------------------------------------------------- enums
enum ENUM_TIMEFRAMES
{
   PERIOD_CURRENT = 0, PERIOD_M1 = 1, PERIOD_M5 = 5, PERIOD_M15 = 15, PERIOD_M30 = 30,
   PERIOD_H1 = 16385, PERIOD_H2 = 16386, PERIOD_H3 = 16387, PERIOD_H4 = 16388,
   PERIOD_H6 = 16390, PERIOD_H8 = 16392, PERIOD_H12 = 16396, PERIOD_D1 = 16408,
   PERIOD_W1 = 32769, PERIOD_MN1 = 49153
};
enum ENUM_MA_METHOD { MODE_SMA = 0, MODE_EMA = 1, MODE_SMMA = 2, MODE_LWMA = 3 };
enum ENUM_APPLIED_PRICE { PRICE_CLOSE = 1, PRICE_OPEN = 2, PRICE_HIGH = 3, PRICE_LOW = 4,
                          PRICE_MEDIAN = 5, PRICE_TYPICAL = 6, PRICE_WEIGHTED = 7 };
enum ENUM_ORDER_TYPE
{
   ORDER_TYPE_BUY = 0, ORDER_TYPE_SELL = 1, ORDER_TYPE_BUY_LIMIT = 2, ORDER_TYPE_SELL_LIMIT = 3,
   ORDER_TYPE_BUY_STOP = 4, ORDER_TYPE_SELL_STOP = 5, ORDER_TYPE_BUY_STOP_LIMIT = 6,
   ORDER_TYPE_SELL_STOP_LIMIT = 7, ORDER_TYPE_CLOSE_BY = 8
};
enum ENUM_ORDER_TYPE_FILLING { ORDER_FILLING_FOK = 0, ORDER_FILLING_IOC = 1, ORDER_FILLING_RETURN = 2, ORDER_FILLING_BOC = 3 };
enum ENUM_ORDER_TYPE_TIME { ORDER_TIME_GTC = 0, ORDER_TIME_DAY = 1, ORDER_TIME_SPECIFIED = 2, ORDER_TIME_SPECIFIED_DAY = 3 };
enum ENUM_POSITION_TYPE { POSITION_TYPE_BUY = 0, POSITION_TYPE_SELL = 1 };
enum ENUM_DEAL_TYPE
{
   DEAL_TYPE_BUY = 0, DEAL_TYPE_SELL = 1, DEAL_TYPE_BALANCE = 2, DEAL_TYPE_CREDIT = 3,
   DEAL_TYPE_CHARGE = 4, DEAL_TYPE_CORRECTION = 5, DEAL_TYPE_BONUS = 6, DEAL_TYPE_COMMISSION = 7,
   DEAL_TYPE_INTEREST = 14
};
enum ENUM_DEAL_ENTRY { DEAL_ENTRY_IN = 0, DEAL_ENTRY_OUT = 1, DEAL_ENTRY_INOUT = 2, DEAL_ENTRY_OUT_BY = 3 };
enum ENUM_TRADE_REQUEST_ACTIONS
{
   TRADE_ACTION_DEAL = 1, TRADE_ACTION_PENDING = 5, TRADE_ACTION_SLTP = 6, TRADE_ACTION_MODIFY = 7,
   TRADE_ACTION_REMOVE = 8, TRADE_ACTION_CLOSE_BY = 10
};
enum ENUM_TRADE_TRANSACTION_TYPE
{
   TRADE_TRANSACTION_ORDER_ADD = 0, TRADE_TRANSACTION_ORDER_UPDATE = 1, TRADE_TRANSACTION_ORDER_DELETE = 2,
   TRADE_TRANSACTION_DEAL_ADD = 3, TRADE_TRANSACTION_DEAL_UPDATE = 4, TRADE_TRANSACTION_DEAL_DELETE = 5,
   TRADE_TRANSACTION_POSITION = 6
};
enum ENUM_SYMBOL_INFO_DOUBLE
{
   SYMBOL_BID = 0, SYMBOL_ASK = 1, SYMBOL_POINT = 2, SYMBOL_TRADE_TICK_SIZE = 3,
   SYMBOL_TRADE_TICK_VALUE = 4, SYMBOL_TRADE_CONTRACT_SIZE = 5, SYMBOL_VOLUME_MIN = 6,
   SYMBOL_VOLUME_MAX = 7, SYMBOL_VOLUME_STEP = 8, SYMBOL_SPREAD_FLOAT = 9
};
enum ENUM_SYMBOL_INFO_INTEGER
{
   SYMBOL_DIGITS = 0, SYMBOL_SPREAD = 1, SYMBOL_TRADE_STOPS_LEVEL = 2, SYMBOL_TRADE_FREEZE_LEVEL = 3,
   SYMBOL_FILLING_MODE = 4, SYMBOL_TRADE_MODE = 5, SYMBOL_TRADE_EXEMODE = 6
};
enum ENUM_SYMBOL_INFO_STRING { SYMBOL_NAME = 0, SYMBOL_DESCRIPTION = 1, SYMBOL_CURRENCY_BASE = 2, SYMBOL_CURRENCY_PROFIT = 3 };
enum ENUM_SYMBOL_TRADE_MODE
{
   SYMBOL_TRADE_MODE_DISABLED = 0, SYMBOL_TRADE_MODE_LONGONLY = 1, SYMBOL_TRADE_MODE_SHORTONLY = 2,
   SYMBOL_TRADE_MODE_CLOSEONLY = 3, SYMBOL_TRADE_MODE_FULL = 4
};
enum ENUM_POSITION_PROPERTY_DOUBLE
{
   POSITION_VOLUME = 0, POSITION_PRICE_OPEN = 1, POSITION_SL = 2, POSITION_TP = 3,
   POSITION_PRICE_CURRENT = 4, POSITION_SWAP = 5, POSITION_PROFIT = 6
};
enum ENUM_POSITION_PROPERTY_INTEGER
{
   POSITION_TIME = 0, POSITION_TYPE = 1, POSITION_MAGIC = 2, POSITION_TICKET = 3,
   POSITION_TIME_MSC = 4, POSITION_TIME_UPDATE = 5, POSITION_IDENTIFIER = 6
};
enum ENUM_POSITION_PROPERTY_STRING { POSITION_SYMBOL = 0, POSITION_COMMENT = 1, POSITION_EXTERNAL_ID = 2 };
enum ENUM_DEAL_PROPERTY_INTEGER { DEAL_ORDER = 0, DEAL_TIME = 1, DEAL_TYPE = 2, DEAL_ENTRY = 3, DEAL_MAGIC = 4, DEAL_POSITION_ID = 5 };
enum ENUM_DEAL_PROPERTY_DOUBLE { DEAL_VOLUME = 0, DEAL_PRICE = 1, DEAL_COMMISSION = 2, DEAL_SWAP = 3,
                                 DEAL_PROFIT = 4, DEAL_FEE = 5 };
enum ENUM_DEAL_PROPERTY_STRING { DEAL_SYMBOL = 0, DEAL_COMMENT = 1, DEAL_EXTERNAL_ID = 2 };
enum ENUM_ORDER_PROPERTY_INTEGER { ORDER_TICKET = 0, ORDER_TIME_SETUP = 1, ORDER_TYPE = 2, ORDER_MAGIC = 3 };
enum ENUM_ORDER_PROPERTY_STRING { ORDER_SYMBOL = 0, ORDER_COMMENT = 1 };
enum ENUM_ACCOUNT_MARGIN_MODE
{
   ACCOUNT_MARGIN_MODE_RETAIL_NETTING = 0, ACCOUNT_MARGIN_MODE_EXCHANGE = 1, ACCOUNT_MARGIN_MODE_RETAIL_HEDGING = 2
};
enum ENUM_ACCOUNT_TRADE_MODE { ACCOUNT_TRADE_MODE_DEMO = 0, ACCOUNT_TRADE_MODE_CONTEST = 1, ACCOUNT_TRADE_MODE_REAL = 2 };
enum ENUM_ACCOUNT_INFO_DOUBLE { ACCOUNT_BALANCE = 0, ACCOUNT_CREDIT = 1, ACCOUNT_PROFIT = 2, ACCOUNT_EQUITY = 3,
                                ACCOUNT_MARGIN = 4, ACCOUNT_MARGIN_FREE = 5, ACCOUNT_MARGIN_LEVEL = 6 };
enum ENUM_ACCOUNT_INFO_INTEGER { ACCOUNT_LOGIN = 0, ACCOUNT_LEVERAGE = 1, ACCOUNT_TRADE_MODE = 2,
                                 ACCOUNT_TRADE_ALLOWED = 3, ACCOUNT_TRADE_EXPERT = 4, ACCOUNT_MARGIN_MODE = 5 };
enum ENUM_ACCOUNT_INFO_STRING { ACCOUNT_NAME = 0, ACCOUNT_SERVER = 1, ACCOUNT_CURRENCY = 2, ACCOUNT_COMPANY = 3 };
enum ENUM_TERMINAL_INFO_INTEGER { TERMINAL_CONNECTED = 0, TERMINAL_TRADE_ALLOWED = 1, TERMINAL_BUILD = 2 };
enum ENUM_MQL_INFO_INTEGER { MQL_PROGRAM_TYPE = 0, MQL_TRADE_ALLOWED = 1, MQL_TESTER = 2, MQL_OPTIMIZATION = 3 };

// ---------------------------------------------------------------- constants
const int INVALID_HANDLE = -1;
const int INIT_SUCCEEDED = 0;
const int INIT_FAILED = 1;
const int INIT_PARAMETERS_INCORRECT = 2;

const int FILE_READ = 1, FILE_WRITE = 2, FILE_BIN = 4, FILE_CSV = 8, FILE_TXT = 16, FILE_ANSI = 32,
          FILE_UNICODE = 64, FILE_SHARE_READ = 128, FILE_SHARE_WRITE = 256, FILE_COMMON = 4096;
const int TIME_DATE = 1, TIME_MINUTES = 2, TIME_SECONDS = 4;

const int SYMBOL_FILLING_FOK = 1;
const int SYMBOL_FILLING_IOC = 2;

const uint TRADE_RETCODE_REQUOTE = 10004;
const uint TRADE_RETCODE_REJECT = 10006;
const uint TRADE_RETCODE_CANCEL = 10007;
const uint TRADE_RETCODE_PLACED = 10008;
const uint TRADE_RETCODE_DONE = 10009;
const uint TRADE_RETCODE_DONE_PARTIAL = 10010;
const uint TRADE_RETCODE_ERROR = 10011;
const uint TRADE_RETCODE_TIMEOUT = 10012;
const uint TRADE_RETCODE_INVALID = 10013;
const uint TRADE_RETCODE_INVALID_VOLUME = 10014;
const uint TRADE_RETCODE_INVALID_PRICE = 10015;
const uint TRADE_RETCODE_INVALID_STOPS = 10016;
const uint TRADE_RETCODE_TRADE_DISABLED = 10017;
const uint TRADE_RETCODE_MARKET_CLOSED = 10018;
const uint TRADE_RETCODE_NO_MONEY = 10019;
const uint TRADE_RETCODE_PRICE_CHANGED = 10020;
const uint TRADE_RETCODE_PRICE_OFF = 10021;
const uint TRADE_RETCODE_INVALID_EXPIRATION = 10022;
const uint TRADE_RETCODE_ORDER_CHANGED = 10023;
const uint TRADE_RETCODE_TOO_MANY_REQUESTS = 10024;
const uint TRADE_RETCODE_NO_CHANGES = 10025;
const uint TRADE_RETCODE_SERVER_DISABLES_AT = 10026;
const uint TRADE_RETCODE_CLIENT_DISABLES_AT = 10027;
const uint TRADE_RETCODE_LOCKED = 10028;
const uint TRADE_RETCODE_FROZEN = 10029;
const uint TRADE_RETCODE_INVALID_FILL = 10030;
const uint TRADE_RETCODE_CONNECTION = 10031;
const uint TRADE_RETCODE_ONLY_REAL = 10032;
const uint TRADE_RETCODE_LIMIT_ORDERS = 10033;
const uint TRADE_RETCODE_LIMIT_VOLUME = 10034;
const uint TRADE_RETCODE_INVALID_ORDER = 10035;
const uint TRADE_RETCODE_POSITION_CLOSED = 10036;
const uint TRADE_RETCODE_INVALID_CLOSE_VOLUME = 10038;
const uint TRADE_RETCODE_CLOSE_ORDER_EXIST = 10039;
const uint TRADE_RETCODE_LIMIT_POSITIONS = 10040;
const uint TRADE_RETCODE_REJECT_CANCEL = 10041;
const uint TRADE_RETCODE_LONG_ONLY = 10042;
const uint TRADE_RETCODE_SHORT_ONLY = 10043;
const uint TRADE_RETCODE_CLOSE_ONLY = 10044;
const uint TRADE_RETCODE_FIFO_CLOSE = 10045;
const uint TRADE_RETCODE_HEDGE_PROHIBITED = 10046;

// ---------------------------------------------------------------- arrays
template<typename T>
struct MqlArray
{
   std::vector<T> v;
   T &operator[](int i) { return v[(size_t)i]; }
   const T &operator[](int i) const { return v[(size_t)i]; }
   bool resize(int n) { v.resize((size_t)n); return true; }
   void clear() { v.clear(); }
   int size() const { return (int)v.size(); }
   void setAsSeries(bool) {}
};

inline void ArraySetAsSeriesImpl() {}

// ---------------------------------------------------------------- globals
static MqlStr _Symbol("XAUUSD");
static MqlStr _CommentText;

// ---------------------------------------------------------------- math
template<typename T> inline T MathAbs(T v) { return (v < (T)0) ? -v : v; }
template<typename A, typename B> inline double MathMax(A a, B b) { return ((double)a > (double)b) ? (double)a : (double)b; }
template<typename A, typename B> inline double MathMin(A a, B b) { return ((double)a < (double)b) ? (double)a : (double)b; }
inline double MathRound(double v) { return std::round(v); }
inline double MathFloor(double v) { return std::floor(v); }
inline double MathCeil(double v) { return std::ceil(v); }
inline double MathPow(double a, double b) { return std::pow(a, b); }
inline double MathSqrt(double a) { return std::sqrt(a); }
inline bool MathIsValidNumber(double v) { return std::isfinite(v); }
inline double NormalizeDouble(double v, int digits) { char b[64]; std::snprintf(b, sizeof(b), "%.*f", digits, v); return std::atof(b); }

// ---------------------------------------------------------------- time
inline datetime TimeCurrent() { return (datetime)1761174000; }
inline datetime TimeGMT() { return (datetime)1761174000; }
inline datetime TimeLocal() { return (datetime)1761174000; }
inline datetime TimeTradeServer() { return (datetime)1761174000; }
inline bool TimeToStruct(datetime t, MqlDateTime &dt)
{
   (void)t;
   std::memset(&dt, 0, sizeof(dt));
   dt.year = 2026; dt.mon = 10; dt.day = 22; dt.hour = 12; dt.day_of_week = 4;
   return true;
}
inline datetime StructToTime(MqlDateTime &dt)
{
   (void)dt;
   return (datetime)1761174000;
}
inline MqlStr TimeToString(datetime t, int mode = 0) { (void)t; (void)mode; return MqlStr("2026.10.22 12:00:00"); }
inline int PeriodSeconds(ENUM_TIMEFRAMES tf) { return (int)tf >= 16385 ? 3600 : (int)tf * 60; }

// ---------------------------------------------------------------- strings
inline int StringLen(const MqlStr &s) { return (int)std::strlen(s.data); }
inline MqlStr StringSubstr(const MqlStr &s, int start, int length = -1)
{
   if(start < 0) start = 0;
   int len = (int)std::strlen(s.data);
   if(start > len) return MqlStr("");
   if(length < 0 || start + length > len) length = len - start;
   MqlStr r;
   std::snprintf(r.data, sizeof(r.data), "%.*s", length, s.data + start);
   return r;
}
inline int StringFind(const MqlStr &s, const MqlStr &sub, int start = 0)
{
   if(start < 0) start = 0;
   const char *p = std::strstr(s.data + start, sub.data);
   return p ? (int)(p - s.data) : -1;
}
inline bool StringReplace(MqlStr &s, const MqlStr &find, const MqlStr &rep)
{
   std::string src(s.data), f(find.data), r(rep.data);
   if(f.empty()) return false;
   size_t pos = 0; bool changed = false;
   while((pos = src.find(f, pos)) != std::string::npos) { src.replace(pos, f.size(), r); pos += r.size(); changed = true; }
   s.set(src.c_str());
   return changed;
}
inline long StringToInteger(const MqlStr &s) { return std::atoll(s.data); }
inline double StringToDouble(const MqlStr &s) { return std::atof(s.data); }
inline bool StringToUpper(MqlStr &s)
{
   for(char *p = s.data; *p; ++p) *p = (char)std::toupper((unsigned char)*p);
   return true;
}
inline MqlStr DoubleToString(double v, int digits = 8) { char b[128]; std::snprintf(b, sizeof(b), "%.*f", digits, v); return MqlStr(b); }
inline MqlStr IntegerToString(long v, int = 0, int = ' ') { char b[64]; std::snprintf(b, sizeof(b), "%lld", (long long)v); return MqlStr(b); }
inline MqlStr StringFormat(const char *fmt, ...)
{
   char buf[4096];
   va_list ap; va_start(ap, fmt); std::vsnprintf(buf, sizeof(buf), fmt, ap); va_end(ap);
   return MqlStr(buf);
}

// ---------------------------------------------------------------- print
inline void PrintFormat(const char *fmt, ...)
{
   char buf[4096];
   va_list ap; va_start(ap, fmt); std::vsnprintf(buf, sizeof(buf), fmt, ap); va_end(ap);
   std::cout << buf << std::endl;
}
template<typename... Args> inline void Print(Args... args) { ((std::cout << args), ...); std::cout << std::endl; }
template<typename... Args> inline void Alert(Args... args) { ((std::cout << args), ...); std::cout << std::endl; }
inline void Comment(const MqlStr &s) { _CommentText = s; }

// ---------------------------------------------------------------- symbol / account
inline bool SymbolSelect(const MqlStr &, bool) { return true; }
inline double SymbolInfoDouble(const MqlStr &, ENUM_SYMBOL_INFO_DOUBLE prop)
{
   switch(prop)
   {
      case SYMBOL_POINT: return 0.01;
      case SYMBOL_TRADE_TICK_SIZE: return 0.01;
      case SYMBOL_TRADE_TICK_VALUE: return 1.0;
      case SYMBOL_TRADE_CONTRACT_SIZE: return 100.0;
      case SYMBOL_VOLUME_MIN: return 0.01;
      case SYMBOL_VOLUME_MAX: return 100.0;
      case SYMBOL_VOLUME_STEP: return 0.01;
      default: return 0.0;
   }
}
inline long SymbolInfoInteger(const MqlStr &, ENUM_SYMBOL_INFO_INTEGER prop)
{
   switch(prop)
   {
      case SYMBOL_DIGITS: return 2;
      case SYMBOL_TRADE_STOPS_LEVEL: return 0;
      case SYMBOL_TRADE_FREEZE_LEVEL: return 0;
      case SYMBOL_FILLING_MODE: return 3;
      case SYMBOL_TRADE_MODE: return SYMBOL_TRADE_MODE_FULL;
      default: return 0;
   }
}
inline MqlStr SymbolInfoString(const MqlStr &, ENUM_SYMBOL_INFO_STRING) { return MqlStr("XAUUSD"); }
inline bool SymbolInfoTick(const MqlStr &, MqlTick &tick)
{
   std::memset(&tick, 0, sizeof(tick));
   tick.bid = 2400.00; tick.ask = 2400.30;
   return true;
}
inline double AccountInfoDouble(ENUM_ACCOUNT_INFO_DOUBLE prop)
{
   switch(prop)
   {
      case ACCOUNT_BALANCE: return 10000.0;
      case ACCOUNT_EQUITY: return 10000.0;
      case ACCOUNT_MARGIN_FREE: return 10000.0;
      default: return 0.0;
   }
}
inline long AccountInfoInteger(ENUM_ACCOUNT_INFO_INTEGER prop)
{
   switch(prop)
   {
      case ACCOUNT_LOGIN: return 12345678;
      case ACCOUNT_LEVERAGE: return 100;
      case ACCOUNT_TRADE_MODE: return ACCOUNT_TRADE_MODE_DEMO;
      case ACCOUNT_TRADE_ALLOWED: return 1;
      case ACCOUNT_TRADE_EXPERT: return 1;
      case ACCOUNT_MARGIN_MODE: return ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
      default: return 0;
   }
}
inline MqlStr AccountInfoString(ENUM_ACCOUNT_INFO_STRING) { return MqlStr("Demo Broker"); }
inline long TerminalInfoInteger(ENUM_TERMINAL_INFO_INTEGER prop) { return prop == TERMINAL_TRADE_ALLOWED ? 1 : (prop == TERMINAL_CONNECTED ? 1 : 5000); }
inline long MQLInfoInteger(ENUM_MQL_INFO_INTEGER prop) { return prop == MQL_TRADE_ALLOWED ? 1 : 0; }

// ---------------------------------------------------------------- indicators
inline int iMA(const MqlStr &, ENUM_TIMEFRAMES, int, int, ENUM_MA_METHOD, ENUM_APPLIED_PRICE) { return 1; }
inline int iATR(const MqlStr &, ENUM_TIMEFRAMES, int) { return 2; }
inline bool IndicatorRelease(int) { return true; }
inline int CopyBuffer(int, int, int, int, MqlArray<double> &) { return 0; }
inline int CopyRates(const MqlStr &, ENUM_TIMEFRAMES, int, int, MqlArray<MqlRates> &) { return 0; }

// ---------------------------------------------------------------- positions / orders
inline int PositionsTotal() { return 0; }
inline ulong PositionGetTicket(int) { return 0; }
inline bool PositionSelect(const MqlStr &) { return false; }
inline bool PositionSelectByTicket(ulong) { return false; }
inline double PositionGetDouble(ENUM_POSITION_PROPERTY_DOUBLE) { return 0.0; }
inline long PositionGetInteger(ENUM_POSITION_PROPERTY_INTEGER) { return 0; }
inline MqlStr PositionGetString(ENUM_POSITION_PROPERTY_STRING) { return MqlStr(""); }

inline int OrdersTotal() { return 0; }
inline ulong OrderGetTicket(int) { return 0; }
inline bool OrderSelect(ulong) { return false; }
inline long OrderGetInteger(ENUM_ORDER_PROPERTY_INTEGER) { return 0; }
inline MqlStr OrderGetString(ENUM_ORDER_PROPERTY_STRING) { return MqlStr(""); }

inline bool OrderCheck(MqlTradeRequest &, MqlTradeCheckResult &) { return true; }
inline bool OrderSend(MqlTradeRequest &, MqlTradeResult &) { return true; }
inline bool OrderCalcMargin(ENUM_ORDER_TYPE, const MqlStr &, double, double, double &margin) { margin = 10.0; return true; }
inline bool OrderCalcProfit(ENUM_ORDER_TYPE, const MqlStr &, double, double, double, double &profit) { profit = -10.0; return true; }

// ---------------------------------------------------------------- history
inline bool HistorySelect(datetime, datetime) { return true; }
inline bool HistoryDealSelect(ulong) { return true; }
inline int HistoryDealsTotal() { return 0; }
inline ulong HistoryDealGetTicket(int) { return 0; }
inline long HistoryDealGetInteger(ulong, ENUM_DEAL_PROPERTY_INTEGER) { return 0; }
inline double HistoryDealGetDouble(ulong, ENUM_DEAL_PROPERTY_DOUBLE) { return 0.0; }
inline MqlStr HistoryDealGetString(ulong, ENUM_DEAL_PROPERTY_STRING) { return MqlStr(""); }

// ---------------------------------------------------------------- files
inline int FileOpen(const MqlStr &, int, short = 0, int = 0) { return 1; }
inline bool FileClose(int) { return true; }
inline uint FileWriteString(int, const MqlStr &, int = -1) { return 0; }
inline MqlStr FileReadString(int, int = -1) { return MqlStr(""); }
inline bool FileIsExist(const MqlStr &, int = 0) { return false; }
inline bool FileDelete(const MqlStr &, int = 0) { return true; }
inline bool FileSeek(int, long, int) { return true; }
inline bool FileFlush(int) { return true; }
inline ulong FileTell(int) { return 0; }

// ---------------------------------------------------------------- misc
inline int GetLastError() { return 0; }
inline void ResetLastError() {}
inline bool IsStopped() { return false; }
inline bool EventSetTimer(int) { return true; }
inline bool EventKillTimer() { return true; }
template<typename T> inline void ZeroMemory(T &obj) { std::memset(&obj, 0, sizeof(T)); }
