#!/usr/bin/env python3
"""SpendZero 2.0 localization helper.
  todo                 write localization/v20/todo/<lang>.json (what each language still needs)
  validate <lang>...   check localization/v20/out/<lang>.json (formats, Siri tokens, coverage)
  merge <lang>...      write the validated translations into Resources/<lang>.lproj
"""
import json, os, re, sys, glob, plistlib, collections
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V = f"{ROOT}/localization/v20"
EXISTING = ["de","es","fr","fr-CA","it","ja","nl","pt-BR","pt-PT","tr","zh-Hans"]
NEW = ["ko","zh-Hant","sv","da","nb","fi"]
PLURAL_CATS = {"ko":["other"],"zh-Hant":["other"],"ja":["other"],"zh-Hans":["other"],"sv":["one","other"],"da":["one","other"],"nb":["one","other"],"fi":["one","other"],
               "de":["one","other"],"nl":["one","other"],"it":["one","many","other"],"es":["one","many","other"],"fr":["one","many","other"],"fr-CA":["one","many","other"],
               "pt-BR":["one","many","other"],"pt-PT":["one","many","other"],"tr":["one","other"]}
FMT = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|\.?\d*f|li|i|u|llu)")

def read_strings(p):
    out = {}
    if not os.path.exists(p): return out
    txt = open(p, encoding="utf-8").read()
    for m in re.finditer(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', txt, re.M):
        out[unesc(m.group(1))] = unesc(m.group(2))
    return out
def unesc(s): return s.replace('\\"','"').replace("\\n","\n").replace("\\\\","\\")
def esc(s): return s.replace("\\","\\\\").replace('"','\\"').replace("\n","\\n")
def fmts(s): return sorted(re.sub(r"\d+\$","",f) for f in FMT.findall(s))

def source():
    return json.load(open(f"{V}/source_en.json"))

def todo():
    src = source(); en = read_strings(f"{ROOT}/Resources/en.lproj/Localizable.strings")
    sd = plistlib.load(open(f"{ROOT}/Resources/en.lproj/Localizable.stringsdict","rb"))
    allkeys = dict(src["Localizable"])
    for k,v in en.items():  # keys only used dynamically (category names etc.) still need translating
        allkeys.setdefault(k, {"comment":"","source":"(dynamic)","en":v})
    info = read_strings(f"{ROOT}/Resources/en.lproj/InfoPlist.strings")
    sc = read_strings(f"{ROOT}/Resources/en.lproj/AppShortcuts.strings")
    for l in EXISTING + NEW:
        have = read_strings(f"{ROOT}/Resources/{l}.lproj/Localizable.strings")
        need = {k:v for k,v in allkeys.items() if k not in have and k not in sd}
        task = {"lang": l, "new_language": l in NEW, "plural_categories": PLURAL_CATS[l], "Localizable": need}
        if l in NEW:
            task["plurals"] = {k: {"en": {c: v[c] for c in v if isinstance(v, dict)} if False else None} for k in []}
            task["plurals"] = {k: {"format": v.get("NSStringLocalizedFormatKey"), "en": {c: x for c, x in v[[kk for kk in v if kk != "NSStringLocalizedFormatKey"][0]].items() if c in ("zero","one","two","few","many","other")}} for k, v in sd.items()}
            task["InfoPlist"] = info; task["AppShortcuts"] = sc
        json.dump(task, open(f"{V}/todo/{l}.json","w"), ensure_ascii=False, indent=1)
        print(l, "Localizable:", len(need), "| plurals:", len(task.get("plurals",{})))

def validate(l, quiet=False):
    t = json.load(open(f"{V}/todo/{l}.json")); p = f"{V}/out/{l}.json"
    if not os.path.exists(p): print(l, "no output yet"); return False
    o = json.load(open(p)); errs = []; warns = []
    loc = o.get("Localizable", {})
    for k,v in t["Localizable"].items():
        if k not in loc: errs.append(f"missing: {k!r}"); continue
        tr = loc[k]
        if not isinstance(tr,str) or not tr.strip(): errs.append(f"empty: {k!r}"); continue
        if fmts(tr) != fmts(v["en"] if v.get("en") else k): errs.append(f"format mismatch: {k!r} -> {tr!r}")
        if "%" in tr and re.search(r"%(?!(?:\d+\$)?(?:lld|ld|d|@|\.?\d*f|li|i|u|llu|%))", tr): errs.append(f"stray %: {k!r} -> {tr!r}")
    for k,forms in o.get("plurals", {}).items():
        for c in t["plural_categories"]:
            if c not in forms: errs.append(f"plural {k!r} lacks {c}")
    for k,v in (t.get("AppShortcuts") or {}).items():
        tr = o.get("AppShortcuts",{}).get(k)
        if not tr: errs.append(f"AppShortcuts missing {k!r}")
        elif "${applicationName}" not in tr: errs.append(f"AppShortcuts {k!r} lacks ${{applicationName}}")
    for k in (t.get("InfoPlist") or {}):
        if not o.get("InfoPlist",{}).get(k): errs.append(f"InfoPlist missing {k!r}")
    same = [k for k,v in t["Localizable"].items() if loc.get(k) == (v.get("en") or k) and re.search(r"[a-z]{4,}", k)]
    if len(same) > 25: warns.append(f"{len(same)} strings identical to English (check they are names/brands): {same[:8]}")
    print(f"{l}: {len(errs)} errors, {len(warns)} warnings")
    for e in (errs if not quiet else errs[:15]): print("  ERR", e)
    for w in warns: print("  WARN", w)
    return not errs

def merge(l):
    if not validate(l, quiet=True): print(l, "not merged (fix errors first)"); return
    t = json.load(open(f"{V}/todo/{l}.json")); o = json.load(open(f"{V}/out/{l}.json"))
    d = f"{ROOT}/Resources/{l}.lproj"; os.makedirs(d, exist_ok=True)
    p = f"{d}/Localizable.strings"
    have = read_strings(p)
    add = {k:o["Localizable"][k] for k in t["Localizable"] if k not in have}
    with open(p, "a", encoding="utf-8") as f:
        if not have: f.write("/* SpendZero */\n")
        f.write("\n/* 2.0 */\n")
        for k,v in add.items(): f.write(f'"{esc(k)}" = "{esc(v)}";\n')
    if o.get("plurals"):
        en = plistlib.load(open(f"{ROOT}/Resources/en.lproj/Localizable.stringsdict","rb"))
        sp = f"{d}/Localizable.stringsdict"
        cur = plistlib.load(open(sp,"rb")) if os.path.exists(sp) else {}
        for k,forms in o["plurals"].items():
            base = en.get(k)
            if not base: continue
            entry = json.loads(json.dumps(base)); var = [x for x in entry if x != "NSStringLocalizedFormatKey"][0]
            for c in ("zero","one","two","few","many","other"): entry[var].pop(c, None)
            for c in t["plural_categories"]: entry[var][c] = forms[c]
            if "format" in forms: entry["NSStringLocalizedFormatKey"] = forms["format"]
            cur[k] = entry
        plistlib.dump(cur, open(sp,"wb"), fmt=plistlib.FMT_XML)
    for name in ("InfoPlist","AppShortcuts"):
        if o.get(name):
            with open(f"{d}/{name}.strings","w",encoding="utf-8") as f:
                for k,v in o[name].items(): f.write(f'"{esc(k)}" = "{esc(v)}";\n')
    os.system(f'plutil -lint "{d}"/*.strings "{d}"/*.stringsdict 2>/dev/null | grep -v ": OK" || true')
    print(l, "merged", len(add), "strings")

if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "todo": todo()
    elif cmd == "validate": [validate(l) for l in args]
    elif cmd == "merge": [merge(l) for l in args]
