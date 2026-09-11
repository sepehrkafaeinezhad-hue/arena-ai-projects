# 📱 راهنمای اجرا روی گوشی — بدون کامپیوتر

> خبر خوب: کل چرخه این سیستم گوشی‌پسند است — AI روی ترمینال گوشی، ضبط با دوربین، ادیت با CapCut، انتشار با اینستاگرام. همه از یک دستگاه!

---

## از کجا از GitHub بردارم؟

کل پروژه الان روی شاخه اصلی مخزن خودته. لینک مستقیم پوشه:

**https://github.com/sepehrkafaeinezhad-hue/arena-ai-projects/tree/main/content-team-os**

> روی گوشی نیازی به دانلود ZIP نیست — دستور `git clone` خودش برمی‌دارد (پایین را ببین).

---

## مسیر A — اندروید (با Termux — رایگان، مستقیم روی گوشی)

### قدم ۱: نصب Termux
- از سایت **f-droid.org** نصب کن (نسخه گوگل‌پلی قدیمی و مشکل‌دار است — حتماً F-Droid).
- Termux یک «ترمینال لینوکسی» برای اندروید است. ترسناک نیست، فقط تایپ می‌کنی.

### قدم ۲: نصب Claude Code و گرفتن پروژه
Termux را باز کن و این ۵ خط را به‌ترتیب paste کن (هر کدام Enter):

```bash
pkg update -y && pkg install nodejs-lts git -y
npm install -g @anthropic-ai/claude-code
git clone https://github.com/sepehrkafaeinezhad-hue/arena-ai-projects
cd arena-ai-projects/content-team-os
claude
```

### قدم ۳: ورود به حساب Claude
- اولین بار یک **لینک** نشان می‌دهد → در مرورگر گوشی بازش کن → با اکانت **Claude Pro** لاگین کن → کدی که می‌دهد را در Termux paste کن.

### قدم ۴: تست
- تایپ کن `/agents` → اگر ۶ اسم دیدی، همه‌چیز آماده است ✅
- بعدش همان ۳ قدم همیشگی: `/trend-scan` و ادامه…

### دفعات بعدی که خواستی استفاده کنی
Termux را باز کن و بزن:
```bash
cd arena-ai-projects/content-team-os && claude
```

> ⚠️ اگر مرحله `npm install` ارور داد: این مسیر جایگزین را امتحان کن (اوبونتو داخل Termux):
> ```bash
> pkg install proot-distro -y && proot-distro install ubuntu && proot-distro login ubuntu
> apt update && apt install nodejs npm -y
> npm install -g @anthropic-ai/claude-code
> ```
> بعد `git clone` و ادامه مثل بالا.

---

## مسیر B — آیفون

### گزینه B1 — مرورگر سافاری (بدون نصب هیچ اپی)
از قابلیت رایگان **GitHub Codespaces** استفاده می‌کنیم: یک کامپیوتر ابری که در مرورگر گوشیت باز می‌شود.

1. در سافاری برو به: `github.com/sepehrkafaeinezhad-hue/arena-ai-projects`
2. دکمه سبز **Code** → تب **Codespaces** → **Create codespace on main**
3. چند دقیقه صبر — یک صفحه مثل VS Code باز می‌شود. پایین صفحه ترمینال را پیدا کن (اگر نبود: منوی ☰ → Terminal → New Terminal) و بزن:
   ```bash
   npm install -g @anthropic-ai/claude-code
   cd content-team-os
   claude
   ```
4. لاگین مثل مسیر A. بعد `/agents` و شروع.

> 💰 Codespaces ماهانه ~۶۰ ساعت رایگان دارد (برای این کاربرد کافی است). بعد از تمام‌شدن کار، خودش بعد از ~۳۰ دقیقه بی‌کاری خاموش می‌شود و فایل‌ها می‌مانند.

### گزینه B2 — اپ **Catnip** (تجربه راحت‌تر)
اپ رایگان و متن‌باز در App Store: خودش Codespace می‌سازد، Claude Code را نصب می‌کند و رابط موبایلی تمیزی می‌دهد. با اکانت GitHub وصل شو و پروژه را باز کن — بقیه همان است.

---

## 💡 ترفند طلایی برای کار با گوشی: فایل‌ها را دستی ادیت نکن!

روی کامپیوتر گفته بودیم `voice.md` را با Notepad پر کن. روی گوشی **نیازی نیست** — به Claude داخل همون ترمینال بگو:

> «voice.md رو با من پر کن — ازم سوال بپرس و خودت فایل رو پر کن»

خودش مصاحبه را شروع می‌کند، جواب‌هایت را در فایل می‌نویسد. همین ترفند برای همه فایل‌ها کار می‌کند.

## 💾 ذخیره کارها (مخصوص مسیر B)
فایل‌های Codespace روی ابر خودت هستند، ولی برای اطمینان هر چند روز یک‌بار به Claude بگو:
> «commit and push کن»

(فقط اولین بار می‌پرسد به کدام شاخه — بگو main و تمام.)

## ⚠️ دو یادآوری
1. اشتراک **Claude Pro** در هر دو مسیر لازم است — بدون آن Claude Code اجرا نمی‌شود.
2. کیبورد ترمینال اندروید برای فارسی کمی خشک است؛ اگر سخت بود، دستورات را جایی دیگر بنویس و paste کن.
