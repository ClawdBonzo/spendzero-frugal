# SpendZero 2.0 — App Store copy brief

Read first: `localization/LISTING_BRIEF.md` (rules for name/subtitle/keywords/description, keyword research method with
the public iTunes Search API) and `localization/v20/TRANSLATOR_BRIEF.md` (what the app is, 2.0 features, tone).
English masters: `localization/listing_en-US.json` (1.3 listing) — you will write 2.0 versions.
Rob insists every locale reads NATIVELY and is optimized for THAT market's searches; never literal translation.
Facts you may claim: no ads, no account, no bank linking, data stored on the iPhone, works with Siri, widgets, Lock
Screen Live Activity, Control Center control, 25 levels, quests, badges, streak freezes, wealth tree, Coin Vault,
Mint Calendar, savings forecast, Monthly Recap, unlockable app icons. Subscriptions: weekly, monthly, yearly + lifetime;
monthly & yearly may include a 3-day free trial for eligible new subscribers. Do NOT invent stats, ratings, awards or
testimonials. Keep the legal links verbatim (Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ ,
Privacy: https://gwlabs.app/privacy).

App languages in 2.0 (18): English, German, Spanish, French, Italian, Dutch, Portuguese, Turkish, Japanese,
Simplified Chinese, Traditional Chinese, Korean, Swedish, Danish, Norwegian, Finnish (+ Canadian French, European
Portuguese variants). The description's "Available in ..." line must list these, translated.
For LISTING-ONLY locales (the app itself is NOT translated into that language) the description must say so honestly,
e.g. "The app is available in English and 17 other languages" — never imply the app is in that language.

## 2.0 What's New (all locales)
Highlights, in order: Coin Vault (every sealed day drops a gold coin into a glass jar you can tilt), Mint Calendar
(your whole year in gold coins) + new charts, savings forecast, Monthly Recap story you can share, Lock Screen and
Dynamic Island countdown to seal today + Control Center and Siri, the wealth tree now lives in real time (day and
night, seasons, December lights), unlock Gold/Emerald/Midnight app icons as you level up, sound effects and haptics,
now in 18 languages. ≤ 4000 chars but aim for ~500–700, bullet list, native tone.

## Output: `localization/v20/listing_<ascLocale>.json`
{ "name", "subtitle", "keywords", "promotionalText", "description", "whatsNew",
  "iap": { "group": "...", "weekly": {"name","description"}, "monthly": {...}, "yearly": {...}, "lifetime": {...} } }
- iap names ≤ 30 chars, descriptions ≤ 45 chars; a name must NEVER equal its description (Apple rejected us for that);
  each product's name and description must be distinct from the other products'.
- Existing locales: start from `localization/listing_<locale>.json`; keep name/subtitle/keywords unless you find a
  clearly better market-specific option via keyword research (explain in your report); refresh the description so the
  2.0 features appear in the first lines; new whatsNew; new promotionalText (≤170) about 2.0.
- Also write `localization/v20/promo_<ascLocale>.json` with the seasonal promotional texts for NEW locales only, same
  keys as an existing entry in `localization/promo14.json` ("now","bf","dec","jan", and any others there), adapted to
  the market (skip Black Friday wording where the market doesn't use it; keep it about no-spend challenges).
- Keywords for US-indexed listing-only locales (ru, vi): use them for English long-tail terms NOT already in en-US,
  es-MX, zh-Hans, fr-FR, pt-BR keywords (the US store indexes these locales too). ar-SA: Arabic keywords for the Gulf.
- Validate: name starts with "SpendZero", lengths, keywords ≤100 chars, no ", " (comma-space), no keyword word already in
  name/subtitle. Write JSON with python (ensure_ascii=False).
Do NOT call App Store Connect, do NOT run git/xcodebuild/simulators, do NOT edit outside localization/v20/.
Report per locale: chosen keywords and the 1–2 reasons, plus anything you were unsure about.
