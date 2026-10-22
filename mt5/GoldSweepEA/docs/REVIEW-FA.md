# بررسی کامل GoldSweepEA — از نسخه ۱.۰۰ تا نسخه ۲.۰۰

**تاریخ بررسی:** ۲۰۲۶-۱۰-۲۲ · **نسخه تحویلی:** 2.00 · **نماد هدف:** XAUUSD · **پلتفرم:** MetaTrader 5

---

## ۱) خلاصه مدیریتی

گزارش بازبینی PDF، نسخه ۱.۰۰ (فایل ۳۰۵ خطی `GoldSweepEA.mq5`) را از نظر **کنترل ریسک و کنترل اجرا** رد کرده بود. جمع‌بندی گزارش این بود:

> «کامپایل موفق به‌معنای آماده بودن برای حساب واقعی نیست؛ ضعف اصلی: کنترل ریسک و اجرا تأیید نشده است.»

منبع کد نسخه ۱ در مخزن موجود نبود؛ بنابراین نسخه ۲.۰۰ یک **بازنویسی کامل** است که:

- منطق مستندشده استراتژی (سوییپ نقدینگی روی کندل بسته، فیلتر EMA در H1، SL مبتنی بر ATR، TP بر اساس R:R، سقف زیان روزانه، فیلتر سشن) را حفظ می‌کند؛
- **هر ۱۴ ایراد گزارش** را با یک راه‌حل مشخص و قابل ردیابی در کد برطرف می‌کند؛
- ۱۶ مورد سخت‌سازی اضافه دارد که در گزارش نبود (مارجین، سقف ریسک باز، دراودان از HWM، قفل حساب واقعی، Dry-Run، ماندگاری وضعیت و ...)؛
- یک **گیت نحوی** و **۴۹ تست عددی** دارد که در همین محیط اجرا و پاس شده‌اند؛
- بدون ادعای سوددهی تحویل داده می‌شود و مسیر تست آن مستند است.

> **صادقانه:** در این محیط MetaEditor و داده تاریخی بروکر وجود ندارد. بنابراین «کامپایل واقعی»، «بک‌تست» و «فوروارد دمو» انجام نشده و باید توسط شما طبق `TEST-PLAN-FA.md` انجام شود. چیزی که انجام شده، حذف کلاس‌های خطای گزارش‌شده + اعتبارسنجی ساختاری/عددی کد است.

---

## ۲) روش بررسی

| مرحله | کار انجام‌شده | نتیجه |
|---|---|---|
| ۱ | استخراج کامل متن PDF (۶ صفحه) و فهرست‌کردن ۱۴ ایراد + نکات مثبت | نقشه اصلاحات |
| ۲ | بازنویسی کامل EA با معماری لایه‌ای و حفظ رفتار مستند | `Experts/GoldSweepEA.mq5` (≈۳۶۰۰ خط) |
| ۳ | گیت نحوی: تبدیل MQL5 به C++17 با stub API و `g++ -fsyntax-only` | **PASS** |
| ۴ | تست عددی الگوریتم‌ها (حجم، SL/TP، سشن، بازسازی PnL روزانه، سوییپ) | **PASS — 49 assertion** |
| ۵ | ممیزی ورودی‌ها (۷۰ پارامتر: همه استفاده شده‌اند؟ محدوده‌ها اعتبارسنجی شده‌اند؟) | **PASS** |
| ۶ | مقایسه ساختار با پروژه‌های MQL5 در GitHub و مستندات رسمی | در بخش ۶ |

**چرا گیت C++17؟** MQL5 شبیه C++ است اما کامپایلر آن در لینوکس موجود نیست. با یک stub از API (توابع و ساختارهای MQL5) و تبدیل مکانیکی چند ساختار خاص MQL5 (مثل `input` و آرایه‌های داینامیک)، می‌توان خطاهای نحوی، شناسه‌های تعریف‌نشده، تعداد آرگومان اشتباه و ناسازگاری نوع را قبل از رسیدن به MetaEditor گرفت. این کار یک باگ واقعی هم پیدا کرد: **فراخوانی `ReleaseIndicators()` قبل از تعریف آن** که MQL5 هم آن را رد می‌کند.

---

## ۳) چهارده ایراد گزارش و اصلاح آن‌ها

شدت: 🔴 بحرانی · 🟠 بالا · 🟡 متوسط · ⚪ پایین

### ۳.۱ — رفتار حساب Netting (🔴 بحرانی)

**مشکل گزارش:** `HasPosition()` فقط با `magic + symbol` جست‌وجو می‌کند؛ در Netting فقط یک پوزیشن برای هر نماد وجود دارد و magic با هر معامله بازنویسی می‌شود. تنها بودن magic جداسازی ایجاد نمی‌کند؛ تغییر SL/TP روی پوزیشن تجمیعی روی کل موقعیت اثر می‌گذارد.

**اصلاح در v2:**
- تشخیص حالت حساب در `OnInit` با `ACCOUNT_MARGIN_MODE` و چاپ `HEDGING` / `RETAIL-NETTING` / `EXCHANGE`.
- `HasForeignNettingPosition()`: اگر روی نماد پوزیشنی با magic غیر از ما باشد → **ورود ممنوع** (هیچ‌وقت پوزیشن دیگری را نمی‌بندیم).
- `SyncPosStates()`: اگر حجم پوزیشن ما از بیرون زیاد شود یا magic عوض شود → آن پوزیشن از مدیریت EA خارج و هشدار داده می‌شود.
- `ModifyStops()`: در Hedging با `position=ticket`، در Netting فقط با `symbol` (طبق مستندات MQL5).
- `ClosePositionByTicket()` همیشه `position=ticket` + `symbol` می‌فرستد (CTrade هم همین کار را می‌کند).

### ۳.۲ — حد ضرر روزانه «توقف سخت» نبود (🔴 بحرانی)

