# SpendZero — Finnish (fi) glossary

Tone: informal *sinä*, warm and playful, never preachy. Short UI labels.
Grammar rule: interpolated numbers/names must stay grammatical for ANY value. Prefer
"Label: %lld" or genitive compounds ("%lld päivän putki" works for 1 and 100), avoid case endings on %@
(names and month names stay in the nominative: "Paras kuukautesi: syyskuu", "Putki · %@").
Month names come from the system in the nominative ("syyskuu"), lowercase, so never sentence-initial.
Exception (deliberate): when %@ is ALWAYS a system month name (month(.wide)), a case ending is appended,
because all 12 Finnish month names end in "-kuu" and inflect identically: "Säästit %@ssa" → "Säästit syyskuussa",
"Sinetöit %@n." → "Sinetöit syyskuun.", "%@n kooste" → "syyskuun kooste" (verified against ICU: tammikuu … joulukuu).
Siri phrases keep ${applicationName} as a separate, uninflected word, addressed first: "${applicationName}, kirjaa ostos" (same style as out/shortcuts_fi.json).

| English | fi | Notes |
|---|---|---|
| no-spend challenge | ostolakko | "30 päivän ostolakko", "Tammikuun ostolakko" |
| no-spend day | ostoton päivä (pl. ostottomat päivät) | the Finnish name of Buy Nothing Day |
| no-spend streak | ostoton putki | |
| streak | putki ("%lld päivän putki", "Putki: %lld pv") | tab label "Putki" |
| streak freeze | putkenjäädytys (short: jäädytys) | 🧊 |
| seal (a day) / sealed | sinetöidä / sinetöity ("Sinetöi tämä päivä") | each sealed day = a gold coin |
| gold coin | kultakolikko | |
| mint (a coin) | lyödä (kolikko) | "Jokainen sinetöity päivä lyö kolikon" |
| Coin Vault (glass jar) | Kolikkopurkki (jar = purkki) | |
| Mint Calendar | Kolikkokalenteri | |
| wealth tree | rahapuu | (also the Finnish name of the jade plant) |
| XP | XP | |
| level / level up | taso / tasonnousu, nousta tasolle | "Taso %lld" |
| quest(s) | tehtävä(t) | Päivän tehtävät, Viikon tehtävä |
| challenge | haaste | |
| badge | merkki (pl. merkit) | |
| impulse buy / purchase | heräteostos | standard Finnish term |
| urge, impulse (logged item) | ostohimo (pl. ostohimot) | |
| resist / resisted | vastustaa / voittaa; "Vastustin!" | |
| gave in | sorruin / annoit periksi | |
| win(s) | onnistuminen / voitto | "voitot" avoided as a list label (reads as "profits") |
| kept (money not spent) | säästetty / säästit | "%@ säästetty" |
| savings | säästöt | "Säästetty yhteensä" |
| savings forecast | säästöennuste | |
| Monthly Recap | kuukausikooste | |
| spending / spent | kulutus, ostokset / käytetty | "Päivän ostokset", "Käytetty yhteensä" |
| log (verb) | kirjata ("Kirjaa ostos") | tab label "Päiväkirja" |
| budget / daily budget | budjetti / päiväbudjetti | |
| essentials | välttämättömyydet | |
| Lock Screen / Dynamic Island | lukitusnäyttö / Dynamic Island | Apple's fi terms |
| Home Screen | Koti-valikko | Apple's fi term |
| Premium / Pro | Premium / Pro | unchanged |
| free trial | ilmainen kokeilu | "%lld päivän ilmainen kokeilu" |

## Rank names (levels 1–25)
1 Säästöalokas · 2 Penninvenyttäjä · 3 Budjettivahti · 4 Rahatietoinen · 5 Talouden turvaaja ·
6 Säästövartija · 7 Vaurauden rakentaja · 8 Onnensa seppä · 9 Kullanhuuhtoja · 10 Aarteenmetsästäjä ·
11 Platinamestari · 12 Timanttipuolustaja · 13 Nouseva tähti · 14 Johtotähti · 15 Säteilevä · 16 Huippu ·
17 Tunturi · 18 Monumentti · 19 Titaani · 20 Kilpi · 21 Valtias · 22 Ylväs · 23 Ylivertainen ·
24 Keisarillinen · 25 Rahakuningas

## Tree stages
Seedling → Itu · Sprout → Taimi · Young Tree → Nuori puu · Tall Tree → Korkea puu · Full Palm → Komea palmu
