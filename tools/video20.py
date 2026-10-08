#!/usr/bin/env python3
"""SpendZero 2.0 App Store preview video (886x1920, 30 fps, H.264 + AAC, under 30 s).

  record <set>...     record each clip on the screenshot simulator (same capture sets as shots20.py)
  compose <locale>... cut the clips, add the locale's screenshot headlines as captions and the app's own
                      sound effects, and write screenshots/v20/<locale>/preview.mp4

Every frame is footage of the app itself; captions sit on a dark band over the top of the screen.
"""
import json, os, re, signal, subprocess, sys, time
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shots20 as S  # noqa: E402

ROOT, WORK, UDID, BID = S.ROOT, S.WORK, S.UDID, S.BID
FFMPEG = "/opt/homebrew/bin/ffmpeg"
SOUNDS = f"{ROOT}/Resources/Sounds"
W, H = 886, 1920

SEED = ["-SeedDemoData"]
# name, launch args, record seconds, (offset after the splash, length), caption frame, sound and when (s into the clip)
CLIPS = [
    ("sealed", SEED + ["-ShowDaySealed"], 9, (1.1, 4.0), "f1", ("clink", 0.2)),
    ("vault", SEED + ["-ScrollToVault", "-VaultSimulateSeal"], 11, (1.0, 4.6), "f2", ("clink", 1.6)),
    ("forecast", ["-hasCompletedOnboarding", "NO", "-ShowForecast"], 9, (1.3, 3.6), "f3", ("chime", 0.3)),
    ("calendar", SEED + ["-InitialTab", "calendar"], 8, (0.2, 3.4), "f4", None),
    ("tree", SEED + ["-InitialTab", "gamification", "-ScrollToTree", "-TreeSeason", "december", "-TreeHour", "20.5", "-TreeEvents"], 11, (1.0, 4.0), "f6", ("chime", 0.6)),
    ("recap", SEED + ["-ShowRecap"], 10, (0.6, 4.2), None, ("flip", 0.3)),  # the recap card carries its own headline
    ("levelup", SEED + ["-ShowLevelUp"], 8, (1.3, 3.6), "f9", ("levelup", 0.2)),
]
XFADE = 0.35


def sh(*a, timeout=120):
    return subprocess.run(a, capture_output=True, text=True, timeout=timeout)


def record(set_name):
    lang, region = S.SETS[set_name]
    out = f"{WORK}/video_{set_name}"
    os.makedirs(out, exist_ok=True)
    for name, args, secs, *_ in CLIPS:
        path = f"{out}/{name}.mov"
        if os.path.exists(path):
            os.remove(path)
        sh("xcrun", "simctl", "terminate", UDID, BID)
        time.sleep(1)
        rec = subprocess.Popen(["xcrun", "simctl", "io", UDID, "recordVideo", "--codec=h264", "--force", path],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1.2)
        sh("xcrun", "simctl", "launch", UDID, BID, "-AppleLanguages", f"({lang})", "-AppleLocale", region, *args)
        time.sleep(secs)
        rec.send_signal(signal.SIGINT)
        try:
            rec.wait(timeout=30)
        except subprocess.TimeoutExpired:
            rec.kill()
        print(f"{set_name}: {name}", flush=True)
    sh("xcrun", "simctl", "terminate", UDID, BID)


def splash_end(path):
    """Seconds until the bright-green launch screen is gone (sampled every 0.1 s)."""
    tmp = f"{WORK}/_frames"
    os.makedirs(tmp, exist_ok=True)
    for f in os.listdir(tmp):
        os.remove(f"{tmp}/{f}")
    sh(FFMPEG, "-v", "error", "-i", path, "-t", "8", "-vf", "fps=10,scale=40:-1", f"{tmp}/%04d.png")
    seen_splash = False
    for i, f in enumerate(sorted(os.listdir(tmp))):
        if S.looks_like_splash(f"{tmp}/{f}"):
            seen_splash = True
        elif seen_splash:
            return i / 10.0
    return 1.5


def caption_png(cap, frame, rtl, out):
    """Headline in the screenshot style on a dark top band, rendered with the same fonts by headless Chrome."""
    h = cap[frame]["h"].replace("<g>", '<span class="g">').replace("</g>", "</span>")
    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: SFR; src: url("file:///System/Library/Fonts/SFNSRounded.ttf"); font-weight: 100 1000; }}
html,body {{ margin:0; width:{W}px; height:{H}px; background:transparent; }}
.band {{ position:absolute; left:0; right:0; top:0; height:440px;
  background: linear-gradient(180deg, rgb(4,16,10) 0%, rgb(4,16,10) 80%, rgba(4,16,10,0) 100%); }}
