# 🔍 بررسی تخصصی سند «AI Content Team OS»

> بررسی‌کننده: Agent Mode (Arena.ai) — سپتامبر ۲۰۲۶
> سند منبع: Google Docs — @academymoghimi — «۷ کارمند هوش مصنوعی با Subagentهای Claude Code»

---

## ۱) خلاصه اجرایی

| معیار | امتیاز | توضیح |
|---|---|---|
| ایده و معماری | ⭐ 9/10 | الگوی in-memory team + human-in-the-loop عالی است |
| دقت فنی | ⭐ 6/10 | یک ایراد معماری جدی (Manager) + چند غفلت اجرایی |
| اجرایی‌بودن «همین امروز» | ⭐ 5/10 | با متن سند به‌تنهایی نصف راه گیر می‌کنید |
| امنیت و کم‌هزینه‌بودن | ⭐ 7/10 | نقاط تأیید انسانی درست است؛ هزینه و مجوزها نادیده گرفته شده |
| **جمع‌بندی** | **7.5/10** | ارزش پیاده‌سازی دارد — **با اصلاحات این سند** |

**پیام اصلی:** معماری و mindset سند درست و باکلاس است، اما ۳ ایراد فنی جدی دارد که اگر ندانید، سیستم یا اجرا نمی‌شود یا نتیجه بد می‌دهد. هر سه در نسخه‌ای که برایتان ساختم (`content-team-os/`) اصلاح شده‌اند.

---

## ۲) این سیستم چیست؟

سند یک «تیم محتوای مجازی» تعریف می‌کند: هر «کارمند» یک فایل Markdown در `.claude/agents/` کلود کد است (Subagent) با نقش، ابزار و System Prompt مشخص. جریان کار:

```
Research → Hook Writer → Script Writer → Designer
     ↑                                        ↓
Analyst ← شما (سردبیر ارشد) تأیید می‌کنید ← Publisher
```

Manager هماهنگ می‌کند، شما در ۲ نقطه تأیید می‌دهید، و Analyst نتیجه‌ها را به تحقیق بعدی تزریق می‌کند. پایپلاین روی فایل‌های ساده (`ideas.md`, `calendar.md`, `performance.md`) سوار است.

---

## ۳) نقاط قوت — چیزهایی که از نظر مهندسی درست است ✅

1. **Human-in-the-loop درست طراحی شده.** دو GATE (بعد از ایده‌ها، بعد از پیش‌نویس) + «انتشار فقط با go دستی». این دقیقاً الگوی توصیه‌شده برای عامل‌های تولیدمحتواست و خطر انتشار بی‌کیفیت/اشتباه را حذف می‌کند.
2. **State روی فایل، نه دیتابیس.** `ideas.md` و `performance.md` یعنی قابلیت audit، git-friendly، بدون وابستگی به سرویس خارجی. برای یک نفر بهترین انتخاب است.
3. **قرنطینه context.** هر Subagent context window مستقل دارد — تحقیق حجیم، کانتکست نویسنده هوک را شلوغ نمی‌کند. این مزیت واقعی معماری multi-agent در Claude Code است.
4. **ضد توهم (anti-hallucination) در System Promptها.** «هرگز آمار نساز»، «فقط ساختار رقبا، نه محتوا»، «تحلیل فقط از اعداد واقعی» — سه قانون طلایی که خیلی از promptهای مشابه ندارند.
5. **شروع سبک.** «فقط Web Search + Filesystem برای شروع» توصیه هوشمندانه‌ای است؛ باقی MCPها اضافی‌اند تا وقتی چرخه کار کند.
6. **فایل voice.md.** تمرکز روی «صدای خودت» دقیقاً راه‌حل مشکل شماره یک محتوای AI یعنی ژنریک‌بودن است.

---

## ۴) ایرادهای فنی — به ترتیب شدت 🔴🟠🟡

