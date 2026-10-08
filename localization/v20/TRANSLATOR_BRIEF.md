# SpendZero 2.0 — app translation brief

SpendZero is an iPhone no-spend challenge app. Users mark "no-spend days" (days with no non-essential spending),
build streaks, earn XP, level up (25 levels with rank names), complete quests and challenges, earn badges, log and
resist impulse purchases, and grow a "wealth tree". Each no-spend day is "sealed" with a gold coin. 2.0 adds:
a Coin Vault (a glass jar that fills with physics coins, one per sealed day), a Mint Calendar (a year of gold coins),
a savings forecast, a Monthly Recap story (Instagram-story style), a Lock Screen / Dynamic Island countdown
("3h left to seal today", Live Activity), Control Center + Siri actions, a living wealth tree (day/night, seasons,
December lights), unlockable app icons (Gold, Emerald, Midnight) and a "More from GW Labs" list of the developer's apps.
Tone: warm, encouraging, playful, never preachy or shaming about money. Short UI labels. Second person, informal
where the language has an informal register that consumer apps use (de: du, fr: tu, es: tú, it: tu, pt: você (BR) /
tu (PT), nl: je, sv/da/nb/fi: informal, ko: friendly 해요체, ja: polite but light です/ます for sentences, short nouns
for labels, zh: 你).

Rob (the owner) insists every language reads NATIVELY for its market: never literal word-for-word translation.
Use the words people in that country actually use for saving money, no-buy challenges, streaks, etc.

## Your input
`localization/v20/todo/<lang>.json`:
- `Localizable`: { key: { "en": English text, "comment": translator note (may be empty), "source": Swift file } }
  The KEY is the English source (it may contain format specifiers). Translate the "en" value.
- new languages only: `plurals` (stringsdict entries; give one form per category in `plural_categories`),
  `InfoPlist` (Home Screen quick-action titles), `AppShortcuts` (Siri phrases).
For consistency, EXISTING languages must reuse the terminology already in `Resources/<lang>.lproj/Localizable.strings`
(read it first: rank names, "no-spend day", "seal", "streak", "wealth tree", "quests", "XP", tab names...).
NEW languages: before translating, write a short glossary (10–30 core terms) at
`localization/v20/glossary_<lang>.md`, then apply it everywhere. Look at how zh-Hans / ja / de handle terms for ideas.

## Your output
`localization/v20/out/<lang>.json`:
{ "Localizable": { "<exact key>": "<translation>", ... },
  "plurals": { "<key>": { "<category>": "<text with the same %lld/%@ specifiers>" } },   // new languages only
  "InfoPlist": { "<key>": "<translation>" }, "AppShortcuts": { "<key>": "<translation>" } }   // new languages only
Rules:
- Keep every format specifier exactly (same count and type: %@, %lld, %d, %.0f...). You may reorder with positional
  forms (%1$@, %2$lld) when grammar needs it. Keep "\n" line breaks where the English has them.
- Never translate product names: SpendZero, GW Labs, Lighthouse, WishLock, Places I've Visited, CalmAnchor, Siri, Face ID.
  "Pro" stays "Pro". Keep emoji as in the English.
- Siri phrases (AppShortcuts) MUST contain the literal token ${applicationName} and be natural spoken requests.
- Currency amounts inside strings (e.g. "$50") — keep the number, use the market's normal currency style only if the
  string is plainly an example; otherwise keep as is.
- Keep UI labels about as short as the English (buttons, tabs, chips). Lines in the Lock Screen countdown must be short.
- Write the JSON with a script (python json.dump, ensure_ascii=False) to avoid escaping mistakes.

## Check your work
Run `python3 tools/l10n20.py validate <lang>` until it reports 0 errors. Then do a second pass reading your
translations as a native user would see them in the app: fix anything stiff, literal, too long, or inconsistent.
Do NOT run `merge` (the coordinator does). Do NOT edit anything outside localization/v20/ . Do NOT run git,
xcodebuild, simulators, or App Store Connect calls (the Mac is overloaded). Report: languages done, error count,
glossary choices, and any keys you were unsure about.