**مشکل گزارش:** گارد فقط قبل از ورود بررسی می‌شد؛ پوزیشن باز بسته نمی‌شد؛ ضرر شناور و گپ در نظر گرفته نمی‌شد؛ «ظرفیت باقی‌مانده» با ریسک معامله جدید مقایسه نمی‌شد.

**اصلاح در v2:**
- `EvaluateGuards()` روی **هر تیک و هر ثانیه** (تایمر) اجرا می‌شود؛ نه فقط قبل از ورود.
- `ComputeDailyStats()` ضرر **بسته‌شده + شناور** را محاسبه می‌کند؛ برای حالت Account از `equity - startBalance` استفاده می‌شود که گپ و کمیسیون را هم می‌گیرد.
- `LockDaily()`: قفل روزانه + ذخیره در فایل + `Alert` + `DeleteOurPendingOrders()` + بستن پوزیشن‌ها (`InpDailyLossClosePos`).
- قفل روزانه با شروع **روز سرور** بعدی خودکار آزاد می‌شود؛ قفل دراودان (`LockHard`) فقط با `InpResetState=true` آزاد می‌شود.
- در `TryEnter()` ریسک معامله جدید با **ظرفیت باقی‌مانده** سقف روزانه مقایسه می‌شود و اگر جا نباشد، معامله رد می‌شود.
- محدودیت باقی‌مانده: گپ/اسلیپیج شدید می‌تواند از سقف عبور کند (هر EA دیگری هم دارد)؛ این در مستندات و لاگ صریح گفته شده است.

### ۳.۳ — محاسبه PnL روزانه ناپایدار (🟠 بالا)

**مشکل گزارش:** `dayStartBal = balance - pnl` بدون احتساب واریز/برداشت، swap، کمیسیون و fee؛ خطای `HistorySelect` مدیریت نمی‌شد؛ معامله‌های دیگر/نمادهای دیگر.

**اصلاح در v2:**
- بازسازی دقیق بالانس شروع روز با معادله بالانس:
  `startBalance = balance_now − Σ(profit + swap + commission + fee)`
  چون واریز/برداشت هم «deal» هستند، این معادله آن‌ها را خودکار حذف می‌کند (deal نوع Balance/Credit/Bonus).
- `DEAL_TYPE_CREDIT` از معادله بالانس کنار گذاشته می‌شود (کردیت `ACCOUNT_CREDIT` را تغییر می‌دهد، نه `ACCOUNT_BALANCE`).
- شکست `HistorySelect` → `stats.valid=false` → **ورودهای جدید قفل** + لاگ خطا (نه سکوت).
- کراس‌چک با `startBalance` ذخیره‌شده در فایل؛ اگر اختلاف >۵٪ باشد هشدار و از **مقدار محافظه‌کارانه‌تر (کمتر)** استفاده می‌شود.
- `InpLossScope` انتخاب می‌کند ضرر روزانه فقط این EA باشد یا کل حساب.

### ۳.۴ — اعتبارسنجی نادرست SL/TP نسبت به Stops/Freeze/Spread/تیک (🟠 بالا)

**مشکل گزارش:** برای Buy از Bid و برای Sell از Ask استفاده نمی‌شد؛ `stops level`/`freeze`/`tick size` لحاظ نمی‌شد؛ `NormalizeDouble` قیمت را روی شبکه تیک نمی‌برد.

**اصلاح در v2:**
- `ValidateStops()` **سمت‌آگاه** است: SL/TP خرید نسبت به **Bid** و فروش نسبت به **Ask** سنجیده می‌شود.
- حداقل فاصله = `max(stopsLevel, freezeLevel) × point` که **هر ثانیه** از `SymbolInfoInteger` تازه می‌شود (نه فقط در Init).
- `RoundToTick()` قیمت را روی مضرب `SYMBOL_TRADE_TICK_SIZE` می‌برد؛ SL همیشه «دورتر» و TP «دورتر» گرد می‌شود.
- سه لایه اعتبارسنجی: چک داخلی → `OrderCheck` → خطای سرور (`INVALID_STOPS` در retcode).
- در `ModifyStops()`، stop جدید به حداقل فاصله مجاز بروکر کلمپ می‌شود و `freeze level` چک می‌شود.

### ۳.۵ — پاسخ غلط به نتیجه سفارش/Breakeven (🟠 بالا)

**مشکل گزارش:** مقدار `true` از `CTrade::Buy/Sell/PositionModify` فقط یعنی «درخواست ساخته شد»؛ کد بازگشتی سرور بررسی نمی‌شد و رد شدن (requote/margin/stops/freeze/market closed) پنهان می‌ماند.

**اصلاح در v2:**
- `CTrade` کنار گذاشته شد؛ `SendMarketOrder()` با `MqlTradeRequest` خام کار می‌کند:
  `OrderCheck` → `OrderSend` → بررسی `tr.retcode` با `IsSuccessRetcode()` → تشخیص retryable → حداکثر ۳ تلاش با قیمت تازه.
- لاگ ساختاریافته: `retcode`, متن آن (`RetcodeText`)، `order`, `deal`, قیمت درخواست، قیمت پر شدن، حجم درخواست/پر شده، `comment`.
- بعد از موفقیت، **وجود پوزیشن واقعی** با `FindOurNewestPosition()` تأیید می‌شود؛ اگر نبود خطای بحرانی.
- Partial fill لاگ می‌شود و حجم واقعی مبنای مدیریت قرار می‌گیرد.
- `ModifyStops()` هم retcode و هم `NO_CHANGES` را می‌فهمد؛ حداقل ۳ ثانیه بین تلاش‌های تکراری فاصله می‌گذارد.

### ۳.۶ — ناسازگاری تایم‌فریم (🟡 متوسط)

**مشکل گزارش:** EA روی هر تایم‌فریمی اجرا می‌شود اما کامنت/طراحی M15 است؛ اندیکاتورها از `Period()` ضمنی استفاده می‌کردند.