### 🔴 ایراد ۱ — «Manager» به‌صورت Subagent اصلاً کار نمی‌کند (مهم‌ترین ایراد)
سند ۷ فایل در `.claude/agents/` می‌سازد که یکی‌شان `manager.md` است و «با یک دستور، ۶ Agent دیگر را صدا می‌زند». این **غیرممکن** است:

- Subagentها به ابزار Task/Agent دسترسی ندارند؛ یعنی یک Subagent نمی‌تواند Subagent دیگری بسازد. این محدودیت مستند و by-design است (جلوگیری از بازگشت بی‌نهایت) — [GitHub issue #60763](https://github.com/anthropics/claude-code/issues/60763)، [#4182](https://github.com/anthropics/claude-code/issues/4182).
- نتیجه: اگر به Manager-Subagent بگویید «۳ ریل بساز»، در بهترین حالت خودش دستی همه‌کار را می‌کند و نقش بقیه تیم فیک می‌شود.

**✅ راه‌حل درست (در نسخه من پیاده شده):** نقش Manager را **session اصلی** بازی می‌کند — `CLAUDE.md` او را Manager/Producer تعریف می‌کند و او به‌ترتیب به ۶ Subagent کار می‌دهد (fan-out از root، orchestration یک‌سطحی — الگوی استاندارد).

### 🔴 ایراد ۲ — Subagentها نمی‌توانند اجازه (permission) بگیرند → نوشتن فایل‌ها رد می‌شود
- Subagentها نمی‌توانند پنجره «اجازه می‌دهید؟» را به شما نشان دهند؛ اگر ابزار با قاعده ask بخورد، **به‌صورت خودکار deny می‌شود**.
- سند فرض کرده هر Agent آزادانه در `pipeline/` فایل می‌نویسد — با تنظیمات پیش‌فرض Claude Code، این کارها می‌گیرند و پایپلاین وسط راه می‌خوابد.

**✅ راه‌حل (پیاده شده):** فایل `.claude/settings.json` با allowlist حداقلی: `Write(./**)` و `Edit(./**)` فقط داخل پروژه + `WebSearch`/`WebFetch`. هر Agent هم طبق اصل **کمترین دسترسی** فقط ابزار لازمش را دارد (مثلاً hook-writer فقط `Read` — هوک را در چت برمی‌گرداند، فایل نمی‌نویسد). برای audit هم کل پوشه زیر git است.

### 🟠 ایراد ۳ — فرمت فایل‌های Agent ناقص است
سند می‌گوید «هر فایل Markdown شامل نام، توضیح و System Prompt». در واقع فرمت رسمی این است که فایل باید **YAML frontmatter** داشته باشد و فیلد `description` فقط توضیح نیست — **سیگنال routing** است: Claude اصلی با خواندن آن تصمیم می‌گیرد چه کاری به کدام Agent برود:

```markdown
---
name: research
description: Finds content ideas ... Use when brainstorming ... (کلیدواژه‌های ماشه‌ای بنویسید)
tools: WebSearch, WebFetch, Read, Write, Edit
model: sonnet          ← اختیاری: کنترل هزینه
---
System Prompt اینجا
```

در نسخه من، descriptionها با کلیدواژه‌های ماشه‌ای نوشته شده‌اند تا delegation خودکار درست کار کند.

### 🟠 ایراد ۴ — واقعیت MCPها کمی صورتی‌تر از سند است
- **Canva MCP** واقعی است (`mcp.canva.com/mcp`) ولی فقط **ساخت/ویرایش طرح** است — انتشار ندارد؛ برای «Thumbnail خودکار» هم محدود است.
- **زمان‌بندی/انتشار:** گزینه‌های واقعی: **Postiz** (اوپن‌سورس، self-host رایگان، ۱۱ ابزار MCP از جمله schedulePost)، **Metricool MCP** (رسمی، آنالیتیکس + زمان‌بندی)، **Buffer MCP** (رسمی ولی فقط ساخت پیش‌نویس). انتشار مستقیم اینستاگرام/تیک‌تاک از API رسمی برای اکانت عادی عملاً بسته است — پس طراحی «Publisher فقط آماده می‌کند و شما دکمه را می‌زنید» که سند دارد **درست است و باید بماند**.
- **YouTube transcript** به‌راحتی با WebFetch درنمی‌آید؛ اگر لازم شد، یک MCP ترنسکریپت یا `youtube-transcript-api` اضافه کنید.

### 🟡 ایراد ۵ — هزینه و مصرف توکن نادیده گرفته شده
هر Subagent context مستقل دارد؛ پایپلاین چندمرحله‌ای می‌تواند تا **~۷ برابر** حالت تک‌نخ توکن مصرف کند. راه‌های کنترل (در README هم هست): شروع با ۱ بچ در هفته، مدل سبک‌تر (`model: haiku`) برای Agentهای ساده، و برگرداندن خلاصه از Agentها به‌جای متن کامل.

### 🟡 ایراد ۶ — «Scheduled Claude Code Task» مبهم است
اتوماسیون هفتگی Analyst با خود Claude Code ساده‌ترین راه نیست؛ راه درست: **cron / GitHub Actions** که هفته‌ای یک‌بار `claude -p "Analyst, weekly review"` را headless اجرا کند. (فعلاً دستی هم کافی است.)

### 🟡 ایراد ۷ — نکات کوچک ولی مؤثر
- ادعای «ساخت در ۳۰ دقیقه» برای **ساختار** درست است؛ اما کیفیت خروجی به `voice.md` شما بستگی دارد — برای نتیجه واقعی چند روز تیونینگ لازم است.
- تحویل خروجی Subagent فقط «یک پیام نهایی» است؛ مکانیزم ثبت خروجی در فایل باید صریح باشد (در promptهای نسخه من، قرارداد ورودی/خروجی هر Agent مشخص شده).
- زبان: اگر محتوای شما فارسی است، در `CLAUDE.md` زبان خروجی را `fa` بگذارید و نمونه‌های voice.md فارسی باشند — promptهای سیستمی را همیشه انگلیسی نگه دارید (پیروی بهتر مدل).

---

## ۵) واقعیت‌سنجی ادعاهای سند

| ادعا | حکم |
|---|---|
| «۷ کارمند» | ✅ استعاره درست — در واقع ۶ Subagent + ۱ Orchestrator |
| ساخت در ۳۰ دقیقه | ⚠️ برای اسکلت بله؛ برای خروجی باکیفیت، تیونینگ voice.md لازم است |
| Subagentها خودکار ساخته می‌شوند | ✅ درست، به‌شرط frontmatter معتبر |
| Manager همه را هماهنگ می‌کند | ❌ فقط از session اصلی ممکن است |
| Publisher زمان‌بندی می‌کند | ⚠️ فقط با MCP شخص ثالث (Postiz/Metricool) و به‌صورت draft |
| هرگز بدون go منتشر نمی‌کند | ✅ درست و حیاتی — نگهش دارید |
| شروع با Web Search + Filesystem | ✅ توصیه درست |

---

## ۶) امنیت و ملاحظات حقوقی ⚖️

1. **کلیدهای API** هرگز داخل `.mcp.json` کامیت نشوند — این ریپو `.mcp.json.example` با placeholder دارد؛ `.mcp.json` واقعی را `.gitignore` کنید.
2. **اسکرپ رقبا:** برای مطالعه ساختار OK؛ کپی محتوا نه. از ابزارهای رسمی (APIها) استفاده کنید نه اسکرپ تهاجمی.
3. **قوانین پلتفرم:** انتشار با APIهای غیررسمی خلاف ToS اینستاگرام/تیک‌تاک است و ریسک محدودسازی اکانت دارد — به همین دلیل Publisher این سیستم فقط «آماده‌سازی + draft» است.
4. **شفافیت:** خیلی از پلتفرم‌ها برچسب‌گذاری محتوای AI-generated را می‌خواهند؛ در صورت استفاده از_assets تولیدی، برچسب بزنید.
5. **دسترسی‌ها:** اجازه Bash به هیچ Agent داده نشده (نیازی ندارند) — سطح حمله کم می‌ماند.

---

## ۷) چه چیزهایی نسبت به سند اصلی بهتر شد؟

| مورد | سند اصلی | نسخه اجرایی این ریپو |
|---|---|---|
| Orchestrator | manager.md به‌عنوان Subagent ❌ | CLAUDE.md؛ session اصلی = Manager ✅ |
| فرمت Agent | Markdown ساده | frontmatter + description ماشه‌ای + tools حداقلی ✅ |
| مجوزها | هیچ | `.claude/settings.json` با allowlist scoped ✅ |
| قرارداد ورودی/خروجی Agent | کلی | صریح در هر prompt (کدام فایل، کدام ستون، چه status) ✅ |
| Lifecycle ایده | ذکر نشده | `proposed→…→analyzed` در ideas.md ✅ |
| Hook output | نامشخص | هوک در چت ثبت می‌شود؛ انتخاب در ideas.md ✅ |
| Anti-hallucination | کلی | `[NEEDS SOURCE]` + الزام URL + مقایسه درون-فرمت در Analyst ✅ |
| زبان خروجی | نامشخص | پرچم `fa/en` در CLAUDE.md ✅ |
| MCP | فهرست کلی | `.mcp.json.example` آماده با URLهای رسمی ✅ |

---

## ۸) نقشه راه اجرایی پیشنهادی برای شما

**فاز ۰ — امروز (۱۵ دقیقه):** پوشه را کپی، `CLAUDE.md` و `brand/voice.md` را پر کنید، `/agents` را چک کنید، یک ریل تست بسازید.
**فاز ۱ — هفته ۱:** ۳ پست واقعی با پایپلاین؛ آمار دستی در performance.md؛ یک weekly review.
**فاز ۲ — هفته ۲–۳:** Canva MCP را وصل کنید؛ ریتم هفتگی را بر اساس Analyst تنظیم کنید؛ swipe-file را با outlierهای رقبا پر کنید.
**فاز ۳ — ماه ۲:** Postiz یا Metricool برای draft زمان‌بندی؛ اتوماسیون weekly review با cron/CI؛ در صورت نیاز MCP ترنسکریپت یوتیوب برای Research.
**پارالل — پورتفولیو:** معماری + یک case study واقعی (ایده → اسکریپت → خروجی → آمار) را ارائه دهید؛ تاریخچه git همین پوشه خودش شاهد فرایند است.

---

## ۹) منابع کلیدی

- Subagentها: frontmatter، ایزولاسیون context، عدم prompt اجازه — [مرجع فیچرهای Claude Code 2026](https://hidekazu-konishi.com/entry/claude_code_features_settings_reference_2026.html)، [راهنمای عملی](https://nimbalyst.com/blog/claude-code-subagents-guide/)
- عدم امکان Subagent تو در تو — [issue #60763](https://github.com/anthropics/claude-code/issues/60763)، [issue #4182](https://github.com/anthropics/claude-code/issues/4182)، [تحلیل Task vs Subagents](https://amitkoth.com/claude-code-task-tool-vs-subagents/)
- مصرف توکن چند Subagent — [nimbalyst](https://nimbalyst.com/blog/claude-code-subagents-guide/)
- MCPهای شبکه اجتماعی — [مقایسه ۹ سرور](https://www.blotato.com/blog/best-social-media-mcp-servers)، [مقایسه Sprout/Buffer/Metricool/Postiz](https://www.plugkit.co/blog/social-media-mcp-servers-compared/)، [Canva MCP](https://mcp.so/servers/canva)
