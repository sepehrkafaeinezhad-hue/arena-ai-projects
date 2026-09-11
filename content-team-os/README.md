# AI Content Team OS — نسخه شخصی‌سازی‌شده من

تیم تولید محتوای هوش مصنوعی من روی **Claude Code** — برای نیچ **«کسب‌وکار و کارآفرینی با هوش مصنوعی»**، پلتفرم **Instagram Reels**، زبان **فارسی محاوره‌ای**، لحن «من»-محور.

۶ متخصص که تحقیق می‌کنند، هوک می‌نویسند، اسکریپت می‌سازند، طراحی می‌کنند، بسته انتشار را آماده می‌کنند و آمار را تحلیل می‌کنند — و **من سردبیر ارشد هستم**.

> 📖 **برای شروع: [`docs/SETUP-ROADMAP.md`](docs/SETUP-ROADMAP.md)** — نقشه پیاده‌سازی کامل به زبان ساده (نصب، شخصی‌سازی، اولین اجرا، روتین هفتگی، ارتقا، نمونه‌کار).
> 🎬 نمونه خروجی هر مرحله: [`docs/EXAMPLE-WALKTHROUGH.md`](docs/EXAMPLE-WALKTHROUGH.md)
> 🔍 بررسی تخصصی سند منبع و تصمیم‌های فنی: [`docs/REVIEW.md`](docs/REVIEW.md)

---

## 📁 ساختار

```
content-team-os/
├── CLAUDE.md                  ← Master Prompt — نقش Manager را session اصلی بازی می‌کند
├── .claude/
│   ├── settings.json          ← مجوزهای امن برای نوشتن فایل‌ها
│   ├── agents/                ← ۶ Subagent
│   │   ├── research.md        ← تحقیق و ترند (نیچ بیزنس+AI، با فیلتر مخاطب فارسی)
│   │   ├── hook-writer.md     ← ۱۰ هوک فارسی محاوره‌ای رتبه‌بندی‌شده
│   │   ├── script-writer.md   ← اسکریپت ~۴۰ ثانیه‌ای (هوک→ارزش→صادقانه→CTA)
│   │   ├── designer.md        ← زیرنویس، کاور، B-roll (RTL، فونت فارسی)
│   │   ├── publisher.md       ← بسته انتشار اینستاگرام — فقط staging، بدون انتشار
│   │   └── analyst.md         ← تحلیل هفتگی آمار (Saves/Shares محور)
│   └── commands/              ← دستورات سریع
│       ├── make-content.md    ← /make-content — کل پایپلاین با ۲ GATE
│       ├── trend-scan.md      ← /trend-scan — اسکن ترند هفتگی
│       ├── new-hooks.md       ← /new-hooks I-03 — هوک برای یک ایده
│       └── weekly-review.md   ← /weekly-review — تحلیل آمار
├── .mcp.json.example          ← اتصال اختیاری Canva / Metricool / Postiz
├── .gitignore                 ← کلیدها کامیت نشوند
├── brand/
│   ├── voice.md               ← ⭐ صدای برند — مهم‌ترین فایل
│   ├── swipe-file.md          ← هوک‌های اثبات‌شده + کتابخانه الگو
│   └── hashtags.md            ← ست‌های هشتگ فارسی
├── pipeline/
│   ├── ideas.md               ← صندوق ایده‌ها (proposed → analyzed)
│   ├── calendar.md            ← تقویم (شنبه/دوشنبه/سه‌شنبه — ۱۹:۰۰ تهران)
│   └── scripts/               ← اسکریپت‌ها + بسته‌های انتشار
├── results/
│   └── performance.md         ← آمار واقعی پست‌ها + Weekly review
└── docs/
    ├── SETUP-ROADMAP.md       ← نقشه پیاده‌سازی گام‌به‌گام
    ├── EXAMPLE-WALKTHROUGH.md ← نمونه کامل یک چرخه
    └── REVIEW.md              ← بررسی تخصصی سند منبع
```

## 🚀 شروع سریع

```bash
cd ~/content-team   # پوشه کپی‌شده
claude
```
بعد در Claude Code: `/agents` برای چک تیم → `brand/voice.md` را پر کن → `/trend-scan`.

## ⚠️ دو نکته فنی که سند منبع اشتباه داشت (اصلاح شده)
1. Manager یک Subagent نیست (Subagentها نمی‌توانند Subagent بسازند) — session اصلی = Manager (از طریق CLAUDE.md).
2. بدون `settings.json` با allowlist، نوشتن فایل‌ها توسط Subagentها رد می‌شود (Subagent پنجره اجازه باز نمی‌کند).

جزئیات و منابع: `docs/REVIEW.md`
