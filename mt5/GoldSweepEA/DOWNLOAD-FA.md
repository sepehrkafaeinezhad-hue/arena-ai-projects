# دانلود GoldSweepEA v2.00 از GitHub — راهنمای خیلی ساده

> این فایل روی شاخه `main` است، پس با باز کردن صفحه پروژه مستقیماً دیده می‌شود.

---

## ✅ روش ۱ — دانلود کل پروژه (ساده‌ترین)

روی این لینک کلیک کن:

```
https://github.com/sepehrkafaeinezhad-hue/arena-ai-projects/archive/refs/heads/main.zip
```

یا اگر صفحه پروژه را باز کردی:

1. دکمه سبز **Code** بالای صفحه را بزن.
2. گزینه **Download ZIP** را انتخاب کن.
3. فایل ZIP را **Extract** کن.
4. داخل پوشه باز شده برو به مسیر:

```
mt5/GoldSweepEA/Experts/GoldSweepEA.mq5
```

5. همین یک فایل را کپی کن در:

```
MQL5/Experts
```

مسیر پوشه در MT5: **File → Open Data Folder** (یا `Ctrl+Shift+D`).

---

## ✅ روش ۲ — دانلود فقط فایل ربات

1. این صفحه را باز کن:

```
https://github.com/sepehrkafaeinezhad-hue/arena-ai-projects/blob/main/mt5/GoldSweepEA/Experts/GoldSweepEA.mq5
```

2. بالای کادر کد، دکمه **Download raw file** (آیکون ⤓) یا **Raw** را بزن.
3. `Ctrl+S` → ذخیره.
4. ⚠️ اگر ویندوز پسوند `.txt` اضافه کرد، نام فایل را به `GoldSweepEA.mq5` تغییر بده
   (در Explorer: View → File name extensions را روشن کن).
5. فایل را در `MQL5/Experts` بگذار.

---

## ✅ روش ۳ — پریست تنظیمات (اختیاری)

```
https://github.com/sepehrkafaeinezhad-hue/arena-ai-projects/blob/main/mt5/GoldSweepEA/Presets/GoldSweepEA_XAUUSD_M15.set
```

با همان روش Raw دانلود کن و در `MQL5/Presets` بگذار.

---

## پس از دانلود: ۴ قدم تا اجرا

| قدم | کار |
|---|---|
| ۱ | `Ctrl+Shift+D` در MT5 → پوشه `MQL5/Experts` → فایل `GoldSweepEA.mq5` را کپی کن |
| ۲ | MetaEditor (`F4`) → فایل را باز کن → **F7** | انتظار: **0 errors** |
| ۳ | چارت **XAUUSD** با تایم‌فریم **M15** باز کن → ربات را از Navigator روی چارت بکش |
| ۴ | تب Common: تیک **Allow Algo Trading** · تب Inputs: **Load** → فایل `.set` · دکمه **AutoTrading** سبز |

بعد از اجرا، در تب **Journal → Experts** باید بنر `[GoldSweepEA] ===== v2.00 starting` را ببینی.

---

## اگر شاخه `main` را نمی‌بینی

بالای صفحه GitHub، کنار نام پروژه، یک منوی کشویی هست که معمولاً `main` نشان می‌دهد.
اگر چیز دیگری بود، روی آن کلیک کن و `main` را انتخاب کن؛ بعد مسیر
`mt5 → GoldSweepEA → Experts → GoldSweepEA.mq5` را دنبال کن.

---

## نکته‌های مهم

- فقط فایل **`GoldSweepEA.mq5`** برای اجرای ربات لازم است؛ پوشه‌های `docs/` و `tools/` برای مطالعه و تست آفلاین هستند.
- پیش‌فرض‌ها ایمن‌اند: ریسک ۰.۵٪، سقف ضرر روزانه ۳٪، سقف دراودان ۱۰٪ و **اجرای حساب واقعی قفل** است (`InpEnableLiveTrading=false`).
- ترتیب پیشنهادی: یک روز `InpDryRun=true` → Strategy Tester با «Every tick based on real ticks» → دمو ۲ تا ۴ هفته → بعد تصمیم واقعی.