**اصلاح در v2:**
- `InpSignalTF` و `InpTrendTF` **ورودی صریح** هستند و همه `CopyRates/CopyBuffer/iMA/iATR` آن‌ها را پاس می‌دهند.
- ورودی `InpTrendTF` باید ≥ `InpSignalTF` باشد (اعتبارسنجی).
- سیگنال فقط از کندل **بسته** (`shift=1`) خوانده می‌شود؛ ربات روی هر تایم‌فریم چارتی همان M15 را معامله می‌کند.

### ۳.۷ — نرمال‌سازی حجم با دو رقم اعشار (🟠 بالا)

**مشکل گزارش:** `NormalizeDouble(lots, 2)` سپس floor با `volume step`؛ برای بروکرهایی با step = 0.001 یا 0.005 حجم صفر/نامعتبر می‌شد.

**اصلاح در v2:**
- `VolumeStepDigits()` تعداد اعشار را از خود `SYMBOL_VOLUME_STEP` استخراج می‌کند (۰.۰۱ → ۲، ۰.۰۰۱ → ۳، ۰.۱ → ۱).
- `FloorToVolumeStep()` با `floor` به مضرب step و `volMin/volMax` اعتبارسنجی می‌شود.
- اگر حجم زیر حداقل بروکر باشد، فقط با مجوز `InpMaxRiskMult` به حداقل افزایش می‌یابد، وگرنه معامله **رد** می‌شود.

### ۳.۸ — ریسک ۰.۵٪ که می‌توانست دو برابر شود (🟠 بالا)

**مشکل گزارش:** وقتی حجم محاسبه‌شده کمتر از حداقل بروکر بود، حداقل حجم انتخاب می‌شد و ریسک واقعی می‌توانست ۲ برابر هدف شود؛ `InpMaxRiskMult=2.0` هم همین را مجاز می‌کرد.

**اصلاح در v2:**
- پیش‌فرض `InpMaxRiskMult = 1.00` (هیچ افزایشی مجاز نیست).
- قبل از استفاده از حداقل حجم، ریسک واقعی آن با `target × InpMaxRiskMult` مقایسه می‌شود.
- ریسک واقعی همیشه در Journal و CSV لاگ می‌شود (`risk %.2f (%.2f%%)`).
- اگر اسلیپیج باعث شود ریسک واقعی بعد از فیل > ۱۲۵٪ برنامه باشد، هشدار داده می‌شود.

### ۳.۹ — محاسبه حجم بدون ارزش تیک سمت معامله (🟠 بالا)

**مشکل گزارش:** فرمول حجم فقط از tick value استفاده می‌کرد؛ تفاوت Bid/Ask، contract size و تبدیل ارز حساب لحاظ نمی‌شد.

**اصلاح در v2:**
- `RiskPerLot()` از `OrderCalcProfit(type, symbol, 1.0, entry, sl)` استفاده می‌کند: قیمت ورود **همان سمت معامله** (Ask برای خرید، Bid برای فروش)، حجم ۱ لات، و سود/زیان به ارز حساب — یعنی contract size و تبدیل ارز خودکار.
- کمیسیون رفت‌وبرگشت (`InpCommissionPerLotRT`) و بافر اسلیپیج (`InpRiskBufferPct`، پیش‌فرض ۱۰٪) روی ریسک اضافه می‌شوند.
- فالبک: اگر `OrderCalcProfit` در دسترس نبود، `(distance/tickSize) × tickValue` با یک بار هشدار.
- قبل از ارسال، `OrderCalcMargin` + حداقل مارجین آزاد (`InpMinFreeMarginPct`) چک می‌شود.

### ۳.۱۰ — اعتبارسنجی ناقص ورودی‌ها (🟡 متوسط)

**مشکل گزارش:** فقط ترتیب EMAها و درصد ریسک چک می‌شد؛ ATR/lookback صفر، RR منفی، ساعات نامعتبر، SL range منفی، deviation منفی و ... رد نمی‌شدند.

**اصلاح در v2:**
- `ValidateInputs()` تمام ۷۰ ورودی را با محدوده مشخص چک می‌کند (عدد، enum، منطق بین پارامترها).
- خطاها با پیام دقیق در Journal چاپ و `INIT_PARAMETERS_INCORRECT` برگردانده می‌شود؛ EA با تنظیم غلط شروع نمی‌کند.
- هشدارهای ایمنی: ریسک > ۲٪، خاموش بودن سقف روزانه/دراودان، تایم‌فریم خیلی پایین.

### ۳.۱۱ — سشن/ساعت سرور/DST/Friday (🟡 متوسط)

**مشکل گزارش:** ساعت سرور با London یکی فرض شده بود؛ Start > End سشن را جابه‌جا می‌کرد؛ خاموش‌کردن سشن، محدودیت جمعه را هم غیرفعال می‌کرد؛ DST پوشش نداشت.

**اصلاح در v2:**
- سشن با **دقیقه** و پشتیبانی از پنجره عبور از نیمه‌شب (`start > end`).
- `InpSessionShiftHours` برای تنظیم DST/اختلاف بروکر بدون تغییر ساعت‌ها.
- `FridayBlocked()` **مستقل** از `InpUseSession` است.
- در `OnInit` زمان سرور، GMT و لوکال چاپ می‌شود تا ساعت‌ها را دقیق تنظیم کنید.
- پایان هفته (شنبه/یکشنبه) در حالت سشن فعال رد می‌شود.

### ۳.۱۲ — سیگنال تکراری بعد از ری‌استارت / وسط کندل (🟠 بالا)

**مشکل گزارش:** `lastBarTime = 0` در شروع باعث می‌شد اولین تیک، سیگنال کندل قدیمی را اجرا کند؛ ری‌استارت وسط کندل امکان تکرار داشت.

