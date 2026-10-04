#!/usr/bin/env python3
"""SpendZero 2.0 App Store screenshots (10 frames, 1320x2868, one continuous canvas).

  capture <set>...   launch the DEBUG build in the screenshot simulator and save raw captures
  crops <set>...     cut the enlarged close-ups (vault stats, forecast, calendar, impulses, trees, quests)
  render <locale>... fill localization/v20/screenshots_template.html with captions_<locale>.json,
                     render it with headless Chrome and write screenshots/v20/<locale>/01-10.jpg

A capture <set> is an app language plus region (see SETS); every App Store locale maps to one set.
Listing-only locales (the app isn't translated) use the en_US set.
"""
import json, os, re, subprocess, sys, time
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.environ.get("SHOTS_WORK", "/private/tmp/claude-501/-Users-robgoldstein-Desktop-SpendZero-NoSpend/90a4176c-9a65-4381-a41e-1315d75484c2/scratchpad/shots")
UDID = open(f"{WORK}/udid.txt").read().strip()
BID = "com.clawdbonzo.SpendZero"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

SETS = {  # set: (AppleLanguages, AppleLocale)
    "en_US": ("en", "en_US"), "en_GB": ("en-GB", "en_GB"), "de": ("de", "de_DE"), "es_ES": ("es", "es_ES"),
    "es_MX": ("es-MX", "es_MX"), "fr": ("fr", "fr_FR"), "fr_CA": ("fr-CA", "fr_CA"), "it": ("it", "it_IT"),
    "ja": ("ja", "ja_JP"), "nl": ("nl", "nl_NL"), "pt_BR": ("pt-BR", "pt_BR"), "pt_PT": ("pt-PT", "pt_PT"),
    "tr": ("tr", "tr_TR"), "zh_CN": ("zh-Hans", "zh_CN"), "zh_TW": ("zh-Hant", "zh_TW"), "ko": ("ko", "ko_KR"),
    "sv": ("sv", "sv_SE"), "da": ("da", "da_DK"), "nb": ("nb", "nb_NO"), "fi": ("fi", "fi_FI"),
}
LOCALE_SET = {
    "en-US": "en_US", "en-AU": "en_US", "en-CA": "en_US", "en-GB": "en_GB", "de-DE": "de", "es-ES": "es_ES",
    "es-MX": "es_MX", "fr-FR": "fr", "fr-CA": "fr_CA", "it": "it", "ja": "ja", "nl-NL": "nl", "pt-BR": "pt_BR",
    "pt-PT": "pt_PT", "tr": "tr", "zh-Hans": "zh_CN", "zh-Hant": "zh_TW", "ko": "ko", "sv": "sv", "da": "da",
    "no": "nb", "fi": "fi",
}
RTL = {"ar-SA", "he"}

SEED = ["-SeedDemoData"]
SHOTS = [  # name, args, wait seconds
    ("sealed", SEED + ["-ShowDaySealed"], 8.5),
    ("vault", SEED + ["-ScrollToVault"], 11),
    ("forecast", ["-hasCompletedOnboarding", "NO", "-ShowForecast"], 10),
    ("calendar", SEED + ["-InitialTab", "calendar"], 9),
    ("impulses", SEED + ["-InitialTab", "logger", "-LogSegment", "1"], 9),
    ("tree_dec_night", SEED + ["-InitialTab", "gamification", "-ScrollToTree", "-TreeSeason", "december", "-TreeHour", "20.5"], 11),
    ("tree_spring_day", SEED + ["-InitialTab", "gamification", "-ScrollToTree", "-TreeSeason", "spring", "-TreeHour", "10"], 11),
    ("tree_autumn", SEED + ["-InitialTab", "gamification", "-ScrollToTree", "-TreeSeason", "autumn", "-TreeHour", "17.5"], 11),
    ("recap0", SEED + ["-ShowRecap", "-RecapCard", "0"], 9),
    ("recap1", SEED + ["-ShowRecap", "-RecapCard", "1"], 9),
    ("recap3", SEED + ["-ShowRecap", "-RecapCard", "3"], 9),
    ("levelup", SEED + ["-ShowLevelUp"], 8),
    ("quests", SEED + ["-InitialTab", "gamification"], 9),
]