.h {{ position:absolute; left:40px; right:40px; top:120px; text-align:center; font:850 84px/1.04 SFR, sans-serif;
  letter-spacing:{'0' if rtl else '-1.5px'}; color:#fff; white-space:nowrap; direction:{'rtl' if rtl else 'ltr'}; }}
.g {{ background: linear-gradient(180deg,#FFF6C2,#FFD740 45%,#FFA000); -webkit-background-clip:text; background-clip:text; color:transparent; }}
</style></head><body><div class="band"></div><div class="h" id="h">{h}</div>
<script>const el=document.getElementById('h'); let s=84; while(el.scrollWidth>el.clientWidth+2&&s>40){{s-=3;el.style.fontSize=s+'px';}}</script>
</body></html>"""
    page = out.replace(".png", ".html")
    open(page, "w").write(html)
    sh(S.CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
       "--force-device-scale-factor=1", f"--window-size={W},{H}", "--default-background-color=00000000",
       "--virtual-time-budget=3000", f"--screenshot={out}", f"file://{page}", timeout=300)


def compose(locale):
    set_name = S.LOCALE_SET.get(locale, "en_US")
    src = f"{WORK}/video_{set_name}"
    cap = json.load(open(f"{ROOT}/localization/v20/captions_{'en' if locale == 'en-US' else locale}.json"))
    rtl = locale in S.RTL
    tmp = f"{WORK}/vid_{locale}"
    os.makedirs(tmp, exist_ok=True)
    parts, sounds, t = [], [], 0.0
    for i, (name, _, _, (off, length), frame, sound) in enumerate(CLIPS):
        clip = f"{src}/{name}.mov"
        start = splash_end(clip) + off
        part = f"{tmp}/{i:02d}_{name}.mp4"
        base = (f"[0:v]trim=start={start:.2f}:duration={length:.2f},setpts=PTS-STARTPTS,fps=30,"
                f"scale={W}:-2,crop={W}:{H}:0:(ih-{H})/2")
        if frame:
            png = f"{tmp}/cap_{name}.png"
            caption_png(cap, frame, rtl, png)
            vf = (base + ",format=yuva420p[v];"
                  "[1:v]format=rgba,fade=t=in:st=0.15:d=0.3:alpha=1[c];[v][c]overlay=0:0,format=yuv420p")
            extra = ["-loop", "1", "-t", f"{length:.2f}", "-i", png]
        else:
            vf, extra = base + ",format=yuv420p", []
        r = sh(FFMPEG, "-v", "error", "-y", "-i", clip, *extra,
               "-filter_complex", vf, "-t", f"{length:.2f}", "-an", "-c:v", "libx264", "-preset", "medium",
               "-crf", "18", "-pix_fmt", "yuv420p", part, timeout=600)
        if r.returncode:
            raise SystemExit(f"{locale}/{name}: {r.stderr[-400:]}")
        parts.append((part, length))
        if sound:
            sounds.append((sound[0], t + sound[1]))
        t += length - XFADE
    # Cross-fade the clips together.
    inputs, chain, last, offset = [], "", "0:v", 0.0
    for p, _ in parts:
        inputs += ["-i", p]
    for i in range(1, len(parts)):
        offset += parts[i - 1][1] - XFADE
        out = f"x{i}"
        chain += f"[{last}][{i}:v]xfade=transition=fade:duration={XFADE}:offset={offset:.2f}[{out}];"
        last = out
    total = sum(l for _, l in parts) - XFADE * (len(parts) - 1)
    # The app's own sounds at their moments, over a silent stereo bed.
    n = len(parts)
    audio_inputs, amix = [], []
    for j, (snd, at) in enumerate(sounds):
        audio_inputs += ["-i", f"{SOUNDS}/{snd}.wav"]
        amix.append(f"[{n + j}:a]adelay={int(at * 1000)}|{int(at * 1000)},volume=0.8[s{j}]")
    bed = f"anullsrc=r=44100:cl=stereo,atrim=duration={total:.2f}[bed]"
    mix_inputs = "[bed]" + "".join(f"[s{j}]" for j in range(len(sounds)))
    afilter = ";".join([bed] + amix + [f"{mix_inputs}amix=inputs={len(sounds) + 1}:normalize=0,atrim=duration={total:.2f}[a]"])
    dest = f"{ROOT}/screenshots/v20/{locale}/preview.mp4"
    r = sh(FFMPEG, "-v", "error", "-y", *inputs, *audio_inputs, "-filter_complex", chain + afilter,
           "-map", f"[{last}]", "-map", "[a]", "-c:v", "libx264", "-profile:v", "high", "-level", "4.0",
           "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-r", "30", "-c:a", "aac", "-b:a", "256k",
           "-ar", "44100", "-ac", "2", "-movflags", "+faststart", "-t", f"{total:.2f}", dest, timeout=1200)
    if r.returncode:
        raise SystemExit(f"{locale}: {r.stderr[-600:]}")
    print(f"{locale}: preview {total:.1f}s", flush=True)


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    for a in args:
        {"record": record, "compose": compose}[cmd](a)