**اصلاح در v2:**
- `lastEvalBar` و `lastEntryBar` در فایل `state.csv` ذخیره می‌شوند.
- **سیاست attach:** کندلی که قبل از بالا آمدن EA بسته شده، هرگز اجرا نمی‌شود (لاگ می‌شود).
- `g_barAttempts` و `g_lastAttemptTime` برای هر کندل؛ پس از اتمام تلاش‌ها، کندل «پردازش‌شده» علامت می‌خورد.
- بعد از پر شدن سفارش، `lastEntryBar` ذخیره می‌شود؛ حتی اگر پوزیشن در همان کندل بسته شود، دوباره وارد نمی‌شود.

### ۳.۱۳ — از دست رفتن فرصت با اسپرد/خطای اولین تیک (🟡 متوسط)

**مشکل گزارش:** اگر اولین تیک بعد از بسته شدن کندل اسپرد بالا داشت، سیگنال برای همیشه رد می‌شد.

**اصلاح در v2:**
- تفکیک خطای **موقت** (`ENTRY_TRANSIENT`) از **دائمی** (`ENTRY_SKIP`):
  موقت: اسپرد بالا، نبود تیک معتبر، requote/price changed، timeout/connection.
  دائمی: نبود سیگنال، ریسک/مارجین/هندسه، قفل، سشن، cooldown.
- تلاش مجدد با `InpMaxRetriesPerBar` (پیش‌فرض ۲) و `InpRetryDelaySec` (۱۰ ثانیه).
- هر تلاش لاگ می‌شود؛ پس از اتمام، «signal skipped» با دلیل.

### ۳.۱۴ — Breakeven بر اساس RR ورودی/TP (🟠 بالا)

**مشکل گزارش:** فاصله R از `abs(TP-open)/InpRR` محاسبه می‌شد؛ تغییر دستی TP یا RR بعداً، R را خراب می‌کرد؛ freeze level چک نمی‌شد.

**اصلاح در v2:**
- برای هر پوزیشن یک رکورد وضعیت (`SPosState`) ذخیره می‌شود: `entry`, `initialSL`, `riskMoney`, `initialRiskPoints`, `beDone`.
- `TryBreakEven()` فقط از **SL اولیه ذخیره‌شده** استفاده می‌کند؛ TP/RR فعلی هیچ نقشی ندارد.
- قبل از Modify: حداقل فاصله بروکر و `freeze level` چک می‌شود؛ retcode بررسی می‌شود.
- بعد از ری‌استارت، وضعیت از فایل بازیابی می‌شود (و اگر فایل نبود، از خود پوزیشن بازسازی می‌شود).

---

## ۴) نکات مثبت گزارش که حفظ/تقویت شد

| نکته گزارش | وضعیت در v2 |
|---|---|
| سیگنال از کندل بسته `shift=1` و lookback از `shift=2` | حفظ شد + صریح در `DetectSignal()` |
| EMA های H1 از `shift=1` (نه کندل در حال تشکیل) | حفظ شد + `InpTrendTF` جدا |
| آزادسازی هندل اندیکاتورها در `OnDeinit` | حفظ شد + `ReleaseIndicators()` در خطای Init |
| تنظیم magic، deviation و filling مخصوص نماد | حفظ و تقویت: تشخیص bitmask filling و fallback |
| استفاده از `PositionModify` مبتنی بر ticket برای Hedging | حفظ شد + شاخه Netting |
| استفاده از tick value در فرمول ریسک | ارتقا به `OrderCalcProfit` سمت‌آگاه |

---

## ۵) سخت‌سازی‌های اضافه (خارج از گزارش)

1. **سقف ریسک باز کل** (`InpMaxOpenRiskPct`) — جمع ریسک پوزیشن‌های باز نباید از ۲٪ اکوییتی بگذرد.
2. **قفل دراودان از High-Water Mark** (`InpMaxDrawdownPct`) — حافظ سرمایه در دوره‌های ضرر.
3. **سقف تعداد معاملات روز** (`InpMaxTradesPerDay`) و **cooldown بعد از ضرر** (`InpCooldownLossMin`).
4. **سقف پوزیشن هم‌زمان** (`InpMaxPositions`).
5. **مارجین**: `OrderCalcMargin` + حداقل مارجین آزاد.
6. **چسباندن مجدد SL** اگر بروکر بعد از فیل SL را نگه ندارد + هشدار بحرانی.
7. **ریسک واقعی بعد از فیل** و هشدار در صورت عبور از ۱۲۵٪ برنامه.
8. **Partial fill** و **حجم واقعی** مبنای مدیریت.
9. **حالت Dry-Run** برای اعتبارسنجی بدون ارسال سفارش.
10. **قفل حساب واقعی** تا `InpEnableLiveTrading=true` نشود.
11. **ماندگاری وضعیت** (state + per-position) و بازیابی بعد از ری‌استارت.
12. **داشبورد روی چارت** + **لاگ CSV** معاملات.
13. **غیرفعال‌سازی I/O در Optimization** برای سرعت تستر.
14. **اعتبارسنجی مشخصات نماد** (point/tick/digits/volume/stops/filling) و بنر تشخیصی.
15. **حذف سفارش‌های Pending باقی‌مانده** با magic ما در شروع (این EA فقط Market می‌زند).
16. **اصلاح باگ فیلتر روند:** حالت «خنثی» در نسخه اولیه بازنویسی، معاملات خلاف روند را مجاز می‌کرد؛ حالا جهت صفر یعنی «بدون اجازه ورود» و فیلتر سه‌حالته است.

---

## ۶) مقایسه با پروژه‌های GitHub و استانداردهای MQL5

### ۶.۱ ساختار پروژه