def sh(*a, timeout=60):
    try:
        return subprocess.run(a, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        print("  timeout:", " ".join(a[:4]), flush=True)
        return None


def capture(set_name, only=None):
    lang, region = SETS[set_name]
    out = f"{WORK}/raw_{set_name}"
    os.makedirs(out, exist_ok=True)
    for name, args, wait in SHOTS:
        if only and name not in only:
            continue
        for attempt in range(2):
            sh("xcrun", "simctl", "terminate", UDID, BID)
            time.sleep(1)
            sh("xcrun", "simctl", "launch", UDID, BID, "-AppleLanguages", f"({lang})", "-AppleLocale", region, *args)
            time.sleep(wait)
            r = sh("xcrun", "simctl", "io", UDID, "screenshot", f"{out}/{name}.png")
            if r and r.returncode == 0 and not looks_like_splash(f"{out}/{name}.png"):
                break
            print(f"  retry {set_name}/{name}", flush=True)
        print(f"{set_name}: {name}", flush=True)
    sh("xcrun", "simctl", "terminate", UDID, BID)


def looks_like_splash(path):
    """The launch screen is a flat bright green; a real capture never is."""
    try:
        im = Image.open(path).convert("RGB").resize((20, 40))
        px = list(im.getdata())
        green = sum(1 for r, g, b in px if g > 200 and r < 60 and b < 140)
        return green > len(px) * 0.6
    except Exception:
        return True


CROPS = {  # asset: (raw, box)
    "vault_stats": ("vault", (45, 2015, 1275, 2310)),
    "forecast_big": ("forecast", (60, 560, 1260, 900)),
    "calendar_card": ("calendar", (30, 540, 1290, 2020)),
    "impulse_rows": ("impulses", (45, 1010, 1275, 1630)),
    "quest_rows": ("quests", (60, 590, 1260, 1410)),
    "tree_dec_night": ("tree_dec_night", (144, 483, 1176, 1284)),
    "tree_spring_day": ("tree_spring_day", (144, 483, 1176, 1284)),
    "tree_autumn": ("tree_autumn", (144, 483, 1176, 1284)),
}


def gold_rows(path, top, bottom):
    """First and last row in [top, bottom) where the big gold forecast number is drawn."""
    im = Image.open(path).convert("RGB")
    rows = []
    for y in range(top, bottom, 4):
        n = sum(1 for x in range(60, 1260, 6) if (lambda p: p[0] > 200 and p[1] > 160 and p[2] < 120)(im.getpixel((x, y))))
        if n > 12:
            rows.append(y)
    if not rows:
        return None
    end = rows[0]
    for y in rows[1:]:  # first contiguous block only (the chart below also has gold)
        if y - end > 24:
            break
        end = y
    return rows[0], end


def crops(set_name):
    raw, out = f"{WORK}/raw_{set_name}", f"{WORK}/assets_{set_name}"
    os.makedirs(out, exist_ok=True)
    for asset, (src, box) in CROPS.items():
        if asset == "forecast_big":  # the headline above it changes height per language
            g = gold_rows(f"{raw}/{src}.png", 300, 1200)
            if g:
                box = (60, max(0, g[0] - 120), 1260, min(2868, g[1] + 135))
        Image.open(f"{raw}/{src}.png").crop(box).save(f"{out}/{asset}.png")
    print(f"{set_name}: crops done", flush=True)


def fill(template, cap):
    def get(path):
        cur = cap
        for part in path.split("."):
            cur = cur[int(part)] if isinstance(cur, list) else cur[part]
        return cur

    def sub(m):
        v = get(m.group(1))
        return v.replace("<g>", '<span class="g">').replace("</g>", "</span>")

    return re.sub(r"\{\{([a-z0-9_.]+)\}\}", sub, template)


def render(locale):
    set_name = LOCALE_SET.get(locale, "en_US")
    cap = json.load(open(f"{ROOT}/localization/v20/captions_{'en' if locale == 'en-US' else locale}.json"))
    t = open(f"{ROOT}/localization/v20/screenshots_template.html").read()
    t = t.replace("{{RAW}}", f"raw_{set_name}").replace("{{ASSETS}}", f"assets_{set_name}").replace("{{SHARED}}", "assets")
    t = t.replace("{{BODYCLASS}}", ("rtl" if locale in RTL else "") + (" nospace" if locale in ("hi", "th") else ""))
    html = fill(t, cap)
    page = f"{WORK}/page_{locale}.html"
    open(page, "w").write(html)
    png = f"{WORK}/full_{locale}.png"
    if os.path.exists(png):
        os.remove(png)
    sh(CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
       "--force-device-scale-factor=1", "--window-size=13200,2868", "--virtual-time-budget=8000",
       f"--screenshot={png}", f"file://{page}", timeout=900)
    im = Image.open(png).convert("RGB")
    dest = f"{ROOT}/screenshots/v20/{locale}"
    os.makedirs(dest, exist_ok=True)
    for i in range(10):
        im.crop((i * 1320, 0, (i + 1) * 1320, 2868)).save(f"{dest}/{i + 1:02d}.jpg", quality=92)
    im.resize((im.width // 6, im.height // 6)).save(f"{WORK}/preview_{locale}.png")
    print(f"{locale}: rendered", flush=True)


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    for a in args:
        {"capture": capture, "crops": crops, "render": render}[cmd](a)
