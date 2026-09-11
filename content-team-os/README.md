# AI Content Team OS — نسخه اصلاح‌شده و اجرایی

تیم تولید محتوای هوش مصنوعی شما روی **Claude Code**: چند متخصص که تحقیق می‌کنند، هوک می‌نویسند، اسکریپت می‌سازند، طراحی می‌کنند، تحلیل می‌کنند و بسته انتشار را آماده می‌کنند — و **شما سردبیر ارشد** هستید.

> این پروژه بر اساس سند «AI Content Team OS» (@academymoghimi) ساخته شده، اما با اصلاحات مهندسی لازم برای اجرای واقعی. تفاوت‌ها و دلایل فنی: [`docs/REVIEW.md`](docs/REVIEW.md)

---

## 📁 ساختار

```
content-team-os/
├── CLAUDE.md                  ← Master Prompt (نقش Manager را خود Claude اصلی بازی می‌کند)
├── .claude/
│   ├── settings.json          ← مجوزهای لازم تا Agentها بتوانند فایل بنویسند
│   └── agents/                ← ۶ Subagent واقعی
│       ├── research.md
│       ├── hook-writer.md
│       ├── script-writer.md
│       ├── designer.md
│       ├── analyst.md
│       └── publisher.md
├── .mcp.json.example          ← نمونه اتصال Canva / Metricool / Postiz
├── brand/
│   ├── voice.md               ← صدای برند شما (مهم‌ترین فایل کل سیستم!)
│   └── swipe-file.md          ← هوک‌ها و فرمت‌های اثبات‌شده
├── pipeline/
│   ├── ideas.md               ← صندوق ایده‌ها (با وضعیت lifecycle)
│   ├── calendar.md            ← تقویم انتشار
│   └── scripts/               ← اسکریپت‌های نهایی
├── results/
│   └── performance.md         ← آمار هر پست + بررسی هفتگی
└── docs/
    └── REVIEW.md              ← بررسی تخصصی سند اصلی
```

⚠️ **نکته مهم:** سند اصلی ۷ Subagent تعریف می‌کرد (شامل Manager). این اشتباه است — Subagentها در Claude Code نمی‌توانند Subagent دیگری صدا بزنند. نقش Manager را **session اصلی** (از طریق CLAUDE.md) بازی می‌کند. توضیح کامل در REVIEW.md.

---

## 🚀 راه‌اندازی (۱۵ دقیقه)

### پیش‌نیاز
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) نصب شده (`npm install -g @anthropic-ai/claude-code`)
- اشتراک Claude Pro/Max یا کلید API

### مراحل
1. **این پوشه را کپی کنید** به جایی که می‌خواهید، مثلاً `~/content-team`:
   ```bash
   cp -r content-team-os ~/content-team
   cd ~/content-team
   ```
2. **Claude Code را اجرا کنید:**
   ```bash
   claude
   ```
3. **Agentها را چک کنید:** دستور `/agents` را بزنید — باید ۶ عضو تیم را ببینید (research, hook-writer, script-writer, designer, analyst, publisher).
4. **Master Prompt را شخصی‌سازی کنید:** فایل `CLAUDE.md` را باز کنید و همه `<PLACEHOLDER>`ها را پر کنید (نیچ، مخاطب، پلتفرم، زبان خروجی، سبک CTA).
5. **صدای برند را بنویسید:** `brand/voice.md` — ۳ تا ۵ نمونه از بهترین کپشن/متن‌های قبلی خودتان را داخلش بگذارید. **کیفیت کل سیستم به این فایل بستگی دارد.**
6. **Swipe file را پر کنید:** `brand/swipe-file.md` — چند هوک/پست که از آن‌ها خوشتان می‌آید + چرا.
7. **(اختیاری) MCPها را وصل کنید:** فایل `.mcp.json.example` را به `.mcp.json` تغییر نام دهید و کلیدها را بگذارید. برای شروع لازم نیست — WebSearch و فایل‌سازی داخلی کافی است.
8. **تست کنید:**
   ```
   Manager, make me one reel about <موضوع>
   ```
9. در دو نقطه توقف (GATE 1: تأیید ایده‌ها، GATE 2: تأیید پیش‌نویس) نظر بدهید.
10. بعد از انتشار، آمار پست را در `results/performance.md` وارد کنید و بگویید: «Analyst, weekly review».

---

## 🎛️ استفاده روزمره

| دستور نمونه | چه می‌شود |
|---|---|
| `what's trending this week?` | research می‌گردد و ایده رتبه‌بندی‌شده می‌دهد |
| `Hook Writer — 10 hooks for I-03` | ۱۰ هوک رتبه‌بندی‌شده با تریگر هر کدام |
| `Manager, make me 3 reels this week` | اجرای کل پایپلاین با ۲ نقطه تأیید |
| `Analyst, weekly review` | الگوهای واقعی از آمار + یک تغییر پیشنهادی |

## 🔌 MCPهای پیشنهادی (بعد از راه‌اندازی اصلی)

| MCP | نقش | وضعیت |
|---|---|---|
| WebSearch / WebFetch | تحقیق | داخلی Claude Code — بدون نصب |
| [Canva MCP](https://mcp.canva.com/mcp) | ساخت کاور/کارت визуال | رسمی، رایگان — **انتشار ندارد** |
| [Metricool MCP](https://ai.metricool.com/mcp) | زمان‌بندی + آنالیتیکس | رسمی |
| [Postiz MCP](https://mcp.postiz.com/mcp) | زمان‌بندی (اوپن‌سورس، self-host رایگان) | رسمی |
| Buffer MCP | پیش‌نویس زمان‌بندی‌شده سبک | رسمی، فقط ساخت |

## 💰 نکته هزینه

هر Subagent یک context window مستقل دارد؛ پایپلاین چندمرحله‌ای مصرف توکن را چند برابر می‌کند (تا حدود ۷ برابر حالت تک‌نخ). پیشنهاد: هفته‌ای ۱ بچ شروع کنید؛ برای Agentهای ساده در فایلشان `model: haiku` بگذارید.

## 🎓 به‌عنوان نمونه‌کار (پورتفولیو)

- معماری multi-agent + نقش‌ها را از REVIEW.md بردارید و در ارائه توضیح دهید (چرا Manager در main session است — نشان‌دهنده تسلط واقعی).
- تاریخچه git این پوشه خودش «گزارش کار» است: هر ایده → اسکریپت → انتشار → تحلیل.
- یک نمونه خروجی واقعی (اسکریپت + کاور + آمار بعد از انتشار) را در `results/` نگه دارید.

## 🛠️ اشکال‌زدایی

- **Agent در `/agents` دیده نمی‌شود؟** فایل باید `.md` باشد با YAML frontmatter معتبر (داشته باشد `name:` و `description:`) و در مسیر `.claude/agents/` پروژه‌ای که `claude` را در آن اجرا می‌کنید.
- **Agent فایل می‌نویسد و اجازه نمی‌گیرد/رد می‌شود؟** Subagent نمی‌تواند پنجره اجازه (permission prompt) باز کند — فایل `.claude/settings.json` همین پوشه مجوز Write/Edit را در محدوده پروژه داده است؛ اگر پوشه را جدا کردید، آن را هم منتقل کنید.
- **نتایج ژنریک است؟** ۹۰٪ مواقع یعنی `brand/voice.md` ضعیف است — نمونه‌های واقعی خودتان را بیشتر کنید.