| پروژه | ساختار | چیزی که اتخاذ کردیم |
|---|---|---|
| [abebr/awesome-mql5-expert-advisors](https://github.com/abebr/awesome-mql5-expert-advisors) | `Experts/` + `Include/RiskManager.mqh` + `Include/TradeManager.mqh` + مستندات | جداسازی مسئولیت Risk / Trade / Signal / Guards |
| [cryptyroot-ux/ICT-MT5](https://github.com/cryptyroot-ux/ICT-MT5) | `Experts/ICT_EA.mq5` + `Include/ICT_*.mqh` (MarketStructure, RiskManager, SignalGenerator) + `docs/BACKTEST_GUIDE.md` | لایه‌بندی + راهنمای بک‌تست جداگانه |
| [Royatvand/mql5-risk-manager](https://github.com/Royatvand/mql5-risk-manager) | پنل مدیریت ریسک با daily-loss و drawdown guard، فیلتر خبر/اسپرد/سشن، BE و trailing | الگوی گاردهای ریسک و فیلترها |
| [maxime-fintech/mt5-trade-panel](https://github.com/maxime-fintech/mt5-trade-panel) | ماژول‌های Controller / Order / Calcul / Types / View | تفکیک «محاسبه» از «اجرا» از «نمایش» |
| [hamamun/Perfect](https://github.com/hamamun/Perfect) | `Include/PF_Types.mqh`, `PF_Data.mqh`, `PF_Features.mqh`… | تعریف Types و Data جدا |

**تصمیم ما:** همان لایه‌بندی را داریم، اما در **یک فایل** (`GoldSweepEA.mq5`) با ریجن‌های شماره‌دار. دلیل: تجربه نشان می‌دهد بزرگ‌ترین علت خطای کاربران، کپی‌نکردن پوشه `Include` یا خراب شدن مسیر آن است. یک فایل = نصب بدون خطا. برای توسعه‌دهنده، هر ریجن مستقل و قابل استخراج به `.mqh` است.

### ۶.۲ بررسی نتیجه سفارش (retcode-first)

- مقاله [OrderSend returned true, so where is my trade?](https://dev.to/omaisali/ordersend-returned-true-so-where-is-my-trade-checking-results-properly-in-mql5-4j6p) و مستندات [CTrade::ResultRetcode](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctraderesultretcode) دقیقاً همان ایراد گزارش را توضیح می‌دهند: `true` یعنی «درخواست ساخته شد»، نه «معامله انجام شد».
- [تحلیل رفتار PositionClose](https://barmenteros.com/ctrade-positionclose-signature/) نشان می‌دهد حتی بعد از `DONE` باید وضعیت پوزیشن را در تیک بعد تأیید کرد.
- پیاده‌سازی ما: `OrderSend` خام + `retcode` + تأیید پوزیشن + state machine، بدون تکیه بر bool.

### ۶.۳ Netting / Hedging

- [کتاب MQL5: Account type](https://www.mql5.com/en/book/automation/account/account_netting_hedge) و [توضیح magic در Netting](https://fxnx.com/en/blog/mql5-magic-numbers-running-several-eas-one-account): در Netting فقط یک پوزیشن برای هر نماد است و magic با آخرین deal بازنویسی می‌شود.
- پیاده‌سازی: تشخیص mode، سیاست «پوزیشن خارجی = عدم ورود»، شاخه‌بندی SL/TP و Close، و رهاسازی مدیریت در صورت تغییر حجم/magic.

### ۶.۴ مدیریت ریسک

- [Risk Manager for Trading Robots (MQL5)](https://www.mql5.com/en/articles/18918) الگوی daily/weekly/total limit و baseline را نشان می‌دهد.
- ما daily + HWM drawdown + open risk + remaining capacity را پیاده کردیم و baseline را از history بازسازی می‌کنیم (نه فقط یک متغیر).

### ۶.۵ داده‌های سری‌زمانی و ZeroMemory

- [CopyBuffer](https://www.mql5.com/en/docs/series/copybuffer) و [CopyRates](https://www.mql5.com/en/docs/series/copyrates): داده‌ها همیشه از قدیم به جدید در حافظه چیده می‌شوند و `ArraySetAsSeries(true)` ایندکس را برعکس می‌کند؛ کد ما همیشه `ArraySetAsSeries` را قبل از Copy صدا می‌زند و `start_pos=1` می‌گیرد تا `[0]` = آخرین کندل بسته باشد.
- [ZeroMemory](https://www.mql5.com/en/docs/common/zeromemory): برای ساختارهای دارای string هم امن است (برای هر عضو صدا زده می‌شود) — استفاده ما برای `MqlTradeRequest` و ساختارهای وضعیت معتبر است.

---

## ۷) معماری نسخه ۲.۰۰

```
┌───────────────────────────── GoldSweepEA.mq5 ─────────────────────────────┐
│ 0. Enums            1. Inputs (70)         2. Types/Globals               │
│ 3. Utilities/Log    4. Symbol cache        5. Positions                   │
│ 6. State store      7. Daily stats         8. Risk sizing                 │
│ 9. Execution        10. Guards             11. Session                    │
│ 12. Indicators      13. Signal             14. Position management        │
│ 15. Entry engine    16. Validation         17. Dashboard                  │
│ 18. Event handlers (OnInit/OnTick/OnTimer/OnDeinit/OnTradeTransaction)    │
└───────────────────────────────────────────────────────────────────────────┘
```

**قواعد طراحی:**
- هیچ تصمیم معاملاتی روی کندل در حال تشکیل گرفته نمی‌شود (`shift >= 1`).
- هر تابع فقط یک مسئولیت دارد و خروجی‌اش با `bool + err` یا enum قابل تست است.
- هیچ `Sleep`، حلقه بی‌پایان یا وابستگی به کتابخانه خارجی وجود ندارد.
- تمام I/O فایل خطا-مقاوم است (شکست نوشتن، EA را متوقف نمی‌کند).
- در Optimization هیچ فایل/داشبوردی نوشته نمی‌شود.

### ماشین حالت ورود (Idempotency)

```
کندل بسته شد
   │
   ├─ lastEvalBar == bar? ── بله ──► خروج (قبلاً پردازش شده)
   │
   ├─ DetectSignal() (کش‌شده برای همان کندل)
   │      └─ سیگنال ندارد ──► خروج (کندل علامت نمی‌خورد)
   │
   ├─ CanTradeNow()
   │      ├─ خطای موقت (اسپرد/تیک/ارتباط) ──► تلاش بعدی تا سقف retries
   │      └─ خطای دائمی ──► lastEvalBar = bar (ذخیره)
   │
   ├─ BuildLevels + ValidateStops + CalcLots + Margin + Capacity
   │
   ├─ OrderCheck → OrderSend → retcode
   │      ├─ موفق ──► تأیید پوزیشن ──► ذخیره state ──► lastEntryBar = bar
   │      ├─ retryable ──► تلاش درون‌تابعی (حداکثر ۳)
   │      └─ رد ──► lastEvalBar = bar
   │
   └─ پایان
```

---

## ۸) پارامترها (۷۰ ورودی)

> همه ورودی‌ها در `ValidateInputs()` اعتبارسنجی می‌شوند و هیچ‌کدام بی‌استفاده نیست (ممیزی خودکار).

### عمومی و امنیت

| نام | پیش‌فرض | محدوده | کار |
|---|---|---|---|
| `InpMagic` | 20261022 | >0 | شناسه معاملات EA |
| `InpEnableTrading` | true | bool | کلید اصلی ورود جدید |
| `InpDryRun` | false | bool | لاگ بدون ارسال سفارش |
| `InpEnableLiveTrading` | false | bool | اجازه روی حساب REAL |
| `InpPersistState` | true | bool | ذخیره وضعیت در فایل |
| `InpResetState` | false | bool | نادیده‌گرفتن وضعیت قبلی |
| `InpLogLevel` | 2 | 0..3 | سطح لاگ |
| `InpAlerts` | false | bool | Alert روی خطا/ورود (فقط لایو) |
| `InpShowDashboard` | true | bool | داشبورد روی چارت |
| `InpWriteTradeLog` | true | bool | CSV معاملات |

### سیگنال (سوییپ)

| نام | پیش‌فرض | محدوده | کار |
|---|---|---|---|
| `InpSignalTF` | M15 | TIMEFRAME | تایم‌فریم سیگنال |
| `InpSweepLookback` | 16 | 3..500 | تعداد کندل برای سطح سوییپ |
| `InpMinPenetrationATR` | 0.10 | 0..10 | حداقل نفوذ به‌اندازه ATR |
| `InpReclaimBufferATR` | 0.00 | 0..10 | بافر بازگشت داخل محدوده |
| `InpRequireReversalClose` | true | bool | الزام کندل برگشتی |
| `InpMaxBarRangeATR` | 3.00 | 0..50 | رد کندل‌های خیلی بزرگ (0=خاموش) |
| `InpAtrPeriod` | 14 | 2..500 | دوره ATR |

### روند

| نام | پیش‌فرض | محدوده | کار |
|---|---|---|---|
| `InpUseTrendFilter` | true | bool | فیلتر EMA |
| `InpTrendTF` | H1 | TIMEFRAME | تایم‌فریم روند (≥ سیگنال) |
| `InpEmaFastPeriod` | 50 | 1..1000 | EMA سریع |
| `InpEmaSlowPeriod` | 200 | 2..2000 | EMA کند |
| `InpTrendRequirePrice` | false | bool | تأیید قیمت نسبت به EMA کند |

### حد ضرر/سود

| نام | پیش‌فرض | محدوده | کار |
|---|---|---|---|
| `InpAtrSLMult` | 1.00 | ≥0 | ضریب ATR پشت سوییپ |
| `InpMinSLPoints` | 120 | 1..100000 | حداقل فاصله SL (point) |
| `InpMaxSLPoints` | 900 | 0..1000000 | حداکثر فاصله (0=بی‌نهایت) |
| `InpRR` | 2.00 | 0..1000 | نسبت TP به SL (0=بدون TP) |
| `InpRiskBufferPct` | 10 | 0..200 | بافر هزینه/اسلیپیج |
| `InpCommissionPerLotRT` | 0 | ≥0 | کمیسیون هر لات رفت‌وبرگشت |

### ریسک و حفاظت حساب

| نام | پیش‌فرض | محدوده | کار |
|---|---|---|---|
| `InpRiskMode` | PERCENT | enum | درصدی یا حجم ثابت |
| `InpRiskPercent` | 0.50 | 0..10 | ریسک هر معامله |
| `InpFixedLot` | 0.01 | >0 | حجم ثابت |
| `InpUseEquityForRisk` | true | bool | مبنای اکوییتی/بالانس |
| `InpMaxRiskMult` | 1.00 | 0..10 | سقف افزایش برای min lot |
| `InpMaxDailyLossPct` | 3.00 | 0..100 | قفل زیان روزانه |
| `InpDailyLossClosePos` | true | bool | بستن پوزیشن هنگام قفل |
| `InpMaxDrawdownPct` | 10.0 | 0..100 | قفل دراودان از HWM |
| `InpMaxDDClosePos` | true | bool | بستن هنگام دراودان |
| `InpMaxOpenRiskPct` | 2.00 | 0..100 | سقف ریسک باز کل |
| `InpMinFreeMarginPct` | 30.0 | 0..100 | حداقل مارجین آزاد بعد از ورود |
| `InpLossScope` | EA | enum | دامنه PnL روزانه |

### فرکانس و فیلترها

| نام | پیش‌فرض | محدوده | کار |
|---|---|---|---|
| `InpMaxPositions` | 1 | 1..50 | سقف پوزیشن هم‌زمان |
| `InpMaxTradesPerDay` | 3 | 0..1000 | سقف ورود روزانه |
| `InpCooldownLossMin` | 30 | 0..10080 | مکث بعد از ضرر |
| `InpCooldownWinMin` | 0 | 0..10080 | مکث بعد از سود |
| `InpMaxSpreadPoints` | 50 | 0..100000 | سقف اسپرد ورود |

### سشن

| نام | پیش‌فرض | محدوده | کار |
|---|---|---|---|
| `InpUseSession` | false | bool | فیلتر ساعت |
| `InpSessionStartHour/Min` | 9:00 | 0..23 / 0..59 | شروع (سرور) |
| `InpSessionEndHour/Min` | 22:00 | 0..23 / 0..59 | پایان (سرور) |
| `InpSessionShiftHours` | 0 | −12..12 | جبران DST/بروکر |
| `InpUseFridayCutoff` | true | bool | قطع ورود جمعه |
| `InpFridayCutHour/Min` | 19:00 | 0..23 / 0..59 | ساعت قطع جمعه |

### اجرا

| نام | پیش‌فرض | محدوده | کار |
|---|---|---|---|
| `InpFillingMode` | AUTO | enum | سیاست filling |
| `InpDeviationPoints` | 30 | 0..100000 | حداکثر لغزش |
| `InpUseOrderCheck` | true | bool | پیش‌اعتبارسنجی |
| `InpMaxRetriesPerBar` | 2 | 0..50 | تلاش‌های مجدد در کندل |
| `InpRetryDelaySec` | 10 | 0..3600 | فاصله تلاش‌ها |

### مدیریت پوزیشن

| نام | پیش‌فرض | محدوده | کار |
|---|---|---|---|
| `InpUseBreakeven` | true | bool | انتقال SL به سربه‌سر |
| `InpBEStartR` | 1.00 | 0..100 | شروع BE در چند R |
| `InpBELockR` | 0.05 | 0..100 | قفل چند R |
| `InpBEMinStepPoints` | 20 | 0..100000 | حداقل بهبود SL |
| `InpUseTrailing` | false | bool | تریلینگ |
| `InpTrailStartR` | 1.50 | 0..100 | شروع تریل |
| `InpTrailDistR` | 0.75 | 0..100 | فاصله تریل |
| `InpTrailMinStepPoints` | 20 | 0..100000 | حداقل گام تریل |
| `InpCloseAtSessionEnd` | false | bool | بستن در پایان سشن |
| `InpTimeExitBars` | 0 | 0..10000 | خروج زمانی (0=خاموش) |
| `InpTimeExitOnlyProfit` | true | bool | خروج زمانی فقط در سود |

---

## ۹) وضعیت تست (در همین محیط)

### انجام‌شده و پاس‌شده ✅

| تست | ابزار | نتیجه |
|---|---|---|
| گیت نحوی کل فایل (شناسه، آرگومان، نوع، تعریف قبل از استفاده) | `g++ -std=c++17 -fsyntax-only` روی تبدیل MQL5→C++ | **PASS** |
| ۴۹ تست الگوریتمی: floor حجم، گرد کردن تیک، هندسه SL/TP، سقف min-lot، اعتبارسنجی سمت‌آگاه، سشن عبوری، بازسازی بالانس با واریز/برداشت، تشخیص سوییپ | `tools/verify_algorithms.py` | **PASS** |
| ممیزی ۷۰ ورودی: همه استفاده شده‌اند | اسکریپت شمارش | **PASS** |
| تعادل براکت/پرانتز و شمارش توابع | کامپایلر + بازبینی | **PASS** |

### انجام‌نشده ❌ (باید توسط شما انجام شود)

| تست | دلیل | مرجع |
|---|---|---|
| کامپایل با MetaEditor همان بروکر | MetaEditor در این محیط نیست | مرحله ۱ در `TEST-PLAN-FA.md` |
| بک‌تست Every tick based on real ticks | داده تاریخی بروکر لازم است | مرحله ۲ |
| فوروارد دمو ۲–۴ هفته | زمان واقعی لازم است | مرحله ۳ |
| تست Netting واقعی | حساب دمو از نوع Netting لازم است | سناریوی N در `TEST-PLAN-FA.md` |

> هیچ نتیجه بک‌تستی در این پوشه ارائه نشده و هیچ ادعای سوددهی وجود ندارد. اعداد و منحنی سود باید از تستر خودتان بیاید.

---

## ۱۰) محدودیت‌ها و ریسک‌های باقی‌مانده

1. **کیفیت استراتژی** مستقل از کیفیت کد است؛ این نسخه فقط اجرا و ریسک را قابل‌اتکا می‌کند.
2. **گپ و اسلیپیج** می‌تواند از سقف زیان روزانه عبور کند؛ هیچ EA نمی‌تواند گپ را حذف کند.
3. **فیلتر خبری** ندارد (نه تقویم اقتصادی، نه WebRequest). برای اخبار کلان USD، دستی مدیریت کنید.
4. **تک‌نماد** است؛ چند نماد = چند چارت با magicهای متفاوت.
5. **Netting** با EA/معامله دستی دیگر روی همان نماد همزیستی امن ندارد؛ EA ورود را متوقف می‌کند.
6. **قفل دراودان و واریز/برداشت:** واریز/برداشت هنگام اجرای ربات، HWM را اصلاح می‌کند. اگر واریز/برداشت **زمانی که ربات خاموش است** انجام شود، ممکن است HWM قدیمی باعث قفل دراودان شود؛ در این حالت بعد از بررسی، یک‌بار `InpResetState=true` بدهید.
7. **فایل وضعیت** در `MQL5/Files` است؛ اگر پاک شود، پوزیشن‌های باز از روی خود پوزیشن بازسازی می‌شوند ولی SL اولیه ممکن است دقیق نباشد (Fallback).
8. **بروکرهای مختلف** در filling/stops/execution رفتار متفاوت دارند؛ بنر Init را جدی بگیرید.
9. **`input group`** نیاز به build 2470+ دارد (MT5 2020 به بعد)؛ عملاً همه نسخه‌های امروزی.
10. **بازسازی بالانس روزانه** به تاریخچه ترمینال وابسته است؛ cross-check با فایل وضعیت، خطای بزرگ را می‌گیرد ولی خطای کوچک ممکن است باقی بماند.
11. **حجم‌های بزرگ** ممکن است به سقف `SYMBOL_VOLUME_MAX` برسند؛ EA حجم را کلمپ می‌کند و لاگ می‌دهد.

---

## ۱۱) تغییرات نسخه

### v2.00 — بازنویسی کامل (2026-10-22)

- بازنویسی کامل از صفر با حفظ منطق مستندشده نسخه ۱.۰۰.
- رفع ۱۴ ایراد گزارش + ۱۶ سخت‌سازی اضافه.
- حذف وابستگی به `CTrade` و پیاده‌سازی اجرای خام با بررسی کامل retcode.
- افزودن state persistence، داشبورد، Dry-Run، قفل حساب واقعی، گیت‌های تست.
- یکسان‌سازی نام پارامترهای گزارش (`InpRR`، `InpMaxRiskMult`، `InpUseSession`، `InpAtrSLMult`، `InpMinSLPoints`، `InpMaxSLPoints`، `InpSweepLookback`).

### v1.00 — نسخه بررسی‌شده در PDF

- ۳۰۵ خط، بدون تست بروکر/دمو، ۱۴ ایراد بازبینی.

---


## ۱۲) ارزیابی سطح استراتژی (خارج از کد)

این نسخه از نظر **مهندسی اجرا** سخت‌شده است، اما کیفیت آماری استراتژی را نمی‌توان از روی کد تضمین کرد. ارزیابی صادقانه:

**منطق استراتژی:** سوییپ نقدینگی + بازگشت داخل محدوده، هم‌جهت با EMA در H1، با SL ساختاری و TP ثابت R. این خانواده استراتژی در بازارهای روندی و بعد از «شکار استاپ» می‌تواند لبه داشته باشد؛ در بازار رِنج/چوپی و در اسپردهای بالا مستعد ضررهای پیاپی است.

**ریسک‌های آماری که باید در تستر بسنجید:**
1. **رژیم بازار:** نتیجه را به تفکیک سه دوره (روند صعودی، روند نزولی، رِنج) گزارش کنید؛ اگر فقط در یک رژیم سود می‌دهد، در اجرای زنده شکننده است.
2. **هزینه‌ها:** اسپرد متغیر + کمیسیون + سوآپ. استراتژی با RR=2 و SL نسبتاً کوچک، به هزینه حساس است. تست بدون کمیسیون واقعی، گمراه‌کننده است.
3. **تعداد نمونه:** کمتر از ۱۰۰ معامله در بک‌تست = نتیجه قابل اتکا نیست. با سقف ۳ معامله در روز، ۶ ماه ممکن است کافی نباشد؛ ۱ تا ۲ سال داده بگیرید.
4. **Out-of-sample:** پارامترها را روی ۷۰٪ داده تنظیم و روی ۳۰٪ باقی‌مانده (که ندیده‌اید) تست کنید. اگر افت شدید بود، Overfit است.
5. **حساسیت پارامتر:** `InpSweepLookback` (۸/۱۲/۱۶/۲۰)، `InpMinPenetrationATR` (۰/۰۵/۰/۱/۰/۲)، `InpAtrSLMult` (۰/۸/۱/۱/۵) و `InpRR` (۱/۵/۲/۲/۵) را جدا تغییر دهید. اگر سود فقط در یک نقطه خاص ظاهر می‌شود، لبه واقعی نیست.
6. **Walk-forward:** به‌جای بهینه‌سازی ۷۰ پارامتر، فقط ۲–۳ پارامتر حساس را در پنجره‌های زمانی متوالی بهینه کنید. بهینه‌سازی همه پارامترها = منحنی سود زیبا و آینده‌ی نامعلوم.

**حداقل شواهد برای رفتن به حساب واقعی (پیشنهاد ما):**
- ۱۰۰+ معامله در بک‌تست با real ticks و هزینه واقعی
- Profit Factor بعد از هزینه‌ها ≥ ۱.۲
- حداکثر دراودان ≤ ۱۵٪ (با سقف ۱۰٪ ربات)
- سوددهی در حداقل دو رژیم بازار یا دو بازه زمانی مستقل
- ۲ تا ۴ هفته فوروارد دمو بدون Red Flag

**اگر این شرایط برآورده نشد:** ربات را روی حساب واقعی اجرا نکنید؛ حتی اگر بک‌تست «زیبا» بود. این سند هیچ ادعایی درباره سوددهی ندارد.

---

## ۱۳) منابع

- گزارش بازبینی PDF «GoldSweepEA برای XAUUSD» (پیوست گفتگو، ۶ صفحه).
- MQL5 Reference: [CopyBuffer](https://www.mql5.com/en/docs/series/copybuffer)، [CopyRates](https://www.mql5.com/en/docs/series/copyrates)، [ZeroMemory](https://www.mql5.com/en/docs/common/zeromemory)، [Deal properties](https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties)، [CTrade::ResultRetcode](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctraderesultretcode).
- MQL5 Book: [Netting vs Hedging](https://www.mql5.com/en/book/automation/account/account_netting_hedge).
- مقاله ریسک: [Risk Manager for Trading Robots](https://www.mql5.com/en/articles/18918).
- GitHub: [awesome-mql5-expert-advisors](https://github.com/abebr/awesome-mql5-expert-advisors)، [ICT-MT5](https://github.com/cryptyroot-ux/ICT-MT5)، [mql5-risk-manager](https://github.com/Royatvand/mql5-risk-manager)، [mt5-trade-panel](https://github.com/maxime-fintech/mt5-trade-panel)، [Perfect](https://github.com/hamamun/Perfect).
- retcode-first: [dev.to article](https://dev.to/omaisali/ordersend-returned-true-so-where-is-my-trade-checking-results-properly-in-mql5-4j6p)، [PositionClose analysis](https://barmenteros.com/ctrade-positionclose-signature/)، [magic در Netting](https://fxnx.com/en/blog/mql5-magic-numbers-running-several-eas-one-account).
