# SpendZero App Store listing brief (for localizers)

Source of truth: localization/listing_en-US.json (English master). Current live localized metadata for reference:
/private/tmp/claude-501/-Users-robgoldstein-Desktop-SpendZero-NoSpend/90a4176c-9a65-4381-a41e-1315d75484c2/scratchpad/listing_current.json

App: SpendZero — a no-spend challenge app. Users mark "no-spend days", build streaks (with streak freezes),
earn XP, level up (25 levels), complete quests and challenges, earn badges, log/resist impulse purchases,
and grow a unique "wealth tree" that bears gold coins. Each no-spend day is "sealed" with a golden coin.
Interactive Home/Lock Screen widgets, Siri/Shortcuts, evening check-in reminders. 100% on-device, no account,
no ads, no tracking. Subscriptions: weekly/monthly/yearly + lifetime; monthly & yearly may include a 3-day free
trial for eligible new subscribers. Available in: English, Spanish, French, German, Dutch, Italian, Portuguese,
Turkish, Japanese, Chinese.

## Output
For each locale write localization/listing_<locale>.json with keys:
name, subtitle, keywords, promotionalText, description, whatsNew, screenshot_captions
- name ≤ 30 chars, MUST start with "SpendZero" (e.g. "SpendZero: <localized hook>").
- subtitle ≤ 30 chars.
- keywords ≤ 100 characters total, comma-separated, NO spaces after commas, no word that already appears in
  name or subtitle (they're indexed already), no competitor brand names, no "app"/"free"/"iphone", no plurals
  when the singular is present. Single words beat phrases (the store combines them).
- promotionalText ≤ 170 chars. description ≤ 4000 chars (aim ~2,000–2,600). whatsNew ≤ 1,000.
- Keep the description's structure and facts from the English master (do NOT invent claims, stats or
  testimonials). Keep the SUBSCRIPTIONS paragraph accurate and the two legal links verbatim. Write natively for
  the market — not a literal translation. Keep the "Available in …" languages line, translated.
- screenshot_captions: exactly 7 short ALL-CAPS captions (max ~22 characters per line, max 3 lines; use "\n"
  for line breaks) for these slides, in order:
  1 Day Sealed coin moment ("SEAL EVERY\nNO-SPEND DAY")
  2 Wealth tree ("GROW YOUR\nWEALTH TREE")
  3 Dashboard streak ("BUILD A\nNO-SPEND STREAK")
  4 Quests ("COMPLETE QUESTS,\nEARN XP")
  5 Badge unlock ("UNLOCK BADGES\n& LEVELS")
  6 Impulse log ("CRUSH\nIMPULSE BUYS")
  7 Streak calendar ("SEE EVERY\nDAY YOU WIN")
  For CJK, captions may be shorter lines (~10 chars/line).

## Keyword research (required, READ-ONLY web requests only)
Use the public iTunes Search API to pick keywords for the locale's storefront, e.g.:
  curl -s "https://itunes.apple.com/search?term=<term>&country=<cc>&entity=software&limit=25"
Look at result counts and the top apps' titles for 10–20 candidate terms native speakers would type
(e.g. "no spend", "no buy", saving challenge, budget, impulse buying, money saving, frugal, habit tracker…
in the local language). Prefer terms with real competitor presence (people search it) where a small app can
plausibly rank. Note in your final report the terms you chose and why, and 1–2 you rejected.
Do NOT call any App Store Connect API, do NOT modify anything outside localization/, do NOT run git.

Validate each JSON with a python script (lengths; name starts with SpendZero; keywords ≤100 chars and no
comma-space; no keyword word duplicated in name/subtitle; 7 captions).
