# Prompts to paste into other threads

## A. Into EACH other 4+ GW Labs app's Claude Code thread
(WishLock, Lighthouse, CalmAnchor, Places I've Visited, Throne Score, Maxx)

```text
Add SpendZero to this app's "More from GW Labs" cross-promotion.

SpendZero: App Store id 6761767438, URL scheme "spendzero", rated 4+.
Pitch (adapt the wording to this app's audience): "A no-spend challenge: every day you don't spend becomes a gold coin."

1. If this app already has a cross-promo list (More from GW Labs / More from us / house ads), add SpendZero as a row:
   - Bundle a 512 px icon. Get it from the SpendZero repo at ~/Desktop/SpendZero-NoSpend/SpendZero/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png and copy it in; don't change that repo.
   - Add "spendzero" to LSApplicationQueriesSchemes and hide the row when SpendZero is installed.
   - Open the App Store sheet in-app (SKStoreProductViewController or SKOverlay) with provider token 117201882 and campaign "house-<thisapp>". Fall back to https://apps.apple.com/app/apple-store/id6761767438?pt=117201882&ct=house-<thisapp>&mt=8.
2. If there's no list yet, add a "More from GW Labs" section in Settings, using the same pattern as SpendZero's
   ~/Desktop/SpendZero-NoSpend/SpendZero/Views/Settings/MoreFromGWLabs.swift (read-only reference).
3. Translate the pitch into every language this app supports, keep the build passing, and commit. Ship it with this app's next update; don't submit a release just for this.
Never cross-promote from or to the 12+ and 17+ apps.
```

## B. Into the GW Labs website thread (Manus): press page

```text
Add a press kit page for SpendZero at /spendzero-press.html (exact-file routing, like /spendzero.html). Include:
- the app icon, a one-paragraph description, and 5 key facts: no account, no bank linking, no ads, 16 languages, iPhone;
- download links for 6 screenshots (taken from the existing SpendZero page assets);
- the App Store badge linking to https://apps.apple.com/app/apple-store/id6761767438?pt=117201882&ct=press&mt=8;
- press contact: "press@gwlabs.app" (or Rob's preferred address);
- a short "No-Spend January" story angle.
Link it from the footer of /spendzero.html and add it to the sitemap.
```
